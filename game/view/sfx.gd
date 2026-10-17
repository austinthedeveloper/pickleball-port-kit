## Sound from sim events (the event seam), mapped by AudioMap: effects are
## panned by court x (AudioStreamPlayer2D across the screen, no distance
## falloff), pitched by shot, sized by the rally; the venue's ambience
## loops, fades in, swells with long rallies, and hushes on match point.
## The demo behind the title plays ambience only.
class_name Sfx
extends Node

const DIR := "res://assets/audio/"
const EFFECTS := {"hit": "0_hit", "bounce": "1_bounce", "net": "2_net",
	"whistle": "3_whistle", "applause": "4_applause", "blip": "5_blip",
	"confirm": "6_confirm", "back": "7_back"}
const AMBIENCE := {"park": "ambience_park", "lakeside": "ambience_lakeside",
	"sunset": "ambience_sunset"}
const VOICES := 3                  ## overlapping copies per effect
const AMBIENCE_DB := -12.0
const FADE_IN := 0.6

## SOUND setting (AudioMap.SOUND_*), shared by every screen.
static var setting := AudioMap.SOUND_ALL

var _players := {}                 # effect -> [AudioStreamPlayer2D...]
var _next := {}
var _quiet := false
var _amb: AudioStreamPlayer
var _amb_level := 0.0
var _fade := 0.0
var last: Array = []               ## the last sound played (for tests)
var ambience_name := ""            ## whose ambience loop plays


## `ambience` names the venue whose loop plays instead (NIGHT: crickets).
func setup(venue: String, quiet: bool, ambience := "") -> void:
	_quiet = quiet
	for k in EFFECTS:
		var list := []
		var stream := load(DIR + EFFECTS[k] + ".wav")
		for v in VOICES:
			var p := AudioStreamPlayer2D.new()
			p.stream = stream
			p.attenuation = 0.0
			p.max_distance = 100000.0
			p.panning_strength = 1.0
			add_child(p)
			list.append(p)
		_players[k] = list
		_next[k] = 0
	var loop := ambience if AMBIENCE.has(ambience) else venue
	if AMBIENCE.has(loop):
		ambience_name = loop
		_amb = AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(DIR + AMBIENCE[loop] + ".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.get_length() * stream.mix_rate
		_amb.stream = stream
		_amb.volume_db = -60.0
		_amb.autoplay = true
		add_child(_amb)


## A menu or UI sound.
func play(name: String) -> void:
	if _quiet:
		return
	_play(name, 1.0, 12, 0.0, true)


## The sounds for a sim event (silent in the demo).
func event(e: Array, rally: int, match_won: bool) -> void:
	if _quiet:
		return
	for s in AudioMap.for_event(e, setting, rally, match_won):
		_play(s[0], s[1], s[2], s[3], false)


func _play(name: String, pitch: float, volume: int, pan: float, ui: bool) -> void:
	if not _players.has(name) or setting == AudioMap.SOUND_OFF:
		return
	last = [name, pitch, volume, pan]
	if not is_inside_tree():
		return
	var p: AudioStreamPlayer2D = _players[name][_next[name]]
	_next[name] = (_next[name] + 1) % VOICES
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(volume / 15.0, 0.001)) - (4.0 if ui else 2.0)
	p.position = Vector2(480.0 + pan * 480.0, 270.0)
	p.play()


## Once a frame: the ambience follows the play (and fades in).
func update_ambience(live: bool, rally: int, match_point: bool, delta: float) -> void:
	if _amb == null:
		return
	_fade = minf(1.0, _fade + delta / FADE_IN)
	var want := AudioMap.ambience_level(setting, live, rally, match_point)
	_amb_level = lerpf(_amb_level, want, 0.05)
	_amb.volume_db = AMBIENCE_DB + linear_to_db(maxf(_amb_level * _fade, 0.001))
