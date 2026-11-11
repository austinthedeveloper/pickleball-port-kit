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


# --- Sharing (PORT-156, PORT-157, port ADR-112) -------------------------------------

## A replay as bytes to share (a file, or a code through the relay): MAGIC,
## then the dictionary as var_to_bytes, gzipped. A few KB a rally.
const MAGIC := "PB94R1"
const MAX_BYTES := 36 * 1024     ## what an import takes (the relay's cap, as base64, is 48 KB)


static func to_bytes(data: Dictionary) -> PackedByteArray:
	var out := MAGIC.to_ascii_buffer()
	out.append_array(var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP))
	return out


## The bytes of a saved replay ("" name: none).
static func bytes_of(name: String) -> PackedByteArray:
	var d := load_replay(name)
	return to_bytes(d) if not d.is_empty() else PackedByteArray()


## Bytes back to a replay: [the dictionary, ""] or [{}, why not, as the
## screen says it]. Nothing but plain data comes in (no objects).
static func from_bytes(b: PackedByteArray) -> Array:
	var m := MAGIC.to_ascii_buffer()
	if b.size() <= m.size() or b.size() > MAX_BYTES or b.slice(0, m.size()) != m:
		return [{}, "NOT A REPLAY"]
	var raw := b.slice(m.size()).decompress_dynamic(1 << 20, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return [{}, "DAMAGED"]
	var d: Variant = bytes_to_var(raw)
	if not d is Dictionary:
		return [{}, "DAMAGED"]
	for k in ["cfg", "inputs", "ops", "rally"]:
		if not (d as Dictionary).has(k):
			return [{}, "DAMAGED"]
	if not d["inputs"] is PackedInt32Array or not d["rally"] is Dictionary or not d["cfg"] is Dictionary:
		return [{}, "DAMAGED"]
	var why := refusal(d)
	return [{} if why != "" else d, why]


## Why this build can't play a replay ("" when it can): it plays only on
## the sim it was recorded on (ADR-081).
static func refusal(d: Dictionary) -> String:
	if int(d.get("format", 0)) != FORMAT:
		return "ANOTHER VERSION'S"
	var t := int(d.get("tuning", -1))
	if t < K.TUNING_VERSION:
		return "FROM AN OLDER GAME"
	if t > K.TUNING_VERSION:
		return "UPDATE TO WATCH IT"
	return ""


## Bytes into REPLAYS: [its name, ""] or ["", why not].
static func import_bytes(b: PackedByteArray) -> Array:
	var r := from_bytes(b)
	if r[1] != "":
		return ["", r[1]]
	if full():
		return ["", "FULL: DELETE ONE"]
	var name := save(r[0])
	return [name, "" if name != "" else "COULDN'T SAVE IT"]


static var export_dir := ""      ## tests point it elsewhere ("": Downloads, else user://exports/)


## EXPORT: a replay as a file the player can send: in Downloads on a
## desktop (else the game's exports folder), downloaded on the Web. What
## the row says: IN DOWNLOADS, IN EXPORTS, DOWNLOADED, or why not.
static func export_replay(name: String) -> String:
	var b := bytes_of(name)
	if b.is_empty():
		return "NOTHING THERE"
	var file := "pickleball94-replay-%s%s" % [name.get_basename(), EXT]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(b, file, "application/octet-stream")
		return "DOWNLOADED"
	var where := export_dir
	var said := "IN EXPORTS"
	if where == "":
		where = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		said = "IN DOWNLOADS"
		if where == "" or not DirAccess.dir_exists_absolute(where):
			where = ProjectSettings.globalize_path("user://exports")
			said = "IN EXPORTS"
	DirAccess.make_dir_recursive_absolute(where)
	var f := FileAccess.open(where.path_join(file), FileAccess.WRITE)
	if f == null:
		return "COULDN'T WRITE IT"
	f.store_buffer(b)
	f.close()
	last_export = where.path_join(file)
	return said


static var last_export := ""     ## the last EXPORT's path (tests, the import's default folder)


## IMPORT: a replay file from disk into REPLAYS.
static func import_file(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ["", "COULDN'T OPEN IT"]
	if f.get_length() > MAX_BYTES:
		f.close()
		return ["", "NOT A REPLAY"]
	var b := f.get_buffer(f.get_length())
	f.close()
	return import_bytes(b)


## REPLAYS' row for a replay: "12 SHOTS", and "DOUBLES 10/22" (or OLD VERSION).
static func row_label(r: Dictionary) -> String:
	return "%d SHOTS" % int(r["shots"])


static func row_value(r: Dictionary) -> String:
	if not r["playable"]:
		return "OLD VERSION"
	var local := int(r["saved"]) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(local)
	return "%s %d/%d" % ["DOUBLES" if r["doubles"] else "SINGLES", t["month"], t["day"]]
