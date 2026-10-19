## PORT-16: multiplayer. The lobby's rules (join, sides and partners,
## shirts, ready, start), the match it builds, four humans in the sim each
## on their own intent, and the view reading four (fake) controllers.
extends TestSuite

const A := Practice.PAD_B        ## the pad's A button, as menu bits
const B := Lobby.BACK
const MENU := Practice.PAD_START
const UP := Practice.PAD_UP
const DOWN := Practice.PAD_DOWN
const LEFT := Practice.PAD_LEFT
const RIGHT := Practice.PAD_RIGHT


func test_join_and_sides() -> void:
	var l := Lobby.new()
	eq(l.join(7), 0, "the first pad is P1")
	eq(l.join(3), 1, "the next P2, whatever its device id")
	eq(l.join(7), 0, "joining twice is the same card")
	eq([l.cards[0]["side"], l.cards[1]["side"]], [Lobby.LEFT, Lobby.LEFT], "doubles: two on the left")
	eq(l.join(5), 2)
	eq(l.cards[2]["side"], Lobby.RIGHT, "the left is full")
	l.input(7, RIGHT)                         # P1 crosses: the right has room
	eq(l.cards[0]["side"], Lobby.RIGHT, "P1 goes right: P1 and P3 are partners now")
	eq(l.slot_players(), [1, -1, 0, 2], "P2 alone on the left with a CPU partner")
	eq(l.join(9), 3)
	eq(l.cards[3]["side"], Lobby.LEFT, "the newcomer takes the room")
	eq(l.join(11), -1, "four at most")
	l.input(9, RIGHT)
	eq(l.cards[3]["side"], Lobby.LEFT, "no room on the right: P4 stays")
	l.set_mode(K.MODE_SINGLES)
	eq(l.blocker(), "SINGLES IS TWO PLAYERS", "four players can't play singles")
	l.leave(3)
	l.leave(2)
	l.set_mode(K.MODE_DOUBLES)
	l.cards[0]["side"] = Lobby.LEFT
	l.set_mode(K.MODE_SINGLES)
	eq([l.side_count(Lobby.LEFT), l.side_count(Lobby.RIGHT)], [1, 1],
		"singles: the second left player crosses to the empty right")
	check(not l.cards[1]["ready"], "and has to ready again")


func test_shirts_stay_unique() -> void:
	var l := Lobby.new()
	for d in [1, 2, 3, 4]:
		l.join(d)
	var colours := l.cards.map(func(c): return c["palette"])
	eq(colours, [0, 1, 2, 3], "each joins in a free colour")
	l.input(1, DOWN)                          # SHIRT row
	l.input(1, RIGHT)
	eq(l.cards[0]["palette"], 0, "every colour is taken: P1 keeps theirs")
	l.leave(3)
	l.input(1, RIGHT)
	eq(l.cards[0]["palette"], 3, "a free colour now")
	l.input(1, DOWN)                          # BODY
	l.input(1, RIGHT)
	eq(l.cards[0]["variant"], K.VARIANT_FEMALE)
	l.input(1, DOWN)                          # PADDLE
	l.input(1, LEFT)
	eq(l.cards[0]["paddle"], Paddles.WOOD)


func test_ready_back_and_start() -> void:
	var l := Lobby.new()
	eq(l.input(1, B), Lobby.LEAVE, "B with nobody joined leaves")
	l.input(1, A)
	l.input(2, A)
	eq(l.joined().size(), 2, "A joins")
	eq(l.blocker(), "WAITING FOR READY")
	l.input(1, A)
	check(l.cards[0]["ready"], "A again readies")
	l.input(1, RIGHT)
	eq(l.cards[0]["side"], Lobby.LEFT, "a ready card is locked")
	eq(l.input(1, MENU), Lobby.STAY, "can't start while P2 isn't ready")
	l.input(2, A)
	eq(l.blocker(), "SOMEONE TAKE THE RIGHT SIDE", "both on the left")
	l.input(2, B)
	check(not l.cards[1]["ready"], "B un-readies")
	l.input(2, RIGHT)
	l.input(2, A)
	eq(l.blocker(), "")
	eq(l.input(2, MENU), Lobby.START, "Menu starts")
	# everyone on the right: slot 0 must be a human
	l.input(1, B)
	l.input(1, RIGHT)
	l.input(1, A)
	eq(l.blocker(), "SOMEONE TAKE THE LEFT SIDE", "slot 0 is always a human: someone on the left")
	l.input(1, B)
	l.input(1, B)
	check(l.cards[0] == null, "B on an unready card leaves the lobby slot")


func test_match_config() -> void:
	var l := Lobby.new()
	l.join(10)                                 # P1 left
	l.join(11)                                 # P2 left (P1's partner)
	l.join(12)                                 # P3 right, with a CPU partner
	l.cards[1]["paddle"] = Paddles.RED
	eq(l.slot_players(), [0, 1, 2, -1])
	eq(l.slot_pads(), [10, 11, 12, -1])
	var cfg := l.match_config(K.DIFFICULTY_HARD, 11, K.MOD_LAVA)
	eq(cfg.mode, K.MODE_DOUBLES)
	eq(cfg.human, [1, 1, 1, 0])
	eq(cfg.paddle, [Paddles.STANDARD, Paddles.RED, Paddles.STANDARD, Paddles.STANDARD])
	eq(cfg.palette[3], 3, "the CPU takes the free colour")
	check(PlayerSelect.palettes_unique(cfg), "unique colours")
	eq([cfg.difficulty, cfg.points_to_win, cfg.modifiers, cfg.opponent],
		[K.DIFFICULTY_HARD, 11, K.MOD_LAVA, -1])
	var sim := Sim.new(cfg)
	eq(sim.owners, [K.OWNER_HUMAN, K.OWNER_HUMAN, K.OWNER_HUMAN, K.OWNER_CPU])
	# singles: one each side, on slots 0 and 2
	var s := Lobby.new()
	s.set_mode(K.MODE_SINGLES)
	s.join(4)
	s.join(8)
	eq(s.cards[1]["side"], Lobby.RIGHT, "singles: the second player goes right")
	eq(s.slot_players(), [0, -1, 1, -1])
	var sc := s.match_config(K.DIFFICULTY_MEDIUM, 5, 0)
	eq([sc.palette[1], sc.palette[3]], [-1, -1], "slots 1 and 3 off")
	eq(sc.human, [1, 0, 1, 0])


