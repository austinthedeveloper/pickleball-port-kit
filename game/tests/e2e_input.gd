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
	# a scratch save, so the run never touches the player's
	SaveGame.default_dir = "user://e2e/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.default_dir))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.default_dir + f))
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


func _tick() -> void:
	_frame += 1
	_release()
	match _step:
		0:
			if _frame == 30:
				_expect(_screen() is TitleScreen, "boots to the title")
				TitleScreen.cursor = 0
				_press("hit")              # SINGLES
				_step = 1
		1:
			if _frame == 36:
				_expect(_screen() is MatchView, "B on SINGLES starts a match")
				var m: MatchView = _screen()
				_expect(m.ladder and m.card_frames >= 0, "a ladder match opens on the intro card")
				_expect(m.sim.phase == K.PHASE_SERVE_SETUP and m.sim.phase_timer == 0,
					"the match waits under the card")
			if _frame == 80:
				_press("hit")              # close the card
			if _frame == 84:
				var m: MatchView = _screen()
				_expect(m.card_frames < 0, "B closes the card")
			if _frame == 110:
				var m: MatchView = _screen()
				_expect(m.sim.phase == K.PHASE_SERVE_SETUP, "the match opens on the serve")
				_expect(m.sim.serve_requested == 0, "the closing press didn't serve (ADR-026)")
				_step = 2
		2:
			var m: MatchView = _screen()
			if m.sim.phase_timer >= K.SERVE_READY_FRAMES + 2 and _frame % 2 == 0:
				_press("hit")              # tap B: the classic serve
				_step = 3
		3:
			var m: MatchView = _screen()
			if m.sim.phase == K.PHASE_LIVE:
				_expect(m.sim.ball.last_hitter == 0, "P1's tap served")
				_expect(m.sim.charge_power == K.SERVE_CHARGE_CLASSIC, "a tap is the classic serve")
				_step = 4
			elif _frame > 400:
				_expect(false, "the serve went live")
				_step = 5
		4:
			var m: MatchView = _screen()
			if m.sim.phase == K.PHASE_POINT_RESULT:
				_expect(true, "the rally ended in a point (%s)" % K.fault_word(m.sim.last_fault))
				_press("start")
				_step = 6
			elif _frame > 3000:
				_expect(false, "a point ended")
				_step = 5
		6:
			var m: MatchView = _screen()
			_expect(m.sim.paused == 0, "Start on a point result doesn't pause (only in play)")
			_step = 5
		5:
			print("\n%s" % ("e2e passed" if _fails == 0 else "e2e FAILED (%d)" % _fails))
			quit(1 if _fails else 0)
