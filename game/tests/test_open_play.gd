## ADR-034 open play: the park's stacks, games, walking, and your turn
## (reference/snes-src/test/test_open_play.c, and test_opponents.c's
## test_partner), then the Godot side: the park view, the menu, the match.
extends TestSuite

const DIR := "user://test_open_play/"

var op: OpenPlay


func _place_you(x: int, y: int) -> void:
	op.x_fp = K.to_fp(x)
	op.y_fp = K.to_fp(y)


## Every team is in exactly one place: on a court or in one stack. You are
## in at most one stack, and only where your_court says.
func _check_population() -> bool:
	var seen := []
	seen.resize(OpenPlay.TEAMS)
	seen.fill(0)
	var you := 0
	var ok := true
	for c in OpenPlay.COURTS:
		var ct: OpenPlay.OpenCourt = op.court[c]
		for i in 2 + ct.stack_count:
			var e: int = ct.playing[i] if i < 2 else ct.stack[i - 2]
			if e == OpenPlay.NONE:
				continue
			if e == OpenPlay.YOU:
				you += 1
				ok = ok and (i < 2 or op.your_court == c)
				continue
			ok = ok and e < OpenPlay.TEAMS
			if e < OpenPlay.TEAMS:
				seen[e] += 1
		ok = ok and ct.stack_count <= OpenPlay.STACK_MAX
	for e in OpenPlay.TEAMS:
		ok = ok and seen[e] == 1
	return check(ok and you <= 1, "every team in one place, you in at most one stack")


func test_teams_are_the_ladder() -> void:
	eq(Opponents.count(), OpenPlay.TEAMS, "OpenPlay.TEAMS is the ladder")


## The levels: ladder order, names, and the difficulty of your game.
func test_levels() -> void:
	check(OpenPlay.team_court(0) == 0 and OpenPlay.team_court(2) == 0)
	check(OpenPlay.team_court(3) == 1 and OpenPlay.team_court(5) == 1)
	check(OpenPlay.team_court(6) == 2 and OpenPlay.team_court(7) == 2)
	eq(OpenPlay.court_level_name(0), "<3.5")
	eq(OpenPlay.court_level_name(2), "4.5+")
	eq(OpenPlay.court_difficulty(0, K.DIFFICULTY_HARD), K.DIFFICULTY_EASY)
	eq(OpenPlay.court_difficulty(1, K.DIFFICULTY_EASY), K.DIFFICULTY_MEDIUM)
	eq(OpenPlay.court_difficulty(2, K.DIFFICULTY_MEDIUM), K.DIFFICULTY_HARD)
	eq(OpenPlay.court_difficulty(2, K.DIFFICULTY_KID), K.DIFFICULTY_KID)


func test_begin() -> void:
	op = OpenPlay.new()
	op.begin(1234, false)
	for c in OpenPlay.COURTS:
		eq(op.court[c].state, OpenPlay.COURT_PLAYING)
		check(op.court[c].score[0] < OpenPlay.GAME_POINTS)
	# Every team starts at its level's court.
	for c in OpenPlay.COURTS:
		for side in 2:
			eq(OpenPlay.team_court(op.court[c].playing[side]), c)
	eq(op.your_court, OpenPlay.NONE)
	eq(op.called, OpenPlay.NONE)
	check(OpenPlay.walkable(op.x_fp, op.y_fp))
	_check_population()


func test_walking() -> void:
	var left := OpenPlay.court_left(1)
	op = OpenPlay.new()
	op.begin(1, false)
	# Inside a court is fenced off; the walks between courts are open.
	check(not OpenPlay.walkable(K.to_fp(left + 20), K.to_fp(OpenPlay.COURT_TOP + 40)))
	check(OpenPlay.walkable(K.to_fp(left - 12), K.to_fp(OpenPlay.COURT_TOP + 40)))
	check(not OpenPlay.walkable(K.to_fp(2), K.to_fp(150)))
	# Walking up into a court stops at its fence.
	_place_you(left + 20, OpenPlay.RACK_Y)
	for n in 200:
		op.update(0, -1, false)
	check(K.from_fp(op.y_fp) >= OpenPlay.COURT_TOP + OpenPlay.COURT_H + OpenPlay.FENCE_MARGIN - 1,
		"stopped at the fence")
	# Diagonally, you slide along it.
	op.update(1, -1, false)
	check(K.from_fp(op.x_fp) > left + 20, "slides")
	check(op.walking and not op.facing_left)
	op.update(-1, 0, false)
	check(op.facing_left != 0)


