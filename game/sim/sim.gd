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
var practice: Practice          ## the ball machine (ADR-028), in practice

# GameState (game.h)
var paused := 0
var phase := K.PHASE_SERVE_SETUP
var phase_timer := 0
var last_fault := K.FAULT_NONE
var point_winner := K.NO_TEAM
var team_score := [0, 0]
var required_bounce := K.REQUIRED_BOUNCE_NONE
var serving_team := 0
## SIDE-OUT (port ADR-063): which of the serving pair serves, 1 or 2 (a
## game opens on 2), the side-out's first server's slot, whether the last
## rally scored, and whether it's still the game's opening server.
var server_number := 2
var first_server := -1
var opening := true
var point_scored := true
var match_winner := K.NO_TEAM
var hit_stop := 0
## The last rally contact was before the ball bounced (ADR-055, the kitchen).
var contact_volley := 0
## MOMENTUM: the slot whose volley is still carrying them (-1: none).
var momentum_slot := -1
## SPECIALS (port ADR-080): each slot's meter, 0 .. SPECIAL_METER_MAX,
## and the team whose PICKLE SMASH is in the air (-1: none).
var meter := [0, 0, 0, 0]
var smash_team := -1
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
## Ball pace (ADR-025): KID and EASY play a slower ball by skipping steps
## evenly over a 60-frame cycle; the table runs 12 ticks past the cycle
## for the CPUs' swing lookahead. MEDIUM/HARD step every frame.
const BALL_CYCLE := 60
const BALL_PACE_TICKS := BALL_CYCLE + 12
var ball_paced := false
## POPCORN (SNES ADR-053): pace levels this rally has added (0..POPCORN_LEVELS).
var popcorn_level := 0
## ICE (SNES ADR-053): this match's footing (players_set_ice). Per sim, not
## a global as in the C: two sims can run at once (online's tests).
var ice := false
## BIG BALL grows reach and sweet spot (collision.c g_hit_box).
var grow_fp := 0
## ROAD TRIP's one-sided rules this match (port ADR-087): spent once-a-match
## perks, and SECOND WIND's extra speed per slot while it's on.
var kitchen_pass_used := false
var second_serve_used := false
var lucky_line_used := false
var hot_streak := 0              ## points the left side has won in a row (HOT HAND)
var wind_add := [0, 0, 0, 0]
var ball_pace: Array = []
var ball_tick := 0
var rally_start := 0
var last_rally_length := 0
var events: Array = []          ## [kind, x, y, detail, step] since last drain
## Steps this sim has run, never reset (a new match goes on counting): an
## event's `step` (port ADR-101), so a step run again (a rollback) gives its
## events the same stamp. Part of the state, so a load puts it back.
var step_count := 0

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
	practice = Practice.new(self)
	mb = MultiBallPlay.new(self)
	new_match()


## Breaks the sim <-> AI and sim <-> practice references, so all three can
## be freed (reference counting can't free a cycle): its owner calls this
## when the match is done. The sim isn't usable afterwards.
func dispose() -> void:
	if ai:
		ai.sim = null
	if practice:
		practice.sim = null
	if mb:
		mb.sim = null


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
	frames = frames * b.flight[0] / b.flight[1]      # MOON: longer, higher
	var rise := -b.z_fp - b.gravity_fp * frames * (frames - 1) / 2
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
	b.vz_fp += b.gravity_fp
	if b.wind:
		b.wind_tick += 1
		if b.wind_tick % K.WIND_PERIOD == 0:
			b.vy_fp += b.wind
	var net := K.to_fp(K.COURT_NET_X)
	if (px < net) != (b.x_fp < net):
		var h = net_crossing_height(px, pz, b.x_fp, b.z_fp)
		if h != null and h < K.to_fp(K.COURT_NET_HEIGHT):
			ev |= K.BALL_EVENT_NET_FAULT
	if pz > 0 and b.z_fp <= 0:
		var impact_vz := b.vz_fp - b.gravity_fp
		b.z_fp = 0
		b.vx_fp = retain(b.vx_fp, K.BALL_BOUNCE_PLANAR_256)
		b.vy_fp = retain(b.vy_fp, K.BALL_BOUNCE_PLANAR_256)
		b.vz_fp = -retain(impact_vz, b.bounce_256)
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
	_ball_physics()


## MOON, BOUNCY and WIND (port ADR-065) on the match's ball.
func _ball_physics() -> void:
	var mods := config.modifiers
	ball.gravity_fp = K.MOON_GRAVITY_FP if mods & K.MOD_MOON else K.BALL_GRAVITY_FP
	ball.flight = K.MOON_FLIGHT if mods & K.MOD_MOON else [1, 1]
	ball.bounce_256 = K.BOUNCY_VERTICAL_256 if mods & K.MOD_BOUNCY else K.BALL_BOUNCE_VERTICAL_256
	ball.wind = 0
	ball.wind_tick = 0


# --- Collision (collision.c) -------------------------------------------------------

