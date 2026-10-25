## ROAD TRIP's home (port ADR-087): the garage, the mode's logo, and a
## MenuPage: CONTINUE (the trip in progress), NEW TRIP (pressed twice over
## a trip in progress), PARTNER (Pepper or a captain you've beaten), HEAT,
## GARAGE, SCRAPBOOK and BACK; under it the trip records. GARAGE shows the
## ladder of lasting rewards (the steps reached stamped, the next and the
## ones after) and the looks you've unlocked (VAN, ORNAMENT, CASSETTE).
## SCRAPBOOK (port ADR-092) shows the story told across trips, arc by arc:
## the chapters seen (left and right, B watches one again) and a hint at
## the next. After a trip, its results first: how far, the matches, the
## miles and the steps they reached.
class_name TripHome
extends Control

signal start(trip: RoadTrip)     ## a new trip, stored
signal resume(trip: RoadTrip)    ## the trip in progress
signal replay(beat: Dictionary)  ## a SCRAPBOOK chapter to watch again
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
var scrap_page: MenuPage
var view := "home"               ## "home", "garage", "scrapbook", "results"
var chapter := {}                ## the SCRAPBOOK's chapter chosen per arc
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
var _scrap: Control
var _scrap_lines: Array = []
var _open := ""
var _bg: Sprite2D
var _sfx: Sfx


## `open`: a view to open on ("scrapbook", back from watching a chapter).
func setup(game_save: SaveGame, ended: Dictionary = {}, open := "") -> TripHome:
	save = game_save
	results = ended
	_open = open
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
	_bg = Sprite2D.new()
	_bg.texture = load(DIR + "trip_garage.webp")
	_bg.centered = false
	add_child(_bg)
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
	elif _open == "scrapbook":
		_open_scrapbook()
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
	rows.append({"id": "scrapbook", "label": "SCRAPBOOK", "value": func(): return "%d/%d" % [
		meta()["beats"].size(), RoadTrip.data()["beats"].size()], "press": func(): _open_scrapbook()})
	rows.append({"id": "back", "label": "BACK", "press": func(): _leave()})
	page = MenuPage.new().setup("trip", "", rows,
		Rect2(540, 136, 400, 18 + rows.size() * MenuPage.ROW_H + 50), [["hit", "SELECT"], ["back", "BACK"]])
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
		"scrapbook":
			_close_scrapbook()
		"results":
			_close_results()
		_:
			_leave()


func _build_records() -> void:
	var p := UiKit.panel(Rect2(540, 408, 400, 112), self)
	p.name = "records"
	for k in 3:
		_records.append(UiKit.text("small", "", Vector2(560, 422 + k * 26), 0.0, DIM, self))
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
	UiKit.panel(Rect2(40, 136, 880, 206), _garage)
	_show_records(false)
	UiKit.text("big_gold", "THE GARAGE", Vector2(480, 146), 0.5, Color.WHITE, _garage)
	var m := meta()
	var reached := RoadTrip.steps_reached(m)
	var ladder: Array = RoadTrip.data()["ladder"]
	var first := clampi(reached - 2, 0, maxi(0, ladder.size() - TAGS_SHOWN))
	var tags: Texture2D = load(DIR + "trip_ladder_step.png")
	for k in TAGS_SHOWN:
		var i := first + k
		if i >= ladder.size():
			break
		var at := Vector2(480 - (TAGS_SHOWN * 160 - 40) / 2.0 + k * 160, 186)
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
	UiKit.text("small", nxt, Vector2(480, 284), 0.5, GOLD, _garage)
	if reached < ladder.size():
		UiKit.text("small", "%d MILES TO GO, %d DRIVEN" % [RoadTrip.miles_to_next(m), int(m["miles"])],
			Vector2(480, 308), 0.5, DIM, _garage)
	var g := RoadTrip.garage(m)
	var looks: Dictionary = m["looks"]
	garage_page = MenuPage.new().setup("garage", "", [
		{"id": "van", "label": "VAN", "value": func(): return String(RoadTrip.data()["vans"][int(looks["van"])]),
			"change": func(d): looks["van"] = _cycle(g["vans"], int(looks["van"]), d)},
		{"id": "ornament", "label": "ORNAMENT", "value": func(): return String(RoadTrip.data()["ornaments"][int(looks["ornament"])]),
			"change": func(d): looks["ornament"] = _cycle(g["ornaments"], int(looks["ornament"]), d)},
		{"id": "tape", "label": "CASSETTE", "value": func(): return String(RoadTrip.data()["tapes"][int(looks["tape"])]["name"]),
			"change": func(d): looks["tape"] = _cycle(g["tapes"], int(looks["tape"]), d)},
		{"id": "back", "label": "BACK", "press": func(): _close_garage()},
	], Rect2(250, 352, 460, 18 + 4 * MenuPage.ROW_H + 50), [["dpad", "CHANGE"], ["back", "BACK"]])
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
		s.region_enabled = false
		s.texture = TripArt.gear_icon(id)
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
	var box := s.region_rect.size if s.region_enabled else s.texture.get_size()
	var k2 := IN_WINDOW / maxf(box.x, box.y)
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


