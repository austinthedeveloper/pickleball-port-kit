## The tournament (PORT-25): the draw, your road through it, the CPU
## matches decided from the seed (favourites usually, upsets sometimes),
## the save (a bracket in play survives a restart, an older save loads),
## the bracket screen by row id, a real match recording its result, and
## main's title -> bracket -> match -> bracket loop.
extends TestSuite

const DIR := "user://test_tournament/"
const DT := 1.0 / 60.0


func _save() -> SaveGame:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	var s := SaveGame.new()
	s.dir = DIR
	s.load_game()
	return s


func test_the_draw() -> void:
	var t := Tournament.create(7, false, K.DIFFICULTY_MEDIUM, 11)
	eq(t.draw.size(), Tournament.SIZE)
	eq(t.draw[0], Tournament.YOU, "you're the top seed, first in the bracket")
	check(not (Tournament.SITS_OUT in t.draw), "the warm-up team sits it out")
	var seen := {}
	for e in t.draw:
		seen[e] = true
	eq(seen.size(), Tournament.SIZE, "eight different entries")
	var n := Opponents.count()
	eq(t.draw[1], 1, "seed 8, the weakest left, is your first opponent")
	eq(t.draw[6], n - 1, "the strongest is seed 2, in the other half")
	eq(t.next_match(), {"round": 0, "match": 0, "opponent": 1})
	eq(Tournament.entry_name(t.draw[0]), "YOU")
	eq(t.finish(), "", "still in it")


func test_your_road() -> void:
	var t := Tournament.create(7, false, K.DIFFICULTY_MEDIUM, 11)
	t.record(true, 11, 4)
	eq(t.results[0][0], [Tournament.YOU, 11, 4], "your quarterfinal")
	for m in 4:
		check(not t.results[0][m].is_empty(), "every quarterfinal is decided after yours (%d)" % m)
	check(t.results[1][1].is_empty(), "the other semifinal waits for yours")
	var nm := t.next_match()
	eq(nm["round"], 1, "next: the semifinal")
	eq(nm["opponent"], t.results[0][1][0], "against the 4-5 winner")
	t.record(true, 11, 9)
	t.record(true, 13, 11)
	check(t.over(), "the final played")
	eq(t.champion(), Tournament.YOU)
	eq(t.finish(), "CHAMPION")
	eq(t.next_match(), {}, "nothing left")
	# doubles says CHAMPIONS
	var d := Tournament.create(7, true, K.DIFFICULTY_MEDIUM, 11)
	for i in 3:
		d.record(true, 11, 0)
	eq(d.finish(), "CHAMPIONS")


func test_knocked_out_the_rest_plays_out() -> void:
	var t := Tournament.create(11, false, K.DIFFICULTY_MEDIUM, 7)
	t.record(true, 7, 5)
	t.record(false, 3, 7)
	check(t.knocked_out(), "out")
	check(t.over(), "the final was decided without you")
	check(t.champion() != Tournament.YOU and t.champion() != null)
	eq(t.finish(), "SEMIFINALIST")
	for r in Tournament.ROUNDS:
		for m in Tournament.matches_in(r):
			var res: Array = t.results[r][m]
			check(res[0] in t.entrants(r, m), "a match's winner played in it (%d,%d)" % [r, m])
			check(res[1] >= res[2], "the winner's points first")
	var q := Tournament.create(11, false, K.DIFFICULTY_MEDIUM, 7)
	q.record(false, 2, 7)
	eq(q.finish(), "QUARTERFINALIST")


func test_cpu_matches_from_the_seed() -> void:
	var a := Tournament.create(1234, false, K.DIFFICULTY_MEDIUM, 11)
	var b := Tournament.create(1234, false, K.DIFFICULTY_MEDIUM, 11)
	a.record(false, 0, 11)
	b.record(false, 0, 11)
	eq(a.results, b.results, "the same seed, the same bracket")
	var favourites := 0
	var upsets := 0
	for s in 60:
		var t := Tournament.create(s * 7919 + 1, false, K.DIFFICULTY_MEDIUM, 11)
		t.record(false, 0, 11)
		for m in range(1, 4):
			var e := t.entrants(0, m)
			if t.results[0][m][0] == maxi(e[0], e[1]):
				favourites += 1
			else:
				upsets += 1
	print("    quarterfinals over 60 draws: %d to the favourite, %d upsets" % [favourites, upsets])
	check(favourites > upsets * 2, "favourites usually win")
	check(upsets > 0, "but not always")


func test_the_save() -> void:
	var s := _save()
	eq(s.tournament(), null, "a new save has none")
	eq([s.data["records"]["cups"], s.data["records"]["cup_best"]], [0, 0])
	var t := Tournament.create(99, true, K.DIFFICULTY_HARD, 9)
	t.record(true, 9, 7)
	t.seen = 4
	s.store_tournament(t)
	s.save_game()
	var s2 := SaveGame.new()
	s2.dir = DIR
	s2.load_game()
	var back := s2.tournament()
	check(back != null, "the bracket survives a restart")
	eq(back.to_dict(), t.to_dict(), "exactly (JSON's floats come back as ints)")
	back.record(true, 9, 2)
	t.record(true, 9, 2)
	eq(back.results, t.results, "and plays on the same")
	# a save from before the tournament: the keys fill in
	s2.data.erase("tournament")
	s2.data["records"].erase("cups")
	s2.save_game()
	var s3 := SaveGame.new()
	s3.dir = DIR
	s3.load_game()
	eq(s3.tournament(), null, "an older save: no bracket")
	eq(s3.data["records"]["cups"], 0)
	s3.record_cup("SEMIFINALIST")
	s3.record_cup("CHAMPIONS")
	s3.record_cup("")
	eq([s3.data["records"]["cup_runs"], s3.data["records"]["cups"], s3.data["records"]["cup_best"]],
		[2, 1, 4], "runs, cups, the best finish")


