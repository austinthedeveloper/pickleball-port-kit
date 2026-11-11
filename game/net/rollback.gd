## Rollback over the deterministic sim (port ADR-103, PORT-107; any number
## of seats, port ADR-111): each machine steps at once on a guess of the
## others' inputs, and steps again from the last confirmed frame when a
## real one turns out different.
##
## Two sims. `truth` steps exactly once per frame whose inputs every seat
## has: it's counted, hashed for the desync check, and never wrong. `pred`
## is drawn and heard: it runs ahead to the present on guesses, and when a
## guess was wrong it's reset to `truth` (Sim.load_state) and the guessed
## frames run again. Each local seat's input is scheduled `delay` frames
## ahead (1 or 2) and sent at once; the prediction runs at most `window`
## frames past what's confirmed, and waits beyond that, as lockstep does.
##
## Seats (ADR-111): `local_slots` are this machine's (one, or two on a
## couch), `remote_slots` everyone else's human seats. A watcher has none
## of its own: it only confirms (`watching`), and draws `truth`. A seat
## can be filled with neutral inputs (a rejoin's gap) or retired from a
## frame on (a CPU takes it, Sim's "seat_cpu" command, run at that frame).
##
## A guess repeats a seat's last known held state (moves, aim, held
## buttons) and never a press: a repeated press is a swing they didn't
## make. Commands are guessed to be none.
##
## Time sync: each input message carries the sender's present frame and
## how far ahead it thinks it is of its partner in sync (a guest's is the
## host; the host's, its slowest guest). Every SYNC_EVERY frames a machine
## 2 or more frames ahead holds a frame (it draws without stepping), so one
## machine doesn't do all the rolling back.
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
const NEVER := 1 << 40

var local_slots: Array = [0]
var remote_slots: Array = [2]
var local_slot := 0              ## the first local seat (-1: a watcher)
var remote_slot := 2             ## the first remote seat
var delay := DELAY
var window := WINDOW
var watching := false            ## a watcher: confirms only, draws `truth`
var truth: Sim                   ## steps on confirmed inputs only
var pred: Sim                    ## the present, on guesses where needed
var confirmed := 0               ## the next frame `truth` steps
var predicted := 0               ## the next frame `pred` steps
var desync := -1                 ## the frame whose hashes differed, or -1
var corrections := 0             ## times `pred` was reset to `truth` (a wrong guess)
var stalls := 0                  ## ticks the window was full (waiting for a seat)
var holds := 0                   ## ticks held for time sync
var _inputs := {}                ## slot -> {frame -> packed intent (Lockstep.pack)}
var _cmds := {}                  ## slot -> {frame -> commands (Sim.apply)}, when any
var _extra := {}                 ## frame -> commands the room ran (a seat to a CPU)
var _guessed := {}               ## frame -> {slot -> the input `pred` guessed}
var _last := {}                  ## slot -> the latest input known (guesses repeat it)
var _last_frame := {}            ## slot -> the frame of that input
var _present := {}               ## slot -> its machine's present, as last heard
var _adv := {}                   ## slot -> how far ahead that machine thought it was
var _retired := {}               ## slot -> the frame it stops being an input (a CPU's)
var _sync_slots: Array = []      ## the seats time sync measures against
var _resim := false              ## `pred` must run again from `truth` (a seat retired behind it)
var _hold := 0                   ## frames to hold (time sync)
var _last_sync := -1             ## the frame time sync last looked at
var _hashes := {}                ## frame -> {who -> hash}; who "me" for this machine's
static var log_all := false      ## tests: every rollback keeps its hashes
var keep_log := log_all          ## keep every hash this machine made
var hash_log := {}               ## frame -> its hash (with keep_log)
var input_log := {}              ## frame -> [each seat's packed input] (with keep_log)


