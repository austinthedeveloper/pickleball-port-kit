## PICKLEBALL 101 (PORT-45, ADR-070): the real game's lessons. The data
## holds together (every page one the screen can draw, every quiz
## answerable, every drill a HOW TO PLAY lesson); the rules it teaches are
## the real ones where the numbers say so; a lesson pages, quizzes and
## finishes, saved; the PRACTICE page's row opens it.
extends TestSuite


func _all_pages() -> Array:
	var out := []
	for i in Course.count():
		out.append_array(Course.lesson(i)["pages"])
	return out


func test_the_lessons() -> void:
	eq(Course.count(), 8)
	var chars := String(BitmapText.load_font("small")["chars"])
	var bad := []
	for i in Course.count():
		var l := Course.lesson(i)
		check(Course.quizzes(i) >= 1, "%s has a quiz" % l["title"])
		check(not Course.is_quiz(l["pages"][0]), "%s opens on a page to read" % l["title"])
		eq(Course.pages(i)[-1], {"end": true}, "and closes")
		if l.has("try"):
			check(Course.try_lesson(i) >= 0, "%s's drill is a HOW TO PLAY lesson" % l["title"])
	for p in _all_pages():
		var texts: Array = []
		for k in ["lines", "quiz", "why", "choices"]:
			texts.append_array(p.get(k, []))
		if Course.is_quiz(p):
			if int(p["answer"]) < 0 or int(p["answer"]) >= p["choices"].size():
				bad.append("answer out of range: %s" % [p["quiz"]])
			if p["quiz"].size() > 2 or p["why"].size() > 2:
				bad.append("a quiz in three lines: %s" % [p["quiz"]])
		elif p["lines"].size() > Course.LINES_MAX:
			bad.append("too many lines: %s" % [p["lines"]])
		for s in texts:
			if String(s).length() > Course.LINE_MAX:
				bad.append("long: %s" % s)
			for c in String(s):
				if c != " " and not chars.contains(c):
					bad.append("glyph '%s': %s" % [c, s])
		for z in p.get("show", []) + p.get("bad", []):
			if not CourtDiagram.ZONES.has(z) and z != "net":
				bad.append("zone: %s" % z)
		for pl in p.get("players", []):
			if not CourtDiagram.TEAM.has(String(pl[2])):
				bad.append("player: %s" % [pl])
		for pt in p.get("path", []):
			if not String(pt[2]) in ["", "h", "b", "v", "n", "x"]:
				bad.append("path flag: %s" % [pt])
	eq(bad, [], "every page is one the screen can show")


## The real numbers: what the court and the scoring lessons say.
func test_the_rules_are_real() -> void:
	eq([CourtDiagram.LENGTH, CourtDiagram.WIDTH, CourtDiagram.KITCHEN], [44.0, 20.0, 7.0],
		"a 20 by 44 foot court, 7 foot kitchens")
	var court: Array = Course.lesson(0)["pages"]
	var kitchen_quiz: Dictionary = court.filter(Course.is_quiz)[0]
	eq(String(kitchen_quiz["choices"][int(kitchen_quiz["answer"])]), "7 FEET")
	var score: Array = Course.lesson(4)["pages"].filter(Course.is_quiz)
	eq(String(score[0]["choices"][int(score[0]["answer"])]), "6-4-2", "server's score first")
	eq(String(score[1]["choices"][int(score[1]["answer"])]), "0-0-2", "a game starts at 0-0-2")
	var serve: Array = Course.lesson(1)["pages"].filter(Course.is_quiz)
	eq(String(serve[0]["choices"][int(serve[0]["answer"])]), "FAULT", "a serve on the kitchen line")
	# the serve diagram: from your right court (the bottom half) to theirs
	# (the top half, beyond the far kitchen)
	var cross: Dictionary = Course.lesson(1)["pages"][2]
	var land: Array = cross["path"][1]
	check(CourtDiagram.ZONES["service_far_right"].has_point(Vector2(land[0], land[1])), "lands in it")
	check(cross["path"][0][1] > 10.0, "served from the right")


func test_progress() -> void:
	var sv := fresh_save("user://test_course/")
	eq([Course.done_count(sv), Course.next(sv), Course.label(sv)], [0, 0, "0/8"])
	Course.finish(sv, 0, false)
	Course.finish(sv, 1, true)
	eq([Course.status(sv, 0), Course.status(sv, 1)], [Course.DONE, Course.PERFECT])
	Course.finish(sv, 1, false)
	eq(Course.status(sv, 1), Course.PERFECT, "a perfect run is kept")
	eq([Course.next(sv), Course.label(sv)], [2, "2/8"])
	sv.save_game()
	var back := SaveGame.new()
	back.dir = sv.dir
	back.load_game()
	eq(Course.done_count(back), 2, "kept in the save")
	back.data.erase("course")
	eq(Course.done_count(back), 0, "an old save starts fresh")
	wipe_saves("user://test_course/")


