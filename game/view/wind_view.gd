## WIND (port ADR-065), display only: faint streaks drift across the
## picture the way this serve's wind blows (up or down the screen, across
## the court), none when it's calm. Deterministic, from the sim's frame.
class_name WindView
extends Node2D

const STREAKS := 26
const SPEED := 5.0               ## px a frame along the wind
const LENGTH := 34.0

var sim: Sim
var _frame := 0


func setup(s: Sim) -> WindView:
	sim = s
	z_index = 39
	return self


func update() -> void:
	_frame = sim.frame_count
	visible = sim.ball.wind != 0
	queue_redraw()


func _draw() -> void:
	var dir := float(signi(sim.ball.wind))
	for k in STREAKS:
		# each streak its own lane and phase; it wraps over the screen
		var x := fmod(k * 61.0 + sin(k * 1.7) * 40.0, 960.0)
		var span := 540.0 + LENGTH * 2
		var y := fmod(k * 97.0 + _frame * SPEED * dir * (0.8 + 0.05 * (k % 5)), span)
		if y < 0:
			y += span
		y -= LENGTH
		var sway := sin((_frame + k * 13) / 18.0) * 6.0
		var a := 0.32 + 0.1 * (k % 3)
		draw_line(Vector2(x + sway, y), Vector2(x + sway * 0.5, y - LENGTH * dir), Color(1, 1, 1, a), 2.0)
