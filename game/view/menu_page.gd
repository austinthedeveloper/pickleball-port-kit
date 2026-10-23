## One menu page (ADR-025/030, modernised in PORT-11): a panel, an
## optional title, rows, and a highlight bar that eases to the selected
## row. Every settings screen is built from it: the title's pages and the
## pause menu. A row is a Dictionary:
##   id     String, unique on the page (tests select rows by it, §4.8)
##   label  String, or Callable -> String (a label that changes, refreshed)
##   value  Callable -> String (optional: the yellow right-hand column)
##   change Callable(dir: int) (optional: Left/Right; arrows show on it)
##   press  Callable (optional: B/Start; without one, B steps change(+1))
## Pages are driven through move/change/press, never by reading input
## themselves, so a test can jump straight to a row by name. The mouse
## drives the same calls: hover selects, click presses, the wheel
## changes, a right click asks to go back (signals tell the owner).
class_name MenuPage
extends Control

signal pressed(id: String)        ## a click pressed a row
signal changed(id: String)        ## the wheel changed a row
signal hovered(id: String)        ## the mouse moved the selection
signal back_requested             ## a right click

const ROW_H := 28
const DIM := Color(0.7, 0.74, 0.85)
const VALUE := Color("fbe46a")
const BAR := Color(0.98, 0.86, 0.36, 0.22)
const BAR_EDGE := Color(0.98, 0.86, 0.36, 0.9)
## Frames a page takes to slide and fade in (menu input waits this long).
const TRANSITION := 8
const SLIDE := 36.0
const POP_FRAMES := 8

var page_id := ""
var rows: Array = []
var cursor := 0
var area := Rect2(300, 172, 360, 300)
var prompts: PromptBar
var _labels: Array = []
var _values: Array = []
var _top := 0.0
var _bar_y := -1.0
var _pops: Array = []            ## frames left of each value's pop
var _anim := 0                   ## frames left of the transition
var _anim_dir := 1
var _overlay: Node2D             ## the arrows, over the values
var _bar: Node2D                 ## the highlight bar, under the labels
var _title: BitmapText
var _panel: NinePatchRect


func setup(id: String, title: String, page_rows: Array, rect := Rect2(300, 172, 360, 300),
		help: Variant = "") -> MenuPage:
	page_id = id
	rows = page_rows
	area = rect
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UiKit.panel(area, self)
	_bar = Node2D.new()
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_top = area.position.y + 18
	if title != "":
		var t := BitmapText.new()
		t.font = "big_gold"
		t.text = title
		t.align = 0.5
		t.position = Vector2(area.get_center().x, area.position.y + 16)
		add_child(t)
		_title = t
		_top += 46
	for i in rows.size():
		var label := BitmapText.new()
		label.font = "small"
		label.text = _label(i)
		label.position = Vector2(area.position.x + 36, _top + i * ROW_H)
		add_child(label)
		_labels.append(label)
		var value := BitmapText.new()
		value.font = "small"
		value.align = 1.0
		value.position = Vector2(area.end.x - 40, _top + i * ROW_H)
		value.tint = VALUE
		add_child(value)
		_values.append(value)
		_pops.append(0)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_arrows)
	add_child(_overlay)
	var at := Vector2(area.get_center().x, area.end.y - 22)
	if help is Array and not help.is_empty():
		prompts = PromptBar.new().setup(help, at)
		add_child(prompts)
	elif help is String and help != "":
		var h := BitmapText.new()
		h.font = "small"
		h.text = help
		h.align = 0.5
		h.position = at - Vector2(0, 8)
		h.tint = DIM
		add_child(h)
	refresh()
	settle()
	return self


func _label(i: int) -> String:
	var l: Variant = rows[i]["label"]
	return l.call() if l is Callable else String(l)


## Lines of text between the title and the rows (a notice's message): the
## rows, the panel and the prompts move down to make room.
const BODY_H := 22

func set_body(lines: Array, tint := Color.WHITE) -> void:
	var dy := lines.size() * BODY_H + 10
	for i in lines.size():
		UiKit.text("small", String(lines[i]), Vector2(area.get_center().x, _top + i * BODY_H), 0.5,
			tint, self)
	_top += dy
	area.size.y += dy
	_panel.size.y += dy
	for i in rows.size():
		_labels[i].position.y = _row_y(i)
	if prompts:
		prompts.position.y += dy
	settle()


## A page built with a title can change it (a player's name).
func set_title(text: String) -> void:
	if _title:
		_title.text = text


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


## drive()'s results, as bits.
const NAV_MOVED := 1             ## Up or Down moved the cursor
const NAV_CHANGED := 2           ## Left or Right changed the row's value
const NAV_PRESSED := 4           ## HIT or Start ran the row's press
const NAV_BACK := 8              ## SOFT or DRIVE asked to go back
## The row a press in drive() was on (it may move the page on).
var pressed_id := ""


