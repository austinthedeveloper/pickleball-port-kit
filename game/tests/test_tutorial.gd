## HOW TO PLAY (PORT-30): each lesson's sim, its goal from the events,
## the advice after a miss, a real lesson played through (the bot), the
## card holding the match, main's lesson-to-lesson loop, and the save.
extends TestSuite

const DIR := "user://test_tutorial/"
const DT := 1.0 / 60.0


func _save() -> SaveGame:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	var s := SaveGame.new()
	s.dir = DIR
	s.load_game()
	return s


func _lesson(id: String) -> Tutorial:
	for i in Tutorial.LESSONS.size():
		if Tutorial.LESSONS[i]["id"] == id:
			return Tutorial.new(i)
	return null


func test_each_lesson_sets_up_its_sim() -> void:
	for i in Tutorial.LESSONS.size():
		var t := Tutorial.new(i)
		var cfg := t.config(PlayerSelect.new_choice(PlayerSelect.PAL_GOLD, K.VARIANT_FEMALE, 2))
		if t.is_match():
			eq([cfg.practice, cfg.difficulty, cfg.points_to_win, cfg.opponent], [0, K.DIFFICULTY_KID, 21, -1],
				"%s: singles against a KID CPU" % t.lesson()["id"])
		else:
			eq(cfg.practice, 1, "%s: the ball machine" % t.lesson()["id"])
			eq(cfg.practice_settings[0], t.lesson()["drill"][0], "with the lesson's feed")
		eq([cfg.palette[0], cfg.variant[0], cfg.paddle[0]], [PlayerSelect.PAL_GOLD, K.VARIANT_FEMALE, 2],
			"in your Player Select look")
		for line in t.lesson()["lines"]:
			check(line.length() <= 40, "a card line fits: %s" % line)


## The machine lessons count good returns (the machine's streak going up),
## by the shot that made them.
func test_machine_lessons() -> void:
	var sim := Sim.new(SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0))
	var rally := _lesson("rally")
	for i in 3:
		sim.practice.streak += 1
		rally.observe(sim, [])
	check(rally.done, "RALLY: three returns")
	sim.practice.streak = 0
	var shots := _lesson("shots")
	shots.observe(sim, [])
	for shot in [K.SHOT_DRIVE, K.SHOT_DRIVE, K.SHOT_STANDARD, K.SHOT_SOFT]:
		shots.observe(sim, [[K.EVENT_HIT, 60, 130, 0 | (shot << 4)]])
		sim.practice.streak += 1
		shots.observe(sim, [])
		if shot == K.SHOT_DRIVE:
			eq(shots.progress, 1, "a DRIVE counts once")
	check(shots.done, "SHOTS: a DRIVE and a SOFT")
	sim.practice.streak = 0
	var smash := _lesson("smash")
	smash.observe(sim, [])
	smash.observe(sim, [[K.EVENT_HIT, 60, 130, 0 | (K.SHOT_STANDARD << 4)]])
	sim.practice.streak += 1
	smash.observe(sim, [])
	eq(smash.progress, 0, "an ordinary return isn't a smash")
	sim.practice.streak = 0
	smash.observe(sim, [])
	check(smash.message != "", "a miss gets advice")
	smash.observe(sim, [[K.EVENT_HIT, 60, 130, 0 | (K.SHOT_OVERHEAD << 4)]])
	sim.practice.streak += 1
	smash.observe(sim, [])
	check(smash.done, "SMASH: one")
	sim.dispose()


func test_match_lessons() -> void:
	var sim := Sim.new(SimTypes.MatchConfig.singles())
	sim.phase = K.PHASE_LIVE
	var serve := _lesson("serve")
	serve.observe(sim, [[K.EVENT_SERVE, 60, 130, 0], [K.EVENT_BOUNCE, 190, 100, 1]])
	eq(serve.progress, 1, "a serve that bounced with the rally live: in")
	serve.observe(sim, [[K.EVENT_SERVE, 60, 130, 2], [K.EVENT_BOUNCE, 60, 100, 1]])
	eq(serve.progress, 1, "the CPU's serve doesn't count")
	serve.observe(sim, [[K.EVENT_SERVE, 60, 130, 0], [K.EVENT_FAULT, 160, 100, K.FAULT_WRONG_BOX]])
	check(serve.message.begins_with("SERVE CORNER"), "a fault gets advice")
	var bounces := _lesson("bounces")
	sim.required_bounce = K.REQUIRED_BOUNCE_RETURN
	bounces.observe(sim, [[K.EVENT_SERVE, 60, 130, 0]])
	eq(bounces.progress, 0)
	sim.required_bounce = K.REQUIRED_BOUNCE_NONE
	bounces.observe(sim, [])
	bounces.observe(sim, [])
	eq(bounces.progress, 1, "past the two bounces: once per rally")
	bounces.observe(sim, [[K.EVENT_FAULT, 0, 0, K.FAULT_EARLY_VOLLEY]])
	check(bounces.message.begins_with("LET THE SERVE"), "VOLLEY! gets advice")
	var kitchen := _lesson("kitchen")
	var p: SimTypes.Player = sim.players[0]
	sim.contact_volley = 1
	p.x_fp = K.to_fp(K.COURT_KITCHEN_LEFT_X + 8)
	kitchen.observe(sim, [[K.EVENT_HIT, 100, 130, 0]])
	eq(kitchen.progress, 0, "a volley from the kitchen doesn't count")
	p.x_fp = K.to_fp(K.COURT_KITCHEN_LEFT_X - 4)
	kitchen.observe(sim, [[K.EVENT_HIT, 90, 130, 0]])
	eq(kitchen.progress, 1, "one from behind the line does")
	sim.contact_volley = 0
	kitchen.observe(sim, [[K.EVENT_HIT, 90, 130, 0]])
	eq(kitchen.progress, 1, "a ball that bounced isn't a volley")
	kitchen.observe(sim, [[K.EVENT_FAULT, 0, 0, K.FAULT_KITCHEN]])
	check(kitchen.message.begins_with("NO VOLLEYS"), "KITCHEN! gets advice")
	sim.dispose()


