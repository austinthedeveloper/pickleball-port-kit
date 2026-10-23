## Button prompts that follow the device in hand (PORT-11): on a keyboard
## the action's bound key in a key cap; on a pad the bound button as that
## pad's family labels it (PORT-28): Xbox (A B X Y in their colours, LB RB
## LS RS, Menu and View, the default and any unknown pad), PlayStation
## (cross, circle, square, triangle; L1 R1 L3 R3, OPTIONS and CREATE) or
## Nintendo (B A Y X by position, since Godot maps every pad by position:
## the south button is JOY_BUTTON_A; L R, + and -). A generic pad (one SDL
## doesn't know, mapped on CONTROLLER, port ADR-082) is drawn as a SNES
## pad: B A Y X by position in the Super Famicom's colours, L R, START and
## SELECT. The family comes from the pad's name, or BUTTON ICONS on
## CONTROLLER. Bindings come from the live input map, so a remap shows at
## once.
class_name Prompts
extends RefCounted

## Face buttons (south, east, west, north) and their Xbox colours.
const FACE := {JOY_BUTTON_A: ["A", Color("5fc24a")], JOY_BUTTON_B: ["B", Color("e04a3a")],
	JOY_BUTTON_X: ["X", Color("3a7be0")], JOY_BUTTON_Y: ["Y", Color("f0c030")]}
const DPAD := {JOY_BUTTON_DPAD_UP: 0, JOY_BUTTON_DPAD_DOWN: 1, JOY_BUTTON_DPAD_LEFT: 2,
	JOY_BUTTON_DPAD_RIGHT: 3}
