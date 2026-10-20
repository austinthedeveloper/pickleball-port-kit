## Text from the generated bitmap fonts (assets/levels/ui/font_*.png/json):
## per-glyph advance, optional tint of the white fonts (the outline stays
## dark because tinting multiplies).
class_name BitmapText
extends Node2D

const FONT_DIR := "res://assets/levels/ui/"

static var _fonts := {}

@export var font := "big"
# Setting the same value doesn't redraw: screens set their labels every
# frame, and most frames nothing changed.
@export var text := "":
	set(v):
		if v == text:
			return
		text = v
		queue_redraw()
@export var tint := Color.WHITE:
	set(v):
		if v == tint:
			return
		tint = v
		queue_redraw()
## 0 left, 0.5 centred, 1 right on the node's x.
@export var align := 0.0:
	set(v):
		if v == align:
			return
		align = v
		queue_redraw()
var spacing := -1
## Ink on paper: the letters' fill alone, solid in the tint, no outline
## (a dark tint on the outlined fonts runs the fill into the outline).
@export var ink := false:
	set(v):
		ink = v
		material = _ink_material() if v else null

static var _ink: ShaderMaterial


static func _ink_material() -> ShaderMaterial:
	if _ink == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb, tint.a * t.a * step(0.4, t.r));
}"""
		_ink = ShaderMaterial.new()
		_ink.shader = sh
	return _ink


static func load_font(name: String) -> Dictionary:
	if not _fonts.has(name):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONT_DIR + "font_" + name + ".json"))
		meta["texture"] = load(FONT_DIR + "font_" + name + ".png")
		_fonts[name] = meta
	return _fonts[name]


static func measure(font_name: String, s: String, gap := -1) -> int:
	var f := load_font(font_name)
	var w := 0
	for ch in s:
		var g: Dictionary = f["glyphs"].get(ch, f["glyphs"][" "])
		w += int(g["advance"]) + gap
	return maxi(0, w - gap)


func height() -> int:
	return int(load_font(font)["line_height"])


func _draw() -> void:
	if text == "":
		return
	var f := load_font(font)
	var tex: Texture2D = f["texture"]
	var x := -roundf(measure(font, text, spacing) * align)
	for ch in text:
		var g: Dictionary = f["glyphs"].get(ch, f["glyphs"][" "])
		draw_texture_rect_region(tex, Rect2(x, 0, g["w"], g["h"]),
			Rect2(g["x"], g["y"], g["w"], g["h"]), tint)
		x += int(g["advance"]) + spacing
