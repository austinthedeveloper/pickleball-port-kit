## The soundtrack (PORT-22, ADR-052). The SNES game had no music (the
## ambience stood in, ADR-029/031); these tracks are new, made by
## audio/music/make_music.py. One Music node lives on main for the whole
## session: each screen names its loop (music_track()), and a change of
## screen crossfades to it (equal power, two decks). A match's end plays a
## stinger over the loop's quick fade, then the result is quiet until the
## next screen. The effects come first: the music ducks under the applause
## and the whistle, follows SOUND (OFF silences it), and has its own level
## (MUSIC on OPTIONS, saved in Settings). Headless, nothing plays, but the
## state (which track, the fades) still runs, for the tests.
class_name Music
extends Node

const DIR := "res://assets/audio/"
## Loops by name: the title, the park in open play, and a match at each venue.
const LOOPS := {"title": "music_title", "park": "music_park",
	"match_park": "music_match_park", "match_lakeside": "music_match_lakeside",
	"match_sunset": "music_match_sunset", "match_dinosaur": "music_match_dinosaur",
	"match_space": "music_match_space", "match_undersea": "music_match_undersea"}
const STINGERS := {"won": "music_won", "lost": "music_lost", "cleared": "music_cleared"}
const VOLUMES := 10                ## MUSIC steps above OFF
const BASE_DB := -9.0              ## the soundtrack sits this far under the effects
const CROSSFADE := 1.6             ## seconds a change of screen takes
const STING_FADE := 0.35           ## the loop's fade under a stinger
const DUCK_DB := -9.0              ## under the applause and the whistle
const DUCK_HOLD := 1.0
const DUCK_ATTACK := 0.12
const DUCK_RELEASE := 1.2
const DUCKED_BY := ["applause", "whistle"]

const DEFAULT_VOLUME := 7
## MUSIC (0 = OFF .. VOLUMES), shared by every screen.
static var volume := DEFAULT_VOLUME
## The session's player (none in tests that don't build main): screens
## reach it through the static helpers, which do nothing without one.
static var current: Music

var track := ""                    ## the loop playing or fading in ("" = none)
var sting_name := ""               ## the last stinger started
var silent := false                ## headless: no playback, state only
var _decks: Array[AudioStreamPlayer] = []
var _deck_track := ["", ""]
var _gain := [0.0, 0.0]            ## 0..1 through each deck's fade
var _target := [0.0, 0.0]
var _rate := [1.0, 1.0]            ## gain per second
var _active := 0
var _sting: AudioStreamPlayer
var _sting_gain := 0.0
var _sting_fading := false
var _duck := 0.0                   ## 0..1 of DUCK_DB
var _duck_left := 0.0


func _init() -> void:
	current = self                       # main makes the one the game uses
	silent = DisplayServer.get_name() == "headless"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_decks.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.volume_db = -80.0
	add_child(_sting)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and current == self:
		current = null


func _process(delta: float) -> void:
	update(delta)


static func volume_name(v: int = volume) -> String:
	return "OFF" if v <= 0 else "%d%%" % (v * 100 / VOLUMES)


## The match loop for a venue (the park's where a venue has none).
static func match_track(venue: String) -> String:
	return "match_" + venue if LOOPS.has("match_" + venue) else "match_park"


## The stinger for a match's end: clearing the ladder, else won or lost
## (by team 0; with players on both teams somebody won, so it's a win).
static func result_sting(won: bool, cleared: bool, humans_both_sides: bool) -> String:
	if cleared:
		return "cleared"
	return "won" if won or humans_both_sides else "lost"


## The helpers screens call (no-ops without a player).
static func cue(name: String) -> void:
	if current:
		current.play_loop(name)


static func sting(name: String) -> void:
	if current:
		current.play_sting(name)


static func duck_for(effect: String) -> void:
	if current and effect in DUCKED_BY:
		current.start_duck()


## No music at all: MUSIC OFF, or SOUND OFF.
static func muted() -> bool:
	return volume <= 0 or Sfx.setting == AudioMap.SOUND_OFF


## Crossfades to a loop (the same one keeps playing; "" fades to silence).
func play_loop(name: String) -> void:
	if name == track:
		return
	track = name if LOOPS.has(name) else ""
	_fade_deck(_active, 0.0, 1.0 / CROSSFADE)
	if _sting_gain > 0.0:
		_sting_fading = true             # a new screen cuts a stinger short
	if track == "":
		return
	_active = 1 - _active
	var stream: AudioStreamWAV = load(DIR + LOOPS[track] + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_deck_track[_active] = track
	_gain[_active] = 0.0
	_fade_deck(_active, 1.0, 1.0 / CROSSFADE)
	_decks[_active].stream = stream
	_start(_decks[_active])


## A stinger over the loop's quick fade; the music stays quiet after it.
func play_sting(name: String) -> void:
	if not STINGERS.has(name):
		return
	sting_name = name
	track = ""
	for i in 2:
		_fade_deck(i, 0.0, 1.0 / STING_FADE)
	_sting.stream = load(DIR + STINGERS[name] + ".wav")
	_sting_gain = 1.0
	_sting_fading = false
	_start(_sting)


func start_duck() -> void:
	_duck_left = DUCK_HOLD


func _fade_deck(i: int, to: float, rate: float) -> void:
	_target[i] = to
	_rate[i] = rate


func _start(p: AudioStreamPlayer) -> void:
	if not silent:
		p.play()


## A deck's fade (0..1), for the tests.
func gain_of(name: String) -> float:
	var g := 0.0
	for i in 2:
		if _deck_track[i] == name:
			g = maxf(g, _gain[i])
	return g


func ducking() -> float:
	return _duck


## The level a loop at full fade plays at now (dB), duck included.
func level_db() -> float:
	if muted():
		return -80.0
	return BASE_DB + linear_to_db(float(volume) / VOLUMES) + _duck * DUCK_DB


## Once a frame: the fades, the duck, and each player's volume.
func update(delta: float) -> void:
	if _duck_left > 0.0:
		_duck_left -= delta
		_duck = move_toward(_duck, 1.0, delta / DUCK_ATTACK)
	else:
		_duck = move_toward(_duck, 0.0, delta / DUCK_RELEASE)
	var level := level_db()
	for i in 2:
		_gain[i] = move_toward(_gain[i], _target[i], _rate[i] * delta)
		var p := _decks[i]
		if _gain[i] <= 0.0 and _target[i] <= 0.0:
			_deck_track[i] = ""
			if p.playing:
				p.stop()
		# equal power: sin of the fade in, the matching cos of the fade out
		p.volume_db = level + linear_to_db(maxf(sin(_gain[i] * PI / 2.0), 0.0001))
	if _sting_gain > 0.0 and not silent and not _sting.playing:
		_sting_gain = 0.0                # it finished
	if _sting_fading:
		_sting_gain = move_toward(_sting_gain, 0.0, delta / 0.6)
		if _sting_gain <= 0.0:
			_sting_fading = false
			_sting.stop()
	# the stinger ducks half as far: it's the moment's own music
	_sting.volume_db = level - _duck * DUCK_DB * 0.5 + linear_to_db(maxf(_sting_gain, 0.0001))
