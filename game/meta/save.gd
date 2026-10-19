## The save (playbook §6, ADR-021 recipe): two copies, each with a magic
## number, a sequence counter, and a checksum. Writes go to the older copy,
## so a torn write loses only that write. Loading takes the newest valid
## copy, migrates it to the current layout, and writes both.
##
## Layouts are frozen: v1 (settings only, the first port build), v2
## (records and the ladder), v3 (practice, ADR-028: its settings and
## the best streaks), and v4 (PORT-08: the win streak, shutouts, the
## record against each opponent, and record initials, ADR-040), and v5
## (PORT-21: the career players, ADR-047). Every change adds a version and a migration
## and a test that loads the old image (playbook rule 4).
class_name SaveGame
extends RefCounted

const MAGIC := "PB94"
const VERSION := 6   ## v6: a ladder place per mode (SNES ADR-055)
## Records beaten by the match in progress (save_new_records: session
## only, never saved). ADR-040.
const NEW_STREAK := 1
const NEW_RALLY := 2
const INITIALS := 3
const FILES := ["save_a.json", "save_b.json"]

## Where saves live; tests point it elsewhere before the game starts.
static var default_dir := "user://"
var dir := default_dir
var seq := 0
var data: Dictionary = {}
var new_records := 0
## The best streak was claimed during the current, unbroken run: the next
## wins extend it under the same initials without asking (session only).
var streak_held := false
## The career players (ADR-047), kept in data["career"] when written.
var career := Career.new()


static func defaults() -> Dictionary:
	return {
		"settings": {"venue": 0, "difficulty": K.DIFFICULTY_MEDIUM, "points": 1,
			"players": 1, "opponent": -2, "camera": 1, "camera_rev": 1, "mods": 0, "sound": 0,
			"practice": Practice.DEFAULTS.duplicate(),
			# menus (PORT-03): modifiers as bits (-1: take the old "mods"
			# preset), window options. New keys fill from these defaults on
			# load, so no layout change.
			"mod_bits": -1, "fullscreen": 0, "integer_scale": 1,
			"player": [0, 0, Paddles.STANDARD],  # Player Select: 1P colour, body, paddle
			"court": [0, 0, 0, 0],  # COURT: surface, kitchen, surround, lines presets
			"time": 0,  # COURT TIME: DAY, DUSK, NIGHT (ADR-045)
			# PORT-12: accessibility, and remapped controls ({} = defaults)
			"shake": 1, "flash": 1, "hud_large": 0, "serve_assist": 0, "bindings": {},
			"vibration": 1,  # PORT-15: controller rumble
			"pad_glyphs": 0,  # PORT-28: BUTTON ICONS, AUTO
			"net_address": "",  # PORT-31: the last address joined
			"music": Music.DEFAULT_VOLUME},  # PORT-22: MUSIC, 0 (OFF) .. 10
		"records": {"singles_wins": 0, "singles_losses": 0, "doubles_wins": 0,
			"doubles_losses": 0, "ladder_rung": 0, "ladder_clears": 0,
			# v6 (SNES ADR-055): ladder_rung is singles' place, this doubles'
			"ladder_doubles": 0,
			"longest_rally": 0, "practice_best": 0,
			"practice_zone_best": [0, 0, 0, 0],
			"streak": 0, "best_streak": 0, "shutouts": 0,
			"vs": _vs_zero(),
			# PORT-13: totals from the match stats (new keys fill in on load)
			"points_won": 0, "points_lost": 0, "aces": 0, "winners": 0,
			# PORT-25: tournaments finished, won, and the best finish (0 none,
			# 1 quarterfinal .. 4 champion)
			"cup_runs": 0, "cups": 0, "cup_best": 0,
			# PORT-30: HOW TO PLAY's lessons done, one bit each
			"lessons": 0},
		## who holds a record ("" = nobody, shown ---)
		"initials": {"best_streak": "", "longest_rally": ""},
		## the three career players and the active one (ADR-047, v5)
		"career": Career.new().to_dict(),
		## the tournament in play (PORT-25; {} = none), filled in on load
		"tournament": {"bracket": {}, "couch": {}},   # PORT-29: the couch cup's
	}


## Wins and losses against each ladder team: [[w, l], ...].
static func _vs_zero() -> Array:
	var out := []
	for i in Opponents.count():
		out.append([0, 0])
	return out


static func checksum(payload: String) -> int:
	return payload.hash() & 0x7fffffff


