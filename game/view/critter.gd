## A venue's critter (SNES ADR-064): LAKESIDE's gull, SPACE's satellite
## (at half speed) and UNDERSEA's fish cross under the scoreboard, in screen
## space, every 2048 frames of the match. Display only; deterministic (the
## sim's frame count), so screenshots repeat.
class_name Critter
extends Node2D

const PERIOD := 2048
const SPEED := 2.0               ## px a frame (the satellite half)
const Y := 96.0
const INK := Color(0.07, 0.06, 0.12)

const KINDS := {"lakeside": "gull", "space": "satellite", "undersea": "fish"}

var kind := ""
var sim: Sim
var at := Vector2(-100, Y)
var frame := 0


static func for_venue(venue: String, s: Sim) -> Critter:
	if not KINDS.has(venue):
		return null
	var c := Critter.new()
	c.kind = KINDS[venue]
	c.sim = s
	c.z_index = 40
	return c


func speed() -> float:
	return SPEED / 2.0 if kind == "satellite" else SPEED


## Where it is this frame (x off screen between crossings).
func update() -> void:
	frame = sim.frame_count
	var t := float(frame % PERIOD)
	at = Vector2(-60.0 + t * speed(), Y)
	if kind == "fish":
		at.y += sin(t / 14.0) * 6.0
	elif kind == "gull":
		at.y += sin(t / 40.0) * 10.0
	visible = at.x < 1020.0
	queue_redraw()


func _draw() -> void:
	match kind:
		"gull":
			# a white body, grey wings that beat every 8 frames
			var up := (frame >> 3) & 1
			var tip := -12.0 if up else 6.0
			for side in [-1.0, 1.0]:
				var wing := PackedVector2Array([at + Vector2(side * 2, -1),
					at + Vector2(side * 12, tip), at + Vector2(side * 22, tip + 4),
					at + Vector2(side * 11, tip + 5), at + Vector2(side * 3, 3)])
				draw_colored_polygon(wing, Color(0.55, 0.58, 0.64))
				draw_polyline(wing + PackedVector2Array([wing[0]]), INK, 1.5)
			draw_circle(at, 5.0, INK)
			draw_circle(at, 4.0, Color.WHITE)
			draw_circle(at + Vector2(6, -2), 3.5, INK)
			draw_circle(at + Vector2(6, -2), 2.6, Color.WHITE)
			draw_colored_polygon(PackedVector2Array([at + Vector2(8, -3), at + Vector2(13, -1),
				at + Vector2(8, 0)]), Color("f0b030"))
		"satellite":
			# a body, two blue panels, an antenna that blinks
			for side in [-1.0, 1.0]:
				var r := Rect2(at + Vector2(side * 9 - (18 if side < 0 else 0), -6), Vector2(18, 12))
				draw_rect(r.grow(1.5), INK)
				draw_rect(r, Color("3a5cc8"))
				for k in 3:
					draw_line(r.position + Vector2(6 * k + 6, 0), r.position + Vector2(6 * k + 6, 12),
						Color("1c2c70"), 1.0)
			var body := Rect2(at - Vector2(8, 9), Vector2(16, 18))
			draw_rect(body.grow(1.5), INK)
			draw_rect(body, Color(0.78, 0.8, 0.86))
			draw_line(at + Vector2(0, -9), at + Vector2(0, -18), INK, 2.0)
			draw_circle(at + Vector2(0, -19), 2.5, Color("ff5a50") if (frame >> 4) & 1 else INK)
		"fish":
			# an orange fish, its tail flicking
			var flick := 3.0 if (frame >> 3) & 1 else -3.0
			var tail := PackedVector2Array([at + Vector2(-10, 0), at + Vector2(-20, -8 + flick),
				at + Vector2(-20, 8 + flick)])
			draw_colored_polygon(tail, INK)
			draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-1, 0),
				tail[1] + Vector2(1.5, 2), tail[2] + Vector2(1.5, -2)]), Color("f08a30"))
			var pts := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				pts.append(at + Vector2(cos(a) * 13, sin(a) * 8))
			var rim := PackedVector2Array()
			for q in pts:
				rim.append(at + (q - at) * 1.12)
			draw_colored_polygon(rim, INK)
			draw_colored_polygon(pts, Color("f8a040"))
			draw_circle(at + Vector2(6, -2), 2.4, INK)
			draw_circle(at + Vector2(6.6, -2.6), 0.9, Color.WHITE)