static func _within(d: int, half: int) -> bool:
	return d >= -half and d <= half

static func in_reach(p: Player, b: Ball, grow: int = 0) -> bool:
	if not p.active or not b.active or b.rally_state != K.BALL_RALLY_LIVE:
		return false
	if not _within(b.x_fp - p.x_fp, K.to_fp(K.HIT_REACH_X) + grow):
		return false
	if not _within(b.y_fp - p.y_fp, K.to_fp(K.HIT_REACH_Y) + grow):
		return false
	return b.z_fp >= 0 and b.z_fp <= K.to_fp(K.HIT_REACH_Z) + grow

static func in_sweet_spot(p: Player, b: Ball, grow: int = 0) -> bool:
	return _within(b.x_fp - p.x_fp, K.to_fp(K.HIT_SWEET_X) + grow) \
		and _within(b.y_fp - p.y_fp, K.to_fp(K.HIT_SWEET_Y) + grow)

## Target and flight for a rally shot (ADR-019).
static func apply_targeted_shot(b: Ball, p: Player, intent: Intent, grow: int = 0) -> void:
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
	elif shot == K.SHOT_SLICE:
		tx = K.HIT_TARGET_SHORT_RIGHT if depth < 0 else K.HIT_TARGET_NEUTRAL_RIGHT
		pace = K.HIT_PACE_SLICE_FP
		min_frames = K.HIT_SLICE_MIN_FRAMES
		wide = K.HIT_SLICE_STRETCH_WIDE
		longer = K.HIT_SLICE_STRETCH_LONG
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
			longer = K.HIT_FAST_DROP_STRETCH_LONG if depth < 0 else K.HIT_DRIVE_STRETCH_LONG
		elif shot == K.SHOT_OVERHEAD:
			pace = K.HIT_PACE_OVERHEAD_FP
			min_frames = K.HIT_OVERHEAD_MIN_FRAMES
			max_frames = K.HIT_OVERHEAD_MAX_FRAMES
			wide = K.HIT_OVERHEAD_STRETCH_WIDE
			longer = K.HIT_OVERHEAD_STRETCH_LONG
		elif shot == K.SHOT_SPECIAL:
			pace = K.HIT_PACE_SPECIAL_FP
			min_frames = K.HIT_SPECIAL_MIN_FRAMES
			max_frames = K.HIT_SPECIAL_MAX_FRAMES
	pace = (pace * Paddles.power_mul(p.paddle)) >> 6
	# PICKLE SMASH is never stretched: it goes where it's aimed
	if not in_sweet_spot(p, b, grow) and shot != K.SHOT_SPECIAL:
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
	if shot == K.SHOT_OVERHEAD:
		flight = overhead_flight(b, tx, ty, flight, max_frames)
	elif shot == K.SHOT_SPECIAL:
		# PICKLE SMASH always clears the net, however low the ball
		flight = overhead_flight(b, tx, ty, flight, K.HIT_FLIGHT_MAX_FRAMES)
	launch(b, tx, ty, flight)

## A smash steep enough to land fast but not into the tape (ADR-053): the
## flight lengthens a frame at a time until it clears the net by
## HIT_OVERHEAD_NET_CLEAR, or reaches `longest` (then it may still find
## the net: a dumped overhead).
static func overhead_flight(b: Ball, tx: int, ty: int, flight: int, longest: int) -> int:
	var probe := Ball.new()
	probe.set_physics(b)
	while flight < longest:
		probe.x_fp = b.x_fp
		probe.y_fp = b.y_fp
		probe.z_fp = b.z_fp
		launch(probe, tx, ty, flight)
		if net_clearance(probe, flight) >= K.to_fp(K.COURT_NET_HEIGHT + K.HIT_OVERHEAD_NET_CLEAR):
			break
		flight += 1
	return flight

## The ball's height where its flight crosses the net (as simulate_step
## moves it), or a large number if it never does.
static func net_clearance(b: Ball, frames: int) -> int:
	var x := b.x_fp
	var z := b.z_fp
	var vz := b.vz_fp
	for f in frames:
		var nx := x + b.vx_fp
		var nz := z + vz
		vz += b.gravity_fp
		var h = net_crossing_height(x, z, nx, nz)
		if h != null:
			return h
		x = nx
		z = nz
	return 1 << 20

