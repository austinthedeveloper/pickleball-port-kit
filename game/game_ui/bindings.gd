## Remappable controls (PORT-12): P1's keys and pad button for each
## action, applied to the input map and kept in the save's
## settings.bindings. A rebind that takes another action's key or button
## swaps it over, so no action is ever left unbound. The pad sticks stay
## on the moves; 2P's pad keeps the default layout.
class_name Bindings
extends RefCounted

const ACTIONS := ["hit", "drive", "soft", "start", "move_up", "move_down", "move_left", "move_right"]
const NAMES := {"hit": "HIT", "drive": "DRIVE", "soft": "SOFT", "start": "START",
	"move_up": "UP", "move_down": "DOWN", "move_left": "LEFT", "move_right": "RIGHT"}

## action -> {"keys": [physical keycodes], "pad": JOY_BUTTON_*}
static var current := defaults()


static func defaults() -> Dictionary:
	var out := {}
	for a in ACTIONS:
		out[a] = {"keys": GameControls.ACTIONS[a].duplicate(), "pad": GameControls.PAD_BUTTONS[a]}
	return out


## Rebuilds the input map's key and pad-button events from `current`.
static func apply() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.4)
		for e in InputMap.action_get_events(a):
			if e is InputEventKey or e is InputEventJoypadButton:
				InputMap.action_erase_event(a, e)
		for code in current[a]["keys"]:
			var k := InputEventKey.new()
			k.physical_keycode = code
			InputMap.action_add_event(a, k)
		var b := InputEventJoypadButton.new()
		b.button_index = current[a]["pad"]
		b.device = GameControls.p1_device()
		InputMap.action_add_event(a, b)
	GameControls.binding_serial += 1


## The action's main key becomes `code` (its old main key is dropped); an
## action that had `code` takes that old key instead, so nothing is left
## unbound.
static func rebind_key(action: String, code: int) -> void:
	var mine: Array = current[action]["keys"]
	var old: int = mine[0] if not mine.is_empty() else 0
	for a in ACTIONS:
		if a == action:
			continue
		var keys: Array = current[a]["keys"]
		var at := keys.find(code)
		if at < 0:
			continue
		if old != 0 and old != code and not old in keys:
			keys[at] = old
		else:
			keys.remove_at(at)
	var rest := mine.slice(1).filter(func(k): return k != code and not _taken(k, action))
	current[action]["keys"] = [code] + rest
	apply()


static func _taken(code: int, except: String) -> bool:
	for a in ACTIONS:
		if a != except and code in current[a]["keys"]:
			return true
	return false


## The action's pad button becomes `button`; an action that had it swaps.
static func rebind_pad(action: String, button: int) -> void:
	var old: int = current[action]["pad"]
	for a in ACTIONS:
		if a != action and current[a]["pad"] == button:
			current[a]["pad"] = old
	current[action]["pad"] = button
	apply()


static func reset() -> void:
	current = defaults()
	apply()


static func is_default() -> bool:
	return current == defaults()


## The row's value: the main key and the pad button, as prompts show them.
static func describe(action: String) -> String:
	var keys: Array = current[action]["keys"]
	var k := Prompts.key_name(keys[0]) if not keys.is_empty() else "-"
	return "%s / %s" % [k, Prompts.label(action, GameControls.PAD)]


static func to_save() -> Dictionary:
	return current.duplicate(true)


## Loads saved bindings (anything missing or malformed stays default).
static func from_save(d: Variant) -> void:
	current = defaults()
	if typeof(d) == TYPE_DICTIONARY:
		for a in ACTIONS:
			var b: Variant = d.get(a)
			if typeof(b) != TYPE_DICTIONARY:
				continue
			var keys: Variant = b.get("keys")
			if typeof(keys) == TYPE_ARRAY and not keys.is_empty():
				current[a]["keys"] = keys.map(func(k): return int(k))
			if b.has("pad"):
				current[a]["pad"] = int(b["pad"])
	apply()