func _view(i: int) -> MatchView:
	var v := MatchView.new()
	v.lesson = Tutorial.new(i)
	runner.root.add_child(v)
	v.setup(v.lesson.config({}), "park", false)
	return v


## The card holds the match (no sim steps) and closes on a press after
## CARD_MIN_FRAMES, locking input so the press doesn't swing.
func test_the_card_holds_the_match() -> void:
	var v := _view(0)
	check(v.lesson_view.blocking(), "the lesson's card first")
	var frames := v.sim.frame_count
	for f in 10:
		v._physics_process(DT)
	eq(v.sim.frame_count, frames, "the match waits under it")
	for f in TutorialView.CARD_MIN_FRAMES:
		v.lesson_view.update_card(false)
	v.lesson_view.update_card(true)
	check(not v.lesson_view.blocking(), "a press closes it")
	eq(v.input_lock, MatchView.INPUT_LOCK_FRAMES, "and doesn't swing")
	v.free()


## TWO BOUNCES against the KID CPU, the bot playing: the goal through the
## real sim, LESSON DONE!, then finished(false) for the next. Observing
## never writes to the sim.
func test_a_real_lesson() -> void:
	var v := _view(4)
	v.lesson_view.card_frames = -1
	v.sim.p1_bot = true
	var went := []
	v.finished.connect(func(to_title): went.append(to_title))
	var f := 0
	while went.is_empty() and f < 60 * 120:
		if v.sim.phase == K.PHASE_SERVE_SETUP and f % 32 == 0:
			v.sim.serve_requested = 1
		v._physics_process(DT)
		f += 1
	check(v.lesson.done, "the bot got two rallies past the two bounces (%d frames)" % f)
	eq(went, [false], "then on to the next lesson")
	var before := v.sim.snapshot()
	v.lesson.observe(v.sim, [[K.EVENT_HIT, 60, 130, 0], [K.EVENT_FAULT, 0, 0, K.FAULT_KITCHEN]])
	eq(v.sim.snapshot(), before, "a lesson only reads the sim")
	v.free()


func test_the_save() -> void:
	var s := _save()
	eq([s.lessons_done(), s.next_lesson()], [0, 0])
	s.finish_lesson(0)
	s.finish_lesson(2)
	eq([s.lessons_done(), s.next_lesson()], [2, 1], "two done, the first not done next")
	for i in Tutorial.LESSONS.size():
		s.finish_lesson(i)
	eq(s.next_lesson(), 0, "all done: from the start again")
	s.data["records"].erase("lessons")
	s.save_game()
	var s2 := SaveGame.new()
	s2.dir = DIR
	s2.load_game()
	eq(s2.lessons_done(), 0, "an older save: none done")


## The real main scene: PRACTICE > HOW TO PLAY starts the first lesson; a
## finished lesson is saved and the next starts; MAIN MENU leaves.
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
	eq(title.pages["main"].value_of("practice"), "HOW TO PLAY", "MAIN invites a new player")
	title.open_page("learn")
	check(title.pages["learn"].select("lessons"))
	title.pages["learn"].press()
	settle.call()
	var m: MatchView = main._screen
	check(m.lesson != null and m.lesson.index == 0, "lesson 1")
	m.finished.emit(false)
	settle.call()
	eq(main.save.lessons_done(), 1, "saved")
	m = main._screen
	check(m.lesson != null and m.lesson.index == 1, "then lesson 2")
	m.finished.emit(true)
	settle.call()
	check(main._screen is TitleScreen, "MAIN MENU: the title")
	main.free()
	SaveGame.default_dir = kept


## SMASH can be done: a little in front of where the machine's lob would
## land (toward the net, where a player meets a falling ball), some swing
## timing makes an overhead that comes back in. Each try is a fresh,
## deterministic sim.
func test_the_lob_can_be_smashed() -> void:
	var t := _lesson("smash")
	var hits := 0
	var tries := 0
	for ahead in [0, 8, 14, 20]:
		for press in range(20, 70):
			tries += 1
			var sim := Sim.new(t.config({}))
			var f := 0
			while sim.practice.state == Practice.WAIT and f < 600:
				sim.step([SimTypes.Intent.new(), null, null, null])
				f += 1
			# where the lob comes down
			var probe := SimTypes.Ball.new()
			for k in ["x_fp", "y_fp", "z_fp", "vx_fp", "vy_fp", "vz_fp", "active", "rally_state"]:
				probe.set(k, sim.ball.get(k))
			for s in 200:
				if Sim.simulate_step(probe) & K.BALL_EVENT_BOUNCE:
					break
			var p: SimTypes.Player = sim.players[0]
			p.x_fp = probe.x_fp + K.to_fp(ahead)
			p.y_fp = probe.y_fp
			var lesson := Tutorial.new(t.index)
			lesson.observe(sim, [])
			for g in 120:
				var it := SimTypes.Intent.new()
				if g == press:
					it.hit_pressed = 1
					it.shot = K.SHOT_DRIVE
				sim.step([it, null, null, null])
				lesson.observe(sim, sim.drain_events())
				if sim.practice.state == Practice.WAIT:
					break
			if lesson.progress > 0:
				hits += 1
			sim.dispose()
	print("    spots and swing timings that smash the lob back in: %d of %d" % [hits, tries])
	check(hits >= 3, "a smash is possible, and not by a hair")
