## PORT-07: the close call (ADR-041, test_replay.c ported) and the
## partner sitting out (ADR-042). Both display only.
extends TestSuite


func test_close_calls() -> void:   # test_replay.c
	# two pixels past the right baseline after a long rally: ~4.7 inches, +x
	var c := Replay.check(K.to_fp(K.COURT_BASELINE_RIGHT + 2), K.to_fp(K.COURT_CENTERLINE_Y),
		Replay.MIN_SHOTS, K.FAULT_OUT)
	check(not c.is_empty() and c["vertical"] and c["out_dir"] == 1, "a baseline, toward +x")
	eq([c.get("dist_fp"), c.get("inches")], [K.to_fp(2), 4])
	# a short rally, another fault, or a wide miss: no close-up
	check(Replay.check(K.to_fp(K.COURT_BASELINE_RIGHT + 2), K.to_fp(K.COURT_CENTERLINE_Y),
		Replay.MIN_SHOTS - 1, K.FAULT_OUT).is_empty(), "short rally")
	check(Replay.check(K.to_fp(K.COURT_BASELINE_RIGHT + 2), K.to_fp(K.COURT_CENTERLINE_Y),
		Replay.MIN_SHOTS, K.FAULT_NET).is_empty(), "another fault")
	check(Replay.check(K.to_fp(K.COURT_BASELINE_RIGHT + 6), K.to_fp(K.COURT_CENTERLINE_Y),
		Replay.MIN_SHOTS, K.FAULT_OUT).is_empty(), "6 px out is over 6 inches")
	check(Replay.check(K.to_fp(K.COURT_BASELINE_RIGHT + 60), K.to_fp(K.COURT_CENTERLINE_Y),
		Replay.MIN_SHOTS, K.FAULT_OUT).is_empty(), "a wide miss")
	# past the top sideline by a hair: a horizontal line, toward -y
	c = Replay.check(K.to_fp(100), K.to_fp(K.COURT_SIDELINE_TOP) - 3, Replay.MIN_SHOTS + 4, K.FAULT_OUT)
	check(not c.is_empty() and not c["vertical"] and c["out_dir"] == -1, "a sideline, toward -y")
	eq(c.get("inches"), 0)
	eq(Replay.caption(0), "OUT BY A HAIR!")
	eq(Replay.caption(1), "OUT BY 1 INCH!")
	eq(Replay.caption(4), "OUT BY 4 INCHES!")
	# past the left baseline and the bottom sideline: the farther one
	c = Replay.check(K.to_fp(K.COURT_BASELINE_LEFT) - 8, K.to_fp(K.COURT_SIDELINE_BOTTOM) + 20,
		Replay.MIN_SHOTS, K.FAULT_OUT)
	check(not c.is_empty() and not c["vertical"] and c["out_dir"] == 1, "the farther line")
	# landed in (an OUT on the hitter's own side): no line
	check(Replay.check(K.to_fp(100), K.to_fp(K.COURT_CENTERLINE_Y), Replay.MIN_SHOTS,
		K.FAULT_OUT).is_empty(), "no line to call")


func _view(cfg: SimTypes.MatchConfig, venue := "park", demo := false) -> MatchView:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, venue, demo)
	return v


## The view's hook on the point result's first frame: a long rally just
## out shows the close-up (caption, the ball at rest past the line, the
## quip held back); a short one doesn't; leaving the point result ends it.
func test_close_up_in_the_view() -> void:
	var v := _view(SimTypes.MatchConfig.singles())
	var s := v.sim
	s.ball.x_fp = K.to_fp(K.COURT_BASELINE_RIGHT) + 10
	s.ball.y_fp = K.to_fp(140)
	s.last_fault = K.FAULT_OUT
	s.shot_serial = (s.rally_start + 3) & 0xff
	v._check_close_call()
	check(v.close_call == null, "a 3-shot rally: no close-up")
	s.shot_serial = (s.rally_start + 11) & 0xff
	v._check_close_call()
	check(v.close_call != null, "an 11-shot rally just out: the close-up")
	eq(v.close_call._caption.text, "OUT BY 1 INCH!")
	for i in 80:
		v.close_call.update()
	check(v.close_call.ball_rest.x > v.close_call.line_at.x, "the ball rests past the line, toward out")
	eq(v.close_call._ball.position + CloseCall.INSET.position, v.close_call.ball_rest, "and settles")
	v._hud.show_quip("TEST", Color.WHITE)
	s.phase = K.PHASE_POINT_RESULT
	v._hud.refresh()
	check(not v._hud._quip.visible, "the close-up holds back the quip")
	v._end_close_call()
	check(v.close_call == null, "gone after the point result")
	v.free()


func test_watcher_only_in_singles_ladder() -> void:
	var cases := [
		[TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), false, true, "singles vs a ladder team"],
		[TitleScreen.config_for(true, 0, K.DIFFICULTY_MEDIUM, 5), false, false, "doubles"],
		[TitleScreen.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5), false, false, "the default CPU"],
		[TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), true, false, "the demo"],
		[SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0), false, false, "practice"],
	]
	var pv := TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5, {},
		PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD))
	cases.append([pv, false, false, "2P"])
	for c in cases:
		var v := _view(c[0], "park", c[1])
		eq(v.watcher.size() > 0, c[2], c[3])
		v.free()


func test_watcher_takes_a_seat_and_cheers() -> void:
	for venue in TitleScreen.VENUES:
		var v := _view(TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), venue)
		var hidden := v._crowd.filter(func(c): return not c[0].visible).size()
		eq(hidden, 1, "%s: the watcher takes one spectator's seat" % venue)
		var spot: Dictionary = v.manifest["venues"][venue]["watcher"]
		check(Rect2(0, 0, 960, 540).has_point(Vector2(spot["x"], spot["y"])), "%s: on screen" % venue)
		v.free()
	var v := _view(TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5))
	var rest: Vector2 = v.watcher[0].position
	v._on_event([K.EVENT_POINT, 128, 130, 0])
	check(v._watcher_cheer == 0, "the other side's point: no cheer")
	v._on_event([K.EVENT_POINT, 128, 130, 1])
	check(v._watcher_cheer > 0, "their teammate's point: a cheer")
	var cheer_region: float = MatchView.SLOTS.find("cheer") * MatchView.FRAME
	var hopped := false
	for i in 20:
		v.sim.frame_count += 1
		v._update_watcher()
		hopped = hopped or v.watcher[0].position.y < rest.y
	eq(v.watcher[0].region_rect.position.x, cheer_region, "the cheer frame")
	check(hopped, "and a hop")
	v.free()
	var night := MatchView.new()
	night.time = CourtStyle.NIGHT
	runner.root.add_child(night)
	night.setup(TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5), "park", false)
	eq(night.watcher[0].modulate, CourtStyle.time_scales(CourtStyle.NIGHT)[0],
		"at NIGHT the watcher sits in the dark with the crowd (KNOWN_ISSUES #24)")
	night.free()


## Display only: a singles ladder match with the watcher and close-up
## hooks runs exactly like a bare sim.
func test_display_only() -> void:
	var cfg := TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5)
	var v := _view(cfg)
	v.sim.p1_bot = true
	var bare := Sim.new(TitleScreen.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5))
	bare.p1_bot = true
	var calls := 0
	for f in 1500:
		v._physics_process(1.0 / 60.0)
		if v.close_call:
			calls += 1
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % f)
			break
	eq(v.sim.snapshot(), bare.snapshot(), "1500 frames match a bare sim")
	v.free()
