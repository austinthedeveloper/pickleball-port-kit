## The close call's close-up (ADR-041), under the OUT! banner: the line
## and the ground beyond it zoomed 3x from the venue's ground layer (so
## the COURT colours and the time of day follow), the ball dropping in slow
## motion onto its spot with its shadow and one small bounce, its edge as
## far past the line's edge as it landed, and the caption. Display only.
class_name CloseCall
extends Control

const ZOOM := 3.0
const INSET := Rect2(354, 318, 252, 114)
## Half the painted line's width, in screen px (the lines are ~3 px).
const LINE_HALF := 1.5
const DROP_FRAMES := 40
const BOUNCE_FRAMES := 16
const DROP_H := 80.0
const BOUNCE_H := 9.0

var call: Dictionary
var frame := 0
var ball_rest := Vector2.ZERO     ## the ball's centre at rest, in screen px
var line_at := Vector2.ZERO       ## where the line's centre crosses the inset
var _ball: Sprite2D
var _caption: BitmapText
var _ball_r := 0.0
var _shadow: Control
var _clip: Control               ## the inset: the drop shows only inside it


func setup(view: MatchView, c: Dictionary) -> CloseCall:
	call = c
	var b := view.sim.ball
	var line_pt: Vector2
	var px_per_world: float
	var axis := Vector2.RIGHT if c["vertical"] else Vector2.DOWN
	if c["vertical"]:
		var lx := K.COURT_BASELINE_RIGHT if c["out_dir"] > 0 else K.COURT_BASELINE_LEFT
		line_pt = CourtView.ground(K.to_fp(lx), b.y_fp)
		px_per_world = (CourtView.ground(K.to_fp(lx + 1), b.y_fp) - line_pt).length()
	else:
		var ly := K.COURT_SIDELINE_BOTTOM if c["out_dir"] > 0 else K.COURT_SIDELINE_TOP
		line_pt = CourtView.ground(b.x_fp, K.to_fp(ly))
		px_per_world = (CourtView.ground(b.x_fp, K.to_fp(ly + 1)) - line_pt).y
	# the inset shows the source rect around the line, a little toward out
	var src_size := INSET.size / ZOOM
	var dir: Vector2 = axis * c["out_dir"]
	var src_center := line_pt + dir * src_size.x * 0.12 * (1.0 if c["vertical"] else 0.0) \
		+ dir * src_size.y * 0.12 * (0.0 if c["vertical"] else 1.0)
	var src := Rect2(src_center - src_size / 2.0, src_size)
	_clip = Control.new()
	_clip.position = INSET.position
	_clip.size = INSET.size
	_clip.clip_contents = true
	add_child(_clip)
	var ground := Sprite2D.new()
	ground.texture = view._ground.texture
	ground.material = view._ground.material
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = Rect2(src.position - view._ground_origin(), src.size)
	ground.scale = Vector2(ZOOM, ZOOM)
	_clip.add_child(ground)
	var to_inset := func(p: Vector2) -> Vector2:
		return INSET.position + (p - src.position) * ZOOM
	line_at = to_inset.call(line_pt)
	_shadow = Control.new()
	_shadow.position = -INSET.position
	_clip.add_child(_shadow)
	_shadow.draw.connect(_draw_shadow)
	var meta: Dictionary = view.manifest["sprites"]["ball"]
	_ball = Sprite2D.new()
	_ball.texture = load(MatchView.LEVELS + meta["file"])
	_ball.region_enabled = true
	_ball.region_rect = Rect2(0, 0, meta["frame_size"][0], meta["frame_size"][1])
	_ball.scale = Vector2(ZOOM, ZOOM) * 0.9
	_ball_r = meta["frame_size"][0] * 0.9 * ZOOM / 2.0 - 2.0
	_clip.add_child(_ball)
	var dist_px: float = c["dist_fp"] / 16.0 * px_per_world
	ball_rest = line_at + dir * ((LINE_HALF + dist_px) * ZOOM + _ball_r)
	_caption = BitmapText.new()
	_caption.font = "small"
	_caption.align = 0.5
	_caption.text = Replay.caption(c["inches"])
	_caption.tint = Color("fbe46a")
	_caption.position = Vector2(INSET.get_center().x, INSET.end.y + 10)
	add_child(_caption)
	clip_contents = false
	_place()
	return self


func _place() -> void:
	var h := 0.0
	if frame < DROP_FRAMES:
		var t := float(frame) / DROP_FRAMES
		h = DROP_H * (1.0 - t * t)
	elif frame < DROP_FRAMES + BOUNCE_FRAMES:
		var t := float(frame - DROP_FRAMES) / BOUNCE_FRAMES
		h = BOUNCE_H * 4.0 * t * (1.0 - t)
	_ball.position = ball_rest - Vector2(0, h) - INSET.position
	_shadow.queue_redraw()


func update() -> void:
	frame += 1
	_place()


func _draw() -> void:
	draw_rect(INSET.grow(4), Color("1a2240"), false, 5.0)


## The shadow on the spot (over the ground, under the ball), darker as the
## ball comes down; then the inner frame over the zoomed ground's edge.
func _draw_shadow() -> void:
	var h := (ball_rest - INSET.position - _ball.position).y
	var a := clampf(1.0 - h / DROP_H, 0.25, 1.0) * 0.45
	_shadow.draw_set_transform(ball_rest + Vector2(0, _ball_r * 0.8), 0.0, Vector2(1.0, 0.35))
	_shadow.draw_circle(Vector2.ZERO, _ball_r * 0.9, Color(0.04, 0.05, 0.1, a))
	_shadow.draw_set_transform(Vector2.ZERO)
	_shadow.draw_rect(INSET.grow(-1), Color("fbe46a"), false, 2.0)
