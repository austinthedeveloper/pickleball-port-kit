## Port of reference/snes-src/test/test_collision.c (HIT-01/02, ADR-019/020).
extends TestSuite

var sim: Sim
var paddle := Paddles.STANDARD
var offset_y := 0
var push := K.HIT_PUSH_DEEP      ## the CPU's push (SNES ADR-076)
var overhead := 1                ## 0: the ROM's rules (the conformance traces')


func _reset() -> void:
	sim = Sim.new()
	sim.config.overhead = overhead
	for i in K.MAX_PLAYERS:
		sim.players[i] = SimTypes.Player.new()
		sim.players[i].contact_consumed = 0
		sim.intents[i].clear()
	var p: SimTypes.Player = sim.players[0]
	p.paddle = Paddles.STANDARD
	p.active = 1
	p.x_fp = K.to_fp(64)
	p.y_fp = K.to_fp(112)
	sim.ball = SimTypes.Ball.new()
	sim.ball.active = 1
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.ball.x_fp = p.x_fp
	sim.ball.y_fp = p.y_fp
	sim.ball.z_fp = K.to_fp(10)


func _lands_near(x: int, y: int) -> void:
	var ev := 0
	for f in 60:
		ev = Sim.simulate_step(sim.ball)
		if ev & K.BALL_EVENT_BOUNCE:
			break
	check(ev & K.BALL_EVENT_BOUNCE, "bounced")
	check(absi(sim.ball.x_fp - K.to_fp(x)) < K.to_fp(3), "lands near x %d (%d)" % [x, K.from_fp(sim.ball.x_fp)])
	check(absi(sim.ball.y_fp - K.to_fp(y)) < K.to_fp(3), "lands near y %d (%d)" % [y, K.from_fp(sim.ball.y_fp)])
	check(not (ev & K.BALL_EVENT_OUT), "in")


func test_reach_boundaries_are_inclusive() -> void:
	_reset()
	var p: SimTypes.Player = sim.players[0]
	var b := sim.ball
	b.x_fp += K.to_fp(K.HIT_REACH_X)
	b.y_fp -= K.to_fp(K.HIT_REACH_Y)
	b.z_fp = K.to_fp(K.HIT_REACH_Z)
	check(Sim.in_reach(p, b), "edge of reach")
	b.x_fp += 1
	check(not Sim.in_reach(p, b), "past x")
	b.x_fp -= 1
	b.y_fp -= 1
	check(not Sim.in_reach(p, b), "past y")
	b.y_fp += 1
	b.z_fp += 1
	check(not Sim.in_reach(p, b), "past z")


func test_windup_cannot_contact() -> void:   # HIT-02
	_reset()
	sim.players[0].state = K.STATE_WINDUP
	eq(sim.resolve_player_hits(), 0)
	eq(sim.players[0].contact_consumed, 0)
	eq(sim.ball.last_hitter, K.BALL_NO_HITTER)


func test_active_overlap_contacts_once() -> void:   # HIT-01
	_reset()
	sim.players[0].state = K.STATE_ACTIVE
	var contacts := 0
	for f in K.PLAYER_ACTIVE_FRAMES:
		contacts += sim.resolve_player_hits()
	eq(contacts, 1)
	eq(sim.players[0].contact_consumed, 1)
	eq(sim.ball.last_hitter, 0)
	check(sim.ball.vx_fp > 0 and sim.ball.vz_fp > 0, "toward the right, upward")
	_lands_near(K.HIT_TARGET_NEUTRAL_RIGHT, K.HIT_TARGET_LANE_CENTER)


func test_team_direction_and_live_ball_requirement() -> void:
	_reset()
	sim.players[0].team = 1
	sim.players[0].state = K.STATE_ACTIVE
	eq(sim.resolve_player_hits(), 1)
	check(sim.ball.vx_fp < 0, "right team hits left")
	_reset()
	sim.players[0].state = K.STATE_ACTIVE
	sim.ball.rally_state = K.BALL_RALLY_INACTIVE
	eq(sim.resolve_player_hits(), 0)


