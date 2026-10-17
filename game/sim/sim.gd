## The deterministic match simulation: a port of the SNES C sim
## (reference/snes-src/src: ball.c, collision.c, player.c, serve.c,
## rules.c, game.c, and main.c's controller schedule).
##
## Pure: no Nodes, no time, no randomness. step() advances one 60 Hz frame
## from the human intents; presentation reads the state and drains
## `events` (SERVE/HIT/BOUNCE/FAULT/POINT) and never writes back.
class_name Sim
extends RefCounted

const Ball := SimTypes.Ball
const Player := SimTypes.Player
const Intent := SimTypes.Intent

var config: SimTypes.MatchConfig
var players: Array = []          # 4 x Player
var ball := Ball.new()
var intents: Array = []          # 4 x Intent, this frame's
var owners := [K.OWNER_HUMAN, K.OWNER_NONE, K.OWNER_CPU, K.OWNER_NONE]
var ai: SimAI

# GameState (game.h)
var paused := 0
var phase := K.PHASE_SERVE_SETUP
var phase_timer := 0
var last_fault := K.FAULT_NONE
var point_winner := K.NO_TEAM
var team_score := [0, 0]
var required_bounce := K.REQUIRED_BOUNCE_NONE
var serving_team := 0
var match_winner := K.NO_TEAM
var hit_stop := 0
var shot_serial := 0            # u8
var frame_count := 0            # u16

# ServeState / ServeCharge (serve.h)
var server_index := 0
var receiver_index := 2
var landing_pending := 0
var serve_requested := 0
var serve_aim_x := K.SERVE_TARGET_NEUTRAL_RIGHT
var serve_aim_y := K.COURT_SIDELINE_TOP + 20
var server_y_fp := K.to_fp(K.COURT_CENTERLINE_Y)
var charge_charging := 0
var charge_level := 0
var charge_rising := 1
var charge_armed := 0
var charge_power := K.SERVE_CHARGE_CLASSIC

# Outside the traced state (as in C): presentation and bookkeeping.
var attract := 0                ## slot 0 driven by the AI (demo)
## Tests and the stats harness: slot 0 is a human driven by the AI with a
## human skill level (test_support.h test_bot_skill), B ORed in.
var p1_bot := false
var loop_count := 0             ## main.c g_loop_count (u16)
var ball_steps := 0             ## physics steps this match (AI cache)
var rally_start := 0
var last_rally_length := 0
var events: Array = []          ## [kind, x, y, detail] since last drain

## Set false to run a slot-0 human through serve meter rules; the bot
## harness and attract use the classic serve.
var rematch_requested := false
var title_requested := false


func _init(cfg: SimTypes.MatchConfig = null) -> void:
	config = cfg if cfg != null else SimTypes.MatchConfig.singles()
	for i in K.MAX_PLAYERS:
		players.append(Player.new())
		intents.append(Intent.new())
	ai = SimAI.new(self)
	new_match()


# --- Court helpers (court.c) -------------------------------------------------

static func toward_net(team: int) -> int:
	return -1 if team else 1

static func side_of_x(x_fp: int) -> int:
	return 0 if x_fp < K.to_fp(K.COURT_NET_X) else 1

static func x_on_side(x_fp: int, team: int) -> bool:
	if team == 0:
		return x_fp < K.to_fp(K.COURT_NET_X)
	return x_fp > K.to_fp(K.COURT_NET_X)

static func aim_depth(team: int, aim_x: int) -> int:
	var toward := -aim_x if team else aim_x
	if toward > 0:
		return 1
	if toward < 0:
		return -1
	return 0

static func target_x_for(team: int, left_hitter_x: int) -> int:
	return K.mirror_x(left_hitter_x) if team else left_hitter_x

static func clamp_y_fp(y_fp: int) -> int:
	return clampi(y_fp, K.to_fp(K.PLAYER_CLAMP_MIN_Y), K.to_fp(K.PLAYER_CLAMP_MAX_Y))

static func contains_ground_fp(x_fp: int, y_fp: int) -> bool:
	return x_fp >= K.to_fp(K.COURT_BASELINE_LEFT) \
		and x_fp <= K.to_fp(K.COURT_BASELINE_RIGHT) \
		and y_fp >= K.to_fp(K.COURT_SIDELINE_TOP) \
		and y_fp <= K.to_fp(K.COURT_SIDELINE_BOTTOM)

static func lane_top(slot: int) -> bool:
	return slot == 1 or slot == 2


# --- Ball (ball.c) -------------------------------------------------------------

## Scales toward zero symmetrically so +v and -v lose the same speed.
static func retain(value: int, fraction_256: int) -> int:
	if value < 0:
		return -((-value * fraction_256) >> 8)
	return (value * fraction_256) >> 8

## Velocity so the ball lands on (tx, ty) after `frames` steps.
static func launch(b: Ball, tx: int, ty: int, frames: int) -> void:
	var half := frames >> 1
	var dx := K.to_fp(tx) - b.x_fp
	var dy := K.to_fp(ty) - b.y_fp
	var rise := -b.z_fp - K.BALL_GRAVITY_FP * frames * (frames - 1) / 2
	b.vx_fp = (dx + half if dx >= 0 else dx - half) / frames
	b.vy_fp = (dy + half if dy >= 0 else dy - half) / frames
	b.vz_fp = (rise if rise >= 0 else rise - frames + 1) / frames

