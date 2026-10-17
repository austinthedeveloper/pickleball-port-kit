## Sound from sim events (the event seam): the SNES effects and the venue's
## ambience loop. The demo behind the title plays ambience only.
class_name Sfx
extends Node

const DIR := "res://assets/audio/"
const EFFECTS := {"hit": "0_hit", "bounce": "1_bounce", "net": "2_net",
	"whistle": "3_whistle", "applause": "4_applause", "blip": "5_blip",
	"confirm": "6_confirm", "back": "7_back"}
const AMBIENCE := {"park": "ambience_park", "lakeside": "ambience_lakeside",
	"sunset": "ambience_sunset"}

var _players := {}
var _quiet := false


func setup(venue: String, quiet: bool) -> void:
	_quiet = quiet
	for k in EFFECTS:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + EFFECTS[k] + ".wav")
		p.volume_db = -4.0 if k != "applause" else -10.0
		add_child(p)
		_players[k] = p
	if AMBIENCE.has(venue):
		var amb := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(DIR + AMBIENCE[venue] + ".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.get_length() * stream.mix_rate
		amb.stream = stream
		amb.volume_db = -14.0
		amb.autoplay = true
		add_child(amb)


func play(name: String) -> void:
	if _quiet or not _players.has(name):
		return
	_players[name].play()
