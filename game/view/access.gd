## ACCESSIBILITY's display helpers (port ADR-108, PORT-123/124): the
## COLOURS sets for the players' rings and tags, the shape each player's
## ring carries, colour-vision simulation for the tests, and the
## captions: the announcer's lines (data/captions.json, made from the
## script by tools/make_captions.py) and the sound-only cues.
class_name Access
extends RefCounted

const STANDARD := 0
const DEUTAN := 1
const PROTAN := 2
const TRITAN := 3
const HIGH := 4
const SETS := ["STANDARD", "DEUTAN", "PROTAN", "TRITAN", "HIGH CONTRAST"]
## P1..P4 in each set. STANDARD is the lobby's own; the colour-blind sets
## are from the Okabe-Ito palette, picked to stay apart under that
## deficiency (test_access simulates it); HIGH CONTRAST is pure and bright.
const TINTS := [
	[Color("4aa0ff"), Color("ff5a50"), Color("6ad860"), Color("ffd040")],
	[Color("0072b2"), Color("e69f00"), Color("f0f0f0"), Color("56b4e9")],
	[Color("0072b2"), Color("e69f00"), Color("f0f0f0"), Color("56b4e9")],
	[Color("d55e00"), Color("009e73"), Color("f0f0f0"), Color("cc79a7")],
	[Color("ffffff"), Color("ffff00"), Color("00ffff"), Color("ffa0ff")],
]
## Each player's mark on the ring, in every set (P1 dot, P2 bar, P3
## triangle, P4 square), so colour is never the only difference.
const SHAPES := ["dot", "bar", "triangle", "square"]


static func player_tint(i: int) -> Color:
	var set: Array = TINTS[clampi(Settings.colours_i, 0, TINTS.size() - 1)]
	return set[clampi(i, 0, 3)]


## HIGH CONTRAST's rings carry a thick edge this dark, so a ring stands
## out on a light court (snow, sand) as its bright fill does on a dark one.
const EDGE := Color(0.04, 0.04, 0.06)


static func high_contrast() -> bool:
	return Settings.colours_i == HIGH


## A player's shape, drawn on `n` at `at` (`r` its size) in `col`, with a
## dark edge.
static func draw_shape(n: CanvasItem, player: int, at: Vector2, r: float, col: Color) -> void:
	var edge := Color(0.05, 0.06, 0.1, col.a)
	match SHAPES[clampi(player, 0, 3)]:
		"dot":
			n.draw_circle(at, r + 1.5, edge)
			n.draw_circle(at, r, col)
		"bar":
			n.draw_rect(Rect2(at - Vector2(r * 1.6 + 1.5, r * 0.55 + 1.5), Vector2(r * 3.2 + 3, r * 1.1 + 3)), edge)
			n.draw_rect(Rect2(at - Vector2(r * 1.6, r * 0.55), Vector2(r * 3.2, r * 1.1)), col)
		"triangle":
			var pts := PackedVector2Array([at + Vector2(0, -r * 1.2), at + Vector2(r * 1.2, r * 0.9),
				at + Vector2(-r * 1.2, r * 0.9)])
			var big := PackedVector2Array([at + Vector2(0, -r * 1.2 - 2.5), at + Vector2(r * 1.2 + 2.5, r * 0.9 + 1.5),
				at + Vector2(-r * 1.2 - 2.5, r * 0.9 + 1.5)])
			n.draw_colored_polygon(big, edge)
			n.draw_colored_polygon(pts, col)
		"square":
			n.draw_rect(Rect2(at - Vector2(r + 1.5, r + 1.5), Vector2(r * 2 + 3, r * 2 + 3)), edge)
			n.draw_rect(Rect2(at - Vector2(r, r), Vector2(r * 2, r * 2)), col)


# --- Colour vision (the tests) -------------------------------------------------------

## Machado, Oliveira and Fernandes (2009), severity 1.0, on linear RGB.
const SIM := {
	DEUTAN: [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	PROTAN: [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	TRITAN: [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


## A colour as someone with `kind`'s deficiency sees it (STANDARD and
## HIGH: as it is).
static func simulate(c: Color, kind: int) -> Color:
	if not SIM.has(kind):
		return c
	var m: Array = SIM[kind]
	var lin := c.srgb_to_linear()
	var v := [lin.r, lin.g, lin.b]
	var out := []
	for row: Array in m:
		out.append(clampf(row[0] * v[0] + row[1] * v[1] + row[2] * v[2], 0.0, 1.0))
	return Color(out[0], out[1], out[2], c.a).linear_to_srgb()


## WCAG's contrast ratio between two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## How far apart two colours look: Euclidean in sRGB, 0 to about 1.7.
static func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- Captions (PORT-124) --------------------------------------------------------------

const CAPTIONS := "res://data/captions.json"
## The sounds with no picture of their own, and their words.
const CUES := {"net": "THE NET", "whistle": "WHISTLE", "applause": "APPLAUSE"}
static var _captions := {}


static func captions() -> Dictionary:
	if _captions.is_empty() and FileAccess.file_exists(CAPTIONS):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAPTIONS))
		if d is Dictionary:
			_captions = d["lines"]
	return _captions


static func caption_for(clip: String) -> String:
	return String(captions().get(clip, ""))


## What's being said or heard now, for the caption bar: the text, its
## serial (each new one), its seconds, and whether it's a voice (a cue
## never covers a line being said).
static var caption := ""
static var caption_serial := 0
static var caption_secs := 0.0
static var caption_voice := false


static func say(text: String, seconds: float, voice: bool) -> void:
	if text == "":
		return
	caption = text
	caption_serial += 1
	caption_secs = seconds
	caption_voice = voice


static func cue(effect: String) -> void:
	if CUES.has(effect):
		say(String(CUES[effect]), 1.2, false)