## Interpolated z where the x segment crosses the net, or null.
static func net_crossing_height(px: int, pz: int, cx: int, cz: int) -> Variant:
	var net := K.to_fp(K.COURT_NET_X)
	if px < net:
		if cx < net:
			return null
	elif px > net:
		if cx > net:
			return null
	else:
		return null
	return pz + ((cz - pz) * (net - px)) / (cx - px)

static func simulate_step(b: Ball) -> int:
	var ev := K.BALL_EVENT_NONE
	if not b.active or b.rally_state != K.BALL_RALLY_LIVE:
		return ev
	if b.z_fp == 0 and b.vz_fp <= 0:
		b.vx_fp = 0
		b.vy_fp = 0
		b.vz_fp = 0
		return ev
	var px := b.x_fp
	var pz := b.z_fp
	b.x_fp += b.vx_fp
	b.y_fp += b.vy_fp
	b.z_fp += b.vz_fp
	b.vz_fp += K.BALL_GRAVITY_FP
	var net := K.to_fp(K.COURT_NET_X)
	if (px < net) != (b.x_fp < net):
		var h = net_crossing_height(px, pz, b.x_fp, b.z_fp)
		if h != null and h < K.to_fp(K.COURT_NET_HEIGHT):
			ev |= K.BALL_EVENT_NET_FAULT
	if pz > 0 and b.z_fp <= 0:
		var impact_vz := b.vz_fp - K.BALL_GRAVITY_FP
		b.z_fp = 0
		b.vx_fp = retain(b.vx_fp, K.BALL_BOUNCE_PLANAR_256)
		b.vy_fp = retain(b.vy_fp, K.BALL_BOUNCE_PLANAR_256)
		b.vz_fp = -retain(impact_vz, K.BALL_BOUNCE_VERTICAL_256)
		b.bounce_count += 1
		ev |= K.BALL_EVENT_BOUNCE
		if not contains_ground_fp(b.x_fp, b.y_fp):
			ev |= K.BALL_EVENT_OUT
		if b.vz_fp <= K.BALL_MIN_BOUNCE_VZ_FP:
			b.vx_fp = 0
			b.vy_fp = 0
			b.vz_fp = 0
	return ev

func ball_initialize() -> void:
	ball = Ball.new()
	ball.active = 1
	ball.x_fp = K.to_fp(K.BALL_START_X)
	ball.y_fp = K.to_fp(K.BALL_START_Y)
	ball.rally_state = K.BALL_RALLY_LIVE


# --- Collision (collision.c) -------------------------------------------------------

static func _within(d: int, half: int) -> bool:
	return d >= -half and d <= half

static func in_reach(p: Player, b: Ball) -> bool:
	if not p.active or not b.active or b.rally_state != K.BALL_RALLY_LIVE:
		return false
	if not _within(b.x_fp - p.x_fp, K.to_fp(K.HIT_REACH_X)):
		return false
	if not _within(b.y_fp - p.y_fp, K.to_fp(K.HIT_REACH_Y)):
		return false
	return b.z_fp >= 0 and b.z_fp <= K.to_fp(K.HIT_REACH_Z)

static func in_sweet_spot(p: Player, b: Ball) -> bool:
	return _within(b.x_fp - p.x_fp, K.to_fp(K.HIT_SWEET_X)) \
		and _within(b.y_fp - p.y_fp, K.to_fp(K.HIT_SWEET_Y))