func test_team_hits_once() -> void:   # KNOWN_ISSUES #19
	_reset()
	var p1: SimTypes.Player = sim.players[1]
	p1.active = 1
	p1.x_fp = sim.players[0].x_fp
	p1.y_fp = sim.players[0].y_fp
	p1.state = K.STATE_ACTIVE
	sim.ball.last_hitter = 0
	eq(sim.resolve_player_hits(), 0, "teammate can't re-hit")
	var p2: SimTypes.Player = sim.players[2]
	p2.active = 1
	p2.team = 1
	p2.x_fp = p1.x_fp
	p2.y_fp = p1.y_fp
	p2.state = K.STATE_ACTIVE
	p1.active = 0
	p1.state = K.STATE_IDLE
	eq(sim.resolve_player_hits(), 3, "opponent can")
	eq(sim.ball.last_hitter, 2)


func test_directional_target_lanes() -> void:
	for c in [[0, 0, K.HIT_TARGET_NEUTRAL_RIGHT, K.HIT_TARGET_LANE_CENTER],
			[0, -1, K.HIT_TARGET_NEUTRAL_RIGHT, K.HIT_TARGET_LANE_TOP],
			[0, 1, K.HIT_TARGET_NEUTRAL_RIGHT, K.HIT_TARGET_LANE_BOTTOM],
			[1, 0, K.HIT_TARGET_DEEP_RIGHT, K.HIT_TARGET_LANE_CENTER],
			[-1, 0, K.HIT_TARGET_SHORT_RIGHT, K.HIT_TARGET_LANE_CENTER]]:
		_reset()
		sim.players[0].state = K.STATE_ACTIVE
		sim.intents[0].aim_x = c[0]
		sim.intents[0].aim_y = c[1]
		sim.intents[0].push = K.HIT_PUSH_DEEP
		eq(sim.resolve_player_hits(), 1)
		_lands_near(c[2], c[3])


func _fly_shot(team: int, shot: int, aim_x: int) -> Array:
	_reset()
	var p: SimTypes.Player = sim.players[0]
	p.paddle = paddle
	sim.ball.y_fp = p.y_fp + K.to_fp(offset_y)
	p.x_fp = K.to_fp(146 if team else 110)
	sim.ball.x_fp = p.x_fp
	p.team = team
	p.shot_type = shot
	p.state = K.STATE_ACTIVE
	sim.intents[0].aim_x = aim_x
	sim.intents[0].push = push
	eq(sim.resolve_player_hits(), 1)
	var apex := 0
	var frames := 0
	while not (Sim.simulate_step(sim.ball) & K.BALL_EVENT_BOUNCE):
		apex = maxi(apex, sim.ball.z_fp)
		frames += 1
		if frames >= 80:
			runner.fail("shot never landed")
			break
	return [frames, apex]


func test_shot_types() -> void:   # ADR-019
	var std := _fly_shot(0, K.SHOT_STANDARD, 1)
	check(std[0] + 1 < K.HIT_FLIGHT_MAX_FRAMES, "standard within max flight")
	check(absi(sim.ball.x_fp - K.to_fp(K.HIT_TARGET_DEEP_RIGHT)) < K.to_fp(3), "standard deep")
	var drive := _fly_shot(0, K.SHOT_DRIVE, 1)
	check(drive[0] < std[0] and drive[1] < std[1], "drive sooner and flatter")
	var lob := _fly_shot(0, K.SHOT_SOFT, 1)
	check(lob[0] + 1 >= K.HIT_LOB_MIN_FRAMES, "lob long")
	check(lob[1] > std[1] + K.to_fp(10), "lob high")
	_fly_shot(0, K.SHOT_SOFT, -1)
	check(sim.ball.x_fp > K.to_fp(K.COURT_NET_X) and sim.ball.x_fp < K.to_fp(K.COURT_KITCHEN_RIGHT_X),
		"dink lands in the opponent's kitchen")
	_fly_shot(1, K.SHOT_SOFT, 1)
	check(sim.ball.x_fp < K.to_fp(K.COURT_NET_X) and sim.ball.x_fp > K.to_fp(K.COURT_KITCHEN_LEFT_X),
		"right team's dink lands in the left kitchen")


