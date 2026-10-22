## Lockstep over the deterministic sim (PORT-31, ADR-056): both machines
## run the same Sim from the same config, stepping a frame only when they
## hold both players' inputs for it. Each side's input is scheduled DELAY
## frames ahead and sent at once, so on a quick line neither ever waits;
## a slow packet makes both wait (the match pauses, nothing diverges).
## Frames 0..DELAY-1 start with empty inputs on both sides.
##
## Every HASH_EVERY frames each side sends a hash of its sim; a different
## hash from the other side is a desync (a bug: the sim must be exact).
class_name Lockstep
extends RefCounted

const DELAY := 4                 ## frames of input delay (~67 ms at 60 Hz), the default
const MIN_DELAY := 3
const MAX_DELAY := 12
const HASH_EVERY := 120

var local_slot := 0
var remote_slot := 2
var delay := DELAY               ## this match's: the host picks it from the line (for_rtt)
var frame := 0                   ## the next sim frame to step
var waited := 0                  ## frames in a row spent waiting for the other side
var desync := -1                 ## the frame whose hashes differed, or -1
var _local := {}                 ## frame -> packed intent
var _remote := {}
var _hashes := {}                ## frame -> [mine, theirs] (null until known)


func _init(local := 0, remote := 2, frames := DELAY) -> void:
	local_slot = local
	remote_slot = remote
	delay = frames
	for f in delay:
		_local[f] = 0
		_remote[f] = 0


## An Intent as one int (each field is small): move, aim, the shot and its
## presses. 0 is an empty intent.
static func pack(it: SimTypes.Intent) -> int:
	return (it.move_x + 1) | ((it.move_y + 1) << 2) | ((it.aim_x + 1) << 4) \
		| ((it.aim_y + 1) << 6) | (it.hit_pressed << 8) | (it.shot << 9) \
		| (it.pause_pressed << 11) | (it.hit_held << 12) | (1 << 13) | ((it.shot >> 2) << 14)


static func unpack(v: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	if v == 0:
		return it
	it.move_x = (v & 3) - 1
	it.move_y = ((v >> 2) & 3) - 1
	it.aim_x = ((v >> 4) & 3) - 1
	it.aim_y = ((v >> 6) & 3) - 1
	it.hit_pressed = (v >> 8) & 1
	it.shot = ((v >> 9) & 3) | (((v >> 14) & 1) << 2)     # SHOT_SPECIAL needs the third bit
	it.pause_pressed = (v >> 11) & 1
	it.hit_held = (v >> 12) & 1
	return it


## The delay for a line's round trip: half of it in frames, plus two for
## jitter, within MIN..MAX. An input then arrives before it's needed.
static func for_rtt(rtt_ms: int) -> int:
	return clampi(ceili(rtt_ms / 2.0 / (1000.0 / 60.0)) + 2, MIN_DELAY, MAX_DELAY)


## Both inputs for the next frame are here.
func ready() -> bool:
	return _local.has(frame) and _remote.has(frame)


## Steps the bookkeeping: this side's input for frame + DELAY (the message
## to send), and the four slots' intents for this frame.
func advance(local_intent: SimTypes.Intent) -> Array:
	var ahead := frame + delay
	_local[ahead] = pack(local_intent)
	var human: Array = [null, null, null, null]
	human[local_slot] = unpack(_local[frame])
	human[remote_slot] = unpack(_remote[frame])
	_local.erase(frame)
	_remote.erase(frame)
	frame += 1
	waited = 0
	return [["I", ahead, _local[ahead]], human]


func on_message(m: Array) -> void:
	match m[0]:
		"I":
			_remote[int(m[1])] = int(m[2])
		"H":
			_hash(int(m[1]), 1, int(m[2]))


## After stepping frame `f`: this side's hash to send, if it's a hash frame.
func hash_after(f: int, sim: Sim) -> Array:
	if f % HASH_EVERY != 0:
		return []
	var h := str(sim.snapshot()).hash()
	_hash(f, 0, h)
	return ["H", f, h]


func _hash(f: int, who: int, h: int) -> void:
	var pair: Array = _hashes.get(f, [null, null])
	pair[who] = h
	_hashes[f] = pair
	if pair[0] != null and pair[1] != null:
		if pair[0] != pair[1] and desync < 0:
			desync = f
		_hashes.erase(f)
