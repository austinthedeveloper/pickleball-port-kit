## ROAD TRIP's home (port ADR-087): the garage, the mode's logo, and a
## MenuPage: CONTINUE (the trip in progress), NEW TRIP (pressed twice over
## a trip in progress), PARTNER (Pepper or a captain you've beaten), HEAT,
## GARAGE and BACK; under it the trip records. GARAGE shows the ladder of
## lasting rewards (the steps reached stamped, the next and the ones after)
## and the looks you've unlocked (VAN, ORNAMENT). After a trip, its results
## first: how far, the matches, the miles and the steps they reached.
class_name TripHome
extends Control

signal start(trip: RoadTrip)     ## a new trip, stored
signal resume(trip: RoadTrip)    ## the trip in progress
signal leave

const DIR := "res://assets/trip/"
const LOCK := MenuPage.TRANSITION
const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)
const TAG := Vector2(120, 72)
const TAGS_SHOWN := 5
const WINDOW := Vector2(89, 36)        ## the centre of a tag's window
const IN_WINDOW := 28.0                ## px a reward's picture fills

var save: SaveGame
var page: MenuPage
var garage_page: MenuPage
var view := "home"               ## "home", "garage", "results"
var heat := 0
var partner := RoadTrip.PEPPER
var new_armed := false
var results: Dictionary = {}     ## the trip just ended: its numbers, steps reached
## A new trip's seed in the tests (0: the clock's).
static var seed_override := 0
var _lock := LOCK
var _records: Array = []
var _garage: Control
var _results: Control
var _sfx: Sfx


func setup(game_save: SaveGame, ended: Dictionary = {}) -> TripHome:
	save = game_save
	results = ended
	var m := RoadTrip.meta(save)
	heat = int(m["heat"])
	return self


func music_track() -> String:
	return "title"


func meta() -> Dictionary:
	return RoadTrip.meta(save)


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "trip_garage.webp")
	bg.centered = false
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.25)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var logo := Sprite2D.new()
	logo.texture = load(DIR + "trip_title_card.png")
	logo.centered = false
	logo.scale = Vector2(0.6, 0.6)
	logo.position = Vector2(540, 8)
	add_child(logo)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_build_home()
	_build_records()
	if not results.is_empty():
		_show_results()
	GameControls.clear_latch()


# --- Home -----------------------------------------------------------------------------

func _build_home() -> void:
	if page:
		page.queue_free()
	var rows := []
	var now := RoadTrip.current(save)
	if now != null:
		rows.append({"id": "continue", "label": "CONTINUE", "value": func(): return _continue_label(),
			"press": func(): _continue()})
	rows.append({"id": "new", "label": "NEW TRIP", "value": func(): return "PRESS AGAIN" if new_armed else "",
		"press": func(): _new()})
	rows.append({"id": "partner", "label": "PARTNER", "value": func(): return partner_name(partner),
		"change": func(d): _change_partner(d)})
	rows.append({"id": "heat", "label": "HEAT", "value": func(): return str(heat),
		"change": func(d): heat = clampi(heat + d, 0, int(meta()["heat"]))})
	rows.append({"id": "garage", "label": "GARAGE", "value": func(): return "STEP %d/%d" % [
		RoadTrip.steps_reached(meta()), RoadTrip.data()["ladder"].size()], "press": func(): _open_garage()})
	rows.append({"id": "back", "label": "BACK", "press": func(): _leave()})
	page = MenuPage.new().setup("trip", "", rows,
		Rect2(540, 148, 400, 18 + rows.size() * MenuPage.ROW_H + 50), [["hit", "SELECT"], ["back", "BACK"]])
	add_child(page)
	page.pressed.connect(func(_id): page.refresh())
	page.back_requested.connect(_on_back)


func _continue_label() -> String:
	var t := RoadTrip.current(save)
	if t == null:
		return ""
	return "LEG %d, %d %s" % [t.leg() + 1, t.hearts, "HEART" if t.hearts == 1 else "HEARTS"]


## The partners you can take: Pepper, then the captains you've beaten.
func partners() -> Array:
	var out := [RoadTrip.PEPPER]
	for p in meta()["partners"]:
		out.append(int(p))
	return out


static func partner_name(p: int) -> String:
	if p >= 0 and Opponents.exists(p):
		return String(Opponents.team(p)["players"][0]["name"])
	return String(StoryMode.partner()["name"])


func _change_partner(d: int) -> void:
	var all := partners()
	var i := all.find(partner)
	partner = int(all[(i + d + all.size()) % all.size()])


