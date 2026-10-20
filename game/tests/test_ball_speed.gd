## BALL SPEED (port ADR-071): MODIFIERS' slider, 70% to 130% in 1% steps.
## A shot lands where it was aimed, over 100 / speed as many frames; at
## 100 nothing changes (the golden and conformance traces say so); it
## saves, reaches every match the settings build, and travels online.
extends TestSuite


func _ball(flight: Array) -> SimTypes.Ball:
	var b := SimTypes.Ball.new()
	b.active = 1
	b.rally_state = K.BALL_RALLY_LIVE
	b.x_fp = K.to_fp(40)
	b.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	b.z_fp = K.to_fp(12)
	b.flight = flight
	return b


## Frames to the first bounce, and where.
func _fly(b: SimTypes.Ball) -> Array:
	for f in 400:
		if Sim.simulate_step(b) & K.BALL_EVENT_BOUNCE:
			return [f + 1, K.from_fp(b.x_fp), K.from_fp(b.y_fp)]
	return [-1, 0, 0]


func test_flight() -> void:
	var tx := K.COURT_NET_X + 60
	var ty := K.COURT_CENTERLINE_Y + 10
	var base := _ball([1, 1])
	Sim.launch(base, tx, ty, 40)
	var at100 := _fly(base)
	var slow := _ball([100, 90])
	Sim.launch(slow, tx, ty, 40)
	var at90 := _fly(slow)
	check(absi(at90[1] - tx) <= 2 and absi(at90[2] - ty) <= 2, "lands where aimed (%s)" % [at90])
	check(absi(at100[1] - at90[1]) <= 2, "where 100% lands")
	check(absi(at90[0] - 40 * 100 / 90) <= 2 and at90[0] > at100[0],
		"over 100/90 the frames (%d vs %d)" % [at90[0], at100[0]])


func test_the_sim_sets_it() -> void:
	var cfg := SimTypes.MatchConfig.singles()
	eq(Sim.new(cfg).ball.flight, [1, 1], "100%: untouched")
	cfg.ball_speed = 93
	eq(Sim.new(cfg).ball.flight, [100, 93])
	cfg.modifiers = K.MOD_MOON
	eq(Sim.new(cfg).ball.flight, [300, 186], "with MOON's 3/2")
	cfg.modifiers = 0
	cfg.ball_speed = 5
	eq(Sim.new(cfg).ball.flight, [100, K.BALL_SPEED_MIN], "clamped")


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


## ADR-072: 78% is the default; a 0.16.0 save that kept 100 (no choice
## made) moves to it, one saved since keeps its choice.
func test_the_default() -> void:
	var kept := Settings.ball_speed
	eq(Settings.BALL_SPEED_DEFAULT, 78)
	eq(SimTypes.MatchConfig.new().ball_speed, 100, "the sim's own is the ROM's")
	var sv := fresh_save("user://test_ball_speed/")
	sv.data["settings"]["ball_speed"] = 100          # as 0.16.0 wrote it
	Settings.load_from(sv)
	eq(Settings.ball_speed, 78, "an untouched 0.16.0 save")
	Settings.ball_speed = 100
	Settings.store_to(sv)
	Settings.ball_speed = 50
	Settings.load_from(sv)
	eq(Settings.ball_speed, 100, "100 chosen since is kept")
	Settings.ball_speed = kept
	wipe_saves("user://test_ball_speed/")


## BALL SIZE is display only: the ball's sprite and shadow, never the sim
## (BIG BALL's reach is its own); BIG BALL still doubles it.
func test_ball_size() -> void:
	var kept := Settings.ball_size
	eq(Settings.BALL_SIZE_DEFAULT, 105)
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
