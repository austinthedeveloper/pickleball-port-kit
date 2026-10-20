## CPU personalities (ADR-023) from data/opponents.json, plus the difficulty
## adjustment (ADR-025, options.c). Data, not code: the ladder is rows of AI
## knobs.
class_name Opponents
extends RefCounted

const PATH := "res://data/opponents.json"
## Dale Dawson (port ADR-066): the bonus team after the ladder, port-only.
const DAWSON_PATH := "res://data/dawson.json"
const DAWSON := 8
## STORY's partner (ADR-069): PEPPER, from data/story.json, after Dawson; a
## partner only (the partner style), never an opponent.
const STORY_PATH := "res://data/story.json"
const PEPPER := 9

static var _data: Dictionary = {}
static var _default: SimTypes.AiStyle
static var _partner: SimTypes.AiStyle
static var _teams: Array = []      # [{team, venue, players: [{name, style: AiStyle, ...}]}]


static func _load() -> void:
	if not _data.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())
	_default = SimTypes.AiStyle.from_dict(_data["default_style"])
	_partner = SimTypes.AiStyle.from_dict(_data["partner_style"])
	for t in _data["opponents"]:
		var players := []
		for p in t["players"]:
			var q: Dictionary = p.duplicate()
			q["style_obj"] = SimTypes.AiStyle.from_dict(p["style"])
			players.append(q)
		var team: Dictionary = t.duplicate()
		team["players"] = players
		_teams.append(team)
	var dawson: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DAWSON_PATH))
	var dale: Dictionary = dawson["players"][0].duplicate()
	dale["style_obj"] = SimTypes.AiStyle.from_dict(dale["style"])
	dawson["players"] = [dale]
	assert(_teams.size() == DAWSON, "Dawson follows the ladder")
	_teams.append(dawson)
	var pepper: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))["partner"].duplicate()
	pepper["style_obj"] = _partner
	_teams.append({"team": pepper["name"], "venue": "PARK", "intro": "", "taunt": "", "concede": "",
		"quips": [], "players": [pepper]})


static func default_style() -> SimTypes.AiStyle:
	_load()
	return _default.copy()


static func partner_style() -> SimTypes.AiStyle:
	_load()
	return _partner.copy()


## The ladder's teams (Dale Dawson and Pepper, after them, aren't).
static func count() -> int:
	_load()
	return DAWSON


## A team to play: the ladder's, or Dale Dawson.
static func exists(i: int) -> bool:
	_load()
	return i >= 0 and i < _teams.size()


## A team of one (Dale Dawson): in doubles his partner's slot sits out.
static func solo(i: int) -> bool:
	return exists(i) and team(i)["players"].size() == 1


static func team(i: int) -> Dictionary:
	_load()
	return _teams[i]


## A named skin's three 5-bit colours (palette roles 2-4).
static func skin(name: String) -> Array:
	_load()
	return _data["skins"].get(name, _data["skins"]["light"])


## The play style of a CPU slot (match.c match_slot_style): an opponent's
## captain/partner on slots 2-3, an open play partner's captain on slot 1
## (ADR-034), the partner style for a CPU partnering a human, else the
## default CPU.
static func slot_style(cfg: SimTypes.MatchConfig, slot: int) -> SimTypes.AiStyle:
	_load()
	if slot == 1 and cfg.partner >= 0 and cfg.partner < _teams.size():
		return _teams[cfg.partner]["players"][0]["style_obj"]
	if cfg.opponent >= 0 and cfg.opponent < _teams.size() and slot >= 2:
		var members: Array = _teams[cfg.opponent]["players"]
		return members[mini(slot - 2, members.size() - 1)]["style_obj"]
	if cfg.human[slot ^ 1] and not cfg.human[slot]:
		return _partner
	return _default


## A slot's point celebration (match.c match_slot_celebrate, SNES
## ADR-064): an opponent's or open play partner's own ("thumbs_up",
## "flex", "en_garde"), else the cheer (humans, the default CPU).
static func slot_celebrate(cfg: SimTypes.MatchConfig, slot: int) -> String:
	_load()
	if cfg.human[slot]:
		return "cheer"
	if slot == 1 and cfg.partner >= 0 and cfg.partner < _teams.size():
		return String(_teams[cfg.partner]["players"][0].get("celebrate", "cheer"))
	if cfg.opponent >= 0 and cfg.opponent < _teams.size() and slot >= 2:
		var members: Array = _teams[cfg.opponent]["players"]
		return String(members[mini(slot - 2, members.size() - 1)].get("celebrate", "cheer"))
	return "cheer"


## A CPU opposing the humans plays this much better or worse (options.c).
static func apply_difficulty(s: SimTypes.AiStyle, difficulty: int) -> void:
	var late := s.late_period
	match difficulty:
		K.DIFFICULTY_KID:
			if late:
				s.late_period = maxi(2, late / 3)
			s.reaction += 10
			s.speed = s.speed - 4 if s.speed > 16 else 12
		K.DIFFICULTY_EASY:
			if late:
				s.late_period = maxi(2, late / 2)
			s.reaction += 5
			s.speed = s.speed - 2 if s.speed > 14 else 12
		K.DIFFICULTY_HARD:
			if late:
				s.late_period = mini(30, late + late / 2 + 2)
			s.reaction = s.reaction - 3 if s.reaction > 3 else 0
			if s.speed < K.PLAYER_MAX_SPEED_FP:
				s.speed += 1
