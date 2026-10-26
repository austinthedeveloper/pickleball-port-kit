## PORT-15: controllers. Who plays on which pad (and hot-plugging), the
## input map following it, menu repeat on a held stick, a lost pad
## pausing the match, the connection toast, and rumble.
extends TestSuite

var _kept: Array


func _keep() -> void:
	_kept = [GameControls.p1_pad, GameControls.p2_pad, GameControls.last_device,
		GameControls.last_pad, Settings.vibration, Settings.two_players]


func _restore() -> void:
	Settings.vibration = _kept[4]
	Settings.two_players = _kept[5]
	GameControls.last_device = _kept[2]
	GameControls.last_pad = _kept[3]
	GameControls.assign_pads(Input.get_connected_joypads(), false)


func _pad_devices(action: String) -> Array:
	var out := []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			out.append(e.device)
	return out


func test_pad_assignment() -> void:
	_keep()
	GameControls.assign_pads([], false)
	eq([GameControls.p1_pad, GameControls.p2_pad], [-1, GameControls.NO_PAD], "no pads: any pad (none yet)")
	GameControls.assign_pads([3], false)
	eq(GameControls.p1_pad, -1, "one-player: whichever pad you pick up")
	check(_pad_devices("hit").all(func(d): return d == -1), "P1's pad events listen on every pad")
	check(_pad_devices("move_left").size() >= 2, "the D-pad and the stick")
	GameControls.set_split(true)               # a 2P match on screen
	GameControls.assign_pads([3, 1], true)
	eq([GameControls.p1_pad, GameControls.p2_pad], [1, 3], "2P with two pads: the first is P1's")
	check(_pad_devices("hit").all(func(d): return d == 1), "P1 listens on their pad only")
	check(_pad_devices("move_up").all(func(d): return d == 1))
	GameControls.assign_pads([2], true)
	eq([GameControls.p1_pad, GameControls.p2_pad], [GameControls.NO_PAD, 2],
		"2P with one pad: P2 takes it, P1 the keyboard")
	check(not 2 in _pad_devices("hit"), "so the pad never drives P1")
	var keys := 0
	for e in InputMap.action_get_events("hit"):
		keys += 1 if e is InputEventKey else 0
	eq(keys, 2, "the keys stay")
	Bindings.rebind_pad("hit", JOY_BUTTON_Y)
	check(_pad_devices("hit").all(func(d): return d == GameControls.p1_device()),
		"a remap keeps the player's pad")
	Bindings.reset()
	GameControls.set_split(false)
	_restore()


## A tester's report: PLAYERS 2P with one pad gave the pad to 2P, and
## MATCH SETUP stopped hearing it. The split holds on the court only.
func test_menus_hear_every_pad() -> void:
	_keep()
	GameControls.set_split(false)
	GameControls.assign_pads([2], true)
	eq([GameControls.p1_pad, GameControls.p2_pad], [GameControls.NO_PAD, 2], "2P still owns the pad")
	check(_pad_devices("hit").all(func(d): return d == -1), "but the menus hear it")
	check(_pad_devices("move_down").all(func(d): return d == -1))
	GameControls.set_split(true)
	check(not 2 in _pad_devices("hit"), "on the court it's 2P's alone")
	GameControls.set_split(false)
	check(_pad_devices("hit").all(func(d): return d == -1), "and back in the menus, everyone's")
	var Main: GDScript = load("res://scenes/main.gd")
	var cfg := SimTypes.MatchConfig.singles()
	var one := MatchView.new()
	one.setup(cfg, "park", false)
	check(not Main._splits_pads(one), "a 1P match: no split")
	var two_cfg := SimTypes.MatchConfig.singles()
	two_cfg.human[2] = 1
	var two := MatchView.new()
	two.setup(two_cfg, "park", false)
	check(Main._splits_pads(two), "2P on the court: split")
	var demo := MatchView.new()
	demo.setup(two_cfg, "park", true)
	check(not Main._splits_pads(demo), "the title's demo: no split")
	var menu := Node.new()
	check(not Main._splits_pads(menu), "a menu screen: no split")
	for n in [one, two, demo, menu]:
		n.free()
	_restore()


