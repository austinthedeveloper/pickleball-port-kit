## End-to-end smoke: boot the real main scene, drive it through the input
## map like a player, and check the flow. Exits non-zero on failure.
##   godot --headless --path game -s res://tests/e2e_input.gd
extends SceneTree

var _main: Node
var _frame := 0
var _step := 0
var _fails := 0
var _held := ""


func _initialize() -> void:
	# one physics tick per frame: input events flush once a frame, so two
	# ticks in one frame could flush a press and its release together
	# (the press lost, the e2e flaky)
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	# a scratch save, so the run never touches the player's; one per
	# checkout, since every checkout shares user:// (KNOWN_ISSUES #42)
	SaveGame.default_dir = "user://e2e_%s/" % ProjectSettings.globalize_path("res://").md5_text().left(8)
	TestSuite.wipe_saves(SaveGame.default_dir)
	TestSuite.wipe_replays(SaveGame.default_dir + "replays/")
	var controls = load("res://game_ui/controls.gd").new()
	controls.name = "Controls"
	root.add_child(controls)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	physics_frame.connect(_tick)       # one tick = one sim step


## Through the event queue, as a real key arrives (flushed before physics).
func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _press(action: String) -> void:
	_send(action, true)
	_held = action


func _release() -> void:
	if _held != "":
		_send(_held, false)
		_held = ""


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _screen() -> Node:
	return _main.get_child(_main.get_child_count() - 1)


var _t := 0                        # frames since the step began


func _next(step: int) -> void:
	_step = step
	_t = 0


func _title() -> TitleScreen:
	return _screen() as TitleScreen


