## Shared UI building blocks: the framed panel and bitmap text every
## screen uses (they were copied into each view file).
class_name UiKit
extends RefCounted

const UI := "res://assets/levels/ui/"
## The small font's ink, outline and drop shadow included: rows 2 to 18 of
## its 20 px cell (y 2 up to 19), so its middle is 10.5 px below the text.
const SMALL_INK := Vector2(2, 19)
## Every panel's group (the touch pad steps aside from them, PORT-81).
const PANELS := "ui_panels"


## A framed panel (panel_<style>.png, 12 px frame) over `rect`, added to
## `parent` if given. Panels never take the mouse.
static func panel(rect: Rect2, parent: Node = null, style := "title") -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(UI + "panel_" + style + ".png")
	n.patch_margin_left = 12
	n.patch_margin_top = 12
	n.patch_margin_right = 12
	n.patch_margin_bottom = 12
	n.position = rect.position
	n.size = rect.size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_to_group(PANELS)
	if parent:
		parent.add_child(n)
	return n


## A highlight bar `h` tall behind a row of small text at `text_y`, from
## `x` across `w`, centred on the letters' ink (the bar's top on a whole px).
static func bar_behind(x: float, w: float, text_y: float, h: float) -> Rect2:
	var mid := (SMALL_INK.x + SMALL_INK.y) / 2.0
	return Rect2(x, text_y + floorf(mid - h / 2.0), w, h)


## Bitmap text: a font (small, big, big_gold), aligned 0 left .. 1 right
## on `at`, tinted, added to `parent` if given.
static func text(font: String, s: String, at: Vector2, align := 0.0, tint := Color.WHITE,
		parent: Node = null) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.text = s
	t.align = align
	t.position = at
	t.tint = tint
	if parent:
		parent.add_child(t)
	return t