## SNES ADR-076: aimed toward the net, a standard shot or drive lands
## deeper the longer the push, the old deep target at HIT_PUSH_DEEP, past
## the baseline from HIT_PUSH_OUT_FRAMES, never past HIT_PUSH_MAX_X; the
## right team mirrors. A lob ignores it. The ROM's rules (the remaster's
## slack is test_push_slack).
func test_push_depth() -> void:
	overhead = 0
	eq(K.HIT_PUSH_START_X + (K.HIT_PUSH_DEEP >> K.HIT_PUSH_SHIFT), K.HIT_TARGET_DEEP_RIGHT)
	eq([K.HIT_PUSH_START_X, K.HIT_PUSH_MAX_X, K.HIT_PUSH_DEEP, K.HIT_PUSH_OUT_FRAMES],
		[212, 252, 32, 58], "tuning.json v5")
	for shot in [K.SHOT_STANDARD, K.SHOT_DRIVE]:
		var last := 0
		for n in [1, 20, K.HIT_PUSH_DEEP, K.HIT_PUSH_OUT_FRAMES - 1, K.HIT_PUSH_OUT_FRAMES, 200, 255]:
			push = n
			_fly_shot(0, shot, 1)
			var x := K.from_fp(sim.ball.x_fp)
			check(sim.ball.x_fp >= last, "push %d deeper" % n)
			last = sim.ball.x_fp
			check(x <= K.HIT_PUSH_MAX_X + 2, "push %d capped (%d)" % [n, x])
			if n < K.HIT_PUSH_OUT_FRAMES:
				check(x <= K.COURT_BASELINE_RIGHT, "push %d in (%d)" % [n, x])
			else:
				check(x > K.COURT_BASELINE_RIGHT, "push %d out (%d)" % [n, x])
			if n == K.HIT_PUSH_DEEP:
				check(absi(sim.ball.x_fp - K.to_fp(K.HIT_TARGET_DEEP_RIGHT)) < K.to_fp(3), "old deep")
	push = 255                       # the right team: out past its own baseline
	_fly_shot(1, K.SHOT_STANDARD, -1)
	check(sim.ball.x_fp < K.to_fp(K.COURT_BASELINE_LEFT), "right team pushes out")
	_fly_shot(0, K.SHOT_SOFT, 1)     # a lob stays deep and in
	check(absi(sim.ball.x_fp - K.to_fp(K.HIT_TARGET_DEEP_RIGHT)) < K.to_fp(3), "lob ignores it")
	push = K.HIT_PUSH_DEEP
	overhead = 1


## Port ADR-115: the remaster's push matches the ROM's to the old deep spot,
## then deepens a pixel per 3 frames, so a hold the ROM calls out (58 to 70
## frames) still lands in; out from HIT_PUSH_OUT_FRAMES_REMASTER, capped.
func test_push_slack() -> void:
	eq(K.HIT_PUSH_OUT_FRAMES_REMASTER, 71)
	for n in [0, 1, 20, K.HIT_PUSH_DEEP]:
		eq(Sim.push_px(n, true), Sim.push_px(n), "push %d as the ROM" % n)
	for shot in [K.SHOT_STANDARD, K.SHOT_DRIVE]:
		var last := 0
		for n in [K.HIT_PUSH_DEEP, K.HIT_PUSH_OUT_FRAMES, K.HIT_PUSH_OUT_FRAMES_REMASTER - 1,
				K.HIT_PUSH_OUT_FRAMES_REMASTER, 255]:
			push = n
			_fly_shot(0, shot, 1)
			var x := K.from_fp(sim.ball.x_fp)
			check(sim.ball.x_fp >= last, "push %d deeper" % n)
			last = sim.ball.x_fp
			check(x <= K.HIT_PUSH_MAX_X + 2, "push %d capped (%d)" % [n, x])
			if n < K.HIT_PUSH_OUT_FRAMES_REMASTER:
				check(x <= K.COURT_BASELINE_RIGHT, "push %d in (%d)" % [n, x])
			else:
				check(x > K.COURT_BASELINE_RIGHT, "push %d out (%d)" % [n, x])
	push = K.HIT_PUSH_DEEP


