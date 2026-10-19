## SIDE-OUT scoring (port ADR-063, the Pickleball '95 promise): only the
## serving side scores; in doubles the game opens on the second server,
## each side-out starts with the first, and a lost rally passes the serve
## to the partner before the side out. Off, rally scoring as before.
extends TestSuite


func _sim(doubles: bool) -> Sim:
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_SIDE_OUT
	cfg.points_to_win = 11
	return Sim.new(cfg)


## A rally ends: `loser` loses it; the result runs out to the next serve.
func _rally(s: Sim, loser: int) -> void:
	s.set_phase(K.PHASE_LIVE)
	s.resolve_point(loser, K.FAULT_OUT)
	s.phase_timer = K.POINT_RESULT_FRAMES
	s._update_point_result()


func test_singles() -> void:
	var s := _sim(false)
	eq(s.serving_team, 0)
	_rally(s, 1)
	eq(s.team_score, [1, 0], "the server's side scores")
	eq(s.serving_team, 0, "and keeps the serve")
	_rally(s, 0)
	eq(s.team_score, [1, 0], "the receivers win the rally: no point")
	check(not s.point_scored)
	eq(s.serving_team, 1, "side out")
	eq(Hud.point_line(s, "BLUE"), "SIDE OUT")
	_rally(s, 0)
	eq(s.team_score, [1, 1], "now they score")
	check(not s.match_point(0), "a receiving side has no match point")
	s.dispose()


## Doubles: 0-0-2 (one fault, then the side out), then server 1 and 2 on
## each side, each from their own side of the court.
func test_doubles_rotation() -> void:
	var s := _sim(true)
	var opener := s.server_index
	eq(s.server_number, 2, "the game opens on server 2")
	_rally(s, 1)
	eq([s.team_score, s.server_index], [[1, 0], opener], "the opener scores and serves on")
	_rally(s, 0)
	eq(s.serving_team, 1, "the opener's lost rally sides out")
	eq(s.server_number, 1)
	var first := s.server_index
	check(first >= 2, "a right-side player")
	_rally(s, 1)
	eq(Hud.point_line(s, "RED"), "SIDE OUT", "the result's line is for the next serve's side")
	s.dispose()
	s = _sim(true)
	_rally(s, 0)                          # the opener's fault: side out
	first = s.server_index
	_rally(s, 1)                          # first server loses: second server
	eq(s.serving_team, 1)
	eq(s.server_number, 2)
	eq(s.server_index, first ^ 1, "the partner serves")
	_rally(s, 0)                          # they score: the partner serves on
	eq(s.team_score, [0, 1])
	eq(s.server_index, first ^ 1)
	_rally(s, 1)                          # the second server loses: side out
	eq(s.serving_team, 0)
	eq(s.server_number, 1)
	s.dispose()


## SECOND SERVER on the first server's lost rally (shown while its result
## is up, before the serve passes).
func test_second_server_line() -> void:
	var s := _sim(true)
	_rally(s, 0)                          # opener: side out to team 1, server 1
	s.set_phase(K.PHASE_LIVE)
	s.resolve_point(1, K.FAULT_NET)
	eq(Hud.point_line(s, "BLUE"), "SECOND SERVER")
	s.dispose()


## Bot matches finish under SIDE-OUT, singles and doubles; every point is
## the server's side's.
func test_bot_matches() -> void:
	for doubles in [false, true]:
		var s := _sim(doubles)
		s.p1_bot = true
		s.set_bot_skill(4, 0)
		var ok := true
		var points := 0
		var outs := 0
		for f in 60 * 60 * 15:
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
			var serving := s.serving_team
			s.step([it, null, null, null])
			for e in s.drain_events():
				if e[0] == K.EVENT_POINT:
					if s.point_scored:
						points += 1
						ok = ok and e[3] == serving
					else:
						outs += 1
			if s.phase == K.PHASE_MATCH_RESULT:
				break
		print("    side-out %s: %d points, %d side outs, %d-%d" % ["doubles" if doubles else "singles",
			points, outs, s.team_score[0], s.team_score[1]])
		check(ok, "only the serving side scores")
		eq(s.phase, K.PHASE_MATCH_RESULT, "the match finishes")
		check(outs > 0)
		s.dispose()


## Off, rally scoring: the receivers' rally is their point and serve.
func test_rally_scoring_unchanged() -> void:
	var s := Sim.new(SimTypes.MatchConfig.singles())
	_rally(s, 0)
	eq(s.team_score, [0, 1])
	eq(s.serving_team, 1)
	check(s.point_scored)
	s.dispose()