## Target and flight for a rally shot (ADR-019).
static func apply_targeted_shot(b: Ball, p: Player, intent: Intent) -> void:
	var tx: int
	var ty := K.HIT_TARGET_LANE_CENTER
	var pace: int
	var min_frames := K.HIT_FLIGHT_MIN_FRAMES
	var max_frames := K.HIT_FLIGHT_MAX_FRAMES
	var wide := K.HIT_STRETCH_WIDE
	var longer := K.HIT_STRETCH_LONG
	var depth := aim_depth(p.team, intent.aim_x)
	var shot := p.shot_type
	if intent.aim_y < 0:
		ty = K.HIT_TARGET_LANE_TOP
	elif intent.aim_y > 0:
		ty = K.HIT_TARGET_LANE_BOTTOM
	if shot == K.SHOT_SOFT and depth < 0:
		tx = K.HIT_TARGET_DINK_RIGHT
		pace = K.HIT_PACE_DINK_FP
	elif shot == K.SHOT_SOFT:
		tx = K.HIT_TARGET_DEEP_RIGHT
		pace = K.HIT_PACE_LOB_FP
		min_frames = K.HIT_LOB_MIN_FRAMES
		max_frames = K.HIT_LOB_MAX_FRAMES
	else:
		if depth > 0:
			tx = K.HIT_TARGET_DEEP_RIGHT
			pace = K.HIT_PACE_DEEP_FP
		elif depth < 0:
			tx = K.HIT_TARGET_SHORT_RIGHT
			pace = K.HIT_PACE_SHORT_FP
		else:
			tx = K.HIT_TARGET_NEUTRAL_RIGHT
			pace = K.HIT_PACE_NEUTRAL_FP
		if shot == K.SHOT_DRIVE:
			pace = K.HIT_PACE_DRIVE_FP
			min_frames = K.HIT_DRIVE_MIN_FRAMES
			max_frames = K.HIT_DRIVE_MAX_FRAMES
			wide = K.HIT_DRIVE_STRETCH_WIDE
			longer = K.HIT_DRIVE_STRETCH_LONG
	pace = (pace * Paddles.power_mul(p.paddle)) >> 6
	if not in_sweet_spot(p, b):
		wide = (wide * Paddles.control_mul(p.paddle)) >> 6
		longer = (longer * Paddles.control_mul(p.paddle)) >> 6
		if ty < K.HIT_TARGET_LANE_CENTER \
				or (ty == K.HIT_TARGET_LANE_CENTER and b.y_fp < p.y_fp):
			ty -= wide
		else:
			ty += wide
		tx += longer
	tx = target_x_for(p.team, tx)
	var distance := absi(K.to_fp(tx) - b.x_fp)
	var flight := clampi(distance / pace, min_frames, max_frames)
	launch(b, tx, ty, flight)

## Contacting slot + 1, or 0.
func resolve_player_hits() -> int:
	for i in K.MAX_PLAYERS:
		var p: Player = players[i]
		if p.state != K.STATE_ACTIVE or p.contact_consumed:
			continue
		# A team hits once (KNOWN_ISSUES #19).
		if ball.last_hitter < K.MAX_PLAYERS and (ball.last_hitter >= 2) == (i >= 2):
			continue
		if not in_reach(p, ball):
			continue
		p.contact_consumed = 1
		ball.last_hitter = i
		ball.bounce_count = 0
		apply_targeted_shot(ball, p, intents[i])
		return i + 1
	return 0


# --- Players (player.c) -------------------------------------------------------------

static func diagonal_limit(limit: int) -> int:
	if limit >= 0 and limit < 32:
		return K.DIAGONAL_LIMIT[limit]
	return (limit * 181) >> 8

static func is_swinging(p: Player) -> bool:
	return p.state == K.STATE_WINDUP or p.state == K.STATE_ACTIVE \
		or p.state == K.STATE_RECOVERY

static func place(p: Player, x: int, y: int) -> void:
	p.x_fp = K.to_fp(x)
	p.y_fp = K.to_fp(y)
	p.vx_fp = 0
	p.vy_fp = 0
	p.state = K.STATE_IDLE
	p.state_frames_remaining = 0
	p.contact_consumed = 1
	p.animation_frame = 0
	p.animation_timer = 0

static func _approach_zero(v: int) -> int:
	if v > K.PLAYER_FRICTION_FP:
		return v - K.PLAYER_FRICTION_FP
	if v < -K.PLAYER_FRICTION_FP:
		return v + K.PLAYER_FRICTION_FP
	return 0

const ANIM_IDLE_CELS := 2
const ANIM_RUN_CELS := 4
const IDLE_CEL_FRAMES := 20
const RUN_CEL_FRAMES := 6

