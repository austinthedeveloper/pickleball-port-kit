## An online match's connection (PORT-31, ADR-056; a room of seats, port
## ADR-111): the handshake, the room's seats, and then the netcode.
##
## The host is the room's hub. Each guest machine is a port (a NetLink:
## the relay's Port for that guest, an ENet or loopback link): guests send
## only to the host, and the host forwards each message to every other
## machine in the room, so a guest hears the others a hop later. HELLO
## carries the game's version, the player's look and name, the players at
## that machine (one, or two on a couch) and whether it only watches. The
## host checks the versions, gives seats (ROOM tells everyone who's where)
## and START sends the match (the config, venue, time, court colours and
## the career looks) with each machine's own seats.
##
## Seats: singles is 0 (the host) and 2; doubles fills 0, 2, 1, 3 in turn
## (a couch of two takes a side's pair). A seat nobody took is a CPU's.
## Up to WATCHERS machines may watch, seatless.
##
## START also names the netcode, the host's choice (port ADR-103):
## - "rollback": the session owns the sims (`rollback`: the confirmed one
##   and the prediction); MatchView calls `tick` each frame and draws what
##   comes back. Doubles is always rollback.
## - "lockstep" (ADR-056, singles' fallback): MatchView asks `intents` each
##   frame (null: wait), steps its own sim, and calls `after_step`.
##
## A seat that goes quiet or drops (PORT-120) pauses everyone (the netcode
## waits for its inputs) for up to DROP_WAIT polls, counted down. Its
## machine may rejoin: the host fills its missing frames with neutral
## inputs and sends the confirmed state and every input since (Rollback's
## resume). Past the wait the host may give the seat to a CPU (Sim's
## seat_cpu, at a frame every machine is told) or end the match. The host
## leaving ends it for everyone. QUIT leaves.
class_name OnlineSession
extends RefCounted

const PROTOCOL := 5                ## 5: rooms of seats, watchers, drops, chat (port ADR-111); 4: career looks
## The career look HELLO carries (PORT-115): Career.Player's look fields,
## a few small ints. Display only: never in the config, so never the sim.
const LOOK_KEYS := ["variant", "skin", "hair", "hat", "pattern", "head"]
const ROLLBACK := "rollback"
const LOCKSTEP := "lockstep"
## MatchView plays a rollback match (PORT-109): the host starts what
## OPTIONS says. Off, it starts lockstep and OPTIONS hides the row.
const VIEW_PLAYS_ROLLBACK := true
const IDLE := 0
const WAITING := 1               ## the host's room open, or the guest connecting
const CONNECTED := 2             ## seated (the host: someone else is)
const PLAYING := 3
const CLOSED := 4
const REJOINING := 5             ## a guest whose line dropped, dialling back in
const SEATS_SINGLES := [0, 2]
const SEATS_DOUBLES := [0, 2, 1, 3]
const WATCHERS := 4
const POLLS_A_SECOND := 60
const QUIET_POLLS := 180         ## a seat silent this long mid-match has dropped
const DROP_WAIT := 3600          ## polls everyone waits for a dropped seat (60 s)
## Quick chat (PORT-122): the lines, by number, as the bubble says them.
const CHAT := ["NICE SHOT!", "GOOD GAME!", "ONE MORE?", "OOPS!", "WELL PLAYED!",
	"SO CLOSE!", "THANKS!", "LET'S GO!"]
const CHAT_GAP := 180            ## polls between a machine's lines, at least (3 s)


## A machine in the host's room: its line and what it said.
class Peer:
	var link: NetLink
	var hello := {}
	var slots: Array = []            ## its seats ([] for a watcher, or not seated yet)
	var watcher := false
	var welcomed := false            ## its HELLO was good
	var greeted := false             ## the host's HELLO went to it
	var gone := false
	var quiet := 0                   ## polls since it last said anything
	var last_chat := -CHAT_GAP


