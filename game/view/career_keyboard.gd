## Typing a career player's name (ADR-047): the arcade keyboard of the
## CAREER page's EDIT view. The name with an empty box per place left
## (the next one yellow), then A-Z, space and "-" in rows of ten, and DEL
## and END. Reads a CareerPage; the title feeds it presses. The mouse
## picks and types a key. Display only.
class_name CareerKeyboard
extends Control

const AREA := Rect2(380, 46, 500, 432)
const PLACE_W := 44.0
const KEY_W := 44.0
const KEY_H := 46.0
const GOLD := Color("fbe46a")
const DIM := Color(0.7, 0.74, 0.85)
const BAR := Color(0.98, 0.86, 0.36, 0.22)

signal typed(key: int)           ## a click on a key

var page: CareerPage
var _letters: Array = []         ## the name's places
var _keys: Array = []            ## per key: BitmapText (DEL and END last)
var _overlay: Node2D
var prompts: PromptBar
var _erase_shown := true


func setup(p: CareerPage) -> CareerKeyboard:
	page = p
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UiKit.panel(AREA, self)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_text("big_gold", "NAME", Vector2(AREA.get_center().x, AREA.position.y + 16), Color.WHITE)
	for i in Career.NAME:
		_letters.append(_text("big", "", _place_center(i) - Vector2(0, 14), Color.WHITE))
	for k in CareerPage.KEYS:
		var label := "DEL" if k == CareerPage.KEY_DEL else ("END" if k == CareerPage.KEY_END
			else CareerPage.KEY_LETTERS[k])
		_keys.append(_text("big" if k < CareerPage.KEY_CHARS else "small", label,
			_key_rect(k).get_center() - Vector2(0, 14 if k < CareerPage.KEY_CHARS else 9), Color.WHITE))
	prompts = PromptBar.new().setup(_prompt_items(), Vector2(AREA.get_center().x, AREA.end.y - 22))
	add_child(prompts)
	refresh()
	return self


func _text(font: String, s: String, at: Vector2, tint: Color) -> BitmapText:
	return UiKit.text(font, s, at, 0.5, tint, self)


func _place_center(i: int) -> Vector2:
	return Vector2(AREA.get_center().x - PLACE_W * (Career.NAME - 1) / 2.0 + i * PLACE_W,
		AREA.position.y + 100)


## A key's box: letters in rows of ten, DEL under the left half, END the right.
func _key_rect(k: int) -> Rect2:
	var top := AREA.position.y + 150
	if k >= CareerPage.KEY_DEL:
		var half := KEY_W * CareerPage.KEY_COLS / 2.0
		var x := AREA.get_center().x - half + (k - CareerPage.KEY_DEL) * half
		return Rect2(x + 8, top + 3 * KEY_H, half - 16, KEY_H - 6)
	var col := k % CareerPage.KEY_COLS
	var row := k / CareerPage.KEY_COLS
	var left := AREA.get_center().x - KEY_W * CareerPage.KEY_COLS / 2.0
	return Rect2(left + col * KEY_W + 2, top + row * KEY_H, KEY_W - 4, KEY_H - 6)


func _prompt_items() -> Array:
	return [["hit", "TYPE"], ["back", "ERASE" if page.cursor else "BACK"], ["start", "DONE"]]


func refresh() -> void:
	if page == null or page.career == null:
		return
	var player: Career.Player = page.career.players[page.slot]
	for i in Career.NAME:
		_letters[i].text = player.name[i] if i < page.cursor else ""
	var picked := page.key()
	for k in _keys.size():
		_keys[k].tint = GOLD if k == picked else (Color.WHITE if k < CareerPage.KEY_CHARS else DIM)
	if _erase_shown != (page.cursor > 0):
		_erase_shown = page.cursor > 0
		prompts.set_items(_prompt_items())
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if page == null or page.career == null:
		return
	# an empty box per place left, the next one yellow
	for i in range(page.cursor, Career.NAME):
		var c := _place_center(i)
		var r := Rect2(c.x - 15, c.y - 14, 30, 30)
		var col := GOLD if i == page.cursor else DIM
		_overlay.draw_rect(r, col, false, 3.0)
	var picked := page.key()
	var pr := _key_rect(picked)
	_overlay.draw_rect(pr, BAR)
	_overlay.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 3)), GOLD)
	# the space key: a box (the font's space is blank)
	var sr := _key_rect(CareerPage.KEY_LETTERS.find(" "))
	var sc := sr.get_center()
	_overlay.draw_rect(Rect2(sc.x - 9, sc.y - 9, 18, 18),
		GOLD if picked == CareerPage.KEY_LETTERS.find(" ") else Color.WHITE, false, 2.0)


func key_at(p: Vector2) -> int:
	for k in CareerPage.KEYS:
		if _key_rect(k).has_point(p):
			return k
	return -1


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var k := key_at(event.position)
		if k >= 0 and k != page.key():
			page.pick_key(k)
			refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := key_at(event.position)
		if k >= 0:
			page.pick_key(k)
			typed.emit(k)
		accept_event()
