## MAP BUTTONS (port ADR-082): one pad's raw buttons, axes and hat, asked
## for one action at a time ("PRESS HIT"), each answer the standard button
## that action has by default (HIT is the south button, SHORT the left
## shoulder...), so a mapped pad plays like any other and its prompts are
## right. The SNES button each one is on the original pad is named too.
## Feed it the pad's input events; the last answer stores the map
## (PadMaps). A pad mapped before is raw again while it's asked.
class_name PadMapper
extends RefCounted

## [action, its default standard button, the SNES pad's button].
const STEPS := [["move_up", JOY_BUTTON_DPAD_UP, "UP"], ["move_down", JOY_BUTTON_DPAD_DOWN, "DOWN"],
	["move_left", JOY_BUTTON_DPAD_LEFT, "LEFT"], ["move_right", JOY_BUTTON_DPAD_RIGHT, "RIGHT"],
	["hit", JOY_BUTTON_A, "B"], ["drive", JOY_BUTTON_B, "A"], ["soft", JOY_BUTTON_X, "Y"],
	["slice", JOY_BUTTON_Y, "X"], ["short", JOY_BUTTON_LEFT_SHOULDER, "L"],
	["special", JOY_BUTTON_RIGHT_SHOULDER, "R"], ["start", JOY_BUTTON_START, "START"]]
## An axis counts as pressed past PRESS and released under RELEASE; an
## axis resting far from 0 (an analog trigger) is never asked about.
const PRESS := 0.6
const RELEASE := 0.3

const IGNORED := 0
const NEXT := 1
const DONE := 2

var device := -1
var guid := ""
var pad_name := ""
var step := 0
var map := {}                    ## SDL output name -> source ("b3", "-a1", "h0.1")
var _rest := {}                  ## axis -> its value when asking began
var _down := {}                  ## axis -> the side pressed past PRESS (until released)
## The last answer, given: the map waits for it to be let go of, so no
## input is held down across the change (Input keeps raw state).
var _finishing := false
var _last := ""


## Starts asking `dev` (its name and GUID from Input unless given: tests).
func begin(dev: int, id := "", name := "") -> void:
	device = dev
	guid = id if id != "" else Input.get_joy_guid(dev)
	pad_name = name if name != "" else Input.get_joy_name(dev)
	step = 0
	map = {}
	_down = {}
	_rest = {}
	_finishing = false
	if PadMaps.maps.has(guid):
		Input.remove_joy_mapping(guid)   # the raw pad, while asking
	_release_actions()
	for axis in 10:
		_rest[axis] = Input.get_joy_axis(dev, axis)


func done() -> bool:
	return step >= STEPS.size()


## Waiting for the last answer to be let go of.
func finishing() -> bool:
	return _finishing


## Nothing stays held from before the pad's buttons changed meaning.
static func _release_actions() -> void:
	for a in GameControls.ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


func action() -> String:
	return STEPS[mini(step, STEPS.size() - 1)][0]


## What an event from the pad answers ("" if it isn't a press): a button,
## a hat direction (an unmapped pad's hat arrives as the D-pad buttons),
## or half an axis.
func source_of(event: InputEvent) -> String:
	if event.device != device:
		return ""
	if event is InputEventJoypadButton:
		if not event.pressed:
			return ""
		if PadMaps.HAT.has(event.button_index):
			return "h0.%d" % PadMaps.HAT[event.button_index]
		return "b%d" % event.button_index
	if event is InputEventJoypadMotion:
		var axis: int = event.axis
		var v: float = event.axis_value
		if absf(float(_rest.get(axis, 0.0))) >= 0.5:
			return ""
		if absf(v) < RELEASE:
			_down.erase(axis)
			return ""
		var side := -1 if v < 0 else 1
		if absf(v) < PRESS or int(_down.get(axis, 0)) == side:
			return ""
		_down[axis] = side
		return ("-a%d" if v < 0 else "+a%d") % axis
	return ""


## One event: IGNORED, NEXT (the step answered), or DONE (the last
## answer let go of: the map is stored and given to Input).
func feed(event: InputEvent) -> int:
	if _finishing:
		if not _let_go(event):
			return IGNORED
		_finishing = false
		PadMaps.store(guid, pad_name, map)
		_release_actions()
		return DONE
	if done():
		return IGNORED
	var src := source_of(event)
	if src == "" or src in map.values():
		return IGNORED                   # a second step can't take the same input
	map[PadMaps.SDL_NAMES[STEPS[step][1]]] = src
	step += 1
	if done():
		_finishing = true
		_last = src
	return NEXT


## The last answer released: its button up, its hat direction up, or its
## axis back near the middle.
func _let_go(event: InputEvent) -> bool:
	if event.device != device:
		return false
	if event is InputEventJoypadButton and not event.pressed:
		var as_src := ("h0.%d" % PadMaps.HAT[event.button_index]) if PadMaps.HAT.has(event.button_index) \
			else "b%d" % event.button_index
		return as_src == _last
	if event is InputEventJoypadMotion and _last.length() > 2 and _last.substr(2) == str(event.axis):
		return absf(event.axis_value) < RELEASE
	return false


## Backspace: ask the last step again.
func undo() -> void:
	if step == 0:
		return
	_finishing = false
	step -= 1
	map.erase(PadMaps.SDL_NAMES[STEPS[step][1]])


## Esc: the pad's old map (if it had one) comes back.
func cancel() -> void:
	PadMaps.apply(guid)
	_finishing = false
	step = STEPS.size() + 1


## A step's answer as the CONTROLLER screen shows it.
static func source_name(src: String) -> String:
	if src.begins_with("b"):
		return "BUTTON " + src.substr(1)
	if src.begins_with("h"):
		return {"1": "HAT UP", "2": "HAT RIGHT", "4": "HAT DOWN", "8": "HAT LEFT"}.get(src.get_slice(".", 1), "HAT")
	if src.length() > 2:
		return "AXIS %s %s" % [src.substr(2), src[0]]
	return src
