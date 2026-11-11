## The WEEKLY CHALLENGE (port ADR-109, PORT-159): a set match each week
## (data/challenges.json, the Nth for ISO week N, round the list), the
## same for everyone, with a goal; met, it scores, and the week's best is
## kept (save.data["weekly"], a new key with a harmless default) and goes
## to the week's board (Boards). No server is needed to play.
class_name Weekly
extends RefCounted

const DATA := "res://data/challenges.json"
static var _list: Array = []
static var date_override := 0         ## the tests' "today" (YYYYMMDD)


static func challenges() -> Array:
	if _list.is_empty():
		_list = JSON.parse_string(FileAccess.get_file_as_string(DATA))["list"]
	return _list


static func today() -> int:
	return date_override if date_override > 0 else RoadTrip.today()


static func week(date := 0) -> Array:
	return Boards.iso_week(date if date > 0 else today())


static func current(date := 0) -> Dictionary:
	var w := week(date)
	return challenges()[int(w[1]) % challenges().size()]


static func board(date := 0) -> String:
	return Boards.week_board(week(date))


## The challenge's match: you (MATCH SETUP's 1P, or the career player)
## against its team, its points and modifiers, at MEDIUM.
static func config(c: Dictionary, p1: Dictionary, me: Career.Player = null) -> SimTypes.MatchConfig:
	var choice := p1 if me == null else PlayerSelect.new_choice(me.shirt, me.variant, me.paddle)
	var cfg := Settings.config_for(bool(c["doubles"]), int(c["opponent"]), K.DIFFICULTY_MEDIUM, int(c["points"]), choice)
	var bits := 0
	for id: String in c["modifiers"]:
		for row: Array in Settings.MOD_ROWS:
			if row[0] == id:
				bits |= int(row[2])
	cfg.modifiers = bits
	cfg.assist = K.ASSIST_OFF                 # the same match for everyone
	if me:
		cfg.set_career(me)
	return cfg


## A finished match against the goal: {met, score, detail}. `won`, the
## points for and against, your aces and the match's longest rally.
static func judge(c: Dictionary, won: bool, ours: int, theirs: int, aces: int, longest: int) -> Dictionary:
	var n := int(c["n"])
	var met := won
	match String(c["goal"]):
		"MARGIN":
			met = won and ours - theirs >= n
		"SHUTOUT":
			met = won and theirs <= n
		"ACES":
			met = won and aces >= n
		"RALLY":
			met = won and longest >= n
	var score := 0
	if met:
		score = (ours - theirs) * 100 + aces * 50 + longest * 10
	return {"met": met, "score": score, "detail": "%d-%d  %s" % [ours, theirs, "DONE" if met else "MISSED"]}


static func meta(save: SaveGame) -> Dictionary:
	var def := {"board": "", "best": -1, "detail": "", "tries": 0, "done": 0}
	if save == null:
		return def
	if not save.data.has("weekly") or typeof(save.data["weekly"]) != TYPE_DICTIONARY:
		save.data["weekly"] = def
	var m: Dictionary = save.data["weekly"]
	for k in def:
		if not m.has(k):
			m[k] = def[k]
	if String(m["board"]) != board():
		m["board"] = board()                # a new week: a new best
		m["best"] = -1
		m["detail"] = ""
		m["tries"] = 0
	return m


## A try at this week's challenge: kept if it's the week's best. True if
## the goal was met and it's a new best (worth posting).
static func record(save: SaveGame, result: Dictionary) -> bool:
	var m := meta(save)
	m["tries"] = int(m["tries"]) + 1
	if not bool(result["met"]):
		return false
	var first := int(m["best"]) < 0
	if int(result["score"]) <= int(m["best"]):
		return false
	m["best"] = int(result["score"])
	m["detail"] = String(result["detail"])
	if first:
		m["done"] = int(m["done"]) + 1
	return true


## PLAY > WEEKLY's value: the week's best, or the challenge's name.
static func title_label(save: SaveGame) -> String:
	var m := meta(save)
	return "BEST %d" % int(m["best"]) if int(m["best"]) >= 0 else String(current()["name"])