## Builds both sims for `cfg`, each with its own config (a command run on
## a guess mustn't reach `truth`'s). `local` and `remote` are a seat or a
## list of them (a watcher: local []).
func _init(cfg: SimTypes.MatchConfig, local: Variant = 0, remote: Variant = 2, frames := DELAY,
		win := WINDOW) -> void:
	local_slots = (local as Array).duplicate() if local is Array else [int(local)]
	remote_slots = (remote as Array).duplicate() if remote is Array else [int(remote)]
	local_slots.sort()
	remote_slots.sort()
	local_slot = int(local_slots[0]) if not local_slots.is_empty() else -1
	remote_slot = int(remote_slots[0]) if not remote_slots.is_empty() else -1
	watching = local_slots.is_empty()
	delay = frames
	window = win
	for s in local_slots + remote_slots:
		_inputs[s] = {}
		_cmds[s] = {}
		_last[s] = 0
		_last_frame[s] = -1
		_present[s] = 0
		_adv[s] = 0
	# a guest keeps time with the host (slot 0); the host, with its guests
	_sync_slots = [0] if not 0 in local_slots and 0 in remote_slots else remote_slots.duplicate()
	truth = Sim.new(cfg)
	pred = Sim.new(SimTypes.MatchConfig.new())
	pred.load_state(truth.save_state())
	for f in delay:
		for s in local_slots + remote_slots:
			_inputs[s][f] = 0


## A machine joining a match under way (a rejoin, a watcher; ADR-111): the
## confirmed state at `frame`, every input known from it on ({slot: {frame:
## packed}}), their commands and the room's, then the present run up to
## `present`. Into this rollback's own sims (whatever draws them keeps them).
func restart(state: Array, frame: int, inputs: Dictionary, cmds: Dictionary, extra: Dictionary,
		present: int) -> void:
	truth.load_state(state)
	pred.load_state(state)
	confirmed = frame
	predicted = frame
	_guessed.clear()
	_extra.clear()
	_retired.clear()
	_hashes.clear()
	_resim = false
	for s in _inputs:
		_inputs[s] = {}
		_cmds[s] = {}
		_last[s] = 0
		_last_frame[s] = -1
		var mine: Dictionary = inputs.get(s, inputs.get(str(s), {}))
		var fs := mine.keys()
		fs.sort()
		for f in fs:
			_set_input(int(s), int(f), int(mine[f]))
		var c: Dictionary = cmds.get(s, cmds.get(str(s), {}))
		for f in c:
			_cmds[s][int(f)] = c[f]
	for f in extra:
		_extra[int(f)] = extra[f]
	if watching:
		return
	var out := {"played": [], "send": [], "counted": []}
	while predicted < present:
		_step_pred(predicted, out)
		predicted += 1


## What a machine needs to resume (`resume`'s arguments), from this one:
## the confirmed state and everything known since.
func snapshot_for_resume() -> Dictionary:
	var ins := {}
	var cs := {}
	for s in _inputs:
		ins[s] = (_inputs[s] as Dictionary).duplicate()
		cs[s] = (_cmds[s] as Dictionary).duplicate(true)
	return {"state": truth.save_state(), "frame": confirmed, "inputs": ins, "cmds": cs,
		"extra": _extra.duplicate(true)}


## The delay for a line's round trip (ADR-103): 1 on a LAN, else 2.
static func for_rtt(rtt_ms: int) -> int:
	return DELAY_LAN if rtt_ms < LAN_RTT_MS else DELAY


func dispose() -> void:
	truth.dispose()
	pred.dispose()


## A message from another machine: an input (a seat's, ["I", frame, packed,
## commands, present, advantage, slot]) or a hash (["H", frame, hash, who]).
func on_message(m: Array) -> void:
	match m[0]:
		"I":
			var s: int = int(m[6]) if m.size() > 6 else remote_slot
			if not _inputs.has(s) or s in local_slots:
				return
			var f := int(m[1])
			_set_input(s, f, int(m[2]))
			if not (m[3] as Array).is_empty():
				_cmds[s][f] = m[3]
			_present[s] = maxi(int(_present[s]), int(m[4]))
			_adv[s] = int(m[5])
		"H":
			_hash(int(m[1]), String(m[3]) if m.size() > 3 else "peer", int(m[2]))