## v1 -> v2: records arrive (all zero, rung 0); settings carry over.
## v2 -> v3: practice arrives (the default drill, bests at 0); the rest
## carries over.
## v3 -> v4: the streaks, shutouts and per-opponent records start at 0
## and nobody holds a record until it is beaten again (as ADR-040's v8).
## v4 -> v5: everything carries over; no career players yet, nobody
## active (as the SNES layout 11 -> 12).
static func migrate(version: int, d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	if version < 2:
		out["records"] = defaults()["records"].duplicate()
		if not out.has("settings"):
			out["settings"] = {}
	if version < 3:
		out["settings"]["practice"] = Practice.DEFAULTS.duplicate()
		out["records"]["practice_best"] = 0
		out["records"]["practice_zone_best"] = [0, 0, 0, 0]
	if version < 4:
		out["records"]["streak"] = 0
		out["records"]["best_streak"] = 0
		out["records"]["shutouts"] = 0
		out["records"]["vs"] = _vs_zero()
		out["initials"] = defaults()["initials"].duplicate()
	if version < 5:
		out["career"] = Career.new().to_dict()
	if version < 6:
		# one shared rung before: both modes keep it, so nobody loses a place
		out["records"]["ladder_doubles"] = int(out["records"].get("ladder_rung", 0))
	# 0.9.1: CAMERA's default went from OFF to 50%. A save from before
	# (no camera_rev) still on OFF moves to 50% once; a choice made after
	# stays. Not a layout change: the key's meaning is the same.
	if out.has("settings") and not out["settings"].has("camera_rev"):
		if int(out["settings"].get("camera", 0)) == 0:
			out["settings"]["camera"] = 1
		out["settings"]["camera_rev"] = 1
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
		career = Career.from_dict(data["career"])
		return
	seq = int(best["seq"])
	var v := int(best["version"])
	data = migrate(v, best["data"])
	career = Career.from_dict(data["career"])
	if v != VERSION:
		save_game()
		save_game()


## Sequence numbers wrap at 2^16: newer is ahead by less than half.
static func _newer(a: int, b: int) -> bool:
	return ((a - b) & 0xffff) != 0 and ((a - b) & 0xffff) < 0x8000


func save_game() -> void:
	seq = (seq + 1) & 0xffff
	data["career"] = career.to_dict()
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


# --- Tournament (PORT-25) ---------------------------------------------------

## The tournament in play, or null: the solo one, or the couch cup's
## (`key` "couch", PORT-29).
func tournament(key := "bracket") -> Tournament:
	return Tournament.from_dict(data["tournament"].get(key, {}))


func store_tournament(t: Tournament, key := "bracket") -> void:
	data["tournament"][key] = t.to_dict() if t else {}


const CUP_FINISHES := ["", "QUARTERFINALIST", "SEMIFINALIST", "FINALIST"]

## A tournament over for you (Tournament.finish()): counted once.
func record_cup(finish: String) -> void:
	if finish == "":
		return
	var r: Dictionary = data["records"]
	r["cup_runs"] = int(r["cup_runs"]) + 1
	var place := 4 if finish.begins_with("CHAMPION") else maxi(0, CUP_FINISHES.find(finish))
	if place == 4:
		r["cups"] = int(r["cups"]) + 1
	r["cup_best"] = maxi(int(r["cup_best"]), place)


## A HOW TO PLAY lesson finished (PORT-30).
func finish_lesson(i: int) -> void:
	var r: Dictionary = data["records"]
	r["lessons"] = int(r["lessons"]) | (1 << i)


func lessons_done() -> int:
	var n := 0
	for i in Tutorial.LESSONS.size():
		if int(data["records"]["lessons"]) & (1 << i):
			n += 1
	return n


## The first lesson not yet done (0 when all are).
func next_lesson() -> int:
	for i in Tutorial.LESSONS.size():
		if not (int(data["records"]["lessons"]) & (1 << i)):
			return i
	return 0


# --- Records ---------------------------------------------------------------

## A finished match against the CPU (save_record_match): wins and losses
## by mode and against the opponent, the win streak (a new best clears
## its initials and asks for them, unless this run already holds it),
## and shutouts. 2P matches count only the rally (record_rally).
func record_match(doubles: bool, won: bool, opponent := -1, points_against := -1) -> void:
	var r: Dictionary = data["records"]
	var key := ("doubles_" if doubles else "singles_") + ("wins" if won else "losses")
	r[key] = int(r[key]) + 1
	if opponent >= 0 and opponent < r["vs"].size():
		r["vs"][opponent][0 if won else 1] += 1
	if won:
		r["streak"] = int(r["streak"]) + 1
		if int(r["streak"]) > int(r["best_streak"]):
			r["best_streak"] = r["streak"]
			# extending one's own record keeps its initials
			if not streak_held or data["initials"]["best_streak"] == "":
				data["initials"]["best_streak"] = ""
				new_records |= NEW_STREAK
				streak_held = true
		if points_against == 0:
			r["shutouts"] = int(r["shutouts"]) + 1
	else:
		r["streak"] = 0
		streak_held = false


## A finished match's stats into the running totals (P1's side).
func record_stats(st: MatchStats) -> void:
	var r: Dictionary = data["records"]
	r["points_won"] = int(r["points_won"]) + int(st.teams[0]["points"])
	r["points_lost"] = int(r["points_lost"]) + int(st.teams[1]["points"])
	r["aces"] = int(r["aces"]) + int(st.teams[0]["aces"])
	r["winners"] = int(r["winners"]) + st.winners(0)


## A rally longer than the record: it's the record now, and its initials
## clear until entered. Returns true if it was.
func record_rally(length: int) -> bool:
	var r: Dictionary = data["records"]
	if length > int(r["longest_rally"]):
		r["longest_rally"] = length
		data["initials"]["longest_rally"] = ""
		new_records |= NEW_RALLY
		return true
	return false


## The initials for every record this match beat (save_set_initials).
func set_initials(letters: String) -> void:
	if new_records & NEW_STREAK:
		data["initials"]["best_streak"] = letters
	if new_records & NEW_RALLY:
		data["initials"]["longest_rally"] = letters
	new_records = 0


## A match left early (RESTART, MAIN MENU) keeps its numbers but asks for
## no initials.
func drop_new_records() -> void:
	new_records = 0


## Erases the records (and who holds them); the settings stay.
func erase_records() -> void:
	data["records"] = defaults()["records"]
	data["initials"] = defaults()["initials"]
	new_records = 0
	streak_held = false


## The ladder place in a mode (SNES ADR-055: singles and doubles each have
## their own; out of range reads as the first).
func ladder(doubles := false) -> int:
	var rung := int(data["records"]["ladder_doubles" if doubles else "ladder_rung"])
	return rung if rung >= 0 and rung < Opponents.count() else 0


## A ladder win moves that mode to the next rung; beating the last clears
## the ladder (either mode counts) and starts over (ADR-023/026). Returns
## true on a clear.
func advance_ladder(count: int, doubles := false) -> bool:
	var r: Dictionary = data["records"]
	var key := "ladder_doubles" if doubles else "ladder_rung"
	var rung := ladder(doubles) + 1
	if rung >= count:
		r[key] = 0
		r["ladder_clears"] = int(r["ladder_clears"]) + 1
		return true
	r[key] = rung
	return false


## Quitting a ladder match (pause, MAIN MENU) starts that mode's ladder
## over (SNES ADR-055); a loss keeps the place. True if it moved.
func quit_ladder(doubles := false) -> bool:
	if ladder(doubles) == 0:
		return false
	data["records"]["ladder_doubles" if doubles else "ladder_rung"] = 0
	return true


# --- Practice (ADR-028) --------------------------------------------------------

## The saved drill (shot, target, rate, zone), each made valid.
func practice_settings() -> Array:
	var saved: Variant = data["settings"].get("practice")
	var values: Array = saved.duplicate() if typeof(saved) == TYPE_ARRAY and saved.size() == Practice.ROWS \
		else Practice.DEFAULTS.duplicate()
	Practice.Edit.new().begin(values)
	return values


## The saved best streak for a zone (ANY: the plain streak).
func practice_saved_best(zone: int) -> int:
	var r: Dictionary = data["records"]
	zone = Practice.practice_zone(zone)
	if zone == Practice.ZONE_ANY:
		return int(r["practice_best"])
	return int(r["practice_zone_best"][zone - 1])


## Leaving practice (practice_finish): a new best streak for the session's
## zone is saved. Returns true if it was.
func finish_practice(zone: int, best: int) -> bool:
	if best <= practice_saved_best(zone):
		return false
	zone = Practice.practice_zone(zone)
	if zone == Practice.ZONE_ANY:
		data["records"]["practice_best"] = best
	else:
		data["records"]["practice_zone_best"][zone - 1] = best
	save_game()
	return true


## A practice session on the saved drill, with its zone's saved best.
func practice_config(difficulty: int) -> SimTypes.MatchConfig:
	var settings := practice_settings()
	var cfg := SimTypes.MatchConfig.practice_session(settings,
		practice_saved_best(settings[Practice.ROW_ZONE]))
	cfg.difficulty = difficulty
	return cfg
