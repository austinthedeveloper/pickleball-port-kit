## Contact punch (product brief: "physical and punchy"), display only:
## a short screen shake on drives and put-aways, a trail behind fast balls,
## squash on the bounce, a whoosh arc on the swing's contact frames, and
## dust when a running player plants. Each effect has its switch in ON.
## Deterministic (no randomness), so screenshots and tests repeat.
class_name Feel
extends Node2D

const ON := {"shake": true, "trail": true, "squash": true, "whoosh": true, "plant_dust": true}

const SHAKE_DRIVE := [3.0, 8]      ## amplitude px, frames
const SHAKE_PUTAWAY := [4.0, 10]
const SHAKE_SMASH := [5.0, 12]     ## the overhead (ADR-053)
const PUTAWAY_Z := 18              ## world px: a contact this high is a put-away
const TRAIL_SPEED := 50            ## |vx| + |vy| (12.4) at or above which a trail shows
const TRAIL_LEN := 6
const SQUASH_FRAMES := 4
const WHOOSH_FRAMES := 6
const PLANT_SPEED := 14            ## 12.4: running faster than this, a stop kicks dust
## SNES ADR-064: a drive squashes the ball at contact, then stretches it in
## flight; drives and slices trail a spin streak until they bounce. Not
## with BIG BALL.
const DRIVE_SQUASH_FRAMES := 3

var view                           ## MatchView (untyped: the classes reference each other)
var shake_frames := 0
var shake_total := 1
var shake_amp := 0.0
var trail: Array = []              ## recent ball screen positions, oldest first
var squash := 0
var spin := -1                     ## the ball's drive or slice, until it bounces
var drive_squash := 0
var whooshes: Array = []           ## [position, facing_left, frames_left]
var _frame := 0
var _prev_state := [0, 0, 0, 0]
var _prev_speed := [0, 0, 0, 0]
var _ball_scale := Vector2.ONE


func setup(v) -> void:
	view = v
	_ball_scale = view._ball_sprite.scale
	z_index = 1


func on_event(e: Array) -> void:
	match e[0]:
		K.EVENT_HIT:
			var shot: int = e[3] >> 4
			if ON["shake"] and Settings.shake_i > 0:
				if shot == K.SHOT_OVERHEAD:
					_shake(SHAKE_SMASH)
				elif view.sim.ball.z_fp >= K.to_fp(PUTAWAY_Z) or (shot == K.SHOT_DRIVE
						and view.sim.ball.z_fp >= K.to_fp(PUTAWAY_Z - 4)):
					_shake(SHAKE_PUTAWAY)
				elif shot == K.SHOT_DRIVE:
					_shake(SHAKE_DRIVE)
			spin = shot if shot == K.SHOT_DRIVE or shot == K.SHOT_SLICE else -1
			if shot == K.SHOT_DRIVE:
				drive_squash = DRIVE_SQUASH_FRAMES
		K.EVENT_SERVE, K.EVENT_POINT:
			spin = -1
		K.EVENT_BOUNCE:
			spin = -1
			if ON["squash"]:
				squash = SQUASH_FRAMES


func _shake(spec: Array) -> void:
	var amp: float = spec[0] * Settings.shake_scale()     # SCREEN SHAKE strength
	if amp >= shake_amp or shake_frames == 0:
		shake_amp = amp
		shake_frames = spec[1]
		shake_total = spec[1]


func update() -> void:
	_frame += 1
	var sim: Sim = view.sim
	# shake: a decaying deterministic wobble of the whole picture (not the HUD)
	if shake_frames > 0:
		shake_frames -= 1
		var k := shake_amp * float(shake_frames) / shake_total
		view.position = Vector2(sin(_frame * 2.3) * k, cos(_frame * 1.9) * k * 0.6).round()
	else:
		view.position = Vector2.ZERO
	# trail behind a fast ball
	var b := sim.ball
	var fast := b.rally_state == K.BALL_RALLY_LIVE and (absi(b.vx_fp) + absi(b.vy_fp) >= TRAIL_SPEED
		or spin >= 0)
	if ON["trail"] and fast and view._ball_root.visible:
		trail.append(CourtView.air(b.x_fp, b.y_fp, b.z_fp).round())
		if trail.size() > TRAIL_LEN:
			trail.pop_front()
	elif trail.size() > 0:
		trail.pop_front()
	# squash on the bounce; a drive's squash at contact, then its stretch
	var big: bool = sim.config.modifiers & K.MOD_BIG_BALL != 0
	if drive_squash > 0 and not big:
		drive_squash -= 1
		view._ball_sprite.scale = _ball_scale * Vector2(0.75, 1.25)
	elif spin == K.SHOT_DRIVE and not big and ON["squash"]:
		view._ball_sprite.scale = _ball_scale * Vector2(1.3, 0.8)
	elif squash > 0:
		squash -= 1
		var t := float(squash) / SQUASH_FRAMES
		view._ball_sprite.scale = _ball_scale * Vector2(1.0 + 0.35 * t, 1.0 - 0.3 * t)
	else:
		view._ball_sprite.scale = _ball_scale
	# whoosh on the swing's first contact frame; dust when a runner plants
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[i]
		if not p.active:
			continue
		var feet := CourtView.ground(p.x_fp, p.y_fp).round()
		var left := p.team == 1
		if ON["whoosh"] and p.state == K.STATE_ACTIVE and _prev_state[i] != K.STATE_ACTIVE:
			whooshes.append([feet + Vector2(-34 if left else 34, -58), left, WHOOSH_FRAMES])
		if ON["plant_dust"] and _prev_state[i] == K.STATE_MOVE and p.state != K.STATE_MOVE \
				and _prev_speed[i] > PLANT_SPEED:
			view._spawn_fx("dust", feet + Vector2(10 if left else -10, 0), 1)
		_prev_state[i] = p.state
		_prev_speed[i] = absi(p.vx_fp) + absi(p.vy_fp)
	for w in whooshes:
		w[2] -= 1
	whooshes = whooshes.filter(func(w): return w[2] > 0)
	queue_redraw()


func _draw() -> void:
	var n := trail.size()
	# a slice's streak is cool white, a drive's warm
	var tint := Color(0.8, 0.9, 1.0) if spin == K.SHOT_SLICE else Color(1.0, 0.97, 0.75)
	for i in n:
		var t := float(i + 1) / (n + 1)
		draw_circle(trail[i], 1.5 + 3.0 * t, Color(tint, 0.25 + 0.5 * t))
	for w in whooshes:
		var a: float = float(w[2]) / WHOOSH_FRAMES
		var start := -PI * 0.75 if not w[1] else -PI * 0.25
		var sweep := PI * 0.9 * (1.0 if not w[1] else -1.0)
		draw_arc(w[0], 26.0, start, start + sweep, 12, Color(1, 1, 1, 0.55 * a), 3.0)
		draw_arc(w[0], 20.0, start, start + sweep * 0.8, 10, Color(1, 1, 1, 0.3 * a), 2.0)
