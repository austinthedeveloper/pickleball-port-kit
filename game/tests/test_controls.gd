## PORT-12: remapping (a rebind reaches the input map and the prompts, a
## conflict swaps, reset restores, the save keeps it) and accessibility
## (each option against its effect).
extends TestSuite


func _keys(action: String) -> Array:
	var out := []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(e.physical_keycode)
	return out


func _pad(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return e.button_index
	return -1


func test_rebind_reaches_the_map_and_prompts() -> void:
	Bindings.reset()
	var serial := GameControls.binding_serial
	Bindings.rebind_key("hit", KEY_H)
	eq(_keys("hit")[0], KEY_H, "the new main key")
	check(not KEY_SPACE in _keys("hit"), "the old main key is gone")
	check(KEY_J in _keys("hit"), "the second key stays")
	eq(Prompts.label("hit", GameControls.KEYBOARD), "H", "prompts show it")
	check(GameControls.binding_serial > serial, "prompt bars hear about it")
	var joy := false
	for e in InputMap.action_get_events("move_left"):
		joy = joy or e is InputEventJoypadMotion
	check(joy, "the sticks stay on the moves")
	Bindings.reset()


func test_conflicts_swap() -> void:
	Bindings.reset()
	Bindings.rebind_key("hit", KEY_K)         # drive's key
	eq(_keys("hit")[0], KEY_K)
	eq(_keys("drive"), [KEY_SPACE], "drive takes hit's old key")
	Bindings.rebind_key("soft", KEY_J)        # hit's second key
	check(not KEY_J in _keys("hit"), "taken from hit")
	eq(_keys("hit").size() >= 1, true, "hit still has a key")
	Bindings.rebind_pad("hit", JOY_BUTTON_B)  # drive's button
	eq([_pad("hit"), _pad("drive")], [JOY_BUTTON_B, JOY_BUTTON_A], "the buttons swap")
	for a in Bindings.ACTIONS:
		check(not _keys(a).is_empty() and _pad(a) >= 0, "%s is still bound" % a)
	check(not Bindings.is_default())
	Bindings.reset()
	check(Bindings.is_default(), "reset")
	eq(_keys("hit"), [KEY_SPACE, KEY_J], "the defaults are back")
	eq(_pad("drive"), JOY_BUTTON_B)


func test_bindings_saved() -> void:
	var save := SaveGame.new()
	save.dir = "user://test_controls/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save.dir))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.dir + f))
	save.load_game()
	Bindings.reset()
	Bindings.rebind_key("start", KEY_P)
	Bindings.rebind_pad("soft", JOY_BUTTON_Y)
	Settings.store_to(save)
	save.save_game()
	Bindings.reset()
	var again := SaveGame.new()
	again.dir = save.dir
	again.load_game()
	Settings.load_from(again)
	eq(_keys("start")[0], KEY_P, "a remapped key survives a restart")
	eq(_pad("soft"), JOY_BUTTON_Y, "and a remapped button")
	Bindings.from_save({"hit": "nonsense", "drive": {"keys": []}})
	check(Bindings.is_default(), "malformed bindings load as the defaults")
	Bindings.reset()


func _title() -> TitleScreen:
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	return t


func _press(t: TitleScreen, code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	t._input(e)


func test_controls_page_listens() -> void:
	Bindings.reset()
	var t := _title()
	t.open_page("controls")
	var p: MenuPage = t.pages["controls"]
	eq(p.rows.map(func(r): return r["id"]).slice(0, 6), ["hit", "drive", "soft", "slice", "short", "start"],
		"the four swings, SHORT (SNES ADR-056), then START")
	p.select("soft")
	p.press()
	eq(t.listening, "soft", "B on a row listens")
	eq(p.value_of("soft"), "PRESS A KEY OR BUTTON")
	_press(t, KEY_O)
	eq(_keys("soft")[0], KEY_O, "the next key rebinds")
	check(t.listening == "" and t._lock > 0, "and is swallowed (rule 9)")
	p.press()
	_press(t, KEY_ESCAPE)
	eq(_keys("soft")[0], KEY_O, "Esc cancels")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_LEFT_SHOULDER
	b.pressed = true
	p.press()
	t._input(b)
	eq(_pad("soft"), JOY_BUTTON_LEFT_SHOULDER, "a pad button rebinds the pad")
	p.select("reset")
	p.press()
	check(Bindings.is_default(), "RESET DEFAULTS")
	t.free()


func test_accessibility_effects() -> void:
	var kept := [Settings.shake, Settings.flashes, Settings.hud_large, Settings.serve_assist]
	# SCREEN SHAKE off: a drive doesn't move the picture
	Settings.shake = false
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.singles(), "park", false)
	v.feel.on_event([K.EVENT_HIT, 120, 130, K.SHOT_DRIVE << 4])
	eq(v.feel.shake_frames, 0, "no shake")
	Settings.shake = true
	v.feel.on_event([K.EVENT_HIT, 120, 130, K.SHOT_DRIVE << 4])
	check(v.feel.shake_frames > 0, "shake on again")
	# FLASHES off: a hit player doesn't flash white
	Settings.flashes = false
	v.sim.players[0].flash_timer = 3
	v._update_visuals()
	eq(v._players[0]["body"].modulate, Color.WHITE, "no flash")
	Settings.flashes = true
	v._update_visuals()
	check(v._players[0]["body"].modulate.r > 1.0, "the flash with FLASHES on")
	v.free()
	# HUD TEXT LARGE: the banners grow
	Settings.hud_large = true
	var big := MatchView.new()
	runner.root.add_child(big)
	big.setup(SimTypes.MatchConfig.singles(), "park", false)
	eq(big._hud._banner.scale, Vector2(1.5, 1.5), "large banners")
	big.free()
	Settings.hud_large = false
	# SERVE ASSIST: holding B serves strong without timing the release
	for assist in [false, true]:
		Settings.serve_assist = assist
		var s := MatchView.new()
		runner.root.add_child(s)
		s.setup(SimTypes.MatchConfig.singles(), "park", false)
		var frames := 0
		while s.sim.phase == K.PHASE_SERVE_SETUP and frames < 400:
			var it := SimTypes.Intent.new()
			it.hit_held = 1
			s._serve_assist(it)
			s.sim.step([it, null, null, null])
			s.sim.drain_events()
			frames += 1
		if assist:
			eq(s.sim.phase, K.PHASE_SERVE_TOSS, "the assist lets go")
			check(s.sim.charge_power >= MatchInput.SERVE_ASSIST_LEVEL, "a strong serve (%d)" % s.sim.charge_power)
		else:
			eq(s.sim.phase, K.PHASE_SERVE_SETUP, "without it, holding never serves")
		s.free()
	Settings.shake = kept[0]
	Settings.flashes = kept[1]
	Settings.hud_large = kept[2]
	Settings.serve_assist = kept[3]