## Contacting slot + 1, or 0.
func resolve_player_hits() -> int:
	for i in K.MAX_PLAYERS:
		var p: Player = players[i]
		if p.state != K.STATE_ACTIVE or p.contact_consumed:
			continue
		# A team hits once (KNOWN_ISSUES #19).
		if ball.last_hitter < K.MAX_PLAYERS and (ball.last_hitter >= 2) == (i >= 2):
			continue
		var grow := grow_fp + (K.to_fp(K.MOD_BIG_REACH) if p.team == 0
			and config.perks & K.PERK_LONG_ARMS else 0)
		if not in_reach(p, ball, grow):
			continue
		p.contact_consumed = 1
		ball.last_hitter = i
		contact_volley = 1 if ball.bounce_count == 0 else 0
		ball.bounce_count = 0
		# PICKLE SMASH knocks its returner back: their return pops up soft
		var returned := smash_team >= 0 and p.team != smash_team
		if returned:
			p.shot_type = K.SHOT_SOFT
		smash_team = p.team if p.shot_type == K.SHOT_SPECIAL else -1
		# a swing at a falling ball overhead is a smash (ADR-053)
		if config.overhead and not (config.modifiers & K.MOD_DINK_OR_DIE) \
				and (p.shot_type == K.SHOT_STANDARD or p.shot_type == K.SHOT_DRIVE) \
				and ball.vz_fp < 0 \
				and ball.z_fp >= K.to_fp(K.HIT_OVERHEAD_Z):
			p.shot_type = K.SHOT_OVERHEAD
		apply_targeted_shot(ball, p, special_aim(i) if p.shot_type == K.SHOT_SPECIAL
			else (pop_up_aim(i) if returned else intents[i]), grow)
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

static func _approach_zero(v: int, friction := K.PLAYER_FRICTION_FP) -> int:
	if v > friction:
		return v - friction
	if v < -friction:
		return v + friction
	return 0

const ANIM_IDLE_CELS := 2
const ANIM_RUN_CELS := 4
const IDLE_CEL_FRAMES := 20
const RUN_CEL_FRAMES := 6

static func player_step(p: Player, intent: Intent, ice := false, remaster := false) -> void:
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
	if remaster and intent.short_held and p.state < K.STATE_WINDUP:
		limit = limit * K.SHORT_HELD_SPEED[0] / K.SHORT_HELD_SPEED[1]
	var accel := K.PLAYER_ICE_ACCEL_FP if ice else K.PLAYER_ACCEL_FP
	if mx and my:
		accel = K.PLAYER_ICE_DIAGONAL_ACCEL_FP if ice else K.PLAYER_DIAGONAL_ACCEL_FP
		limit = K.DIAGONAL_LIMIT[limit & 31]
	if mx > 0:
		p.vx_fp += accel
	elif mx < 0:
		p.vx_fp -= accel
	else:
		p.vx_fp = _approach_zero(p.vx_fp, K.PLAYER_ICE_FRICTION_FP if ice else K.PLAYER_FRICTION_FP)
	if my > 0:
		p.vy_fp += accel
	elif my < 0:
		p.vy_fp -= accel
	else:
		p.vy_fp = _approach_zero(p.vy_fp, K.PLAYER_ICE_FRICTION_FP if ice else K.PLAYER_FRICTION_FP)
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
			player_step(p, intents[p.logical_input_slot], ice, config.overhead != 0)

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

## SIDE-OUT in doubles: the players keep their sides here (as in rally
## scoring), so the server is a person, not a lane: the side-out's first
## server is the one on the side the score's parity names, the second
## their partner, each serving from their own side.
func side_out_doubles() -> bool:
	return config.modifiers & K.MOD_SIDE_OUT != 0 and config.mode == K.MODE_DOUBLES

func serve_setup(team: int) -> void:
	var even: bool = (team_score[team] & 1) == 0
	var server_y: int
	if (team == 0) == even:
		server_y = K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y
	else:
		server_y = K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y
	if side_out_doubles():
		if first_server < 0 or (first_server >= 2) != (team == 1):
			first_server = _serve_slot_for_lane(team, server_y < K.COURT_CENTERLINE_Y)
		# the game's opener serves on as "server 2": one lost rally sides out
		var slot := first_server if server_number == 1 or opening \
			or not players[first_server ^ 1].active else first_server ^ 1
		server_y = K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y if lane_top(slot) \
			else K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y
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
	if multi_on:
		return mb.serve_team_now     # MULTI BALL: the side a ball was "served" from
	return 1 if server_index >= 2 else 0

