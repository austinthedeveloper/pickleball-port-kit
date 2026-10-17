## One menu page (ADR-025/030): a panel, an optional title, rows, and a
## cursor. Every settings screen is built from it: the title's pages and
## the pause menu. A row is a Dictionary:
##   id     String, unique on the page (tests select rows by it, §4.8)
##   label  String
##   value  Callable -> String (optional: the yellow right-hand column)
##   change Callable(dir: int) (optional: Left/Right)
##   press  Callable (optional: B/Start; without one, B steps change(+1))
## Pages are driven through move/change/press, never by reading input
## themselves, so a test can jump straight to a row by name.
class_name MenuPage
extends Control

const ROW_H := 30
const DIM := Color(0.7, 0.74, 0.85)
const VALUE := Color("fbe46a")

var page_id := ""
var rows: Array = []
var cursor := 0
var area := Rect2(300, 172, 360, 300)
var _labels: Array = []
var _values: Array = []
var _arrow: Sprite2D
var _top := 0.0


func setup(id: String, title: String, page_rows: Array, rect := Rect2(300, 172, 360, 300),
		help := "") -> MenuPage:
	page_id = id
	rows = page_rows
	area = rect
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 12)
	panel.position = area.position
	panel.size = area.size
	add_child(panel)
	_top = area.position.y + 18
	if title != "":
		var t := BitmapText.new()
		t.font = "big_gold"
		t.text = title
		t.align = 0.5
		t.position = Vector2(area.get_center().x, area.position.y + 16)
		add_child(t)
		_top += 46
	for i in rows.size():
		var label := BitmapText.new()
		label.font = "small"
		label.text = rows[i]["label"]
		label.position = Vector2(area.position.x + 40, _top + i * ROW_H)
		add_child(label)
		_labels.append(label)
		var value := BitmapText.new()
		value.font = "small"
		value.align = 1.0
		value.position = Vector2(area.end.x - 36, _top + i * ROW_H)
		value.tint = VALUE
		add_child(value)
		_values.append(value)
	if help != "":
		var h := BitmapText.new()
		h.font = "small"
		h.text = help
		h.align = 0.5
		h.position = Vector2(area.get_center().x, area.end.y - 30)
		h.tint = DIM
		add_child(h)
	_arrow = Sprite2D.new()
	_arrow.texture = load("res://assets/levels/ui/icon_ball.png")
	_arrow.centered = false
	add_child(_arrow)
	refresh()
	return self


func index_of(id: String) -> int:
	for i in rows.size():
		if rows[i]["id"] == id:
			return i
	return -1


## Puts the cursor on a row by id; false if the page has no such row.
func select(id: String) -> bool:
	var i := index_of(id)
	if i < 0:
		return false
	cursor = i
	refresh()
	return true


func current_id() -> String:
	return rows[cursor]["id"]


func value_of(id: String) -> String:
	var i := index_of(id)
	if i < 0 or not rows[i].has("value"):
		return ""
	return rows[i]["value"].call()


func move(d: int) -> void:
	cursor = (cursor + d + rows.size()) % rows.size()
	refresh()


## Left/Right on the current row; false if it has nothing to change.
func change(dir: int) -> bool:
	var row: Dictionary = rows[cursor]
	if not row.has("change"):
		return false
	row["change"].call(dir)
	refresh()
	return true


## B/Start on the current row; false if it does nothing.
func press() -> bool:
	var row: Dictionary = rows[cursor]
	if row.has("press"):
		row["press"].call()
		refresh()
		return true
	return change(1)


func refresh() -> void:
	for i in rows.size():
		_labels[i].tint = Color.WHITE if i == cursor else DIM
		_values[i].text = rows[i]["value"].call() if rows[i].has("value") else ""
	_arrow.position = Vector2(area.position.x + 18, _top + cursor * ROW_H)