var link: NetLink                ## the guest's line to the host; the host's listening one
var host := false
var state := IDLE
var reason := ""                 ## why it closed, for the screen
var notice := ""                 ## the host's: the last guest refused, and why
var mode := K.MODE_SINGLES       ## the host's choice; the guest hears it in ROOM
var players_here := 1            ## the players at this machine (2: a couch)
var watcher := false             ## this machine only watches
var peer_hello := {}             ## the other side's {version, protocol, look, name, ...}: the host's,
                                 ## or (the host's) the first seated guest's
var my_hello := {}
var start := {}                  ## the match, from START
var my_slots: Array = []         ## this machine's seats
var seat_names := {}             ## slot -> name, as ROOM says
var peers: Array = []            ## the host's: Peer, one a machine
var lockstep: Lockstep            ## the netcode's: one of these two
var rollback: Rollback
var drop := {}                   ## a dropped seat: {slots, name, left (polls), expired}
var chats: Array = []            ## quick chat lines heard: [[slot, line]], for the view
var redial: Callable             ## the guest's: a new line to the room, for a rejoin
var _pending: Array = []         ## this machine's presses since the last step, a seat each
var _pending_cmds := []          ## this side's commands since the last step (the host's NEW MATCH)
var commands := []               ## this frame's, both sides' (MatchView steps them)
var _hello_sent := false
var _waited := 0                 ## rollback: ticks in a row that couldn't step
var _polls := 0
var _last_chat := -CHAT_GAP
var _rejoin_left := 0


func _init(l: NetLink = null, is_host := false) -> void:
	link = l
	host = is_host
	if link:
		state = WAITING


## {version, protocol, look, name, career, players, watch} for HELLO: this
## game and its player. A career player (PORT-115) plays in their shirt,
## body and paddle, as every career match does, and `career` carries the
## rest of their look; {} without one.
static func hello(look: Dictionary, name := "", me: Career.Player = null, players := 1,
		watch := false) -> Dictionary:
	var l := look.duplicate()
	if me:
		l = PlayerSelect.new_choice(me.shirt, me.variant, me.paddle)
	return {"version": BuildInfo.version(), "protocol": PROTOCOL, "look": l, "name": name,
		"career": career_look(me), "players": players, "watch": watch}


static func career_look(me: Career.Player) -> Dictionary:
	var d := {}
	if me:
		for k in LOOK_KEYS:
			d[k] = int(me.get(k))
	return d


## A career look from HELLO or START as a Player to draw (its values made
## valid: a peer's bytes can't crash the view), or null for none.
static func look_player(d: Variant) -> Career.Player:
	if not d is Dictionary or (d as Dictionary).is_empty():
		return null
	var src := {}
	for k in LOOK_KEYS:
		src[k] = int((d as Dictionary).get(k, 0))
	src["used"] = 1
	return Career.Player.from_dict(src)


## What a version mismatch says (PORT-115, PORT-117): who has to update.
static func version_line(mine: String, theirs: String) -> String:
	if theirs == "" or theirs == mine:
		return "VERSIONS DIFFER"
	if Updater.compare(theirs, mine) < 0:
		return "YOUR FRIEND HAS %s: THEY NEED TO UPDATE" % theirs
	return "THEY HAVE %s: UPDATE THIS GAME TO PLAY" % theirs


func seat_order() -> Array:
	return SEATS_DOUBLES if mode == K.MODE_DOUBLES else SEATS_SINGLES


## The machines a room takes besides the host's: the other seats, then
## the watchers (RelayLink.host's room size).
static func room_guests(room_mode: int) -> int:
	return (3 if room_mode == K.MODE_DOUBLES else 1) + WATCHERS


# --- The host's room ------------------------------------------------------------------

## The host's own seats: 0, and 1 for a couch partner in doubles.
func host_slots() -> Array:
	return [0, 1] if mode == K.MODE_DOUBLES and players_here == 2 else [0]


