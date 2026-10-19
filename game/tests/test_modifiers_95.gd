## The '95 modifiers (port ADR-065): MOON, BOUNCY and WIND change the
## ball's flight, DINK OR DIE makes a drive a fault, SUDDEN DEATH plays one
## point. Off, the ROM's ball (the conformance and golden traces).
extends TestSuite


func _sim(mods: int) -> Sim:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = mods
	return Sim.new(cfg)


## A launch from the left baseline to (tx, ty): frames to the bounce, the
## apex, and where it lands.
func _flight(s: Sim, frames: int) -> Array:
	var b := s.ball
	b.x_fp = K.to_fp(60)
	b.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	b.z_fp = K.to_fp(10)
	b.rally_state = K.BALL_RALLY_LIVE
	Sim.launch(b, 200, K.COURT_CENTERLINE_Y, frames)
	var n := 0
	var apex := 0
	while not (Sim.simulate_step(b) & K.BALL_EVENT_BOUNCE) and n < 400:
		apex = maxi(apex, b.z_fp)
		n += 1
	return [n, apex, K.from_fp(b.x_fp), K.from_fp(b.y_fp)]


func test_moon() -> void:
	var s := _sim(0)
	var m := _sim(K.MOD_MOON)
	eq(m.ball.gravity_fp, K.MOON_GRAVITY_FP)
	var normal := _flight(s, 30)
	var moon := _flight(m, 30)
	check(absi(normal[0] - 30) <= 1 and absi(moon[0] - 45) <= 1, "half as long again (%d, %d)" % [normal[0], moon[0]])
	check(moon[1] > normal[1], "and higher")
	check(absi(moon[2] - 200) <= 2, "still on target (%d)" % moon[2])
	s.dispose()
	m.dispose()


func test_bouncy() -> void:
	var s := _sim(0)
	var b := _sim(K.MOD_BOUNCY)
	var heights := []
	for sim in [s, b]:
		_flight(sim, 30)
		var apex := 0
		for f in 60:
			Sim.simulate_step(sim.ball)
			apex = maxi(apex, sim.ball.z_fp)
		heights.append(apex)
	check(heights[1] > heights[0] * 3 / 2, "the bounce keeps more height (%d, %d)" % heights)
	s.dispose()
	b.dispose()


func test_wind() -> void:
	var s := _sim(K.MOD_WIND)
	var seen := {}
	for f in 64:
		s.frame_count = f * 8
		s._begin_serve(0)
		seen[s.ball.wind] = true
	eq(seen.size(), 3, "up, down and calm, a serve at a time")
	s.ball.wind = 1
	var blown := _flight(s, 40)
	var calm := _flight(_sim(0), 40)
	check(blown[3] > calm[3], "a shot drifts with the wind (%d, %d)" % [blown[3], calm[3]])
	s.dispose()
	var v := MatchView.new()
	runner.root.add_child(v)
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_WIND
	v.setup(cfg, "park", false)
	check(v.wind_view != null, "streaks show it")
	v.free()


func test_dink_or_die() -> void:
	var s := _sim(K.MOD_DINK_OR_DIE)
	s.set_phase(K.PHASE_LIVE)
	s.players[0].shot_type = K.SHOT_DRIVE
	s.rules_process_player_hit(0)
	eq(s.last_fault, K.FAULT_DRIVE)
	eq(s.point_winner, 1)
	eq(K.fault_word(K.FAULT_DRIVE), "DRIVE!")
	s.dispose()
	# the CPUs (and the bot) never drive; matches go on
	var cfg := Settings.config_for(true, 2, K.DIFFICULTY_MEDIUM, 11)   # the GYM BROS drive
	cfg.modifiers = K.MOD_DINK_OR_DIE
	s = Sim.new(cfg)
	s.p1_bot = true
	var drives := 0
	var points := 0
	for f in 60 * 60 * 5:
		var it := SimTypes.Intent.new()
		it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
		if s.phase == K.PHASE_MATCH_RESULT:
			s.new_match()
		s.step([it, null, null, null])
		for e in s.drain_events():
			if e[0] == K.EVENT_POINT:
				points += 1
				drives += 1 if s.last_fault == K.FAULT_DRIVE else 0
	check(points > 20)
	eq(drives, 0, "no CPU drives")
	s.dispose()


func test_sudden_death() -> void:
	var s := _sim(K.MOD_SUDDEN_DEATH | K.MOD_WIN_BY_2)
	check(s.score_wins(1, 0), "one point takes it, WIN BY 2 or not")
	check(s.match_point(0) and s.match_point(1), "every point is match point")
	s.dispose()


## Off, the ROM's ball: its physics constants.
func test_off() -> void:
	var s := _sim(0)
	eq([s.ball.gravity_fp, s.ball.bounce_256, s.ball.flight, s.ball.wind],
		[K.BALL_GRAVITY_FP, K.BALL_BOUNCE_VERTICAL_256, [1, 1], 0])
	s.dispose()
