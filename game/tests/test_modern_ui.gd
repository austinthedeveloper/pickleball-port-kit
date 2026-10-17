## PORT-11: modern menus. Prompts follow the device and the bindings;
## the mouse drives pages through the same calls as the pad; pages slide
## in and swallow input while they do; screens fade.
extends TestSuite


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func test_device_switch() -> void:
	var kept := [GameControls.last_device, GameControls.last_pad]
	GameControls.note_device(_key(KEY_SPACE))
	eq(GameControls.last_device, GameControls.KEYBOARD)
	var serial := GameControls.device_serial
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	b.device = 1
	GameControls.note_device(b)
	eq([GameControls.last_device, GameControls.last_pad], [GameControls.PAD, 1], "a pad button: that pad")
	eq(GameControls.device_serial, serial + 1, "the change is counted")
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.2
	drift.device = 1
	GameControls.note_device(drift)
	eq(GameControls.device_serial, serial + 1, "stick drift doesn't count")
	var click := InputEventMouseButton.new()
	GameControls.note_device(click)
	eq(GameControls.last_device, GameControls.KEYBOARD, "the mouse counts as the keyboard")
	GameControls.last_device = kept[0]
	GameControls.last_pad = kept[1]


func test_prompts_follow_the_device() -> void:
	var KB := GameControls.KEYBOARD
	var PAD := GameControls.PAD
	eq(Prompts.label("hit", KB), "SPACE", "B is Space")
	eq(Prompts.label("drive", KB), "K")
	eq(Prompts.label("soft", KB), "L")
	eq(Prompts.label("start", KB), "ENTER")
	eq(Prompts.label("dpad", KB), "ARROWS")
	# any pad shows the Xbox layout (PORT-15)
	eq(Prompts.label("hit", PAD), "A", "south is A")
	eq(Prompts.label("drive", PAD), "B")
	eq(Prompts.label("soft", PAD), "X")
	eq(Prompts.label("start", PAD), "MENU", "Start is the Menu button")
	eq(Prompts.label("dpad", PAD), "D-PAD")
	eq(Prompts.label("move_up", PAD), "D-UP")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_BACK)), "VIEW")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_LEFT_SHOULDER)), "LB")
	eq(Prompts.button_glyph(JOY_BUTTON_Y)["text"], "Y")


func test_prompt_bar_redraws_on_a_device_change() -> void:
	var kept := GameControls.last_device
	GameControls.last_device = GameControls.KEYBOARD
	GameControls.device_serial += 1
	var bar := PromptBar.new().setup([["hit", "SELECT"]], Vector2(480, 500))
	var texts := func() -> Array:
		return bar._texts.map(func(t): return t.text)
	check("SPACE" in texts.call(), "a key cap on the keyboard")
	GameControls.last_device = GameControls.PAD
	GameControls.device_serial += 1
	bar._process(0.0)
	check(not "SPACE" in texts.call() and "SELECT" in texts.call(), "a face button on a pad")
	bar.free()
	GameControls.last_device = kept
	GameControls.device_serial += 1


func _page() -> Array:
	var log := []
	var p := MenuPage.new().setup("t", "TEST", [
		{"id": "a", "label": "A", "press": func(): log.append("press a")},
		{"id": "b", "label": "B", "value": func(): return "V", "change": func(d): log.append("change %d" % d)},
		{"id": "c", "label": "C"},
	])
	return [p, log]


func _mouse(p: MenuPage, row: int, button := -1) -> void:
	var at := Vector2(p.area.get_center().x, p._row_y(row) + 6)
	var e: InputEvent
	if button < 0:
		e = InputEventMouseMotion.new()
	else:
		e = InputEventMouseButton.new()
		e.button_index = button
		e.pressed = true
	e.position = at
	p._gui_input(e)


func test_mouse_drives_the_page() -> void:
	var made := _page()
	var p: MenuPage = made[0]
	var log: Array = made[1]
	var seen := []
	p.hovered.connect(func(id): seen.append("hover " + id))
	p.pressed.connect(func(id): seen.append("pressed " + id))
	p.back_requested.connect(func(): seen.append("back"))
	eq(p.row_at(Vector2(10, p._row_y(1))), -1, "outside the panel: no row")
	_mouse(p, 2)
	eq(p.current_id(), "c", "hover selects")
	_mouse(p, 0, MOUSE_BUTTON_LEFT)
	eq(log, ["press a"], "a click presses")
	_mouse(p, 1, MOUSE_BUTTON_WHEEL_UP)
	_mouse(p, 1, MOUSE_BUTTON_WHEEL_DOWN)
	eq(log, ["press a", "change 1", "change -1"], "the wheel changes")
	_mouse(p, 1, MOUSE_BUTTON_RIGHT)
	eq(seen, ["hover c", "pressed a", "back"], "the owner hears hover, press, back")
	p.free()


func test_pages_slide_in_and_swallow_input() -> void:
	var made := _page()
	var p: MenuPage = made[0]
	var log: Array = made[1]
	p.appear(1)
	check(p.animating() and p.position.x > 0.0 and p.modulate.a < 0.5, "starts off to the right, faint")
	_mouse(p, 0, MOUSE_BUTTON_LEFT)
	eq(log, [], "a click during the slide is swallowed")
	for f in MenuPage.TRANSITION:
		p._process(1.0 / 60.0)
	check(not p.animating() and p.position.x == 0.0 and p.modulate.a == 1.0, "settled")
	p.appear(-1)
	check(p.position.x < 0.0, "back comes from the left")
	p.settle()
	# the highlight bar eases to a new row instead of jumping
	var from := p._bar_y
	p.move(1)
	p._process(1.0 / 60.0)
	check(p._bar_y > from and p._bar_y < p._row_y(1), "the bar eases")
	for f in 20:
		p._process(1.0 / 60.0)
	eq(p._bar_y, p._row_y(1), "and arrives")
	p.change(1)
	p._process(1.0 / 60.0)
	check(p._values[1].scale.x > 1.0, "a changed value pops")
	for f in MenuPage.POP_FRAMES:
		p._process(1.0 / 60.0)
	eq(p._values[1].scale.x, 1.0, "and settles")
	p.free()
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	t.open_page("options")
	check(t._lock >= MenuPage.TRANSITION and t.pages["options"].animating(),
		"the title waits out the slide (rule 9)")
	t.free()


func test_screens_fade() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = "user://test_fade/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.default_dir))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	var title: Node = main._screen
	check(title is TitleScreen, "boots to the title")
	var next := Node2D.new()
	main._swap(next)
	check(main.fading() and title.process_mode == Node.PROCESS_MODE_DISABLED,
		"the old screen stops while it fades out")
	check(main._screen == title, "and stays up until black")
	for f in main.FADE_OUT:
		main._physics_process(1.0 / 60.0)
	check(main._screen == next and main._fader.color.a == 1.0, "swapped at black")
	for f in main.FADE_IN:
		main._physics_process(1.0 / 60.0)
	check(not main.fading() and main._fader.color.a == 0.0, "faded in")
	main.free()
	SaveGame.default_dir = kept
