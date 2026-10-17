## World (sim, SNES ground pixels in 12.4) to screen (960x540), through
## the art's court geometry (art/levels manifest "court"), so the painted
## lines and the called lines are the same lines (ADR-011's split: rules
## flat, picture projected). Presentation only: floats are fine here.
class_name CourtView
extends RefCounted

const CENTER_X := 480.0
const TOP_Y := 222.0
const BOTTOM_Y := 427.0
const TOP_HALF := 266.0
const BOTTOM_HALF := 315.0
## Net tape height on screen at the far and near sidelines (the art's net).
const NET_H_FAR := 24.0
const NET_H_NEAR := 45.0

const WORLD_LEFT := float(K.COURT_BASELINE_LEFT)
const WORLD_LEN := float(K.COURT_BASELINE_RIGHT - K.COURT_BASELINE_LEFT)
const WORLD_TOP := float(K.COURT_SIDELINE_TOP)
const WORLD_DEPTH := float(K.COURT_SIDELINE_BOTTOM - K.COURT_SIDELINE_TOP)


static func uv(x_fp: int, y_fp: int) -> Vector2:
	return Vector2((x_fp / 16.0 - WORLD_LEFT) / WORLD_LEN,
		(y_fp / 16.0 - WORLD_TOP) / WORLD_DEPTH)


static func ground(x_fp: int, y_fp: int) -> Vector2:
	var p := uv(x_fp, y_fp)
	var half := TOP_HALF + p.y * (BOTTOM_HALF - TOP_HALF)
	return Vector2(CENTER_X + (p.x - 0.5) * 2.0 * half, TOP_Y + p.y * (BOTTOM_Y - TOP_Y))


## Screen pixels per world pixel of height at this depth: the net (12 world
## px) is exactly the art's tape height on every row.
static func z_scale(y_fp: int) -> float:
	var v := uv(0, y_fp).y
	return lerpf(NET_H_FAR, NET_H_NEAR, v) / float(K.COURT_NET_HEIGHT)


static func air(x_fp: int, y_fp: int, z_fp: int) -> Vector2:
	return ground(x_fp, y_fp) - Vector2(0, z_fp / 16.0 * z_scale(y_fp))
