## The story wrapper's words (ADR-023 ladder, ADR-026 cards, ADR-048
## quips). Display only: nothing here touches the sim. Pure, so tests can
## check the rules.
class_name Story
extends RefCounted

const QUIPS_PATH := "res://data/quips.json"
const QUIP_PERIOD := 3          ## about one lost point in three

static var _generic: Dictionary = {}
var _last_quip := ""
var _quip_next := [0, 0]
var _quip_stride := [1, 1]
var _quip_left := [0, 0]


static func generic() -> Dictionary:
	if _generic.is_empty():
		_generic = JSON.parse_string(FileAccess.get_file_as_string(QUIPS_PATH))
	return _generic


## Team colour of a ladder team (its first HUD colour, 5-bit RGB).
static func team_color(opponent: int) -> Color:
	var hud: Array = Opponents.team(opponent)["hud"][0]
	return Color(hud[0] / 31.0, hud[1] / 31.0, hud[2] / 31.0)


## Who is named on the intro card: singles the captain, doubles the team.
static func card_name(opponent: int, doubles: bool) -> String:
	var t := Opponents.team(opponent)
	return String(t["team"]) if doubles else String(t["players"][0]["name"])


static func intro_line(opponent: int) -> String:
	return String(Opponents.team(opponent)["intro"])


static func rung_line(opponent: int) -> String:
	if opponent == Opponents.DAWSON:
		return "THE COVER MATCH"         # port ADR-066: off the ladder
	return "LADDER %d OF %d" % [opponent + 1, Opponents.count()]


## The opponent's line under the result: the taunt if they won, the
## concession if you did.
static func result_line(opponent: int, you_won: bool) -> String:
	return String(Opponents.team(opponent)["concede" if you_won else "taunt"])


## The side that lost a point sometimes says something (ADR-048): a ladder
## team its own lines, a human side or the default CPU the generic ones;
## about a third of points (frame count mod 3), never the same line twice
## in a row. Returns "" for no quip.
func quip(cfg: SimTypes.MatchConfig, losing_team: int, frame: int) -> String:
	if frame % QUIP_PERIOD != 0:
		return ""
	var lines: Array
	var human: bool = cfg.human[losing_team * 2] != 0
	if losing_team == 1 and not human and cfg.opponent >= 0:
		lines = Opponents.team(cfg.opponent)["quips"]
	elif human:
		lines = generic()["player"]
	else:
		lines = generic()["cpu"]
	# SNES ADR-063 (story_quip): a shuffled deck per side. Each pass starts
	# somewhere and steps by an odd stride, both from the frame count, so
	# it says every line before any again, in a new order each pass. No RNG.
	var n := lines.size()                 # 16, a power of two (the stride's
	var side := 1 if losing_team else 0   # odd steps visit every line)
	if _quip_left[side] == 0:
		_quip_next[side] = (frame >> 2) & (n - 1)
		_quip_stride[side] = ((frame >> 6) & (n - 1)) | 1
		_quip_left[side] = n
		# not on the line the last pass ended on: that one comes last
		if lines[_quip_next[side]] == _last_quip:
			_quip_next[side] = (_quip_next[side] + _quip_stride[side]) & (n - 1)
	var pick: int = _quip_next[side]
	_quip_next[side] = (pick + _quip_stride[side]) & (n - 1)
	_quip_left[side] -= 1
	_last_quip = lines[pick]
	return _last_quip