## A test's (or a LAN's) guest line, added to the host's room by hand.
func add_peer(l: NetLink) -> Peer:
	var p := Peer.new()
	p.link = l
	peers.append(p)
	return p


func _take_ports() -> void:
	if link is RelayLink:
		for port in (link as RelayLink).take_ports():
			add_peer(port)
	elif link and link.status() == NetLink.CONNECTED \
			and peers.filter(func(p: Peer): return p.link == link).is_empty():
		add_peer(link)                   # ENet's or a loopback's one guest


func _seated_peers() -> Array:
	return peers.filter(func(p: Peer): return not p.gone and not p.slots.is_empty())


func _watchers() -> Array:
	return peers.filter(func(p: Peer): return not p.gone and p.watcher)


## The seats taken (slot -> the peer, or null for the host's own).
func seats() -> Dictionary:
	var out := {}
	for s in host_slots():
		out[s] = null
	for p: Peer in peers:
		if not p.gone or (state == PLAYING and drop.has("slots") and p.slots == drop["slots"]):
			for s in p.slots:
				out[s] = p
	return out


## Free seats for a machine of `n` players: one, or a side's pair.
func _free_seats(n: int) -> Array:
	var taken := seats()
	if n == 2 and mode == K.MODE_DOUBLES:
		for pair in [[2, 3], [0, 1]]:
			if not taken.has(pair[0]) and not taken.has(pair[1]):
				return pair
		return []
	for s in seat_order():
		if not taken.has(s):
			return [s]
	return []


func _on_peer_hello(p: Peer, h: Dictionary) -> void:
	p.hello = h
	if int(h.get("protocol", 0)) != PROTOCOL or String(h.get("version", "")) != String(my_hello.get("version", "")):
		p.link.send(["QUIT", "VERSION", String(my_hello.get("version", ""))])
		notice = version_line(String(my_hello.get("version", "")), String(h.get("version", "")))
		_drop_peer(p)
		return
	p.welcomed = true
	var rejoin: Array = h.get("rejoin", [])
	if not rejoin.is_empty():
		_on_rejoin(p, rejoin)
		return
	if bool(h.get("watch", false)):
		if _watchers().size() >= WATCHERS:
			p.link.send(["QUIT", "FULL"])
			_drop_peer(p)
			return
		if state == PLAYING and rollback == null:
			p.link.send(["QUIT", "PLAYING"])     # lockstep has no state to hand over
			_drop_peer(p)
			return
		p.watcher = true
		if state == PLAYING:
			_resume_for(p)
		_send_room()
		return
	if state == PLAYING:
		p.link.send(["QUIT", "PLAYING"])
		_drop_peer(p)
		return
	var free := _free_seats(clampi(int(h.get("players", 1)), 1, 2))
	if free.is_empty():
		p.link.send(["QUIT", "FULL"])
		_drop_peer(p)
		return
	p.slots = free
	if peer_hello.is_empty():
		peer_hello = h
	state = CONNECTED
	_send_room()


func _drop_peer(p: Peer) -> void:
	p.gone = true
	p.link.poll()
	if not (link is RelayLink) and p.link == link:
		return                           # ENet's one line: the session's own
	p.link.close()


## ROOM to every machine: the mode, who sits where, and their own seats.
func _send_room() -> void:
	var names := {}
	for s in host_slots():
		names[s] = String(my_hello.get("name", "")) if s == 0 else ""
	for p: Peer in _seated_peers():
		for k in p.slots.size():
			names[p.slots[k]] = String(p.hello.get("name", "")) if k == 0 else ""
	seat_names = names
	for p: Peer in peers:
		if p.welcomed and not p.gone:
			p.link.send(["ROOM", {"mode": mode, "seats": names, "you": p.slots, "watch": p.watcher}])


