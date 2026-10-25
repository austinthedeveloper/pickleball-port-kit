## ROAD TRIP's map (port ADR-087): the van's dashboard, a fold-out road map
## on it scrolling sideways, a pin for every stop and the roads between
## them (the ones you've driven in red pen), the van at your pin. Along the
## top your hearts, cash, leg, paddle, hat and bag; under the map the stop
## you're choosing. The arrows choose among the stops you can drive to
## (by id: "stop_<leg>_<col>_<lane>", select()), HIT drives there (the van
## goes along the road) and plays the stop (`go`); BACK saves and leaves.
## A pick waiting (a match won, a yard sale) opens over it first. The VAN
## button opens THE VAN over it (stats, gear, the locker; port ADR-092).
## Reads a RoadTrip; only the trip's own calls change it.
class_name TripMap
extends Control

signal go(target: Array)         ## [col, lane]: the stop driven to
signal leave

const DIR := "res://assets/trip/"
const LOCK := MenuPage.TRANSITION
const VIEW := Rect2(72, 150, 858, 262)       ## the map's window on the dash
const PAPER_SCALE := 0.78
const PAPER_W := 1800.0
const LEG_W := 600.0
const COL_X := [110.0, 250.0, 390.0]
const GATE_X := 530.0
const LANE_Y := [85.0, 165.0, 245.0]
const HOME := Vector2(40.0, 165.0)
const DRIVE_FRAMES := 36
const PIN := Vector2(32, 40)
const PIN_INDEX := {"big": 0, "final": 1, "pickup": 2, "grudge": 3, "yard": 4, "shop": 5,
	"motel": 6, "detour": 7, "diner": 9, "rival": 10}
const ROAD := Color(0.35, 0.33, 0.3, 0.75)
const DRIVEN := Color(0.78, 0.12, 0.1, 0.95)
const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)

var save: SaveGame
var trip: RoadTrip
var cursor := 0
var scroll := 0.0
var pick: TripPick                ## the pick open over the map, if any
var van: TripVan                  ## THE VAN open over the map, if any
var _targets: Array = []
var _lock := LOCK
var _drive := 0                   ## frames left of the van's drive
var _drive_from := Vector2.ZERO
var _drive_to := Vector2.ZERO
var _frame := 0
var _clip: Control
var _world: Node2D
var _roads: Node2D
var _pins: Node2D
var _cursor_ring: Node2D
var _van: Sprite2D
var _strip: Node2D
var _info: Array = []
var _prompts: PromptBar
var _sfx: Sfx


func setup(game_save: SaveGame, t: RoadTrip) -> TripMap:
	save = game_save
	trip = t
	return self


## The cassette in the deck (the GARAGE's), or the radio.
func music_track() -> String:
	var tapes: Array = RoadTrip.data()["tapes"]
	var tape := int(RoadTrip.meta(save)["looks"].get("tape", 0)) if save else 0
	return String(tapes[clampi(tape, 0, tapes.size() - 1)]["track"])


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "trip_map_dashboard.webp")
	bg.centered = false
	add_child(bg)
	_ornaments()
	_clip = Control.new()
	_clip.position = VIEW.position
	_clip.size = VIEW.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_world = Node2D.new()
	_clip.add_child(_world)
	var paper := Sprite2D.new()
	paper.texture = load(DIR + "trip_map_paper.webp")
	paper.centered = false
	paper.scale = Vector2(PAPER_SCALE, PAPER_SCALE)
	_world.add_child(paper)
	_roads = Node2D.new()
	_roads.draw.connect(_draw_roads)
	_world.add_child(_roads)
	_pins = Node2D.new()
	_world.add_child(_pins)
	_cursor_ring = Node2D.new()
	_cursor_ring.draw.connect(_draw_cursor)
	_world.add_child(_cursor_ring)
	_van = Sprite2D.new()
	_van.texture = load(DIR + "trip_van_paints.png" if van_paint() > 0 else DIR + "trip_van.png")
	_van.region_enabled = true
	_van.offset = Vector2(0, -26)
	_world.add_child(_van)
	_strip = Node2D.new()
	add_child(_strip)
	UiKit.panel(Rect2(48, 416, 864, 116), self)
	for k in 3:
		_info.append(UiKit.text("small", "", Vector2(70, 426 + k * 24), 0.0,
			GOLD if k == 0 else Color.WHITE, self))
	_prompts = PromptBar.new().setup([["dpad", "CHOOSE"], ["hit", "GO"], ["slice", "VAN"], ["back", "LEAVE"]],
		Vector2(600, 514))
	add_child(_prompts)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	refresh()
	scroll = _scroll_for(_van.position.x)
	_world.position.x = -scroll
	GameControls.clear_latch()
	if not trip.pending.is_empty():
		open_pick()


