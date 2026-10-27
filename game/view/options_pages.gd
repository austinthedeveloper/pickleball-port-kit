## OPTIONS and the pages under it (ACCESSIBILITY, CONTROLS, CONTROLLER),
## the same on the title and in a match's pause menu (port ADR-090). `host`
## is the screen they sit on, a TitleScreen or an OptionsPanel: its
## _add_page, open_page, back_to, listen and listening, open_pad_map,
## pad_mapper and pad_map_screen, swallow, _store_settings and
## _save_settings, _sfx and get_window. Only view and input settings live
## here: nothing on these pages changes a match's rules.
class_name OptionsPages
extends RefCounted


static func build(host: Node) -> void:
	var help := [["hit", "SELECT"], ["back", "BACK"]]
	var rows := [
		{"id": "camera", "label": "CAMERA",
			"value": func(): return "OFF" if Settings.camera_i == 0 else "%d%%" % Settings.CAMERAS[Settings.camera_i],
			"change": func(d): Settings.camera_i = clampi(Settings.camera_i + d, 0, Settings.CAMERAS.size() - 1)},
		{"id": "sound", "label": "SOUND", "value": func(): return AudioMap.SOUND_NAMES[Sfx.setting],
			"change": func(d): Sfx.setting = (Sfx.setting + d + 3) % 3},
		{"id": "music", "label": "MUSIC", "value": func(): return Music.volume_name(),
			"change": func(d): Music.volume = clampi(Music.volume + d, 0, Music.VOLUMES)},
		# ADR-076: the announcer's volume, and how much it says
		{"id": "announcer", "label": "ANNOUNCER", "value": func(): return "ON" if Announcer.enabled else "OFF",
			"change": func(_d): Announcer.enabled = not Announcer.enabled},
		{"id": "voice", "label": "VOICE VOLUME", "value": func(): return Announcer.volume_name(),
			"change": func(d): Announcer.volume = clampi(Announcer.volume + d, 1, Announcer.VOLUMES)},
		{"id": "commentary", "label": "COMMENTARY", "value": func(): return Announcer.CHATTER_NAMES[Announcer.chatter],
			"change": func(d): Announcer.chatter = clampi(Announcer.chatter + d, Announcer.LIGHT, Announcer.LOTS)},
		{"id": "fullscreen", "label": "FULLSCREEN", "value": func(): return "ON" if Settings.fullscreen else "OFF",
			"change": func(_d): Settings.fullscreen = not Settings.fullscreen; Settings.apply_window(host.get_window())},
		{"id": "scale", "label": "SCALE", "value": func(): return "PIXEL" if Settings.integer_scale else "FILL",
			"change": func(_d): Settings.integer_scale = not Settings.integer_scale; Settings.apply_window(host.get_window())},
		{"id": "controls", "label": "CONTROLS", "press": func(): host.open_page("controls")},
		{"id": "access", "label": "ACCESSIBILITY", "press": func(): host.open_page("access")},
		# PORT-32: the in-game updater
		{"id": "updates", "label": "UPDATES", "value": func():
			return Updater.instance.label() if Updater.instance else "DEV BUILD",
			"press": func():
				if Updater.instance:
					Updater.instance.press()},
	]
	# ADR-103: ONLINE's netcode, the host's choice (not in the Web build:
	# no online there), once a match plays rollback (PORT-109)
	if OnlineSession.VIEW_PLAYS_ROLLBACK and not Settings.lite:
		rows.insert(rows.size() - 1, {"id": "netcode", "label": "ONLINE NETCODE",
			"value": func(): return Settings.NETCODES[Settings.netcode_i],
			"change": func(d): Settings.netcode_i = (Settings.netcode_i + d + 2) % 2})
	host._add_page("options", "OPTIONS", rows, [], Rect2(300, 60, 360, 0))     # ADR-076 made it 14 rows: over the logo, hidden
	var onoff := func(on: bool) -> String: return "ON" if on else "OFF"
	host._add_page("access", "ACCESSIBILITY", [
		{"id": "shake", "label": "SCREEN SHAKE",
			"value": func(): return "OFF" if Settings.shake_i == 0 else "%d%%" % Settings.SHAKES[Settings.shake_i],
			"change": func(d): Settings.shake_i = clampi(Settings.shake_i + d, 0, Settings.SHAKES.size() - 1)},
		{"id": "flashes", "label": "FLASHES", "value": func(): return onoff.call(Settings.flashes),
			"change": func(_d): Settings.flashes = not Settings.flashes},
		{"id": "hud", "label": "HUD TEXT", "value": func(): return "LARGE" if Settings.hud_large else "NORMAL",
			"change": func(_d): Settings.hud_large = not Settings.hud_large},
		{"id": "assist", "label": "SERVE ASSIST", "value": func(): return onoff.call(Settings.serve_assist),
			"change": func(_d): Settings.serve_assist = not Settings.serve_assist},
		{"id": "vibration", "label": "VIBRATION", "value": func(): return onoff.call(Settings.vibration),
			"change": func(_d):
				Settings.vibration = not Settings.vibration
				GameControls.rumble(0, 0.4, 0.4, 0.15)},       # a taste of it
	], help, Rect2(280, 172, 400, 0))
	var control_rows := []
	for a in Bindings.ACTIONS:
		var action: String = a
		control_rows.append({"id": action, "label": Bindings.NAMES[action],
			"value": func(): return "PRESS A KEY OR BUTTON" if host.listening == action else Bindings.describe(action),
			"press": func(): host.listen(action)})
	# port ADR-082: the pad's own page (BUTTON ICONS moved there)
	control_rows.append({"id": "pad", "label": "CONTROLLER",
		"value": func(): return PadMaps.status(PadMaps.target_pad()),
		"press": func(): host.open_page("pad")})
	control_rows.append({"id": "reset", "label": "RESET DEFAULTS", "press": func():
		Bindings.reset()
		host._store_settings()})
	host._add_page("controls", "CONTROLS", control_rows, [["hit", "REBIND"], ["back", "BACK"]],
		Rect2(250, 8, 460, 0))           # high: SLICE, SHORT and SPECIAL made it 14 rows
	# CONTROLLER (port ADR-082): the pad in hand, mapping a generic one, its
	# icons, and the startup card about pads
	host._add_page("pad", "CONTROLLER", [
		{"id": "device", "label": "PAD", "value": func(): return PadMaps.display_name(PadMaps.target_pad())},
		{"id": "map", "label": "MAP BUTTONS", "value": func(): return PadMaps.status(PadMaps.target_pad()),
			"press": host.open_pad_map},
		{"id": "clear", "label": "CLEAR MAPPING", "press": func():
			var dev := PadMaps.target_pad()
			if PadMaps.mapped(dev):
				PadMaps.clear(Input.get_joy_guid(dev))
				host._save_settings()},
		{"id": "icons", "label": "BUTTON ICONS",
			"value": func(): return Prompts.FAMILY_NAMES[Settings.pad_glyphs],
			"change": func(d):
				Settings.pad_glyphs = (Settings.pad_glyphs + d + Prompts.FAMILIES.size()) % Prompts.FAMILIES.size()
				GameControls.device_serial += 1},        # every prompt bar redraws
		{"id": "notice", "label": "PAD NOTICE", "value": func(): return onoff.call(Settings.pad_notice),
			"change": func(_d): Settings.pad_notice = not Settings.pad_notice},
		# PORT-81: the on-screen pad (AUTO: on a touch screen with no pad)
		{"id": "touch", "label": "TOUCH PAD", "value": func(): return TouchPad.MODES[Settings.touch_pad],
			"change": func(d):
				Settings.touch_pad = (Settings.touch_pad + d + TouchPad.MODES.size()) % TouchPad.MODES.size()},
	], help, Rect2(250, 150, 460, 0))


