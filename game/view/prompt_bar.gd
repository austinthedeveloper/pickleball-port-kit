## A row of prompts, centred on a point: [action, "LABEL"] pairs drawn as
## the device's glyph and the label (Prompts). Redraws itself when the
## device or the bindings change.
class_name PromptBar
extends Node2D

const H := 22.0
const GAP := 18.0

var items: Array = []            ## [[action, label], ...]
var tint := Color(0.85, 0.88, 0.95)
var _texts: Array = []
var _layout: Array = []          ## per item: [glyph, glyph rect]
var _serial := -1
var _binding_serial := -1


func setup(entries: Array, at: Vector2) -> PromptBar:
	items = entries
	position = at
	rebuild()
	return self


func set_items(entries: Array) -> void:
	items = entries
	rebuild()


func rebuild() -> void:
	_serial = GameControls.device_serial
	_binding_serial = GameControls.binding_serial
	for t in _texts:
		t.queue_free()
	_texts.clear()
	_layout.clear()
	var widths := []
	var total := 0.0
	for it in items:
		var g := Prompts.glyph(it[0])
		var gw := _glyph_width(g)
		var lw := BitmapText.measure("small", it[1])
		widths.append([g, gw, lw])
		total += gw + 6 + lw
	total += GAP * maxi(items.size() - 1, 0)
	var x := -total / 2.0
	for i in items.size():
		var w: Array = widths[i]
		var r := Rect2(x, -H / 2.0, w[1], H)
		_layout.append([w[0], r])
		if w[0]["text"] != "":
			# the glyph's letters or key name, over its shape (children draw last)
			var gt := BitmapText.new()
			gt.font = "small"
			gt.text = w[0]["text"]
			gt.align = 0.5
			gt.position = Vector2(r.get_center().x, r.position.y + 3)
			add_child(gt)
			_texts.append(gt)
		x += w[1] + 6
		var t := BitmapText.new()
		t.font = "small"
		t.text = items[i][1]
		t.tint = tint
		t.position = Vector2(x, -8)
		add_child(t)
		_texts.append(t)
		x += w[2] + GAP
	queue_redraw()


func _glyph_width(g: Dictionary) -> float:
	if g["kind"] == "face":
		return H
	return BitmapText.measure("small", g["text"]) + 12.0


func _ready() -> void:
	rebuild()                        # the input map may not have existed at setup


func _process(_delta: float) -> void:
	if _serial != GameControls.device_serial or _binding_serial != GameControls.binding_serial:
		rebuild()


func _draw() -> void:
	for l in _layout:
		var g: Dictionary = l[0]
		var r: Rect2 = l[1]
		match g["kind"]:
			"face":
				var c := r.get_center()
				draw_circle(c, H / 2.0, Color(0.08, 0.09, 0.16))
				draw_circle(c, H / 2.0 - 2.0, g["color"].darkened(0.55))
				draw_arc(c, H / 2.0 - 2.0, 0, TAU, 20, g["color"], 2.0)
				if g["text"] == "":
					_shape(g["shape"], c, g["color"])
			_:
				var pill: bool = g["kind"] == "pill"
				draw_rect(r, Color(0.92, 0.93, 0.98))
				draw_rect(r.grow(-2), Color(0.16, 0.18, 0.3) if pill else Color(0.24, 0.26, 0.38))
				if not pill:
					draw_rect(Rect2(r.position.x + 2, r.end.y - 5, r.size.x - 4, 3), Color(0.1, 0.11, 0.2))


func _shape(shape: String, c: Vector2, col: Color) -> void:
	var r := 5.0
	match shape:
		"cross":
			draw_line(c - Vector2(r, r), c + Vector2(r, r), col, 2.0)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 2.0)
		"circle":
			draw_arc(c, r, 0, TAU, 16, col, 2.0)
		"square":
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2), col, false, 2.0)
		"triangle":
			draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8),
				c + Vector2(-r, r * 0.8), c + Vector2(0, -r)]), col, 2.0)
