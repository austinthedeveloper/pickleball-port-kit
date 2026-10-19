## The sprite wish list in play (SNES ADR-064, flair.c in its order),
## display only: driven by the sim's events and state, never written to
## it. At a point's end the winners celebrate (a team's own: thumbs-up,
## flex, en garde; else the cheer) and the losers slump; a loser running
## for a ball that bounced twice past them dives, scrambles up, then
## slumps. Emotes over heads: ! into the net, ? out, sweat for a second
## bounce, anger for a rules fault (with the losers' quip); a star over the
## winner of a long rally; a note over a dink rally's third soft shot; Z's
## over the receivers while a human server takes their time. And the net
## shivers where a ball hits it.
##
## The SNES's frame-budget staging (waking, waiting a frame, lookups a slot
## a frame) has no reason here and is left out; the rules are the same.
class_name Flair
extends Node2D

const DIVE_FRAMES := 12
const SCRAMBLE_END := 24
const CORD_FRAMES := 16          ## the net shivers, alternating every 4
const STAR_RALLY := 8            ## shots in a rally its winners star for
const NOTE_RUN := 3              ## soft shots in a row: a dink rally
const NOTE_FRAMES := 40
const ZZZ_WAIT := 300            ## a human server this slow: the Z's
const HELD := 255                ## an emote held until the phase changes

const REACT_NONE := 0
const REACT_CELEBRATE := 1
const REACT_SLUMP := 2
const REACT_DIVE := 3

const EMOTE_NONE := 0
const EMOTE_EXCLAIM := 1         ## into the net
const EMOTE_QUESTION := 2        ## out
const EMOTE_SWEAT := 3           ## couldn't reach it
const EMOTE_NOTE := 4            ## a dink rally
const EMOTE_STAR := 5            ## won a long rally
const EMOTE_ZZZ := 6             ## waiting on a slow server
const EMOTE_ANGER := 7           ## a rules fault: kitchen, box, volley, lava

const HEAD_Y := -118.0           ## an emote over the feet (the frame's head is ~-108)
const INK := Color(0.07, 0.06, 0.12)
const GOLD := Color("fbe46a")

var sim: Sim
var demo := false
var react := [0, 0, 0, 0]
var celebrate := ["cheer", "cheer", "cheer", "cheer"]
var emote := [0, 0, 0, 0]
var emote_timer := [0, 0, 0, 0]
var result_frames := 0
var rally_shots := 0
var soft_run := 0
var cord_timer := 0
var cord_at := Vector2.ZERO      ## where the net shivers (court screen px)
var _phase := -1
var _last_hit := [-1, -1]        ## each team's last hitter this rally
var _quip_slot := -1             ## the losing player nearest the ball
var _quip_team := -1
var _frame := 0


func setup(s: Sim, is_demo: bool) -> Flair:
	sim = s
	demo = is_demo
	z_index = 2
	begin()
	return self


## At a match's start: the slots' celebrations, nothing up.
func begin() -> void:
	for slot in K.MAX_PLAYERS:
		react[slot] = REACT_NONE
		emote[slot] = EMOTE_NONE
		celebrate[slot] = Opponents.slot_celebrate(sim.config, slot)
	result_frames = 0
	rally_shots = 0
	soft_run = 0
	cord_timer = 0
	_phase = sim.phase
	_last_hit = [-1, -1]
	_quip_slot = -1


func _emote(slot: int, e: int, frames: int) -> void:
	emote[slot] = e
	emote_timer[slot] = frames


## How a lost point looks on the losers' faces.
static func fault_emote(fault: int) -> int:
	if fault == K.FAULT_NET:
		return EMOTE_EXCLAIM
	if fault == K.FAULT_OUT:
		return EMOTE_QUESTION
	if fault == K.FAULT_SECOND_BOUNCE or fault == K.FAULT_NONE:
		return EMOTE_SWEAT
	return EMOTE_ANGER                       # kitchen, box, volley, lava