func resolve_point(losing_team: int, fault: int) -> void:
	if phase == K.PHASE_POINT_RESULT or phase == K.PHASE_MATCH_RESULT:
		return
	if multi_on:
		mb.point(losing_team, fault)
		return
	var winner := 1 - losing_team
	point_winner = winner
	last_fault = fault
	momentum_slot = -1
	smash_team = -1
	# SIDE-OUT: only the serving side scores
	point_scored = not (config.modifiers & K.MOD_SIDE_OUT) or winner == serving_team
	if point_scored:
		team_score[winner] += 1
	_second_wind()
	for i in K.MAX_PLAYERS:
		if players[i].active and players[i].team == winner:
			fill_meter(i, K.SPECIAL_FILL_POINT)
	# HOT HAND (port ADR-087): three in a row fill the left side's meters
	if config.perks & K.PERK_HOT_HAND:
		hot_streak = hot_streak + 1 if winner == 0 else 0
		if hot_streak >= K.HOT_HAND_POINTS and specials_on():
			hot_streak = 0
			for i in K.MAX_PLAYERS:
				if players[i].active and players[i].team == 0:
					meter[i] = K.SPECIAL_METER_MAX
			emit(K.EVENT_PERK, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), K.PERK_HOT_HAND)
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
	var team: int = players[slot].team
	# DINK OR DIE (port ADR-065): a drive loses the point
	if config.modifiers & K.MOD_DINK_OR_DIE and players[slot].shot_type == K.SHOT_DRIVE:
		resolve_point(team, K.FAULT_DRIVE)
		return
	if required_bounce == K.REQUIRED_BOUNCE_SERVE:
		resolve_point(team, K.FAULT_EARLY_VOLLEY)
		return
	if required_bounce == K.REQUIRED_BOUNCE_RETURN and team == _server_team():
		resolve_point(team, K.FAULT_EARLY_VOLLEY)
		return
	# ADR-055, port-only: a legal volley still can't be made from inside
	# your own kitchen.
	if contact_volley and court_in_kitchen(players[slot].x_fp, players[slot].y_fp, team):
		# KITCHEN PASS (port ADR-087): the left side's first one is forgiven
		if team == 0 and config.perks & K.PERK_KITCHEN_PASS and not kitchen_pass_used:
			kitchen_pass_used = true
			emit(K.EVENT_PERK, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), K.PERK_KITCHEN_PASS)
			return
		resolve_point(team, K.FAULT_KITCHEN)

func rules_process_ball_events(ev: int) -> void:
	if ev & K.BALL_EVENT_BOUNCE:
		momentum_slot = -1           # MOMENTUM: the ball bounced, balance back
	if phase == K.PHASE_SERVE_FAULT:
		# SECOND SERVE (port ADR-087): the left side's first fault is served again
		if _last_hitter_team() == 0 and config.perks & K.PERK_SECOND_SERVE \
				and not second_serve_used and not multi_on:
			second_serve_used = true
			emit(K.EVENT_PERK, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), K.PERK_SECOND_SERVE)
			_begin_serve(serving_team)
			return
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
	# LUCKY LINE (port ADR-087): the left side's first ball out by a hair is in
	if ev & K.BALL_EVENT_OUT and hitter == 0 and side != hitter and config.perks & K.PERK_LUCKY_LINE \
			and not lucky_line_used \
			and not Replay.check(ball.x_fp, ball.y_fp, Replay.MIN_SHOTS, K.FAULT_OUT).is_empty():
		lucky_line_used = true
		emit(K.EVENT_PERK, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), K.PERK_LUCKY_LINE)
		ev &= ~K.BALL_EVENT_OUT
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
	events.append([kind, x, y, detail, step_count])

func drain_events() -> Array:
	var e := events
	events = []
	return e

func set_phase(p: int) -> void:
	phase = p
	phase_timer = 0

func score_wins(score: int, other: int) -> bool:
	if config.modifiers & K.MOD_SUDDEN_DEATH:
		return score >= 1                # SUDDEN DEATH (port ADR-065)
	return score >= config.points_to_win \
		and (not (config.modifiers & K.MOD_WIN_BY_2) or score >= other + 2)

func team_won(team: int) -> bool:
	return score_wins(team_score[team], team_score[team ^ 1])

func match_point(team: int) -> bool:
	# SIDE-OUT: only the serving side can win the next rally's point
	if config.modifiers & K.MOD_SIDE_OUT and team != serving_team:
		return false
	return score_wins(team_score[team] + 1, team_score[team ^ 1])

## SECOND WIND (port ADR-087): while the right side has match point, the
## left side's top speed is up SECOND_WIND_FP (to the most there is).
func _second_wind() -> void:
	if not (config.perks & K.PERK_SECOND_WIND):
		return
	var on := match_point(1) and not team_won(1)
	for i in K.MAX_PLAYERS:
		var p: Player = players[i]
		if p.team != 0:
			continue
		if on and wind_add[i] == 0:
			wind_add[i] = mini(K.SECOND_WIND_FP, 31 - p.max_speed_fp)
			p.max_speed_fp += wind_add[i]
		elif not on and wind_add[i] > 0:
			p.max_speed_fp -= wind_add[i]
			wind_add[i] = 0


func _game_initialize() -> void:
	paused = 0
	last_fault = K.FAULT_NONE
	point_winner = K.NO_TEAM
	match_winner = K.NO_TEAM
	# HEAD START (port ADR-087): the left side starts a point up
	team_score = [1 if config.perks & K.PERK_HEAD_START else 0, 0]
	kitchen_pass_used = false
	second_serve_used = false
	lucky_line_used = false
	hot_streak = 0
	wind_add = [0, 0, 0, 0]
	required_bounce = K.REQUIRED_BOUNCE_NONE
	serving_team = 0
	momentum_slot = -1
	server_number = 2                # SIDE-OUT: "0-0-2"
	first_server = -1
	opening = true
	point_scored = true
	hit_stop = 0
	shot_serial = 0
	frame_count = 0
	set_phase(K.PHASE_SERVE_SETUP)

