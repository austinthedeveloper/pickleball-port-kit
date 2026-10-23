## Generic pads (port ADR-082): a pad SDL doesn't know (a cheap SNES USB
## pad, "USB Gamepad") reaches Godot raw: its own button numbers, the
## D-pad as a hat or two axes. CONTROLLER > MAP BUTTONS asks for each of
## its buttons (PadMapper) and the answers become an SDL-style mapping
## string, given to Input.add_joy_mapping, so the pad is a standard one
## from then on: the input map, the prompts and 2P's pad reading need
## nothing of their own. Kept per pad model (its GUID) in the save's
## settings.pad_maps, and given to Input again at load and whenever a pad
## connects.
class_name PadMaps
extends RefCounted

## The mapping's outputs, by the standard button each one is.
const SDL_NAMES := {JOY_BUTTON_A: "a", JOY_BUTTON_B: "b", JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y",
	JOY_BUTTON_BACK: "back", JOY_BUTTON_START: "start", JOY_BUTTON_LEFT_SHOULDER: "leftshoulder",
	JOY_BUTTON_RIGHT_SHOULDER: "rightshoulder", JOY_BUTTON_DPAD_UP: "dpup",
	JOY_BUTTON_DPAD_DOWN: "dpdown", JOY_BUTTON_DPAD_LEFT: "dpleft", JOY_BUTTON_DPAD_RIGHT: "dpright"}
## The raw hat's directions (Godot's HatMask, as SDL's), by the D-pad
## button an unmapped pad's hat arrives as.
const HAT := {JOY_BUTTON_DPAD_UP: 1, JOY_BUTTON_DPAD_RIGHT: 2, JOY_BUTTON_DPAD_DOWN: 4,
	JOY_BUTTON_DPAD_LEFT: 8}

## guid -> {"name": the pad's name, "map": {output: source}}; a source is
## "b3" (button 3), "-a1" / "+a1" (half of axis 1) or "h0.4" (hat 0 down).
static var maps := {}
## The mapping strings given to Input, last first (tests read it).
static var applied: Array = []


## The mapping string for one pad: "GUID,Name,a:b2,b:b1,...". Moving
## also takes the stick (axes 0 and 1) when the D-pad didn't use them.
static func mapping_string(guid: String, entry: Dictionary) -> String:
	var parts := [guid, _plain(String(entry.get("name", "PAD")))]
	var m: Dictionary = entry.get("map", {})
	var keys := m.keys()
	keys.sort()
	var axes_used := false
	for k in keys:
		var src := String(m[k])
		parts.append("%s:%s" % [k, src])
		axes_used = axes_used or src in ["-a0", "+a0", "-a1", "+a1"]
	if not axes_used:
		parts.append_array(["leftx:a0", "lefty:a1"])
	return ",".join(parts)


## A name a mapping string can carry (no commas) and the fonts can draw.
static func _plain(n: String) -> String:
	var out := ""
	for c in n.to_upper().replace(",", " "):
		out += c if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in " -.'/+" else " "
	out = out.strip_edges()
	return out if out != "" else "PAD"


## The pad's name for a row (the fonts' characters, at most `width`).
static func display_name(device: int, width := 18) -> String:
	if device < 0:
		return "NONE"
	return short_name(Input.get_joy_name(device), width)


## A pad's reported name in the fonts' characters, cut to `width` with "..".
static func short_name(raw: String, width: int) -> String:
	var n := _plain(raw)
	return n if n.length() <= width else n.substr(0, width - 2).strip_edges() + ".."


## Gives one pad's mapping to Input (any old one for its GUID goes first,
## so a connect finds just this one); a connected pad of that model
## changes at once.
static func apply(guid: String) -> void:
	if not maps.has(guid):
		return
	var s := mapping_string(guid, maps[guid])
	Input.remove_joy_mapping(guid)
	Input.add_joy_mapping(s, true)
	applied.push_front(s)


static func apply_all() -> void:
	for guid in maps:
		apply(guid)


## A pad connected: its saved mapping, if it has one.
static func on_connect(device: int) -> void:
	if not device in Input.get_connected_joypads():
		return
	var guid := Input.get_joy_guid(device)
	if guid != "" and maps.has(guid):
		apply(guid)


static func store(guid: String, pad_name: String, map: Dictionary) -> void:
	maps[guid] = {"name": _plain(pad_name), "map": map.duplicate()}
	apply(guid)


## CLEAR MAPPING: the pad is raw again.
static func clear(guid: String) -> void:
	if maps.erase(guid):
		Input.remove_joy_mapping(guid)


static func mapped(device: int) -> bool:
	return device in Input.get_connected_joypads() and maps.has(Input.get_joy_guid(device))


## A pad to draw as a SNES pad: one we mapped, or a connected one nobody
## knows (port ADR-082).
static func generic(device: int) -> bool:
	if mapped(device):
		return true
	return device in Input.get_connected_joypads() and not Input.is_joy_known(device)


## The pad CONTROLLER's rows mean: the one last touched, else the first
## pad nobody knows, else the first pad (-1: none).
static func target_pad() -> int:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	if GameControls.last_device == GameControls.PAD and GameControls.last_pad in pads:
		return GameControls.last_pad
	for d in pads:
		if not Input.is_joy_known(d):
			return d
	return pads[0]


const NO_PAD := "NO PAD"
const STANDARD := "STANDARD"
const UNKNOWN := "UNKNOWN"
const MAPPED := "MAPPED"

## MAP BUTTONS' value: a pad SDL knows needs no map (its buttons can be
## rebound on CONTROLS); an unknown one does.
static func status(device: int) -> String:
	if device < 0:
		return NO_PAD
	if mapped(device):
		return MAPPED
	return STANDARD if Input.is_joy_known(device) else UNKNOWN


## What a mapped pad's raw event becomes: the events Input sends instead,
## by the same rules as Godot's mapping (a button, a half axis past 0.5,
## a hat direction). Tests check a map against it; Input does the real
## work.
static func translate(map: Dictionary, raw: InputEvent) -> Array:
	var out := []
	for k in map:
		var target: int = SDL_NAMES.find_key(k) if SDL_NAMES.values().has(k) else -1
		if target < 0:
			continue
		var src := String(map[k])
		var e := InputEventJoypadButton.new()
		e.device = raw.device
		e.button_index = target
		if raw is InputEventJoypadButton:
			var as_src := ("h0.%d" % HAT[raw.button_index]) if HAT.has(raw.button_index) \
				else "b%d" % raw.button_index
			if as_src == src:
				e.pressed = raw.pressed
				out.append(e)
		elif raw is InputEventJoypadMotion and src.ends_with("a%d" % raw.axis) and src.length() > 2:
			var sign := -1.0 if src[0] == "-" else 1.0
			e.pressed = raw.axis_value * sign > 0.5
			out.append(e)
	return out


static func to_save() -> Dictionary:
	return maps.duplicate(true)


## Loads saved maps (malformed ones are dropped) and gives them to Input.
static func from_save(d: Variant) -> void:
	maps = {}
	if typeof(d) != TYPE_DICTIONARY:
		return
	for guid in d:
		var e: Variant = d[guid]
		if typeof(e) != TYPE_DICTIONARY or typeof(e.get("map")) != TYPE_DICTIONARY:
			continue
		var m := {}
		for k in e["map"]:
			if String(k) in SDL_NAMES.values():
				m[String(k)] = str(e["map"][k])
		if not m.is_empty():
			maps[str(guid)] = {"name": _plain(str(e.get("name", "PAD"))), "map": m}
	apply_all()
