## An online match's connection (PORT-31, ADR-056): the handshake and then
## the lockstep. The host listens; the guest joins by address. Each sends
## HELLO (the game's version and its player's look); the host checks the
## versions, and START sends the match (the config, venue, time and court
## colours) so both build the same Sim. The host plays slot 0 (left), the
## guest slot 2 (right). In the match, MatchView asks `intents` each frame
## (null: wait) and calls `after_step`. QUIT leaves; a lost line closes it.
class_name OnlineSession
extends RefCounted

const PROTOCOL := 2                ## 2: commands ride on the inputs (port ADR-102)
const IDLE := 0
const WAITING := 1               ## the host listening, or the guest connecting
const CONNECTED := 2             ## both said HELLO
const PLAYING := 3
const CLOSED := 4

var link: NetLink
var host := false
var state := IDLE
var reason := ""                 ## why it closed, for the screen
var peer_hello := {}             ## the other side's {version, protocol, look, name}
var start := {}                  ## the match, from START
var lockstep: Lockstep
var _pending := SimTypes.Intent.new()   ## this side's presses since the last step
var _pending_cmds := []          ## this side's commands since the last step (the host's NEW MATCH)
var commands := []               ## this frame's, both sides' (MatchView steps them)
var _hello_sent := false


func _init(l: NetLink = null, is_host := false) -> void:
	link = l
	host = is_host
	if link:
		state = WAITING


## {version, protocol, look, name} for HELLO: this game and its player.
static func hello(look: Dictionary, name := "") -> Dictionary:
	return {"version": BuildInfo.version(), "protocol": PROTOCOL, "look": look.duplicate(), "name": name}


var my_hello := {}


func poll() -> void:
	if link == null or state == CLOSED:
		return
	link.poll()
	for m in link.receive():                 # first: a QUIT may come with the close
		_on(m)
		if state == CLOSED:
			return
	if link.status() == NetLink.CLOSED:
		_close(link.error if link.error != "" else "CONNECTION LOST")
		return
	if link.status() == NetLink.CONNECTED and not _hello_sent and not my_hello.is_empty():
		link.send(["HELLO", my_hello])
		_hello_sent = true


func _on(m: Array) -> void:
	match m[0]:
		"HELLO":
			peer_hello = m[1]
			if int(peer_hello.get("protocol", 0)) != PROTOCOL \
					or String(peer_hello.get("version", "")) != String(my_hello.get("version", "")):
				link.send(["QUIT", "VERSION"])
				_close("VERSIONS DIFFER: %s AND %s" % [my_hello.get("version", "?"),
					peer_hello.get("version", "?")])
				return
			if state == WAITING:
				state = CONNECTED
		"START":
			start = m[1]
			lockstep = Lockstep.new(2, 0, int(start.get("delay", Lockstep.DELAY)))
			state = PLAYING
		"QUIT":
			_close("VERSIONS DIFFER" if m.size() > 1 and m[1] == "VERSION" else "YOUR FRIEND LEFT")
		"I", "H":
			if lockstep:
				lockstep.on_message(m)


## The host starts the match: both build it from this.
## The input delay comes from the line's round trip (Lockstep.for_rtt),
## unless `info` names one.
func begin(info: Dictionary) -> void:
	start = info.duplicate()
	if not start.has("delay"):
		start["delay"] = Lockstep.for_rtt(link.rtt_ms())
	link.send(["START", start])
	lockstep = Lockstep.new(0, 2, int(start["delay"]))
	state = PLAYING


## This frame: the local player's intent goes in; the four slots' intents
## come out when both sides' are here, or null (wait). Presses made while
## waiting are kept for the next step.
func intents(local: SimTypes.Intent) -> Variant:
	commands = []
	_merge(local)
	if lockstep == null or state != PLAYING:
		return null
	if not lockstep.ready():
		lockstep.waited += 1
		return null
	var out := lockstep.advance(_pending, _pending_cmds)
	link.send(out[0])
	_pending = SimTypes.Intent.new()
	_pending_cmds = []
	commands = out[2]
	return out[1]


## A command for the match (Sim.apply, port ADR-102): sent with this side's
## next input, and stepped on both sides delay frames on.
func command(c: Array) -> void:
	_pending_cmds.append(c)


func _merge(it: SimTypes.Intent) -> void:
	_pending.move_x = it.move_x
	_pending.move_y = it.move_y
	_pending.aim_x = it.aim_x
	_pending.aim_y = it.aim_y
	_pending.hit_held = it.hit_held
	_pending.short_held = it.short_held
	if it.hit_pressed:
		_pending.hit_pressed = 1
		_pending.shot = it.shot
	_pending.pause_pressed |= it.pause_pressed


## After a sim step: the hash every HASH_EVERY frames.
func after_step(sim: Sim) -> void:
	if lockstep == null:
		return
	var h := lockstep.hash_after(lockstep.frame - 1, sim)
	if not h.is_empty():
		link.send(h)
	if lockstep.desync >= 0:
		link.send(["QUIT"])
		_close("OUT OF SYNC AT FRAME %d" % lockstep.desync)


func quit() -> void:
	if link and state != CLOSED:
		link.send(["QUIT"])
		link.poll()
	_close("")


func closed() -> bool:
	return state == CLOSED


func _close(why: String) -> void:
	if state == CLOSED:
		return
	state = CLOSED
	reason = why
	if link:
		link.close()


## MatchConfig to a Dictionary and back (START): every script variable but
## the career (online matches play the Player Select look).
static func config_to_dict(cfg: SimTypes.MatchConfig) -> Dictionary:
	var d := {}
	for p in cfg.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["name"] != "career":
			var v = cfg.get(p["name"])
			d[p["name"]] = v.duplicate() if v is Array else v
	return d


static func config_from_dict(d: Dictionary) -> SimTypes.MatchConfig:
	var cfg := SimTypes.MatchConfig.new()
	for k in d:
		var v = d[k]
		if v is Array:
			var a := []
			for x in v:
				a.append(int(x) if (x is float or x is int) else x)
			cfg.set(k, a)
		elif v is float:
			cfg.set(k, int(v))
		else:
			cfg.set(k, v)
	return cfg
