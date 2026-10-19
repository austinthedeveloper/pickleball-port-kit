## MULTI BALL (port ADR-067), port-only and out of gd so the sim keeps
## the C's shape: several balls, no serving. Each ball keeps the rally
## state the ROM's code keeps for its one ball; a frame swaps each into the
## sim's single-ball fields, runs the unchanged hit, rules and physics code
## on it, and swaps it out. Off, nothing here runs and the traces are the
## ROM's. Pure, like the sim: ints only, no Nodes.
class_name MultiBallPlay
extends RefCounted

var sim: Sim


func _init(owner_sim: Sim) -> void:
	sim = owner_sim

## One ball in play and its rally state.
class Entry:
	var ball: SimTypes.Ball
	var required_bounce := K.REQUIRED_BOUNCE_SERVE
	var landing_pending := 0
	var contact_volley := 0
	var shot_serial := 0
	var ball_steps := 0
	var serve_team := 0              ## as if this side had served it
	var blink := K.MULTI_BLINK       ## frames left at the net before it flies
	var dead := false
	var id := 0                      ## its launch number this match

var balls: Array = []                ## Entry, oldest first
var timer := 0                       ## frames to the next ball
var launched := 0                    ## balls so far this match
var serve_team_now := 0              ## the swapped-in ball's serve_team
var idle := SimTypes.Ball.new()      ## ball while none is in play
var ai_ball := [-1, -1, -1, -1]      ## the ball each slot plays (its id)
var serving := 0                     ## serving_team outside a swap

## The match opens: everyone at their serve spots, live at once, the first
## ball at the net.
func begin() -> void:
	sim.serve_setup(0)
	for p in sim.players:
		p.frozen = 0
		p.pose = K.POSE_NONE
	balls = []
	timer = 0
	launched = 0
	ai_ball = [-1, -1, -1, -1]
	idle = SimTypes.Ball.new()
	idle.set_physics(sim.ball)
	sim.ball = idle
	sim.required_bounce = K.REQUIRED_BOUNCE_NONE
	sim.set_phase(K.PHASE_LIVE)

func swap_in(m: Entry) -> void:
	sim.ball = m.ball
	sim.required_bounce = m.required_bounce
	sim.landing_pending = m.landing_pending
	sim.contact_volley = m.contact_volley
	sim.shot_serial = m.shot_serial
	sim.ball_steps = m.ball_steps
	serve_team_now = m.serve_team
	sim.serving_team = m.serve_team      # the AI's return rule reads it

func swap_out(m: Entry) -> void:
	m.required_bounce = sim.required_bounce
	m.landing_pending = sim.landing_pending
	m.contact_volley = sim.contact_volley
	m.shot_serial = sim.shot_serial
	m.ball_steps = sim.ball_steps

## A new ball at the net: it shoots to each side in turn (the left first),
## landing mid-court in a lane of its own, as if served from the far side.
func spawn() -> void:
	var m := Entry.new()
	m.ball = SimTypes.Ball.new()
	m.ball.set_physics(idle)
	m.ball.active = 1
	m.ball.x_fp = K.to_fp(K.COURT_NET_X)
	m.ball.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	m.ball.z_fp = K.to_fp(K.MULTI_START_Z)
	m.ball.rally_state = K.BALL_RALLY_INACTIVE
	var side := launched & 1
	m.serve_team = side ^ 1
	m.shot_serial = launched & 0xff
	m.id = launched
	m.ball.last_hitter = 2 if m.serve_team else 0
	launched += 1
	balls.append(m)

func launch_ball(m: Entry) -> void:
	var side := m.serve_team ^ 1
	var lane: int = K.MULTI_LANES[(launched - 1) % K.MULTI_LANES.size()]
	var tx := K.COURT_NET_X - K.MULTI_DEPTH if side == 0 else K.COURT_NET_X + K.MULTI_DEPTH
	m.ball.rally_state = K.BALL_RALLY_LIVE
	Sim.launch(m.ball, tx, K.COURT_CENTERLINE_Y + lane, K.MULTI_FLIGHT)
	sim.emit(K.EVENT_SERVE, K.COURT_NET_X, K.COURT_CENTERLINE_Y, 2 if m.serve_team else 0)

