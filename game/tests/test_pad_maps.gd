## Port ADR-082: L is SHORT and R SPECIAL (the triggers the same); a
## generic pad (a SNES USB pad SDL doesn't know) mapped button by button
## from its raw events, its map saved per GUID and given to Input; the
## card at startup recommending a controller.
extends TestSuite

const DEV := 7
const GUID := "03000000790000001100000000000000"


func _button(b: int, pressed := true, dev := DEV) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = pressed
	return e


func _axis(axis: int, v: float, dev := DEV) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = axis
	e.axis_value = v
	return e


## A DragonRise-style SNES USB pad: the D-pad on axes 0 and 1, X Y as
## buttons 0 and 3, A B as 1 and 2, L R 4 and 5, START 9. Each step's
## press and release, in MAP BUTTONS' order.
const SNES_USB := [[[1, -1.0], [1, 0.0]], [[1, 1.0], [1, 0.0]], [[0, -1.0], [0, 0.0]],
	[[0, 1.0], [0, 0.0]], [2], [1], [3], [0], [4], [5], [9]]


func _answer(m: PadMapper, step: Array) -> Array:
	var out := []
	if step.size() == 1:
		out.append(m.feed(_button(step[0])))
		out.append(m.feed(_button(step[0], false)))
	else:
		for ev in step:
			out.append(m.feed(_axis(ev[0], ev[1])))
	return out


func _cleanup() -> void:
	PadMaps.clear(GUID)
	PadMaps.maps = {}
	GameControls.fake_pads = {}


func _triggers(action: String) -> Array:
	var out := []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			out.append(e.axis)
	return out


func test_shoulders_and_triggers() -> void:
	Bindings.reset()
	eq(Bindings.current["short"]["pad"], JOY_BUTTON_LEFT_SHOULDER, "SHORT is L")
	eq(Bindings.current["special"]["pad"], JOY_BUTTON_RIGHT_SHOULDER, "SPECIAL is R")
	eq(Prompts.label("short", GameControls.PAD), Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_LEFT_SHOULDER)))
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_RIGHT_SHOULDER, Prompts.SNES)), "R")
	eq(_triggers("short"), [JOY_AXIS_TRIGGER_LEFT], "the left trigger mirrors L")
	eq(_triggers("special"), [JOY_AXIS_TRIGGER_RIGHT], "the right trigger mirrors R")
	Bindings.rebind_pad("short", JOY_BUTTON_Y)
	eq(_triggers("short"), [JOY_AXIS_TRIGGER_LEFT], "a rebound SHORT keeps its trigger")
	Bindings.reset()


## A save from before (SPECIAL with no button, "-1"; SHORT on LB meaning
## either shoulder) loads with R on SPECIAL.
func test_old_bindings_load() -> void:
	var s := SaveGame.new()
	s.data = SaveGame.defaults()
	var old := Bindings.defaults()
	old["special"]["pad"] = -1
	old["short"]["pad"] = JOY_BUTTON_LEFT_SHOULDER
	old["soft"]["pad"] = JOY_BUTTON_Y
	old["slice"]["pad"] = JOY_BUTTON_X
	s.data["settings"]["bindings"] = old
	s.data["settings"].erase("pad_maps")
	s.data["settings"].erase("pad_notice")
	Settings.load_from(s)
	eq(Bindings.current["special"]["pad"], JOY_BUTTON_RIGHT_SHOULDER, "SPECIAL gets R")
	eq(Bindings.current["short"]["pad"], JOY_BUTTON_LEFT_SHOULDER, "SHORT keeps L")
	eq([Bindings.current["soft"]["pad"], Bindings.current["slice"]["pad"]], [JOY_BUTTON_Y, JOY_BUTTON_X],
		"other choices stay")
	check(Settings.pad_notice and PadMaps.maps.is_empty(), "the new keys fill with their defaults")
	Bindings.reset()


