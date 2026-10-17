## Button prompts that follow the device in hand (PORT-11): on a keyboard
## the action's bound key in a key cap; on any pad the bound button as
## the Xbox layout shows it (PORT-15: A B X Y in their colours, LB RB LS
## RS, the Menu and View buttons, the D-pad), since every pad is mapped to
## that layout. Bindings come from the live input map, so a remap shows
## at once.
class_name Prompts
extends RefCounted

## Face buttons (south, east, west, north) and their Xbox colours.
const FACE := {JOY_BUTTON_A: ["A", Color("5fc24a")], JOY_BUTTON_B: ["B", Color("e04a3a")],
	JOY_BUTTON_X: ["X", Color("3a7be0")], JOY_BUTTON_Y: ["Y", Color("f0c030")]}
const DPAD := {JOY_BUTTON_DPAD_UP: 0, JOY_BUTTON_DPAD_DOWN: 1, JOY_BUTTON_DPAD_LEFT: 2,
	JOY_BUTTON_DPAD_RIGHT: 3}
const NAMED := {JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"}


## A key's name for a cap, from its physical code.
static func key_name(code: int) -> String:
	var names := {KEY_SPACE: "SPACE", KEY_ENTER: "ENTER", KEY_ESCAPE: "ESC", KEY_UP: "UP",
		KEY_DOWN: "DOWN", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_SHIFT: "SHIFT",
		KEY_TAB: "TAB", KEY_BACKSPACE: "BKSP", KEY_CTRL: "CTRL", KEY_ALT: "ALT"}
	if names.has(code):
		return names[code]
	return OS.get_keycode_string(code).to_upper()


static func first_key(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode if e.physical_keycode else e.keycode
	return 0


static func first_button(action: String) -> int:
	if not InputMap.has_action(action):
		return -1
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return e.button_index
	return -1


## How to draw the prompt for an action ("dpad" is the four moves):
## {kind: "key" | "face" | "pill" | "menu" | "view" | "dpad", text,
## color, dir (dpad: -1 all, else 0 up, 1 down, 2 left, 3 right)}.
static func glyph(action: String, device := -1) -> Dictionary:
	if device < 0:
		device = GameControls.last_device
	if device == GameControls.KEYBOARD:
		if action == "dpad":
			return {"kind": "key", "text": "ARROWS"}
		var k := first_key(action)
		return {"kind": "key", "text": key_name(k) if k else "?"}
	if action == "dpad":
		return {"kind": "dpad", "text": "", "dir": -1}
	return button_glyph(first_button(action))


static func button_glyph(b: int) -> Dictionary:
	if FACE.has(b):
		return {"kind": "face", "text": FACE[b][0], "color": FACE[b][1]}
	if DPAD.has(b):
		return {"kind": "dpad", "text": "", "dir": DPAD[b]}
	if b == JOY_BUTTON_START:
		return {"kind": "menu", "text": ""}
	if b == JOY_BUTTON_BACK:
		return {"kind": "view", "text": ""}
	if NAMED.has(b):
		return {"kind": "pill", "text": NAMED[b]}
	return {"kind": "pill", "text": "?" if b < 0 else "BUTTON %d" % b}


## Plain text for a prompt, for tests and the CONTROLS page: "SPACE", "A",
## "MENU", "D-PAD", "D-UP".
static func label(action: String, device := -1) -> String:
	return glyph_text(glyph(action, device))


static func glyph_text(g: Dictionary) -> String:
	match g["kind"]:
		"menu":
			return "MENU"
		"view":
			return "VIEW"
		"dpad":
			return "D-PAD" if g["dir"] < 0 else ["D-UP", "D-DOWN", "D-LEFT", "D-RIGHT"][g["dir"]]
	return g["text"]
