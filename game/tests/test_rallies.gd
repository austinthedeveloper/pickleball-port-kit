## Longer rallies (PORT-48, ADR-073): CPU ERRORS spaces the CPUs' late
## swings (the ROM's deliberate misses); at 50%, the default, rallies run
## longer than at the ROM's 100%. A paced ball (BALL SPEED, KID, EASY) is
## drawn gliding, display only.
extends TestSuite


func test_late_period() -> void:
	eq(Sim.late_period(7, 100), 7, "the ROM's")
	eq(Sim.late_period(7, 50), 14, "half as often")
	eq(Sim.late_period(7, 200), 3, "twice as often")
	eq(Sim.late_period(7, 0), 0, "never")
	eq(Sim.late_period(0, 50), 0, "a style that's never late stays so")
	eq(Settings.CPU_ERRORS_DEFAULT, 50)
	eq(SimTypes.MatchConfig.new().cpu_errors, 100, "the sim's own is the ROM's")
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11)
	cfg.cpu_errors = 50
	var s := Sim.new(cfg)
	var style: int = Opponents.slot_style(cfg, 2).late_period
	eq(s.ai.slots[2].late_period, Sim.late_period(style, 50), "the CPUs get it")
	s.dispose()


func _mean_rally(errors: int) -> float:
	var total := 0
	var points := 0
	for team in [1, 3, 5, 7]:            # enough points to see past the noise
		var cfg := Settings.config_for(true, team, K.DIFFICULTY_MEDIUM, 11)
		cfg.cpu_errors = errors
		var s := Sim.new(cfg)
		s.p1_bot = true
		for f in 60 * 60 * 15:
			s.step([SimTypes.Intent.new(), null, null, null])
			for e in s.drain_events():
				if e[0] == K.EVENT_POINT:
					total += (s.shot_serial - s.rally_start) & 0xff
					points += 1
			if s.phase == K.PHASE_MATCH_RESULT:
				break
		s.dispose()
	return float(total) / maxi(points, 1)


func test_longer_rallies() -> void:
	var rom := _mean_rally(100)
	var half := _mean_rally(50)
	print("    mean rally: %.1f at 100%%, %.1f at 50%%" % [rom, half])
	check(half > rom * 1.1, "longer rallies (%.1f vs %.1f)" % [half, rom])


## The drawn ball moves every frame of a flight at 78% (the sim's ball
## stands still on about one frame in five), and the view plays as a bare
## sim does.
func test_the_glide() -> void:
	var cfg := Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 11)
	cfg.ball_speed = 78
	var v := match_view(cfg)
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	var flying := 0
	var still_sim := 0
	var still_drawn := 0
	var last_sim := Vector3i.ZERO
	var last_drawn := Vector2.ZERO
	for f in 1500:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		var b := v.sim.ball
		var at := Vector3i(b.x_fp, b.y_fp, b.z_fp)
		var drawn := v._ball_root.position + v._ball_sprite.position
		if b.rally_state == K.BALL_RALLY_LIVE and b.z_fp > K.to_fp(4) and b.vx_fp != 0:
			flying += 1
			still_sim += 1 if at == last_sim else 0
			still_drawn += 1 if drawn == last_drawn else 0
		last_sim = at
		last_drawn = drawn
	check(flying > 200, "flights (%d frames)" % flying)
	check(still_sim > flying / 8, "the sim's ball pauses (%d)" % still_sim)
	check(still_drawn < flying / 40, "the drawn one glides (%d still)" % still_drawn)
	eq(v.sim.snapshot(), bare.snapshot(), "display only")
	bare.dispose()
	v.free()