func test_map_a_generic_pad() -> void:
	_cleanup()
	var m := PadMapper.new()
	m.begin(DEV, GUID, "USB Gamepad, Inc.")
	eq(m.feed(_button(2, true, DEV + 1)), PadMapper.IGNORED, "another pad's press isn't an answer")
	for i in SNES_USB.size():
		var got := _answer(m, SNES_USB[i])
		check(PadMapper.NEXT in got, "step %d (%s) answered" % [i, PadMapper.STEPS[i][0]])
		if i == 4:
			eq(m.feed(_button(2)), PadMapper.IGNORED, "an input already given isn't a second answer")
	check(m.done() and not m.finishing() and PadMaps.maps.has(GUID), "START let go of: stored")
	var map: Dictionary = PadMaps.maps[GUID]["map"]
	eq([map["dpup"], map["dpdown"], map["dpleft"], map["dpright"]], ["-a1", "+a1", "-a0", "+a0"],
		"a D-pad on axes")
	eq([map["a"], map["b"], map["x"], map["y"], map["leftshoulder"], map["rightshoulder"], map["start"]],
		["b2", "b1", "b3", "b0", "b4", "b5", "b9"], "each action's default button")
	var s: String = PadMaps.applied[0]
	check(s.begins_with(GUID + ",USB GAMEPAD  INC.,") or s.begins_with(GUID + ",USB GAMEPAD INC.,"),
		"given to Input under its GUID, a name without commas: " + s)
	check("dpup:-a1" in s and "start:b9" in s and not "leftx" in s, "the D-pad's axes aren't the stick too")
	# what the mapped pad sends, through P1's input map and a pad's own reading
	var expect := {"move_up": [_axis(1, -1.0)], "move_down": [_axis(1, 1.0)], "move_left": [_axis(0, -1.0)],
		"move_right": [_axis(0, 1.0)], "hit": [_button(2)], "drive": [_button(1)], "soft": [_button(3)],
		"slice": [_button(0)], "short": [_button(4)], "special": [_button(5)], "start": [_button(9)]}
	for action in expect:
		var out := PadMaps.translate(map, expect[action][0]).filter(func(e): return e.pressed)
		eq(out.size(), 1, "%s: one standard press" % action)
		check(InputMap.event_is_action(out[0], action), "%s: the raw input drives %s" % [action, action])
	GameControls.fake_pads = {DEV: {"buttons": []}}
	GameControls.read_pad_intent(DEV, 0)
	GameControls.fake_pads[DEV]["buttons"] = _held(map, [_axis(1, -1.0), _button(4), _button(2)])
	var it := GameControls.read_pad_intent(DEV, 0)
	eq([it.move_y, it.aim_x, it.shot, it.hit_pressed], [-1, -1, K.SHOT_STANDARD, 1],
		"2P's reading: up, SHORT (L) and HIT (SNES B)")
	GameControls.fake_pads[DEV]["buttons"] = []
	GameControls.read_pad_intent(DEV, 0)
	GameControls.fake_pads[DEV]["buttons"] = _held(map, [_button(5)])
	eq(GameControls.read_pad_intent(DEV, 0).shot, K.SHOT_SPECIAL, "R is SPECIAL")
	GameControls.fake_pads[DEV]["buttons"] = []
	GameControls.pad_menu_bits(DEV)
	GameControls.fake_pads[DEV]["buttons"] = _held(map, [_axis(0, 1.0), _button(2)])
	eq(GameControls.pad_menu_bits(DEV)[0], Practice.PAD_RIGHT | Practice.PAD_B, "menus: Right and confirm")
	_cleanup()


func _held(map: Dictionary, raw: Array) -> Array:
	var bs := []
	for r in raw:
		for e in PadMaps.translate(map, r):
			if e.pressed:
				bs.append(e.button_index)
	return bs


