## The couch cup (PORT-29): the lobby's players enter a tournament (in
## singles each player, in doubles each side), take the top seeds in
## different quarters, play CPU teams at their courts and each other on
## their own pads; the CPU matches wait for a round's human matches. The
## cup has its own save slot and never touches the records.
extends TestSuite

const DIR := "user://test_couch/"


func _save() -> SaveGame:
	var s := fresh_save(DIR)
	return s


func _lobby(n: int, mode: int) -> Lobby:
	var l := Lobby.new()
	for d in n:
		l.join(10 + d)
	l.cup = true
	l.set_mode(mode)
	for c in l.joined():
		c["ready"] = true
	return l


func test_the_lobby_modes_and_entries() -> void:
	var l := Lobby.new()
	l.join(10)
	eq(l.mode_name(), "DOUBLES")
	for name in ["SINGLES CUP", "DOUBLES CUP", "SINGLES", "DOUBLES"]:
		l.step_mode(1)
		eq(l.mode_name(), name)
	l.step_mode(-2)
	eq(l.mode_name(), "DOUBLES CUP", "round and round, both ways (PORT-58)")
	var s := _lobby(3, K.MODE_SINGLES)
	eq(s.blocker(), "", "a singles cup takes three players")
	eq(s.entries().map(func(e): return e["name"]), ["P1", "P2", "P3"], "each player an entry")
	var d := _lobby(3, K.MODE_DOUBLES)
	eq(d.entries().map(func(e): return e["name"]), ["P1 + P2", "P3"], "each side a team")
	eq(d.entries()[0]["cards"][1]["number"], 1)


func test_the_draw_spreads_the_humans() -> void:
	var t := Tournament.create(5, false, K.DIFFICULTY_MEDIUM, 11, _lobby(4, K.MODE_SINGLES).entries())
	var quarters := {}
	for pos in Tournament.SIZE:
		if Tournament.is_human(t.draw[pos]):
			quarters[pos / 2] = true
	eq(quarters.size(), 4, "four humans, four quarters")
	eq(t.name_of(t.draw[0]), "P1", "P1 is the top seed")
	check(not (Tournament.SITS_OUT in t.draw), "four CPU teams from the top")


func test_cpu_matches_wait_for_the_humans() -> void:
	var t := Tournament.create(5, false, K.DIFFICULTY_MEDIUM, 11, _lobby(3, K.MODE_SINGLES).entries())
	var nm := t.next_match()
	eq([nm["round"], nm["match"], nm["left"]], [0, 0, Tournament.human(0)], "P1's quarterfinal first")
	t.record_left(true, 11, 5)
	check(t.results[0][1].is_empty(), "a CPU quarterfinal waits for the other humans'")
	check(t.next_match()["left"] == Tournament.human(2), "next: P3's (seed 3)")
	t.record_left(true, 11, 6)
	t.record_left(true, 11, 7)
	for m in 4:
		check(not t.results[0][m].is_empty(), "every quarterfinal done (%d)" % m)
	eq(t.next_match()["round"], 1, "on to the semis")


## P1 and P2 in the final: a match on two pads; then everyone out and the
## rest plays out.
func test_humans_meet() -> void:
	var l := _lobby(2, K.MODE_SINGLES)
	var t := Tournament.create(9, false, K.DIFFICULTY_MEDIUM, 11, l.entries())
	for i in 4:
		t.record_left(true, 11, 3)        # both win through to the final
	var nm := t.next_match()
	eq([nm["round"], nm["left"], nm["right"]], [2, Tournament.human(0), Tournament.human(1)],
		"the final: P1 against P2")
	var cm := t.couch_match(0, "sunset")
	var cfg: SimTypes.MatchConfig = cm["cfg"]
	eq(cfg.human, [1, 0, 1, 0], "both human")
	eq(cm["pads"], [10, -1, 11, -1], "each on their own pad")
	eq(cm["players"], [0, -1, 1, -1])
	eq([cfg.opponent, cm["venue"]], [-1, "sunset"], "no team: the chosen court")
	t.record_left(false, 8, 11)
	eq(t.name_of(t.champion()), "P2", "P2 takes the cup")
	var out := Tournament.create(9, false, K.DIFFICULTY_MEDIUM, 11, l.entries())
	out.record_left(false, 2, 11)
	out.record_left(false, 4, 11)
	check(out.over(), "both out in the first round: the rest plays out")