func _continue() -> void:
	var t := RoadTrip.current(save)
	if t == null:
		return
	_beep("confirm")
	resume.emit(t)


func _new() -> void:
	if RoadTrip.current(save) != null and not new_armed:
		new_armed = true
		_beep("blip")
		return
	_beep("confirm")
	var t := RoadTrip.begin(save, seed_override if seed_override else Time.get_ticks_usec(), heat, partner)
	save.save_game()
	start.emit(t)


func _leave() -> void:
	_beep("back")
	leave.emit()


func _on_back() -> void:
	match view:
		"garage":
			_close_garage()
		"results":
			_close_results()
		_:
			_leave()


func _build_records() -> void:
	var p := UiKit.panel(Rect2(540, 382, 400, 120), self)
	p.name = "records"
	for k in 3:
		_records.append(UiKit.text("small", "", Vector2(560, 398 + k * 28), 0.0, DIM, self))
	_refresh_records()


func _refresh_records() -> void:
	var m := meta()
	var best := int(m["best_heat"])
	_records[0].text = "TRIPS %d    WON %d" % [int(m["trips"]), int(m["won"])]
	_records[1].text = "BEST HEAT %s    FARTHEST LEG %d" % ["-" if best < 0 else str(best), maxi(1, int(m["best_leg"]))]
	_records[2].text = "MILES %d" % int(m["miles"])


# --- The GARAGE ------------------------------------------------------------------------

func _open_garage() -> void:
	_beep("confirm")
	view = "garage"
	page.visible = false
	_garage = Control.new()
	_garage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_garage)
	UiKit.panel(Rect2(40, 150, 880, 214), _garage)
	_show_records(false)
	UiKit.text("big_gold", "THE GARAGE", Vector2(480, 162), 0.5, Color.WHITE, _garage)
	var m := meta()
	var reached := RoadTrip.steps_reached(m)
	var ladder: Array = RoadTrip.data()["ladder"]
	var first := clampi(reached - 2, 0, maxi(0, ladder.size() - TAGS_SHOWN))
	var tags: Texture2D = load(DIR + "trip_ladder_step.png")
	for k in TAGS_SHOWN:
		var i := first + k
		if i >= ladder.size():
			break
		var at := Vector2(480 - (TAGS_SHOWN * 160 - 40) / 2.0 + k * 160, 204)
		var tag := Sprite2D.new()
		tag.texture = tags
		tag.region_enabled = true
		# the sheet: reached (stamped), plain, next (greyed)
		var cell := 0 if i < reached else (2 if i > reached else 1)
		tag.region_rect = Rect2(cell * TAG.x, 0, TAG.x, TAG.y)
		tag.centered = false
		tag.position = at
		_garage.add_child(tag)
		_step_icon(i, at + WINDOW)
		UiKit.text("small", str(i + 1), Vector2(at.x + TAG.x / 2.0, at.y + TAG.y + 2), 0.5,
			GOLD if i == reached else DIM, _garage)
	var nxt := "THE TOP OF THE LADDER!" if reached >= ladder.size() else \
		"NEXT: " + RoadTrip.step_label(reached)
	UiKit.text("small", nxt, Vector2(480, 304), 0.5, GOLD, _garage)
	if reached < ladder.size():
		UiKit.text("small", "%d MILES TO GO, %d DRIVEN" % [RoadTrip.miles_to_next(m), int(m["miles"])],
			Vector2(480, 328), 0.5, DIM, _garage)
	var g := RoadTrip.garage(m)
	var looks: Dictionary = m["looks"]
	garage_page = MenuPage.new().setup("garage", "", [
		{"id": "van", "label": "VAN", "value": func(): return String(RoadTrip.data()["vans"][int(looks["van"])]),
			"change": func(d): looks["van"] = _cycle(g["vans"], int(looks["van"]), d)},
		{"id": "ornament", "label": "ORNAMENT", "value": func(): return String(RoadTrip.data()["ornaments"][int(looks["ornament"])]),
			"change": func(d): looks["ornament"] = _cycle(g["ornaments"], int(looks["ornament"]), d)},
		{"id": "back", "label": "BACK", "press": func(): _close_garage()},
	], Rect2(250, 372, 460, 18 + 3 * MenuPage.ROW_H + 50), [["dpad", "CHANGE"], ["back", "BACK"]])
	_garage.add_child(garage_page)
	garage_page.back_requested.connect(_close_garage)
	_lock = LOCK


static func _cycle(options: Array, value: int, d: int) -> int:
	var i := options.find(value)
	return int(options[(i + d + options.size()) % options.size()])


