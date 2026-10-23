## Achievements (PORT-54, ADR-077): each unlocks once, saved with its day,
## announced; a finished match checks P1's side (PICKLED, the first win,
## an ace, long rallies, a comeback, modifiers, venues, the ladder, Dawson);
## PICKLEBALL 101 and the bracket unlock theirs; RECORDS lists them.
extends TestSuite


func _match(over := {}) -> Dictionary:
	var m := {"won": true, "scores": [11, 4], "aces": 0, "longest": 6, "behind": 0, "mods": 0,
		"opponent": 2, "venue": "park", "cleared": false}
	m.merge(over, true)
	return m


func test_the_list() -> void:
	var chars := String(BitmapText.load_font("small")["chars"])
	var ids := {}
	for a in Achievements.LIST:
		check(not ids.has(a[0]), "one %s" % a[0])
		ids[a[0]] = true
		for s in [a[1], a[2]]:
			for c in String(s):
				check(c == " " or chars.contains(c), "%s: '%s' in the font" % [s, c])
	eq(Achievements.entry("pickled")[1], "PICKLED")


func test_a_match() -> void:
	var sv := fresh_save("user://test_achievements/")
	var heard := []
	var kept: Callable = Achievements.on_unlock
	Achievements.on_unlock = func(id): heard.append(id)
	eq(Achievements.check_match(sv, _match({"scores": [11, 1]})), ["first_win"], "a win")
	eq(Achievements.check_match(sv, _match({"scores": [11, 0]})), ["pickled"], "PICKLED: 11-0")
	eq(Achievements.check_match(sv, _match({"scores": [11, 0]})), [], "once")
	eq(Achievements.check_match(sv, _match({"won": false, "scores": [3, 11], "aces": 1, "longest": 22})),
		["ace", "marathon"], "an ace and a 22-shot rally, even in a loss")
	eq(Achievements.check_match(sv, _match({"won": false, "behind": 6})), [], "a comeback needs the win")
	eq(Achievements.check_match(sv, _match({"behind": 5, "longest": 31})), ["on_fire", "comeback"])
	eq(Achievements.check_match(sv, _match({"mods": K.MOD_WIND | K.MOD_MOON | K.MOD_ICE})), ["mad_scientist"])
	var last := Settings.VENUES.size() - 1
	for v in Settings.VENUES.slice(0, last):
		eq(Achievements.check_match(sv, _match({"venue": v})), [], "not every venue yet (%s)" % v)
	eq(Achievements.check_match(sv, _match({"venue": Settings.VENUES[last]})), ["globetrotter"], "every one")
	eq(Achievements.check_match(sv, _match({"cleared": true, "opponent": Opponents.DAWSON})),
		["ladder", "cover_man"])
	eq(heard, ["first_win", "pickled", "ace", "marathon", "on_fire", "comeback", "mad_scientist",
		"globetrotter", "ladder", "cover_man"], "each announced once")
	eq(Achievements.day(sv, "pickled"), Time.get_date_string_from_system(), "with the day")
	eq(Achievements.label(sv), "10/%d" % Achievements.count())
	sv.save_game()
	var back := SaveGame.new()
	back.dir = sv.dir
	back.load_game()
	eq(Achievements.unlocked_count(back), 10, "kept in the save")
	back.data.erase("achievements")
	eq(Achievements.unlocked_count(back), 0, "an old save has none")
	Achievements.on_unlock = kept
	wipe_saves("user://test_achievements/")


## How far behind each side has been, from the score after each point.
func test_comeback_tracking() -> void:
	var st := MatchStats.new()
	for s in [[0, 1], [0, 3], [0, 5], [2, 5], [6, 5]]:
		st.note_score(s)
	eq(st.behind, [5, 1])


## A real match's end checks them (a bot for P1, on a fresh save).
func test_from_a_match() -> void:
	var sv := fresh_save("user://test_achievements/")
	var v := MatchView.new()
	v.save = sv
	runner.root.add_child(v)
	v.setup(Settings.config_for(false, 0, K.DIFFICULTY_KID, 5), "park", false)
	v.card_frames = -1
	v.sim.p1_bot = true
	v.highlight = null
	for f in 60 * 60 * 10:
		v._physics_process(1.0 / 60.0)
		if v.sim.phase == K.PHASE_MATCH_RESULT:
			break
	check(v.sim.phase == K.PHASE_MATCH_RESULT, "the match ended")
	eq(Achievements.unlocked(sv, "first_win"), v.sim.match_winner == 0, "FIRST DINK if it was won")
	eq(Achievements.unlocked(sv, "pickled"), v.sim.match_winner == 0 and v.sim.team_score[1] == 0)
	v.initials.open = false
	v.free()
	wipe_saves("user://test_achievements/")


## Every PICKLEBALL 101 lesson done: SCHOLAR.
func test_scholar() -> void:
	var sv := fresh_save("user://test_achievements/")
	for i in Course.count() - 1:
		Course.finish(sv, i, false)
	var c := CourseScreen.new().setup(sv, Course.count() - 1)
	runner.root.add_child(c)
	if not c.is_node_ready():
		c._ready()
	check(not Achievements.unlocked(sv, "scholar"))
	while not c._page().has("end"):
		if Course.is_quiz(c._page()):
			c.answer(int(c._page()["answer"]))
		c.next_page()
	check(Achievements.unlocked(sv, "scholar"), "the last lesson done")
	c.free()
	wipe_saves("user://test_achievements/")


## RECORDS > ACHIEVEMENTS: a row each, DONE on the unlocked, how to earn the
## selected one under the panel.
func test_the_page() -> void:
	var sv := fresh_save("user://test_achievements/")
	Achievements.unlock(sv, "pickled")
	var t := title_screen(sv)
	eq(t.pages["records"].value_of("achievements"), "1/%d" % Achievements.count())
	t.open_page("achievements")
	var p: MenuPage = t.pages["achievements"]
	eq(p.rows.size(), Achievements.count() + 1, "a row each, and BACK")
	eq(p.value_of("pickled"), "DONE")
	eq(p.value_of("ace"), "")
	p.select("pickled")
	t._refresh_achievement()
	check(t.achieve_how.visible and t.achieve_how.text.begins_with("WIN WITHOUT"), t.achieve_how.text)
	t.free()
	wipe_saves("user://test_achievements/")