## A hat D-pad (it arrives as the D-pad buttons until mapped), undo,
## cancel, and an axis resting far from 0 (a trigger) never answering.
func test_hat_undo_cancel() -> void:
	_cleanup()
	var m := PadMapper.new()
	m.begin(DEV, GUID, "Generic SNES")
	m._rest[2] = -1.0
	eq(m.feed(_axis(2, 1.0)), PadMapper.IGNORED, "a resting trigger axis isn't asked about")
	for b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]:
		eq(m.feed(_button(b)), PadMapper.NEXT)
		m.feed(_button(b, false))
	eq(m.map["dpleft"], "h0.8", "the hat's left")
	m.undo()
	eq([m.step, m.map.has("dpleft")], [2, false], "BACKSPACE asks LEFT again")
	m.feed(_button(JOY_BUTTON_DPAD_LEFT))
	m.feed(_button(JOY_BUTTON_DPAD_RIGHT))
	for b in [0, 1, 2, 3, 4, 5, 6]:
		m.feed(_button(b))
		m.feed(_button(b, false))
	check(PadMaps.maps.has(GUID), "mapped")
	var s := PadMaps.mapping_string(GUID, PadMaps.maps[GUID])
	check("dpup:h0.1" in s and "dpright:h0.2" in s and "leftx:a0" in s and "lefty:a1" in s,
		"hat directions, and the stick stays on axes 0 and 1: " + s)
	var t := PadMaps.translate(PadMaps.maps[GUID]["map"], _button(JOY_BUTTON_DPAD_DOWN))
	eq(t[0].button_index, JOY_BUTTON_DPAD_DOWN, "the hat still moves")
	var before: Dictionary = PadMaps.maps[GUID].duplicate(true)
	var again := PadMapper.new()
	again.begin(DEV, GUID, "Generic SNES")
	again.feed(_button(8))
	again.cancel()
	eq(PadMaps.maps[GUID], before, "a cancelled remap keeps the old map")
	eq(PadMaps.applied[0], s, "and gives it back to Input")
	PadMaps.clear(GUID)
	check(not PadMaps.maps.has(GUID), "CLEAR MAPPING")
	_cleanup()


func test_maps_saved() -> void:
	_cleanup()
	var save := fresh_save("user://test_pad_maps/")
	PadMaps.store(GUID, "USB Gamepad", {"a": "b2", "start": "b9", "dpup": "-a1"})
	Settings.pad_notice = false
	Settings.store_to(save)
	save.save_game()
	PadMaps.maps = {}
	PadMaps.applied = []
	Settings.pad_notice = true
	var again := SaveGame.new()
	again.dir = save.dir
	again.load_game()
	Settings.load_from(again)
	eq(PadMaps.maps.get(GUID, {}).get("map", {}), {"a": "b2", "start": "b9", "dpup": "-a1"},
		"a pad's map survives a restart")
	check(not PadMaps.applied.is_empty() and PadMaps.applied[0].begins_with(GUID), "and is given to Input at load")
	check(not Settings.pad_notice, "DON'T SHOW AGAIN is kept")
	PadMaps.from_save({"x": "junk", "y": {"map": {"nonsense": "b1"}}, GUID: {"name": 3, "map": {"a": "b1"}}})
	eq(PadMaps.maps.keys(), [GUID], "malformed maps are dropped")
	Settings.pad_notice = true
	_cleanup()


func _title() -> TitleScreen:
	return title_screen()


## MAP BUTTONS on the title: the pad's events answer, Esc cancels, the
## last answer goes back to CONTROLLER with its press swallowed (rule 9).
func test_title_map_flow() -> void:
	_cleanup()
	var t := _title()
	t.reveal_page("pad")
	t.open_pad_map()
	eq(t.page, "pad", "no pad, nothing to map")
	eq(t.pages["pad"].value_of("map"), PadMaps.NO_PAD)
	t.pad_mapper.begin(DEV, GUID, "USB Gamepad")
	t._show("padmap")
	t._input(_button(2))
	eq(t.pad_mapper.step, 1, "a pad press answers")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	t._input(esc)
	check(t.page == "pad" and t._lock > 0 and not PadMaps.maps.has(GUID), "Esc cancels to CONTROLLER")
	t.pad_mapper.begin(DEV, GUID, "USB Gamepad")
	t._show("padmap")
	for step in SNES_USB:
		if step.size() == 1:
			t._input(_button(step[0]))
			t._input(_button(step[0], false))
		else:
			for ev in step:
				t._input(_axis(ev[0], ev[1]))
	check(t.page == "pad" and t._lock > 0 and PadMaps.maps.has(GUID), "done: back, mapped, swallowed")
	eq(t.pages["pad"].current_id(), "map")
	t.free()
	_cleanup()


