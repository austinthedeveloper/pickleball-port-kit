## Achievements (port ADR-077): goals across the game, each unlocked once
## and saved with the day (save.data["achievements"]: id -> "YYYY-MM-DD").
## A match is checked as it ends (MatchEnd); STORY, PICKLEBALL 101 and the
## bracket unlock theirs where they finish. An unlock is announced through
## `on_unlock` (main shows it as a toast); RECORDS > ACHIEVEMENTS lists them.
## They count for P1's side, in matches the records count (not the demo,
## online or practice).
class_name Achievements
extends RefCounted

## [id, name, how it's earned] (the bitmap fonts: caps, digits, !?.,:-'/%+)
const LIST := [
	["pickled", "PICKLED", "WIN WITHOUT LETTING THEM SCORE"],
	["first_win", "FIRST DINK", "WIN A MATCH"],
	["ace", "ACE!", "WIN A POINT WITH A SERVE THEY CAN'T TOUCH"],
	["marathon", "MARATHON", "PLAY A 20-SHOT RALLY"],
	["on_fire", "ON FIRE", "PLAY A 30-SHOT RALLY"],
	["comeback", "COMEBACK KID", "WIN AFTER TRAILING BY 5"],
	["mad_scientist", "MAD SCIENTIST", "WIN WITH 3 MODIFIERS ON"],
	["globetrotter", "GLOBETROTTER", "WIN AT EVERY VENUE"],
	["ladder", "TOP OF THE LADDER", "BEAT ALL EIGHT TEAMS IN A ROW"],
	["cover_man", "THE COVER MAN", "BEAT DALE DAWSON"],
	["champion", "CHAMPION", "WIN A TOURNAMENT"],
	["park_saved", "PARK SAVED", "FINISH STORY: SAVE THE PARK"],
	["scholar", "SCHOLAR", "FINISH EVERY PICKLEBALL 101 LESSON"],
]
const MARATHON_SHOTS := 20
const ON_FIRE_SHOTS := 30
const COMEBACK_BEHIND := 5
const MAD_MODIFIERS := 3

## Called with the id of each new unlock (main sets it: the toast).
static var on_unlock: Callable


static func count() -> int:
	return LIST.size()


static func entry(id: String) -> Array:
	for a in LIST:
		if a[0] == id:
			return a
	return []


static func _store(save: SaveGame) -> Dictionary:
	if not save.data.has("achievements") or typeof(save.data["achievements"]) != TYPE_DICTIONARY:
		save.data["achievements"] = {}
	return save.data["achievements"]


static func unlocked(save: SaveGame, id: String) -> bool:
	return save != null and _store(save).has(id)


static func unlocked_count(save: SaveGame) -> int:
	if save == null:
		return 0
	return LIST.filter(func(a): return _store(save).has(a[0])).size()


## The day it was unlocked, or "".
static func day(save: SaveGame, id: String) -> String:
	return String(_store(save).get(id, "")) if save else ""


## Unlocks `id` (once): true if it's new. Announced through on_unlock.
static func unlock(save: SaveGame, id: String) -> bool:
	if save == null or entry(id).is_empty() or unlocked(save, id):
		return false
	_store(save)[id] = Time.get_date_string_from_system()
	if on_unlock.is_valid():
		on_unlock.call(id)
	return true


## The RECORDS row: "3/13".
static func label(save: SaveGame) -> String:
	return "%d/%d" % [unlocked_count(save), count()]


## A finished match, for P1's side (team 0). `m`: {won, scores [ours,
## theirs], aces, longest, behind (the most P1's side trailed by), mods,
## opponent, venue, cleared}. The new unlocks, in LIST's order.
static func check_match(save: SaveGame, m: Dictionary) -> Array:
	if save == null:
		return []
	var won: bool = m["won"]
	var got := []
	var want := func(id: String, cond: bool) -> void:
		if cond and unlock(save, id):
			got.append(id)
	if won:
		var venues: Array = save.data.get("achievement_venues", [])
		if not String(m["venue"]) in venues:
			venues.append(String(m["venue"]))
		save.data["achievement_venues"] = venues
	var mods := 0
	for row in Settings.MOD_ROWS:
		if int(m["mods"]) & int(row[2]):
			mods += 1
	want.call("pickled", won and int(m["scores"][1]) == 0)
	want.call("first_win", won)
	want.call("ace", int(m["aces"]) > 0)
	want.call("marathon", int(m["longest"]) >= MARATHON_SHOTS)
	want.call("on_fire", int(m["longest"]) >= ON_FIRE_SHOTS)
	want.call("comeback", won and int(m["behind"]) >= COMEBACK_BEHIND)
	want.call("mad_scientist", won and mods >= MAD_MODIFIERS)
	want.call("globetrotter", won and Settings.venues().all(func(v): return v in save.data["achievement_venues"]))
	want.call("ladder", bool(m.get("cleared", false)))
	want.call("cover_man", won and int(m["opponent"]) == Opponents.DAWSON)
	return got
