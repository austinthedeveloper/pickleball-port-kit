## Rollback over the deterministic sim (port ADR-103, PORT-107): each side
## steps at once on a guess of the other side's input, and steps again
## from the last confirmed frame when the real one turns out different.
##
## Two sims. `truth` steps exactly once per frame whose inputs both sides
## know: it's counted, hashed for the desync check, and never wrong.
## `pred` is drawn and heard: it runs ahead to the present on guesses, and
## when a guess was wrong it's reset to `truth` (Sim.load_state) and the
## guessed frames run again. Each side's input is scheduled `delay` frames
## ahead (1 or 2) and sent at once; the prediction runs at most `window`
## frames past what's confirmed, and waits beyond that, as lockstep does.
##
## A guess repeats the other side's last known held state (moves, aim,
## held buttons) and never a press: a repeated press is a swing they
## didn't make. Commands are guessed to be none.
##
## Time sync: each input message carries the sender's present frame and
## how far ahead of the other it thinks it is. Every SYNC_EVERY frames, a
## side 2 or more frames further ahead than the other holds a frame (it
## draws without stepping), so one side doesn't do all the rolling back.
##
## Pure: no Nodes, no clock. The session feeds it messages and calls
## tick() once a drawn frame; what to send, play and count comes back.
class_name Rollback
extends RefCounted

const DELAY := 2                 ## frames of input delay over the internet
const DELAY_LAN := 1             ## ... under LAN_RTT_MS
const LAN_RTT_MS := 20
const WINDOW := 8                ## frames predicted past the confirmed, at most
const HASH_EVERY := 120
const SYNC_EVERY := 60

var local_slot := 0
var remote_slot := 2
var delay := DELAY
var window := WINDOW
var truth: Sim                   ## steps on confirmed inputs only
var pred: Sim                    ## the present, on guesses where needed
var confirmed := 0               ## the next frame `truth` steps
var predicted := 0               ## the next frame `pred` steps
var desync := -1                 ## the frame whose hashes differed, or -1
var corrections := 0             ## times `pred` was reset to `truth` (a wrong guess)
var stalls := 0                  ## ticks the window was full (waiting for the other side)
var holds := 0                   ## ticks held for time sync
var _local := {}                 ## frame -> packed intent (Lockstep.pack)
var _remote := {}
var _local_cmds := {}            ## frame -> commands (Sim.apply), when any
var _remote_cmds := {}
var _guessed := {}               ## frame -> the remote input `pred` guessed for it
var _last_remote := 0            ## the latest remote input known (guesses repeat it)
var _last_remote_frame := -1
var _remote_frame := 0           ## the other side's present, as last heard
var _remote_adv := 0             ## how far ahead it thought it was
var _hold := 0                   ## frames to hold (time sync)
var _last_sync := -1             ## the frame time sync last looked at
var _hashes := {}                ## frame -> [mine, theirs]


## Builds both sims for `cfg`, each with its own config (a command run on
## a guess mustn't reach `truth`'s).
func _init(cfg: SimTypes.MatchConfig, local := 0, remote := 2, frames := DELAY,
		win := WINDOW) -> void:
	local_slot = local
	remote_slot = remote
	delay = frames
	window = win
	truth = Sim.new(cfg)
	pred = Sim.new(SimTypes.MatchConfig.new())
	pred.load_state(truth.save_state())
	for f in delay:
		_local[f] = 0
		_remote[f] = 0


## The delay for a line's round trip (ADR-103): 1 on a LAN, else 2.
static func for_rtt(rtt_ms: int) -> int:
	return DELAY_LAN if rtt_ms < LAN_RTT_MS else DELAY


func dispose() -> void:
	truth.dispose()
	pred.dispose()


func on_message(m: Array) -> void:
	match m[0]:
		"I":
			var f := int(m[1])
			_remote[f] = int(m[2])
			if not (m[3] as Array).is_empty():
				_remote_cmds[f] = m[3]
			if f > _last_remote_frame:
				_last_remote_frame = f
				_last_remote = int(m[2])
			_remote_frame = maxi(_remote_frame, int(m[4]))
			_remote_adv = int(m[5])
		"H":
			_hash(int(m[1]), 1, int(m[2]))


## How far ahead of the other side's present this one is, as heard (the
## line's latency included).
func advantage() -> int:
	return predicted - _remote_frame


## How many frames this side's clock leads the other's: half the
## difference of the two advantages, so the latency cancels out.
func lead() -> int:
	return (advantage() - _remote_adv) / 2


