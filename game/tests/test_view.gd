## Presentation checks: the painted court is the called court, and the view
## never writes to the sim (playbook rules 2 and "the line you see is the
## line that's called").
extends TestSuite


func _manifest() -> Dictionary:
	return MatchView.levels_manifest()


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
	for venue in Settings.VENUES:
		var view := MatchView.new()
		runner.root.add_child(view)
		view.setup(SimTypes.MatchConfig.singles(), venue, false)
		for f in 60:
			view._physics_process(1.0 / 60.0)
		check(view.get_child_count() > 8, "%s built its layers" % venue)
		view.queue_free()


func test_title_config_takes_the_opponent() -> void:
	Settings.opponent_i = 0
	Settings.difficulty_i = K.DIFFICULTY_HARD
	Settings.points_i = 3
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
	Settings.opponent_i = -1
	Settings.difficulty_i = K.DIFFICULTY_MEDIUM
	Settings.points_i = 1
	t.free()


## ADR-023 through the real view: a ladder win records the match, moves
## the save's rung on, and B asks for the next opponent (not a rematch).
func test_ladder_win_advances_and_offers_the_next_rung() -> void:
	var save := fresh_save("user://test_view_save/")
	var view := MatchView.new()
	view.save = save
	view.ladder = true
	runner.root.add_child(view)
	view.setup(Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), "park", false)
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
	check(view.initials.open, "a first win is a new best streak: the initials card")
	for f in Initials.MIN_FRAMES:
		view.initials.update(0, 0)
	check(not view.initials.update(Initials.PAD_START, 0), "Start enters them")
	eq(save.data["initials"]["best_streak"], "AAA")
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
		view.camera.percent = pct
		runner.root.add_child(view)
		view.setup(SimTypes.MatchConfig.singles(), "park", true)
		var bare := Sim.new()
		bare.start_attract()
		var max_cam := 0.0
		for f in 900:
			view._physics_process(1.0 / 60.0)
			bare.step()
			bare.drain_events()
			max_cam = maxf(max_cam, view.camera.offset.length())
		eq(view.sim.snapshot(), bare.snapshot(), "camera %d%% leaves the sim alone" % pct)
		if pct == 0:
			eq(max_cam, 0.0, "OFF never moves")
		else:
			check(max_cam > 4.0 and max_cam <= CameraLean.MAX.length() + 0.01,
				"ON leans within its limit (%.1f px)" % max_cam)
			var sky: Array = view._layers[0]
			var ground: Array = view._layers[3]
			check(absf((sky[0].position - sky[1]).x) <= absf((ground[0].position - ground[1]).x) + 1,
				"the sky moves less than the ground")
		view.queue_free()


## M4-OPP-04: ladder opponents wear their own colours and hats (role
## sheets through the palette swap); the human's side keeps its team sheet.
func test_ladder_opponents_wear_their_looks() -> void:
	var pirates := -1
	for t in Opponents.count():
		if Opponents.team(t)["players"][0]["hat"] == "tricorn":
			pirates = t
	check(pirates >= 0, "a team wears the tricorn")
	var view := MatchView.new()
	runner.root.add_child(view)
	view.setup(Settings.config_for(true, pirates, K.DIFFICULTY_MEDIUM, 11), "park", false)
	view._physics_process(1.0 / 60.0)
	check(view._players[0]["look"] == null, "P1 keeps the team sheet")
	check(view._players[0]["body"].material == null, "no palette swap on P1")
	var members: Array = Opponents.team(pirates)["players"]
	for slot in [2, 3]:
		var m: Dictionary = members[slot - 2]
		var e: Dictionary = view._players[slot]
		var body: Sprite2D = e["body"]
		check(body.texture.resource_path.ends_with("roles/player_%s_body.png" % m["variant"]), "slot %d body" % slot)
		check(e["cap"].texture.resource_path.ends_with("_%s.png" % m["hat"]), "slot %d wears the %s" % [slot, m["hat"]])
		var pal: PackedColorArray = body.material.get_shader_parameter("palette")
		var order: String = view.manifest["sprites"]["players"]["roles"]["order"]
		eq(pal[order.find("M")], PlayerLook.rgb5(m["shirt"][1]), "slot %d shirt" % slot)
		eq(pal[order.find("k")], PlayerLook.rgb5(m["shoe"]), "slot %d shoe accent" % slot)
		check(not pal.has(Color.MAGENTA), "slot %d every role coloured" % slot)
	view.queue_free()


