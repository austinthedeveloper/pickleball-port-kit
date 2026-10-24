## The PRO SHOP (port ADR-087): four items (the same each visit), a soda
## for a heart and a fix for the hazards waiting, as a MenuPage ("item_<n>",
## "soda", "fix", "leave"); beside it the chosen item's icon, its lines and
## what it does to your stats, and your cash. Buying is the trip's.
class_name TripShop
extends Control

signal leave

const DIR := "res://assets/trip/"
const GOLD := Color("fbe46a")
const LOCK := MenuPage.TRANSITION

var save: SaveGame
var trip: RoadTrip
var stock: Array = []
var page: MenuPage
var _lock := LOCK
var _icon: Sprite2D
var _name: BitmapText
var _lines: Array = []
var _cash: BitmapText
var _sfx: Sfx


func setup(game_save: SaveGame, t: RoadTrip) -> TripShop:
	save = game_save
	trip = t
	stock = t.shop_stock(RoadTrip.meta(game_save))
	return self


func music_track() -> String:
	return "title"


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "trip_scene_pro_shop.webp")
	bg.centered = false
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.4)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var rows := []
	for i in stock.size():
		var id := String(stock[i])
		rows.append({"id": "item_%d" % i, "label": String(RoadTrip.gear(id)["name"]),
			"value": func(): return _price_label(id), "press": func(): _buy(id)})
	rows.append({"id": "soda", "label": "SODA: A HEART BACK", "value": func(): return str(RoadTrip.SODA),
		"press": func(): _result(trip.buy_soda())})
	rows.append({"id": "fix", "label": "FIX THE HAZARDS", "value": func(): return str(RoadTrip.FIX) if not trip.hazards.is_empty() else "",
		"press": func(): _result(trip.buy_fix())})
	rows.append({"id": "leave", "label": "BACK ON THE ROAD", "press": func(): _leave()})
	page = MenuPage.new().setup("shop", "PRO SHOP", rows,
		Rect2(40, 60, 470, 64 + rows.size() * MenuPage.ROW_H + 50), [["hit", "BUY"], ["back", "LEAVE"]])
	add_child(page)
	page.hovered.connect(func(_id): _refresh())
	page.pressed.connect(func(_id): _refresh())
	page.back_requested.connect(_leave)
	UiKit.panel(Rect2(540, 60, 380, 300), self)
	_icon = Sprite2D.new()
	_icon.centered = false
	_icon.position = Vector2(696, 84)
	add_child(_icon)
	_name = UiKit.text("big_gold", "", Vector2(730, 160), 0.5, Color.WHITE, self)
	for k in 3:
		_lines.append(UiKit.text("small", "", Vector2(730, 206 + k * 28), 0.5,
			GOLD if k == 2 else Color.WHITE, self))
	_cash = UiKit.text("small", "", Vector2(730, 318), 0.5, GOLD, self)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_refresh()
	GameControls.clear_latch()


func _price_label(id: String) -> String:
	if not trip.can_take(id):
		return "HAVE IT"
	return str(trip.price(id))


func _buy(id: String) -> void:
	_result(trip.buy(id))


func _result(ok: bool) -> void:
	_beep("confirm" if ok else "back")
	_refresh()


func _leave() -> void:
	_beep("back")
	leave.emit()


func _refresh() -> void:
	page.refresh()
	_cash.text = "CASH %d    HEARTS %d/%d" % [trip.cash, trip.hearts, trip.max_hearts]
	var id := page.current_id()
	_icon.visible = false
	_name.text = ""
	for l in _lines:
		l.text = ""
	if id.begins_with("item_"):
		var gid := String(stock[int(id.trim_prefix("item_"))])
		var g := RoadTrip.gear(gid)
		var icon := int(g["icon"])
		_icon.texture = load(DIR + "trip_gear_icons.png") if icon >= 0 else load(DIR + "trip_paddle_plain.png")
		_icon.region_enabled = icon >= 0
		if icon >= 0:
			_icon.region_rect = Rect2((icon % 8) * 64, (icon / 8) * 64, 64, 64)
		_icon.visible = true
		var nl := TripPick.wrap_name(String(g["name"]))
		_name.text = String(nl[0]) if nl.size() == 1 else String(g["name"])
		if BitmapText.measure("big_gold", _name.text) > 340:
			_name.text = ""
			_lines[0].text = String(g["name"])
		_lines[1].text = String(g["lines"][0])
		_lines[2].text = String(g["lines"][1])
		if _lines[0].text == "":
			_lines[0].text = String(g["rarity"]).to_upper()
	elif id == "soda":
		_lines[0].text = "A COLD ONE FROM THE COOLER."
		_lines[1].text = "ONE HEART BACK."
	elif id == "fix":
		_lines[0].text = "NOTHING TO FIX." if trip.hazards.is_empty() else "LIFTS THE HAZARDS:"
		var names: Array = trip.hazards.map(func(h): return String(RoadTrip.hazard(String(h))["name"]))
		_lines[1].text = ", ".join(names.slice(0, 2))
		_lines[2].text = ", ".join(names.slice(2))


func _process(_delta: float) -> void:
	if _lock > 0:
		_lock -= 1
		return
	var nav := page.drive(false)
	if nav & MenuPage.NAV_MOVED:
		_beep("blip")
		_refresh()
	if nav & MenuPage.NAV_BACK:
		_leave()


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