## MAP BUTTONS: asks the pad in hand for its buttons, if it's one SDL
## doesn't know (or one mapped before); a standard pad needs none.
static func open_pad_map(host: Node) -> void:
	var dev := PadMaps.target_pad()
	if not PadMaps.status(dev) in [PadMaps.UNKNOWN, PadMaps.MAPPED]:
		if host._sfx:
			host._sfx.play("back")
		return
	host.pad_mapper.begin(dev)
	host._show("padmap")
	host.pad_map_screen.refresh()
	host.swallow()


## One input event while MAP BUTTONS is open: the pad's answers; Esc
## cancels and Backspace steps back. All of it is swallowed (rule 9).
static func pad_map_input(host: Node, event: InputEvent) -> void:
	if event.is_echo():
		return
	var mapper: PadMapper = host.pad_mapper
	if event is InputEventKey and event.is_pressed():
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code == KEY_ESCAPE:
			mapper.cancel()
			host.back_to("pad", "map")
			if host._sfx:
				host._sfx.play("back")
		elif code == KEY_BACKSPACE:
			mapper.undo()
			host.pad_map_screen.refresh()
			if host._sfx:
				host._sfx.play("blip")
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var r := mapper.feed(event)
		if r == PadMapper.DONE:
			host._save_settings()
			host.back_to("pad", "map")
		else:
			host.pad_map_screen.refresh()
		if r != PadMapper.IGNORED and host._sfx:
			host._sfx.play("confirm" if r == PadMapper.DONE else "blip")


## One input event on the host: MAP BUTTONS' answers, or, while CONTROLS
## listens, the next key or pad button press rebinds the action (Esc
## cancels). Either is swallowed (rule 9). True when it took the event.
static func input(host: Node, event: InputEvent) -> bool:
	if host.page == "padmap":
		pad_map_input(host, event)
		return true
	if host.listening == "" or not event.is_pressed() or event.is_echo():
		return false
	var done := false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code != KEY_ESCAPE:
			Bindings.rebind_key(host.listening, code)
		done = true
	elif event is InputEventJoypadButton:
		Bindings.rebind_pad(host.listening, event.button_index)
		done = true
	if not done:
		return false
	host.listening = ""
	host._store_settings()
	host.swallow()
	host.pages["controls"].refresh()
	if host._sfx:
		host._sfx.play("confirm")
	return true
