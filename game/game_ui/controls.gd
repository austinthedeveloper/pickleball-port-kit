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
	"slice": [KEY_I],                  # SNES X (SNES ADR-056)
	"short": [KEY_SHIFT, KEY_U],       # SNES L or R held: any shot goes short
	"start": [KEY_ENTER, KEY_ESCAPE],
}
const PAD_BUTTONS := {
	"hit": JOY_BUTTON_A,
	"drive": JOY_BUTTON_B,
	"soft": JOY_BUTTON_X,
	"slice": JOY_BUTTON_Y,
	"short": JOY_BUTTON_LEFT_SHOULDER,   # RB too (added in _ready)
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


## Rumble one controller by id (multiplayer).
static func rumble_device(dev: int, weak: float, strong: float, seconds: float) -> void:
	if not Settings.vibration or dev < 0:
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
	# SHORT is either shoulder, as on the SNES (L or R)
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("short", rb)
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
const LATCHED := ["hit", "drive", "soft", "slice", "start"]
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
			["hit", Practice.PAD_B], ["drive", PAD_A | Practice.PAD_Y], ["soft", Practice.PAD_Y],
			["start", Practice.PAD_START]]:
		# drive (B on a pad) is also back (Y), the Xbox menus' convention
		if Input.is_action_just_pressed(pair[0]):
			pressed |= pair[1]
		if Input.is_action_pressed(pair[0]):
			held |= pair[1]
	return [pressed, held]


## P1's intent from the input map. The four swings (SNES ADR-056): HIT
## (standard), DRIVE, SOFT (a lob, or a dink aimed away), SLICE. SHORT
## held (L or R on a pad) aims away from your own net, so any of them goes
## short, while the D-pad still moves and aims at a sideline; `team` says
## which way away is (0 left: -1; 1 right: +1).
static func read_intent(team := 0) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	if Input.is_action_pressed("move_left"):
		it.move_x = -1
	elif Input.is_action_pressed("move_right"):
		it.move_x = 1
	if Input.is_action_pressed("move_up"):
		it.move_y = -1
	elif Input.is_action_pressed("move_down"):
		it.move_y = 1
	it.aim_x = (1 if team else -1) if Input.is_action_pressed("short") else it.move_x
	it.aim_y = it.move_y
	var b := _pressed("hit")
	var a := _pressed("drive")
	var y := _pressed("soft")
	var x := _pressed("slice")
	it.hit_pressed = 1 if (a or b or y or x) else 0
	it.hit_held = 1 if (Input.is_action_pressed("hit") or Input.is_action_pressed("drive")
		or Input.is_action_pressed("soft") or Input.is_action_pressed("slice")) else 0
	if a:
		it.shot = K.SHOT_DRIVE
	elif y:
		it.shot = K.SHOT_SOFT
	elif x:
		it.shot = K.SHOT_SLICE
	it.pause_pressed = 1 if _pressed("start") else 0
	return it


## Reading pads directly (2P, and multiplayer's four pads; PORT-16). For
## now every pad is taken to be an Xbox pad on its default layout: A hit,
## B drive, X soft, Menu pause, D-pad or left stick to move. Remaps apply
## to P1's input map only (design/KNOWN_ISSUES.md #39).
##
## Tests and the e2e can stand in fake pads: `fake_pads` maps a device id
## to {"buttons": [JOY_BUTTON_*...], "x": axis, "y": axis}; while it isn't
## empty, the real pads are ignored.
static var fake_pads := {}


static func connected_pads() -> Array:
	if not fake_pads.is_empty():
		var ids := fake_pads.keys()
		ids.sort()
		return ids
	return Input.get_connected_joypads()


static func joy_button(device: int, b: int) -> bool:
	if not fake_pads.is_empty():
		return fake_pads.has(device) and b in fake_pads[device].get("buttons", [])
	return Input.is_joy_button_pressed(device, b)