func test_rgb5_expands_like_the_dac() -> void:
	eq(PlayerLook.rgb5([31, 0, 16]), Color8(255, 0, 132))


## A new view places its people and ball before its first tick (the title
## restarts its demo on a COURT or TIME change; they used to flash in the
## top-left corner, at the origin, for a frame).
func test_new_view_places_everyone_at_once() -> void:
	for doubles in [false, true]:
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles(), "park", true)
		for i in K.MAX_PLAYERS:
			var e: Dictionary = v._players[i]
			if v.sim.players[i].active:
				check(e["root"].position.length() > 100.0, "player %d placed on court" % i)
			else:
				check(not e["root"].visible, "an empty slot hidden")
		check(not v._ball_root.visible or v._ball_root.position.length() > 100.0, "the ball placed or hidden")
		v.free()


## SNES ADR-055: pause, MAIN MENU in a ladder match starts that mode's
## ladder over (and saves); outside the ladder nothing moves.
func test_quitting_a_ladder_match_resets_it() -> void:
	for ladder in [true, false]:
		var s := SaveGame.new()
		s.dir = "user://test_view_save/"
		s.data = SaveGame.defaults()
		s.career = Career.from_dict(s.data["career"])
		s.data["records"]["ladder_doubles"] = 3
		s.data["records"]["ladder_rung"] = 2
		var v := MatchView.new()
		v.save = s
		v.ladder = ladder
		runner.root.add_child(v)
		var cfg := SimTypes.MatchConfig.doubles()
		cfg.opponent = 3
		v.setup(cfg, "park", false)
		v.input.pause_choice = "menu"
		v.input.pause_input(SimTypes.Intent.new())
		eq([s.ladder(false), s.ladder(true)], [2, 0] if ladder else [2, 3],
			"ladder %s: doubles reset, singles kept" % ladder if ladder else "not a ladder match: nothing moves")
		v.free()


## KNOWN_ISSUES #68: the people in the stands (the crowd, the watching
## partner) move with the stands layer as the camera leans.
func test_the_crowd_moves_with_the_stands() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.camera.percent = 100
	v.setup(Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 11), "park", false)
	v.card_frames = -1
	v.sim.p1_bot = true
	var stands: Array = []
	for l in v._layers:
		if l[2] == v._stands_parallax and l[0].texture.resource_path.contains("stands"):
			stands = l
	check(not stands.is_empty(), "the stands layer")
	var moved := false
	for f in 900:
		v._physics_process(1.0 / 60.0)
		var shift: Vector2 = stands[0].position - stands[1]
		if f % 100 == 0:
			eq(v.crowd.position, shift, "the crowd with the stands")
			if v.watcher:
				eq(v.watcher.position, shift, "and the watcher")
		moved = moved or shift != Vector2.ZERO
	check(moved, "the camera leaned")
	v.free()


## KNOWN_ISSUES #69, display only: a ball on the near side (below the feet
## on screen, where the ROM's hit area reaches) gets the low reach, and the
## drawn player steps toward it; the sim's player never moves for it.
func test_near_side_reach() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11)
	v.setup(cfg, "park", false)
	v.card_frames = -1
	v.sim.p1_bot = true
	v.highlight = null
	var p: SimTypes.Player = v.sim.players[0]
	v.sim.ball.rally_state = K.BALL_RALLY_LIVE
	v.sim.ball.z_fp = K.to_fp(10)
	v.sim.ball.y_fp = p.y_fp + K.to_fp(12)
	eq(v.actors.choose_swing(p), "reach", "a ball on the near side: the low reach")
	v.sim.ball.y_fp = p.y_fp - K.to_fp(4)
	eq(v.actors.choose_swing(p), "standard", "one just behind the feet: the swing")
	v.free()
	# a match: some reaches step down; it plays as a bare sim does
	var m := match_view(cfg)
	m.highlight = null
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	var most := 0.0
	for f in 4000:
		m._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		for i in K.MAX_PLAYERS:
			most = maxf(most, float(m._players[i].get("lean", 0.0)))
	check(most > 4.0, "a near-side reach stepped toward the ball (%.1f px)" % most)
	check(most <= MatchActors.LEAN_MAX + 0.01, "never past the cap")
	eq(m.sim.snapshot(), bare.snapshot(), "display only")
	bare.dispose()
	m.free()
