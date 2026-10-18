## PORT-08: records and initials (ADR-021, ADR-040): save layout v4 and
## its migration, test_save.c's initials rules, test_story.c's initials
## card, and the view and page around them. Records never count in the
## demo.
extends TestSuite

const DIR := "user://test_records/"


func _fresh() -> SaveGame:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	var s := SaveGame.new()
	s.dir = DIR
	s.load_game()
	return s


func test_v3_save_migrates_to_v4() -> void:
	var s := _fresh()
	var v3 := SaveGame.defaults()
	v3.erase("initials")
	for k in ["streak", "best_streak", "shutouts", "vs"]:
		v3["records"].erase(k)
	v3["records"]["singles_wins"] = 9
	v3["records"]["longest_rally"] = 23
	v3["records"]["practice_zone_best"] = [1, 2, 3, 4]
	v3["settings"]["venue"] = 2
	var payload := JSON.stringify(v3, "", true)
	var f := FileAccess.open(DIR + "save_a.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"magic": SaveGame.MAGIC, "version": 3, "seq": 5,
		"checksum": SaveGame.checksum(payload), "payload": payload}))
	f = null
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	eq(t.data["records"]["singles_wins"], 9, "records carry over")
	eq(t.data["records"]["longest_rally"], 23)
	eq(t.data["records"]["practice_zone_best"], [1, 2, 3, 4])
	eq(t.data["settings"]["venue"], 2, "settings carry over")
	eq([t.data["records"]["streak"], t.data["records"]["best_streak"], t.data["records"]["shutouts"]],
		[0, 0, 0], "the new counts start at 0")
	eq(t.data["records"]["vs"].size(), Opponents.count(), "a record against each opponent")
	eq(t.data["initials"], {"best_streak": "", "longest_rally": ""}, "nobody holds a record yet")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "save_b.json"))
	eq(int(raw["version"]), SaveGame.VERSION, "rewritten as the current layout")


func test_initials_rules() -> void:   # test_save.c test_initials
	var s := _fresh()
	s.record_rally(9)
	eq(s.new_records, SaveGame.NEW_RALLY, "a longer rally is new")
	s.set_initials("ABC")
	eq(s.data["initials"]["longest_rally"], "ABC")
	eq(s.new_records, 0)
	check(not s.record_rally(5), "a shorter rally beats nothing")
	eq(s.data["initials"]["longest_rally"], "ABC", "and keeps its holder")
	s.record_rally(12)
	eq(s.data["initials"]["longest_rally"], "", "a beaten record clears its initials at once")
	s.record_match(false, true, 0, 3)
	eq(s.new_records, SaveGame.NEW_RALLY | SaveGame.NEW_STREAK, "a first win: a new best streak too")
	s.set_initials("XYZ")
	eq(s.data["initials"], {"best_streak": "XYZ", "longest_rally": "XYZ"}, "one entry names both")
	# a run extends its own record without asking
	s.record_match(false, true, 1, 0)
	eq(s.data["records"]["best_streak"], 2)
	eq(s.new_records, 0, "the same run: no new initials")
	eq(s.data["initials"]["best_streak"], "XYZ")
	eq(s.data["records"]["shutouts"], 1, "won 5-0: a shutout")
	s.record_match(true, false, 1)
	eq(s.data["records"]["streak"], 0, "a loss ends the run")
	eq(s.new_records, 0, "a loss beats nothing")
	eq(s.data["records"]["vs"][1], [1, 1], "the record against that team")
	eq(s.data["records"]["vs"][0], [1, 0])
	s.record_match(false, true)
	s.record_match(false, true)
	s.record_match(false, true)
	eq(s.new_records, SaveGame.NEW_STREAK, "a new run past the record asks again")
	s.drop_new_records()
	eq(s.new_records, 0, "a match left early asks for nothing")
	eq(s.data["records"]["best_streak"], 3, "but keeps the number")
	var after := SaveGame.new()
	after.dir = DIR
	s.save_game()
	after.load_game()
	after.record_match(false, true)
	eq(after.new_records, SaveGame.NEW_STREAK, "after a power cycle the run isn't held")
	s.erase_records()
	eq(s.data["initials"], {"best_streak": "", "longest_rally": ""}, "erase clears the holders")
	eq(s.data["records"]["singles_wins"], 0, "and the records")
	eq(s.data["settings"]["venue"], SaveGame.defaults()["settings"]["venue"], "settings untouched")


func _card(new_records: int) -> Initials:
	var s := _fresh()
	s.new_records = new_records
	var ini := Initials.new()
	ini.begin(s)
	return ini


