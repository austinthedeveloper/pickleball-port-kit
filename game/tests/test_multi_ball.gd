## MULTI BALL (port ADR-067): balls trickle in from the net (one every
## MULTI_EVERY frames, MULTI_MAX at most), blink, then fly to each side in
## turn; no serving; each ball scores on its own by the usual rules, the
## two-bounce rule included, and a match can end with balls in the air.
extends TestSuite


func _sim(doubles := false) -> Sim:
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_MULTI_BALL
	cfg.points_to_win = 11
	var s := Sim.new(cfg)
	s.p1_bot = true
	s.set_bot_skill(4, 0)
	return s


func _run(s: Sim, frames: int, each := Callable()) -> Array:
	var events := []
	for f in frames:
		s.step([SimTypes.Intent.new(), null, null, null])
		var ev := s.drain_events()
		events.append_array(ev)
		if each.is_valid():
			each.call(f, ev)
		if s.phase == K.PHASE_MATCH_RESULT:
			break
	return events


func test_no_serve_balls_trickle_in() -> void:
	var s := _sim()
	eq(s.phase, K.PHASE_LIVE, "live from the start: no serve")
	_run(s, 1)
	eq(s.multi.size(), 1, "the first ball at the net")
	var m: Sim.MultiBall = s.multi[0]
	eq(m.ball.rally_state, K.BALL_RALLY_INACTIVE, "blinking, not flying")
	_run(s, K.MULTI_BLINK)
	eq(m.ball.rally_state, K.BALL_RALLY_LIVE, "then it flies")
	check(m.ball.vx_fp < 0, "the first to the left side")
	eq(m.required_bounce, K.REQUIRED_BOUNCE_SERVE, "it must bounce before anyone hits it")
	var c := {"most": 0}
	_run(s, 60 * 30, func(f, ev): c["most"] = maxi(c["most"], s.multi.size()))
	check(c["most"] >= 2 and c["most"] <= K.MULTI_MAX, "several at once, %d at most (%d)" % [K.MULTI_MAX, c["most"]])
	s.dispose()


## Bot matches finish, singles and doubles; every point comes from a ball
## dying, and the sides alternate.
func test_matches_finish() -> void:
	for doubles in [false, true]:
		var s := _sim(doubles)
		var c := {"points": 0, "hits": 0}
		var serves := []
		_run(s, 60 * 60 * 10, func(f, ev):
			for e in ev:
				if e[0] == K.EVENT_POINT:
					c["points"] += 1
				elif e[0] == K.EVENT_HIT:
					c["hits"] += 1
				elif e[0] == K.EVENT_SERVE:
					serves.append(e[3]))
		var points: int = c["points"]
		var hits: int = c["hits"]
		print("    multi ball %s: %d points, %d hits, %d-%d" % ["doubles" if doubles else "singles",
			points, hits, s.team_score[0], s.team_score[1]])
		eq(s.phase, K.PHASE_MATCH_RESULT, "the match finishes")
		eq(points, s.team_score[0] + s.team_score[1], "a point per ball")
		check(hits > points, "rallies happen (%d hits)" % hits)
		check(serves.size() >= 2 and serves[0] == 2 and serves[1] == 0, "alternating sides")
		s.dispose()


## Deterministic (online plays it in lockstep): two runs, one trace.
func test_deterministic() -> void:
	var a := _sim(true)
	var b := _sim(true)
	var same := true
	for f in 3000:
		a.step([SimTypes.Intent.new(), null, null, null])
		b.step([SimTypes.Intent.new(), null, null, null])
		a.drain_events()
		b.drain_events()
		same = same and a.snapshot() == b.snapshot()
	check(same, "the same frame by frame")
	a.dispose()
	b.dispose()


## Off, nothing of it: one ball, a serve.
func test_off() -> void:
	var s := Sim.new(SimTypes.MatchConfig.singles())
	check(not s.multi_on)
	eq(s.phase, K.PHASE_SERVE_SETUP)
	s.dispose()


## The view draws every ball (blinking ones blink) and plays as a bare sim.
func test_view() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.modifiers = K.MOD_MULTI_BALL
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, "park", false)
	v.sim.p1_bot = true
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	eq(v._multi_balls.size(), K.MULTI_MAX - 1, "a sprite for each ball past the first")
	var drawn := 0
	for frame in 1500:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % frame)
			break
		var shown := 1 if v._ball_root.visible else 0
		for e in v._multi_balls:
			shown += 1 if e[0].visible else 0
		drawn = maxi(drawn, shown)
	check(drawn >= 2, "several balls on screen (%d)" % drawn)
	bare.dispose()
	v.free()