static func _aim(x: int, y: int = 0) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	it.aim_x = x
	it.aim_y = y
	it.move_x = x
	return it


## SNES ADR-076 (test_input.c's test_push): the push counts frames aimed
## toward the player's net (right on the left team, left on the right),
## and anything else resets it: away, nothing, or SHORT's aim. It caps.
## The port counts it in Sim.step, so it is state that rolls back.
func test_push_counts() -> void:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.human = [1, 0, 1, 0]
	var s := Sim.new(cfg)
	eq([s.intents[0].push, s.intents[2].push], [0, 0])
	for f in 10:
		s.step([_aim(1), null, _aim(1), null])   # P1 toward the net, slot 2 away
	eq([s.intents[0].push, s.intents[2].push], [10, 0])
	s.step([_aim(1, -1), null, _aim(-1), null])  # a sideline aim still counts
	eq([s.intents[0].push, s.intents[2].push], [11, 1])
	s.step([_aim(-1), null, _aim(-1), null])     # SHORT aims away
	eq(s.intents[0].push, 0)
	s.step([_aim(1), null, _aim(-1), null])
	var kept := SimState.save(s)
	s.step([_aim(0), null, _aim(-1), null])
	eq(s.intents[0].push, 0, "nothing held resets")
	SimState.load_into(s, kept)
	eq(s.intents[0].push, 1, "the push is state")
	for f in 300:
		s.step([_aim(1), null, _aim(-1), null])
	eq(s.intents[0].push, K.INPUT_PUSH_MAX)


func test_paddle_stats() -> void:   # ADR-020
	eq(Paddles.power_mul(Paddles.STANDARD), 64)
	eq(Paddles.control_mul(Paddles.STANDARD), 64)
	eq(Paddles.swing_limit(Paddles.STANDARD), K.PLAYER_SWING_MAX_SPEED_FP)
	eq(Paddles.recovery(Paddles.STANDARD), K.PLAYER_RECOVERY_FRAMES)
	paddle = Paddles.STANDARD
	var std: int = _fly_shot(0, K.SHOT_STANDARD, 1)[0]
	paddle = Paddles.RED
	check(_fly_shot(0, K.SHOT_STANDARD, 1)[0] < std, "power paddle flies sooner")
	paddle = Paddles.WOOD
	check(_fly_shot(0, K.SHOT_STANDARD, 1)[0] > std, "soft paddle flies longer")
	offset_y = K.HIT_SWEET_Y + 4
	paddle = Paddles.STANDARD
	_fly_shot(0, K.SHOT_DRIVE, 0)
	var std_y := sim.ball.y_fp
	paddle = Paddles.WOOD
	_fly_shot(0, K.SHOT_DRIVE, 0)
	check(sim.ball.y_fp < std_y, "control narrows a stretched spray")
	paddle = Paddles.RED
	_fly_shot(0, K.SHOT_DRIVE, 0)
	check(sim.ball.y_fp > std_y, "low control widens it")
	offset_y = 0
	paddle = Paddles.STANDARD


func test_new_swing_restores_contact() -> void:
	var s := Sim.new()
	var p: SimTypes.Player = s.players[0]
	p.state = K.STATE_IDLE
	p.frozen = 0
	p.contact_consumed = 1
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	Sim.player_step(p, it)
	eq(p.state, K.STATE_WINDUP)
	eq(p.contact_consumed, 0)