static func player_step(p: Player, intent: Intent) -> void:
	if p.flash_timer:
		p.flash_timer -= 1
	var mx := intent.move_x
	var my := intent.move_y
	var hit := intent.hit_pressed
	if p.frozen:
		mx = 0
		my = 0
		hit = 0
	var was_moving := p.state == K.STATE_MOVE
	if p.state >= K.STATE_WINDUP:
		p.state_frames_remaining -= 1
		if p.state_frames_remaining == 0:
			if p.state == K.STATE_WINDUP:
				p.state = K.STATE_ACTIVE
				p.state_frames_remaining = K.PLAYER_ACTIVE_FRAMES
			elif p.state == K.STATE_ACTIVE:
				p.state = K.STATE_RECOVERY
				p.state_frames_remaining = Paddles.recovery(p.paddle)
			else:
				p.state = K.STATE_IDLE
	elif hit:
		p.state = K.STATE_WINDUP
		p.state_frames_remaining = K.PLAYER_WINDUP_FRAMES
		p.contact_consumed = 0
		p.shot_type = intent.shot
	else:
		p.state = K.STATE_MOVE if (mx or my) else K.STATE_IDLE
	var limit := Paddles.swing_limit(p.paddle) if p.state >= K.STATE_WINDUP \
		else p.max_speed_fp
	var accel := K.PLAYER_ACCEL_FP
	if mx and my:
		accel = K.PLAYER_DIAGONAL_ACCEL_FP
		limit = K.DIAGONAL_LIMIT[limit & 31]
	if mx > 0:
		p.vx_fp += accel
	elif mx < 0:
		p.vx_fp -= accel
	else:
		p.vx_fp = _approach_zero(p.vx_fp)
	if my > 0:
		p.vy_fp += accel
	elif my < 0:
		p.vy_fp -= accel
	else:
		p.vy_fp = _approach_zero(p.vy_fp)
	p.vx_fp = clampi(p.vx_fp, -limit, limit)
	p.vy_fp = clampi(p.vy_fp, -limit, limit)
	var nx := p.x_fp + p.vx_fp
	var lo := K.to_fp(K.PLAYER_CLAMP_MIN_X if p.team == 0 else K.PLAYER_RIGHT_CLAMP_MIN_X)
	var hi := K.to_fp(K.PLAYER_CLAMP_MAX_X if p.team == 0 else K.PLAYER_RIGHT_CLAMP_MAX_X)
	if nx < lo:
		nx = lo
		p.vx_fp = 0
	elif nx > hi:
		nx = hi
		p.vx_fp = 0
	p.x_fp = nx
	var ny := p.y_fp + p.vy_fp
	if ny < K.to_fp(K.PLAYER_CLAMP_MIN_Y):
		ny = K.to_fp(K.PLAYER_CLAMP_MIN_Y)
		p.vy_fp = 0
	elif ny > K.to_fp(K.PLAYER_CLAMP_MAX_Y):
		ny = K.to_fp(K.PLAYER_CLAMP_MAX_Y)
		p.vy_fp = 0
	p.y_fp = ny
	p.facing_left = p.team
	var moving := p.state == K.STATE_MOVE
	if moving != was_moving:
		p.animation_frame = 0
		p.animation_timer = 0
	var cel := RUN_CEL_FRAMES if moving else IDLE_CEL_FRAMES
	p.animation_timer += 1
	if p.animation_timer >= cel:
		p.animation_timer = 0
		p.animation_frame += 1
		if p.animation_frame >= (ANIM_RUN_CELS if moving else ANIM_IDLE_CELS):
			p.animation_frame = 0

func players_update() -> void:
	for i in K.MAX_PLAYERS:
		var p: Player = players[i]
		if p.active:
			player_step(p, intents[p.logical_input_slot])

## Doubles (ADR-018): nudge crowded teammates 1 px apart in y.
func separate_teammates() -> void:
	for pair in [[0, 1], [2, 3]]:
		var a: Player = players[pair[0]]
		var b: Player = players[pair[1]]
		if not (a.active and b.active):
			continue
		var dx := absi(a.x_fp - b.x_fp)
		var dy := a.y_fp - b.y_fp
		if dx < K.to_fp(K.PLAYER_SEPARATION_X) and dy < K.to_fp(K.PLAYER_SEPARATION_Y) \
				and dy > -K.to_fp(K.PLAYER_SEPARATION_Y):
			var step := -K.FP_ONE if dy <= 0 else K.FP_ONE
			a.y_fp = clamp_y_fp(a.y_fp + step)
			b.y_fp = clamp_y_fp(b.y_fp - step)


# --- Serve (serve.c) -------------------------------------------------------------------

## The charged serve's meter runs for a human server (ADR-044).
func serve_charged() -> bool:
	return not attract and config.difficulty != K.DIFFICULTY_KID \
		and owners[server_index] == K.OWNER_HUMAN

static func serve_flight_frames(power: int) -> int:
	return K.SERVE_FLIGHT_FRAMES - ((power - K.SERVE_CHARGE_DUD) >> 1)

func _serve_hold_ball() -> void:
	var server: Player = players[server_index]
	var offset := -K.SERVE_HAND_OFFSET_X if server.team else K.SERVE_HAND_OFFSET_X
	ball.active = 1
	ball.x_fp = server.x_fp + K.to_fp(offset)
	ball.y_fp = server.y_fp + K.to_fp(1)
	ball.z_fp = K.to_fp(K.SERVE_HAND_Z)
	ball.vx_fp = 0
	ball.vy_fp = 0
	ball.vz_fp = 0
	ball.last_hitter = K.BALL_NO_HITTER
	ball.bounce_count = 0
	ball.rally_state = K.BALL_RALLY_INACTIVE

func _serve_select_target(server: Player, intent: Intent) -> void:
	var box_y: int
	if server_y_fp >= K.to_fp(K.COURT_CENTERLINE_Y):
		box_y = (K.COURT_SIDELINE_TOP + K.COURT_CENTERLINE_Y) / 2
	else:
		box_y = (K.COURT_CENTERLINE_Y + K.COURT_SIDELINE_BOTTOM) / 2
	if intent.aim_y < 0:
		box_y -= K.SERVE_TARGET_LANE_SHIFT
	elif intent.aim_y > 0:
		box_y += K.SERVE_TARGET_LANE_SHIFT
	serve_aim_y = box_y
	var depth := aim_depth(server.team, intent.aim_x)
	var x := K.SERVE_TARGET_NEUTRAL_RIGHT
	if depth > 0:
		x = K.SERVE_TARGET_DEEP_RIGHT
	elif depth < 0:
		x = K.SERVE_TARGET_SHORT_RIGHT
	serve_aim_x = target_x_for(server.team, x)

