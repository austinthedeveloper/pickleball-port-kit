## CAPTIONS (port ADR-108, PORT-124): what the announcer says and the
## sounds with no picture (the net, the whistle, the applause), in a bar
## near the bottom of the screen, under the court and clear of the HUD.
## Added by main for the session; shown only with ACCESSIBILITY >
## CAPTIONS on. A cue never covers a line being said. Display only.
class_name Captions
extends CanvasLayer

const BAR_Y := 436.0                 ## the bar's top (the court ends above it)
const MAX_W := 820.0                 ## a line's most px; a longer caption wraps to two
const LINE_H := 22.0
const VOICE := Color.WHITE
const CUE := Color("fbe46a")

var _panel: NinePatchRect
var _lines: Array = []
var _seen := Access.caption_serial
var _left := 0.0
var _voice := false


func _ready() -> void:
	layer = 95
	_panel = UiKit.panel(Rect2(0, BAR_Y, 100, 40), self, "sub")
	_panel.remove_from_group(UiKit.PANELS)   # the touch pad needn't step aside for it
	for k in 2:
		_lines.append(UiKit.text("small", "", Vector2(480, 0), 0.5, VOICE, self))
	_show("")


func _process(delta: float) -> void:
	tick(delta)


## The clock: a new caption (a cue only if no line is being said), the
## one shown running out.
func tick(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_show("")
	if Access.caption_serial != _seen:
		_seen = Access.caption_serial
		if Settings.captions and (Access.caption_voice or not (_voice and _left > 0.0)):
			_voice = Access.caption_voice
			_left = Access.caption_secs
			_show(Access.caption, VOICE if _voice else CUE)
	if not Settings.captions and visible_text() != "":
		_show("")


## A caption's lines: one, or two split at a space near the middle.
static func wrap_lines(text: String) -> Array:
	if BitmapText.measure("small", text) <= MAX_W:
		return [text]
	var mid := text.length() / 2
	var best := -1
	for i in text.length():
		if text[i] == " " and (best < 0 or absi(i - mid) < absi(best - mid)):
			best = i
	if best < 0:
		return [text]
	return [text.substr(0, best), text.substr(best + 1)]


func _show(text: String, tint := VOICE) -> void:
	var rows: Array = wrap_lines(text) if text != "" else []
	var w := 0.0
	for k in 2:
		var t: BitmapText = _lines[k]
		t.text = String(rows[k]) if k < rows.size() else ""
		t.tint = tint
		t.position = Vector2(480, BAR_Y + 10 + k * LINE_H)
		w = maxf(w, BitmapText.measure("small", t.text))
	_panel.visible = not rows.is_empty()
	_panel.size = Vector2(w + 40.0, 20.0 + rows.size() * LINE_H)
	_panel.position = Vector2(480.0 - _panel.size.x / 2.0, BAR_Y)


func visible_text() -> String:
	return (String(_lines[0].text) + " " + String(_lines[1].text)).strip_edges()