func test_a_doubles_team_against_a_cpu_team() -> void:
	var l := _lobby(3, K.MODE_DOUBLES)
	var t := Tournament.create(4, true, K.DIFFICULTY_HARD, 9, l.entries())
	var cm := t.couch_match(0, "park")
	var cfg: SimTypes.MatchConfig = cm["cfg"]
	var nm := t.next_match()
	eq(cfg.human, [1, 1, 0, 0], "P1 + P2 on the left")
	eq(cm["pads"], [10, 11, -1, -1])
	eq(cfg.opponent, nm["right"], "the CPU team on the right")
	eq(cm["venue"], Settings.home_venue(nm["right"]), "at their court")
	eq([cfg.difficulty, cfg.points_to_win], [K.DIFFICULTY_HARD, 9])
	# P3 alone: a CPU partner
	t.record_left(true, 9, 2)
	cm = t.couch_match(0, "park")
	eq(cm["cfg"].human, [1, 0, 0, 0], "P3 with a CPU partner")
	eq(cm["players"][0], 2, "P3 on slot 0")


func test_the_save_and_the_records() -> void:
	var s := _save()
	var solo := Tournament.create(1, false, K.DIFFICULTY_MEDIUM, 11)
	s.store_tournament(solo)
	var cup := Tournament.create(2, false, K.DIFFICULTY_MEDIUM, 11, _lobby(2, K.MODE_SINGLES).entries())
	s.store_tournament(cup, "couch")
	s.save_game()
	var s2 := SaveGame.new()
	s2.dir = DIR
	s2.load_game()
	eq(s2.tournament().to_dict(), solo.to_dict(), "the solo bracket is untouched")
	eq(s2.tournament("couch").to_dict(), cup.to_dict(), "the cup round-trips, cards as ints")
	# a match's end, through the view: the bracket takes it, the records don't
	var t := s2.tournament("couch")
	var cm := t.couch_match(0, "park")
	var v := MatchView.new()
	v.save = s2
	v.tournament = true
	v.cup_key = "couch"
	v.slot_pads = cm["pads"]
	v.slot_players = cm["players"]
	runner.root.add_child(v)
	v.setup(cm["cfg"], cm["venue"], false)
	v.sim.team_score = [11, 4]
	v.sim.match_winner = 0
	v.end.on_match_over()
	eq(s2.tournament("couch").results[0][0], [Tournament.human(0), 11, 4], "the cup has P1's win")
	eq([s2.data["records"]["singles_wins"], s2.data["records"]["cup_runs"]], [0, 0],
		"friends' cups don't touch the records")
	v.free()


## The bracket screen on a cup: COUCH CUP, the entries' names, PLAY sends
## the pads along, DONE when it's over.
func test_the_bracket_screen() -> void:
	var s := _save()
	var t := Tournament.create(3, true, K.DIFFICULTY_MEDIUM, 11, _lobby(4, K.MODE_DOUBLES).entries())
	s.store_tournament(t, "couch")
	var b := BracketScreen.new().setup(s, false, true)
	runner.root.add_child(b)
	if not b.is_node_ready():
		b._ready()
	check(b.couch and b.started)
	var nm := t.next_match()
	eq(b.page.value_of("play"), "P1 + P2 VS %s" % Tournament.entry_name(nm["right"]))
	var got := []
	b.play_couch.connect(func(cfg, venue, pads, players): got.append([cfg, venue, pads, players]))
	b.page.select("play")
	b.page.press()
	eq(got.size(), 1, "PLAY: the cup's match")
	eq(got[0][2], [10, 11, -1, -1], "with the pads")
	b.page.select("mode")
	b.page.change(1)
	check(b.t.doubles, "MODE doesn't change a cup")
	b.free()
