## The story wrapper's words (ADR-023 ladder, ADR-026 cards, ADR-048
## quips). Display only: nothing here touches the sim. Pure, so tests can
## check the rules.
class_name Story
extends RefCounted

const QUIPS_PATH := "res://data/quips.json"
const QUIP_PERIOD := 3          ## about one lost point in three

static var _generic: Dictionary = {}
var _last_quip := ""


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
	var line: String = lines[(frame / QUIP_PERIOD) % lines.size()]
	if line == _last_quip:
		line = lines[(frame / QUIP_PERIOD + 1) % lines.size()]
	_last_quip = line
	return line