## Four humans in the sim, each moved by their own intent only.
func test_four_humans_in_the_sim() -> void:
	var l := Lobby.new()
	for d in [1, 2, 3, 4]:
		l.join(d)
	var sim := Sim.new(l.match_config(K.DIFFICULTY_MEDIUM, 11, 0))
	eq(sim.owners, [K.OWNER_HUMAN, K.OWNER_HUMAN, K.OWNER_HUMAN, K.OWNER_HUMAN])
	var start: Array = sim.players.map(func(p): return [p.x_fp, p.y_fp])
	for f in 40:
		var its := []
		for s in 4:
			var it := SimTypes.Intent.new()
			if s == 3:
				it.move_y = -1                     # only P4 moves
			its.append(it)
		sim.step(its)
	for s in 3:
		eq([sim.players[s].x_fp, sim.players[s].y_fp], start[s], "slot %d stood still" % s)
	check(sim.players[3].y_fp < start[3][1], "slot 3 moved on its own intent")


func _pads(ids: Array) -> void:
	GameControls.fake_pads = {}
	for d in ids:
		GameControls.fake_pads[d] = {"buttons": []}


func _hold(dev: int, buttons: Array) -> void:
	GameControls.fake_pads[dev]["buttons"] = buttons


func test_view_reads_each_controller() -> void:
	_pads([20, 21, 22, 23])
	var l := Lobby.new()
	for d in [20, 21, 22, 23]:
		l.join(d)
	var v := MatchView.new()
	v.slot_pads = l.slot_pads()
	v.slot_players = l.slot_players()
	runner.root.add_child(v)
	v.setup(l.match_config(K.DIFFICULTY_MEDIUM, 11, 0), "park", false)
	check(v.multiplayer(), "a multiplayer match")
	eq(v._hud._tags.size(), 4, "a tag over each player")
	for f in MatchView.INPUT_LOCK_FRAMES + 2:
		v._physics_process(1.0 / 60.0)
	var y0: int = v.sim.players[0].y_fp
	var y3: int = v.sim.players[3].y_fp
	_hold(23, [JOY_BUTTON_DPAD_UP])
	for f in 20:
		v._physics_process(1.0 / 60.0)
	check(v.sim.players[3].y_fp < y3, "P4's pad moves P4")
	eq(v.sim.players[0].y_fp, y0, "and nobody else")
	_hold(23, [])
	_hold(22, [JOY_BUTTON_START])               # P3 pauses
	v._physics_process(1.0 / 60.0)
	eq(v.sim.paused, 1, "anyone's Menu pauses")
	_hold(22, [])
	v._physics_process(1.0 / 60.0)
	_hold(21, [JOY_BUTTON_A])                   # P2 picks RESUME
	v._physics_process(1.0 / 60.0)
	v._physics_process(1.0 / 60.0)
	eq(v.sim.paused, 0, "anyone's A works the pause menu")
	v.free()
	GameControls.fake_pads = {}


func test_lobby_on_the_title() -> void:
	_pads([30, 31])
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	var started := []
	t.start_match.connect(func(cfg, _v, _l, pads, players): started.append([cfg, pads, players]))
	t.pages["main"].select("multiplayer")
	t.pages["main"].press()
	eq(t.page, "multi", "MULTIPLAYER: LOCAL or ONLINE (PORT-31)")
	t.pages["multi"].select("local")
	t.pages["multi"].press()
	eq(t.page, "lobby", "LOCAL opens the lobby")
	check(t.lobby_screen.visible and not t._header[0].visible, "over the title")
	var tap := func(dev: int, buttons: Array) -> void:
		_hold(dev, buttons)
		t._update_lobby()
		_hold(dev, [])
		t._update_lobby()
	tap.call(30, [JOY_BUTTON_A])
	tap.call(30, [JOY_BUTTON_RIGHT_SHOULDER])
	eq(t.lobby.mode_name(), "SINGLES CUP", "RB steps on (PORT-29)")
	tap.call(30, [JOY_BUTTON_LEFT_SHOULDER])
	eq(t.lobby.mode_name(), "DOUBLES", "LB steps back")
	tap.call(31, [JOY_BUTTON_A])
	eq(t.lobby.joined().size(), 2, "two pads joined")
	tap.call(31, [JOY_BUTTON_DPAD_RIGHT])       # P2 to the right side
	tap.call(30, [JOY_BUTTON_A])
	tap.call(31, [JOY_BUTTON_A])
	t.lobby_screen.refresh()
	eq(t.lobby_screen._status.text, "READY TO START")
	tap.call(30, [JOY_BUTTON_START])
	eq(started.size(), 1, "Menu starts the match")
	var cfg: SimTypes.MatchConfig = started[0][0]
	eq(cfg.human, [1, 0, 1, 0], "doubles: P1 left and P2 right, each with a CPU partner")
	eq(started[0][1], [30, -1, 31, -1], "each human slot's pad")
	eq(started[0][2], [0, -1, 1, -1], "and player number")
	t.free()
	GameControls.fake_pads = {}