# --- The SCRAPBOOK ------------------------------------------------------------------

func _open_scrapbook() -> void:
	_beep("confirm")
	view = "scrapbook"
	page.visible = false
	_show_records(false)
	_scrap = Control.new()
	_scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrap)
	if TripArt.has_backdrop("scrapbook"):
		_bg.texture = TripArt.backdrop("scrapbook")
	var rows := []
	for arc in RoadTrip.data()["arcs"]:
		var id := String(arc["id"])
		rows.append({"id": id, "label": String(arc["name"]), "value": func(): return _arc_value(id),
			"change": func(d): _change_chapter(id, d), "press": func(): _watch(id)})
	rows.append({"id": "back", "label": "BACK", "press": func(): _close_scrapbook()})
	scrap_page = MenuPage.new().setup("scrapbook", "SCRAPBOOK", rows,
		Rect2(200, 136, 560, 64 + rows.size() * MenuPage.ROW_H + 50),
		[["dpad", "CHAPTER"], ["hit", "WATCH"], ["back", "BACK"]])
	_scrap.add_child(scrap_page)
	scrap_page.back_requested.connect(_close_scrapbook)
	scrap_page.hovered.connect(func(_id): _scrap_refresh())
	scrap_page.changed.connect(func(_id): _scrap_refresh())
	UiKit.panel(Rect2(130, 396, 700, 110), _scrap)
	for k in 3:
		_scrap_lines.append(UiKit.text("small", "", Vector2(480, 410 + k * 28), 0.5,
			GOLD if k == 0 else (Color.WHITE if k == 1 else DIM), _scrap))
	_scrap_refresh()
	_lock = LOCK


func _arc_value(arc: String) -> String:
	return "%d/%d" % [RoadTrip.arc_seen(meta(), arc).size(), RoadTrip.arc_beats(arc).size()]


## The chapter chosen in an arc: the latest seen, until you choose another.
func chosen(arc: String) -> int:
	var seen := RoadTrip.arc_seen(meta(), arc)
	return clampi(int(chapter.get(arc, seen.size() - 1)), 0, maxi(0, seen.size() - 1))


func _change_chapter(arc: String, d: int) -> void:
	var n := RoadTrip.arc_seen(meta(), arc).size()
	if n > 0:
		chapter[arc] = (chosen(arc) + d + n) % n
	_scrap_refresh()


func _watch(arc: String) -> void:
	var seen := RoadTrip.arc_seen(meta(), arc)
	if seen.is_empty():
		_beep("back")
		return
	_beep("confirm")
	replay.emit(seen[chosen(arc)])


func _scrap_refresh() -> void:
	scrap_page.refresh()
	var arc := scrap_page.current_id()
	for l in _scrap_lines:
		l.text = ""
	if arc == "back":
		_scrap_lines[0].text = "%d OF %d CHAPTERS SEEN" % [meta()["beats"].size(), RoadTrip.data()["beats"].size()]
		return
	var seen := RoadTrip.arc_seen(meta(), arc)
	if seen.is_empty():
		_scrap_lines[0].text = "NOT STARTED"
	else:
		var i := chosen(arc)
		_scrap_lines[0].text = "CHAPTER %d: %s" % [i + 1, String(seen[i]["title"])]
	var hint := RoadTrip.arc_hint(meta(), arc)
	_scrap_lines[1].text = "NEXT: " + hint if hint != "" else "THE END. FOR NOW."
	if not seen.is_empty():
		_scrap_lines[2].text = "WATCH IT AGAIN ANY TIME."


func _close_scrapbook() -> void:
	_beep("back")
	view = "home"
	if _scrap:
		_scrap.queue_free()
		_scrap = null
		scrap_page = null
	_scrap_lines.clear()
	_bg.texture = load(DIR + "trip_garage.webp")
	page.visible = true

	_show_records(true)
	_lock = LOCK


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
		"scrapbook":
			var nav3 := scrap_page.drive()
			if nav3 & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
				_beep("blip")
				_scrap_refresh()
			if nav3 & MenuPage.NAV_BACK:
				_close_scrapbook()

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