func _tick() -> void:
	_frame += 1
	_t += 1
	_release()
	match _step:
		0:
			# the menu tree: MAIN -> OPTIONS, SOUND one right, Y back
			if _frame == 30:
				_expect(_screen() is TitleScreen, "boots to the title")
				_expect(_title().page == "main", "the title opens on MAIN")
				_title().pages["main"].select("options")
				_press("hit")
			if _frame == 34:
				_expect(_title().page == "options", "B on OPTIONS opens the page")
			if _frame == 46:
				_expect(_title().pages["options"].current_id() == "camera",
					"the opening press was swallowed (the cursor stayed on CAMERA)")
				_press("move_down")
			if _frame == 50:
				_press("move_right")
			if _frame == 54:
				_expect(Sfx.setting == AudioMap.SOUND_NO_CROWD, "Right on SOUND sets NO CROWD")
				_press("soft")
			if _frame == 64:
				_expect(_title().page == "main", "Y goes back to MAIN")
				_expect(_title().pages["main"].current_id() == "options",
					"back lands on the page's row")
			if _frame == 72:
				Settings.quick_doubles = false
				_title().reveal("start")
				_press("hit")              # MATCH SETUP's START: Player Select
			if _frame == 84:
				_expect(_title().page == "select", "START opens Player Select")
			if _frame == 90:
				_press("move_down")        # to the colour row
			if _frame == 94:
				_press("move_right")       # RED
			if _frame == 98:
				_expect(_title().select.choice[0]["palette"] == PlayerSelect.PAL_RED, "Right picks RED")
				_press("hit")              # to the paddle row
			if _frame == 102:
				_press("move_left")        # WOOD
			if _frame == 106:
				_press("hit")              # B on the paddle row confirms
				_next(1)
		1:
			if _t == 16:
				var m0 := _screen() as MatchView
				_expect(m0 != null and m0.sim.config.palette[0] == PlayerSelect.PAL_RED
					and m0.sim.players[0].paddle == Paddles.WOOD, "the choices reach the match")
				_expect(_screen() is MatchView, "B on SINGLES starts a match")
				var m: MatchView = _screen()
				_expect(m.ladder and m.card_frames >= 0, "a ladder match opens on the intro card")
				_expect(m.sim.phase == K.PHASE_SERVE_SETUP and m.sim.phase_timer == 0,
					"the match waits under the card")
			if _t == 64:
				_press("hit")              # close the card
			if _t == 68:
				var m: MatchView = _screen()
				_expect(m.card_frames < 0, "B closes the card")
			if _t == 94:
				var m: MatchView = _screen()
				_expect(m.sim.phase == K.PHASE_SERVE_SETUP, "the match opens on the serve")
				_expect(m.sim.serve_requested == 0, "the closing press didn't serve (ADR-026)")
				_next(2)
		2:
			var m: MatchView = _screen()
			if m.sim.phase_timer >= K.SERVE_READY_FRAMES + 2 and _frame % 2 == 0:
				_press("hit")              # tap B: the classic serve
				_next(3)
		3:
			var m: MatchView = _screen()
			if m.sim.phase == K.PHASE_LIVE:
				_expect(m.sim.ball.last_hitter == 0, "P1's tap served")
				_expect(m.sim.charge_power == K.SERVE_CHARGE_CLASSIC, "a tap is the classic serve")
				_next(4)
			elif _frame > 400:
				_expect(false, "the serve went live")
				_next(9)
		4:
			var m: MatchView = _screen()
			if m.sim.phase == K.PHASE_POINT_RESULT:
				_expect(true, "the rally ended in a point (%s)" % K.fault_word(m.sim.last_fault))
				_press("start")
				_next(5)
			elif _frame > 3000:
				_expect(false, "a point ended")
				_next(9)
		5:
			# (the sim allows a pause anywhere but the match result; checks
			# wait 3 frames, since a press reaches the sim on the next tick)
			var m: MatchView = _screen()
			if _t == 3:
				_expect(m.sim.paused != 0, "Start pauses on a point result too")
				_press("start")            # START resumes
			if _t == 6:
				_expect(m.sim.paused == 0, "Start resumes")
			if m.sim.phase == K.PHASE_SERVE_SETUP and _t > 6:
				_press("start")
				_next(6)
			elif _t > 600:
				_expect(false, "the next serve came")
				_next(9)
		6:
			# the pause menu: Down to RESTART, B
			var m: MatchView = _screen()
			if _t == 3:
				_expect(m.sim.paused != 0, "Start pauses")
				_expect(m._hud.pause_menu.is_visible_in_tree(), "the pause menu shows")
				_expect(m._hud.pause_menu.current_id() == "resume", "it opens on RESUME")
				_press("move_down")
			if _t == 6:
				_expect(m._hud.pause_menu.current_id() == "restart", "Down moves to RESTART")
				_press("hit")
			if _t == 9:
				_expect(m.sim.paused == 0, "RESTART unpauses")
				_expect(m.sim.team_score == [0, 0] and m.sim.phase == K.PHASE_SERVE_SETUP,
					"RESTART starts the match over")
				_expect(m.sim.serve_requested == 0 and not m.sim.charge_charging,
					"the RESTART press didn't serve")
			if _t == 30:
				_press("start")
			if _t == 33:
				_expect(m.sim.paused != 0 and m._hud.pause_menu.current_id() == "resume",
					"a second pause opens on RESUME again")
				_press("move_up")          # wraps to MAIN MENU
			if _t == 36:
				_expect(m._hud.pause_menu.current_id() == "menu", "Up wraps to MAIN MENU")
				_press("hit")
				_next(7)
		7:
			if _t == 16:
				_expect(_screen() is TitleScreen, "MAIN MENU returns to the title")
				_expect(_title().page == "setup" and _title().pages["setup"].current_id() == "start",
					"the title comes back to MATCH SETUP, on START")
				var s := SaveGame.new()
				s.load_game()
				_expect(int(s.data["settings"]["sound"]) == AudioMap.SOUND_NO_CROWD,
					"the SOUND setting was saved (survives a restart)")
				_next(9)
		9:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e FAILED (%d)" % _fails))
			quit(1 if _fails else 0)