func test_stacking() -> void:
	var c := 2
	op = OpenPlay.new()
	op.begin(7, false)
	# Away from every rack, B does nothing.
	_place_you(128, 200)
	eq(op.rack_near(), OpenPlay.NONE)
	eq(op.update(0, 0, true), OpenPlay.EVENT_NONE)
	_place_you(OpenPlay.rack_x(c), OpenPlay.RACK_Y + 4)
	eq(op.rack_near(), c)
	eq(op.update(0, 0, true), OpenPlay.EVENT_STACKED)
	eq(op.your_court, c)
	eq(op.court[c].stack[op.court[c].stack_count - 1], OpenPlay.YOU)
	eq(op.your_wait(), (op.court[c].stack_count - 1) / 2)
	_check_population()
	# B again takes it back.
	eq(op.update(0, 0, true), OpenPlay.EVENT_UNSTACKED)
	eq(op.your_court, OpenPlay.NONE)
	eq(op.your_wait(), OpenPlay.NONE)
	# Stacking at another court moves your paddle there.
	op.update(0, 0, true)
	_place_you(OpenPlay.rack_x(0), OpenPlay.RACK_Y)
	eq(op.update(0, 0, true), OpenPlay.EVENT_STACKED)
	eq(op.your_court, 0)
	_check_population()
	# A full stack has no room.
	op.court[1].stack_count = OpenPlay.STACK_MAX
	_place_you(OpenPlay.rack_x(1), OpenPlay.RACK_Y)
	eq(op.update(0, 0, true), OpenPlay.EVENT_FULL)
	eq(op.your_court, 0)


## Stack, wait for your game, play it, come back: the park goes on.
func test_your_turn() -> void:
	var c := 1
	op = OpenPlay.new()
	op.begin(99, false)
	_place_you(OpenPlay.rack_x(c), OpenPlay.RACK_Y)
	eq(op.update(0, 0, true), OpenPlay.EVENT_STACKED)
	_place_you(128, 200)
	var event := OpenPlay.EVENT_NONE
	var frames := 0
	var population := true
	while event != OpenPlay.EVENT_CALLED and frames < 60 * 60 * 5:
		event = op.update(0, 0, false)
		if (frames & 63) == 0:
			population = population and _check_population()
		frames += 1
	eq(event, OpenPlay.EVENT_CALLED, "called")
	print("    open play: called after %d s on court %d" % [frames / 60, op.called + 1])
	eq(op.called, c)
	var opponent := op.opponent
	check(opponent < OpenPlay.TEAMS)
	eq(OpenPlay.team_court(opponent), c, "a team of that level")
	# Your partner: the team waiting next there (not your opponents).
	if op.court[c].stack_count:
		eq(op.partner, op.court[c].stack[0])
		check(op.partner != opponent)
		eq(OpenPlay.team_court(op.partner), c)
	else:
		eq(op.partner, OpenPlay.NONE)
	eq(op.court[c].state, OpenPlay.COURT_YOURS)
	eq(op.your_court, OpenPlay.NONE)
	# The call shows for a while, input ignored, then the match.
	_place_you(128, 200)
	var quiet := true
	for f in range(1, OpenPlay.CALL_FRAMES):
		quiet = quiet and op.update(1, 0, true) == OpenPlay.EVENT_NONE
	check(quiet, "nothing during the call")
	eq(K.from_fp(op.x_fp), 128, "input ignored")
	eq(op.update(0, 0, false), OpenPlay.EVENT_PLAY)
	# Back from the match: you leave, the court changes over.
	op.return_from_match(true, 11, 7)
	eq(op.called, OpenPlay.NONE)
	check(op.last_won == 1 and op.last_score[0] == 11)
	eq(op.court[c].state, OpenPlay.COURT_CHANGEOVER)
	check(OpenPlay.walkable(op.x_fp, op.y_fp))
	for f in OpenPlay.CHANGEOVER_FRAMES + 1:
		op.update(0, 0, false)
	eq(op.court[c].state, OpenPlay.COURT_PLAYING)
	_check_population()


