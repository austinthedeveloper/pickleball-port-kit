## Saved replays (PORT-69, ADR-081): rallies kept to watch again, from the
## pause menu's SAVE LAST RALLY. Each is a file of its own under `dir`
## (not in the save: a match's inputs would grow every save write),
## gzipped `store_var` of Highlight.export's dictionary, so its ints stay
## ints and the playback's snapshot check holds. A replay plays only on
## the sim it was recorded on (`tuning`); REPLAYS lists the others as OLD.
class_name SavedReplays
extends RefCounted

const FORMAT := 1
const MAX := 6                    ## REPLAYS' rows; SAVE LAST RALLY says FULL past it
const EXT := ".pbr"

static var dir := "user://replays/"      ## tests point it elsewhere
static var _cache: Array = []
static var _cached := false


## The saved replays, newest first: {name, saved, shots, doubles, teams,
## venue, playable}.
static func list() -> Array:
	if _cached:
		return _cache
	_cache = []
	_cached = true
	if not DirAccess.dir_exists_absolute(dir):
		return _cache
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(EXT):
			continue
		var d := load_replay(f)
		if d.is_empty():
			continue
		_cache.append({"name": f, "saved": int(d.get("saved", 0)),
			"shots": int(d["rally"].get("shots", 0)), "doubles": bool(d.get("doubles", false)),
			"teams": d.get("teams", ["", ""]), "venue": str(d.get("venue", "")),
			"playable": playable(d)})
	_cache.sort_custom(func(a, b): return a["saved"] > b["saved"] \
		or (a["saved"] == b["saved"] and a["name"] > b["name"]))
	return _cache


static func full() -> bool:
	return list().size() >= MAX


## Whether this build's sim can play it (the one it was recorded on).
static func playable(d: Dictionary) -> bool:
	return int(d.get("format", 0)) == FORMAT and int(d.get("tuning", -1)) == K.TUNING_VERSION


## Writes one; its file name, or "" when full or the write failed.
static func save(data: Dictionary) -> String:
	if full():
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var stem := str(int(data.get("saved", 0)))
	var name := stem + EXT
	var n := 1
	while FileAccess.file_exists(dir + name):
		n += 1
		name = "%s-%d%s" % [stem, n, EXT]
	var f := FileAccess.open_compressed(dir + name, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return ""
	f.store_var(data)
	f.close()
	_cached = false
	return name


## One replay's dictionary; empty when it's missing or not a replay.
static func load_replay(name: String) -> Dictionary:
	var f := FileAccess.open_compressed(dir + name, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return {}
	var d: Variant = f.get_var(false)
	f.close()
	if not d is Dictionary:
		return {}
	for k in ["cfg", "inputs", "ops", "rally"]:
		if not d.has(k):
			return {}
	if not d["inputs"] is PackedInt32Array or not d["rally"] is Dictionary:
		return {}
	return d


static func remove(name: String) -> void:
	DirAccess.remove_absolute(dir + name)
	_cached = false


## REPLAYS' row for a replay: "12 SHOTS", and "DOUBLES 10/22" (or OLD VERSION).
static func row_label(r: Dictionary) -> String:
	return "%d SHOTS" % int(r["shots"])


static func row_value(r: Dictionary) -> String:
	if not r["playable"]:
		return "OLD VERSION"
	var local := int(r["saved"]) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(local)
	return "%s %d/%d" % ["DOUBLES" if r["doubles"] else "SINGLES", t["month"], t["day"]]