## The host changes the room's mode (only before a match, with nobody
## seated it wouldn't fit).
func set_mode(m: int) -> bool:
	if state == PLAYING or (m == K.MODE_SINGLES and _seated_peers().size() > 1):
		return false
	mode = m
	if mode == K.MODE_SINGLES:
		players_here = 1
		for p: Peer in _seated_peers():
			if p.slots.size() > 1 or p.slots[0] != 2:
				p.slots = [2] if int(p.hello.get("players", 1)) == 1 else []
	_send_room()
	return true


## A seat's name for the HUD: its player's (or YOU), "" for a CPU's.
func seat_name(slot: int) -> String:
	return String(seat_names.get(slot, seat_names.get(str(slot), "")))


func seated(slot: int) -> bool:
	return seat_names.has(slot) or seat_names.has(str(slot))


# --- The frame ---------------------------------------------------------------------------

func poll() -> void:
	if link == null or state == CLOSED:
		return
	_polls += 1
	if host:
		_poll_host()
	else:
		_poll_guest()
	flush()


## Sends what the links hold (RelayLink batches a poll's messages).
func flush() -> void:
	if link:
		link.flush()
	if host and not (link is RelayLink):
		for p: Peer in peers:
			if p.link != link and not p.gone:
				p.link.flush()


func _poll_host() -> void:
	link.poll()
	_take_ports()
	if link is RelayLink and link.status() == NetLink.CLOSED and (link as RelayLink).error != "":
		_close(link.error)
		return
	for p: Peer in peers:
		if p.gone:
			continue
		if not (link is RelayLink) and p.link != link:
			p.link.poll()
		var got := p.link.receive()
		p.quiet = 0 if not got.is_empty() else p.quiet + 1
		for m in got:
			_from_peer(p, m)
			if state == CLOSED:
				return
		if p.link.status() == NetLink.CLOSED and not p.gone:
			_lost(p, p.link.error)
		elif state == PLAYING and not p.slots.is_empty() and p.quiet == QUIET_POLLS:
			_quiet(p)
	if not my_hello.is_empty():
		for p: Peer in peers:
			if not p.gone and not p.greeted and p.link.status() == NetLink.CONNECTED:
				p.link.send(["HELLO", my_hello])
				p.greeted = true
	_count_drop()


func _poll_guest() -> void:
	link.poll()
	for m in link.receive():                 # first: a QUIT may come with the close
		_on(m)
		if state == CLOSED:
			return
	if link.status() == NetLink.CLOSED:
		if state == PLAYING and rollback and redial.is_valid():
			_start_rejoin()
			return
		if state == REJOINING:
			_rejoin_left -= 1
			if _rejoin_left <= 0:
				_close("YOUR LINE DROPPED")
			elif _rejoin_left % POLLS_A_SECOND == 0:
				_start_rejoin()          # dial again
			return
		_close(link.error if link.error != "" else "CONNECTION LOST")
		return
	if link.status() == NetLink.CONNECTED and not _hello_sent and not my_hello.is_empty():
		var h := my_hello.duplicate()
		if state == REJOINING:
			h["rejoin"] = my_slots
		link.send(["HELLO", h])
		_hello_sent = true
	_count_drop()


## A guest's message at the host: its own, the room's, or one to forward.
func _from_peer(p: Peer, m: Array) -> void:
	match m[0]:
		"HELLO":
			_on_peer_hello(p, m[1])
		"QUIT":
			if m.size() > 2 and m[1] == "VERSION":
				notice = version_line(String(my_hello.get("version", "")), String(m[2]))
			_lost(p, "LEFT")
		"K":
			pass                             # a stalled machine, still there
		"I", "H":
			if not p.welcomed or p.watcher:
				return
			if rollback:
				rollback.on_message(m)
			elif lockstep:
				lockstep.on_message(m)
			_forward(p, m)
		"C":
			if p.watcher or _polls - p.last_chat < CHAT_GAP:
				return                       # one line in 3 s
			p.last_chat = _polls
			chats.append([int(m[1]), int(m[2])])
			_forward(p, m)


