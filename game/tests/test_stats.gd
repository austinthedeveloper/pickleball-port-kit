## PORT-13: post-match stats from sim events (scripted points, then a
## real match), the card on the result screen, the totals in the records,
## and display only.
extends TestSuite

const S0 := 0                    ## P1's slot
const S2 := 2                    ## the CPU's slot


func _ev(kind: int, a3: int) -> Array:
	return [kind, 128, 130, a3]


func test_scripted_points() -> void:
	var st := MatchStats.new()
	# P1 serves, the CPU returns, P1 drives it past them (two bounces)
	st.on_event(_ev(K.EVENT_SERVE, S0))
	st.on_event(_ev(K.EVENT_HIT, S2 | (K.SHOT_STANDARD << 4)))
	st.on_event(_ev(K.EVENT_HIT, S0 | (K.SHOT_DRIVE << 4)))
	st.on_event(_ev(K.EVENT_POINT, 0))
	eq(st.teams[0]["winners"], [0, 1, 0], "a drive winner")
	eq([st.teams[0]["serve_won"], st.teams[0]["serve_points"]], [1, 1])
	eq(st.teams[0]["drives"], 1)
	eq(st.rallies, [3], "three shots, the serve included")
	# an ace: the serve never comes back
	st.on_event(_ev(K.EVENT_SERVE, S0))
	st.on_event(_ev(K.EVENT_POINT, 0))
	eq(st.teams[0]["aces"], 1, "an unreturned serve is an ace")
	eq(st.winners(0), 2, "and a winner")
	# the CPU serves, P1 hits it out: P1's error, the CPU's serve point
	st.on_event(_ev(K.EVENT_SERVE, S2))
	st.on_event(_ev(K.EVENT_HIT, S0 | (K.SHOT_SOFT << 4)))
	st.on_event(_ev(K.EVENT_FAULT, K.FAULT_OUT))
	st.on_event(_ev(K.EVENT_POINT, 1))
	eq(st.errors(0), 1, "P1's error")
	eq(st.top_error(0), "OUT 1")
	eq(st.top_error(1), "-")
	eq([st.teams[1]["serve_won"], st.teams[1]["serve_points"]], [1, 1])
	eq(st.teams[1]["aces"], 0, "won on an error isn't an ace")
	eq([st.teams[0]["points"], st.teams[1]["points"]], [2, 1])
	eq(st.longest_rally(), 3)
	check(is_equal_approx(st.average_rally(), 2.0), "average (3 + 1 + 2) / 3")
	var rows := st.rows()
	eq(rows[0], ["POINTS", "2", "1"])
	eq(rows[1], ["SERVE WON", "2/2", "1/1"])
	eq(rows[3][1], "2 STD", "winners, by the most common shot")
	eq(st.rally_line(), "LONGEST RALLY 3   AVERAGE 2.0")


## A whole bot match: every point counted once, a rally for each, and
## the shots match the hits the sim reported.
func test_a_real_match_adds_up() -> void:
	var sim := Sim.new(Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 11))
	sim.p1_bot = true
	var st := MatchStats.new()
	var hits := 0
	for f in 40000:
		if sim.phase == K.PHASE_MATCH_RESULT:
			break
		if sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0:
			sim.serve_requested = 1
		sim.step()
		for e in sim.drain_events():
			st.on_event(e)
			if e[0] == K.EVENT_HIT or e[0] == K.EVENT_SERVE:
				hits += 1
	eq(sim.phase, K.PHASE_MATCH_RESULT, "the match finished")
	eq([st.teams[0]["points"], st.teams[1]["points"]], sim.team_score, "points = the score")
	eq(st.rallies.size(), sim.team_score[0] + sim.team_score[1], "a rally per point")
	eq(st.teams[0]["shots"] + st.teams[1]["shots"], hits, "every shot counted")
	var sp: int = st.teams[0]["serve_points"] + st.teams[1]["serve_points"]
	eq(sp, st.rallies.size(), "every point had a server")
	for t in 2:
		check(st.winners(t) + st.errors(1 - t) <= st.teams[t]["points"],
			"team %d's points: winners plus the other side's errors, at most" % t)


func _finish(view: MatchView) -> void:
	var sim := view.sim
	sim.team_score[0] = sim.config.points_to_win - 1
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1, K.FAULT_OUT)
	for f in K.POINT_RESULT_FRAMES + 5:
		view._physics_process(1.0 / 60.0)


func test_card_and_totals() -> void:
	var save := SaveGame.new()
	save.dir = "user://test_stats/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save.dir))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.dir + f))
	save.load_game()
	var v := MatchView.new()
	v.save = save
	runner.root.add_child(v)
	v.setup(Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5), "park", false)
	_finish(v)
	eq(v.sim.phase, K.PHASE_MATCH_RESULT)
	check(v.initials.open, "a first win asks for initials first")
	v._hud.refresh()
	check(v._hud._stats_card == null or not v._hud._stats_card.visible, "no card under the initials")
	for f in Initials.MIN_FRAMES:
		v.initials.update(0, 0)
	v.initials.update(Initials.PAD_START, 0)
	v._hud.refresh()
	check(v._hud._stats_card != null and v._hud._stats_card.visible, "then the card")
	eq(v._hud._banner.position.y, 96.0, "the banner moves up over it")
	eq(int(save.data["records"]["points_won"]), 1, "the point rolled into the records")
	eq(int(save.data["records"]["points_lost"]), 0)
	v.sim.rematch_requested = true
	v._physics_process(1.0 / 60.0)
	check(v._hud._stats_card == null, "a rematch clears the card")
	eq(v.stats.rallies, [], "and the stats")
	v.free()
	var demo := MatchView.new()
	runner.root.add_child(demo)
	demo.setup(SimTypes.MatchConfig.singles(), "park", true)
	demo.sim.phase = K.PHASE_MATCH_RESULT
	demo._hud.refresh()
	check(not demo._hud.stats_shown(), "no card in the demo")
	demo.free()


func test_display_only() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(Settings.config_for(true, 1, K.DIFFICULTY_HARD, 7), "sunset", false)
	v.sim.p1_bot = true
	var bare := Sim.new(Settings.config_for(true, 1, K.DIFFICULTY_HARD, 7))
	bare.p1_bot = true
	for f in 1500:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
	eq(v.sim.snapshot(), bare.snapshot(), "1500 frames with stats on match a bare sim")
	check(v.stats.teams[0]["shots"] + v.stats.teams[1]["shots"] > 0, "and stats were collected")
	v.free()