## The point is over: winners celebrate, losers slump; a loser running for
## a ball that bounced twice past dives for it (the nearest one).
func _point(winner: int, ball_x: int, ball_y: int) -> void:
	var diver := -1
	var nearest := 0x7fff
	var nearest_runner := 0x7fff
	_quip_slot = -1
	for slot in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[slot]
		if not p.active:
			react[slot] = REACT_NONE
			continue
		if p.team == winner:
			react[slot] = REACT_CELEBRATE
			continue
		react[slot] = REACT_SLUMP
		var d := absi(K.from_fp(p.x_fp) - ball_x) + absi(K.from_fp(p.y_fp) - ball_y)
		if d < nearest:
			nearest = d
			_quip_slot = slot
			_quip_team = p.team
		if sim.last_fault != K.FAULT_SECOND_BOUNCE or p.state != K.STATE_MOVE:
			continue
		if d < nearest_runner:
			nearest_runner = d
			diver = slot
	if diver >= 0:
		react[diver] = REACT_DIVE
	if rally_shots >= STAR_RALLY and _last_hit[winner] >= 0:
		_emote(_last_hit[winner], EMOTE_STAR, HELD)
	result_frames = 0
	_phase = K.PHASE_POINT_RESULT       # the emotes just set belong to it


func on_event(e: Array) -> void:
	match e[0]:
		K.EVENT_SERVE:
			var server: int = e[3]
			_last_hit = [-1, -1]
			_last_hit[1 if server >= 2 else 0] = server
			rally_shots = 1
			soft_run = 0
		K.EVENT_HIT:
			rally_shots = mini(rally_shots + 1, 255)
			var shot: int = e[3] >> 4
			var slot: int = e[3] & 3
			_last_hit[1 if slot >= 2 else 0] = slot
			if shot != K.SHOT_SOFT:
				soft_run = 0
			else:
				soft_run += 1
				if soft_run >= NOTE_RUN:
					_emote(slot, EMOTE_NOTE, NOTE_FRAMES)
		K.EVENT_FAULT:
			if e[3] == K.FAULT_NET:
				cord_timer = CORD_FRAMES
				cord_at = CourtView.air(K.to_fp(e[1]), K.to_fp(e[2]), sim.ball.z_fp)
		K.EVENT_POINT:
			_point(e[3], e[1], e[2])


## The side that lost the point says a quip: its player nearest the ball
## (else its first) emotes how they lost it. Only on its own result.
func quip(losing_team: int) -> void:
	if sim.phase != K.PHASE_POINT_RESULT and sim.phase != K.PHASE_MATCH_RESULT:
		return
	var e := fault_emote(sim.last_fault)
	if _quip_slot >= 0 and _quip_team == losing_team:
		_emote(_quip_slot, e, HELD)
		return
	for slot in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[slot]
		if p.active and p.team == losing_team:
			_emote(slot, e, HELD)
			return


## A human serving: their slot plays on a pad or keys (not the bot).
func _human(slot: int) -> bool:
	return sim.config.human[slot] != 0 and not (slot == 0 and sim.p1_bot)


## Z's over the receivers while a human server takes their time.
func _waiting() -> void:
	var server := sim.server_index
	if sim.phase_timer < ZZZ_WAIT or demo or not _human(server):
		return
	var team := 1 if server >= 2 else 0
	for slot in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[slot]
		if p.active and p.team != team and emote[slot] == EMOTE_NONE:
			_emote(slot, EMOTE_ZZZ, HELD)


static func _result(phase: int) -> bool:
	return phase == K.PHASE_POINT_RESULT or phase == K.PHASE_MATCH_RESULT


## Once per frame, after the step and its events.
func tick() -> void:
	_frame += 1
	var phase := sim.phase
	if phase == K.PHASE_SERVE_SETUP:
		_waiting()
	var changed := phase != _phase and not (_result(phase) and _result(_phase))
	_phase = phase
	if cord_timer:
		cord_timer -= 1
	if _result(phase):
		result_frames = mini(result_frames + 1, 255)
	else:
		for slot in K.MAX_PLAYERS:
			react[slot] = REACT_NONE
	for slot in K.MAX_PLAYERS:
		if emote[slot] == EMOTE_NONE:
			continue
		if emote_timer[slot] == HELD:
			if changed:
				emote[slot] = EMOTE_NONE
		else:
			emote_timer[slot] -= 1
			if emote_timer[slot] <= 0:
				emote[slot] = EMOTE_NONE
	queue_redraw()


## A slot's body frame for its point reaction, or "" (the usual one).
func body_frame(slot: int) -> String:
	match react[slot]:
		REACT_CELEBRATE:
			return celebrate[slot]
		REACT_SLUMP:
			return "slump"
		REACT_DIVE:
			if result_frames < DIVE_FRAMES:
				return "dive"
			if result_frames < SCRAMBLE_END:
				return "scramble"
			return "slump"
	return ""