func test_hot_plug() -> void:
	_keep()
	var news := GameControls.news_serial
	var lost := GameControls.lost_serial
	GameControls._on_joy_connection(0, true)
	eq(GameControls.pad_news, ["CONNECTED", 0])
	eq(GameControls.news_serial, news + 1)
	eq(GameControls.lost_serial, lost, "a connect isn't a loss")
	GameControls._on_joy_connection(0, false)
	eq(GameControls.pad_news, ["DISCONNECTED", 0])
	eq(GameControls.lost_serial, lost + 1)
	_restore()


func test_menu_repeat() -> void:
	var st := {}
	var R := func(just: bool, held: bool, now: int) -> bool:
		return GameControls.repeat_step(st, "move_down", just, held, now)
	check(R.call(true, true, 1000), "a press moves")
	check(not R.call(false, true, 1100), "holding waits")
	check(not R.call(false, true, 1299))
	check(R.call(false, true, 1300), "then repeats after %d ms" % GameControls.REPEAT_DELAY_MS)
	check(not R.call(false, true, 1350))
	check(R.call(false, true, 1385), "every %d ms" % GameControls.REPEAT_EVERY_MS)
	check(not R.call(false, false, 1500), "let go: nothing")
	check(not R.call(false, true, 2000), "holding again without a press doesn't repeat")


func test_lost_pad_pauses_the_match() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.singles(), "park", false)
	v.input_lock = 0
	v._physics_process(1.0 / 60.0)
	eq(v.sim.paused, 0)
	GameControls._on_joy_connection(5, false)
	v._physics_process(1.0 / 60.0)
	eq(v.sim.paused, 1, "a controller dropping out pauses")
	v._hud.refresh()
	check(v._hud._paused.visible, "the pause menu waits")
	v._physics_process(1.0 / 60.0)
	eq(v.sim.paused, 1, "and stays paused")
	v.free()
	var demo := MatchView.new()
	runner.root.add_child(demo)
	demo.setup(SimTypes.MatchConfig.singles(), "park", true)
	GameControls._on_joy_connection(5, false)
	demo._physics_process(1.0 / 60.0)
	eq(demo.sim.paused, 0, "the demo doesn't pause")
	demo.free()
	GameControls.refresh_pads()


func test_toast() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = "user://test_controller/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.default_dir))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	main._physics_process(1.0 / 60.0)
	check(not main._toast.visible, "quiet at first")
	GameControls._on_joy_connection(0, true)
	main._physics_process(1.0 / 60.0)
	check(main._toast.visible, "a toast")
	eq(main._toast_text.text, "CONTROLLER CONNECTED")
	for f in main.TOAST_FRAMES:
		main._physics_process(1.0 / 60.0)
	check(not main._toast.visible, "it goes")
	main.free()
	SaveGame.default_dir = kept
	GameControls.refresh_pads()


func test_rumble() -> void:
	_keep()
	GameControls.assign_pads([0], false)
	Settings.vibration = true
	GameControls.last_device = GameControls.PAD
	GameControls.last_pad = 0
	GameControls.last_rumble = []
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.singles(), "park", false)
	v._rumble_hit(0, K.SHOT_DRIVE)
	eq(GameControls.last_rumble.slice(0, 1), [0], "P1's pad")
	check(GameControls.last_rumble[2] > 0.5, "a drive kicks hard")
	v._rumble_hit(0, K.SHOT_SOFT)
	eq(GameControls.last_rumble[2], 0.0, "a soft shot barely")
	GameControls.last_rumble = []
	v._rumble_hit(2, K.SHOT_DRIVE)
	eq(GameControls.last_rumble, [], "not for the CPU's shots")
	Settings.vibration = false
	v._rumble_hit(0, K.SHOT_DRIVE)
	eq(GameControls.last_rumble, [], "VIBRATION off")
	Settings.vibration = true
	GameControls.last_device = GameControls.KEYBOARD
	v._rumble_hit(0, K.SHOT_DRIVE)
	eq(GameControls.last_rumble, [], "not when playing on the keyboard")
	v.free()
	_restore()


