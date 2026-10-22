## Three small touches (PORT-66), display only and deterministic (the
## frame count, never randomness), all a few shapes a frame:
## - bounce marks: a scuff where the ball lands, fading over MARK_FRAMES;
## - camera flashes: glints among the crowd at the big moments (a 15, 20,
##   25 or 30-shot rally, PICKLE SMASH, match point, the match won); none
##   with FLASHES off or in the demo;
## - the net shakes when a ball clips the tape and carries over (a net
##   cord), and when one goes into it.
class_name CourtEffects
extends RefCounted

const MARK_FRAMES := 240            ## a scuff fades over four seconds
const MARK_MAX := 12
const MARK_SIZE := Vector2(7, 2.5)  ## the ellipse's radii, screen px
const MARK_ALPHA := 0.22
const FLASH_BURST := 50             ## frames of flashing: a moment
const FLASH_BIG := 110              ## the match won
const FLASH_EVERY := 3              ## a new flash every this many frames
const FLASH_LIFE := 5
const FLASH_CALLS := [15, 20, 25, 30]
const CORD_CLEAR := 3               ## world px over the tape that still clips it
const SHAKE_FRAMES := 24
const SHAKE_PX := 2.0               ## the net's wobble, screen px, at its start

var view: MatchView
var marks: Marks
var flashes: Flashes
var shake := 0                      ## frames of the net's wobble left
var _prev := Vector3.ZERO           ## the ball last frame (world fp), z < 0: none
var _calls := {}                    ## this rally's rally-length flashes made


func setup(v: MatchView, shadows: Node2D, crowd: Crowd) -> CourtEffects:
	view = v
	marks = Marks.new()
	shadows.add_child(marks)
	if crowd:
		flashes = Flashes.new()
		flashes.crowd = crowd
		crowd.add_child(flashes)
	_prev.z = -1
	return self


## The sim's events, as the view takes them.
func on_event(e: Array) -> void:
	var s := view.sim
	match int(e[0]):
		K.EVENT_SERVE:
			_calls = {}
		K.EVENT_BOUNCE:
			marks.add(CourtView.ground(K.to_fp(e[1]), K.to_fp(e[2])))
		K.EVENT_HIT:
			if int(e[3]) >> 4 == K.SHOT_SPECIAL:
				flash(FLASH_BURST)
			var shots: int = (s.shot_serial - s.rally_start) & 0xff
			if shots in FLASH_CALLS and not _calls.has(shots):
				_calls[shots] = true
				flash(FLASH_BURST)
		K.EVENT_FAULT:
			if e[3] == K.FAULT_NET:
				shake = SHAKE_FRAMES
		K.EVENT_POINT:
			if s.team_won(e[3]):
				flash(FLASH_BIG)
			elif s.match_point(0) or s.match_point(1):
				flash(FLASH_BURST)


func flash(frames: int) -> void:
	if flashes and Settings.flashes and not view.demo:
		flashes.left = maxi(flashes.left, frames)


## Once a drawn frame: the net cord, the wobble, and the marks' and
## flashes' clocks.
func update() -> void:
	var b := view.sim.ball
	var now := Vector3(b.x_fp, b.y_fp, b.z_fp)
	if b.active and b.rally_state == K.BALL_RALLY_LIVE:
		if _prev.z >= 0:
			var h = Sim.net_crossing_height(int(_prev.x), int(_prev.z), int(now.x), int(now.z))
			if h != null and h >= K.to_fp(K.COURT_NET_HEIGHT) \
					and h <= K.to_fp(K.COURT_NET_HEIGHT + CORD_CLEAR):
				shake = SHAKE_FRAMES                 # it clipped the tape
				view._sfx.play("net")
		_prev = now
	else:
		_prev.z = -1
	if shake:
		shake -= 1
	marks.tick()
	if flashes:
		flashes.tick()


## The net's offset this frame (the net layer moves by it).
func net_offset() -> Vector2:
	if shake <= 0:
		return Vector2.ZERO
	var t := float(SHAKE_FRAMES - shake)
	return Vector2(0, roundf(SHAKE_PX * sin(t * 1.2) * shake / SHAKE_FRAMES))


## The scuffs, on the ground under the players.
class Marks:
	extends Node2D
	var list: Array = []            ## [at, frames left]

	func add(at: Vector2) -> void:
		list.append([at, MARK_FRAMES])
		if list.size() > MARK_MAX:
			list.pop_front()

	func tick() -> void:
		for m in list:
			m[1] -= 1
		list = list.filter(func(m): return m[1] > 0)
		queue_redraw()

	func _draw() -> void:
		for m in list:
			var a: float = MARK_ALPHA * minf(1.0, float(m[1]) / (MARK_FRAMES / 2.0))
			draw_set_transform(m[0], 0.0, MARK_SIZE / MARK_SIZE.x)
			draw_circle(Vector2.ZERO, MARK_SIZE.x, Color(0, 0, 0, a))
		draw_set_transform(Vector2.ZERO)


## Glints at people's heads in the stands, one every FLASH_EVERY frames
## while a burst lasts, each a little white star for FLASH_LIFE frames.
class Flashes:
	extends Node2D
	var crowd: Crowd
	var left := 0                   ## frames of the burst left
	var lit: Array = []             ## [at, frames left]
	var _n := 0

	func tick() -> void:
		for f in lit:
			f[1] -= 1
		lit = lit.filter(func(f): return f[1] > 0)
		if left > 0:
			left -= 1
			if left % FLASH_EVERY == 0 and not crowd.people.is_empty():
				_n += 1
				var p: Array = crowd.people[(_n * 37 + left * 11) % crowd.people.size()]
				var s: Sprite2D = p[0]
				if s.visible:
					var head: Vector2 = s.position + Vector2(s.region_rect.size.x / 2.0, 4)
					lit.append([head.round(), FLASH_LIFE])
		queue_redraw()

	func _draw() -> void:
		for f in lit:
			var c: Vector2 = f[0]
			var r: float = 2.0 + f[1]
			var col := Color(1, 1, 1, 0.5 + 0.1 * float(f[1]))
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, 1.0)
			draw_line(c - Vector2(0, r), c + Vector2(0, r), col, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
