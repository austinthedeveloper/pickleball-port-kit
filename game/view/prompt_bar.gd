## A row of prompts, centred on a point: [action, "LABEL"] pairs drawn as
## the device's glyph and the label (Prompts). Redraws itself when the
## device or the bindings change.
class_name PromptBar
extends Node2D

const H := 22.0                  ## a round button or the d-pad
const KEY_H := 24.0              ## a key or a pill: the letters' outline and shadow fit
## The small font's ink is rows 2..18 of its 20 px cell (outline and drop
## shadow included): at TEXT_Y that's -9..7, inside a key's top face.
const TEXT_Y := -11.0
const ROUND := ["face", "menu", "view", "dpad"]   ## glyphs H wide and tall; the rest are keys and pills
const LIP := 2.0                 ## a key's dark front edge, under its top face
const GAP := 18.0

## A menu's prompts are buttons on a touch screen (port ADR-117): the
## touch pad presses a tapped prompt's action, so BACK and CONFIRM work
## though the pad's own buttons have stepped aside from the panel.
static var _tappable: Array[int] = []   ## the instance ids of the bars that take taps
## A prompt's action -> the input action a tap presses ("back" is Y).
const TAP_ACTIONS := {"hit": "hit", "drive": "drive", "soft": "soft", "back": "soft",
	"slice": "slice", "start": "start", "short": "short", "special": "special"}
const TAP_PAD := Vector2(8, 9)   ## px around a prompt that still take its tap

var items: Array = []            ## [[action, label], ...]
## Set: its prompts take taps (MenuPage's, Player Select's).
var tappable := false:
	set(v):
		tappable = v
		if v and not get_instance_id() in _tappable:
			_tappable.append(get_instance_id())
		elif not v:
			_tappable.erase(get_instance_id())
		queue_redraw()
## Set: the bar's owner reads its taps itself (tap_at), not the touch pad
## (Player Select: BACK leaves from any row, where the pad's Y steps up one).
var own_taps := false
var tint := Color(0.85, 0.88, 0.95)
var _texts: Array = []
var _layout: Array = []          ## per item: [glyph, glyph rect, its letters or null, label]
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
		remove_child(t)
		t.free()                         # now: a lazy free left the old prompt up a frame
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
		var h := H if w[0]["kind"] in ROUND else KEY_H
		var r := Rect2(x, -h / 2.0, w[1], h)
		var entry := [w[0], r, null, null]
		_layout.append(entry)
		if w[0]["text"] != "":
			# the glyph's letters or key name, over its shape (children draw last)
			var gt := BitmapText.new()
			gt.font = "small"
			gt.text = w[0]["text"]
			gt.align = 0.5
			gt.position = Vector2(r.get_center().x, TEXT_Y)
			add_child(gt)
			_texts.append(gt)
			entry[2] = gt
		x += w[1] + 6
		var t := BitmapText.new()
		t.font = "small"
		t.text = items[i][1]
		t.tint = tint
		t.position = Vector2(x, TEXT_Y)
		add_child(t)
		_texts.append(t)
		entry[3] = t
		x += w[2] + GAP
	queue_redraw()


## Each key or pill's top face (inside its frame, above a key's lip) with
## the letters on it and the label beside it, in the bar's coordinates:
## [[Rect2, BitmapText, BitmapText], ...]. Round buttons and the d-pad are
## left out (no face to sit in).
func key_faces() -> Array:
	var out := []
	for l in _layout:
		var g: Dictionary = l[0]
		if g["kind"] in ["key", "pill"]:
			var r: Rect2 = l[1]
			var lip := LIP if g["kind"] == "key" else 0.0
			out.append([r.grow_individual(-2, -2, -2, -2 - lip), l[2], l[3]])
	return out


## Each tappable prompt's box on the screen and the action a tap presses:
## [[Rect2, action], ...].
func tap_targets() -> Array:
	var out := []
	if not tappable:
		return out
	var xf := get_global_transform()
	for i in mini(_layout.size(), items.size()):
		var action := String(items[i][0])
		if not TAP_ACTIONS.has(action):
			continue
		var r: Rect2 = _layout[i][1]
		var label: BitmapText = _layout[i][3]
		var end := label.position.x + BitmapText.measure("small", label.text)
		var box := Rect2(r.position.x, -KEY_H / 2.0, end - r.position.x, KEY_H)
		box = box.grow_individual(TAP_PAD.x, TAP_PAD.y, TAP_PAD.x, TAP_PAD.y)
		out.append([Rect2(xf * box.position, box.size * xf.get_scale()), TAP_ACTIONS[action]])
	return out


## The action a tappable prompt shown at `p` (on the screen) presses, or "".
static func tapped_at(p: Vector2) -> String:
	for id in _tappable:
		var bar := instance_from_id(id) as PromptBar
		if bar != null and not bar.own_taps and bar.shown():
			var a := bar.tap_at(p)
			if a != "":
				return a
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_tappable.erase(get_instance_id())


