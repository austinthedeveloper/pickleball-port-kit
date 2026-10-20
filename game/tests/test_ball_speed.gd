## BALL SPEED (port ADR-071): MODIFIERS' slider, 70% to 130% in 1% steps.
## A shot lands where it was aimed, over 100 / speed as many frames; at
## 100 nothing changes (the golden and conformance traces say so); it
## saves, reaches every match the settings build, and travels online.
extends TestSuite


## Since ADR-073, the ROM's own slow ball (KID and EASY's): fewer ball
## steps a cycle, spread evenly, the flights themselves unchanged.
func test_the_pace() -> void:
	var cfg := SimTypes.MatchConfig.singles()
	var s := Sim.new(cfg)
	check(not s.ball_paced, "100%: unpaced, as the ROM")
	eq(s.ball.flight, [1, 1], "and the flight untouched")
	cfg.ball_speed = 78
	s = Sim.new(cfg)
	check(s.ball_paced)
	eq(s.ball.flight, [1, 1], "the same flights")
	var n := 0
	for k in Sim.BALL_CYCLE:
		n += int(s.ball_pace[k])
	eq(n, 47, "47 steps in 60 frames")
	cfg.difficulty = K.DIFFICULTY_EASY
	eq(Sim.ball_per_cycle(K.DIFFICULTY_EASY, 78), 35, "on EASY's slower pace")
	cfg.ball_speed = 5
	cfg.difficulty = K.DIFFICULTY_MEDIUM
	eq(Sim.new(cfg).ball_speed(), K.BALL_SPEED_MIN, "clamped")
	cfg.ball_speed = 130
	var fast := Sim.new(cfg)
	n = 0
	for k in Sim.BALL_CYCLE:
		n += int(fast.ball_pace[k])
	eq(n, 78, "faster: some frames take two steps")


## A ball flies the same path at 78% as at 100%, just over more frames.
func test_same_path() -> void:
	var paths := []
	for speed in [100, 78]:
		var cfg := Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 11)
		cfg.ball_speed = speed
		var s := Sim.new(cfg)
		s.p1_bot = true
		var path := []
		var frames := 0
		while s.ball.rally_state != K.BALL_RALLY_LIVE or s.ball.last_hitter == K.BALL_NO_HITTER:
			s.step([SimTypes.Intent.new(), null, null, null])
			s.drain_events()
		var serial := s.shot_serial
		var seen := -1
		while s.shot_serial == serial and frames < 600:
			if s.ball_steps != seen:
				seen = s.ball_steps
				path.append([s.ball.x_fp, s.ball.y_fp, s.ball.z_fp])
			s.step([SimTypes.Intent.new(), null, null, null])
			s.drain_events()
			frames += 1
		paths.append([path.slice(0, 20), frames])
		s.dispose()
	eq(paths[1][0], paths[0][0], "step for step, the same flight")
	check(paths[1][1] > paths[0][1], "taking longer (%d vs %d frames)" % [paths[1][1], paths[0][1]])


## A doubles match at 90% plays out: rallies, points, a winner.
func test_a_match_plays() -> void:
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11)
	cfg.ball_speed = 90
	var s := Sim.new(cfg)
	s.p1_bot = true
	var hits := 0
	var finished := false
	for f in 60 * 60 * 8:
		s.step([SimTypes.Intent.new(), null, null, null])
		for e in s.drain_events():
			hits += 1 if e[0] == K.EVENT_HIT else 0
		if s.phase == K.PHASE_MATCH_RESULT:
			finished = true
			break
	check(finished, "the match finishes")
	check(hits > 40, "with rallies (%d hits)" % hits)
	s.dispose()