## PORT-28: each pad family's glyphs. The family comes from the pad's name
## (unknown pads are Xbox), or BUTTON ICONS forces one; Nintendo labels go
## by position (the south button, JOY_BUTTON_A, is B).
func test_pad_families() -> void:
	eq(Prompts.family_of("PS5 Controller"), Prompts.PLAYSTATION)
	eq(Prompts.family_of("Sony DualSense Wireless Controller"), Prompts.PLAYSTATION)
	eq(Prompts.family_of("PS4 Controller"), Prompts.PLAYSTATION)
	eq(Prompts.family_of("Nintendo Switch Pro Controller"), Prompts.NINTENDO)
	eq(Prompts.family_of("Joy-Con (L/R)"), Prompts.NINTENDO)
	eq(Prompts.family_of("Xbox Series Controller"), Prompts.XBOX)
	eq(Prompts.family_of("8BitDo SN30 Pro"), Prompts.XBOX, "an unknown pad: Xbox")
	eq(Prompts.family_of(""), Prompts.XBOX)
	var ps := Prompts.PLAYSTATION
	eq(Prompts.button_glyph(JOY_BUTTON_A, ps)["shape"], "cross", "south: cross")
	eq(Prompts.button_glyph(JOY_BUTTON_B, ps)["shape"], "circle")
	eq(Prompts.button_glyph(JOY_BUTTON_X, ps)["shape"], "square")
	eq(Prompts.button_glyph(JOY_BUTTON_Y, ps)["shape"], "triangle")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_START, ps)), "OPTIONS")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_LEFT_SHOULDER, ps)), "L1")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_A, ps)), "CROSS", "as text")
	var nin := Prompts.NINTENDO
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_A, nin)), "B", "Switch: south is B")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_B, nin)), "A", "east is A")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_START, nin)), "+")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_RIGHT_SHOULDER, nin)), "R")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_A, Prompts.XBOX)), "A")
	# BUTTON ICONS forces a family, and the prompts follow it
	var kept := Settings.pad_glyphs
	Settings.pad_glyphs = Prompts.FAMILIES.find(ps)
	eq(Prompts.label("hit", GameControls.PAD), "CROSS", "hit on a forced PlayStation pad")
	Settings.pad_glyphs = Prompts.FAMILIES.find(nin)
	eq(Prompts.label("drive", GameControls.PAD), "A", "drive (east) on a Switch pad")
	eq(Prompts.label("hit", GameControls.KEYBOARD), "SPACE", "the keyboard doesn't care")
	Settings.pad_glyphs = kept


## BUTTON ICONS on CONTROLS' CONTROLLER page (port ADR-082), by row id, saved.
func test_button_icons_row() -> void:
	var dir := "user://test_glyphs/"
	var s := fresh_save(dir)
	var kept := Settings.pad_glyphs
	var t := title_screen(s)
	check(t.pages["controls"].select("pad"), "CONTROLLER is on CONTROLS")
	var c: MenuPage = t.pages["pad"]
	check(c.select("icons"), "BUTTON ICONS is on CONTROLLER")
	eq(c.value_of("icons"), "AUTO")
	c.change(1)
	c.change(1)
	eq(c.value_of("icons"), "PLAYSTATION")
	t._store_settings()
	s.save_game()
	t.free()
	Settings.pad_glyphs = 0
	var s2 := SaveGame.new()
	s2.dir = dir
	s2.load_game()
	Settings.load_from(s2)
	eq(Settings.pad_glyphs, 2, "saved")
	Settings.pad_glyphs = kept
