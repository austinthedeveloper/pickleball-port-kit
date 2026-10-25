## THE VAN (port ADR-092): your trip at a glance, over the map. Your four
## stats as bars of 20, coloured by where each point comes from (the
## GARAGE and the road, gear, sets, the diner's meal), your partner's, and
## a MenuPage: PADDLE and HAT (left and right swap in one from the locker,
## where every paddle and hat you've replaced is kept), BAG and SETS (left
## and right look through them), BACK. Under it the chosen thing's card;
## along the bottom hearts, cash, the trip's seed and HEAT, the hazards
## waiting and the meal. Swapping is the trip's (RoadTrip.equip).
class_name TripVan
extends Control

signal closed

const LOCK := MenuPage.TRANSITION
const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)
const BASE := Color(0.86, 0.88, 0.95)
const SET := Color(0.45, 0.9, 0.4)
const MEAL := Color(1.0, 0.6, 0.35)
const EMPTY := Color(1, 1, 1, 0.12)
const CELL := 12.0
const GAP := 2.0
const BAR_X := 150.0
const YOU_Y := 100.0
const YOU_STEP := 34.0
const PARTNER_Y := 300.0
const PARTNER_STEP := 27.0

var save: SaveGame
var trip: RoadTrip
var page: MenuPage
var bag_i := 0
var set_i := 0
var _lock := LOCK
var _bars: Node2D
var _values: Array = []
var _partner_values: Array = []
var _icon: Sprite2D
var _name: BitmapText
var _lines: Array = []
var _strip: Node2D
var _sfx: Sfx


func setup(game_save: SaveGame, t: RoadTrip) -> TripVan:
	save = game_save
	trip = t
	return self


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Sprite2D.new()
	bg.texture = TripArt.backdrop("van_interior")
	bg.centered = false
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.55 if TripArt.has_backdrop("van_interior") else 0.72)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	UiKit.text("big_gold", "THE VAN", Vector2(480, 8), 0.5, Color.WHITE, self)
	UiKit.panel(Rect2(24, 52, 456, 196), self)
	UiKit.text("small", "YOU", Vector2(44, 64), 0.0, GOLD, self)
	for k in [["GEAR", GOLD, 212.0], ["SETS", SET, 292.0], ["MEAL", MEAL, 372.0]]:
		UiKit.text("small", String(k[0]), Vector2(float(k[2]), 64), 0.0, k[1], self)
	UiKit.panel(Rect2(24, 256, 456, 160), self)
	UiKit.text("small", "PARTNER: " + TripHome.partner_name(trip.partner), Vector2(44, 268), 0.0, GOLD, self)
	for i in 4:
		UiKit.text("small", RoadTrip.STAT_NAMES[i], Vector2(44, YOU_Y + i * YOU_STEP), 0.0, Color.WHITE, self)
		_values.append(UiKit.text("small", "", Vector2(462, YOU_Y + i * YOU_STEP), 1.0, Color.WHITE, self))
		UiKit.text("small", RoadTrip.STAT_NAMES[i], Vector2(44, PARTNER_Y + i * PARTNER_STEP), 0.0, DIM, self)
		_partner_values.append(UiKit.text("small", "", Vector2(462, PARTNER_Y + i * PARTNER_STEP), 1.0, DIM, self))
	_bars = Node2D.new()
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	page = MenuPage.new().setup("van", "", [
		{"id": "paddle", "label": "PADDLE", "value": func(): return _gear_name(trip.paddle),
			"change": func(d): _swap("paddle", d)},
		{"id": "hat", "label": "HAT", "value": func(): return _gear_name(trip.hat),
			"change": func(d): _swap("hat", d)},
		{"id": "bag", "label": "BAG", "value": func(): return _bag_label(),
			"change": func(d): _step_bag(d)},
		{"id": "sets", "label": "SETS", "value": func(): return "%d ON" % trip.active_sets().size(),
			"change": func(d): _step_set(d)},
		{"id": "back", "label": "BACK", "press": func(): close()},
	], Rect2(500, 52, 436, 18 + 5 * MenuPage.ROW_H + 50), [["dpad", "CHANGE"], ["back", "BACK"]])
	add_child(page)
	page.hovered.connect(func(_id): _refresh())
	page.changed.connect(func(_id): _refresh())
	page.back_requested.connect(close)
	UiKit.panel(Rect2(500, 268, 436, 148), self)
	_icon = Sprite2D.new()
	_icon.centered = false
	_icon.position = Vector2(516, 278)
	_icon.scale = Vector2(0.75, 0.75)
	add_child(_icon)
	_name = UiKit.text("small", "", Vector2(576, 292), 0.0, GOLD, self)
	for k in 3:
		_lines.append(UiKit.text("small", "", Vector2(516, 330 + k * 26), 0.0, Color.WHITE if k < 2 else GOLD, self))
	_strip = Node2D.new()
	add_child(_strip)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_refresh()
	GameControls.clear_latch()


