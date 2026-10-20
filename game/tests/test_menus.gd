## PORT-03: the menu tree and the pause menu. Pages and rows are reached
## by name, never by counting presses (playbook §4.8).
extends TestSuite

const DIR := "user://test_menus/"
var _kept := []


func _keep() -> void:
	_kept = [Settings.venue_i, Settings.difficulty_i, Settings.points_i,
		Settings.opponent_i, Settings.two_players, Settings.camera_i,
		Settings.mod_bits, Settings.fullscreen, Settings.integer_scale,
		TitleScreen.main_cursor, Sfx.setting]


func _restore() -> void:
	var k := _kept
	Settings.venue_i = k[0]
	Settings.difficulty_i = k[1]
	Settings.points_i = k[2]
	Settings.opponent_i = k[3]
	Settings.two_players = k[4]
	Settings.camera_i = k[5]
	Settings.mod_bits = k[6]
	Settings.fullscreen = k[7]
	Settings.integer_scale = k[8]
	TitleScreen.main_cursor = k[9]
	Sfx.setting = k[10]


func _save() -> SaveGame:
	var s := fresh_save(DIR)
	return s


func _title(save: SaveGame) -> TitleScreen:
	var t := TitleScreen.new()
	t.save = save
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()                  # the runner's root isn't ready during the suites
	return t


func test_menu_page_rows_by_name() -> void:
	var hits := [0]
	var level := [0]
	var p := MenuPage.new().setup("t", "TEST", [
		{"id": "go", "label": "GO", "press": func(): hits[0] += 1},
		{"id": "level", "label": "LEVEL", "value": func(): return str(level[0]),
			"change": func(d): level[0] += d},
		{"id": "note", "label": "NOTE"},
	])
	check(p.select("level"), "select by id")
	eq(p.current_id(), "level")
	check(p.change(1) and p.change(1), "Right changes a choice row")
	eq(p.value_of("level"), "2")
	check(p.press(), "B on a choice row steps it")
	eq(level[0], 3)
	p.select("go")
	check(p.press(), "B on an action row presses it")
	eq(hits[0], 1)
	check(not p.change(1), "an action row has nothing to change")
	p.select("note")
	check(not p.press(), "a label row does nothing")
	p.move(1)
	eq(p.current_id(), "go", "Down wraps to the top")
	p.move(-1)
	eq(p.current_id(), "note", "Up wraps to the bottom")
	check(not p.select("missing"), "no such row")
	p.free()


func test_every_page_opens_by_name_and_backs_out() -> void:
	_keep()
	var t := _title(_save())
	eq(t.page, "main")
	for id in ["play", "modifiers", "options"]:
		t.pages["main"].select(id)
		t.pages["main"].press()
		eq(t.page, id, "MAIN's %s row opens its page" % id)
		check(t.pages[id].visible and not t.pages["main"].visible, "only %s shows" % id)
		eq(t.pages[id].rows[-1]["id"], "back", "%s ends in BACK" % id)
		t.pages[id].select("back")
		t.pages[id].press()
		eq(t.page, "main", "BACK from %s" % id)
		eq(t.pages["main"].current_id(), id, "the cursor lands on %s" % id)
	# CAREER (ADR-047): its slots, RECORDS from there, and back by BACK rows
	t.pages["main"].select("career")
	t.pages["main"].press()
	eq(t.page, "career", "MAIN's CAREER row opens the slots")
	t.pages["career"].select("records")
	t.pages["career"].press()
	eq(t.page, "records", "RECORDS from CAREER")
	t.pages["records"].select("back")
	t.pages["records"].press()
	eq(t.page, "career", "BACK from the records: CAREER")
	eq(t.pages["career"].current_id(), "records", "on RECORDS")
	t.pages["career"].select("back")
	t.pages["career"].press()
	eq(t.page, "main", "BACK from CAREER")
	eq(t.pages["main"].current_id(), "career", "the cursor lands on CAREER")
	t.pages["main"].select("practice")
	t.pages["main"].press()
	eq(t.page, "learn", "PRACTICE opens its page (PORT-30)")
	t.pages["learn"].select("machine")
	t.pages["learn"].press()
	check(t.page_open() and t.page == "practice", "BALL MACHINE opens the drill editor")
	t._update_practice(Practice.PAD_Y)
	eq(t.page, "learn", "backing out of the drill editor: PRACTICE's page")
	t.free()
	_restore()


func test_options_rows_change_their_settings() -> void:
	_keep()
	var t := _title(_save())
	t.open_page("options")
	var o: MenuPage = t.pages["options"]
	Sfx.setting = AudioMap.SOUND_ALL
	o.select("sound")
	o.change(1)
	eq(o.value_of("sound"), "NO CROWD")
	o.change(1)
	o.change(1)
	eq(Sfx.setting, AudioMap.SOUND_ALL, "SOUND wraps")
	Settings.camera_i = 0
	o.select("camera")
	o.change(1)
	eq(o.value_of("camera"), "50%")
	Settings.fullscreen = false
	o.select("fullscreen")
	o.press()
	eq(o.value_of("fullscreen"), "ON")
	Settings.integer_scale = true
	o.select("scale")
	o.change(-1)
	eq(o.value_of("scale"), "FILL")
	t.free()
	_restore()