static func joy_axis(device: int, axis: int) -> float:
	if not fake_pads.is_empty():
		if not fake_pads.has(device):
			return 0.0
		return float(fake_pads[device].get("x" if axis == JOY_AXIS_LEFT_X else "y", 0.0))
	return Input.get_joy_axis(device, axis)


static var _pad_prev := {}

## A pad's intent this frame (2P and multiplayer). Menu is the pause.
static func read_pad_intent(device: int, team := 0) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	if not device in connected_pads():
		return it
	var ax := joy_axis(device, JOY_AXIS_LEFT_X)
	var ay := joy_axis(device, JOY_AXIS_LEFT_Y)
	if joy_button(device, JOY_BUTTON_DPAD_LEFT) or ax < -0.4:
		it.move_x = -1
	elif joy_button(device, JOY_BUTTON_DPAD_RIGHT) or ax > 0.4:
		it.move_x = 1
	if joy_button(device, JOY_BUTTON_DPAD_UP) or ay < -0.4:
		it.move_y = -1
	elif joy_button(device, JOY_BUTTON_DPAD_DOWN) or ay > 0.4:
		it.move_y = 1
	var short := joy_button(device, JOY_BUTTON_LEFT_SHOULDER) or joy_button(device, JOY_BUTTON_RIGHT_SHOULDER)
	it.aim_x = (1 if team else -1) if short else it.move_x
	it.aim_y = it.move_y
	var held := {}
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
		held[b] = joy_button(device, b)
	var prev: Dictionary = _pad_prev.get(device, {})
	var pressed := {}
	for b in held:
		pressed[b] = held[b] and not prev.get(b, false)
	_pad_prev[device] = held
	var swings := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
	it.hit_pressed = 1 if swings.any(func(b): return pressed[b]) else 0
	it.hit_held = 1 if swings.any(func(b): return held[b]) else 0
	if pressed[JOY_BUTTON_B]:
		it.shot = K.SHOT_DRIVE
	elif pressed[JOY_BUTTON_X]:
		it.shot = K.SHOT_SOFT
	elif pressed[JOY_BUTTON_Y]:
		it.shot = K.SHOT_SLICE
	it.pause_pressed = 1 if pressed[JOY_BUTTON_START] else 0
	return it


## A pad's menu presses as SNES pad bits (like pad_bits), plus LB / RB:
## [newly pressed, held]. Its own edge memory, apart from the intents'.
const PAD_L := 0x0020
const PAD_R := 0x0010
static var _menu_prev := {}

static func pad_menu_bits(device: int) -> Array:
	var held := 0
	if device in connected_pads():
		var ax := joy_axis(device, JOY_AXIS_LEFT_X)
		var ay := joy_axis(device, JOY_AXIS_LEFT_Y)
		for pair in [[JOY_BUTTON_DPAD_UP, Practice.PAD_UP], [JOY_BUTTON_DPAD_DOWN, Practice.PAD_DOWN],
				[JOY_BUTTON_DPAD_LEFT, Practice.PAD_LEFT], [JOY_BUTTON_DPAD_RIGHT, Practice.PAD_RIGHT],
				[JOY_BUTTON_A, Practice.PAD_B], [JOY_BUTTON_B, PAD_A | Practice.PAD_Y], [JOY_BUTTON_X, Practice.PAD_Y],
				[JOY_BUTTON_START, Practice.PAD_START], [JOY_BUTTON_LEFT_SHOULDER, PAD_L],
				[JOY_BUTTON_RIGHT_SHOULDER, PAD_R]]:
			if joy_button(device, pair[0]):
				held |= pair[1]
		if ay < -0.5:
			held |= Practice.PAD_UP
		elif ay > 0.5:
			held |= Practice.PAD_DOWN
		if ax < -0.5:
			held |= Practice.PAD_LEFT
		elif ax > 0.5:
			held |= Practice.PAD_RIGHT
	var pressed := held & ~int(_menu_prev.get(device, 0))
	_menu_prev[device] = held
	return [pressed, held]
