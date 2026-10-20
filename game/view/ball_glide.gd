## A paced ball, drawn gliding (port ADR-073), display only. When the sim
## paces the ball (BALL SPEED, KID, EASY, FAST BALL, POPCORN) it takes 0,
## 1 or 2 steps a frame, so drawn as it is, it stops still on the 0-step
## frames. This draws it at an even rate instead, at most a step behind:
## between the positions of the last steps the sim took, never ahead.
class_name BallGlide
extends RefCounted

var _hist: Array = []            ## [steps, Vector3i(x_fp, y_fp, z_fp)], oldest first
var _shown := 0.0                ## the step drawn (fractional)


## Where to draw `sim`'s ball this frame (fixed point, as the sim's).
func position(sim: Sim) -> Vector3i:
	var b := sim.ball
	var now := Vector3i(b.x_fp, b.y_fp, b.z_fp)
	var steps := sim.ball_steps
	if not sim.ball_paced or b.rally_state != K.BALL_RALLY_LIVE:
		_reset(steps, now)
		return now
	var last: Array = _hist[-1] if not _hist.is_empty() else []
	if last.is_empty() or steps < int(last[0]) or steps > int(last[0]) + 3:
		_reset(steps, now)                 # a new point, or a jump
		return now
	if steps == int(last[0]):
		if now != last[1]:
			_reset(steps, now)             # moved without a step: placed
			return now
	else:
		_hist.append([steps, now])
		if _hist.size() > 5:
			_hist.pop_front()
	_shown = clampf(_shown + _rate(sim), float(steps) - 1.0, float(steps))
	return _at(_shown, now)


func _reset(steps: int, now: Vector3i) -> void:
	_hist = [[steps, now]]
	_shown = steps


## Steps a frame, on average over the pace's cycle.
static func _rate(sim: Sim) -> float:
	var n := 0
	for k in Sim.BALL_CYCLE:
		n += int(sim.ball_pace[k])
	return float(n) / Sim.BALL_CYCLE


## The position at fractional step `s`: between the steps around it (a
## step the view never saw, two in a frame, is between its neighbours).
func _at(s: float, now: Vector3i) -> Vector3i:
	var lo: Array = []
	var hi: Array = []
	for h in _hist:
		if float(h[0]) <= s:
			lo = h
		elif hi.is_empty():
			hi = h
	if lo.is_empty() or hi.is_empty():
		return now if hi.is_empty() else hi[1]
	var t := (s - float(lo[0])) / float(int(hi[0]) - int(lo[0]))
	var a: Vector3i = lo[1]
	var c: Vector3i = hi[1]
	return Vector3i(roundi(lerpf(a.x, c.x, t)), roundi(lerpf(a.y, c.y, t)), roundi(lerpf(a.z, c.z, t)))