## The card: with no pad, the title opens on it once a session; OK goes to
## MAIN swallowing the press; DON'T SHOW AGAIN turns it off; a pad
## connecting closes it; with a pad, it never shows.
func test_controller_notice() -> void:
	var kept := Settings.pad_notice
	Settings.pad_notice = true
	TitleScreen.notice_done = false
	TitleScreen.return_to = ""            # at startup, nothing to come back to
	var t := _title()
	eq(t.page, "notice", "no pad: the card first")
	check(TitleScreen.notice_done, "once a session")
	t.pages["notice"].select("ok")
	t.pages["notice"].press()
	check(t.page == "main" and t._lock > 0, "OK: MAIN, the press swallowed")
	t.free()
	var again := _title()
	eq(again.page, "main", "not twice")
	again.free()
	TitleScreen.notice_done = false
	var n := _title()
	n.pages["notice"].select("never")
	n.pages["notice"].press()
	check(not Settings.pad_notice and n.page == "main", "DON'T SHOW AGAIN")
	n.free()
	TitleScreen.notice_done = false
	var off := _title()
	eq(off.page, "main", "turned off, it stays away")
	off.free()
	Settings.pad_notice = true
	TitleScreen.notice_done = false
	GameControls.fake_pads = {0: {"buttons": []}}
	var pad := _title()
	eq(pad.page, "main", "with a pad, no card")
	pad.free()
	GameControls.fake_pads = {}
	TitleScreen.notice_done = false
	var late := _title()
	late._lock = 0
	GameControls.fake_pads = {0: {"buttons": []}}
	late._process(0.0)
	eq(late.page, "main", "a pad connecting closes it")
	late.free()
	GameControls.fake_pads = {}
	TitleScreen.notice_done = true
	Settings.pad_notice = kept


## A generic pad's prompts: SNES letters by position, not Xbox's.
func test_generic_prompts() -> void:
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_A, Prompts.SNES)), "B", "south is B")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_B, Prompts.SNES)), "A", "east is A")
	eq(Prompts.glyph_text(Prompts.button_glyph(JOY_BUTTON_START, Prompts.SNES)), "START")
	eq(Prompts.family_of("SNES Controller"), Prompts.SNES)
	var kept := Settings.pad_glyphs
	Settings.pad_glyphs = Prompts.FAMILIES.find(Prompts.SNES)
	eq(Prompts.family(), Prompts.SNES, "BUTTON ICONS: SNES")
	Settings.pad_glyphs = kept
	eq(PadMapper.source_name("-a1"), "AXIS 1 -")
	eq(PadMapper.source_name("h0.4"), "HAT DOWN")
	eq(PadMapper.source_name("b12"), "BUTTON 12")


## A pad's name in the fonts' characters, cut to fit; no pad's row values.
func test_names_and_status() -> void:
	eq(PadMaps.short_name("8BitDo SN30 Pro", 18), "8BITDO SN30 PRO")
	eq(PadMaps.short_name("Pad™ (USB) #2", 18), "PAD   USB   2", "the fonts' characters only")
	eq(PadMaps.short_name("™™", 18), "PAD", "nothing left: PAD")
	eq(PadMaps.short_name("USB,2-axis 8-button gamepad", 18), "USB 2-AXIS 8-BUT..", "cut to 18")
	eq(PadMaps.short_name("USB,2-axis 8-button gamepad", 18).length(), 18)
	eq(PadMaps.display_name(-1), "NONE")
	eq(PadMaps.status(-1), PadMaps.NO_PAD)