## A long soak: games end and start on every court, teams move between
## courts, and nobody is lost or duplicated.
func test_soak() -> void:
	var games := [0, 0, 0]
	var away := false
	var population := true
	op = OpenPlay.new()
	op.begin(4321, false)
	var before := [0, 0, 0]
	for f in 60 * 60 * 20:
		for c in OpenPlay.COURTS:
			before[c] = op.court[c].state
		op.update(0, 0, false)
		for c in OpenPlay.COURTS:
			var ct: OpenPlay.OpenCourt = op.court[c]
			if before[c] == OpenPlay.COURT_CHANGEOVER and ct.state == OpenPlay.COURT_PLAYING:
				games[c] += 1
			# Teams only play at their own level.
			for side in 2:
				var e: int = ct.playing[side]
				if e < OpenPlay.TEAMS and OpenPlay.team_court(e) != c:
					away = true
		if (f & 255) == 0:
			population = population and _check_population()
	print("    open play: 20 minutes, games by court %d %d %d" % games)
	for c in OpenPlay.COURTS:
		check(games[c] >= 15, "court %d played %d games" % [c + 1, games[c]])
	check(not away, "teams stay at their level")


## 2P as your partner (M4-OPEN-04): slot 1 is human; in versus, slot 2.
func test_two_players() -> void:
	op = OpenPlay.new()
	op.begin(5, true)
	eq(op.two_players, 1)
	op.called = 1
	op.opponent = 3
	op.partner = 4
	var cfg := Settings.open_play_config(op)
	eq(cfg.human, [1, 1, 0, 0], "2P on slot 1")
	eq(cfg.partner, -1, "2P, not the captain next in line")
	var sim := Sim.new(cfg)
	eq(sim.owners[1], K.OWNER_HUMAN)
	eq(sim.players[1].cpu_controlled, 0)
	var it := SimTypes.Intent.new()
	it.move_x = 1
	sim.step([null, it, null, null])
	eq(sim.intents[1].move_x, 1, "slot 1 takes 2P's input")
	eq(sim.intents[2].move_x == 1 and sim.owners[2] == K.OWNER_HUMAN, false)


## M4-OPEN-05: the clubhouse. Its walls are solid; the door in the bottom
## wall lets you in. Inside, B at the board turns its page and B at the
## ball machine asks for practice; the bench seats the first two teams
## waiting.
func test_clubhouse() -> void:
	op = OpenPlay.new()
	op.begin(7, false)
	# Walls, inside, the door.
	check(not OpenPlay.walkable(K.to_fp(OpenPlay.HOUSE_LEFT + 2), K.to_fp(100)))
	check(not OpenPlay.walkable(K.to_fp(OpenPlay.HOUSE_RIGHT - 2), K.to_fp(100)))
	check(not OpenPlay.walkable(K.to_fp(360), K.to_fp(OpenPlay.HOUSE_TOP + 2)))
	check(not OpenPlay.walkable(K.to_fp(340), K.to_fp(OpenPlay.HOUSE_BOTTOM - 2)))
	check(OpenPlay.walkable(K.to_fp(360), K.to_fp(100)))
	check(OpenPlay.walkable(K.to_fp(OpenPlay.HOUSE_DOOR_X), K.to_fp(OpenPlay.HOUSE_BOTTOM - 2)))
	check(OpenPlay.walkable(K.to_fp(OpenPlay.HOUSE_LEFT - 8), K.to_fp(100)))
	# Walk in: along the path to the door, then up through it.
	_place_you(OpenPlay.HOUSE_DOOR_X, OpenPlay.START_Y)
	check(not op.in_house())
	for n in 60:
		op.update(0, -1, false)
	check(op.in_house(), "in through the door")
	# Walking into a wall from inside stops at it.
	for n in 200:
		op.update(1, 0, false)
	check(K.from_fp(op.x_fp) < OpenPlay.HOUSE_RIGHT - OpenPlay.HOUSE_WALL)
	# The board: each B the next page, round again; leaving clears it.
	_place_you(OpenPlay.BOARD_X, OpenPlay.BOARD_Y)
	eq(op.update(0, 0, true), OpenPlay.EVENT_BOARD)
	eq(op.board_page, 0)
	for n in range(1, OpenPlay.BOARD_PAGES):
		op.update(0, 0, true)
	eq(op.board_page, OpenPlay.BOARD_PAGES - 1)
	op.update(0, 0, true)
	eq(op.board_page, 0)
	_place_you(400, 120)
	op.update(0, 0, false)
	eq(op.board_page, OpenPlay.NONE)
	# The ball machine.
	_place_you(OpenPlay.MACHINE_X, OpenPlay.MACHINE_Y)
	check(op.machine_near())
	eq(op.update(0, 0, true), OpenPlay.EVENT_PRACTICE)
	# The bench: the two teams waiting at the start (one each at the first
	# two levels' courts).
	check(op.waiting_team(0) < OpenPlay.TEAMS)
	check(op.waiting_team(1) < OpenPlay.TEAMS)
	check(op.waiting_team(0) != op.waiting_team(1))
	eq(op.waiting_team(2), OpenPlay.NONE)
	_place_you(OpenPlay.BENCH_X + 24, OpenPlay.BENCH_Y + 8)
	check(op.bench_near())
	_check_population()