func _set_input(s: int, f: int, packed: int) -> void:
	_inputs[s][f] = packed
	if f > int(_last_frame[s]):
		_last_frame[s] = f
		_last[s] = packed


## The latest frame a seat's input is known for (-1: none).
func last_known(slot: int) -> int:
	return int(_last_frame.get(slot, -1))


## Neutral inputs for a seat over [from, to) where none came (a rejoin's
## gap, ADR-111): every machine fills the same frames, as the host says.
func fill(slot: int, from: int, to: int) -> void:
	if not _inputs.has(slot):
		return
	for f in range(maxi(from, confirmed), to):
		if not (_inputs[slot] as Dictionary).has(f):
			_set_input(slot, f, 0)


## A seat stops being an input from frame `from` on: a CPU plays it,
## through Sim's "seat_cpu" command run at that frame (ADR-111).
func retire(slot: int, from: int) -> void:
	if _retired.has(slot):
		return
	_retired[slot] = from
	var at: Array = _extra.get(from, [])
	at.append(["seat_cpu", slot])
	_extra[from] = at
	if from < predicted:
		_resim = true


## Whether a seat gives frame f's input (not once a CPU has it).
func _seat_in(slot: int, f: int) -> bool:
	return f < int(_retired.get(slot, NEVER))


## How far ahead of its partners in sync this machine's present is, as
## heard (the line's latency included).
func advantage() -> int:
	var behind := NEVER
	for s in _sync_slots:
		if _seat_in(s, predicted):
			behind = mini(behind, int(_present[s]))
	return 0 if behind == NEVER else predicted - behind


## How many frames this machine's clock leads the slowest partner's: half
## the difference of the two advantages, so the latency cancels out.
func lead() -> int:
	var most := 0
	for s in _sync_slots:
		if _seat_in(s, predicted):
			most = maxi(most, ((predicted - int(_present[s])) - int(_adv[s])) / 2)
	return most


## Frames `pred` ran on a guess that isn't confirmed yet.
func guessing() -> int:
	return _guessed.size()


## One drawn frame: each local seat's intent and the commands go in (when
## it steps; otherwise the caller keeps them for the next tick). One intent
## or a list, a seat each (local_slots' order). Returns {stepped, send:
## [messages], played: [[step, events]] from `pred` (for EventLedger.run),
## counted: [[step, events, commands]] from `truth`}.
func tick(local_intent: Variant, cmds: Array = []) -> Dictionary:
	var out := {"stepped": false, "send": [], "played": [], "counted": []}
	if watching:
		_confirm(out)
		return out
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
	var intents: Array = local_intent if local_intent is Array else [local_intent]
	var ahead := predicted + delay
	for k in local_slots.size():
		var s: int = local_slots[k]
		var it: SimTypes.Intent = intents[k] if k < intents.size() and intents[k] != null else SimTypes.Intent.new()
		_inputs[s][ahead] = Lockstep.pack(it)
		var mine: Array = cmds if k == 0 else []
		if not mine.is_empty():
			_cmds[s][ahead] = mine.duplicate(true)
		out["send"].append(["I", ahead, _inputs[s][ahead], mine.duplicate(true), predicted, advantage(), s])
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


## Whether every seat's input for frame f is here.
func _known(f: int) -> bool:
	for s in _inputs:
		if _seat_in(s, f) and not (_inputs[s] as Dictionary).has(f):
			return false
	return true