func _begin_serve(team: int) -> void:
	for p in players:
		p.pose = K.POSE_NONE
	if config.modifiers & K.MOD_WIND:
		ball.wind = K.WIND_DIRS[(frame_count >> 3) & 7]   # WIND: a new one each serve
		ball.wind_tick = 0
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
	ball_tick = 0
	ball_steps = 0
	popcorn_level = 0
	# BALL SPEED (port ADR-073): the ROM's own slow ball (KID, EASY), fewer
	# ball steps a cycle, the same flights; at 100 the difficulty's pace
	var speed := ball_speed()
	ball_paced = (config.modifiers & (K.MOD_FAST_BALL | K.MOD_POPCORN)) != 0 \
		or ball_per_cycle(config.difficulty, speed) != BALL_CYCLE
	if ball_paced:
		ball_pace = make_ball_pace(config.difficulty, config.modifiers, speed)
	grow_fp = K.to_fp(K.MOD_BIG_REACH) if config.modifiers & K.MOD_BIG_BALL else 0
	ice = (config.modifiers & K.MOD_ICE) != 0       # players_set_ice
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
		# ADR-047 stage 4: a career player's hat shifts their paddle's
		# stats (the paddle tables hold every pairing).
		if i == 0 and config.career_p1 and config.career:
			p.paddle = Paddles.profile(config.paddle[0], config.career.hat)
		# ROAD TRIP (port ADR-087): the slot's own stats, not its paddle's
		var ts: Array = config.trip_stats[i] if config.trip else []
		if ts.size() == 4:
			p.paddle = Paddles.trip_profile(int(ts[0]), int(ts[1]), int(ts[2]))
			if not p.cpu_controlled:
				p.max_speed_fp = Paddles.trip_feet(int(ts[3]))
		if p.cpu_controlled:
			var style: SimTypes.AiStyle = Opponents.slot_style(config, i).copy()
			# The top speed is the style's before the difficulty (game.c):
			# the difficulty's speed change never reaches the running speed.
			# The ladder is tuned so; the port copies it (port ADR-059).
			p.max_speed_fp = style.speed
			if config.difficulty != K.DIFFICULTY_MEDIUM \
					and not config.human[i & 2] and not config.human[(i & 2) + 1]:
				Opponents.apply_difficulty(style, config.difficulty)
			# smart play (port ADR-094): a CPU heading for the kitchen volleys
			if config.smarts.size() == K.MAX_PLAYERS * K.SMART_KNOBS:
				ai.smart[i] = config.smarts.slice(i * K.SMART_KNOBS, (i + 1) * K.SMART_KNOBS)
				if int(ai.smart[i][K.SMART_KITCHEN]) >= 50:
					style.volley = 1
			ai.styles[i] = style
			ai.slots[i].late_period = late_period(style.late_period, config.cpu_errors)
			ai.slots[i].reaction_frames = style.reaction

## The tuning panel (port ADR-074), between frames: BALL SPEED and CPU
## ERRORS on the live match, as if it had started with them. An input to
## the sim, like a pad's; the view never calls it on its own.
func retune(speed: int, errors: int) -> void:
	config.ball_speed = speed
	config.cpu_errors = errors
	var was_paced := ball_paced
	var s := ball_speed()
	ball_paced = (config.modifiers & (K.MOD_FAST_BALL | K.MOD_POPCORN)) != 0 \
		or ball_per_cycle(config.difficulty, s) != BALL_CYCLE
	if ball_paced:
		ball_pace = make_ball_pace(config.difficulty, config.modifiers, s)
		for level in popcorn_level:
			popcorn_add(ball_pace, level)
		if not was_paced:
			ball_tick = 0
	for i in K.MAX_PLAYERS:
		if players[i].cpu_controlled and ai.styles[i] and not (attract and i == 0):
			ai.slots[i].late_period = late_period(ai.styles[i].late_period, errors)

## BALL SPEED's percent, within its range (port ADR-071, 073).
func ball_speed() -> int:
	return clampi(config.ball_speed, K.BALL_SPEED_MIN, K.BALL_SPEED_MAX)

## The tuning panel's smart play (port ADR-094), between frames: each CPU
## slot's KITCHEN, TOGETHER and AIM from `smarts` (MatchConfig.smarts'
## shape), as if the match had started with them. An input, like retune.
func retune_smarts(smarts: Array) -> void:
	config.smarts = smarts.duplicate()
	for i in K.MAX_PLAYERS:
		if not players[i].cpu_controlled or (attract and i == 0) or ai.styles[i] == null:
			continue
		if smarts.size() == K.MAX_PLAYERS * K.SMART_KNOBS:
			ai.smart[i] = smarts.slice(i * K.SMART_KNOBS, (i + 1) * K.SMART_KNOBS)
			if int(ai.smart[i][K.SMART_KITCHEN]) >= 50:
				ai.styles[i].volley = 1
		else:
			ai.smart[i] = []


## CPU ERRORS (port ADR-073): a CPU swings late every `period`th return;

