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


## P1's intent for this frame from the input map (input_state.c
## build_intent): D-pad moves and aims; B/A/Y swing with their shot type.
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
	var b := Input.is_action_just_pressed("hit")
	var a := Input.is_action_just_pressed("drive")
	var y := Input.is_action_just_pressed("soft")
	it.hit_pressed = 1 if (a or b or y) else 0
	it.hit_held = 1 if (Input.is_action_pressed("hit") or Input.is_action_pressed("drive")
		or Input.is_action_pressed("soft")) else 0
	if a:
		it.shot = K.SHOT_DRIVE
	elif y:
		it.shot = K.SHOT_SOFT
	it.pause_pressed = 1 if Input.is_action_just_pressed("start") else 0
	return it