func test_the_setting() -> void:
	var kept := Settings.ball_speed
	var sv := fresh_save("user://test_ball_speed/")
	Settings.ball_speed = 93
	eq(Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 11).ball_speed, 93, "matches get it")
	var lobby := Lobby.new()
	lobby.join(0)
	eq(lobby.match_config(K.DIFFICULTY_MEDIUM, 11, 0).ball_speed, 93, "the lobby's too")
	Settings.store_to(sv)
	Settings.ball_speed = 100
	Settings.load_from(sv)
	eq(Settings.ball_speed, 93, "saved")
	var d := OnlineSession.config_to_dict(Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 11))
	eq(OnlineSession.config_from_dict(JSON.parse_string(JSON.stringify(d))).ball_speed, 93,
		"online: the guest plays the host's")
	# the MODIFIERS row: 1% a press, within its range
	var t := TitleScreen.new()
	t.save = sv
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	var page: MenuPage = t.pages["modifiers"]
	page.select("ball_speed")
	eq(page.value_of("ball_speed"), "93%")
	page.change(-1)
	eq(Settings.ball_speed, 92, "1% a step")
	eq(t._mods_label(), "BALL 92%", "MODIFIERS says so on the title")
	for k in 100:
		page.change(1)
	eq(Settings.ball_speed, K.BALL_SPEED_MAX)
	Settings.ball_speed = Settings.BALL_SPEED_DEFAULT
	eq(t._mods_label(), "NONE")
	t.free()
	Settings.ball_speed = kept
	wipe_saves("user://test_ball_speed/")


## ADR-072: 85% and 110% are the defaults (78% and 105% in 0.17.0, 100%
## in 0.16.0). A save holding an old default, from before it changed,
## moves to today's; any other value is kept, and so is a value saved since.
func test_the_default() -> void:
	var kept := [Settings.ball_speed, Settings.ball_size]
	eq([Settings.BALL_SPEED_DEFAULT, Settings.BALL_SIZE_DEFAULT], [85, 110])
	eq(SimTypes.MatchConfig.new().ball_speed, 100, "the sim's own is the ROM's")
	var sv := fresh_save("user://test_ball_speed/")
	var st: Dictionary = sv.data["settings"]
	for old in [[{"ball_speed": 100}, 85, 110, "an untouched 0.16.0 save"],
			[{"ball_speed": 78, "ball_speed_v": 1, "ball_size": 105}, 85, 110, "an untouched 0.17.0 save"],
			[{"ball_speed": 92, "ball_speed_v": 1, "ball_size": 120}, 92, 120, "0.17.0 choices kept"],
			[{"ball_speed": 100, "ball_speed_v": 1, "ball_size": 105}, 100, 110, "100% chosen in 0.17.0"]]:
		for k in ["ball_speed", "ball_speed_v", "ball_size"]:
			st.erase(k)
		st.merge(old[0], true)
		Settings.load_from(sv)
		eq([Settings.ball_speed, Settings.ball_size], [old[1], old[2]], old[3])
	Settings.ball_speed = 78
	Settings.ball_size = 105
	Settings.store_to(sv)
	Settings.load_from(sv)
	eq([Settings.ball_speed, Settings.ball_size], [78, 105], "78% and 105% chosen now are kept")
	Settings.ball_speed = kept[0]
	Settings.ball_size = kept[1]
	wipe_saves("user://test_ball_speed/")


## BALL SIZE is display only: the ball's sprite and shadow, never the sim
## (BIG BALL's reach is its own); BIG BALL still doubles it.
func test_ball_size() -> void:
	var kept := Settings.ball_size
	Settings.ball_size = 120
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 11), "park", false)
	eq(v._ball_sprite.scale, Vector2(1.2, 1.2), "the ball")
	eq(v._ball_shadow.scale, Vector2(1.2, 1.2), "its shadow")
	eq(v.sim.grow_fp, 0, "no more reach")
	v.free()
	var cfg := Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 11)
	cfg.modifiers = K.MOD_BIG_BALL
	var b := MatchView.new()
	runner.root.add_child(b)
	b.setup(cfg, "park", false)
	eq(b._ball_sprite.scale, Vector2(2, 2), "BIG BALL is still BIG BALL")
	b.free()
	Settings.ball_size = kept