## Shown: it and every parent visible (in the tree or not).
func shown() -> bool:
	var n: Node = self
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			return false
		n = n.get_parent()
	return true


## The action a tap at `p` (on the screen) presses, or "".
func tap_at(p: Vector2) -> String:
	for t in tap_targets():
		if (t[0] as Rect2).has_point(p):
			return t[1]
	return ""


func _glyph_width(g: Dictionary) -> float:
	if g["kind"] in ROUND:
		return H
	return BitmapText.measure("small", g["text"]) + 12.0


func _process(_delta: float) -> void:
	if _serial != GameControls.device_serial or _binding_serial != GameControls.binding_serial:
		rebuild()


func _draw() -> void:
	if tappable and GameControls.last_device == GameControls.TOUCH:
		# on a touch screen a menu's prompts are buttons: framed as such
		for i in mini(_layout.size(), items.size()):
			if TAP_ACTIONS.has(String(items[i][0])):
				var r: Rect2 = _layout[i][1]
				var label: BitmapText = _layout[i][3]
				var end := label.position.x + BitmapText.measure("small", label.text)
				var box := Rect2(r.position.x - 5, -KEY_H / 2.0 - 3, end - r.position.x + 10, KEY_H + 6)
				draw_rect(box, Color(0.98, 0.86, 0.36, 0.16))
				draw_rect(box, Color(0.98, 0.86, 0.36, 0.7), false, 1.5)
	for l in _layout:
		var g: Dictionary = l[0]
		var r: Rect2 = l[1]
		var c := r.get_center()
		match g["kind"]:
			"face":
				_round_button(c, g["color"])
				if g.has("shape"):
					_shape(c, g["shape"], g["color"])
			"menu":
				_round_button(c, Color(0.85, 0.87, 0.95))
				for i in 3:
					draw_rect(Rect2(c.x - 5, c.y - 4 + i * 3.5, 10, 1.5), Color(0.92, 0.93, 0.98))
			"view":
				_round_button(c, Color(0.85, 0.87, 0.95))
				draw_rect(Rect2(c.x - 5, c.y - 4, 7, 6), Color(0.92, 0.93, 0.98), false, 1.5)
				draw_rect(Rect2(c.x - 2, c.y - 1, 7, 6), Color(0.92, 0.93, 0.98), false, 1.5)
			"dpad":
				_dpad(c, int(g["dir"]))
			_:
				var pill: bool = g["kind"] == "pill"
				draw_rect(r, Color(0.92, 0.93, 0.98))
				draw_rect(r.grow(-2), Color(0.16, 0.18, 0.3) if pill else Color(0.24, 0.26, 0.38))
				if not pill:
					draw_rect(Rect2(r.position.x + 2, r.end.y - 2 - LIP, r.size.x - 4, LIP), Color(0.1, 0.11, 0.2))


## An Xbox face-style button: dark ring, tinted face, coloured rim.
func _round_button(c: Vector2, col: Color) -> void:
	draw_circle(c, H / 2.0, Color(0.08, 0.09, 0.16))
	draw_circle(c, H / 2.0 - 2.0, col.darkened(0.55))
	draw_arc(c, H / 2.0 - 2.0, 0, TAU, 20, col, 2.0)


## A PlayStation face's shape, in its colour (the font has no such glyphs).
func _shape(c: Vector2, shape: String, col: Color) -> void:
	var s := 4.5
	match shape:
		"cross":
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, 2.0)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 2.0)
		"circle":
			draw_arc(c, s, 0, TAU, 16, col, 2.0)
		"square":
			draw_rect(Rect2(c - Vector2(s, s) * 0.9, Vector2(s, s) * 1.8), col, false, 2.0)
		"triangle":
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.75),
				c + Vector2(-s, s * 0.75), c + Vector2(0, -s)])
			draw_polyline(pts, col, 2.0)


## A D-pad cross; one arm lit for a single direction.
func _dpad(c: Vector2, dir: int) -> void:
	var arm := 6.0
	var w := 6.0
	var base := Color(0.08, 0.09, 0.16)
	draw_rect(Rect2(c.x - w / 2 - 1, c.y - arm - w / 2 - 1, w + 2, arm * 2 + w + 2), base)
	draw_rect(Rect2(c.x - arm - w / 2 - 1, c.y - w / 2 - 1, arm * 2 + w + 2, w + 2), base)
	var face := Color(0.62, 0.65, 0.76)
	draw_rect(Rect2(c.x - w / 2, c.y - arm - w / 2, w, arm * 2 + w), face)
	draw_rect(Rect2(c.x - arm - w / 2, c.y - w / 2, arm * 2 + w, w), face)
	if dir >= 0:
		var lit := Color("fbe46a")
		var off: Vector2 = [Vector2(0, -arm), Vector2(0, arm), Vector2(-arm, 0), Vector2(arm, 0)][dir]
		draw_rect(Rect2(c + off - Vector2(w, w) / 2.0, Vector2(w, w)), lit)
