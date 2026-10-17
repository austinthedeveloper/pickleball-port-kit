## Button prompts that follow the device in hand (PORT-11): on a keyboard
## the action's bound key in a key cap; on a pad the bound face button as
## that pad family shows it (Xbox and Nintendo letters, PlayStation
## shapes), or a START / D-PAD pill. Bindings come from the live input
## map, so a remap (PORT-12) shows at once.
class_name Prompts
extends RefCounted

const XBOX := 0
const NINTENDO := 1
const PLAYSTATION := 2

## Face buttons by position (Godot's JOY_BUTTON_A..Y = south, east, west, north).
const FACE := {JOY_BUTTON_A: 0, JOY_BUTTON_B: 1, JOY_BUTTON_X: 2, JOY_BUTTON_Y: 3}
const LETTERS := [["A", "B", "X", "Y"], ["B", "A", "Y", "X"], ["", "", "", ""]]
const SHAPES := ["cross", "circle", "square", "triangle"]
const XBOX_COLORS := [Color("5fc24a"), Color("e04a3a"), Color("3a7be0"), Color("f0c030")]
const PS_COLORS := [Color("7aa6e8"), Color("e8667a"), Color("d77ad8"), Color("5fcfa8")]


## Forces a pad family (screenshots without the pad); -1 reads the pad.
static var force_family := -1

static func family(pad: int) -> int:
	if force_family >= 0:
		return force_family
	return family_for_name(Input.get_joy_name(pad))


static func family_for_name(name: String) -> int:
	var n := name.to_lower()
	if "playstation" in n or "dualshock" in n or "dualsense" in n or "ps4" in n or "ps5" in n:
		return PLAYSTATION
	if "nintendo" in n or "switch" in n or "snes" in n or "pro controller" in n:
		return NINTENDO
	return XBOX


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
## {kind: "key" | "face" | "pill", text, color, shape}.
static func glyph(action: String, device := -1, pad := -1, fam := -1) -> Dictionary:
	if device < 0:
		device = GameControls.last_device
	if pad < 0:
		pad = GameControls.last_pad
	if device == GameControls.KEYBOARD:
		if action == "dpad":
			return {"kind": "key", "text": "ARROWS"}
		var k := first_key(action)
		return {"kind": "key", "text": key_name(k) if k else "?"}
	if action == "dpad":
		return {"kind": "pill", "text": "D-PAD"}
	var b := first_button(action)
	if b == JOY_BUTTON_START:
		return {"kind": "pill", "text": "START"}
	if b == JOY_BUTTON_BACK:
		return {"kind": "pill", "text": "SELECT"}
	if not FACE.has(b):
		return {"kind": "pill", "text": "?"}
	var f := fam if fam >= 0 else family(pad)
	var i: int = FACE[b]
	if f == PLAYSTATION:
		return {"kind": "face", "text": "", "shape": SHAPES[i], "color": PS_COLORS[i]}
	return {"kind": "face", "text": LETTERS[f][i], "color": XBOX_COLORS[i] if f == XBOX
		else Color("c8c8d8")}


## Plain text for a prompt, for tests and logs: "SPACE", "A", "CROSS".
static func label(action: String, device := -1, pad := -1, fam := -1) -> String:
	var g := glyph(action, device, pad, fam)
	return String(g["text"]) if g["text"] != "" else String(g.get("shape", "")).to_upper()
