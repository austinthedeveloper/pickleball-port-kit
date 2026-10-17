## The camera lean (ADR-050/051), display only: the picture leans toward
## the ball. The target is a sixteenth of the ball's distance from the net
## across the screen and an eighth of its distance from the centre line
## (SNES px, capped 8 x 4), scaled by the setting's percent; it eases an
## eighth of the way a frame, at most half a SNES pixel's worth.
class_name CameraLean
extends RefCounted

## Full lean at this density: the SNES 8 x 4 px, times the court's scale.
const MAX := Vector2(22, 10)

var percent := 0                 ## 0 = OFF (the SNES default)
var offset := Vector2.ZERO


func update(ball: SimTypes.Ball) -> Vector2:
	var target := Vector2.ZERO
	if percent > 0 and ball.rally_state == K.BALL_RALLY_LIVE:
		var dx := (ball.x_fp / 16.0 - K.COURT_NET_X) / 16.0
		var dy := (ball.y_fp / 16.0 - K.COURT_CENTERLINE_Y) / 8.0
		target = Vector2(clampf(dx, -8, 8) / 8.0 * MAX.x,
			clampf(dy, -4, 4) / 4.0 * MAX.y) * percent / 100.0
	var step := (target - offset) / 8.0
	var limit := MAX.x / 16.0
	offset += step.limit_length(limit) if step.length() > 0.02 else target - offset
	return offset