func _serve_contact(intent: Intent) -> void:
	var server: Player = players[server_index]
	_serve_select_target(server, intent)
	if charge_power < K.SERVE_CHARGE_DUD:
		launch(ball, target_x_for(server.team, K.COURT_NET_X + K.SERVE_DUD_PAST_NET),
			serve_aim_y, K.SERVE_DUD_FRAMES)
	else:
		launch(ball, serve_aim_x, serve_aim_y, serve_flight_frames(charge_power))
	ball.last_hitter = server_index
	ball.bounce_count = 0
	ball.rally_state = K.BALL_RALLY_LIVE
	shot_serial = (shot_serial + 1) & 0xff
	emit(K.EVENT_SERVE, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), server_index)
	landing_pending = 1
	required_bounce = K.REQUIRED_BOUNCE_SERVE
	server.contact_consumed = 1
	server.pose = K.POSE_NONE
	server.frozen = 0
	set_phase(K.PHASE_LIVE)

func serve_initialize() -> void:
	server_index = 0
	receiver_index = 2
	landing_pending = 0
	serve_requested = 0
	serve_aim_x = K.SERVE_TARGET_NEUTRAL_RIGHT
	serve_aim_y = K.COURT_SIDELINE_TOP + 20
	server_y_fp = K.to_fp(K.COURT_CENTERLINE_Y)

func _serve_slot_for_lane(team: int, top: bool) -> int:
	var first := 2 if team else 0
	if not players[first + 1].active:
		return first
	if not players[first].active:
		return first + 1
	return first if lane_top(first) == top else first + 1

func _serve_place_partner(slot: int, at_kitchen: bool) -> void:
	var p: Player = players[slot]
	var y := K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y if lane_top(slot) \
		else K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y
	var x: int
	if at_kitchen:
		x = K.COURT_KITCHEN_RIGHT_X + K.SERVE_PARTNER_KITCHEN_GAP if p.team \
			else K.COURT_KITCHEN_LEFT_X - K.SERVE_PARTNER_KITCHEN_GAP
	else:
		x = K.COURT_BASELINE_RIGHT + K.SERVE_RECEIVER_GAP if p.team \
			else K.COURT_BASELINE_LEFT - K.SERVE_RECEIVER_GAP
	place(p, x, y)
	p.frozen = 0
	p.pose = K.POSE_NONE

func serve_setup(team: int) -> void:
	var even: bool = (team_score[team] & 1) == 0
	var server_y: int
	if (team == 0) == even:
		server_y = K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y
	else:
		server_y = K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y
	var receiver_y := K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y \
		if server_y >= K.COURT_CENTERLINE_Y \
		else K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y
	var server_top := server_y < K.COURT_CENTERLINE_Y
	server_index = _serve_slot_for_lane(team, server_top)
	receiver_index = _serve_slot_for_lane(0 if team else 1, not server_top)
	landing_pending = 0
	serve_requested = 0
	charge_charging = 0
	charge_level = 0
	charge_rising = 1
	charge_armed = 0
	charge_power = K.SERVE_CHARGE_CLASSIC
	var server: Player = players[server_index]
	var receiver: Player = players[receiver_index]
	if team == 0:
		place(server, K.COURT_BASELINE_LEFT - K.SERVE_BASELINE_GAP, server_y)
		place(receiver, K.COURT_BASELINE_RIGHT + K.SERVE_RECEIVER_GAP, receiver_y)
	else:
		place(server, K.COURT_BASELINE_RIGHT + K.SERVE_BASELINE_GAP, server_y)
		place(receiver, K.COURT_BASELINE_LEFT - K.SERVE_RECEIVER_GAP, receiver_y)
	server.frozen = 1
	receiver.frozen = 0
	server.pose = K.POSE_NONE
	receiver.pose = K.POSE_NONE
	if players[server_index ^ 1].active:
		_serve_place_partner(server_index ^ 1, false)
	if players[receiver_index ^ 1].active:
		_serve_place_partner(receiver_index ^ 1, true)
	server_y_fp = server.y_fp
	serving_team = team
	required_bounce = K.REQUIRED_BOUNCE_NONE
	_serve_hold_ball()

func serve_update() -> void:
	var server: Player = players[server_index]
	var intent: Intent = intents[server.logical_input_slot]
	if phase == K.PHASE_SERVE_SETUP:
		_serve_hold_ball()
		if intent.hit_pressed:
			serve_requested = 1
		if phase_timer < K.SERVE_READY_FRAMES:
			return
		if serve_charged() and intent.hit_held:
			if not charge_charging:
				charge_charging = 1
			elif charge_rising:
				charge_level += 1
				if charge_level >= K.SERVE_CHARGE_MAX:
					charge_rising = 0
				if charge_level >= K.SERVE_CHARGE_DUD:
					charge_armed = 1
			else:
				charge_level -= 1
				if charge_level == 0:
					charge_rising = 1
			return
		if charge_charging:
			charge_charging = 0
			if charge_armed:
				charge_power = charge_level
		elif not serve_requested:
			return
		serve_requested = 0
		ball.vz_fp = K.SERVE_TOSS_VZ_FP
		server.pose = K.POSE_TOSS
		set_phase(K.PHASE_SERVE_TOSS)
		last_fault = K.FAULT_NONE
		return
	if phase != K.PHASE_SERVE_TOSS:
		return
	ball.z_fp += ball.vz_fp
	ball.vz_fp += K.BALL_GRAVITY_FP
	if phase_timer == K.SERVE_TOSS_POSE_FRAMES:
		server.pose = K.POSE_NONE
		server.state = K.STATE_WINDUP
		server.state_frames_remaining = K.PLAYER_WINDUP_FRAMES
		server.contact_consumed = 1
	if phase_timer >= K.SERVE_TOSS_FRAMES:
		_serve_contact(intent)