func _same_style(a: SimTypes.AiStyle, b: SimTypes.AiStyle) -> bool:
	for f in ["late_period", "reaction", "dink_period", "lob_distance", "putaway_z",
			"putaway_distance", "aim", "depth", "recover", "speed", "volley", "net",
			"team", "tactics", "footwork"]:
		if a.get(f) != b.get(f):
			return false
	return true


## test_opponents.c test_partner: the captain of a ladder team on slot 1,
## in their look, body, paddle, and play style; difficulty never changes
## your partner.
func test_partner() -> void:
	var cfg := Settings.config_for(true, 6, K.DIFFICULTY_HARD, 11)
	cfg.set_partner(7)
	var captain: Dictionary = Opponents.team(7)["players"][0]
	eq(cfg.partner, 7)
	check(_same_style(Opponents.slot_style(cfg, 1), captain["style_obj"]), "slot 1 the captain's style")
	check(_same_style(Opponents.slot_style(cfg, 0), Opponents.default_style()), "slot 0 unchanged")
	check(_same_style(Opponents.slot_style(cfg, 2), Opponents.team(6)["players"][0]["style_obj"]))
	eq(cfg.variant[1], K.VARIANT_FEMALE if captain["variant"] == "female" else K.VARIANT_MALE)
	eq(cfg.paddle[1], Paddles.NAMES.find(captain["paddle"]))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/levels/manifest.json"))
	var look := PlayerLook.for_slot(cfg, 1, manifest)
	check(look != null and look.palette == PlayerLook.from_member(captain, manifest).palette,
		"slot 1 in the captain's colours")
	eq(look.hat, String(captain.get("hat", "cap")), "and hat")
	var sim := Sim.new(cfg)
	check(_same_style(sim.ai.styles[1], captain["style_obj"]), "HARD didn't change the partner")
	# No partner from the stack: the smarter partner style (ADR-035).
	cfg.set_partner(-1)
	check(_same_style(Opponents.slot_style(cfg, 1), Opponents.partner_style()))
	check(PlayerLook.for_slot(cfg, 1, manifest) == null, "the team colours again")
	eq(SimTypes.MatchConfig.doubles().partner, -1, "other modes leave it unset")


## main.c start_open_play_match: doubles vs the team drawn, the captain
## next in line as partner, the court's difficulty, saved points and
## modifiers.
func test_open_play_config() -> void:
	var kept := [Settings.difficulty_i, Settings.points_i, Settings.mod_bits]
	op = OpenPlay.new()
	op.begin(3, false)
	op.called = 2
	op.opponent = 6
	op.partner = 7
	Settings.difficulty_i = K.DIFFICULTY_EASY
	Settings.points_i = 1
	Settings.mod_bits = K.MOD_BIG_BALL
	var cfg := Settings.open_play_config(op)
	eq(cfg.mode, K.MODE_DOUBLES)
	eq(cfg.opponent, 6)
	eq(cfg.partner, 7)
	eq(cfg.human, [1, 0, 0, 0])
	eq(cfg.difficulty, K.DIFFICULTY_HARD, "4.5+ is HARD whatever OPTIONS says")
	eq(cfg.points_to_win, Settings.POINTS[1])
	eq(cfg.modifiers, K.MOD_BIG_BALL)
	eq(cfg.open_play, 1)
	Settings.difficulty_i = K.DIFFICULTY_KID
	eq(Settings.open_play_config(op).difficulty, K.DIFFICULTY_KID, "KID keeps its assist")
	op.partner = OpenPlay.NONE
	eq(Settings.open_play_config(op).partner, -1, "nobody waiting: the regular")
	Settings.difficulty_i = kept[0]
	Settings.points_i = kept[1]
	Settings.mod_bits = kept[2]


