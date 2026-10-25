## PICK ONE (port ADR-087): the trip's pick on offer as cards (an index
## card in its rarity's colour, the item's icon in the window, its name),
## and under them the chosen card's two lines and what it does to your
## stats. Left and Right choose (cards by id: "card_<n>", select()), HIT
## takes the card, BACK skips it for a little cash, and with a CB RADIO
## the VAN button redraws the cards once a leg (port ADR-092). Over the map.
class_name TripPick
extends Control

signal closed

const DIR := "res://assets/trip/"
const CARD := Vector2(200, 260)
const STEP := 216.0
const TOP := 112.0
const WINDOW := Rect2(62, 50, 80, 80)    ## the card art's window
const NAME_MAX := 12             ## characters a line of the name holds
const LOCK := MenuPage.TRANSITION
const RARITY_CELL := {"common": 0, "uncommon": 1, "rare": 2, "start": 0}
const KINDS := {"bag": "BAG", "paddle": "PADDLE", "hat": "HAT", "partner": "PARTNER", "perk": "RULE"}
const GOLD := Color("fbe46a")
const INK := Color("2a2230")

var save: SaveGame
var trip: RoadTrip
var items: Array = []
var cursor := 0
var _lock := LOCK
var _frame := 0
var _cards: Array = []           ## the cards' nodes
var _desc: Array = []
var _title: BitmapText
var _prompts: PromptBar
var _sfx: Sfx


func setup(game_save: SaveGame, t: RoadTrip) -> TripPick:
	save = game_save
	trip = t
	items = t.pending.get("items", []).duplicate()
	return self


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.72)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_title = UiKit.text("big_gold", "", Vector2(480, 56), 0.5, Color.WHITE, self)
	UiKit.panel(Rect2(80, 392, 800, 92), self)
	for k in 2:
		_desc.append(UiKit.text("small", "", Vector2(480, 408 + k * 28), 0.5, Color.WHITE if k == 0 else GOLD, self))
	_prompts = PromptBar.new().setup([], Vector2(480, 512))
	add_child(_prompts)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_build_cards()


## The cards (again after a redraw), the title and the prompts.
func _build_cards() -> void:
	for c in _cards:
		c.free()
	_cards.clear()
	_title.text = "PICK ONE FOR YOUR BAG" if not items.is_empty() else "NOTHING LEFT TO PICK"
	var help := [["dpad", "CHOOSE"], ["hit", "TAKE"]]
	if trip.can_redraw():
		help.append(["slice", "REDRAW"])
	help.append(["back", "SKIP +%d CASH" % RoadTrip.SKIP_CASH])
	_prompts.set_items(help)
	var tex: Texture2D = load(DIR + "trip_card.png")
	var left := 480.0 - (STEP * (items.size() - 1) + CARD.x) / 2.0
	for i in items.size():
		var id := String(items[i])
		var g := RoadTrip.gear(id)
		var card := Node2D.new()
		card.position = Vector2(left + i * STEP, TOP)
		add_child(card)
		var hole := ColorRect.new()          # the card's window is open: a plain fill behind it
		hole.color = Color("efe6cc")
		hole.position = WINDOW.position
		hole.size = WINDOW.size
		card.add_child(hole)
		var face := Sprite2D.new()
		face.texture = tex
		face.region_enabled = true
		face.region_rect = Rect2(int(RARITY_CELL.get(String(g["rarity"]), 0)) * CARD.x, 0, CARD.x, CARD.y)
		face.centered = false
		card.add_child(face)
		_icon(id, WINDOW.get_center() - Vector2(32, 32), card)
		var name_lines := wrap_name(String(g["name"]))
		for k in name_lines.size():
			var t := UiKit.text("small", String(name_lines[k]), Vector2(CARD.x / 2.0, 140 + k * 24), 0.5, INK, card)
			t.ink = true
		var kind := UiKit.text("small", String(KINDS.get(String(g["kind"]), "")),
			Vector2(CARD.x / 2.0, 214), 0.5, Color(0.42, 0.38, 0.36), card)
		kind.ink = true
		_cards.append(card)
	cursor = clampi(cursor, 0, maxi(0, items.size() - 1))
	_refresh()


