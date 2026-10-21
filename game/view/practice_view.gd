## Practice on screen (ADR-028), read-only: the ball machine on the far
## baseline and the return zone's corners. The machine is the swing-arm cart
## of art/sprites/machine (machine.aseprite): a body, a launcher arm in
## ARM_FRAMES angles and the pivot cap over it. The arm swings smoothly
## toward the sim's pose (up, centre or down: the next feed's lane) instead
## of snapping, and kicks back on a feed (render.c render_machine / render_zone).
class_name PracticeView
extends RefCounted

const SHEET := "res://assets/machine/machine.png"
const CELL := Vector2i(36, 26)   ## art px: cell 0 the body, 1..ARM_FRAMES the arm, then the hub
const ARM_FRAMES := 9            ## up the screen (toward the far sideline) first
const SCALE := 2.0               ## art px to screen px, as the players
const ORIGIN := Vector2(-6, -50) ## the sheet's top-left from the ground under the machine
const ARM_STEP := 0.7            ## arm frames a tick: one pose's sweep about TURN_FRAMES long
const OUTLINE := Color("232831")
const CORNER := Color("fbe46a")
const CORNER_LEN := 16.0


## The machine: origin on the ground under it (y-sorted with the players).
class Machine:
	extends Node2D
	var practice: Practice
	var sheet: Texture2D = load(SHEET)
	var arm := -1.0                  ## the arm frame shown, easing toward the pose's

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	## The arm frame of the sim's pose: UP 0, CENTER the middle, DOWN the last.
	func target() -> float:
		return float(practice.pose * (ARM_FRAMES - 1) / 2)

	func _process(delta: float) -> void:
		var goal := target()
		arm = goal if arm < 0.0 else move_toward(arm, goal, ARM_STEP * delta * 60.0)
		queue_redraw()

	func _cell(i: int, at: Vector2) -> void:
		var src := Rect2(Vector2(CELL.x * i, 0), Vector2(CELL))
		draw_texture_rect_region(sheet, Rect2(ORIGIN + at, Vector2(CELL) * SCALE), src)

	func _draw() -> void:
		var kick := 0.0
		if practice.kick:
			kick = 2.0 if practice.kick > Practice.KICK_FRAMES / 2 else 1.0
		# the cart rocks back a pixel; the arm recoils further, along itself
		var rock := Vector2(SCALE if kick > 0.0 else 0.0, 0)
		var frame := clampi(roundi(arm), 0, ARM_FRAMES - 1)
		var angle := deg_to_rad(32.0 - 8.0 * frame)
		var recoil := Vector2(cos(angle), sin(angle)) * kick * SCALE
		_cell(0, rock)
		_cell(1 + frame, (rock + recoil).round())
		_cell(ARM_FRAMES + 1, rock)


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
	m.position = CourtView.ground(K.to_fp(Practice.MACHINE_X), K.to_fp(Practice.MACHINE_Y)).round()
	return m


static func zone(p: Practice) -> Zone:
	var z := Zone.new()
	z.practice = p
	return z