## The park view only reads the park (apart from passing input on): it
## and a bare OpenPlay given the same input stay identical.
func test_view_never_writes_to_the_park() -> void:
	var a := OpenPlay.new()
	a.begin(77, false)
	var bare := OpenPlay.new()
	bare.begin(77, false)
	var view := ParkView.new().setup(a, null, false)
	view.input_lock = 0
	runner.root.add_child(view)
	var ok := true
	var stacked := false
	for f in 3000:
		var it := SimTypes.Intent.new()
		# a walk to court 2's rack, B there, then about the park
		if f < 400:
			it.move_x = 1 if K.from_fp(a.x_fp) < OpenPlay.rack_x(1) else -1
			it.move_y = -1 if K.from_fp(a.y_fp) > OpenPlay.RACK_Y else 0
		elif f == 400:
			it.hit_pressed = 1
		elif f > 600:
			it.move_x = 1 if (f >> 7) & 1 else -1
		view.step_frame(it)
		if a.called != OpenPlay.NONE and a.call_timer >= OpenPlay.CALL_FRAMES - 1:
			break                   # the match would start; nothing more to compare
		bare.update(it.move_x, it.move_y, it.hit_pressed != 0)
		stacked = stacked or a.your_court == 1
		if a.snapshot() != bare.snapshot():
			runner.fail("the view's park diverged from a bare park at frame %d" % f)
			ok = false
			break
	check(ok, "the view only reads the park")
	check(stacked, "stacked on court 2 on the way")
	view.queue_free()


## The panel's lines (render_park.c park_message).
func test_panel_lines() -> void:
	op = OpenPlay.new()
	op.begin(9, false)
	var view := ParkView.new().setup(op, null, false)
	eq(view.panel()[0], "OPEN PLAY")
	eq(view.panel()[1], [["start", "EXIT"]], "a prompt, not a button name")
	_place_you(OpenPlay.rack_x(1), OpenPlay.RACK_Y)
	eq(view.panel()[1], [["hit", "STACK YOUR PADDLE"]])
	op.update(0, 0, true)
	eq(view.panel()[1], [["hit", "TAKE YOUR PADDLE"]])
	_place_you(OpenPlay.START_X, OpenPlay.START_Y)
	var wait := op.your_wait()
	eq(view.panel()[0], ("YOU'RE NEXT ON COURT 2" if wait == 0 else "WAITING ON COURT 2"))
	_place_you(OpenPlay.court_left(0) - 6, OpenPlay.COURT_TOP + 40)
	eq(view.panel()[0], "%s VS %s" % [Opponents.team(op.court[0].playing[0])["team"],
		Opponents.team(op.court[0].playing[1])["team"]], "the peek")
	op.called = 1
	op.opponent = 4
	op.partner = 3
	eq(view.panel()[0], "WITH PETE VS GOTH CLUB")
	check(view.panel()[2], "the call in yellow")
	op.called = OpenPlay.NONE
	op.last_won = 1
	op.last_score = [7, 5]
	view.result_timer = 10
	eq(view.panel()[0], "YOU WON 7-5")
	view.result_timer = 0
	_place_you(OpenPlay.BOARD_X, OpenPlay.BOARD_Y)
	op.update(0, 0, true)
	eq(view.panel()[0], "DOUBLES  WON 0  LOST 0", "records board page 1")
	for line in ["UNDER 3.5", "3.5-4.5", "4.5+", "THE CLUBHOUSE", "THIS STACK IS FULL",
			"2P JOINED: YOUR PARTNER!", "CLEARS 0  DRILL BEST 0"]:
		check(BitmapText.measure("small", line) > 0)
		for ch in line:
			check(BitmapText.load_font("small")["glyphs"].has(ch), "the font has %s" % ch)
	view.free()