## at `percent` of the ROM's errors, that many times as rarely (0: never).
## At 100 the period is the style's.
static func late_period(period: int, percent: int) -> int:
	if period == 0 or percent == 100:
		return period
	if percent <= 0:
		return 0
	return clampi(period * 100 / percent, 1, 255)

## Fresh match (RST-01): every module re-initialized.
func new_match() -> void:
	meter = [0, 0, 0, 0]
	smash_team = -1
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
	multi_on = config.modifiers & K.MOD_MULTI_BALL != 0 and not config.practice
	if config.practice:
		practice.begin()            # ADR-028: no serve
	elif multi_on:
		mb.begin()
	else:
		_begin_serve(0)
	if attract:
		ai.slots[0].late_period = K.ATTRACT_LATE_PERIOD

## A CPU-vs-CPU demo (or bot run): slot 0 is driven by the AI too.
func start_attract() -> void:
	attract = 1
	new_match()

func contact(slot: int) -> void:
	var p: Player = players[slot]
	if p.shot_type == K.SHOT_SPECIAL:
		meter[slot] = 0                  # PICKLE SMASH spends the meter
	else:
		fill_meter(slot, K.SPECIAL_FILL_HIT)
	shot_serial = (shot_serial + 1) & 0xff
	p.flash_timer = K.HIT_FLASH_FRAMES
	hit_stop = K.HIT_STOP_FRAMES
	emit(K.EVENT_HIT, K.from_fp(ball.x_fp), K.from_fp(ball.y_fp), slot | (p.shot_type << 4))
	# MOMENTUM: a volley carries its hitter until the next bounce or hit
	if config.modifiers & K.MOD_MOMENTUM:
		momentum_slot = slot if contact_volley else -1
	# POPCORN: each hit in the rally adds pace, up to the cap.
	if (config.modifiers & K.MOD_POPCORN) and popcorn_level < K.MOD_POPCORN_LEVELS \
			and config.practice == 0:
		popcorn_add(ball_pace, popcorn_level)
		popcorn_level += 1

## The tick each popcorn level starts at, in its stride (modifiers.c). None
## is 2 mod 3, FAST BALL's extra step: a tick gains one or the other.
const POPCORN_OFFSET := [0, 6, 3, 9, 1, 7]

## modifiers_popcorn_add / _remove: level `level`'s steps, one every
## MOD_POPCORN_STRIDE ticks through the pace table.
static func popcorn_add(pace: Array, level: int) -> void:
	var i: int = POPCORN_OFFSET[level]
	while i < BALL_PACE_TICKS:
		pace[i] += 1
		i += K.MOD_POPCORN_STRIDE

static func popcorn_remove(pace: Array, level: int) -> void:
	var i: int = POPCORN_OFFSET[level]
	while i < BALL_PACE_TICKS:
		pace[i] -= 1
		i += K.MOD_POPCORN_STRIDE

static func ball_per_cycle(difficulty: int, percent: int = 100) -> int:
	var base := BALL_CYCLE
	if difficulty == K.DIFFICULTY_KID:
		base = BALL_CYCLE * 2 / 3
	elif difficulty == K.DIFFICULTY_EASY:
		base = BALL_CYCLE * 3 / 4
	return (base * percent + 50) / 100

## Even spreading: a step each time the running share passes a cycle.
## FAST BALL (ADR-033) adds a step on every 3rd tick.
static func make_ball_pace(difficulty: int, modifiers: int = 0, percent: int = 100) -> Array:
	var per := ball_per_cycle(difficulty, percent)
	var pace := []
	var share := 0
	var tick := 0
	for i in BALL_PACE_TICKS:
		var n := 0
		share += per
		while share >= BALL_CYCLE:
			share -= BALL_CYCLE
			n += 1
		if (modifiers & K.MOD_FAST_BALL) and tick % 3 == 2:
			n += 1
		pace.append(n)
		tick += 1
		if tick >= BALL_CYCLE:
			tick = 0
	return pace

## Ball steps `frames` frames from now (0 = this frame): 0, 1, or 2.
func steps_ahead(frames: int) -> int:
	return ball_pace[ball_tick + frames]

func step_ball() -> int:
	if not ball_paced:
		ball_steps += 1
		return simulate_step(ball)
	var ev := 0
	for n in steps_ahead(0):
		ball_steps += 1
		ev |= simulate_step(ball)
	ball_tick += 1
	if ball_tick >= BALL_CYCLE:
		ball_tick = 0
	return ev

## LAVA (ADR-033): a ground point past your own kitchen line toward the
## net, between the sidelines.
## COURT_IN_KITCHEN_FP (court.h): the kitchen line counts as in, for the
## volley fault (SNES ADR-052). LAVA's test (in_kitchen) leaves it out.
static func court_in_kitchen(x_fp: int, y_fp: int, team: int) -> bool:
	if y_fp < K.to_fp(K.COURT_SIDELINE_TOP) or y_fp > K.to_fp(K.COURT_SIDELINE_BOTTOM):
		return false
	if team:
		return x_fp <= K.to_fp(K.COURT_KITCHEN_RIGHT_X) and x_fp > K.to_fp(K.COURT_NET_X)
	return x_fp >= K.to_fp(K.COURT_KITCHEN_LEFT_X) and x_fp < K.to_fp(K.COURT_NET_X)

