## The save (playbook §6, ADR-021 recipe): two copies, each with a magic
## number, a sequence counter, and a checksum. Writes go to the older copy,
## so a torn write loses only that write. Loading takes the newest valid
## copy, migrates it to the current layout, and writes both.
##
## Layouts are frozen: v1 (settings only, the first port build) and v2
## (records and the ladder). Every change adds a version and a migration
## and a test that loads the old image (playbook rule 4).
class_name SaveGame
extends RefCounted

const MAGIC := "PB94"
const VERSION := 2
const FILES := ["save_a.json", "save_b.json"]

## Where saves live; tests point it elsewhere before the game starts.
static var default_dir := "user://"
var dir := default_dir
var seq := 0
var data: Dictionary = {}


static func defaults() -> Dictionary:
	return {
		"settings": {"venue": 0, "difficulty": K.DIFFICULTY_MEDIUM, "points": 1,
			"players": 1, "opponent": -2, "camera": 0},
		"records": {"singles_wins": 0, "singles_losses": 0, "doubles_wins": 0,
			"doubles_losses": 0, "ladder_rung": 0, "ladder_clears": 0,
			"longest_rally": 0},
	}


static func checksum(payload: String) -> int:
	return payload.hash() & 0x7fffffff


## v1 -> v2: records arrive (all zero, rung 0); settings carry over.
static func migrate(version: int, d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	if version < 2:
		out["records"] = defaults()["records"].duplicate()
		if not out.has("settings"):
			out["settings"] = {}
	var def := defaults()
	for section in def:
		if not out.has(section):
			out[section] = {}
		for k in def[section]:
			if not out[section].has(k):
				out[section][k] = def[section][k]
	return out


## Godot's JSON reads every number as a float: the checksum covers the
## payload's exact text, and numbers come back as ints (every saved value
## is an int).
static func _ints(v: Variant) -> Variant:
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_DICTIONARY:
		var d := {}
		for k in v:
			d[k] = _ints(v[k])
		return d
	if typeof(v) == TYPE_ARRAY:
		return v.map(_ints)
	return v


func _read(name: String) -> Variant:
	var path := dir + name
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var parsed: Dictionary = json.data
	if parsed.get("magic", "") != MAGIC or typeof(parsed.get("payload")) != TYPE_STRING:
		return null
	if int(parsed.get("checksum", -1)) != checksum(parsed["payload"]):
		return null
	var v := int(parsed.get("version", 0))
	if v < 1 or v > VERSION:
		return null
	var inner := JSON.new()
	if inner.parse(parsed["payload"]) != OK or typeof(inner.data) != TYPE_DICTIONARY:
		return null
	return {"seq": int(parsed.get("seq", 0)), "version": v, "data": _ints(inner.data)}


## Loads the newest valid copy (by sequence, with wrap), migrating it.
func load_game() -> void:
	var best: Variant = null
	for f in FILES:
		var c = _read(f)
		if c == null:
			continue
		if best == null or _newer(int(c["seq"]), int(best["seq"])):
			best = c
	if best == null:
		seq = 0
		data = defaults()
		return
	seq = int(best["seq"])
	var v := int(best["version"])
	data = migrate(v, best["data"])
	if v != VERSION:
		save_game()
		save_game()


## Sequence numbers wrap at 2^16: newer is ahead by less than half.
static func _newer(a: int, b: int) -> bool:
	return ((a - b) & 0xffff) != 0 and ((a - b) & 0xffff) < 0x8000


func save_game() -> void:
	seq = (seq + 1) & 0xffff
	var payload := JSON.stringify(data, "", true)
	var body := {"magic": MAGIC, "version": VERSION, "seq": seq,
		"checksum": checksum(payload), "payload": payload}
	var target := _older_file()
	var f := FileAccess.open(dir + target, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(body))


func _older_file() -> String:
	var a = _read(FILES[0])
	var b = _read(FILES[1])
	if a == null:
		return FILES[0]
	if b == null:
		return FILES[1]
	return FILES[1] if _newer(int(a["seq"]), int(b["seq"])) else FILES[0]


# --- Records ---------------------------------------------------------------

func record_match(doubles: bool, won: bool) -> void:
	var r: Dictionary = data["records"]
	var key := ("doubles_" if doubles else "singles_") + ("wins" if won else "losses")
	r[key] = int(r[key]) + 1


func record_rally(length: int) -> bool:
	var r: Dictionary = data["records"]
	if length > int(r["longest_rally"]):
		r["longest_rally"] = length
		return true
	return false


## A ladder win moves to the next rung; beating the last clears the ladder
## and starts over (ADR-023/026). Returns true on a clear.
func advance_ladder(count: int) -> bool:
	var r: Dictionary = data["records"]
	var rung := int(r["ladder_rung"]) + 1
	if rung >= count:
		r["ladder_rung"] = 0
		r["ladder_clears"] = int(r["ladder_clears"]) + 1
		return true
	r["ladder_rung"] = rung
	return false
