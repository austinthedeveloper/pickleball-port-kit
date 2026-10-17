## Presentation checks: the painted court is the called court, and the view
## never writes to the sim (playbook rules 2 and "the line you see is the
## line that's called").
extends TestSuite


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/manifest.json"))


func test_projected_court_is_the_painted_court() -> void:
	var corners: Dictionary = _manifest()["court"]["corners"]
	var world := {
		"far_left": [K.COURT_BASELINE_LEFT, K.COURT_SIDELINE_TOP],
		"far_right": [K.COURT_BASELINE_RIGHT, K.COURT_SIDELINE_TOP],
		"near_left": [K.COURT_BASELINE_LEFT, K.COURT_SIDELINE_BOTTOM],
		"near_right": [K.COURT_BASELINE_RIGHT, K.COURT_SIDELINE_BOTTOM],
	}
	for k in world:
		var s := CourtView.ground(K.to_fp(world[k][0]), K.to_fp(world[k][1]))
		var want := Vector2(corners[k][0], corners[k][1])
		check(s.distance_to(want) < 0.5, "%s corner %s vs painted %s" % [k, s, want])
	var court: Dictionary = _manifest()["court"]
	for u in court["kitchen_u"]:
		var x_world: float = K.COURT_BASELINE_LEFT + float(u) * (K.COURT_BASELINE_RIGHT - K.COURT_BASELINE_LEFT)
		var kx := K.COURT_KITCHEN_LEFT_X if u < 0.5 else K.COURT_KITCHEN_RIGHT_X
		check(absf(x_world - kx) < 0.6, "painted kitchen line %.2f is the rules' %d" % [x_world, kx])


func test_net_height_matches_the_painted_net() -> void:
	var net: Dictionary = _manifest()["court"]["net"]
	var far := CourtView.z_scale(K.to_fp(K.COURT_SIDELINE_TOP)) * K.COURT_NET_HEIGHT
	var near := CourtView.z_scale(K.to_fp(K.COURT_SIDELINE_BOTTOM)) * K.COURT_NET_HEIGHT
	check(absf(far - float(net["tape_height_far"])) < 0.01, "far tape %f" % far)
	check(absf(near - float(net["tape_height_near"])) < 0.01, "near tape %f" % near)


func test_view_never_writes_to_the_sim() -> void:
	var view := MatchView.new()
	runner.root.add_child(view)
	view.setup(SimTypes.MatchConfig.doubles(), "sunset", true)
	var bare := Sim.new(SimTypes.MatchConfig.doubles())
	bare.start_attract()
	for f in 1500:
		view._physics_process(1.0 / 60.0)
		bare.step()
		bare.drain_events()
		if view.sim.snapshot() != bare.snapshot():
			runner.fail("view's sim diverged from a bare sim at frame %d" % f)
			view.queue_free()
			return
	check(true)
	view.queue_free()


func test_every_venue_builds() -> void:
	for venue in ["park", "lakeside", "sunset"]:
		var view := MatchView.new()
		runner.root.add_child(view)
		view.setup(SimTypes.MatchConfig.singles(), venue, false)
		for f in 60:
			view._physics_process(1.0 / 60.0)
		check(view.get_child_count() > 8, "%s built its layers" % venue)
		view.queue_free()


func test_title_config_takes_the_opponent() -> void:
	TitleScreen.opponent_i = 0
	TitleScreen.difficulty_i = K.DIFFICULTY_HARD
	TitleScreen.points_i = 3
	var t := TitleScreen.new()
	var cfg := t.config(true)
	eq(cfg.opponent, 0)
	eq(cfg.difficulty, K.DIFFICULTY_HARD)
	eq(cfg.points_to_win, 9)
	var members: Array = Opponents.team(0)["players"]
	eq(cfg.paddle[2], Paddles.NAMES.find(members[0]["paddle"]), "captain's paddle")
	var sim := Sim.new(cfg)
	eq(sim.ai.styles[2].late_period, Opponents.team(0)["players"][0]["style_obj"].late_period
		+ Opponents.team(0)["players"][0]["style_obj"].late_period / 2 + 2, "HARD tightens the captain")
	TitleScreen.opponent_i = -1
	TitleScreen.difficulty_i = K.DIFFICULTY_MEDIUM
	TitleScreen.points_i = 1
	t.free()


## ADR-023 through the real view: a ladder win records the match, moves
## the save's rung on, and B asks for the next opponent (not a rematch).
func test_ladder_win_advances_and_offers_the_next_rung() -> void:
	var save := SaveGame.new()
	save.dir = "user://test_view_save/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save.dir))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.dir + f))
	save.load_game()
	var view := MatchView.new()
	view.save = save
	view.ladder = true
	runner.root.add_child(view)
	view.setup(TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), "park", false)
	check(view.card_frames >= 0, "ladder match opens on the card")
	view.card_frames = -1
	var asked := [false]
	view.next_rung.connect(func(): asked[0] = true)
	var sim := view.sim
	sim.team_score[0] = 4
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1, K.FAULT_OUT)
	for f in K.POINT_RESULT_FRAMES + 5:
		view._physics_process(1.0 / 60.0)
	eq(sim.phase, K.PHASE_MATCH_RESULT, "match over")
	eq(save.data["records"]["singles_wins"], 1, "the win is recorded")
	eq(save.data["records"]["ladder_rung"], 1, "on to the next rung")
	sim.rematch_requested = true
	view._physics_process(1.0 / 60.0)
	check(asked[0], "B after a ladder win asks for the next opponent")
	view.queue_free()


## ADR-050/051: with the camera on, the picture leans toward the ball and
## the layers move at their parallax; off, nothing moves. Either way the
## sim is untouched (the view's sim equals a bare one).
func test_camera_leans_and_parallax() -> void:
	for pct in [0, 100]:
		var view := MatchView.new()
		view.camera_percent = pct
		runner.root.add_child(view)
		view.setup(SimTypes.MatchConfig.singles(), "park", true)
		var bare := Sim.new()
		bare.start_attract()
		var max_cam := 0.0
		for f in 900:
			view._physics_process(1.0 / 60.0)
			bare.step()
			bare.drain_events()
			max_cam = maxf(max_cam, view.cam.length())
		eq(view.sim.snapshot(), bare.snapshot(), "camera %d%% leaves the sim alone" % pct)
		if pct == 0:
			eq(max_cam, 0.0, "OFF never moves")
		else:
			check(max_cam > 4.0 and max_cam <= MatchView.CAM_MAX.length() + 0.01,
				"ON leans within its limit (%.1f px)" % max_cam)
			var sky: Array = view._layers[0]
			var ground: Array = view._layers[3]
			check(absf((sky[0].position - sky[1]).x) <= absf((ground[0].position - ground[1]).x) + 1,
				"the sky moves less than the ground")
		view.queue_free()