static func in_kitchen(x_fp: int, y_fp: int, team: int) -> bool:
	if y_fp < K.to_fp(K.COURT_SIDELINE_TOP) or y_fp > K.to_fp(K.COURT_SIDELINE_BOTTOM):
		return false
	if team:
		return x_fp < K.to_fp(K.COURT_KITCHEN_RIGHT_X) and x_fp > K.to_fp(K.COURT_NET_X)
	return x_fp > K.to_fp(K.COURT_KITCHEN_LEFT_X) and x_fp < K.to_fp(K.COURT_NET_X)

## A CPU's target x moved behind its kitchen line.
static func lava_target(x: int, team: int) -> int:
	if team:
		return maxi(x, K.COURT_KITCHEN_RIGHT_X + K.MOD_LAVA_MARGIN)
	return mini(x, K.COURT_KITCHEN_LEFT_X - K.MOD_LAVA_MARGIN)

## MOMENTUM: in the kitchen past the forgiven margin.
static func momentum_in_kitchen(x_fp: int, y_fp: int, team: int) -> bool:
	var grace := K.to_fp(K.MOMENTUM_GRACE)
	return in_kitchen(x_fp + (grace if team else -grace), y_fp, team)

func _update_live() -> void:
	if specials_on() and frame_count % K.SPECIAL_FILL_PERIOD == 0:
		for i in K.MAX_PLAYERS:
			if players[i].active:
				fill_meter(i, 1)
	if config.modifiers & K.MOD_LAVA:
		for p in players:
			if p.active and in_kitchen(p.x_fp, p.y_fp, p.team):
				resolve_point(p.team, K.FAULT_LAVA)
				break
		if phase != K.PHASE_LIVE:
			return
	if momentum_slot >= 0:
		var mp: Player = players[momentum_slot]
		if momentum_in_kitchen(mp.x_fp, mp.y_fp, mp.team):
			resolve_point(mp.team, K.FAULT_MOMENTUM)
			return
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
	# POPCORN: back to the match's pace for the next serve. Not on the
	# result's first frame, which records the rally.
	if popcorn_level and phase_timer == 2:
		while popcorn_level:
			popcorn_level -= 1
			popcorn_remove(ball_pace, popcorn_level)
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
	_begin_serve(next_server_team(winner))

## Who serves next: the rally's winner (rally scoring); with SIDE-OUT the
## server keeps serving while their side scores, a lost rally passes it to
## the partner (doubles, server 1) or sides out.
func next_server_team(winner: int) -> int:
	if not (config.modifiers & K.MOD_SIDE_OUT) or winner == serving_team:
		return winner
	if side_out_doubles() and server_number == 1:
		server_number = 2
		return serving_team
	server_number = 1
	first_server = -1
	opening = false
	return winner

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
	if config.practice:
		practice.update()
		return
	match phase:
		K.PHASE_SERVE_SETUP, K.PHASE_SERVE_TOSS:
			serve_update()
		K.PHASE_LIVE:
			if multi_on:
				mb.update()
			else:
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
	step_count += 1
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
		_ai_update(0)
		intents[0].hit_pressed |= pressed
	if attract:
		var think: bool = (ai.slots[0].has_target or (lc & 3) == 0) \
			if config.mode == K.MODE_DOUBLES else (loop_count & 1) == 1
		if think:
			_ai_update(0)
		else:
			ai.hold_intent(0, intents[0])
	elif config.difficulty == K.DIFFICULTY_KID:
		# main.c assists slots 0-2 (2P sat on slot 2); multiplayer (PORT-16)
		# can put a human on slot 3 too
		for slot in [0, 1, 2, 3]:
			if slot == 0 and p1_bot:
				continue                 # the stats bot plays its own swings
			if owners[slot] == K.OWNER_HUMAN and players[slot].active \
					and _ai_assist(slot):
				intents[slot].hit_pressed = 1
				intents[slot].shot = K.SHOT_STANDARD
	# CPU_THINKS (cpu_schedule.h, tuning v4): the stagger counts the
	# match's frames (frame_count, 0 at each new match), not the loop since
	# power-on, so the same inputs play the same match.
	var cpu_frame := frame_count & 0xff
	for slot in [1, 2, 3]:
		if owners[slot] == K.OWNER_CPU and players[slot].active:
			if not players[slot ^ 1].active or ai.slots[slot].has_target \
					or _serving(slot) or (cpu_frame & 3) == slot:
				_ai_update(slot)
			else:
				ai.hold_intent(slot, intents[slot])
	# SPECIALS: a CPU (and the bot) with a full meter smashes its next
	# standard or drive; a SPECIAL press without one is a standard hit
	# in a rally only (a serve isn't a smash)
	for slot in K.MAX_PLAYERS:
		var it: Intent = intents[slot]
		var ready := special_ready(slot) and phase == K.PHASE_LIVE
		if (owners[slot] == K.OWNER_CPU or (slot == 0 and (p1_bot or attract))) \
				and ready and it.hit_pressed \
				and (it.shot == K.SHOT_STANDARD or it.shot == K.SHOT_DRIVE):
			it.shot = K.SHOT_SPECIAL
		if it.shot == K.SHOT_SPECIAL and not ready:
			it.shot = K.SHOT_STANDARD
	# DINK OR DIE: the CPUs (and the bot) play the soft shot for a drive
	if config.modifiers & K.MOD_DINK_OR_DIE:
		for slot in K.MAX_PLAYERS:
			if (owners[slot] == K.OWNER_CPU or (slot == 0 and (p1_bot or attract))) \
					and intents[slot].shot == K.SHOT_DRIVE:
				intents[slot].shot = K.SHOT_SOFT
	game_update()
	loop_count = (loop_count + 1) & 0xffff


