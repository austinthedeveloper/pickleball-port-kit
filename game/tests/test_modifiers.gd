## Port of reference/snes-src/test/test_modifiers.c (ADR-033, MOD-01).
extends TestSuite


func test_ball_steps() -> void:
	var kid := Sim.make_ball_pace(K.DIFFICULTY_KID)
	var count := 0
	for t in Sim.BALL_CYCLE:
		count += kid[t]
	eq(count, 40, "KID 40 a cycle")
	var fast := Sim.make_ball_pace(K.DIFFICULTY_MEDIUM, K.MOD_FAST_BALL)
	count = 0
	for t in Sim.BALL_CYCLE:
		count += fast[t]
	eq(count, 80, "FAST BALL adds 20 a cycle")
	var easy := Sim.make_ball_pace(K.DIFFICULTY_EASY)
	for t in Sim.BALL_PACE_TICKS - Sim.BALL_CYCLE:
		eq(easy[Sim.BALL_CYCLE + t], easy[t], "the lookahead past the cycle repeats its start")


func _frames_to_bounce(mods: int) -> Array:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = mods
	var sim := Sim.new(cfg)
	sim.phase = K.PHASE_LIVE
	sim.required_bounce = K.REQUIRED_BOUNCE_NONE
	var b := sim.ball
	b.rally_state = K.BALL_RALLY_LIVE
	b.active = 1
	b.last_hitter = 0
	b.bounce_count = 0
	b.x_fp = K.to_fp(80)
	b.y_fp = K.to_fp(130)
	b.z_fp = K.to_fp(20)
	Sim.launch(b, 200, 130, 40)
	sim.players[2].x_fp = K.to_fp(236)
	sim.players[2].y_fp = K.to_fp(96)
	var frames := 0
	while b.bounce_count == 0 and frames < 100:
		sim.game_update()
		frames += 1
	return [frames, b.x_fp]


func test_fast_ball_arc() -> void:
	var normal := _frames_to_bounce(0)
	var fast := _frames_to_bounce(K.MOD_FAST_BALL)
	eq(normal[0], 40, "a 40-step shot")
	eq(fast[0], 30, "three quarters of the frames with FAST BALL")
	eq(normal[1], fast[1], "the same landing spot")


func test_big_ball_reach() -> void:
	var p := SimTypes.Player.new()
	p.active = 1
	p.x_fp = K.to_fp(64)
	p.y_fp = K.to_fp(112)
	var b := SimTypes.Ball.new()
	b.active = 1
	b.rally_state = K.BALL_RALLY_LIVE
	b.x_fp = p.x_fp + K.to_fp(K.HIT_REACH_X + 2)
	b.y_fp = p.y_fp
	b.z_fp = K.to_fp(10)
	var big := K.to_fp(K.MOD_BIG_REACH)
	check(not Sim.in_reach(p, b), "past the normal reach")
	check(Sim.in_reach(p, b, big), "inside the big ball's reach")
	b.x_fp = p.x_fp + K.to_fp(K.HIT_REACH_X + K.MOD_BIG_REACH) + 1
	check(not Sim.in_reach(p, b, big), "past even the big reach")
	b.x_fp = p.x_fp + K.to_fp(K.HIT_SWEET_X + 2)
	check(Sim.in_sweet_spot(p, b, big), "the sweet spot grows too")
	check(not Sim.in_sweet_spot(p, b), "but not without BIG BALL")
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_BIG_BALL
	eq(Sim.new(cfg).grow_fp, big, "a BIG BALL match grows the hit box")


func _award(sim: Sim, team: int) -> void:
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1 - team, K.FAULT_OUT)
	for f in K.POINT_RESULT_FRAMES + 2:
		sim.game_update()


func test_win_by_2() -> void:
	var sim := Sim.new()
	sim.team_score = [5, 4]
	check(sim.team_won(0) and not sim.team_won(1), "first to 5")
	sim.team_score = [4, 4]
	check(sim.match_point(0) and sim.match_point(1), "both on match point")
	sim.config.modifiers = K.MOD_WIN_BY_2
	check(not sim.match_point(0) and not sim.match_point(1), "deuce: neither")
	sim.team_score = [5, 4]
	check(not sim.team_won(0) and sim.match_point(0) and not sim.match_point(1), "5-4 plays on")
	sim.team_score = [6, 4]
	check(sim.team_won(0), "6-4 wins")
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_WIN_BY_2
	sim = Sim.new(cfg)
	for i in 4:
		_award(sim, 0)
		_award(sim, 1)
	_award(sim, 0)
	check(sim.phase != K.PHASE_MATCH_RESULT and sim.match_point(0), "5-4: match point")
	_award(sim, 1)
	check(not sim.match_point(0) and not sim.match_point(1), "5-5: deuce")
	_award(sim, 1)
	check(sim.phase != K.PHASE_MATCH_RESULT and sim.match_point(1), "5-6")
	_award(sim, 1)
	eq(sim.phase, K.PHASE_MATCH_RESULT, "5-7 ends it")
	eq(sim.match_winner, 1)
	eq(sim.team_score[1], 7)