static func serve_validate_landing(x_fp: int, y_fp: int, server_team: int,
		server_y: int) -> int:
	if not contains_ground_fp(x_fp, y_fp):
		return K.FAULT_OUT
	if server_team == 0:
		if x_fp <= K.to_fp(K.COURT_NET_X):
			return K.FAULT_WRONG_BOX
		if x_fp <= K.to_fp(K.COURT_KITCHEN_RIGHT_X):
			return K.FAULT_KITCHEN
	else:
		if x_fp >= K.to_fp(K.COURT_NET_X):
			return K.FAULT_WRONG_BOX
		if x_fp >= K.to_fp(K.COURT_KITCHEN_LEFT_X):
			return K.FAULT_KITCHEN
	if server_y < K.to_fp(K.COURT_CENTERLINE_Y):
		if y_fp < K.to_fp(K.COURT_CENTERLINE_Y):
			return K.FAULT_WRONG_BOX
	else:
		if y_fp > K.to_fp(K.COURT_CENTERLINE_Y):
			return K.FAULT_WRONG_BOX
	return K.FAULT_NONE

func serve_process_ball_events(ev: int) -> void:
	if not landing_pending:
		return
	if ev & K.BALL_EVENT_NET_FAULT:
		last_fault = K.FAULT_NET
		phase = K.PHASE_SERVE_FAULT
		landing_pending = 0
		ball.rally_state = K.BALL_RALLY_INACTIVE
		return
	if not (ev & K.BALL_EVENT_BOUNCE):
		return
	var server: Player = players[server_index]
	var fault := serve_validate_landing(ball.x_fp, ball.y_fp, server.team, server_y_fp)
	last_fault = fault
	landing_pending = 0
	if fault != K.FAULT_NONE:
		phase = K.PHASE_SERVE_FAULT
		ball.rally_state = K.BALL_RALLY_INACTIVE
		ball.vx_fp = 0
		ball.vy_fp = 0
		ball.vz_fp = 0


# --- Rules (rules.c) ---------------------------------------------------------------------

func _last_hitter_team() -> int:
	if ball.last_hitter >= K.MAX_PLAYERS:
		return 0
	return 1 if ball.last_hitter >= 2 else 0

func _server_team() -> int:
	return 1 if server_index >= 2 else 0

func resolve_point(losing_team: int, fault: int) -> void:
	if phase == K.PHASE_POINT_RESULT or phase == K.PHASE_MATCH_RESULT:
		return
	var winner := 1 - losing_team
	point_winner = winner
	last_fault = fault
	team_score[winner] += 1
	if fault != K.FAULT_SECOND_BOUNCE and fault != K.FAULT_NONE:
		emit(K.EVENT_FAULT, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), fault)
	emit(K.EVENT_POINT, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), winner)
	set_phase(K.PHASE_POINT_RESULT)
	required_bounce = K.REQUIRED_BOUNCE_NONE
	landing_pending = 0
	ball.rally_state = K.BALL_RALLY_INACTIVE
	ball.vx_fp = 0
	ball.vy_fp = 0
	ball.vz_fp = 0

func rules_process_player_hit(slot: int) -> void:
	if phase != K.PHASE_LIVE or slot >= K.MAX_PLAYERS:
		return
	if required_bounce == K.REQUIRED_BOUNCE_NONE:
		return
	var team: int = players[slot].team
	if required_bounce == K.REQUIRED_BOUNCE_SERVE:
		resolve_point(team, K.FAULT_EARLY_VOLLEY)
		return
	if team == _server_team():
		resolve_point(team, K.FAULT_EARLY_VOLLEY)

func rules_process_ball_events(ev: int) -> void:
	if phase == K.PHASE_SERVE_FAULT:
		resolve_point(_last_hitter_team(), last_fault)
		return
	if phase != K.PHASE_LIVE:
		return
	var hitter := _last_hitter_team()
	if ev & K.BALL_EVENT_NET_FAULT:
		resolve_point(hitter, K.FAULT_NET)
		return
	if not (ev & K.BALL_EVENT_BOUNCE):
		if ball.z_fp == 0 and ball.vz_fp == 0 and ball.vx_fp == 0 \
				and ball.vy_fp == 0 and ball.bounce_count > 0:
			resolve_point(side_of_x(ball.x_fp), K.FAULT_SECOND_BOUNCE)
		return
	var side := side_of_x(ball.x_fp)
	if ball.bounce_count >= 2:
		resolve_point(1 - hitter, K.FAULT_SECOND_BOUNCE)
		return
	if (ev & K.BALL_EVENT_OUT) or side == hitter:
		resolve_point(hitter, K.FAULT_OUT)
		return
	if required_bounce == K.REQUIRED_BOUNCE_SERVE:
		required_bounce = K.REQUIRED_BOUNCE_RETURN
	elif required_bounce == K.REQUIRED_BOUNCE_RETURN:
		if hitter != _server_team() and side == _server_team():
			required_bounce = K.REQUIRED_BOUNCE_NONE