func test_initials_card() -> void:   # test_story.c test_initials_card
	Initials.last = "AAA"
	check(not Initials.new().begin(_fresh()), "no record, no card")
	var ini := _card(SaveGame.NEW_RALLY)
	check(ini.open, "a record opens it")
	eq(ini.text(), "AAA", "starting from the last initials")
	ini.update(Initials.PAD_DOWN, Initials.PAD_DOWN)
	eq(ini.text(), "ZAA", "letters wrap")
	ini.update(Initials.PAD_UP, Initials.PAD_UP)
	var steps := 0
	for f in 15:
		ini.update(0, Initials.PAD_UP)
	eq(ini.text(), "AAA", "held Up waits 16 frames")
	ini.update(0, Initials.PAD_UP)
	eq(ini.text(), "BAA", "then repeats")
	for f in 4:
		ini.update(0, Initials.PAD_UP)
	eq(ini.text(), "CAA", "every 4 frames")
	ini.update(0, 0)
	ini = _card(SaveGame.NEW_RALLY)
	ini.update(Initials.PAD_B, Initials.PAD_B)
	ini.update(Initials.PAD_START, Initials.PAD_START)
	check(ini.open and ini.cursor == 0, "nothing but Up/Down for the first 30 frames")
	while ini.timer < Initials.MIN_FRAMES:
		ini.update(0, 0)
	ini.update(Initials.PAD_UP, Initials.PAD_UP)
	ini.update(Initials.PAD_B, 0)
	eq(ini.cursor, 1, "B moves on")
	ini.update(Initials.PAD_A, 0)
	eq(ini.cursor, 2, "A too")
	ini.update(Initials.PAD_Y, 0)
	eq(ini.cursor, 1, "Y goes back")
	ini.update(Initials.PAD_RIGHT, 0)
	ini.update(Initials.PAD_UP, 0)
	ini.update(Initials.PAD_UP, 0)
	check(not ini.update(Initials.PAD_B, 0), "B past the third saves")
	eq(ini.save.data["initials"]["longest_rally"], "BAC")
	eq(Initials.last, "BAC", "the next card starts there")
	ini = _card(SaveGame.NEW_STREAK)
	eq(ini.text(), "BAC")
	for f in Initials.FRAMES - 1:
		ini.update(0, 0)
	check(ini.open, "still up just before the timeout")
	check(not ini.update(0, 0), "the timeout keeps the letters shown")
	eq(ini.save.data["initials"]["best_streak"], "BAC")
	ini = _card(SaveGame.NEW_STREAK)
	while ini.timer < Initials.MIN_FRAMES:
		ini.update(0, 0)
	check(not ini.update(Initials.PAD_START, 0), "Start saves at once")
	Initials.last = "AAA"


func _finish(view: MatchView, winner: int) -> void:
	var sim := view.sim
	sim.team_score[winner] = sim.config.points_to_win - 1
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1 - winner, K.FAULT_OUT)     # the faulting team
	for f in K.POINT_RESULT_FRAMES + 5:
		view._physics_process(1.0 / 60.0)


func test_card_after_a_finished_match_only() -> void:
	var s := _fresh()
	var view := MatchView.new()
	view.save = s
	runner.root.add_child(view)
	view.setup(Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 5), "park", false)
	_finish(view, 0)
	eq(view.sim.phase, K.PHASE_MATCH_RESULT)
	check(view.initials.open, "a win (a first best streak) asks for initials")
	eq(s.data["records"]["vs"][2], [1, 0], "against that team")
	eq(s.data["records"]["shutouts"], 1, "won without a point against")
	var frame := view.sim.frame_count
	view._physics_process(1.0 / 60.0)
	eq(view.sim.frame_count, frame, "the match waits under the card")
	view._hud.refresh()
	check(view._hud._initials.visible and view._hud._banner.text == "", "the card, not the result")
	view.free()
	# a match left early: the rally record stays, the request goes
	var v2 := MatchView.new()
	v2.save = s
	runner.root.add_child(v2)
	v2.setup(SimTypes.MatchConfig.singles(), "park", false)
	s.record_rally(40)
	check(s.new_records != 0, "a new rally record mid-match")
	v2.sim.paused = 1
	v2._update_visuals()
	v2._hud.pause_menu.select("restart")
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	v2._pause_input(it)
	eq(s.new_records, 0, "RESTART drops the request (only a finished match asks)")
	eq(s.data["records"]["longest_rally"], 40, "and keeps the record")
	v2.free()


func test_records_never_count_in_the_demo() -> void:
	var s := _fresh()
	var before := s.data.duplicate(true)
	var view := MatchView.new()
	view.save = s
	runner.root.add_child(view)
	view.setup(SimTypes.MatchConfig.singles(), "park", true)
	var results := 0
	for f in 6000:
		view._physics_process(1.0 / 60.0)
		if view.sim.phase == K.PHASE_MATCH_RESULT:
			results += 1
	check(results > 0, "the demo finished a match")
	eq(s.data, before, "and recorded nothing")
	check(not view.initials.open and s.new_records == 0, "nor asked for initials")
	view.free()


func test_records_page() -> void:
	var s := _fresh()
	s.data["records"]["best_streak"] = 4
	s.data["initials"]["best_streak"] = "ZED"
	s.data["records"]["vs"][3] = [2, 5]
	var t := TitleScreen.new()
	t.save = s
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	t.open_page("records")
	var p: MenuPage = t.pages["records"]
	eq(p.value_of("streak"), "ZED 4", "the holder before the count")
	eq(p.value_of("rally"), "--- 0", "--- for nobody")
	p.select("vs")
	for i in 3:
		p.change(1)
	eq(p.value_of("vs"), "%s 2-5" % Opponents.team(3)["team"], "VS steps through the teams")
	p.select("erase")
	p.press()
	eq(s.data["records"]["best_streak"], 4, "one press only arms the erase")
	eq(p.value_of("erase"), "B AGAIN")
	p.press()
	eq(s.data["records"]["best_streak"], 0, "the second erases")
	eq(s.data["initials"]["best_streak"], "")
	t.free()