func _bracket(s: SaveGame, reveal := false) -> BracketScreen:
	var b := BracketScreen.new().setup(s, reveal)
	runner.root.add_child(b)
	if not b.is_node_ready():
		b._ready()
	return b


func test_the_bracket_screen() -> void:
	var s := _save()
	var b := _bracket(s)
	check(not b.started, "a fresh draw until START")
	eq(b.page.value_of("play"), "QF VS SNOWBIRDS")
	check(b.page.select("mode"))
	b.page.change(1)
	check(b.t.doubles, "MODE: doubles")
	eq(s.tournament(), null, "nothing saved yet")
	var got := []
	b.play.connect(func(cfg, venue): got.append([cfg, venue]))
	b.page.select("play")
	b.page.press()
	eq(got.size(), 1, "START plays your first match")
	var cfg: SimTypes.MatchConfig = got[0][0]
	eq([cfg.mode, cfg.opponent], [K.MODE_DOUBLES, 1], "doubles, against the first opponent")
	eq(got[0][1], Settings.home_venue(1), "at their home court")
	check(s.tournament() != null, "and the bracket is saved")
	# FORFEIT asks twice
	b.page.select("mode")
	eq(b.page.rows[1]["label"].call(), "FORFEIT", "in play, MODE is FORFEIT")
	b.page.press()
	check(not s.tournament().knocked_out(), "one press only arms it")
	eq(b.page.value_of("mode"), "PRESS AGAIN")
	b.page.press()
	check(s.tournament().knocked_out(), "the second forfeits")
	eq(s.data["records"]["cup_runs"], 1)
	b.page.select("play")
	eq(b.page.rows[0]["label"].call(), "NEW TOURNAMENT")
	b.free()


## Back from a match, the new results appear one at a time.
func test_results_reveal() -> void:
	var s := _save()
	var t := Tournament.create(5, false, K.DIFFICULTY_MEDIUM, 11)
	s.store_tournament(t)
	t.record(true, 11, 3)
	s.store_tournament(t)
	var b := _bracket(s, true)
	eq(b.shown, 0, "nothing shown yet")
	for f in BracketScreen.REVEAL_FRAMES * 5:
		b._process(DT)
	eq(b.shown, 4, "the four quarterfinals, one by one")
	eq(s.tournament().seen, 4, "and the save remembers they were seen")
	b.free()
	var again := _bracket(s, false)
	eq(again.shown, 4, "from the title: all shown at once")
	again.free()


## A real tournament match through the view: the result goes in the
## bracket, the result screen offers BRACKET, and B goes back to it.
func test_a_real_match_records() -> void:
	var s := _save()
	var t := Tournament.create(3, false, K.DIFFICULTY_KID, 3)
	s.store_tournament(t)
	var v := MatchView.new()
	v.save = s
	v.tournament = true
	runner.root.add_child(v)
	var b := BracketScreen.new().setup(s, false)
	v.setup(b.match_config(), "lakeside", false)
	b.free()
	check(v.card_frames == 0, "the opponent's intro card")
	v.card_frames = -1
	v._hud.close_card()
	v.sim.p1_bot = true
	var f := 0
	while v.sim.phase != K.PHASE_MATCH_RESULT and f < 30000:
		if v.sim.phase == K.PHASE_SERVE_SETUP and f % 32 == 0:
			v.sim.serve_requested = 1
		v._physics_process(DT)
		f += 1
	check(v.sim.phase == K.PHASE_MATCH_RESULT, "the match ended")
	var after := s.tournament()
	check(not after.results[0][0].is_empty(), "the bracket has your quarterfinal")
	eq(after.results[0][0][0] == Tournament.YOU, v.sim.match_winner == 0, "with the right winner")
	v.initials.open = false             # a first win's record would ask for initials
	v.unlock_frames = -1
	for i in K.POINT_RESULT_MIN_FRAMES + 2:
		v._physics_process(DT)
	eq(v._hud._result_prompts.items[0][1], "BRACKET", "B: back to the bracket")
	var went := []
	v.finished.connect(func(to_title): went.append(to_title))
	v.sim.rematch_requested = true
	v._physics_process(DT)
	eq(went, [false], "to the bracket, not a rematch")
	v.free()


## The real main scene: TOURNAMENT on the title opens the bracket, START a
## match at the opponent's court, and its end comes back to the bracket.
func test_main_loop() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = DIR
	_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	var settle := func():
		for i in main.FADE_OUT + main.FADE_IN + 1:
			main._physics_process(DT)
	var title: TitleScreen = main._screen
	if not title.is_node_ready():
		title._ready()
	check(title.pages["main"].select("tournament"), "TOURNAMENT is on MAIN")
	eq(title.pages["main"].value_of("tournament"), "8 TEAMS")
	title.pages["main"].press()
	settle.call()
	check(main._screen is BracketScreen, "the bracket")
	var b: BracketScreen = main._screen
	if not b.is_node_ready():
		b._ready()
	b.page.select("play")
	b.page.press()
	settle.call()
	check(main._screen is MatchView and main._screen.tournament, "a tournament match")
	eq(main._screen.venue, Settings.home_venue(1), "at SNOWBIRDS' home")
	main._screen.finished.emit(false)
	settle.call()
	check(main._screen is BracketScreen, "back to the bracket")
	main.show_title()
	settle.call()
	if not main._screen.is_node_ready():
		main._screen._ready()
	eq(main._screen.pages["main"].value_of("tournament"), "QF", "the title shows your round")
	main.free()
	SaveGame.default_dir = kept