# --- What's shown ---------------------------------------------------------------------

static func _gear_name(id: String) -> String:
	return String(RoadTrip.gear(id).get("name", ""))


## The bag's items, one row each (a stacked item once, with its count).
func bag_items() -> Array:
	var out := []
	for id in trip.bag:
		if not out.has(id):
			out.append(String(id))
	return out


func _bag_label() -> String:
	var items := bag_items()
	if items.is_empty():
		return "EMPTY"
	bag_i = clampi(bag_i, 0, items.size() - 1)
	var id := String(items[bag_i])
	var n := trip.bag.count(id)
	return _gear_name(id) + (" X%d" % n if n > 1 else "")


## The sets on show: the ones whose every item can turn up on the road.
func sets_shown() -> Array:
	var pool: Array = RoadTrip.pool(RoadTrip.meta(save)) if save else RoadTrip.data()["start_pool"]
	return RoadTrip.data()["sets"].filter(func(st): return st["items"].all(
		func(id): return pool.has(id) or RoadTrip.gear(String(id))["rarity"] == "start"))


func _swap(kind: String, d: int) -> void:
	var all := trip.choices_of(kind)
	if all.size() < 2:
		return
	trip.equip(String(all[1] if d > 0 else all[all.size() - 1]))
	if d < 0:
		trip.locker.erase(all[0])        # left again goes on back through them
		trip.locker.push_front(all[0])
	_refresh()


func _step_bag(d: int) -> void:
	var n := bag_items().size()
	if n > 0:
		bag_i = (bag_i + d + n) % n
	_refresh()


func _step_set(d: int) -> void:
	var n := sets_shown().size()
	if n > 0:
		set_i = (set_i + d + n) % n
	_refresh()


func _refresh() -> void:
	page.refresh()
	var s := trip.stats(true)
	var p := trip.partner_now()
	for i in 4:
		_values[i].text = str(s[i])
		_partner_values[i].text = str(p[i])
	_bars.queue_redraw()
	_icon.visible = false
	_name.text = ""
	for l in _lines:
		l.text = ""
	match page.current_id():
		"paddle", "hat":
			var kind := page.current_id()
			_show_item(trip.paddle if kind == "paddle" else trip.hat)
			var more := trip.choices_of(kind).size() - 1
			_lines[2].text = "THE LOCKER IS EMPTY." if more == 0 else \
				"%d MORE IN THE LOCKER" % more
		"bag":
			var items := bag_items()
			if items.is_empty():
				_lines[0].text = "NOTHING IN THE BAG YET."
			else:
				var id := String(items[clampi(bag_i, 0, items.size() - 1)])
				_show_item(id)
				var sets := RoadTrip.sets_of(id)
				if not sets.is_empty():
					_lines[2].text = "PART OF " + String(sets[0]["name"])
		"sets":
			var all := sets_shown()
			if all.is_empty():
				_lines[0].text = "NO SETS YET."
			else:
				var st: Dictionary = all[clampi(set_i, 0, all.size() - 1)]
				var on: bool = trip.active_sets().has(st)
				_name.text = String(st["name"]) + (": ON!" if on else ": NOT YET")
				var names: Array = st["items"].map(func(id): return _gear_name(String(id)))
				_lines[0].text = ", ".join(names.slice(0, 2))
				_lines[1].text = ", ".join(names.slice(2))
				_lines[2].text = RoadTrip.bonus_label(st)
				_icon.texture = TripArt.gear_icon(String(st["items"][0]))
				_icon.visible = true
	_strip_refresh()


