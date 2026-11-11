## The WEEKLY CHALLENGE and the score boards (PORT-158/159, port ADR-109):
## weeks counted as the relay counts them, every challenge playable, the
## goals judged, the week's best kept, a bot playing this week's to the
## end, the boards' scores and names; and, with the relay beside the kit
## (or PB94_RELAY_JS), a score posted and read back through it.
extends TestSuite

const DIR := "user://test_weekly/"
const NODE_PORT := 24994 + 15


func test_iso_weeks() -> void:
	for case: Array in [[20261111, [2026, 46]], [20270101, [2026, 53]], [20240101, [2024, 1]],
			[20210103, [2020, 53]], [20261231, [2026, 53]], [20270104, [2027, 1]], [20200229, [2020, 9]]]:
		eq(Boards.iso_week(case[0]), case[1], str(case[0]))
	eq(Boards.week_board([2026, 46]), "week-202646")
	eq(Boards.trip_board(20261111), "trip-20261111")


func test_every_challenge_is_playable() -> void:
	var chars := String(BitmapText.load_font("small")["chars"])
	for c: Dictionary in Weekly.challenges():
		check(String(c["venue"]) in Settings.VENUES, c["name"] + ": its venue")
		check(Opponents.exists(int(c["opponent"])), c["name"] + ": its team")
		check(String(c["goal"]) in ["WIN", "MARGIN", "SHUTOUT", "ACES", "RALLY"], c["name"] + ": its goal")
		var cfg := Weekly.config(c, Settings.p1_choice)
		eq(cfg.opponent, int(c["opponent"]))
		eq(cfg.assist, K.ASSIST_OFF, "no assist in a challenge")
		eq(cfg.points_to_win, int(c["points"]))
		var want := 0
		for id: String in c["modifiers"]:
			var found := false
			for row: Array in Settings.MOD_ROWS:
				if row[0] == id:
					found = true
					want |= int(row[2])
			check(found, "%s: modifier %s" % [c["name"], id])
		eq(cfg.modifiers, want, c["name"] + "'s modifiers")
		for line in [c["name"]] + Array(c["text"]):
			for ch in String(line):
				if ch != " " and not chars.contains(ch):
					check(false, "%s: '%s' isn't in the font" % [line, ch])
	Weekly.date_override = 20261111
	eq(Weekly.current(), Weekly.challenges()[46 % Weekly.challenges().size()], "week 46's")
	eq(Weekly.board(), "week-202646")
	Weekly.date_override = 0


func test_goals() -> void:
	var c := {"goal": "MARGIN", "n": 3}
	check(Weekly.judge(c, true, 7, 4, 0, 5)["met"], "by 3")
	check(not Weekly.judge(c, true, 7, 5, 0, 5)["met"], "by 2 isn't")
	check(not Weekly.judge({"goal": "WIN", "n": 0}, false, 6, 7, 0, 3)["met"], "a loss never")
	check(Weekly.judge({"goal": "SHUTOUT", "n": 1}, true, 5, 1, 0, 3)["met"])
	check(not Weekly.judge({"goal": "ACES", "n": 2}, true, 7, 2, 1, 3)["met"])
	check(Weekly.judge({"goal": "RALLY", "n": 12}, true, 7, 2, 0, 12)["met"])
	var r := Weekly.judge({"goal": "WIN", "n": 0}, true, 7, 3, 2, 9)
	eq(int(r["score"]), 4 * 100 + 2 * 50 + 9 * 10)
	eq(String(r["detail"]), "7-3  DONE")
	eq(int(Weekly.judge(c, true, 7, 6, 0, 5)["score"]), 0, "missed: no score")