func _screen(sv: SaveGame, start := -1) -> CourseScreen:
	var c := CourseScreen.new().setup(sv, start)
	runner.root.add_child(c)
	if not c.is_node_ready():
		c._ready()
	return c


## Pages turn; a quiz holds the page until it's answered; the first pick is
## the one that counts; the closing page saves the lesson.
func test_a_lesson() -> void:
	var sv := fresh_save("user://test_course/")
	var c := _screen(sv)
	eq(c.lesson, -1, "opens on the list")
	c.list.select("score")
	c.list.press()
	eq([c.lesson, c.page], [4, 0], "KEEPING SCORE")
	check(c.diagram.visible)
	c.prev_page()
	eq(c.page, 0, "nothing before the first")
	while not Course.is_quiz(c._page()):
		c.next_page()
	check(not c.diagram.visible and c.choices != null, "a quiz: its choices")
	var at := c.page
	c.next_page()
	eq(c.page, at, "held until answered")
	var right := int(c._page()["answer"])
	c.answer((right + 1) % c._page()["choices"].size())
	c.answer(right)
	eq(c._choice_mark(at, right), "RIGHT")
	eq(c._lines[0].text.begins_with("NOT QUITE"), true, "the first pick counts")
	while not c._page().has("end"):
		if Course.is_quiz(c._page()):
			c.answer(int(c._page()["answer"]))
		c.next_page()
	eq(Course.status(sv, 4), Course.DONE, "done, not perfect")
	check(c.choices.index_of("next") >= 0 and c.choices.index_of("try") < 0, "on to the next")
	c.choices.select("next")
	c.choices.press()
	eq(c.lesson, 5, "LINE CALLS")
	c.free()
	# a perfect run, and the drill offered
	var p := _screen(sv, 1)
	var tried := []
	p.try_lesson.connect(func(k): tried.append(k))
	while not p._page().has("end"):
		if Course.is_quiz(p._page()):
			p.answer(int(p._page()["answer"]))
		p.next_page()
	eq(Course.status(sv, 1), Course.PERFECT)
	p.choices.select("try")
	p.choices.press()
	eq(tried, [Course.try_lesson(1)], "TRY IT: the SERVE drill")
	eq(Tutorial.LESSONS[tried[0]]["id"], "serve")
	p.free()
	wipe_saves("user://test_course/")


## Display only: the diagram's ball runs and loops, its marks drawn.
func test_the_diagram_loops() -> void:
	var d := CourtDiagram.new().setup(10.0)
	runner.root.add_child(d)
	d.show_page(Course.lesson(1)["pages"][2])
	for f in 400:
		d.step()
	eq(d.frame, 400)
	d.show_page({"call": "4 - 2 - 1"})
	eq(d.frame, 0, "a new page starts the ball over")
	eq(d._texts.size(), 1, "the call")
	d.free()


## PRACTICE > PICKLEBALL 101 opens the list; BACK leaves for the title;
## TRY IT plays the drill and comes back.
func test_from_the_title() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = "user://test_course_main/"
	wipe_saves(SaveGame.default_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.default_dir))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	var t: TitleScreen = main._screen
	if not t.is_node_ready():
		t._ready()
	eq(t.pages["learn"].value_of("course"), "0/8")
	t.pages["learn"].select("course")
	t.pages["learn"].press()
	for f in main.FADE_OUT + 1:
		main._physics_process(1.0 / 60.0)
	var c: CourseScreen = main._screen
	check(c is CourseScreen, "PICKLEBALL 101")
	if not c.is_node_ready():
		c._ready()
	c.open_lesson(2)
	c.try_lesson.emit(Course.try_lesson(2))
	for f in main.FADE_OUT + 1:
		main._physics_process(1.0 / 60.0)
	var m: MatchView = main._screen
	check(m is MatchView and m.lesson != null and m.lesson.index == Course.try_lesson(2), "the drill")
	m.finished.emit(true)
	for f in main.FADE_OUT + 1:
		main._physics_process(1.0 / 60.0)
	check(main._screen is CourseScreen, "and back")
	main.free()
	wipe_saves(SaveGame.default_dir)
	SaveGame.default_dir = kept