func _show_item(id: String) -> void:
	var g := RoadTrip.gear(id)
	_icon.texture = TripArt.gear_icon(id)
	_icon.visible = true
	_name.text = String(g["name"])
	_lines[0].text = String(g["lines"][0])
	_lines[1].text = String(g["lines"][1])


## Hearts, cash, the trip's seed and HEAT, the hazards waiting, the meal.
func _strip_refresh() -> void:
	for c in _strip.get_children():
		_strip.remove_child(c)
		c.free()
	UiKit.panel(Rect2(24, 424, 912, 62), _strip)
	var hud: Texture2D = load(TripArt.DIR + "trip_hud_icons.png")
	for i in trip.max_hearts:
		var h := AtlasTexture.new()
		h.atlas = hud
		h.region = Rect2(0 if i < trip.hearts else 24, 0, 24, 24)
		TripArt.sprite(h, Vector2(40 + i * 26, 443), 1.0, _strip)
	var cash := AtlasTexture.new()
	cash.atlas = hud
	cash.region = Rect2(48, 0, 24, 24)
	TripArt.sprite(cash, Vector2(282, 443), 1.0, _strip)
	UiKit.text("small", str(trip.cash), Vector2(310, 445), 0.0, GOLD, _strip)
	var which := "DAY " + RoadTrip.date_label(trip.daily) if trip.daily > 0 else "TRIP %d" % (trip.seed % 10000)
	UiKit.text("small", "%s  HEAT %d" % [which, trip.heat], Vector2(366, 445), 0.0, DIM, _strip)
	for i in mini(4, trip.hazards.size()):
		TripArt.sprite(TripArt.hazard_icon(String(trip.hazards[i])), Vector2(596 + i * 26, 442), 0.375, _strip)
	if trip.meal != "":
		UiKit.text("small", "MEAL " + RoadTrip.bonus_label(RoadTrip.dish(trip.meal)), Vector2(920, 445), 1.0,
			MEAL, _strip)


## The bars: a cell a point, in the colour of where it comes from.
func _draw_bars() -> void:
	var parts := trip.stat_parts()
	var total := trip.stats(true)
	for i in 4:
		var left := int(total[i])
		var segs := []
		for k in [["base", BASE], ["gear", GOLD], ["sets", SET], ["meal", MEAL]]:
			var n := clampi(int(parts[k[0]][i]), 0, left)
			segs.append([n, k[1]])
			left -= n
		if left > 0:
			segs[0][0] += left          # a negative item's points come off the base's count
		_bar(Vector2(BAR_X, YOU_Y + i * YOU_STEP + 3), segs, CELL)
	var own: Array = trip.partner_stats
	var now := trip.partner_now()
	for i in 4:
		var mine := clampi(int(own[i]), 0, int(now[i]))
		_bar(Vector2(BAR_X, PARTNER_Y + i * PARTNER_STEP + 4), [[mine, BASE], [int(now[i]) - mine, GOLD]], 10.0)


func _bar(at: Vector2, segs: Array, h: float) -> void:
	var x := at.x
	var drawn := 0
	for seg in segs:
		for n in int(seg[0]):
			_bars.draw_rect(Rect2(x, at.y, CELL, h), seg[1])
			x += CELL + GAP
			drawn += 1
	for n in RoadTrip.STAT_MAX - drawn:
		_bars.draw_rect(Rect2(x, at.y, CELL, h), EMPTY)
		x += CELL + GAP


func close() -> void:
	_beep("back")
	closed.emit()


func _process(_delta: float) -> void:
	if _lock > 0:
		_lock -= 1
		return
	var nav := page.drive()
	if nav & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
		_beep("blip")
		_refresh()
	if nav & MenuPage.NAV_BACK or Input.is_action_just_pressed("slice"):
		close()


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
