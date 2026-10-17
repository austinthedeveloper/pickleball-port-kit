## Input map, built at startup so project.godot stays readable. SNES layout
## on a keyboard and any gamepad: B = standard hit (Space/J, pad south),
## A = drive (K, pad east), Y = soft shot (L, pad west), Start = Enter.
class_name GameControls
extends Node

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"hit": [KEY_SPACE, KEY_J],
	"drive": [KEY_K],
	"soft": [KEY_L],
	"start": [KEY_ENTER, KEY_ESCAPE],
}
const PAD_BUTTONS := {
	"hit": JOY_BUTTON_A,
	"drive": JOY_BUTTON_B,
	"soft": JOY_BUTTON_X,
	"start": JOY_BUTTON_START,
	"move_up": JOY_BUTTON_DPAD_UP,
	"move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT,
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for key in ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
		if PAD_BUTTONS.has(action):
			var b := InputEventJoypadButton.new()
			b.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, b)
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
			["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


## Presses latched from input events until the next sim step reads them,
## so a tap shorter than a physics tick (fast frames, high refresh) is
## never lost.
const LATCHED := ["hit", "drive", "soft", "start"]
static var _latch := {}


## The device the player touched last (prompts follow it): KEYBOARD
## (keys and the mouse) or PAD, and that pad's id; `device_serial` counts
## changes so a prompt can redraw.
const KEYBOARD := 0
const PAD := 1
static var last_device := KEYBOARD
static var last_pad := 0
static var device_serial := 0
## Counts input-map changes (a remap), so prompts redraw.
static var binding_serial := 0


static func note_device(event: InputEvent) -> void:
	var dev := -1
	if event is InputEventKey or event is InputEventMouseButton:
		dev = KEYBOARD
	elif event is InputEventJoypadButton:
		dev = PAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		dev = PAD
	if dev < 0:
		return
	var pad := event.device if dev == PAD else last_pad
	if dev != last_device or pad != last_pad:
		last_device = dev
		last_pad = pad
		device_serial += 1


func _input(event: InputEvent) -> void:
	note_device(event)
	if event.is_echo():
		return
	for a in LATCHED:
		if event.is_action_pressed(a):
			_latch[a] = true


static func _pressed(action: String) -> bool:
	var p: bool = _latch.get(action, false) or Input.is_action_just_pressed(action)
	_latch.erase(action)
	return p


## P1's intent for this frame from the input map (input_state.c
## build_intent): D-pad moves and aims; B/A/Y swing with their shot type.
## Drops latched presses (a screen change: rule 9).
static func clear_latch() -> void:
	_latch.clear()


## Menus and cards read SNES pad bits (Practice.PAD_*; A is 0x0080):
## [newly pressed, held] from the input map.
const PAD_A := 0x0080

static func pad_bits() -> Array:
	var pressed := 0
	var held := 0
	for pair in [["move_up", Practice.PAD_UP], ["move_down", Practice.PAD_DOWN],
			["move_left", Practice.PAD_LEFT], ["move_right", Practice.PAD_RIGHT],
			["hit", Practice.PAD_B], ["drive", PAD_A], ["soft", Practice.PAD_Y],
			["start", Practice.PAD_START]]:
		if Input.is_action_just_pressed(pair[0]):
			pressed |= pair[1]
		if Input.is_action_pressed(pair[0]):
			held |= pair[1]
	return [pressed, held]


static func read_intent() -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	if Input.is_action_pressed("move_left"):
		it.move_x = -1
	elif Input.is_action_pressed("move_right"):
		it.move_x = 1
	if Input.is_action_pressed("move_up"):
		it.move_y = -1
	elif Input.is_action_pressed("move_down"):
		it.move_y = 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	var b := _pressed("hit")
	var a := _pressed("drive")
	var y := _pressed("soft")
	it.hit_pressed = 1 if (a or b or y) else 0
	it.hit_held = 1 if (Input.is_action_pressed("hit") or Input.is_action_pressed("drive")
		or Input.is_action_pressed("soft")) else 0
	if a:
		it.shot = K.SHOT_DRIVE
	elif y:
		it.shot = K.SHOT_SOFT
	it.pause_pressed = 1 if _pressed("start") else 0
	return it


## 2P (ADR-020): a second gamepad's intent, read directly so the input map
## (keyboard + pad 0) stays P1's.
static var _pad_prev := {}

static func read_pad_intent(device: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	if not device in Input.get_connected_joypads():
		return it
	var ax := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT) or ax < -0.4:
		it.move_x = -1
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT) or ax > 0.4:
		it.move_x = 1
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP) or ay < -0.4:
		it.move_y = -1
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN) or ay > 0.4:
		it.move_y = 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	var held := {}
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]:
		held[b] = Input.is_joy_button_pressed(device, b)
	var prev: Dictionary = _pad_prev.get(device, {})
	var pressed := {}
	for b in held:
		pressed[b] = held[b] and not prev.get(b, false)
	_pad_prev[device] = held
	it.hit_pressed = 1 if (pressed[JOY_BUTTON_A] or pressed[JOY_BUTTON_B] or pressed[JOY_BUTTON_X]) else 0
	it.hit_held = 1 if (held[JOY_BUTTON_A] or held[JOY_BUTTON_B] or held[JOY_BUTTON_X]) else 0
	if pressed[JOY_BUTTON_B]:
		it.shot = K.SHOT_DRIVE
	elif pressed[JOY_BUTTON_X]:
		it.shot = K.SHOT_SOFT
	return it
