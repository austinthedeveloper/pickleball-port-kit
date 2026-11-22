## End-to-end touch smoke (port ADR-118): boot the real main scene and
## drive it with fingers only, real InputEventScreenTouch through the
## event queue (Godot makes the first finger a mouse, as on a phone), on
## Player Select and ONLINE's room keypad. Exits non-zero on failure.
##   godot --headless --path game -s res://tests/e2e_touch.gd
extends SceneTree

var _main: Node
var _step := 0
var _t := 0
var _fails := 0
var _want := 0


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	SaveGame.default_dir = "user://e2e_touch_%s/" % ProjectSettings.globalize_path("res://").md5_text().left(8)
	TestSuite.wipe_saves(SaveGame.default_dir)
	TestSuite.wipe_replays(SaveGame.default_dir + "replays/")
	var controls = load("res://game_ui/controls.gd").new()
	controls.name = "Controls"
	root.add_child(controls)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	physics_frame.connect(_tick)


func _touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = at
	e.pressed = pressed
	Input.parse_input_event(e)


## A tap at `at` spread over the frames: down at `t0`, up two frames on.
func _tap_at(at: Vector2, t0: int) -> void:
	if _t == t0:
		_touch(at, true)
	if _t == t0 + 2:
		_touch(at, false)


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _screen() -> Node:
	return _main.get_child(_main.get_child_count() - 1)


func _title() -> TitleScreen:
	return _screen() as TitleScreen


func _next(step: int) -> void:
	_step = step
	_t = 0


## Where a tappable prompt for `action` is on the screen.
func _prompt(bar: PromptBar, action: String) -> Vector2:
	for t in bar.tap_targets():
		if t[1] == action:
			return (t[0] as Rect2).get_center()
	return Vector2(-1, -1)


func _row_point(page: MenuPage, id: String) -> Vector2:
	var want := page.rows.map(func(r): return r["id"]).find(id)
	var inv := page.get_global_transform().affine_inverse()
	for y in range(0, 540, 2):
		var p := Vector2(480, y)
		if page.row_at(inv * p) == want:
			return p + Vector2(0, 6)
	return Vector2(-1, -1)


func _tick() -> void:
	_t += 1
	match _step:
		0:
			if _t == 1:
				Settings.touch_pad = TouchPad.ON
			if _t == 20 and _screen() is TitleScreen:
				_touch(Vector2(480, 300), true)      # a finger: the device is touch now
			if _t == 22:
				_touch(Vector2(480, 300), false)
			if _t == 40:
				_expect(GameControls.last_device == GameControls.TOUCH, "a finger makes the device touch")
				_title().open_select(false)
				_next(1)
		1:
			# Player Select by tap: a shirt, a paddle, then BACK
			var s := _title().select_screen
			var sel := _title().select
			if _t == 10:
				_expect(s.is_visible_in_tree(), "Player Select is up")
				_want = (int(sel.choice[0]["palette"]) + 2) % PlayerSelect.PAL_COUNT
			_tap_at(SelectScreen.thumb_rect(_want).get_center(), 20)
			if _t == 40:
				_expect(int(sel.choice[0]["palette"]) == _want, "a tap on a shirt picks it")
				_want = (int(sel.choice[0]["paddle"]) + 1) % Paddles.NAMES.size()
			_tap_at(s._paddle_rect(_want).get_center(), 50)
			if _t == 70:
				_expect(int(sel.choice[0]["paddle"]) == _want, "a tap on a paddle picks it")
			_tap_at(_prompt(s._prompts, "soft"), 80)
			if _t == 110:
				_expect(_title().page == "setup", "a tap on BACK goes back")
				_main.show_online()
				_next(2)
		2:
			# ONLINE: ROOM opens the keypad; four letters and BACK, by tap
			var o := _screen() as OnlineScreen
			if o == null:
				if _t > 60:
					_expect(false, "ONLINE opened")
					_next(9)
				return
			if _t == 30:
				_want = 1
			_tap_at(_row_point(o.page, "address"), 30)
			if _t == 50:
				_expect(o.grid_open and o.keys.visible, "ROOM opens the keypad")
				_expect(not o.grid.visible, "not the small grid")
			var code := "BXKM"
			for i in code.length():
				_tap_at(OnlineScreen.key_rect(code[i]).get_center(), 60 + i * 10)
			if _t == 110:
				_expect(o.room == "BXKM", "four taps type the room (%s)" % o.room)
			_tap_at(OnlineScreen.key_rect("DELETE").get_center(), 120)
			if _t == 135:
				_expect(o.room == "BXK", "DELETE takes one back")
			# a finger that slides off a key types nothing
			if _t == 140:
				_touch(OnlineScreen.key_rect("M").get_center(), true)
			if _t == 142:
				_touch(OnlineScreen.key_rect("Z").get_center() + Vector2(0, 200), false)
			if _t == 150:
				_expect(o.room == "BXK", "sliding off a key types nothing")
			_tap_at(OnlineScreen.key_rect("BACK").get_center(), 160)
			if _t == 175:
				_expect(not o.grid_open and o.page.visible, "BACK closes the keypad")
				_next(9)
		9:
			print("\n%s" % ("e2e touch passed" if _fails == 0 else "e2e touch FAILED (%d)" % _fails))
			quit(1 if _fails else 0)