# --- Game (game.c) --------------------------------------------------------------------------

func emit(kind: int, x: int, y: int, detail: int) -> void:
	events.append([kind, x, y, detail])

func drain_events() -> Array:
	var e := events
	events = []
	return e

func set_phase(p: int) -> void:
	phase = p
	phase_timer = 0

func score_wins(score: int, other: int) -> bool:
	return score >= config.points_to_win and (not config.win_by_2 or score >= other + 2)

func team_won(team: int) -> bool:
	return score_wins(team_score[team], team_score[team ^ 1])

func match_point(team: int) -> bool:
	return score_wins(team_score[team] + 1, team_score[team ^ 1])

func _game_initialize() -> void:
	paused = 0
	last_fault = K.FAULT_NONE
	point_winner = K.NO_TEAM
	match_winner = K.NO_TEAM
	team_score = [0, 0]
	required_bounce = K.REQUIRED_BOUNCE_NONE
	serving_team = 0
	hit_stop = 0
	shot_serial = 0
	frame_count = 0
	set_phase(K.PHASE_SERVE_SETUP)

func _begin_serve(team: int) -> void:
	for p in players:
		p.pose = K.POSE_NONE
	serve_setup(team)
	rally_start = shot_serial
	set_phase(K.PHASE_SERVE_SETUP)

func _players_initialize() -> void:
	for i in K.MAX_PLAYERS:
		var p := Player.new()
		p.team = 0 if i < 2 else 1
		p.logical_input_slot = i
		p.cpu_controlled = 1 if i == 2 else 0
		p.max_speed_fp = K.PLAYER_CPU_MAX_SPEED_FP if p.cpu_controlled \
			else K.PLAYER_MAX_SPEED_FP
		p.facing_left = p.team
		place(p, 0, 0)
		players[i] = p
	players[0].active = 1
	place(players[0], K.PLAYER_SPAWN_X, K.PLAYER_SPAWN_Y)

func _activate_players() -> void:
	for i in K.MAX_PLAYERS:
		var active := config.slot_active(i)
		if i == 0:
			owners[i] = K.OWNER_HUMAN
		else:
			owners[i] = K.OWNER_NONE if not active else \
				(K.OWNER_HUMAN if config.human[i] else K.OWNER_CPU)
		var p: Player = players[i]
		p.active = 1 if active else 0
		p.cpu_controlled = 1 if owners[i] == K.OWNER_CPU else 0
		p.max_speed_fp = K.PLAYER_MAX_SPEED_FP
		p.variant = config.variant[i]
		p.paddle = config.paddle[i]
		if p.cpu_controlled:
			var style: SimTypes.AiStyle = Opponents.slot_style(config, i).copy()
			if config.difficulty != K.DIFFICULTY_MEDIUM \
					and not config.human[i & 2] and not config.human[(i & 2) + 1]:
				Opponents.apply_difficulty(style, config.difficulty)
			p.max_speed_fp = style.speed
			ai.styles[i] = style
			ai.slots[i].late_period = style.late_period
			ai.slots[i].reaction_frames = style.reaction

## Fresh match (RST-01): every module re-initialized.
func new_match() -> void:
	rematch_requested = false
	title_requested = false
	_players_initialize()
	ball_initialize()
	serve_initialize()
	ai.initialize()
	_game_initialize()
	ball_steps = 0
	events = []
	_activate_players()
	_begin_serve(0)
	if attract:
		ai.slots[0].late_period = K.ATTRACT_LATE_PERIOD

## A CPU-vs-CPU demo (or bot run): slot 0 is driven by the AI too.
func start_attract() -> void:
	attract = 1
	new_match()

func contact(slot: int) -> void:
	var p: Player = players[slot]
	shot_serial = (shot_serial + 1) & 0xff
	p.flash_timer = K.HIT_FLASH_FRAMES
	hit_stop = K.HIT_STOP_FRAMES
	emit(K.EVENT_HIT, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), slot | (p.shot_type << 4))

func step_ball() -> int:
	ball_steps += 1
	return simulate_step(ball)

func _update_live() -> void:
	var hit_player := 0
	for p in players:
		if p.state == K.STATE_ACTIVE:
			hit_player = resolve_player_hits()
			break
	if hit_player:
		contact(hit_player - 1)
		rules_process_player_hit(hit_player - 1)
		if phase != K.PHASE_LIVE:
			return
	var ev := step_ball()
	if ev & K.BALL_EVENT_BOUNCE:
		emit(K.EVENT_BOUNCE, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), ball.bounce_count)
	serve_process_ball_events(ev)
	rules_process_ball_events(ev)