## A name over two lines when it's long (at a space).
static func wrap_name(name: String) -> Array:
	if name.length() <= NAME_MAX or not name.contains(" "):
		return [name]
	var cut := name.rfind(" ", NAME_MAX)
	if cut <= 0:
		cut = name.find(" ")
	return [name.substr(0, cut), name.substr(cut + 1)]


func _icon(id: String, at: Vector2, parent: Node) -> void:
	TripArt.sprite(TripArt.gear_icon(id), at, 1.0, parent)


## What taking `id` does to your stats ("POWER 1 TO 6"), a set it makes
## ("SET: GYM RAT!"), or the set it's part of; or "".
func stat_change(id: String) -> String:
	var before := trip.stats()
	var t := RoadTrip.from_dict(trip.to_dict())
	t.take(id)
	var after := t.stats()
	var parts := []
	for i in 4:
		if int(after[i]) != int(before[i]):
			parts.append("%s %d TO %d" % [RoadTrip.STAT_NAMES[i], int(before[i]), int(after[i])])
	if t.max_hearts != trip.max_hearts:
		parts.append("HEARTS %d TO %d" % [trip.max_hearts, t.max_hearts])
	var had: Array = trip.active_sets().map(func(st): return st["id"])
	for st in t.active_sets():
		if not had.has(st["id"]):
			parts.append("SET: %s!" % String(st["name"]))
	if parts.size() < 2:
		for st in RoadTrip.sets_of(id):
			if not t.active_sets().has(st):
				parts.append("PART OF %s" % String(st["name"]))
				break
	return "   ".join(parts)


## The CB RADIO's redraw: new cards, once a leg.
func redraw() -> void:
	if not trip.redraw():
		_beep("back")
		return
	_beep("confirm")
	items = trip.pending["items"].duplicate()
	_build_cards()


func _refresh() -> void:
	for i in _cards.size():
		_cards[i].position.y = TOP - (12.0 if i == cursor else 0.0)
		_cards[i].modulate = Color.WHITE if i == cursor else Color(0.72, 0.74, 0.8)
	if items.is_empty():
		_desc[0].text = ""
		_desc[1].text = ""
		return
	var g := RoadTrip.gear(String(items[cursor]))
	_desc[0].text = " ".join(g["lines"])
	_desc[1].text = stat_change(String(items[cursor]))


func current_id() -> String:
	return "card_%d" % cursor


func select(id: String) -> bool:
	var i := int(id.trim_prefix("card_"))
	if not id.begins_with("card_") or i < 0 or i >= items.size():
		return false
	cursor = i
	_refresh()
	return true


func take() -> void:
	if items.is_empty():
		skip()
		return
	_beep("confirm")
	trip.take(String(items[cursor]))
	closed.emit()


func skip() -> void:
	_beep("back")
	trip.skip_pick()
	closed.emit()


func _process(_delta: float) -> void:
	_frame += 1
	if _lock > 0:
		_lock -= 1
		return
	if GameControls.menu_pressed("move_right") and not items.is_empty():
		cursor = (cursor + 1) % items.size()
		_beep("blip")
		_refresh()
	elif GameControls.menu_pressed("move_left") and not items.is_empty():
		cursor = (cursor - 1 + items.size()) % items.size()
		_beep("blip")
		_refresh()
	if Input.is_action_just_pressed("slice") and trip.can_redraw():
		redraw()
	elif Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
		skip()

	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		take()


func _gui_input(event: InputEvent) -> void:
	if _lock > 0:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			skip()
			accept_event()
			return
		for i in _cards.size():
			if Rect2(_cards[i].position, CARD).has_point(event.position):
				if i == cursor and event.button_index == MOUSE_BUTTON_LEFT:
					take()
				else:
					cursor = i
					_refresh()
				accept_event()
				return
	elif event is InputEventMouseMotion:
		for i in _cards.size():
			if i != cursor and Rect2(_cards[i].position, CARD).has_point(event.position):
				cursor = i
				_refresh()


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