## The van's paint and the dash ornament the GARAGE has on.
func van_paint() -> int:
	return int(RoadTrip.meta(save)["looks"].get("van", 0)) if save else 0


func _ornaments() -> void:
	var looks: Dictionary = RoadTrip.meta(save)["looks"] if save else {}
	var orn := Sprite2D.new()
	orn.texture = load(DIR + "trip_dash_ornaments.png")
	orn.region_enabled = true
	orn.region_rect = Rect2(48 * clampi(int(looks.get("ornament", 0)), 0, 5), 0, 48, 64)
	orn.centered = false
	orn.position = Vector2(16, 236)
	add_child(orn)
	var fresh := Sprite2D.new()
	fresh.texture = orn.texture
	fresh.region_enabled = true
	fresh.region_rect = Rect2(20 * (int(looks.get("ornament", 0)) % 4), 64, 20, 40)
	fresh.centered = false
	fresh.position = Vector2(902, 18)
	add_child(fresh)


# --- Positions ------------------------------------------------------------------------

## A stop's point on the paper (unscaled): leg, column (GATE: its big
## match; START: where the leg begins), lane.
static func paper_point(leg: int, col: int, lane: int) -> Vector2:
	if col == RoadTrip.START:
		if leg == 0:
			return HOME
		return Vector2(LEG_W * (leg - 1) + GATE_X, LANE_Y[1])
	if col == RoadTrip.GATE:
		return Vector2(LEG_W * leg + GATE_X, LANE_Y[1])
	return Vector2(LEG_W * leg + COL_X[col], LANE_Y[lane])


static func world_point(leg: int, col: int, lane: int) -> Vector2:
	return paper_point(leg, col, lane) * PAPER_SCALE


func _scroll_for(x: float) -> float:
	return clampf(x - VIEW.size.x * 0.35, 0.0, PAPER_W * PAPER_SCALE - VIEW.size.x)


func target_id(target: Array) -> String:
	return "stop_%d_%d_%d" % [trip.leg(), int(target[0]), int(target[1])]


func current_id() -> String:
	return target_id(_targets[cursor]) if not _targets.is_empty() else ""


# --- Building ------------------------------------------------------------------------

func refresh() -> void:
	_targets = trip.targets()
	cursor = clampi(cursor, 0, maxi(0, _targets.size() - 1))
	for c in _pins.get_children():
		_pins.remove_child(c)
		c.free()
	_add_pin(0, RoadTrip.START, 0, -1, true)          # home
	for leg in RoadTrip.LEGS:
		for col in RoadTrip.COLS:
			for lane in RoadTrip.LANES:
				var n: Dictionary = trip.map[leg]["cols"][col][lane]
				_add_pin(leg, col, lane, int(PIN_INDEX.get(String(n["type"]), 2)), n["done"],
					int(n.get("team", -1)))
		var g: Dictionary = trip.map[leg]["gate"]
		_add_pin(leg, RoadTrip.GATE, 0, int(PIN_INDEX[String(g["type"])]), g["done"], int(g["team"]))
	_place_van()
	_roads.queue_redraw()
	_cursor_ring.queue_redraw()
	_strip_refresh()
	_info_refresh()


func _add_pin(leg: int, col: int, lane: int, index: int, done: bool, team := -1) -> void:
	if index < 0:
		return
	var s := Sprite2D.new()
	s.texture = TripArt.pin(index, done)
	s.position = world_point(leg, col, lane)
	s.offset = Vector2(0, -PIN.y / 2.0 + 6)
	if index == 0 and team >= 0 and team < Opponents.count() and not done:
		s.modulate = Color.WHITE.lerp(Story.team_color(team), 0.55)   # the crest in the team's colours
	if index == PIN_INDEX["rival"] and not done:
		var rv := Sprite2D.new()                # the ROAD HOGS' RV, parked by their court
		rv.texture = load(DIR + "trip_rv.png")
		rv.flip_h = true
		rv.scale = Vector2(0.6, 0.6)
		rv.position = world_point(leg, col, lane) + Vector2(-30, 4)
		_pins.add_child(rv)
	_pins.add_child(s)


func _place_van() -> void:
	var p := world_point(trip.leg(), trip.col(), trip.lane())
	if trip.state == "won":
		p = world_point(RoadTrip.LEGS - 1, RoadTrip.GATE, 0)
	_van.position = p + Vector2(0, -2)
	_van_frame(0)


