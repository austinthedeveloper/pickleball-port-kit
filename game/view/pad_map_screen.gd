## MAP BUTTONS (port ADR-082): the steps a PadMapper asks, each with the
## pad input that answered it, the one being asked lit, and the keys that
## leave or step back (the pad's own buttons mean nothing yet).
class_name PadMapScreen
extends Node2D

const AREA := Rect2(230, 40, 500, 460)
const ROW_H := 24
const TOP := 150.0

var mapper: PadMapper
var _name: BitmapText
var _labels: Array = []
var _values: Array = []
var _bar: Node2D


func setup(m: PadMapper) -> PadMapScreen:
	mapper = m
	UiKit.panel(AREA, self)
	_bar = Node2D.new()
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	UiKit.text("big_gold", "MAP BUTTONS", Vector2(480, AREA.position.y + 16), 0.5, Color.WHITE, self)
	_name = UiKit.text("small", "", Vector2(480, AREA.position.y + 62), 0.5, MenuPage.DIM, self)
	UiKit.text("small", "PRESS THE BUTTON FOR EACH ONE", Vector2(480, AREA.position.y + 84), 0.5,
		Color.WHITE, self)
	for i in PadMapper.STEPS.size():
		var y := TOP + i * ROW_H
		_labels.append(UiKit.text("small", Bindings.NAMES[PadMapper.STEPS[i][0]],
			Vector2(AREA.position.x + 40, y), 0.0, MenuPage.DIM, self))
		_values.append(UiKit.text("small", "", Vector2(AREA.end.x - 40, y), 1.0, MenuPage.VALUE, self))
	var bar := PromptBar.new().setup([["esc", "CANCEL"], ["bksp", "STEP BACK"]],
		Vector2(480, AREA.end.y - 22))
	add_child(bar)
	return self


func refresh() -> void:
	if mapper == null:
		return
	var n := PadMaps._plain(mapper.pad_name)
	_name.text = n if n.length() <= 28 else n.substr(0, 26).strip_edges() + ".."
	for i in PadMapper.STEPS.size():
		var out: String = PadMaps.SDL_NAMES[PadMapper.STEPS[i][1]]
		var asked := i == mapper.step
		_labels[i].tint = Color.WHITE if asked else MenuPage.DIM
		if mapper.map.has(out):
			_values[i].text = PadMapper.source_name(String(mapper.map[out]))
		elif asked:
			var snes: String = PadMapper.STEPS[i][2]
			_values[i].text = "PRESS " + ("SNES " + snes if snes != Bindings.NAMES[PadMapper.STEPS[i][0]] else snes)
		else:
			_values[i].text = "-"
	_bar.queue_redraw()


func _draw_bar() -> void:
	if mapper == null or mapper.done():
		return
	var r := Rect2(AREA.position.x + 14, TOP + mapper.step * ROW_H - 1, AREA.size.x - 28, ROW_H - 2)
	_bar.draw_rect(r, MenuPage.BAR)
	_bar.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), MenuPage.BAR_EDGE)