func _freeze_players(winner: int) -> void:
	for p in players:
		if not p.active:
			continue
		p.frozen = 1
		p.pose = K.POSE_CHEER if p.team == winner else K.POSE_NONE

func _update_point_result() -> void:
	var winner := point_winner
	_freeze_players(winner)
	if phase_timer == 1:
		last_rally_length = (shot_serial - rally_start) & 0xff
	if phase_timer < K.POINT_RESULT_MIN_FRAMES:
		return
	if phase_timer < K.POINT_RESULT_FRAMES and not intents[0].hit_pressed:
		return
	if score_wins(team_score[winner], team_score[winner ^ 1]):
		match_winner = winner
		set_phase(K.PHASE_MATCH_RESULT)
		return
	_begin_serve(winner)

func _update_match_result() -> void:
	_freeze_players(match_winner)
	if attract:
		if phase_timer >= K.ATTRACT_RESULT_FRAMES:
			new_match()
		return
	if phase_timer < K.POINT_RESULT_MIN_FRAMES:
		return
	if intents[0].pause_pressed:
		title_requested = true
	elif intents[0].hit_pressed:
		rematch_requested = true

func game_update() -> void:
	frame_count = (frame_count + 1) & 0xffff
	if intents[0].pause_pressed and not attract and phase != K.PHASE_MATCH_RESULT:
		paused = 0 if paused else 1
	if paused:
		return
	if hit_stop:
		hit_stop -= 1
		return
	if phase_timer < 0xffff:
		phase_timer += 1
	players_update()
	separate_teammates()
	match phase:
		K.PHASE_SERVE_SETUP, K.PHASE_SERVE_TOSS:
			serve_update()
		K.PHASE_LIVE:
			_update_live()
		K.PHASE_POINT_RESULT:
			_update_point_result()
		K.PHASE_MATCH_RESULT:
			_update_match_result()


# --- Frame pipeline (main.c) ------------------------------------------------------------------

## Serving: the serve setup and toss only (main.c SERVING).
func _serving(slot: int) -> bool:
	return server_index == slot and phase <= K.PHASE_SERVE_TOSS

## One frame: human intents in, CPUs think on the shipped schedule
## (singles CPU every frame; a doubles lane cover every 4th, staggered by
## slot; the demo P1 every other frame), then the game updates.
## `human` holds an Intent per slot (only human-owned slots are read).
func step(human: Array = []) -> void:
	for i in K.MAX_PLAYERS:
		var it: Intent = intents[i]
		if owners[i] == K.OWNER_HUMAN and not (i == 0 and attract) \
				and i < human.size() and human[i] != null:
			it.copy_from(human[i])
			if i != 0:
				it.pause_pressed = 0
		else:
			it.clear()
	var lc := loop_count & 0xff
	if p1_bot and not attract:
		var pressed: int = intents[0].hit_pressed
		ai.update(0, intents[0])
		intents[0].hit_pressed |= pressed
	if attract:
		var think: bool = (ai.slots[0].has_target or (lc & 3) == 0) \
			if config.mode == K.MODE_DOUBLES else (loop_count & 1) == 1
		if think:
			ai.update(0, intents[0])
		else:
			ai.hold_intent(0, intents[0])
	elif config.difficulty == K.DIFFICULTY_KID:
		for slot in [0, 1, 2]:
			if owners[slot] == K.OWNER_HUMAN and players[slot].active \
					and ai.assist_swing(slot):
				intents[slot].hit_pressed = 1
				intents[slot].shot = K.SHOT_STANDARD
	for slot in [1, 2, 3]:
		if owners[slot] == K.OWNER_CPU and players[slot].active:
			if not players[slot ^ 1].active or ai.slots[slot].has_target \
					or _serving(slot) or (lc & 3) == slot:
				ai.update(slot, intents[slot])
			else:
				ai.hold_intent(slot, intents[slot])
	game_update()
	loop_count = (loop_count + 1) & 0xffff


# --- Trace -------------------------------------------------------------------------------------

## The P1 stand-in's skill (test_support.h test_bot_skill): mistimes every
## `late`th shot; reaction and foot speed vary by match index.
func set_bot_skill(late: int, match_index: int) -> void:
	ai.slots[0].late_period = late
	ai.slots[0].reaction_frames = (match_index * 7) % 20
	players[0].max_speed_fp = 16 + (match_index % 3) * 4


## The traced simulation state (GameState, ServeState, players, ball, AI
## slots), as the golden trace compares it.
func snapshot() -> Array:
	var s := [paused, phase, phase_timer, last_fault, point_winner,
		team_score[0], team_score[1], required_bounce, serving_team,
		match_winner, hit_stop, shot_serial, frame_count, server_index,
		receiver_index, landing_pending, serve_requested, serve_aim_x,
		serve_aim_y, server_y_fp]
	s.append_array(ball.to_array())
	for p in players:
		s.append_array(p.to_array())
	for a in ai.slots:
		s.append_array(a.to_array())
	return s