## Steps `truth` through every frame all inputs are known for, up to the
## present `pred` has shown (a watcher: as far as they go); resets `pred`
## if a guess there was wrong.
func _confirm(out: Dictionary) -> void:
	var wrong := _resim
	_resim = false
	var limit := NEVER if watching else predicted
	while confirmed < limit and _known(confirmed):
		var f := confirmed
		if _guessed.has(f):
			var g: Dictionary = _guessed[f]
			for s in g:
				if not _seat_in(s, f) or g[s] != _inputs[s][f] or (_cmds[s] as Dictionary).has(f):
					wrong = true
		var cmds := _commands(f)
		if keep_log:
			var row := []
			for s in K.MAX_PLAYERS:
				row.append(int(_inputs[s][f]) if _inputs.has(s) and _seat_in(s, f) else -1)
			input_log[f] = row
		truth.step(_humans(f, {}), cmds)
		var events := truth.drain_events()
		out["counted"].append([truth.step_count, events, cmds])
		# and offered to play: a frame `pred` guessed wrong played the guess's
		# events, and isn't run again (it's confirmed now); EventLedger.run
		# plays only what wasn't played for it, so a right guess plays nothing
		out["played"].append([truth.step_count, events])
		for s in _inputs:
			(_inputs[s] as Dictionary).erase(f)
			(_cmds[s] as Dictionary).erase(f)
		_guessed.erase(f)
		_extra.erase(f)
		confirmed += 1
		if f % HASH_EVERY == 0:
			var h := truth.state_hash()
			if keep_log:
				hash_log[f] = h
			_hash(f, "me", h)
			out["send"].append(["H", f, h, _me()])
	if watching:
		return
	if wrong:
		corrections += 1
		pred.load_state(truth.save_state())
		_guessed.clear()
		for f in range(confirmed, predicted):
			_step_pred(f, out)


func _me() -> String:
	return "w" if watching else str(local_slot)


## `pred` steps frame f: each remote seat's input if it's here, else a guess.
func _step_pred(f: int, out: Dictionary) -> void:
	var guessed := {}
	for s in remote_slots:
		if _seat_in(s, f) and not (_inputs[s] as Dictionary).has(f):
			guessed[s] = guess(int(_last[s]))
	if not guessed.is_empty():
		_guessed[f] = guessed
	pred.step(_humans(f, guessed), _commands(f))        # the others': none, guessed
	out["played"].append([pred.step_count, pred.drain_events()])


## A seat's input repeated: its held state, none of its presses.
static func guess(packed: int) -> int:
	if packed == 0:
		return 0
	return packed & ~((1 << 8) | (1 << 11))          # hit_pressed, pause_pressed (Lockstep.pack)


## Frame f's intents for Sim.step: each seat's known input, or its guess.
func _humans(f: int, guessed: Dictionary) -> Array:
	var human: Array = [null, null, null, null]
	for s in _inputs:
		if not _seat_in(s, f):
			continue
		var d: Dictionary = _inputs[s]
		human[s] = Lockstep.unpack(int(d[f]) if d.has(f) else int(guessed.get(s, 0)))
	return human


## Frame f's commands: the room's (a seat to a CPU) first, then each
## seat's, the lowest seat's first.
func _commands(f: int) -> Array:
	var all: Array = (_extra.get(f, []) as Array).duplicate(true)
	var seats := _inputs.keys()
	seats.sort()
	for s in seats:
		all.append_array((_cmds[s] as Dictionary).get(f, []))
	return all


## A hash for frame f from `who` ("me": this machine's): any two that
## differ are a desync.
func _hash(f: int, who: String, h: int) -> void:
	var seen: Dictionary = _hashes.get(f, {})
	seen[who] = h
	_hashes[f] = seen
	if seen.has("me"):
		for k in seen:
			if seen[k] != seen["me"] and desync < 0:
				desync = f
	# old frames go (every machine has had HASH_EVERY * 8 frames to say)
	for old in _hashes.keys():
		if int(old) < confirmed - HASH_EVERY * 8:
			_hashes.erase(old)
