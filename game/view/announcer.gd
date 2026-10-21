## The announcer's voice (PORT-52, ADR-076): the recorded clips in
## assets/audio/announcer (data/announcer.json has each one's length).
## One Announcer lives on main for the session, like Music; what to say is
## a match's Commentary's call. It says one thing at a time: a line
## waiting behind a busy voice goes stale and is dropped (a call about the
## last shot is no use two shots later), and one of a higher priority cuts
## a lower one off. While it talks, the music ducks and the crowd's bed
## dips. ANNOUNCER (ON or OFF), VOICE VOLUME and COMMENTARY (how much it
## says) are on OPTIONS, saved in Settings; SOUND OFF silences it. Headless, nothing
## plays, but the timing (and `said`, for the tests) still runs.
class_name Announcer
extends Node

const DIR := "res://assets/audio/announcer/"
const INDEX := "res://data/announcer.json"
const VOLUMES := 10
const DEFAULT_VOLUME := 8
const BASE_DB := 1.0               ## a touch over the effects: the voice is the point
const GAP := 0.05                  ## seconds between the pieces of a score call
const LIGHT := 0
const NORMAL := 1
const LOTS := 2
const CHATTER_NAMES := ["LIGHT", "NORMAL", "LOTS"]

## Priorities: a higher one cuts a lower one off.
const LOW := 0                     ## a shot call, a pun
const MID := 1                     ## how a point ended, a score call
const HIGH := 2                    ## match point, an ace, a long rally
const TOP := 3                     ## the match's start and end, replays

static var enabled := true          ## ANNOUNCER: ON or OFF
static var volume := DEFAULT_VOLUME  ## VOICE VOLUME, 1 .. VOLUMES
static var chatter := NORMAL
static var current: Announcer      ## the session's (null in most tests)

var clips := {}                    ## id -> seconds
var families := {}                 ## family -> [ids]: "ace" -> ace_1 .. ace_5
var silent := false                ## headless: no playback, the timing still runs
var said: Array = []               ## every id started, oldest first (for the tests)
var rng := RandomNumberGenerator.new()
var _player: AudioStreamPlayer
var _queue: Array = []             ## the rest of the line playing: ids
var _busy := 0.0                   ## seconds left on what's playing
var _priority := -1
var _waiting := {}                 ## a line held for the voice: {ids, priority, until}
var _last := {}                    ## family -> the id said last
var _family := {}                  ## id -> its family


func _init() -> void:
	current = self
	silent = DisplayServer.get_name() == "headless"
	rng.randomize()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	clips = data["clips"]
	var counts := {}
	for id in clips:
		counts[_stem(id)] = int(counts.get(_stem(id), 0)) + 1
	for id in clips:
		# a trailing number is a variant only beside its siblings: ace_1 ..
		# ace_5 are "ace"; rally_25 and mod_win_by_2 are themselves
		var fam: String = _stem(id) if int(counts[_stem(id)]) > 1 else id
		_family[id] = fam
		if not families.has(fam):
			families[fam] = []
		families[fam].append(id)
	for fam in families:
		families[fam].sort()
	_player = AudioStreamPlayer.new()
	add_child(_player)


func _exit_tree() -> void:
	if current == self:
		current = null


static func _stem(id: String) -> String:
	var parts := id.split("_")
	if parts.size() > 1 and parts[-1].is_valid_int():
		return "_".join(parts.slice(0, parts.size() - 1))
	return id


## A clip's family: "ace_3" -> "ace"; "num_04_up", "rally_25" are their own.
func family_of(id: String) -> String:
	return _family.get(id, id)


## No voice at all: ANNOUNCER OFF, or SOUND OFF.
static func muted() -> bool:
	return not enabled or volume <= 0 or Sfx.setting == AudioMap.SOUND_OFF


static func volume_name() -> String:
	return "OFF" if volume <= 0 else "%d%%" % (volume * 100 / VOLUMES)     # as MUSIC shows it


## The session's announcer, saying a family's line (see say()); nothing
## without one.
static func speak(family: String, priority := MID, wait := 0.0) -> bool:
	return current.say(family, priority, wait) if current else false


static func speak_ids(ids: Array, priority := MID, wait := 0.0) -> bool:
	return current.say_ids(ids, priority, wait) if current else false


func busy() -> bool:
	return _busy > 0.0


## A line from `family` (a variant other than the last one said). Said now
## if the voice is free or this outranks what's playing; else it waits up
## to `wait` seconds (0: now or never). True if said or waiting.
func say(family: String, priority := MID, wait := 0.0) -> bool:
	if not families.has(family):
		return false
	var last: String = _last.get(family, "")
	var pool: Array = families[family]
	if pool.size() > 1:
		pool = pool.filter(func(x): return x != last)    # never the one said last
	return say_ids([pool[rng.randi_range(0, pool.size() - 1)]], priority, wait)


## Several clips back to back, as one line (a score call: "four ... two").
func say_ids(ids: Array, priority := MID, wait := 0.0) -> bool:
	for id in ids:
		if not clips.has(id):
			return false
	if muted():
		return false
	if busy() and priority <= _priority:
		if wait <= 0.0:
			return false
		if _waiting.is_empty() or priority >= int(_waiting["priority"]):
			_waiting = {"ids": ids, "priority": priority, "until": wait}
		return true
	_start(ids, priority)
	return true


func _start(ids: Array, priority: int) -> void:
	_queue = ids.duplicate()
	_priority = priority
	_next()


func _next() -> void:
	var id: String = _queue.pop_front()
	_last[family_of(id)] = id
	said.append(id)
	_busy = float(clips[id]) + (GAP if not _queue.is_empty() else 0.0)
	Music.voice_duck(_busy + 0.2)
	Sfx.voice_until = Time.get_ticks_msec() + int((_busy + 0.2) * 1000)
	if silent or not is_inside_tree():
		return
	_player.stream = load(DIR + id + ".wav")
	_player.volume_db = BASE_DB + linear_to_db(float(volume) / VOLUMES)
	_player.play()


## Stops the voice (a screen leaving mid-line).
func hush() -> void:
	_queue.clear()
	_waiting = {}
	_busy = 0.0
	_priority = -1
	if _player:
		_player.stop()


func _process(delta: float) -> void:
	tick(delta)


## The clock: the next piece of a line, or a waiting one.
func tick(delta: float) -> void:
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			if not _queue.is_empty():
				_next()
				return
			_busy = 0.0
			_priority = -1
	if not _waiting.is_empty():
		_waiting["until"] = float(_waiting["until"]) - delta
		if float(_waiting["until"]) < 0.0:
			_waiting = {}
		elif not busy():
			var w := _waiting
			_waiting = {}
			_start(w["ids"], int(w["priority"]))
