## Input map, built at startup so project.godot stays readable. SNES layout
## on a keyboard and any gamepad: B = standard hit (Space/J, pad south),
## A = drive (K, pad east), Y = soft shot (L, pad west), Start = Enter.
## Controllers (PORT-15): Godot's SDL mappings put every pad (Xbox,
## PlayStation, Switch, generic) on the Xbox layout, so one binding fits
## all. In one-player any pad drives P1; with 2P on and two pads the first
## is P1's and the second P2's (one pad: P1 on the keyboard, P2 the pad).
## Pads can come and go at any time.
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


## The pad each player uses: -1 = any pad (P1 in one-player), NO_PAD =
## none (the keyboard only).
const NO_PAD := -2
static var p1_pad := -1
static var p2_pad := NO_PAD
## Connection news for a toast: ["CONNECTED" | "DISCONNECTED", device], and
## a counter; `lost_serial` counts disconnects only (a match pauses).
static var pad_news: Array = []
static var news_serial := 0
static var lost_serial := 0


## Who plays on which pad, from the connected pads (sorted by id).
static func assign_pads(connected: Array, two_players: bool) -> void:
	var pads := connected.duplicate()
	pads.sort()
	if two_players and pads.size() >= 2:
		p1_pad = pads[0]
		p2_pad = pads[1]
	elif two_players and pads.size() == 1:
		p1_pad = NO_PAD
		p2_pad = pads[0]
	else:
		p1_pad = -1
		p2_pad = NO_PAD
	apply_devices()


## Re-reads the connected pads (and 2P) and re-targets P1's pad events.
static func refresh_pads() -> void:
	assign_pads(Input.get_connected_joypads(), Settings.two_players)


## The device P1's pad events listen on (a pad id, -1 for all, or one no
## pad has when P1 is on the keyboard).
static func p1_device() -> int:
	return 99 if p1_pad == NO_PAD else p1_pad


static func apply_devices() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(action, e)
				var copy: InputEvent = e.duplicate()
				copy.device = p1_device()
				InputMap.action_add_event(action, copy)
	binding_serial += 1


## Menu navigation: a press, or a held direction repeating (a stick or
## D-pad held down scrolls), like most games' menus. In real time, so the
## speed is the same at any frame rate. Call once a frame per action.
const REPEAT_DELAY_MS := 300
const REPEAT_EVERY_MS := 85
static var _held := {}           ## action -> the next repeat's time (ms)

static func menu_pressed(action: String) -> bool:
	return repeat_step(_held, action, Input.is_action_just_pressed(action),
		Input.is_action_pressed(action), Time.get_ticks_msec())


## The repeat rule on its own (tests drive the clock): true on a press, then
## after REPEAT_DELAY_MS of holding, every REPEAT_EVERY_MS.
static func repeat_step(state: Dictionary, action: String, just: bool, held: bool, now: int) -> bool:
	if just:
		state[action] = now + REPEAT_DELAY_MS
		return true
	if held and state.has(action):
		if now >= int(state[action]):
			state[action] = int(state[action]) + REPEAT_EVERY_MS
			return true
		return false
	state.erase(action)
	return false


## Rumble (VIBRATION in ACCESSIBILITY): on a player's pad, or the pad in
## hand when P1 plays on any pad. `last_rumble` keeps the last request
## ([device, weak, strong, seconds]) for tests.
static var last_rumble: Array = []

static func rumble(player: int, weak: float, strong: float, seconds: float) -> void:
	if not Settings.vibration:
		return
	var dev := p1_pad if player == 0 else p2_pad
	if player == 0 and dev == -1:
		dev = last_pad if last_device == PAD else NO_PAD
	if dev < 0:
		return
	last_rumble = [dev, weak, strong, seconds]
	Input.start_joy_vibration(dev, weak, strong, seconds)


static func _on_joy_connection(device: int, connected: bool) -> void:
	pad_news = ["CONNECTED" if connected else "DISCONNECTED", device]
	news_serial += 1
	if not connected:
		lost_serial += 1
	refresh_pads()


func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.connect(_on_joy_connection)
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
	assign_pads(Input.get_connected_joypads(), false)


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