## The reward's picture in a ladder tag's window (centred on `at`).
func _step_icon(i: int, at: Vector2) -> void:
	var step: Dictionary = RoadTrip.data()["ladder"][i]
	var s := Sprite2D.new()
	s.position = at
	s.region_enabled = true
	if step.has("pool") or step.has("start_paddle"):
		var id := String(step["pool"][0]) if step.has("pool") else String(step["start_paddle"])
		var icon := int(RoadTrip.gear(id)["icon"])
		s.texture = load(DIR + "trip_gear_icons.png")
		s.region_rect = Rect2((icon % 8) * 64, (icon / 8) * 64, 64, 64)
	elif step.has("van"):
		s.texture = load(DIR + "trip_van_paints.png")
		s.region_rect = Rect2(64 * int(step["van"]), 0, 64, 40)
	elif step.has("ornament"):
		s.texture = load(DIR + "trip_dash_ornaments.png")
		s.region_rect = Rect2(48 * int(step["ornament"]), 0, 48, 64)
	elif step.has("heart") or step.has("cash"):
		s.texture = load(DIR + "trip_hud_icons.png")
		s.region_rect = Rect2(0 if step.has("heart") else 48, 0, 24, 24)
	else:
		var n := 1
		for k in RoadTrip.STATS:
			n = maxi(n, int(step.get(k, 0)))
		var t := UiKit.text("small", "+%d" % n, at + Vector2(0, -12), 0.5, Color(0.3, 0.25, 0.2), _garage)
		t.ink = true
		return
	var k2 := IN_WINDOW / maxf(s.region_rect.size.x, s.region_rect.size.y)
	s.scale = Vector2(k2, k2)
	_garage.add_child(s)


func _close_garage() -> void:
	_beep("back")
	view = "home"
	if _garage:
		_garage.queue_free()
		_garage = null
		garage_page = null
	save.save_game()
	page.visible = true
	_show_records(true)
	_lock = LOCK


func _show_records(on: bool) -> void:
	for n in _records:
		n.visible = on
	var p := get_node_or_null("records")
	if p:
		p.visible = on


# --- Results --------------------------------------------------------------------------

func _show_results() -> void:
	view = "results"
	page.visible = false
	_results = Control.new()
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_results)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.6)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_child(shade)
	_show_records(false)
	UiKit.panel(Rect2(130, 100, 700, 360), _results)
	var won: bool = results.get("won", false)
	var title := UiKit.text("big_gold", "CHAMPIONS!" if won else "THE TRIP'S OVER",
		Vector2(480, 118), 0.5, Color.WHITE, _results)
	title.scale = Vector2(1.5, 1.5)
	title.position.x = 480
	var lines := [
		"THE SUMMER OPEN, WON!" if won else "TURNED FOR HOME ON LEG %d" % int(results.get("leg", 1)),
		"%d WON, %d LOST, %d STOPS" % [int(results.get("wins", 0)), int(results.get("losses", 0)),
			int(results.get("stops", 0))],
		"+%d MILES" % int(results.get("miles", 0)),
	]
	var steps: Array = results.get("steps", [])
	for i in mini(2, steps.size()):
		lines.append("GARAGE: " + RoadTrip.step_label(int(steps[i])))
	if steps.size() > 2:
		lines.append("AND %d MORE IN THE GARAGE" % (steps.size() - 2))
	if won and int(results.get("heat_open", -1)) >= 0:
		lines.append("HEAT %d IS OPEN" % int(results["heat_open"]))
	for i in lines.size():
		UiKit.text("small", String(lines[i]), Vector2(480, 184 + i * 30), 0.5,
			GOLD if String(lines[i]).begins_with("GARAGE") or i == 2 else Color.WHITE, _results)
	_results.add_child(PromptBar.new().setup([["hit", "OK"]], Vector2(480, 432)))
	_lock = LOCK * 2


func _close_results() -> void:
	_beep("confirm")
	view = "home"
	if _results:
		_results.queue_free()
		_results = null
	results = {}
	page.visible = true
	_show_records(true)
	_lock = LOCK


func _process(_delta: float) -> void:
	if _lock > 0:
		_lock -= 1
		return
	match view:
		"results":
			if Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
				_close_results()
		"garage":
			var nav := garage_page.drive()
			if nav & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
				_beep("blip")
			if nav & MenuPage.NAV_BACK:
				_close_garage()
		_:
			var nav2 := page.drive()
			if nav2 & MenuPage.NAV_MOVED:
				new_armed = false
				_beep("blip")
				page.refresh()
			if nav2 & MenuPage.NAV_CHANGED:
				_beep("blip")
			if nav2 & MenuPage.NAV_BACK:
				_leave()


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
