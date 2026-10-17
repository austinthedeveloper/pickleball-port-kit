## Close call replay (ADR-041), replay.c: a long rally that ends with the
## ball landing just out earns a close-up of the line during the point
## result. Pure and display only: nothing here touches the sim.
class_name Replay
extends RefCounted

const MIN_SHOTS := 8             ## a long rally, serve included
const MAX_INCHES := 6            ## out by this much or less
## Court scale: 224 px is 44 ft, so a 12.4 pixel is 528 / 3584 inch, about
## 151 / 1024. Only for distances up to NEAR_FP.
const NEAR_FP := 256


static func inches(dist_fp: int) -> int:
	return (((dist_fp & 0xffff) * 151) & 0xffff) >> 10      # u16, as REPLAY_INCHES


## The close call for a point that just ended with the ball at (x, y), or
## {} for none: {vertical (a baseline), out_dir (+1/-1 toward out, on
## screen), dist_fp (past the line), inches}.
static func check(x: int, y: int, shots: int, fault: int) -> Dictionary:
	if fault != K.FAULT_OUT or shots < MIN_SHOTS:
		return {}
	var past_x := 0
	var past_y := 0
	var dir_x := 0
	var dir_y := 0
	# how far past each line: the baselines are x, the sidelines y
	if x < K.to_fp(K.COURT_BASELINE_LEFT):
		past_x = K.to_fp(K.COURT_BASELINE_LEFT) - x
		dir_x = -1
	elif x > K.to_fp(K.COURT_BASELINE_RIGHT):
		past_x = x - K.to_fp(K.COURT_BASELINE_RIGHT)
		dir_x = 1
	if y < K.to_fp(K.COURT_SIDELINE_TOP):
		past_y = K.to_fp(K.COURT_SIDELINE_TOP) - y
		dir_y = -1
	elif y > K.to_fp(K.COURT_SIDELINE_BOTTOM):
		past_y = y - K.to_fp(K.COURT_SIDELINE_BOTTOM)
		dir_y = 1
	# past a corner, the farther line made it out; an out ball short of the
	# net (on its hitter's side) is not a line call
	if dir_x == 0 and dir_y == 0:
		return {}
	var vertical := past_x >= past_y
	var dist := past_x if vertical else past_y
	if dist > NEAR_FP or inches(dist) > MAX_INCHES:
		return {}
	return {"vertical": vertical, "out_dir": dir_x if vertical else dir_y,
		"dist_fp": dist, "inches": inches(dist)}


static func caption(n: int) -> String:
	if n == 0:
		return "OUT BY A HAIR!"
	return "OUT BY 1 INCH!" if n == 1 else "OUT BY %d INCHES!" % n