const NAMED := {JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"}

const XBOX := "xbox"
const PLAYSTATION := "playstation"
const NINTENDO := "nintendo"
const SNES := "snes"
## BUTTON ICONS (Settings.pad_glyphs): AUTO, then each family.
const FAMILIES := ["", XBOX, PLAYSTATION, NINTENDO, SNES]
const FAMILY_NAMES := ["AUTO", "XBOX", "PLAYSTATION", "NINTENDO", "SNES"]
## PlayStation faces by position: the shape and its colour.
const PS_FACE := {JOY_BUTTON_A: ["cross", Color("7fa8ff")], JOY_BUTTON_B: ["circle", Color("ff6a6a")],
	JOY_BUTTON_X: ["square", Color("f08ad0")], JOY_BUTTON_Y: ["triangle", Color("5fd6a8")]}
const PS_NAMED := {JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}
## Nintendo faces by position (south B, east A, west Y, north X), one grey.
const NIN_FACE := {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X"}
const NIN_NAMED := {JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"}
const NIN_GREY := Color(0.78, 0.8, 0.86)
## SNES faces by position (south B, east A, west Y, north X) in the Super
## Famicom's colours; the shoulders are L and R, the triggers mirror them.
const SNES_FACE := {JOY_BUTTON_A: ["B", Color("f0c030")], JOY_BUTTON_B: ["A", Color("e04a3a")],
	JOY_BUTTON_X: ["Y", Color("5fc24a")], JOY_BUTTON_Y: ["X", Color("3a7be0")]}
const SNES_NAMED := {JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "SELECT"}


## A pad's family from the name its driver reports (SDL's names: "PS5
## Controller", "Nintendo Switch Pro Controller", "Xbox Series
## Controller"...). Anything unknown is drawn as an Xbox pad.
static func family_of(pad_name: String) -> String:
	var n := pad_name.to_lower()
	for k in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if k in n:
			return PLAYSTATION
	for k in ["snes", "super famicom", "super nintendo"]:
		if k in n:
			return SNES
	for k in ["nintendo", "switch", "joy-con", "joycon", "pro controller", "wii u", "gamecube"]:
		if k in n:
			return NINTENDO
	return XBOX


## The family to draw now: BUTTON ICONS if set, else the last pad touched.
static func family() -> String:
	var forced: String = FAMILIES[clampi(Settings.pad_glyphs, 0, FAMILIES.size() - 1)]
	if forced != "":
		return forced
	if GameControls.last_pad >= 0:
		if PadMaps.generic(GameControls.last_pad):
			return SNES                      # port ADR-082: no Xbox letters on it
		return family_of(Input.get_joy_name(GameControls.last_pad))
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
## {kind: "key" | "face" | "pill" | "menu" | "view" | "dpad", text,
## color, dir (dpad: -1 all, else 0 up, 1 down, 2 left, 3 right)}.
## Pad-only prompts (the lobby is controllers only): always the button.
const PAD_ONLY := {"pad_a": JOY_BUTTON_A, "pad_b": JOY_BUTTON_B, "pad_x": JOY_BUTTON_X,
	"pad_menu": JOY_BUTTON_START, "lb": JOY_BUTTON_LEFT_SHOULDER, "rb": JOY_BUTTON_RIGHT_SHOULDER}
## Keyboard-only prompts (mapping a pad, port ADR-082: the pad's own
## buttons mean nothing yet): always the key.
const KEY_ONLY := {"esc": KEY_ESCAPE, "bksp": KEY_BACKSPACE}

static func glyph(action: String, device := -1) -> Dictionary:
	if PAD_ONLY.has(action):
		return button_glyph(PAD_ONLY[action])
	if KEY_ONLY.has(action):
		return {"kind": "key", "text": key_name(KEY_ONLY[action])}
	if device < 0:
		device = GameControls.last_device
	if device == GameControls.KEYBOARD:
		if action == "dpad":
			return {"kind": "key", "text": "ARROWS"}
		if action == "back":
			action = "soft"                  # L on the keyboard
		var k := first_key(action)
		return {"kind": "key", "text": key_name(k) if k else "?"}
	if action == "dpad":
		return {"kind": "dpad", "text": "", "dir": -1}
	if action == "back":
		action = "drive"                 # B backs out on a pad
	if action in Bindings.TRIGGERS and first_button(action) < 0:
		return trigger_glyph("", Bindings.TRIGGERS[action] == JOY_AXIS_TRIGGER_LEFT)
	return button_glyph(first_button(action))


## A trigger (SHORT's left, SPECIAL's right, port ADR-082), as each family
## names it; a SNES pad has none, so its shoulders' letters.
static func trigger_glyph(fam := "", left := false) -> Dictionary:
	if fam == "":
		fam = family()
	var names := {PLAYSTATION: ["R2", "L2"], NINTENDO: ["ZR", "ZL"], SNES: ["R", "L"]}
	return {"kind": "pill", "text": names.get(fam, ["RT", "LT"])[1 if left else 0]}


static func button_glyph(b: int, fam := "") -> Dictionary:
	if fam == "":
		fam = family()
	if fam == PLAYSTATION:
		if PS_FACE.has(b):
			return {"kind": "face", "text": "", "shape": PS_FACE[b][0], "color": PS_FACE[b][1]}
		if PS_NAMED.has(b):
			return {"kind": "pill", "text": PS_NAMED[b]}
		if b == JOY_BUTTON_START:
			return {"kind": "pill", "text": "OPTIONS"}
		if b == JOY_BUTTON_BACK:
			return {"kind": "pill", "text": "CREATE"}
	elif fam == SNES:
		if SNES_FACE.has(b):
			return {"kind": "face", "text": SNES_FACE[b][0], "color": SNES_FACE[b][1]}
		if SNES_NAMED.has(b):
			return {"kind": "pill", "text": SNES_NAMED[b]}
	elif fam == NINTENDO:
		if NIN_FACE.has(b):
			return {"kind": "face", "text": NIN_FACE[b], "color": NIN_GREY}
		if NIN_NAMED.has(b):
			return {"kind": "pill", "text": NIN_NAMED[b]}
		if b == JOY_BUTTON_START:
			return {"kind": "face", "text": "+", "color": NIN_GREY}
		if b == JOY_BUTTON_BACK:
			return {"kind": "face", "text": "-", "color": NIN_GREY}
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
	if g.has("shape"):
		return String(g["shape"]).to_upper()
	match g["kind"]:
		"menu":
			return "MENU"
		"view":
			return "VIEW"
		"dpad":
			return "D-PAD" if g["dir"] < 0 else ["D-UP", "D-DOWN", "D-LEFT", "D-RIGHT"][g["dir"]]
	return g["text"]
