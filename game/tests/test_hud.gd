## PORT-14: the livelier HUD. Each element against its trigger: scores
## pop on a point, the ball marks the serving side, the marker the server
## in doubles, the rally counter on long rallies, MATCH POINT pulses.
extends TestSuite


func _view(cfg: SimTypes.MatchConfig, demo := false) -> MatchView:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, "park", demo)
	v._hud.refresh()
	return v


func test_scores_pop() -> void:
	var v := _view(SimTypes.MatchConfig.singles())
	var h := v._hud
	eq(h._left_score.scale, Vector2.ONE, "still at the start")
	v.sim.team_score[0] = 1
	h.refresh()
	check(h._left_score.scale.x > 1.15, "a point pops the score")
	check(h._left_score.tint != Color.WHITE, "and lights it gold")
	eq(h._right_score.scale, Vector2.ONE, "only the side that scored")
	for f in Hud.POP_FRAMES:
		h.refresh()
	eq(h._left_score.scale, Vector2.ONE, "then settles")
	eq(h._left_score.tint, Color.WHITE)
	v.sim.team_score[0] = 0                  # a new match: no pop going down
	h.refresh()
	eq(h._left_score.scale, Vector2.ONE, "a reset doesn't pop")
	v.free()


func test_serve_marks() -> void:
	var v := _view(SimTypes.MatchConfig.singles())
	var h := v._hud
	v.sim.serving_team = 0
	h.refresh()
	check(h._serve_icons[0].visible and not h._serve_icons[1].visible, "P1's side serves")
	v.sim.serving_team = 1
	h.refresh()
	check(not h._serve_icons[0].visible and h._serve_icons[1].visible, "the mark follows the serve")
	check(not h._server_mark.visible, "singles: no server marker")
	v.sim.phase = K.PHASE_MATCH_RESULT
	h.refresh()
	check(not h._serve_icons[1].visible, "nobody serves on the result")
	v.free()
	var d := _view(SimTypes.MatchConfig.doubles())
	d.sim.phase = K.PHASE_SERVE_SETUP
	d._hud.refresh()
	check(d._hud._server_mark.visible, "doubles: the server is marked while they set up")
	var p: SimTypes.Player = d.sim.players[d.sim.server_index]
	check(absf(d._hud._server_mark.position.x - CourtView.ground(p.x_fp, p.y_fp).x) < 2.0,
		"over the server")
	d.sim.phase = K.PHASE_LIVE
	d._hud.refresh()
	check(not d._hud._server_mark.visible, "gone once the ball is in play")
	d.free()


func test_rally_counter() -> void:
	var v := _view(SimTypes.MatchConfig.singles())
	var h := v._hud
	var s := v.sim
	s.phase = K.PHASE_LIVE
	s.shot_serial = (s.rally_start + Hud.RALLY_SHOW - 1) & 0xff
	h.refresh()
	check(not h._rally.visible, "short rallies: no counter")
	s.shot_serial = (s.rally_start + Hud.RALLY_SHOW) & 0xff
	h.refresh()
	check(h._rally.visible, "a long rally shows it")
	eq(h._rally_text.text, "RALLY %d" % Hud.RALLY_SHOW)
	check(h._rally_text.scale.x > 1.0, "popping on the shot")
	s.phase = K.PHASE_POINT_RESULT
	h.refresh()
	check(not h._rally.visible, "gone when the point ends")
	v.free()
	var demo := _view(SimTypes.MatchConfig.singles(), true)
	demo.sim.phase = K.PHASE_LIVE
	demo.sim.shot_serial = (demo.sim.rally_start + 12) & 0xff
	demo._hud.refresh()
	check(not demo._hud._rally.visible, "not in the demo")
	demo.free()


func test_match_point_pulses() -> void:
	var v := _view(SimTypes.MatchConfig.singles())
	var h := v._hud
	v.sim.team_score[0] = v.sim.config.points_to_win - 1
	var seen := {}
	for f in 40:
		h.refresh()
		seen[snappedf(h._subtitle.modulate.a, 0.05)] = true
	check(h._subtitle.visible, "MATCH POINT shows")
	check(seen.size() > 3, "and pulses (%d levels)" % seen.size())
	v.free()
