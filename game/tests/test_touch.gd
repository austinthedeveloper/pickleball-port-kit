## PORT-81: the on-screen pad for touch screens (TouchPad, port ADR-086).
## Synthetic fingers go to the pad; the actions it sends are caught here
## (a press through Input would stay "just pressed" for every later suite:
## the runner has one frame) and checked against the input map and the
## latch. The e2e sends real touches through Input's queue.
extends TestSuite

var _pad: TouchPad
var _sent := []                   ## the pad's InputEventActions
var _state := {}                  ## action -> pressed, from them


## A shown pad of the test's own (the runner has no frames: its fingers go
## straight to the pad, and the actions it sends through Input). The e2e
## sends real touches through the event queue.
func _new_pad() -> TouchPad:
	_sent.clear()
	_state.clear()
	TouchPad.sink = func(e: InputEventAction):
		_sent.append(e)
		_state[e.action] = e.pressed
	_pad = TouchPad.new()
	_pad._ready()
	_pad.visible = true
	return _pad


## Pressed now, by the actions the pad sent.
func _on(action: String) -> bool:
	return _state.get(action, false)


func _done(pad: TouchPad) -> void:
	pad.release_all()
	GameControls.clear_latch()
	TouchPad.sink = Callable()
	pad.free()


func _touch(i: int, at: Vector2, pressed := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = at
	e.pressed = pressed
	_pad.take_touch(e)


func _drag(i: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = at
	_pad.take_touch(e)


func test_hidden_on_a_desktop() -> void:
	var kept := Settings.touch_pad
	Settings.touch_pad = TouchPad.AUTO
	check(not TouchPad.wanted(), "no touch screen (headless): no pad on AUTO")
	Settings.touch_pad = TouchPad.ON
	check(TouchPad.wanted(), "ON: shown anyway")
	GameControls.fake_pads = {0: {}}
	check(TouchPad.wanted(), "ON: even with a pad")
	Settings.touch_pad = TouchPad.OFF
	GameControls.fake_pads = {}
	check(not TouchPad.wanted(), "OFF: never")
	Settings.touch_pad = kept
	var pad: TouchPad = runner.root.get_node("Controls/TouchPad")
	check(pad != null, "the input node has its pad")


func test_each_button_fires_its_action() -> void:
	var pad := _new_pad()
	for a in ["hit", "drive", "soft", "slice", "special", "start", "short"]:
		var at: Vector2 = TouchPad.face_centre(a) if TouchPad.FACES.has(a) else TouchPad.PILLS[a].get_center()
		eq(pad.target_at(at), a, "%s is under its button" % a)
		_touch(0, at)
		check(_on(a), "%s held while the finger is down" % a)
		eq(pad.held(), [a], "%s alone" % a)
		_touch(0, at, false)
		check(not _on(a), "%s let go with the finger" % a)
	eq(pad.target_at(Vector2(480, 270)), "", "mid-screen is nobody's")
	_done(pad)


func test_a_tap_reaches_the_intent() -> void:
	var pad := _new_pad()
	GameControls.clear_latch()
	_touch(0, TouchPad.face_centre("drive"))
	_touch(0, TouchPad.face_centre("drive"), false)
	eq(_sent.map(func(e): return [String(e.action), e.pressed]), [["drive", true], ["drive", false]],
		"a tap: a press and a release")
	check(_sent[0].is_action_pressed("drive") and _sent[1].is_action_released("drive"),
		"the input map reads them as DRIVE")
	var controls: GameControls = runner.root.get_node("Controls")
	for e in _sent:
		controls._input(e)                 # as Input delivers them
	var it := GameControls.read_intent()
	eq([it.hit_pressed, it.shot], [1, K.SHOT_DRIVE], "a tap shorter than a tick is still a drive")
	_done(pad)


func test_dpad_eight_ways() -> void:
	var pad := _new_pad()
	var D := TouchPad.DPAD
	_touch(2, D + Vector2(40, 0))
	eq(pad.held(), ["move_right"], "right")
	_drag(2, D + Vector2(-40, -40))
	eq(pad.held(), ["move_left", "move_up"], "slid to up-left: a diagonal")
	_drag(2, D + Vector2(-40, -6))
	eq(pad.held(), ["move_left"], "near the axis is the axis")
	_drag(2, D + Vector2(3, 4))
	eq(pad.held(), [], "the dead centre is still")
	_drag(2, D + Vector2(200, 30))
	eq(pad.held(), ["move_right"], "a thumb that wanders off keeps steering")
	check(_on("move_right") and not _on("move_left"), "sent as a press and a release")
	_touch(2, D, false)
	eq(pad.held(), [], "lifted")
	_done(pad)


func test_two_thumbs_and_a_slide() -> void:
	var pad := _new_pad()
	_touch(0, TouchPad.DPAD + Vector2(0, 40))
	_touch(1, TouchPad.face_centre("hit"))
	eq(pad.held(), ["hit", "move_down"], "D-pad and B together")
	_drag(1, TouchPad.face_centre("drive"))
	eq(pad.held(), ["drive", "move_down"], "slid from B onto A")
	check(not _on("hit") and _on("drive"), "B up, A down")
	_drag(1, TouchPad.DPAD)
	eq(pad.held(), ["drive", "move_down"], "a button finger never takes the D-pad")
	_touch(1, Vector2.ZERO, false)
	_touch(0, Vector2.ZERO, false)
	eq(pad.held(), [], "both up")
	_touch(3, Vector2(480, 270))
	eq(pad.held(), [], "a touch off the pad holds nothing")
	_touch(3, Vector2(480, 270), false)
	_done(pad)


## The first finger's mouse (Godot's emulation) is swallowed on a button,
## so a tap on B doesn't click a menu row under it; elsewhere it's a tap.
func test_menus_get_taps_off_the_buttons() -> void:
	var pad := _new_pad()
	var m := InputEventMouseButton.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	m.pressed = true
	m.position = TouchPad.face_centre("hit")
	check(pad.swallows(m), "a finger's click on B isn't the menu's")
	m.position = Vector2(480, 270)
	check(not pad.swallows(m), "one mid-screen is")
	_touch(0, TouchPad.DPAD)
	var mo := InputEventMouseMotion.new()
	mo.device = InputEvent.DEVICE_ID_EMULATION
	mo.position = Vector2(480, 270)
	check(pad.swallows(mo), "the D-pad's finger wandering off doesn't hover the menu")
	var real := InputEventMouseButton.new()
	real.pressed = true
	real.position = TouchPad.face_centre("hit")
	check(not pad.swallows(real), "a real mouse is never swallowed")
	_done(pad)


## A panel under a part steps that part aside: it hides, takes no touch
## (the tap is the menu's), and lets go of a finger on it.
func test_parts_step_aside_from_panels() -> void:
	var pad := _new_pad()
	_touch(1, TouchPad.face_centre("hit"))
	eq(pad.held(), ["hit"], "B down")
	pad.avoid([Rect2(590, 150, 350, 312)])     # COURT's panel, over the faces
	eq(pad.held(), [], "B let go as the faces stepped aside")
	eq(pad.target_at(TouchPad.face_centre("hit")), "", "a touch there is the menu's")
	check(not pad._letters["hit"].visible and pad._letters["start"].visible, "only the faces hid")
	eq(pad.target_at(TouchPad.DPAD), "dpad", "the D-pad stays")
	pad.avoid([])
	eq(pad.target_at(TouchPad.face_centre("hit")), "hit", "back when the panel goes")
	_touch(1, Vector2.ZERO, false)
	_done(pad)


func test_touch_is_a_device() -> void:
	var kept := [GameControls.last_device, GameControls.last_pad]
	var t := InputEventScreenTouch.new()
	t.pressed = true
	GameControls.note_device(t)
	eq(GameControls.last_device, GameControls.TOUCH, "a finger")
	GameControls.note_device(InputEventMouseButton.new())
	eq(GameControls.last_device, GameControls.KEYBOARD, "a real mouse is the keyboard's")
	var m := InputEventMouseButton.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	GameControls.note_device(m)
	eq(GameControls.last_device, GameControls.TOUCH, "the mouse a finger makes is touch")
	var T := GameControls.TOUCH
	eq([Prompts.label("hit", T), Prompts.label("drive", T), Prompts.label("soft", T),
		Prompts.label("slice", T), Prompts.label("short", T), Prompts.label("special", T),
		Prompts.label("start", T), Prompts.label("back", T), Prompts.label("dpad", T)],
		["B", "A", "Y", "X", "L", "R", "START", "A", "D-PAD"], "the prompts name the pad's buttons")
	GameControls.last_device = kept[0]
	GameControls.last_pad = kept[1]
	GameControls.device_serial += 1


func test_setting_is_saved() -> void:
	var kept := Settings.touch_pad
	var s := fresh_save("user://test_touch/")
	eq(int(s.data["settings"]["touch_pad"]), TouchPad.AUTO, "AUTO by default")
	Settings.touch_pad = TouchPad.OFF
	Settings.store_to(s)
	Settings.touch_pad = TouchPad.ON
	Settings.load_from(s)
	eq(Settings.touch_pad, TouchPad.OFF, "kept")
	Settings.touch_pad = kept


func _finger(p: MenuPage, row: int, pressed: bool, x := -1.0) -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(p.area.get_center().x if x < 0 else x, p._row_y(row) + 6)
	p._gui_input(e)


## Port ADR-117: a finger shows the row it lands on and acts on lifting
## there; one that slides off lets go of nothing; the left arrow steps back.
func test_a_finger_acts_on_lifting() -> void:
	var log := []
	var p := MenuPage.new().setup("t", "TEST", [
		{"id": "a", "label": "A", "press": func(): log.append("a")},
		{"id": "b", "label": "B", "value": func(): return "VALUE", "change": func(d): log.append("b %d" % d)},
		{"id": "c", "label": "C", "press": func(): log.append("c")},
	])
	_finger(p, 2, true)
	eq([p.current_id(), log], ["c", []], "down shows the row, does nothing yet")
	_finger(p, 2, false)
	eq(log, ["c"], "lifting on it presses")
	_finger(p, 0, true)
	_finger(p, 2, false)
	eq(log, ["c"], "lifting on another row presses nothing")
	_finger(p, 1, true)
	_finger(p, 1, false)
	eq(log, ["c", "b 1"], "a value row steps on")
	var v: BitmapText = p._values[1]
	var left := v.position.x - BitmapText.measure("small", v.text) - 10
	_finger(p, 1, true, left)
	_finger(p, 1, false, left)
	eq(log, ["c", "b 1", "b -1"], "its left arrow steps back")
	p.free()


## Port ADR-117: rows grow into a page's spare room on a touch screen, and
## down to the floor its screen allows, never past TOUCH_ROW_H.
func test_touch_rows_fit_their_room() -> void:
	var rows := [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}]
	var tight := Rect2(300, 100, 360, 18 + 2 * MenuPage.ROW_H + 12)
	MenuPage.touch_rows = true
	var a := MenuPage.new().setup("t", "", rows.duplicate(), tight)
	eq(a.row_pitch(), MenuPage.ROW_H, "no room: rows as they were")
	var b := MenuPage.new().setup("t", "", rows.duplicate(), tight, "", tight.end.y + 100)
	eq(b.row_pitch(), MenuPage.TOUCH_ROW_H, "room below: as tall as a finger wants, no taller")
	eq(b.area.size.y, tight.size.y + 2 * (MenuPage.TOUCH_ROW_H - MenuPage.ROW_H), "the panel grew to fit")
	eq(b.row_at(Vector2(480, b._row_y(1) + 6)), 1, "a tap finds the taller row")
	MenuPage.touch_rows = false
	var c := MenuPage.new().setup("t", "", rows.duplicate(), tight, "", tight.end.y + 100)
	eq(c.row_pitch(), MenuPage.ROW_H, "not a touch screen: rows as they were")
	for p in [a, b, c]:
		p.free()


## Port ADR-117: a menu's prompts are buttons for a finger (BACK presses
## Y), so a menu works though the pad's own buttons stepped aside.
func test_menu_prompts_take_taps() -> void:
	var pad := _new_pad()
	runner.root.add_child(pad)
	var p := MenuPage.new().setup("t", "TEST", [{"id": "a", "label": "A"}], Rect2(300, 172, 360, 200),
		[["hit", "SELECT"], ["back", "BACK"]])
	runner.root.add_child(p)
	var targets := p.prompts.tap_targets()
	eq(targets.map(func(t): return t[1]), ["hit", "soft"], "SELECT is B, BACK is Y")
	var back: Rect2 = targets[1][0]
	eq(pad.target_at(back.get_center()), "soft", "the pad presses BACK's action")
	_touch(0, back.get_center())
	eq(pad.held(), ["soft"], "held while the finger's on it")
	_touch(0, back.get_center(), false)
	eq(pad.held(), [], "let go")
	p.visible = false
	eq(pad.target_at(back.get_center()), "", "a hidden page's prompts take nothing")
	runner.root.remove_child(p)
	p.free()
	runner.root.remove_child(pad)
	_done(pad)


## Port ADR-117: Player Select by tap: a thumbnail picks its colour, the
## player the other body, the paddle panel's halves step it.
func test_player_select_by_tap() -> void:
	var sel := PlayerSelect.new()
	sel.begin(K.MODE_SINGLES, 1)
	var s := SelectScreen.new().setup(sel)
	var c: Dictionary = sel.current_choice()
	var want := (int(c["palette"]) + 2) % PlayerSelect.PAL_COUNT
	for b in s.presses_for(SelectScreen.thumb_rect(want).get_center()):
		sel.input(int(b))
	eq([sel.row, int(sel.current_choice()["palette"])], [PlayerSelect.ROW_COLOUR, want], "a thumbnail picks its colour")
	var body := int(sel.current_choice()["variant"])
	for b in s.presses_for(SelectScreen.LEFT.position + Vector2(200, 100)):
		sel.input(int(b))
	eq([sel.row, int(sel.current_choice()["variant"]) != body], [PlayerSelect.ROW_VARIANT, true], "the player: the other body")
	var paddle := int(sel.current_choice()["paddle"])
	for b in s.presses_for(SelectScreen.RIGHT.position + Vector2(SelectScreen.RIGHT.size.x - 30, 300)):
		sel.input(int(b))
	eq([sel.row, int(sel.current_choice()["paddle"])],
		[PlayerSelect.ROW_PADDLE, (paddle + 1) % Paddles.NAMES.size()], "the paddle's right half: the next")
	var last := Paddles.NAMES.size() - 1
	for b in s.presses_for(s._paddle_rect(last).get_center()):
		sel.input(int(b))
	eq(int(sel.current_choice()["paddle"]), last, "a paddle: that one")
	eq(s.presses_for(Vector2(480, 20)), [], "the title: nothing")
	s.free()
