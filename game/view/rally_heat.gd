## A long rally heats up (PORT-43), display only: from FIRE_AT shots the
## ball trails flames (and the HUD's RALLY sign burns: hud.gd); from
## FOCUS_AT, and a step darker every FOCUS_STEP shots after, everything
## but the court dims (FocusDim), so the players are in a spotlight. The
## point's end lets it all go. Not in the title's demo, practice or MULTI
## BALL (no one rally there). Deterministic: no randomness, the frame
## count drives the flicker.
class_name RallyHeat
extends Node2D

const FIRE_AT := 10              ## shots: the ball catches fire
const FOCUS_AT := 15             ## shots: the first step of focus
const FOCUS_STEP := 5            ## shots between steps
const FOCUS_ALPHA := 0.13        ## each step's darkness
const FOCUS_MAX := 0.62          ## never black: the crowd stays in sight
const EMBERS := 22               ## the trail's length, in puffs

var view: MatchView
var embers: Array = []           ## [screen position, age]
var _frame := 0


func setup(v: MatchView) -> RallyHeat:
	view = v
	z_index = 2
	return self


## The rally's shots so far (the HUD's count), 0 where heat doesn't apply.
static func rally(v: MatchView) -> int:
	var s := v.sim
	if v.demo or s.config.practice or s.multi_on or s.phase != K.PHASE_LIVE:
		return 0
	return (s.shot_serial - s.rally_start) & 0xff


static func on_fire(shots: int) -> bool:
	return shots >= FIRE_AT


## The focus's darkness for a rally this long.
static func focus_for(shots: int) -> float:
	if shots < FOCUS_AT:
		return 0.0
	var steps := 1 + (shots - FOCUS_AT) / FOCUS_STEP
	return minf(steps * FOCUS_ALPHA, FOCUS_MAX)


## Once per frame: the trail follows a burning ball; the embers die out.
func update() -> void:
	_frame += 1
	var b := view.sim.ball
	var fire := on_fire(rally(view)) and b.rally_state == K.BALL_RALLY_LIVE and view._ball_root.visible
	for e in embers:
		e[1] += 1
	embers = embers.filter(func(e): return e[1] < EMBERS)
	if fire:
		var at := CourtView.air(b.x_fp, b.y_fp, b.z_fp)
		# two puffs a frame, a little apart, jittered by the frame count
		for k in 2:
			var j := Vector2(sin(_frame * 1.7 + k * 2.1), cos(_frame * 2.3 + k)) * 3.0
			embers.append([at + j, k])
	view._ball_sprite.modulate = Color(1.35, 1.05, 0.7) if fire else Color.WHITE
	queue_redraw()


func _draw() -> void:
	for e in embers:
		var t: float = float(e[1]) / EMBERS          # 0 new .. 1 gone
		var col := Color(1.0, 0.95, 0.55).lerp(Color(1.0, 0.45, 0.1), minf(t * 2.0, 1.0)) \
			.lerp(Color(0.6, 0.12, 0.05), maxf(t * 2.0 - 1.0, 0.0))
		col.a = 0.85 * (1.0 - t)
		# embers rise a little as they cool
		draw_circle(e[0] + Vector2(0, -t * 10.0), 6.0 * (1.0 - t * 0.7), col)


## Everything but the court, dimmed: a dark sheet over the backdrop, the
## stands and the surround, with a soft-edged hole the court's shape. It
## sits over the ground layer and under the net, the shadows and the
## players; the front layer (bushes, near fence) dims by its modulate.
class FocusDim:
	extends Node2D

	const MARGIN := 14               ## world px past the lines the light reaches
	const FEATHER := [6, 13, 22]     ## the soft edge's rings, world px further out

	var view: MatchView
	var amount := 0.0                ## 0 none .. FOCUS_MAX
	var _quads: Array = []           ## the court's shape grown by MARGIN, then each FEATHER
	var _front: Array = []           ## [sprite, its own modulate]

	func setup(v: MatchView, z: int) -> FocusDim:
		view = v
		z_index = z
		_quads.append(_quad(MARGIN))
		for f in FEATHER:
			_quads.append(_quad(MARGIN + f))
		return self

	## A layer over the players that dims with the rest (the front bushes
	## and near fence; not the net, which is on the court).
	func dim_too(layer: CanvasItem) -> void:
		_front.append([layer, layer.modulate])

	## The court grown by `m` world px, on the screen: TL, TR, BR, BL.
	static func _quad(m: int) -> PackedVector2Array:
		var l := K.COURT_BASELINE_LEFT - m
		var r := K.COURT_BASELINE_RIGHT + m
		var top := K.COURT_SIDELINE_TOP - m
		var bottom := K.COURT_SIDELINE_BOTTOM + m
		var q := PackedVector2Array()
		for c in [[l, top], [r, top], [r, bottom], [l, bottom]]:
			q.append(CourtView.ground(K.to_fp(c[0]), K.to_fp(c[1])))
		return q

	## Eases toward the rally's darkness: in over half a second, out a
	## little slower as the point ends.
	func update(shots: int) -> void:
		var want := RallyHeat.focus_for(shots)
		amount = lerpf(amount, want, 0.06 if want > amount else 0.035)
		if absf(amount - want) < 0.003:
			amount = want
		visible = amount > 0.0
		var k := 1.0 - amount
		for f in _front:
			var base: Color = f[1]
			f[0].modulate = Color(base.r * k, base.g * k, base.b * k, base.a)
		if visible:
			queue_redraw()

	## The band between two convex quads (outer around inner), as four quads.
	func _band(outer: PackedVector2Array, inner: PackedVector2Array, col: Color) -> void:
		for k in 4:
			var n := (k + 1) % 4
			draw_colored_polygon(PackedVector2Array([outer[k], outer[n], inner[n], inner[k]]), col)

	func _draw() -> void:
		var dark := Color(0.02, 0.02, 0.06, amount)
		var screen := PackedVector2Array([Vector2(-400, -300), Vector2(1360, -300),
			Vector2(1360, 840), Vector2(-400, 840)])
		_band(screen, _quads[_quads.size() - 1], dark)
		# the feather: lighter toward the court
		for i in range(_quads.size() - 1, 0, -1):
			var a: float = amount * float(i) / _quads.size()
			_band(_quads[i], _quads[i - 1], Color(dark, a))