func _main() -> Node:
	SaveGame.default_dir = DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	return main


func _settle(main: Node) -> void:
	for f in main.FADE_OUT + main.FADE_IN + 1:
		main._physics_process(1.0 / 60.0)


## OPEN PLAY on MAIN opens the park; your game is a park doubles match;
## B on its result comes back to the park, which shows how it went and
## changes your court over; Start leaves for the title.
func test_main_reaches_the_park_and_back() -> void:
	var kept := SaveGame.default_dir
	var main := _main()
	var title: TitleScreen = main._screen
	if not title.is_node_ready():
		title._ready()              # the runner's root isn't ready during the suites
	var p: MenuPage = title.pages["main"]
	check(p.select("openplay"), "OPEN PLAY is on MAIN")
	p.press()
	_settle(main)
	var park: ParkView = main._screen
	check(park is ParkView, "the park")
	var o: OpenPlay = main.park
	check(o != null and o.called == OpenPlay.NONE, "a fresh park")
	# Stack on court 1 and wait (the park's own clock, quickly).
	o.x_fp = K.to_fp(OpenPlay.rack_x(0))
	o.y_fp = K.to_fp(OpenPlay.RACK_Y)
	park.input_lock = 0
	var b := SimTypes.Intent.new()
	b.hit_pressed = 1
	park.step_frame(b)
	eq(o.your_court, 0, "stacked")
	var frames := 0
	while o.called == OpenPlay.NONE and frames < 60 * 60 * 5:
		o.update(0, 0, false)
		frames += 1
	eq(o.called, 0, "called on court 1")
	for f in OpenPlay.CALL_FRAMES + 1:
		if main._screen != park or main.fading():
			break
		park.step_frame(SimTypes.Intent.new())
	_settle(main)
	var m: MatchView = main._screen
	check(m is MatchView and m.park, "your game")
	eq(m.sim.config.open_play, 1)
	eq(m.sim.config.difficulty, K.DIFFICULTY_EASY, "court 1 is EASY")
	eq(m.venue, "park")
	eq(m.card_frames, -1, "no intro card")
	# The result: B goes back to the park.
	m.sim.team_score = [5, 3]
	m.sim.match_winner = 0
	m.sim.rematch_requested = true
	m._physics_process(1.0 / 60.0)
	_settle(main)
	var back: ParkView = main._screen
	check(back is ParkView and back.op == o, "the same park")
	eq(back.message, "YOU WON 5-3")
	eq(o.court[0].state, OpenPlay.COURT_CHANGEOVER, "your court changes over")
	eq(int(main.save.data["records"]["ladder_rung"]), 0, "no ladder change")
	# Start: the title.
	back.input_lock = 0
	var start := SimTypes.Intent.new()
	start.pause_pressed = 1
	back.step_frame(start)
	_settle(main)
	check(main._screen is TitleScreen, "Start leaves for the title")
	check(main.park == null, "and the park is gone")
	main.free()
	SaveGame.default_dir = kept


## The ball machine: practice on the saved drill; PARK on its pause menu
## comes back to the park, which waited.
func test_ball_machine_practice() -> void:
	var kept := SaveGame.default_dir
	var main := _main()
	main._on_open_park(false)
	_settle(main)
	var park: ParkView = main._screen
	var o: OpenPlay = main.park
	o.x_fp = K.to_fp(OpenPlay.MACHINE_X)
	o.y_fp = K.to_fp(OpenPlay.MACHINE_Y)
	park.input_lock = 0
	var b := SimTypes.Intent.new()
	b.hit_pressed = 1
	park.step_frame(b)
	_settle(main)
	var m: MatchView = main._screen
	check(m is MatchView and m.sim.config.practice == 1, "practice")
	var rows: Array = m.pause_rows()
	eq(rows[rows.size() - 1]["label"], "PARK", "the pause menu goes back to the park")
	var before := o.snapshot()
	m.leave_practice()
	_settle(main)
	check(main._screen is ParkView and main._screen.op == o, "back in the park")
	eq(o.snapshot(), before, "the park waited")
	main.free()
	SaveGame.default_dir = kept
