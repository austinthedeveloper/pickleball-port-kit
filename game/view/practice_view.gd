## Practice on screen (ADR-028), read-only: the ball machine on the far
## baseline and the return zone's corners. art/levels has no machine, so
## both are drawn here: a grey body with a hopper of yellow balls, wheels,
## and a nozzle that turns up, centre, or down toward the next feed's lane
## and kicks back on a feed (render.c render_machine / render_zone).
class_name PracticeView
extends RefCounted

## SNES px to screen px at the machine's depth (the court's scale there).
const S := 2.6
const BODY := Color("9aa3ad")
const BODY_DARK := Color("6b737e")
const OUTLINE := Color("232831")
const HOPPER := Color("4d5560")
const BALL := Color("f0e048")
const CORNER := Color("fbe46a")
const CORNER_LEN := 16.0


## The machine: origin on the ground under it (y-sorted with the players).
class Machine:
	extends Node2D
	var practice: Practice

	func _process(_delta: float) -> void:
		queue_redraw()

	func _r(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(x * S, y * S, w * S, h * S)

	func _draw() -> void:
		var kick := 0.0
		if practice.kick:
			kick = 2.0 if practice.kick > Practice.KICK_FRAMES / 2 else 1.0
		var o := Vector2(kick * S, 0)
		draw_set_transform(o)
		# Shadow, wheels, body, hopper with balls.
		draw_rect(Rect2(0.5 * S, -1.5 * S, 14 * S, 2 * S), Color(0, 0, 0, 0.28))
		for wx in [3.5, 11.5]:
			draw_circle(Vector2(wx * S, -2 * S), 2.2 * S, OUTLINE)
			draw_circle(Vector2(wx * S, -2 * S), 1.1 * S, BODY_DARK)
		draw_rect(_r(1.5, -11.5, 13, 8.5), OUTLINE)
		draw_rect(_r(2, -11, 12, 7.5), BODY)
		draw_rect(_r(2, -5.5, 12, 2), BODY_DARK)
		var hopper := PackedVector2Array([Vector2(3 * S, -11 * S), Vector2(13 * S, -11 * S),
			Vector2(15 * S, -16 * S), Vector2(1 * S, -16 * S)])
		draw_colored_polygon(hopper, HOPPER)
		draw_polyline(hopper + PackedVector2Array([hopper[0]]), OUTLINE, 2.0)
		for b in [[4, -14.6], [7, -15], [10, -14.7], [13, -14.4], [5.5, -12.6], [8.6, -12.8], [11.6, -12.5]]:
			draw_circle(Vector2(b[0] * S, b[1] * S), 1.25 * S, BALL)
		# The nozzle: from the body's left side toward P1, tilted to the lane
		# (up = toward the far sideline, up the screen).
		var tilt: float = [-2.5, 0.0, 2.0][practice.pose]
		var base := Vector2(2 * S, -8 * S)
		var tip := Vector2(-1.5 * S, (-8 + tilt) * S)
		draw_line(base, tip, OUTLINE, 3.6 * S)
		draw_line(base, tip, BODY_DARK, 2.4 * S)
		draw_circle(tip, 1.3 * S, OUTLINE)
		draw_set_transform(Vector2.ZERO)


## The return zone's corners on the ground: hidden on ANY, and blinking
## for 32 frames after a return lands in.
class Zone:
	extends Node2D
	var practice: Practice

	func _process(_delta: float) -> void:
		queue_redraw()

	func _p(x: int, y: int) -> Vector2:
		return CourtView.ground(K.to_fp(x), K.to_fp(y))

	func _draw() -> void:
		if practice.zone == Practice.ZONE_ANY or (practice.zone_flash & 4):
			return
		var r: Array = Practice.ZONE_RECTS[practice.zone]
		var corners := [_p(r[0], r[1]), _p(r[2], r[1]), _p(r[2], r[3]), _p(r[0], r[3])]
		for i in 4:
			var c: Vector2 = corners[i]
			var along: Vector2 = (corners[(i + 1) % 4] - c).normalized() * CORNER_LEN
			var back: Vector2 = (corners[(i + 3) % 4] - c).normalized() * CORNER_LEN
			draw_polyline(PackedVector2Array([c + along, c, c + back]), OUTLINE, 6.0)
			draw_polyline(PackedVector2Array([c + along, c, c + back]), CORNER, 3.0)


static func machine(p: Practice) -> Machine:
	var m := Machine.new()
	m.practice = p
	m.position = CourtView.ground(K.to_fp(Practice.MACHINE_X), K.to_fp(Practice.MACHINE_Y)).round() \
		- Vector2(S, 0)
	return m


static func zone(p: Practice) -> Zone:
	var z := Zone.new()
	z.practice = p
	return z
