## STORY: SAVE THE PARK (PORT-44, ADR-069): the script in data/story.json
## follows the ladder and canon (SNES ADR-077); a chapter's match is you
## and Pepper against its team, at its venue and time, with its twist; the
## progress is saved; the scenes page, type and skip; the title's STORY row
## starts the chapter you're on.
extends TestSuite

const WHO := ["narrator", "partner", "captain", "mate", "villain", "note"]


func _pages_of(c: Dictionary) -> Array:
	return c["scene"] + c["win"] + [c["lose"]]


func test_the_script() -> void:
	var d := StoryMode.data()
	eq(d["chapters"].size(), StoryMode.CHAPTERS, "eight chapters")
	eq(StoryMode.villain(), "MR. GRIMSBY")
	eq(StoryMode.company(), "GRIMSBY PARKING CO.")
	var chars := String(BitmapText.load_font("small")["chars"])
	var bad := []
	var all := []
	for i in StoryMode.CHAPTERS:
		var c := StoryMode.chapter(i)
		eq(int(c["team"]), i, "chapter %d is the ladder's team %d" % [i + 1, i])
		check(Settings.VENUES.has(StoryMode.venue(i)), "chapter %d's venue" % (i + 1))
		check(StoryMode.time(i) >= CourtStyle.DAY and StoryMode.time(i) <= CourtStyle.NIGHT)
		for n in c["twist"]:
			check(StoryMode.TWISTS.has(String(n)), "a twist the game has: %s" % n)
		check(String(c["title"]).length() <= 22, "the card's title fits: %s" % c["title"])
		check(c["win"][-1].get("petition", false), "a win ends on the petition")
		check(not c["scene"].is_empty() and not c["win"].is_empty())
		all.append_array(_pages_of(c))
	all.append_array(d["ending"])
	all.append_array(d["epilogue"])
	for p in all:
		if not WHO.has(String(p["who"])):
			bad.append("who: %s" % p["who"])
		if p["lines"].size() < 1 or p["lines"].size() > StoryMode.LINES_MAX:
			bad.append("lines: %s" % [p["lines"]])
		for l in p["lines"]:
			if String(l).length() > StoryMode.LINE_MAX:
				bad.append("long: %s" % l)
			for ch in String(l):
				if ch != " " and not chars.contains(ch):
					bad.append("glyph '%s': %s" % [ch, l])
	eq(bad, [], "every page is one the scene can show")
	# Grimsby is only ever a voice or a letter, never a sprite (SNES ADR-077)
	check(all.any(func(p): return p["who"] == "villain") and all.any(func(p): return p["who"] == "note"))


func test_a_chapters_match() -> void:
	for i in StoryMode.CHAPTERS:
		var cfg := StoryMode.config(i, Settings.p1_choice)
		eq(cfg.mode, K.MODE_DOUBLES, "doubles")
		eq(cfg.partner, Opponents.PEPPER, "with Pepper")
		eq(cfg.modifiers, StoryMode.twist_bits(i), "the chapter's twist")
		eq(cfg.opponent, i, "against the chapter's team")
	eq(StoryMode.twist_bits(0), 0, "chapter 1 is plain")
	eq(StoryMode.twist_bits(3), K.MOD_WIND)
	eq(StoryMode.twist_label(3), "TODAY: WIND")
	eq(StoryMode.twist_label(0), "")
	# a chapter's match plays as a sim does (Pepper is a CPU partner)
	var s := Sim.new(StoryMode.config(2, Settings.p1_choice))
	s.p1_bot = true
	for f in 600:
		s.step([SimTypes.Intent.new(), null, null, null])
		s.drain_events()
	check(s.players[1].active == 1, "Pepper plays")
	s.dispose()


func test_progress() -> void:
	var sv := fresh_save("user://test_story/")
	eq(StoryMode.current(sv), 0)
	eq(StoryMode.label(sv), "CHAPTER 1/8")
	for i in StoryMode.CHAPTERS - 1:
		check(not StoryMode.win(sv, i), "chapter %d isn't the last" % (i + 1))
		eq(StoryMode.current(sv), i + 1)
	eq(StoryMode.label(sv), "CHAPTER 8/8")
	check(StoryMode.win(sv, StoryMode.CHAPTERS - 1), "the last saves the park")
	eq([StoryMode.current(sv), StoryMode.cleared(sv)], [0, 1], "and starts over")
	eq(StoryMode.label(sv), "PARK SAVED!")
	sv.save_game()
	var back := SaveGame.new()
	back.dir = sv.dir
	back.load_game()
	eq(StoryMode.cleared(back), 1, "kept in the save")
	# an old save without the key starts at chapter 1
	back.data.erase("story")
	eq([StoryMode.current(back), StoryMode.cleared(back)], [0, 0])
	check(not StoryMode.win(back, 0) and StoryMode.current(back) == 1)
	wipe_saves("user://test_story/")


func _scene(ch: int, kind: String) -> StoryScene:
	var s := StoryScene.new().setup(null, ch, kind,
		PlayerLook.for_team(0, 0, 0, MatchView.levels_manifest()))
	runner.root.add_child(s)
	return s


## A press finishes the typing, the next turns the page; the last ends the
## scene; START skips.
func test_the_scene_pages() -> void:
	var s := _scene(0, "intro")
	eq(s.pages.size(), 1 + StoryMode.chapter(0)["scene"].size(), "the card, then the scene")
	var ended := []
	s.done.connect(func(skipped: bool): ended.append(skipped))
	s.advance()                                # the card has no text: on
	eq(s.page, 1)
	s._process(0.0)
	check(s.shown > 0 and s.shown < s._text_of(s._page()).length(), "typing")
	s.advance()
	eq([s.page, s.shown], [1, s._text_of(s._page()).length()], "the first press finishes it")
	s.advance()
	eq(s.page, 2, "the next turns the page")
	for k in 200:
		if not ended.is_empty():
			break
		s.advance()
	eq(ended, [false], "the last page ends it")
	s.free()
	var w := _scene(7, "win")
	check(w.pages[-1].get("petition", false))
	w.page = w.pages.size() - 1
	w._show_page()
	check(w._card != null, "the petition shows")
	w.free()
	var e := _scene(7, "ending")
	check(e.pages.any(func(p): return p.get("card", "") == "end"), "THE END")
	e.free()
	var l := _scene(4, "lose")
	eq(l.pages.size(), 1)
	l.free()


## The title's STORY row starts the chapter you're on; the scene skipped
## goes to its match, with Pepper.
func test_from_the_title() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = "user://test_story_main/"
	wipe_saves(SaveGame.default_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.default_dir))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	main.save.data["story"] = {"chapter": 2, "cleared": 0}
	var t: TitleScreen = main._screen
	if not t.is_node_ready():
		t._ready()
	t.pages["main"].select("story")
	eq(t.pages["main"].value_of("story"),
		"CHAPTER 3/8")
	t.pages["main"].press()
	for f in main.FADE_OUT + 1:
		main._physics_process(1.0 / 60.0)
	var sc: StoryScene = main._screen
	check(sc is StoryScene and sc.chapter == 2, "chapter 3's scene")
	sc.done.emit(true)
	for f in main.FADE_OUT + 1:
		main._physics_process(1.0 / 60.0)
	var m: MatchView = main._screen
	check(m is MatchView and m.story_mode, "its match")
	eq(m.sim.config.partner, Opponents.PEPPER)
	eq(m.sim.config.opponent, 2)
	main.free()
	wipe_saves(SaveGame.default_dir)
	SaveGame.default_dir = kept