## The van: the plain sheet's driving frames, or a paint job (the GARAGE's
## recolours of the parked van) bobbing as it drives.
func _van_frame(i: int) -> void:
	var paint := van_paint()
	if paint > 0:
		_van.region_rect = Rect2(64 * paint, 0, 64, 40)
		_van.offset.y = -26 - (1 if i % 2 == 1 else 0)
	else:
		_van.region_rect = Rect2(64 * (i % 5), 0, 64, 40)


## The top strip: hearts, cash, the leg, your paddle and hat, the bag.
func _strip_refresh() -> void:
	for c in _strip.get_children():
		_strip.remove_child(c)
		c.free()
	UiKit.panel(Rect2(10, 6, 880, 58), _strip)
	var hud: Texture2D = load(DIR + "trip_hud_icons.png")
	for i in trip.max_hearts:
		var h := Sprite2D.new()
		h.texture = hud
		h.region_enabled = true
		h.region_rect = Rect2(0 if i < trip.hearts else 24, 0, 24, 24)
		h.centered = false
		h.position = Vector2(26 + i * 26, 22)
		_strip.add_child(h)
	var x := 30.0 + trip.max_hearts * 26
	var cash := Sprite2D.new()
	cash.texture = hud
	cash.region_enabled = true
	cash.region_rect = Rect2(48, 0, 24, 24)
	cash.centered = false
	cash.position = Vector2(x, 22)
	_strip.add_child(cash)
	UiKit.text("small", str(trip.cash), Vector2(x + 28, 24), 0.0, GOLD, _strip)
	UiKit.text("small", "LEG %d" % (trip.leg() + 1), Vector2(x + 96, 24), 0.0, Color.WHITE, _strip)
	var gx := 870.0
	var shown := [trip.paddle, trip.hat]
	var counts := {}
	for id in trip.bag:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		shown.append(id)
	var room := int((gx - (x + 196) - 44.0) / 34.0)
	for i in mini(shown.size(), room):
		var id := String(shown[i])
		gear_icon(id, Vector2(gx - 34 * (i + 1), 19), 0.5, _strip)
		if int(counts.get(id, 0)) > 1:
			UiKit.text("small", str(counts[id]), Vector2(gx - 34 * i - 2, 30), 1.0, Color.WHITE, _strip)
	if shown.size() > room:
		UiKit.text("small", "+%d" % (shown.size() - room), Vector2(gx - 34 * room - 6, 24), 1.0, DIM, _strip)


## A gear item's icon (the plain paddle has its own), at `scale` of 64 px.
func gear_icon(id: String, at: Vector2, scale: float, parent: Node) -> Sprite2D:
	return TripArt.sprite(TripArt.gear_icon(id), at, scale, parent)


func _info_refresh() -> void:
	var lines: Array = []
	if trip.state == "on" and not _targets.is_empty():
		lines = trip.info(trip.node_for(_targets[cursor]))
		if trip.is_gate() and int(_targets[cursor][0]) == RoadTrip.GATE:
			lines[0] = "AGAIN: " + String(lines[0])
	for k in 3:
		_info[k].text = String(lines[k]) if k < lines.size() else ""


func _draw_roads() -> void:
	var from_home := world_point(0, RoadTrip.START, 0)
	for leg in RoadTrip.LEGS:
		var start := world_point(leg, RoadTrip.START, 0) if leg > 0 else from_home
		for lane in RoadTrip.LANES:
			_dash(start, world_point(leg, 0, lane), ROAD)
		for col in RoadTrip.COLS:
			for lane in RoadTrip.LANES:
				var n: Dictionary = trip.map[leg]["cols"][col][lane]
				var a := world_point(leg, col, lane)
				if col == RoadTrip.COLS - 1:
					_dash(a, world_point(leg, RoadTrip.GATE, 0), ROAD)
				else:
					for e in n["edges"]:
						_dash(a, world_point(leg, col + 1, int(e)), ROAD)
	# the road driven, in red pen
	var prev := from_home
	var prev_leg := 0
	for r in trip.route:
		var p := world_point(int(r[0]), int(r[1]), int(r[2]))
		if int(r[0]) != prev_leg:
			prev = world_point(int(r[0]), RoadTrip.START, 0)
			prev_leg = int(r[0])
		_roads.draw_line(prev, p, DRIVEN, 3.0)
		prev = p


## A printed road: 6 px dashes, 4 px gaps.
func _dash(a: Vector2, b: Vector2, c: Color) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(len, 0.001)
	var t := 0.0
	while t < len:
		_roads.draw_line(a + dir * t, a + dir * minf(t + 6.0, len), c, 2.0)
		t += 10.0