## A guest's message on to every other machine in the room.
func _forward(from: Peer, m: Array) -> void:
	for p: Peer in peers:
		if p != from and p.welcomed and not p.gone:
			p.link.send(m)


func _send_all(m: Array) -> void:
	if host:
		for p: Peer in peers:
			if p.welcomed and not p.gone:
				p.link.send(m)
	else:
		link.send(m)


## A guest's message at a guest: the host's, or another machine's forwarded.
func _on(m: Array) -> void:
	match m[0]:
		"HELLO":
			peer_hello = m[1]
			if int(peer_hello.get("protocol", 0)) != PROTOCOL \
					or String(peer_hello.get("version", "")) != String(my_hello.get("version", "")):
				link.send(["QUIT", "VERSION", String(my_hello.get("version", ""))])
				_close(version_line(String(my_hello.get("version", "")), String(peer_hello.get("version", ""))))
		"ROOM":
			var r: Dictionary = m[1]
			mode = int(r.get("mode", K.MODE_SINGLES))
			seat_names = r.get("seats", {})
			if state == WAITING and (not (r.get("you", []) as Array).is_empty() or bool(r.get("watch", false))):
				state = CONNECTED
				my_slots = r.get("you", [])
				watcher = bool(r.get("watch", false))
		"START":
			start = m[1]
			if start.has("seats"):
				seat_names = start["seats"]
			mode = int(OnlineSession.config_from_dict(start["cfg"]).mode)
			my_slots = start.get("you", [])
			watcher = bool(start.get("watch", false))
			_build_guest()
			drop = {}
			state = PLAYING
		"QUIT":
			if m.size() > 1 and m[1] == "VERSION":
				var theirs := String(m[2]) if m.size() > 2 else String(peer_hello.get("version", ""))
				_close(version_line(String(my_hello.get("version", "")), theirs))
			elif m.size() > 1 and m[1] == "FULL":
				_close("THAT ROOM IS FULL: HOST YOUR OWN")
			elif m.size() > 1 and m[1] == "PLAYING":
				_close("THEY'RE PLAYING: JOIN TO WATCH")
			elif m.size() > 1 and m[1] == "ENDED":
				_close("THE HOST ENDED THE MATCH")
			else:
				_close("THE HOST LEFT" if mode == K.MODE_DOUBLES else "YOUR FRIEND LEFT")
		"I", "H":
			if rollback:
				rollback.on_message(m)
			elif lockstep:
				lockstep.on_message(m)
		"C":
			chats.append([int(m[1]), int(m[2])])
		"DROP":
			drop = {"slots": m[1], "name": String(m[2]), "left": int(m[3]), "expired": false}
		"BACK":
			drop = {}
		"FILL":
			if rollback:
				rollback.fill(int(m[1]), int(m[2]), int(m[3]))
		"CPU":
			if rollback:
				rollback.retire(int(m[1]), int(m[2]))
			seat_names.erase(int(m[1]))
			seat_names.erase(str(m[1]))
			drop = {}


# --- Starting ------------------------------------------------------------------------------

## The host starts the match: every machine builds it from this. The input
## delay comes from the line's round trip (Lockstep.for_rtt), unless
## `info` names one. Doubles plays rollback.
func begin(info: Dictionary) -> void:
	start = info.duplicate()
	if not start.has("netcode"):
		start["netcode"] = Settings.netcode_name() if VIEW_PLAYS_ROLLBACK else LOCKSTEP
	if mode == K.MODE_DOUBLES or not _watchers().is_empty():
		start["netcode"] = ROLLBACK          # rooms and watchers need rollback's state
	if not start.has("delay"):
		var rtt := 0
		for p: Peer in _seated_peers():
			rtt = maxi(rtt, p.link.rtt_ms())
		if rtt == 0 and link:
			rtt = link.rtt_ms()
		start["delay"] = Rollback.for_rtt(rtt) if start["netcode"] == ROLLBACK else Lockstep.for_rtt(rtt)
	_send_room()
	start["seats"] = seat_names.duplicate()
	if not start.has("looks"):
		start["looks"] = looks()
	my_slots = host_slots()
	_build(my_slots, _human_seats().filter(func(s): return not s in my_slots))
	for p: Peer in peers:
		if p.welcomed and not p.gone:
			var mine := start.duplicate()
			mine["you"] = p.slots
			mine["watch"] = p.watcher
			p.link.send(["START", mine])
	drop = {}
	state = PLAYING