## A ball died: its point, by the usual rules for whoever hit it last; the
## match can end with balls still in the air.
func point(losing_team: int, fault: int) -> void:
	var winner := 1 - losing_team
	sim.point_winner = winner
	sim.last_fault = fault
	sim.team_score[winner] += 1
	if fault != K.FAULT_SECOND_BOUNCE and fault != K.FAULT_NONE:
		sim.emit(K.EVENT_FAULT, K.from_fp(sim.ball.x_fp), K.from_fp(sim.ball.y_fp), fault)
	sim.emit(K.EVENT_POINT, K.from_fp(sim.ball.x_fp), K.from_fp(sim.ball.y_fp), winner)
	sim.required_bounce = K.REQUIRED_BOUNCE_NONE
	sim.landing_pending = 0
	sim.ball.rally_state = K.BALL_RALLY_INACTIVE
	sim.ball.active = 0
	sim.ball.vx_fp = 0
	sim.ball.vy_fp = 0
	sim.ball.vz_fp = 0
	for m: Entry in balls:
		if m.ball == sim.ball:
			m.dead = true
	if sim.score_wins(sim.team_score[winner], sim.team_score[winner ^ 1]):
		sim.match_winner = winner
		sim.set_phase(K.PHASE_MATCH_RESULT)

## One live frame: new balls, then each ball's hits, flight and rules.
## (LAVA and MOMENTUM aren't called here: with no rally to end they'd score
## every frame you stood in the kitchen.)
func update() -> void:
	if timer > 0:
		timer -= 1
	elif balls.size() < K.MULTI_MAX:
		spawn()
		timer = K.MULTI_EVERY
	# FAST BALL's pace advances once a frame, whatever the balls
	var tick0 := sim.ball_tick
	for m: Entry in balls.duplicate():
		if sim.phase != K.PHASE_LIVE:
			break
		sim.ball_tick = tick0
		if m.blink > 0:
			m.blink -= 1
			if m.blink == 0:
				launch_ball(m)
			continue
		swap_in(m)
		var hit_player := 0
		for p in sim.players:
			if p.state == K.STATE_ACTIVE:
				hit_player = sim.resolve_player_hits()
				break
		if hit_player:
			sim.contact(hit_player - 1)
			sim.rules_process_player_hit(hit_player - 1)
		if not m.dead and sim.phase == K.PHASE_LIVE:
			var ev := sim.step_ball()
			if ev & K.BALL_EVENT_BOUNCE:
				sim.emit(K.EVENT_BOUNCE, K.from_fp(sim.ball.x_fp), K.from_fp(sim.ball.y_fp), sim.ball.bounce_count)
			sim.rules_process_ball_events(ev)
		swap_out(m)
	if sim.ball_paced:
		sim.ball_tick = (tick0 + 1) % sim.BALL_CYCLE
	sim.serving_team = serving
	balls = balls.filter(func(m): return not m.dead)
	sim.ball = balls[0].ball if not balls.is_empty() else idle

## The ball a slot plays: the one it played if it's still coming, else the
## nearest that is on its side or flying to it (or, none, the nearest).
func ball_for(slot: int) -> Entry:
	var p: SimTypes.Player = sim.players[slot]
	var best: Entry = null
	var best_d := 0x7fffffff
	for m: Entry in balls:
		if m.blink > 0 or m.dead:
			continue
		var b := m.ball
		var mine := (b.x_fp < K.to_fp(K.COURT_NET_X)) == (p.team == 0)
		var coming := (b.vx_fp < 0) == (p.team == 0)
		var theirs_last := b.last_hitter < K.MAX_PLAYERS and (b.last_hitter >= 2) == (p.team == 1)
		if theirs_last or not (mine or coming):
			continue
		if m.id == ai_ball[slot]:
			return m
		var d := absi(b.x_fp - p.x_fp) + absi(b.y_fp - p.y_fp)
		if d < best_d:
			best_d = d
			best = m
	return best

## The AI thinks about its ball: it is swapped in, and the AI's landing
## cache (one ball's) starts over when the ball changes.
func ai_update(slot: int) -> void:
	if not sim.multi_on or sim.phase != K.PHASE_LIVE:
		sim.ai.update(slot, sim.intents[slot])
		return
	var m := ball_for(slot)
	if m == null:
		var keep := sim.ball
		sim.ball = idle
		sim.ai.update(slot, sim.intents[slot])
		sim.ball = keep
		return
	var kept := [sim.ball, sim.required_bounce, sim.landing_pending, sim.contact_volley, sim.shot_serial, sim.ball_steps,
		serve_team_now, sim.serving_team]
	ai_ball[slot] = m.id
	sim.ai.land_valid = false
	swap_in(m)
	sim.ai.update(slot, sim.intents[slot])
	sim.ball = kept[0]
	sim.required_bounce = kept[1]
	sim.landing_pending = kept[2]
	sim.contact_volley = kept[3]
	sim.shot_serial = kept[4]
	sim.ball_steps = kept[5]
	serve_team_now = kept[6]
	sim.serving_team = kept[7]

func ai_assist(slot: int) -> bool:
	if not sim.multi_on or sim.phase != K.PHASE_LIVE:
		return sim.ai.assist_swing(slot)
	var m := ball_for(slot)
	if m == null:
		return false
	var keep := sim.ball
	sim.ball = m.ball
	var r := sim.ai.assist_swing(slot)
	sim.ball = keep
	return r