func test_the_weeks_best() -> void:
	var sv := fresh_save(DIR)
	Weekly.date_override = 20261111
	check(not Weekly.record(sv, {"met": false, "score": 0, "detail": "5-7  MISSED"}), "a miss")
	check(Weekly.record(sv, {"met": true, "score": 500, "detail": "7-2  DONE"}), "a best")
	check(not Weekly.record(sv, {"met": true, "score": 300, "detail": "7-4  DONE"}), "not better")
	var m := Weekly.meta(sv)
	eq([int(m["best"]), int(m["tries"]), int(m["done"])], [500, 3, 1])
	eq(Weekly.title_label(sv), "BEST 500")
	Weekly.date_override = 20261118
	eq(int(Weekly.meta(sv)["best"]), -1, "a new week, a new best")
	eq(Weekly.title_label(sv), String(Weekly.current()["name"]))
	Weekly.date_override = 0


## This week's challenge, played to the end by the bot, judged.
func test_a_bot_plays_this_weeks() -> void:
	var c := Weekly.current()
	var v := match_view(Weekly.config(c, Settings.p1_choice), String(c["venue"]))
	var frames := 0
	while v.sim.phase != K.PHASE_MATCH_RESULT and frames < 60 * 60 * 10:
		v._physics_process(1.0 / 60.0)
		frames += 1
	eq(v.sim.phase, K.PHASE_MATCH_RESULT, "%s played to the end (%d frames)" % [c["name"], frames])
	var r := Weekly.judge(c, v.truth.match_winner == 0, v.truth.team_score[0], v.truth.team_score[1],
		int(v.stats.teams[0]["aces"]), v.stats.longest_rally())
	check(r.has("met") and r.has("score"), "judged: " + String(r["detail"]))
	v.free()


func test_trip_scores() -> void:
	check(Boards.trip_score(true, 3, 9, 3) > Boards.trip_score(false, 4, 12, 0), "a won trip above any unwon")
	check(Boards.trip_score(false, 3, 6, 1) > Boards.trip_score(false, 2, 9, 0), "farther above more wins")
	eq(Boards.trip_detail(true, 3, 9, 2), "WON 9-2")
	eq(Boards.trip_detail(false, 2, 4, 3), "LEG 2  4-3")
	var sv := fresh_save(DIR)
	eq(Boards.initials(sv), "PLR", "no player, no initials: PLR")
	sv.career.create(0, "ace")
	eq(Boards.initials(sv), "ACE", "the career player's")
	eq(Boards.lines([{"initials": "ACE", "score": 1240, "detail": "WON 9-2"}]), [" 1  ACE    1240  WON 9-2"])


func _relay_js() -> String:
	var env := OS.get_environment("PB94_RELAY_JS")
	if env != "":
		return env
	return ProjectSettings.globalize_path("res://").path_join("../../pickleball-relay/server.js").simplify_path()


## A score through the real relay (Node), as the game sends it.
func test_a_board_through_the_relay() -> void:
	var js := _relay_js()
	var out := []
	if not FileAccess.file_exists(js) or OS.execute("node", ["--version"], out) != 0:
		check(true, "skipped: no relay or no Node (as on CI)")
		return
	var pid := OS.create_process("node", ["-e",
		"require(%s).createRelay({log: () => {}}).listen(%d)" % [JSON.stringify(js), NODE_PORT]])
	OS.delay_msec(800)
	var kept := Boards.base
	Boards.base = "http://127.0.0.1:%d" % NODE_PORT
	var name := Boards.trip_board(RoadTrip.today())
	var got := Boards.request_blocking(Boards.url(name))
	if int(got[0]) == 404:
		check(true, "skipped: that relay has no boards yet (PB94_RELAY_JS points at one that does)")
	else:
		eq(int(got[0]), 200, "the board")
		var body := JSON.stringify({"initials": "ACE", "score": Boards.trip_score(true, 3, 9, 2),
			"detail": Boards.trip_detail(true, 3, 9, 2)})
		var posted := Boards.request_blocking(Boards.url(name), HTTPClient.METHOD_POST, body)
		eq(int(posted[0]), 200, "posted: %s" % str(posted[1]))
		var back := Boards.request_blocking(Boards.url(name))
		var board: Array = back[1].get("board", [])
		eq(Boards.lines(board), [" 1  ACE   13088  WON 9-2"], "read back")
	Boards.base = kept
	OS.kill(pid)