## The career looks by seat (PORT-115): the host's, then each guest's first.
func looks() -> Dictionary:
	var out := {"0": my_hello.get("career", {})}
	for p: Peer in _seated_peers():
		out[str(p.slots[0])] = p.hello.get("career", {})
	return out


## The match's human seats: START's config says.
func _human_seats() -> Array:
	var out := []
	var cfg: Dictionary = start.get("cfg", {})
	var hum: Array = cfg.get("human", [1, 0, 1, 0])
	for s in K.MAX_PLAYERS:
		if int(hum[s]):
			out.append(s)
	return out


## This machine's netcode for START's match (`local` its seats). A START
## from before PROTOCOL 3 had no netcode: lockstep.
func _build(local: Array, remote: Array) -> void:
	_pending = []
	for s in local:
		_pending.append(SimTypes.Intent.new())
	if netcode() == ROLLBACK:
		rollback = Rollback.new(config_from_dict(start["cfg"]), local, remote,
			int(start.get("delay", Rollback.DELAY)))
	else:
		lockstep = Lockstep.new(int(local[0]), int(remote[0]), int(start.get("delay", Lockstep.DELAY)))


func _build_guest() -> void:
	var others := _human_seats().filter(func(s): return not s in my_slots)
	if not start.has("resume"):
		_build(my_slots, others)
		return
	var r: Dictionary = start["resume"]
	if rollback == null:                 # a watcher arriving mid-match
		rollback = Rollback.new(config_from_dict(start["cfg"]), my_slots, others,
			int(start.get("delay", Rollback.DELAY)))
		_pending = []
		for s in my_slots:
			_pending.append(SimTypes.Intent.new())
	rollback.restart(r["state"], int(r["frame"]), r["inputs"], r["cmds"], r["extra"],
		int(start.get("present", r["frame"])))
	for c in r.get("retired", []):
		rollback._retired[int(c[0])] = int(c[1])


func netcode() -> String:
	return String(start.get("netcode", LOCKSTEP))


# --- Drops and rejoins (PORT-120) ------------------------------------------------------------

## A seated machine went silent mid-match: everyone waits (the netcode
## already does) and counts down.
func _quiet(p: Peer) -> void:
	if drop.is_empty():
		_announce_drop(p)


func _lost(p: Peer, why: String) -> void:
	var seated_in_play := state == PLAYING and not p.slots.is_empty()
	p.gone = true
	if p.link != link or link is RelayLink:
		p.link.close()
	if p.watcher:
		_send_room()
		return
	if not seated_in_play:
		p.slots = []
		var any := _seated_peers()
		state = CONNECTED if not any.is_empty() else WAITING
		if any.is_empty():
			peer_hello = {}
		_send_room()
		return
	if rollback == null or (why == "LEFT" and mode == K.MODE_SINGLES):
		_close("YOUR FRIEND LEFT")           # lockstep can't rejoin; singles' leaving ends it
		return
	_announce_drop(p, 0 if why == "LEFT" else DROP_WAIT)


func _announce_drop(p: Peer, wait := DROP_WAIT) -> void:
	var name := String(p.hello.get("name", ""))
	drop = {"slots": p.slots, "name": name if name != "" else "YOUR FRIEND", "left": wait,
		"expired": wait <= 0, "peer": p}
	_send_all(["DROP", p.slots, drop["name"], wait])