func _draw_cursor() -> void:
	if _targets.is_empty() or _drive > 0 or pick != null or van != null:
		return
	var t: Array = _targets[cursor]
	var p := world_point(trip.leg(), int(t[0]), int(t[1])) + Vector2(0, -24)
	var r := 22.0 + 2.0 * sin(_frame * 0.2)
	_cursor_ring.draw_arc(p, r, 0, TAU, 32, GOLD, 3.0)


# --- Choosing and driving ---------------------------------------------------------

func select(id: String) -> bool:
	for i in _targets.size():
		if target_id(_targets[i]) == id:
			cursor = i
			_moved()
			return true
	return false


func move(d: int) -> void:
	if _targets.is_empty():
		return
	cursor = (cursor + d + _targets.size()) % _targets.size()
	_moved()


func _moved() -> void:
	_info_refresh()
	_cursor_ring.queue_redraw()


## Drives to the chosen stop (the van along the road, then `go`).
func press() -> void:
	if _targets.is_empty() or _drive > 0:
		return
	_beep("confirm")
	var t: Array = _targets[cursor]
	_drive_from = _van.position
	_drive_to = world_point(trip.leg(), int(t[0]), int(t[1])) + Vector2(0, -2)
	_drive = DRIVE_FRAMES if _drive_from.distance_to(_drive_to) > 1.0 else 1
	_cursor_ring.queue_redraw()


## The stop's lines under the map, hidden under a pick or THE VAN.
func _show_info(on: bool) -> void:
	for t in _info:
		t.visible = on


func open_pick() -> void:
	_prompts.visible = false
	_show_info(false)
	pick = TripPick.new().setup(save, trip)
	pick.closed.connect(_on_pick_closed)
	add_child(pick)


func _on_pick_closed() -> void:
	if pick:
		pick.queue_free()
	pick = null
	_prompts.visible = true
	_show_info(true)
	trip.store(save)
	if save:
		save.save_game()
	_lock = LOCK
	refresh()


## THE VAN, over the map: your stats, your gear, the locker.
func open_van() -> void:
	if van or pick or _drive > 0:
		return
	_beep("confirm")
	_prompts.visible = false
	_show_info(false)
	van = TripVan.new().setup(save, trip)
	van.closed.connect(_on_van_closed)
	add_child(van)
	_cursor_ring.queue_redraw()


func _on_van_closed() -> void:
	if van:
		van.queue_free()
	van = null
	_prompts.visible = true
	_show_info(true)

	trip.store(save)
	if save:
		save.save_game()
	_lock = LOCK
	refresh()


func _leave() -> void:
	_beep("back")
	trip.store(save)
	if save:
		save.save_game()
	leave.emit()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % 4 == 0:
		_cursor_ring.queue_redraw()
	var want := _scroll_for(_van.position.x)
	if _drive <= 0 and not _targets.is_empty():
		var t: Array = _targets[cursor]
		want = _scroll_for((_van.position.x + world_point(trip.leg(), int(t[0]), int(t[1])).x) / 2.0)
	scroll = lerpf(scroll, want, 0.12)
	_world.position.x = -roundf(scroll)
	if _drive > 0:
		_drive -= 1
		var k := 1.0 - float(_drive) / DRIVE_FRAMES
		_van.position = _drive_from.lerp(_drive_to, k * k * (3.0 - 2.0 * k))
		_van_frame(1 + (_frame / 4) % 4)
		_van.flip_h = _drive_to.x < _drive_from.x
		if _drive == 0:
			_van_frame(0)
			go.emit(_targets[cursor])
		return
	if pick or van:
		return
	if _lock > 0:
		_lock -= 1
		return
	if Input.is_action_just_pressed("slice"):
		open_van()
		return
	if GameControls.menu_pressed("move_right") or GameControls.menu_pressed("move_down"):
		move(1)
		_beep("blip")
	elif GameControls.menu_pressed("move_left") or GameControls.menu_pressed("move_up"):
		move(-1)
		_beep("blip")
	if Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
		_leave()
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		press()


func _gui_input(event: InputEvent) -> void:
	if pick or van or _drive > 0:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_leave()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var at: Vector2 = event.position - VIEW.position - _world.position
		for i in _targets.size():
			var t: Array = _targets[i]
			var p := world_point(trip.leg(), int(t[0]), int(t[1])) + Vector2(0, -14)
			if at.distance_to(p) < 22.0:
				if i == cursor:
					press()
				else:
					cursor = i
					_moved()
				accept_event()
				return


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
