## CRT (port ADR-109, PORT-131): OPTIONS > CRT OFF, SOFT or STRONG, a
## filter over the whole picture (view/crt.gdshader) like the TV the box
## art had in mind. Added by main for the session, under the touch pad
## and the caption bar so they stay crisp. Display only: nothing reads it.
## The lite Web build offers SOFT at most (a phone's GPU).
class_name Crt
extends CanvasLayer

const OFF := 0
const SOFT := 1
const STRONG := 2
const NAMES := ["OFF", "SOFT", "STRONG"]
## [scanlines, mask, bloom, vignette] for SOFT and STRONG.
const LOOKS := [[0.0, 0.0, 0.0, 0.0], [0.18, 0.06, 0.10, 0.08], [0.38, 0.16, 0.22, 0.16]]

var rect: ColorRect
var _shown := -1


static func levels() -> int:
	return 2 if Settings.lite else NAMES.size()


func _ready() -> void:
	layer = 89
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = ShaderMaterial.new()
	rect.material.shader = preload("res://view/crt.gdshader")
	add_child(rect)
	apply()


func _process(_delta: float) -> void:
	apply()


## The setting, again if it changed (OPTIONS can change it at any time).
func apply() -> void:
	var level := clampi(Settings.crt_i, 0, levels() - 1)
	if level == _shown:
		return
	_shown = level
	rect.visible = level != OFF
	var l: Array = LOOKS[level]
	for k in 4:
		rect.material.set_shader_parameter(["scan", "mask", "bloom", "vignette"][k], l[k])