func test_lava_rule() -> void:
	check(Sim.in_kitchen(K.to_fp(K.COURT_KITCHEN_LEFT_X + 1), K.to_fp(K.COURT_CENTERLINE_Y), 0), "in")
	check(not Sim.in_kitchen(K.to_fp(K.COURT_KITCHEN_LEFT_X), K.to_fp(K.COURT_CENTERLINE_Y), 0), "on the line is out")
	check(not Sim.in_kitchen(K.to_fp(K.COURT_KITCHEN_LEFT_X + 1), K.to_fp(K.COURT_SIDELINE_TOP - 2), 0),
		"off the court's side is out")
	check(Sim.in_kitchen(K.to_fp(K.COURT_KITCHEN_RIGHT_X - 1), K.to_fp(K.COURT_CENTERLINE_Y), 1), "right team")
	check(not Sim.in_kitchen(K.to_fp(K.COURT_KITCHEN_RIGHT_X - 1), K.to_fp(K.COURT_CENTERLINE_Y), 0),
		"the other team's kitchen isn't yours")
	eq(Sim.lava_target(120, 0), K.COURT_KITCHEN_LEFT_X - K.MOD_LAVA_MARGIN)
	eq(Sim.lava_target(40, 0), 40)
	eq(Sim.lava_target(140, 1), K.COURT_KITCHEN_RIGHT_X + K.MOD_LAVA_MARGIN)
	for mods in [0, K.MOD_LAVA]:
		var cfg := SimTypes.MatchConfig.singles()
		cfg.modifiers = mods
		var sim := Sim.new(cfg)
		sim.phase = K.PHASE_LIVE
		sim.ball.rally_state = K.BALL_RALLY_LIVE
		sim.ball.active = 1
		sim.ball.z_fp = K.to_fp(30)
		Sim.launch(sim.ball, 200, 130, 40)
		sim.players[0].x_fp = K.to_fp(K.COURT_KITCHEN_LEFT_X + 6)
		sim.players[0].y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
		sim.game_update()
		if mods:
			eq(sim.phase, K.PHASE_POINT_RESULT, "LAVA ends the point")
			eq(sim.last_fault, K.FAULT_LAVA)
			eq(sim.point_winner, 1)
		else:
			eq(sim.phase, K.PHASE_LIVE, "without LAVA it plays on")


## No CPU walks into the lava over ladder matches (MOD-01).
func test_no_cpu_in_the_lava() -> void:
	for opp in [0, 3, Opponents.count() - 1]:
		var cfg := Settings.config_for(false, opp, K.DIFFICULTY_MEDIUM, 5)
		cfg.modifiers = K.MOD_LAVA
		var sim := Sim.new(cfg)
		sim.p1_bot = true
		var frames := 0
		while sim.phase != K.PHASE_MATCH_RESULT and frames < 60 * 60 * 6:
			sim.set_bot_skill(6, opp)
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0
				and (frames & 31) == 0) else 0
			sim.step([it, null, null, null])
			for e in sim.drain_events():
				if e[0] == K.EVENT_FAULT and e[3] == K.FAULT_LAVA and sim.point_winner == 0:
					runner.fail("a CPU stepped in the lava (opponent %d)" % opp)
					return
			frames += 1
	check(true)


func test_every_modifier_match_finishes() -> void:
	for mods in [K.MOD_BIG_BALL, K.MOD_FAST_BALL, 15]:
		var cfg := SimTypes.MatchConfig.doubles()
		cfg.modifiers = mods
		var sim := Sim.new(cfg)
		sim.start_attract()
		var frames := run_until(sim, func(): return sim.phase == K.PHASE_MATCH_RESULT, 60 * 60 * 10)
		check(frames > 0, "modifiers %d: a doubles demo finishes" % mods)