func test_modifiers_page_sets_bits() -> void:
	_keep()
	var t := _title(_save())
	Settings.mod_bits = 0
	Settings.two_players = false
	Settings.opponent_i = -1
	t.open_page("modifiers")
	var m: MenuPage = t.pages["modifiers"]
	m.select("rules")
	m.press()
	eq(t.page, "rules", "RULES opens from MODIFIERS")
	var r: MenuPage = t.pages["rules"]
	r.select("lava")
	r.press()
	eq(t.pages["main"].value_of("modifiers"), "LAVA")
	eq(m.value_of("rules"), "LAVA")
	t.back()
	eq(t.page, "modifiers", "back to MODIFIERS")
	eq(m.current_id(), "rules")
	m.select("big_ball")
	m.change(1)
	eq(t.config(false).modifiers, K.MOD_LAVA | K.MOD_BIG_BALL, "the toggles reach the match")
	eq(t.pages["main"].value_of("modifiers"), "2 ON")
	m.change(-1)
	eq(Settings.mod_bits, K.MOD_LAVA, "a second change turns it off")
	t.free()
	_restore()


func test_settings_survive_a_restart() -> void:
	_keep()
	var s := _save()
	var t := _title(s)
	Settings.venue_i = 2
	Settings.difficulty_i = K.DIFFICULTY_HARD
	Settings.camera_i = 3
	Settings.mod_bits = K.MOD_FAST_BALL | K.MOD_WIN_BY_2
	Settings.fullscreen = true
	Settings.integer_scale = false
	Sfx.setting = AudioMap.SOUND_OFF
	t._store_settings()
	s.save_game()
	t.free()
	# a fresh start: everything back to defaults, then loaded
	Settings.venue_i = 0
	Settings.difficulty_i = 0
	Settings.camera_i = 0
	Settings.mod_bits = 0
	Settings.fullscreen = false
	Settings.integer_scale = true
	Sfx.setting = 0
	var s2 := SaveGame.new()
	s2.dir = DIR
	s2.load_game()
	var t2 := _title(s2)
	eq([Settings.venue_i, Settings.difficulty_i, Settings.camera_i, Settings.mod_bits],
		[2, K.DIFFICULTY_HARD, 3, K.MOD_FAST_BALL | K.MOD_WIN_BY_2], "match settings")
	check(Settings.fullscreen and not Settings.integer_scale, "window options")
	eq(Sfx.setting, AudioMap.SOUND_OFF, "sound")
	t2.free()
	_restore()


## A save from before the MODIFIERS page keeps its preset as bits.
func test_old_mods_preset_becomes_bits() -> void:
	_keep()
	var s := _save()
	s.data["settings"].erase("mod_bits")
	s.data["settings"]["mods"] = 5                 # ALL FOUR
	var t := _title(s)
	eq(Settings.mod_bits, 15)
	t.free()
	s.data["settings"]["mod_bits"] = -1
	s.data["settings"]["mods"] = 4                 # LAVA
	t = _title(s)
	eq(Settings.mod_bits, K.MOD_LAVA, "-1 (the default) also reads the preset")
	t.free()
	_restore()


func _paused_view(cfg: SimTypes.MatchConfig) -> MatchView:
	var view := MatchView.new()
	runner.root.add_child(view)
	view.setup(cfg, "park", false)
	view.sim.paused = 1
	view._update_visuals()
	return view


func _pick(view: MatchView, row: String) -> bool:
	view._hud.pause_menu.select(row)
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	var done := view.input.pause_input(it)
	check(it.hit_pressed == 0, "a menu press is never a swing")
	return done


func test_pause_menu_rows() -> void:
	var view := _paused_view(SimTypes.MatchConfig.singles())
	var ids := view._hud.pause_menu.rows.map(func(r): return r["id"])
	eq(ids, ["resume", "restart", "tune", "menu"], "TUNE: the tuning panel (ADR-074)")
	check(view._hud._paused.visible, "it shows while paused")
	view.free()
	var practice := _paused_view(SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0))
	ids = practice._hud.pause_menu.rows.map(func(r): return r["id"])
	eq(ids, ["resume", "tune", "menu"], "practice has no RESTART")
	practice.free()


func test_pause_menu_actions() -> void:
	var view := _paused_view(SimTypes.MatchConfig.singles())
	var it := SimTypes.Intent.new()
	view._hud.pause_menu.select("resume")
	it.hit_pressed = 1
	check(not view.input.pause_input(it), "RESUME lets the sim step")
	eq(it.pause_pressed, 1, "...with Start, so the sim unpauses itself")
	view.sim.step([it, null, null, null])
	eq(view.sim.paused, 0, "resumed")
	view.sim.team_score = [3, 2]
	view.sim.paused = 1
	check(_pick(view, "restart"), "RESTART ends the frame")
	eq(view.sim.team_score, [0, 0], "RESTART starts over")
	eq(view.sim.paused, 0)
	check(view.input_lock > 0, "and swallows the press (no serve)")
	var left := [false]
	view.finished.connect(func(to_title: bool): left[0] = to_title)
	view.sim.paused = 1
	check(_pick(view, "menu"), "MAIN MENU ends the frame")
	check(left[0], "MAIN MENU leaves for the title")
	view.free()