## A second of the countdown, on every machine; the host's runs out.
func _count_drop() -> void:
	if drop.is_empty() or bool(drop.get("expired", false)):
		return
	drop["left"] = int(drop["left"]) - 1
	if host and int(drop["left"]) <= 0:
		drop["expired"] = true
	if host and drop.has("peer") and not (drop["peer"] as Peer).gone and (drop["peer"] as Peer).quiet == 0:
		drop = {}                            # quiet, not gone: it spoke again
		_send_all(["BACK"])


## Seconds left of a drop's wait (0: the host decides).
func drop_seconds() -> int:
	return 0 if drop.is_empty() else maxi(0, (int(drop["left"]) + POLLS_A_SECOND - 1) / POLLS_A_SECOND)


## The host's, past the wait: a CPU plays the dropped seats on, from the
## frame after each one's last known input (every machine is told).
func seat_to_cpu() -> void:
	if not host or drop.is_empty() or rollback == null:
		return
	for s in drop["slots"]:
		var from := rollback.last_known(int(s)) + 1
		rollback.retire(int(s), from)
		_send_all(["CPU", int(s), from])
		seat_names.erase(s)
	if drop.has("peer"):
		(drop["peer"] as Peer).slots = []
	drop = {}


## The host's, past the wait: the match ends for everyone (no record).
func end_match() -> void:
	_send_all(["QUIT", "ENDED"])
	_close("THE MATCH ENDED")


## A dropped machine back (a new line, HELLO's rejoin): its missing frames
## filled with neutral inputs on every machine, then the confirmed state
## and every input since, so it carries on from the present.
func _on_rejoin(p: Peer, slots: Array) -> void:
	if drop.is_empty() or rollback == null or str(drop["slots"]) != str(slots):
		p.link.send(["QUIT", "PLAYING"])
		_drop_peer(p)
		return
	var old: Peer = drop.get("peer")
	if old:
		old.slots = []
		old.gone = true
	p.slots = slots
	var to := rollback.predicted + rollback.delay + 2
	for s in slots:
		var from := rollback.last_known(int(s)) + 1
		rollback.fill(int(s), from, to)
		for q: Peer in peers:
			if q != p and q.welcomed and not q.gone:
				q.link.send(["FILL", int(s), from, to])
	_resume_for(p, to - rollback.delay)
	drop = {}
	for q: Peer in peers:
		if q != p and q.welcomed and not q.gone:
			q.link.send(["BACK"])


## START for a machine joining a match under way: the confirmed state and
## what's known since (a watcher's present doesn't matter).
func _resume_for(p: Peer, present := -1) -> void:
	var mine := start.duplicate()
	mine["you"] = p.slots
	mine["watch"] = p.watcher
	var r := rollback.snapshot_for_resume() if rollback else {}
	var retired := []
	if rollback:
		for s in rollback._retired:
			retired.append([s, rollback._retired[s]])
	r["retired"] = retired
	mine["resume"] = r
	mine["present"] = present if present >= 0 else rollback.predicted
	p.link.send(["START", mine])


## The guest's line dropped mid-match: dial the room again and say which
## seats are ours.
func _start_rejoin() -> void:
	if state != REJOINING:
		state = REJOINING
		_rejoin_left = DROP_WAIT
		drop = {"slots": my_slots, "name": "YOU", "left": DROP_WAIT, "expired": false}
	var l: Variant = redial.call()
	if l is NetLink:
		link = l
		_hello_sent = false


# --- The frame's netcode ------------------------------------------------------------------------