# --- SPECIALS (port ADR-080) --------------------------------------------------------------

## SPECIALS is on for this match (not practice or MULTI BALL: no rallies
## of one ball to win).
func specials_on() -> bool:
	return config.modifiers & K.MOD_SPECIALS != 0 and not config.practice and not multi_on


## The slot's meter is full: SPECIAL plays PICKLE SMASH.
func special_ready(slot: int) -> bool:
	return specials_on() and meter[slot] >= K.SPECIAL_METER_MAX


## PICKLE SMASH's aim: deep, down the sideline away from the other side
## (the lane their players are furthest from), whatever was held.
func special_aim(slot: int) -> Intent:
	var team: int = players[slot].team
	var it := Intent.new()
	it.aim_x = -1 if team else 1
	var sum := 0
	var n := 0
	for p in players:
		if p.active and p.team != team:
			sum += p.y_fp
			n += 1
	var their_y := sum / maxi(n, 1)
	it.aim_y = 1 if their_y < K.to_fp(K.COURT_CENTERLINE_Y) else -1
	return it


## A PICKLE SMASH's return: a lob to the middle of the court, whatever was
## held (the paddle was knocked back).
func pop_up_aim(slot: int) -> Intent:
	var it := Intent.new()
	it.aim_x = 0
	it.aim_y = 0
	return it


func fill_meter(slot: int, n: int) -> void:
	if specials_on():
		meter[slot] = mini(meter[slot] + n, K.SPECIAL_METER_MAX)


# --- MULTI BALL (port ADR-067): sim/multi_ball.gd --------------------------------------------

var multi_on := false
var mb: MultiBallPlay
## MULTI BALL's balls in play, oldest first (MultiBallPlay.Entry).
var multi: Array:
	get: return mb.balls

func _ai_update(slot: int) -> void:
	mb.ai_update(slot)

func _ai_assist(slot: int) -> bool:
	return mb.ai_assist(slot)


# --- Trace -------------------------------------------------------------------------------------

## The P1 stand-in's skill (test_support.h test_bot_skill): mistimes every
## `late`th shot; reaction and foot speed vary by match index.
func set_bot_skill(late: int, match_index: int) -> void:
	ai.slots[0].late_period = late
	ai.slots[0].reaction_frames = (match_index * 7) % 20
	players[0].max_speed_fp = 16 + (match_index % 3) * 4


## The whole state (port ADR-100, sim/sim_state.gd): load_state(save_state())
## leaves the sim stepping exactly as before. snapshot() is the traced part.
func save_state() -> Array:
	return SimState.save(self)

func load_state(state: Array) -> bool:
	return SimState.load_into(self, state)

## The whole state's hash, for online's desync check.
func state_hash() -> int:
	return hash(save_state())


## The traced simulation state (GameState, ServeState, players, ball, AI
## slots), as the golden trace compares it.
func snapshot() -> Array:
	var s := [paused, phase, phase_timer, last_fault, point_winner,
		team_score[0], team_score[1], required_bounce, serving_team,
		match_winner, hit_stop, shot_serial, frame_count, server_index,
		receiver_index, landing_pending, serve_requested, serve_aim_x,
		serve_aim_y, server_y_fp]
	if config.modifiers & K.MOD_SIDE_OUT:
		s.append_array([server_number, first_server, point_scored, opening])
	if config.modifiers & K.MOD_MOMENTUM:
		s.append(momentum_slot)
	if config.modifiers & K.MOD_SPECIALS:
		s.append_array(meter)
		s.append(smash_team)
	if multi_on:
		s.append_array([mb.timer, mb.launched])
		for m: MultiBallPlay.Entry in mb.balls:
			s.append_array(m.ball.to_array())
			s.append_array([m.required_bounce, m.landing_pending, m.contact_volley, m.shot_serial,
				m.ball_steps, m.serve_team, m.blink])
	s.append_array(ball.to_array())
	for p in players:
		s.append_array(p.to_array())
	for a in ai.slots:
		s.append_array(a.to_array())
	return s
