## STORY: SAVE THE PARK (port ADR-069): the chapters in data/story.json,
## each a ladder team at its venue and time with its twist; the match a
## chapter plays; and the progress, saved. The scenes are view/story_scene.gd;
## scenes/main.gd runs the chapter, its match and what follows.
class_name StoryMode
extends RefCounted

const PATH := "res://data/story.json"
const CHAPTERS := 8
const LINE_MAX := 46             ## HUD characters a line, at most
const LINES_MAX := 3

## The twists story.json may name.
const TWISTS := {"MOD_BIG_BALL": K.MOD_BIG_BALL, "MOD_FAST_BALL": K.MOD_FAST_BALL,
	"MOD_WIN_BY_2": K.MOD_WIN_BY_2, "MOD_LAVA": K.MOD_LAVA, "MOD_GHOST_BALL": K.MOD_GHOST_BALL,
	"MOD_POPCORN": K.MOD_POPCORN, "MOD_ICE": K.MOD_ICE, "MOD_GLOW": K.MOD_GLOW,
	"MOD_INVERSE": K.MOD_INVERSE, "MOD_MOON": K.MOD_MOON, "MOD_BOUNCY": K.MOD_BOUNCY,
	"MOD_WIND": K.MOD_WIND}

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func chapter(i: int) -> Dictionary:
	return data()["chapters"][clampi(i, 0, CHAPTERS - 1)]


static func villain() -> String:
	return String(data()["villain"])


static func company() -> String:
	return String(data()["company"])


## The partner's look and name (Pepper), opponents.json's player schema.
static func partner() -> Dictionary:
	return data()["partner"]


## A chapter's twist: its MOD_* bits.
static func twist_bits(i: int) -> int:
	var bits := 0
	for name in chapter(i)["twist"]:
		bits |= int(TWISTS[String(name)])
	return bits


## The twist as the chapter card says it ("TONIGHT: WIND"), or "".
static func twist_label(i: int) -> String:
	var names := []
	var bits := twist_bits(i)
	for row in Settings.MOD_ROWS:
		if bits & int(row[2]):
			names.append(String(row[1]))
	return "" if names.is_empty() else "TODAY: " + ", ".join(names)


static func venue(i: int) -> String:
	return String(chapter(i)["venue"])


static func time(i: int) -> int:
	return int(chapter(i)["time"])


## The chapter's match: doubles, you and Pepper against its team at its
## venue, with its twist; MATCH SETUP's difficulty and points; your look
## (`p1`, a Player Select choice) or the active career player's.
static func config(i: int, p1: Dictionary, career: Career.Player = null) -> SimTypes.MatchConfig:
	var team := int(chapter(i)["team"])
	var me := p1 if career == null else PlayerSelect.new_choice(career.shirt, career.variant, career.paddle)
	var cfg := Settings.config_for(true, team, Settings.difficulty_i, Settings.POINTS[Settings.points_i], me)
	cfg.set_partner(Opponents.PEPPER)
	cfg.modifiers = twist_bits(i)
	if career:
		cfg.set_career(career)                 # ADR-047: as the career player
	return cfg


# --- Progress (save.data["story"]) ---------------------------------------------------

## The chapter you're on (0 to CHAPTERS - 1).
static func current(save: SaveGame) -> int:
	if save == null:
		return 0
	return clampi(int(save.data.get("story", {}).get("chapter", 0)), 0, CHAPTERS - 1)


## How many times the park has been saved.
static func cleared(save: SaveGame) -> int:
	if save == null:
		return 0
	return maxi(0, int(save.data.get("story", {}).get("cleared", 0)))


static func _story(save: SaveGame) -> Dictionary:
	if not save.data.has("story") or typeof(save.data["story"]) != TYPE_DICTIONARY:
		save.data["story"] = {"chapter": 0, "cleared": 0}
	return save.data["story"]


## A chapter won: on to the next; the last saves the park and starts the
## story over. True when that was the last.
static func win(save: SaveGame, i: int) -> bool:
	var s := _story(save)
	if i >= CHAPTERS - 1:
		s["chapter"] = 0
		s["cleared"] = cleared(save) + 1
		return true
	s["chapter"] = i + 1
	return false


## The title's STORY value: the chapter, or that the park is saved.
static func label(save: SaveGame) -> String:
	if current(save) == 0 and cleared(save) > 0:
		return "PARK SAVED!"
	return "CHAPTER %d/%d" % [current(save) + 1, CHAPTERS]