## Rollback's frame (ADR-103): the local seats' intents go in (one, or a
## list), kept with any presses from frames that couldn't step, and what
## the frame did comes out (Rollback.tick's: stepped, played, counted). A
## desync closes the session. A watcher's only confirms.
func tick(local: Variant) -> Dictionary:
	var ins: Array = local if local is Array else [local]
	for k in mini(ins.size(), _pending.size()):
		if ins[k] != null:
			_merge(k, ins[k])
	if rollback == null or state != PLAYING:
		return {"stepped": false, "send": [], "played": [], "counted": []}
	var out := rollback.tick(_pending, _pending_cmds)
	for m in out["send"]:
		_send_all(m)
	flush()
	if out["stepped"]:
		for k in _pending.size():
			_pending[k] = SimTypes.Intent.new()
		_pending_cmds = []
		_waited = 0
	elif not rollback.watching:
		_waited += 1
		if _waited % 30 == 0:
			_send_all(["K"])                 # still here, waiting (not a drop)
	if rollback.desync >= 0:
		_send_all(["QUIT"])
		_close("OUT OF SYNC AT FRAME %d" % rollback.desync)
	return out


## Frames in a row this side has waited for the other (either netcode):
## past 20 the match says WAITING FOR YOUR FRIEND.
func waited() -> int:
	if rollback:
		return _waited
	return lockstep.waited if lockstep else 0


## This frame: the local player's intent goes in; the four slots' intents
## come out when both sides' are here, or null (wait). Presses made while
## waiting are kept for the next step.
func intents(local: SimTypes.Intent) -> Variant:
	commands = []
	if _pending.is_empty():
		_pending = [SimTypes.Intent.new()]
	_merge(0, local)
	if lockstep == null or state != PLAYING:
		return null
	if not lockstep.ready():
		lockstep.waited += 1
		return null
	var out := lockstep.advance(_pending[0], _pending_cmds)
	_send_all(out[0])
	flush()
	_pending[0] = SimTypes.Intent.new()
	_pending_cmds = []
	commands = out[2]
	return out[1]


## A command for the match (Sim.apply, port ADR-102): sent with this side's
## next input, and stepped on every machine delay frames on.
func command(c: Array) -> void:
	_pending_cmds.append(c)


func _merge(k: int, it: SimTypes.Intent) -> void:
	var p: SimTypes.Intent = _pending[k]
	p.move_x = it.move_x
	p.move_y = it.move_y
	p.aim_x = it.aim_x
	p.aim_y = it.aim_y
	p.hit_held = it.hit_held
	p.short_held = it.short_held
	if it.hit_pressed:
		p.hit_pressed = 1
		p.shot = it.shot
	p.pause_pressed |= it.pause_pressed


## After a sim step: the hash every HASH_EVERY frames.
func after_step(sim: Sim) -> void:
	if lockstep == null:
		return
	var h := lockstep.hash_after(lockstep.frame - 1, sim)
	if not h.is_empty():
		_send_all(h)
		flush()
	if lockstep.desync >= 0:
		_send_all(["QUIT"])
		_close("OUT OF SYNC AT FRAME %d" % lockstep.desync)


# --- Quick chat (PORT-122) ---------------------------------------------------------------------

## Sends a line (CHAT's number) from this machine's first seat: false when
## it's too soon after the last (one line in 3 s) or this machine watches.
func say(line: int) -> bool:
	if watcher or my_slots.is_empty() or line < 0 or line >= CHAT.size() or _polls - _last_chat < CHAT_GAP:
		return false
	_last_chat = _polls
	var m := ["C", int(my_slots[0]), line]
	chats.append([int(my_slots[0]), line])
	_send_all(m)
	return true


## The chat lines heard since the last call: [[slot, line]].
func take_chats() -> Array:
	var out := chats
	chats = []
	return out


# --- Leaving ------------------------------------------------------------------------------------

func quit() -> void:
	if state != CLOSED:
		if host:
			_send_all(["QUIT"])
			for p: Peer in peers:
				if not p.gone:
					p.link.poll()
		elif link:
			link.send(["QUIT"])
			link.poll()
	_close("")


func closed() -> bool:
	return state == CLOSED


func _close(why: String) -> void:
	if state == CLOSED:
		return
	state = CLOSED
	if rollback:
		rollback.dispose()               # its two sims (ADR-100's cycle)
	reason = why
	if link:
		link.close()
	for p: Peer in peers:
		if p.link != link:
			p.link.close()


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