## Frames `pred` ran on a guess that isn't confirmed yet.
func guessing() -> int:
	return _guessed.size()


## One drawn frame: the local intent and commands go in (when it steps;
## otherwise the caller keeps them for the next tick). Returns
## {stepped, send: [messages], played: [[step, events]] from `pred` (for
## EventLedger.run), counted: [[step, events, commands]] from `truth`}.
func tick(local_intent: SimTypes.Intent, cmds: Array = []) -> Dictionary:
	var out := {"stepped": false, "send": [], "played": [], "counted": []}
	if predicted > 0 and predicted % SYNC_EVERY == 0 and predicted != _last_sync:
		_last_sync = predicted
		if lead() >= 2:
			_hold = 1
	_confirm(out)
	if _hold > 0:
		_hold -= 1
		holds += 1
		return out
	if predicted - confirmed >= window:
		stalls += 1
		return out
	var ahead := predicted + delay
	_local[ahead] = Lockstep.pack(local_intent)
	if not cmds.is_empty():
		_local_cmds[ahead] = cmds.duplicate(true)
	out["send"].append(["I", ahead, _local[ahead], cmds.duplicate(true), predicted, advantage()])
	_step_pred(predicted, out)
	predicted += 1
	out["stepped"] = true
	return out


## Without stepping the present: what's confirmed now (inputs that came
## while waiting, or at a match's end). The same shape as tick()'s.
func catch_up() -> Dictionary:
	var out := {"stepped": false, "send": [], "played": [], "counted": []}
	_confirm(out)
	return out


## Steps `truth` through every frame both inputs are known for, up to the
## present `pred` has shown; resets `pred` if a guess there was wrong.
func _confirm(out: Dictionary) -> void:
	var wrong := false
	while confirmed < predicted and _local.has(confirmed) and _remote.has(confirmed):
		var f := confirmed
		if _guessed.has(f) and (_guessed[f] != _remote[f] or _remote_cmds.has(f)):
			wrong = true
		var cmds := _commands(f)
		truth.step(_humans(_local[f], _remote[f]), cmds)
		var events := truth.drain_events()
		out["counted"].append([truth.step_count, events, cmds])
		# and offered to play: a frame `pred` guessed wrong played the guess's
		# events, and isn't run again (it's confirmed now); EventLedger.run
		# plays only what wasn't played for it, so a right guess plays nothing
		out["played"].append([truth.step_count, events])
		for d in [_local, _remote, _local_cmds, _remote_cmds, _guessed]:
			d.erase(f)
		confirmed += 1
		if f % HASH_EVERY == 0:
			var h := truth.state_hash()
			_hash(f, 0, h)
			out["send"].append(["H", f, h])
	if wrong:
		corrections += 1
		pred.load_state(truth.save_state())
		_guessed.clear()
		for f in range(confirmed, predicted):
			_step_pred(f, out)


## `pred` steps frame f: the remote input if it's here, else a guess.
func _step_pred(f: int, out: Dictionary) -> void:
	var remote: int
	if _remote.has(f):
		remote = _remote[f]
	else:
		remote = guess(_last_remote)
		_guessed[f] = remote
	pred.step(_humans(_local[f], remote), _commands(f))   # the other side's: none, guessed
	out["played"].append([pred.step_count, pred.drain_events()])


## The other side's input repeated: its held state, none of its presses.
static func guess(packed: int) -> int:
	if packed == 0:
		return 0
	return packed & ~((1 << 8) | (1 << 11))          # hit_pressed, pause_pressed (Lockstep.pack)


func _humans(local: int, remote: int) -> Array:
	var human: Array = [null, null, null, null]
	human[local_slot] = Lockstep.unpack(local)
	human[remote_slot] = Lockstep.unpack(remote)
	return human


## Frame f's commands, both sides', the lower slot's first.
func _commands(f: int) -> Array:
	var mine: Array = _local_cmds.get(f, [])
	var theirs: Array = _remote_cmds.get(f, [])
	return mine + theirs if local_slot < remote_slot else theirs + mine


func _hash(f: int, who: int, h: int) -> void:
	var pair: Array = _hashes.get(f, [null, null])
	pair[who] = h
	_hashes[f] = pair
	if pair[0] != null and pair[1] != null:
		if pair[0] != pair[1] and desync < 0:
			desync = f
		_hashes.erase(f)