## One frame of the menu keys and pads (the input map's) on this page:
## Up/Down move, Left/Right change, HIT or Start press, SOFT or DRIVE ask
## to go back (the screen decides what back means). Each screen keeps its
## own sounds and follow-ups; the flags say which parts it reads.
func drive(can_change := true, can_back := true, can_press := true) -> int:
	var out := 0
	if GameControls.menu_pressed("move_up"):
		move(-1)
		out |= NAV_MOVED
	elif GameControls.menu_pressed("move_down"):
		move(1)
		out |= NAV_MOVED
	if can_change:
		var dir := 0
		if GameControls.menu_pressed("move_left"):
			dir = -1
		elif GameControls.menu_pressed("move_right"):
			dir = 1
		if dir != 0 and change(dir):
			out |= NAV_CHANGED
	if can_back and (Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive")):
		out |= NAV_BACK
	elif can_press and (Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start")):
		pressed_id = current_id()
		if press():
			out |= NAV_PRESSED
	return out


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
	_pops[cursor] = POP_FRAMES
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
		_labels[i].text = _label(i)
		_labels[i].tint = Color.WHITE if i == cursor else DIM
		_values[i].text = rows[i]["value"].call() if rows[i].has("value") else ""
	_overlay.queue_redraw()


## Slides and fades the page in from `dir` (+1 from the right, -1 from
## the left), over TRANSITION frames.
func appear(dir := 1) -> void:
	_anim = TRANSITION
	_anim_dir = dir
	_apply_anim()


func animating() -> bool:
	return _anim > 0


## Ends every animation at once (tests, and pages built already open).
func settle() -> void:
	_anim = 0
	_bar_y = _row_y(cursor)
	for i in _pops.size():
		_pops[i] = 0
	_step_visuals()
	_apply_anim()


func _row_y(i: int) -> float:
	return _top + i * ROW_H


func _apply_anim() -> void:
	var t := 1.0 - float(_anim) / TRANSITION
	var ease := 1.0 - pow(1.0 - t, 3.0)
	position.x = SLIDE * _anim_dir * (1.0 - ease)
	modulate.a = ease


func _process(_delta: float) -> void:
	if not visible:
		return                          # the title keeps a dozen pages, one shown
	if _anim > 0:
		_anim -= 1
		_apply_anim()
	_step_visuals()


func _step_visuals() -> void:
	var want := _row_y(cursor)
	_bar_y = want if _bar_y < 0.0 or absf(want - _bar_y) < 0.5 else lerpf(_bar_y, want, 0.4)
	for i in _labels.size():
		var x := area.position.x + 36 + (6.0 if i == cursor else 0.0)
		_labels[i].position.x = lerpf(_labels[i].position.x, x, 0.4)
		if _pops[i] > 0:
			_pops[i] -= 1
		var s := 1.0 + 0.25 * float(_pops[i]) / POP_FRAMES
		_values[i].scale = Vector2(s, s)
		_values[i].position.y = _row_y(i) - (s - 1.0) * 8.0
	_bar.queue_redraw()
	_overlay.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(area.position.x + 14, _bar_y - 2, area.size.x - 28, ROW_H - 4)
	_bar.draw_rect(r, BAR)
	_bar.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), BAR_EDGE)


func _draw_arrows() -> void:
	if cursor >= rows.size() or not rows[cursor].has("change"):
		return
	var v: BitmapText = _values[cursor]
	var w := BitmapText.measure("small", v.text)
	var y := _bar_y + 10
	var right := v.position.x + 10
	var left := v.position.x - w - 10
	_overlay.draw_colored_polygon(PackedVector2Array([Vector2(right, y - 5), Vector2(right + 6, y),
		Vector2(right, y + 5)]), VALUE)
	_overlay.draw_colored_polygon(PackedVector2Array([Vector2(left, y - 5), Vector2(left - 6, y),
		Vector2(left, y + 5)]), VALUE)


## The row under a point (page coordinates), or -1.
func row_at(p: Vector2) -> int:
	if p.x < area.position.x or p.x > area.end.x:
		return -1
	var i := int(floor((p.y - (_top - 4)) / ROW_H))
	return i if i >= 0 and i < rows.size() else -1


func _gui_input(event: InputEvent) -> void:
	if not visible or _anim > 0:
		return
	if event is InputEventMouseMotion:
		var i := row_at(event.position)
		if i >= 0 and i != cursor:
			cursor = i
			refresh()
			hovered.emit(current_id())
	elif event is InputEventMouseButton and event.pressed:
		var i := row_at(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if i >= 0:
					cursor = i
					var id := current_id()
					if press():
						pressed.emit(id)
			MOUSE_BUTTON_RIGHT:
				back_requested.emit()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if i >= 0:
					cursor = i
				if change(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1):
					changed.emit(current_id())
		accept_event()