# --- Drawing (in the court's coordinates, under the HUD) ----------------------

func _draw() -> void:
	for slot in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[slot]
		if p.active and emote[slot] != EMOTE_NONE:
			var head := CourtView.ground(p.x_fp, p.y_fp).round() + Vector2(0, HEAD_Y)
			_draw_emote(emote[slot], head + Vector2(0, -2.0 * float((_frame >> 4) & 1)))
	if cord_timer:
		_draw_cord()


func _bubble(at: Vector2) -> void:
	var r := Rect2(at - Vector2(13, 14), Vector2(26, 24))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 9), at + Vector2(4, 9),
		at + Vector2(0, 16)]), INK)
	draw_rect(r.grow(2), INK)
	draw_rect(r, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-2, 9), at + Vector2(2, 9),
		at + Vector2(0, 13)]), Color.WHITE)


func _glyph(ch: String, at: Vector2, tint: Color) -> void:
	var f := BitmapText.load_font("big")
	var g: Dictionary = f["glyphs"].get(ch, f["glyphs"][" "])
	var w: float = g["w"]
	var h: float = g["h"]
	draw_texture_rect_region(f["texture"], Rect2(at - Vector2(w / 2, h / 2 + 2), Vector2(w, h)),
		Rect2(g["x"], g["y"], w, h), tint)


func _star(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + PI * k / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(at + (q - at) * 1.25)
	draw_colored_polygon(outline, INK)
	draw_colored_polygon(pts, col)


func _draw_emote(e: int, at: Vector2) -> void:
	match e:
		EMOTE_EXCLAIM:
			_bubble(at)
			_glyph("!", at, Color("e04040"))
		EMOTE_QUESTION:
			_bubble(at)
			_glyph("?", at, Color("3060d0"))
		EMOTE_ZZZ:
			_glyph("Z", at + Vector2(-8, 6), Color.WHITE)
			_glyph("Z", at + Vector2(2, -4), Color(1, 1, 1, 0.8))
			_glyph("Z", at + Vector2(12, -14), Color(1, 1, 1, 0.6))
		EMOTE_SWEAT:
			var c := at + Vector2(16, 14)
			var drop := PackedVector2Array([c + Vector2(0, -9)])
			for k in 9:
				var a := PI * k / 8.0
				drop.append(c + Vector2(cos(a) * 5, sin(a) * 5))
			var rim := PackedVector2Array()
			for q in drop:
				rim.append(c + (q - c) * 1.35)
			draw_colored_polygon(rim, INK)
			draw_colored_polygon(drop, Color("8fd0ff"))
		EMOTE_ANGER:
			# the cross-vein: four bent strokes round a gap, red
			var c := at + Vector2(14, 4)
			for k in 4:
				var a := PI / 4 + PI / 2 * k
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var stroke := PackedVector2Array([c + d * 5 + n * 8, c + d * 11, c + d * 5 - n * 8])
				draw_polyline(stroke, INK, 8.0)
				draw_polyline(stroke, Color("e83a3a"), 4.0)
		EMOTE_STAR:
			_star(at, 11.0, GOLD)
		EMOTE_NOTE:
			var c := at + Vector2(10, 4)
			draw_line(c + Vector2(4, 0), c + Vector2(4, -20), INK, 4.0)
			draw_line(c + Vector2(4, -20), c + Vector2(11, -14), INK, 4.0)
			draw_circle(c, 6.0, INK)
			draw_circle(c, 4.5, Color.WHITE)
			draw_line(c + Vector2(4, 0), c + Vector2(4, -19), Color.WHITE, 2.0)
			draw_line(c + Vector2(4, -19), c + Vector2(10, -14), Color.WHITE, 2.0)


## The net's cord shivers: a few short white strokes either side of where
## the ball went in, swapping sides every 4 frames.
func _draw_cord() -> void:
	var side := 1.0 if (cord_timer >> 2) & 1 else -1.0
	var a := float(cord_timer) / CORD_FRAMES
	for k in 3:
		var y := cord_at.y - 10 + k * 10
		var x := cord_at.x + side * (6 + k * 2)
		draw_line(Vector2(x, y - 4), Vector2(x + side * 6, y), Color(1, 1, 1, a), 2.0)
		draw_line(Vector2(x, y + 4), Vector2(x + side * 6, y), Color(1, 1, 1, a), 2.0)
