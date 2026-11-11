## Rooms of seats online (port ADR-111, PORT-118..122): four machines in a
## doubles room through the host's hub, over lines with latency and the
## jitter a lost packet's resend makes; a couch of two on one machine; a
## seat dropping and rejoining (at a serve, mid-rally, on the result
## card); a CPU taking a seat that didn't come back; a watcher; quick chat.
## Headless: sessions and their rollbacks, no views.
extends TestSuite

const LATENCY := 3
const JITTER := [0, 0, 5, 0, 1, 0, 0, 9, 0, 2]   # a lost packet's resend, now and then


## A seat's scripted pad for a frame (the same for the local run).
static func _script(slot: int, f: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	var r := hash([slot, f / 7]) & 0xffffff
	it.move_x = (r % 3) - 1
	it.move_y = ((r >> 3) % 3) - 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	it.hit_pressed = 1 if (hash([slot, f]) & 15) == 0 else 0
	it.hit_held = it.hit_pressed
	it.shot = (r >> 9) % 3 if it.hit_pressed else 0
	return it


class Room:
	var host: OnlineSession
	var guests: Array = []           ## OnlineSession
	var links: Array = []            ## the host's ends, a guest each

	func all() -> Array:
		return [host] + guests


## A room: the host and `players` guests ({players: n, watch: bool} each).
func _room(room_mode: int, host_players: int, guest_specs: Array) -> Room:
	var r := Room.new()
	var first := LoopbackLink.pair(LATENCY, JITTER)
	r.host = OnlineSession.new(first[0], true)
	r.host.mode = room_mode
	r.host.players_here = host_players
	r.host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN", null, host_players)
	r.links.append(first[0])
	for k in guest_specs.size():
		var spec: Dictionary = guest_specs[k]
		var pair: Array = first if k == 0 else LoopbackLink.pair(LATENCY, JITTER)
		if k > 0:
			r.host.add_peer(pair[0])
			r.links.append(pair[0])
		var g := OnlineSession.new(pair[1], false)
		g.my_hello = OnlineSession.hello(PlayerSelect.new_choice((k + 1) % 4, 0, 1), ["BO", "CY", "DEE", "EVE"][k],
			null, int(spec.get("players", 1)), bool(spec.get("watch", false)))
		r.guests.append(g)
		# each guest dials in after the one before is seated
		for i in 30:
			for s in r.all():
				s.poll()
	return r


func _cfg(r: Room, points := 3) -> SimTypes.MatchConfig:
	var doubles := r.host.mode == K.MODE_DOUBLES
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.palette = [0, 1, 2, 3] if doubles else [0, -1, 2, -1]
	var taken := r.host.seats()
	for s in K.MAX_PLAYERS:
		cfg.human[s] = 1 if taken.has(s) else 0
	cfg.points_to_win = points
	return cfg


## Everyone's frame: poll, then each seat's scripted pad (by its machine's
## present) through tick. `skip` machines are away (not polled or ticked).
func _frame(r: Room, skip: Array = []) -> void:
	for s: OnlineSession in r.all():
		if s in skip:
			continue
		s.poll()
		if s.rollback == null or s.state != OnlineSession.PLAYING:
			continue
		var ins := []
		for slot in s.my_slots:
			ins.append(_script(int(slot), s.rollback.predicted))
		s.tick(ins)


func _until(r: Room, done: Callable, cap := 30000, skip: Array = []) -> int:
	var n := 0
	while not done.call() and n < cap:
		_frame(r, skip)
		n += 1
	return n


## The same match on one machine: each seat's input for frame F is its
## pad at F - delay (the delay's first frames empty), as rollback schedules.
func _local_run(cfg: SimTypes.MatchConfig, delay: int, frames: int, cpu_from: Dictionary = {},
		fills: Dictionary = {}) -> Sim:
	var sim := Sim.new(OnlineSession.config_from_dict(OnlineSession.config_to_dict(cfg)))
	for f in frames:
		var human: Array = [null, null, null, null]
		var cmds := []
		for s in K.MAX_PLAYERS:
			if not cfg.human[s]:
				continue
			if cpu_from.has(s) and f >= int(cpu_from[s]):
				if f == int(cpu_from[s]):
					cmds.append(["seat_cpu", s])
				continue
			var filled: Array = fills.get(s, [])
			if f < delay or (not filled.is_empty() and f >= int(filled[0]) and f < int(filled[1])):
				human[s] = SimTypes.Intent.new()
			else:
				var base := f - delay
				if not filled.is_empty() and f >= int(filled[1]):
					base = f - delay       # the rejoiner's present runs from filled[1] - delay
				human[s] = Lockstep.unpack(Lockstep.pack(_script(s, base)))
		sim.step(human, cmds)
	return sim


## The hashes a one-machine run makes where rollback hashes (after frame
## f, every HASH_EVERY), up to `frames`.
func _local_hashes(cfg: SimTypes.MatchConfig, delay: int, frames: int, cpu_from: Dictionary = {}) -> Dictionary:
	var out := {}
	var sim := Sim.new(OnlineSession.config_from_dict(OnlineSession.config_to_dict(cfg)))
	for f in frames:
		var human: Array = [null, null, null, null]
		var cmds := []
		for s in K.MAX_PLAYERS:
			if not cfg.human[s]:
				continue
			if cpu_from.has(s) and f >= int(cpu_from[s]):
				if f == int(cpu_from[s]):
					cmds.append(["seat_cpu", s])
				continue
			human[s] = SimTypes.Intent.new() if f < delay else Lockstep.unpack(Lockstep.pack(_script(s, f - delay)))
		sim.step(human, cmds)
		sim.drain_events()                     # as the room's truth does (they're in the state)
		if f % Rollback.HASH_EVERY == 0:
			out[f] = sim.state_hash()
	sim.dispose()
	return out


## Every machine's hashes agree where they overlap; how many frames compared.
func _agree(r: Room, label: String, machines: Array = []) -> int:
	var ms: Array = machines if not machines.is_empty() else r.all()
	var n := 0
	var first: Dictionary = (ms[0] as OnlineSession).rollback.hash_log
	for s: OnlineSession in ms.slice(1):
		for f in s.rollback.hash_log:
			if first.has(f):
				n += 1
				if first[f] != s.rollback.hash_log[f]:
					check(false, "%s: frame %d differs on %s" % [label, f, str(s.my_slots)])
					return n
	return n


func _keep_logs(r: Room) -> void:
	for s in r.all():
		if s.rollback:
			s.rollback.keep_log = true


func _all_over(r: Room) -> bool:
	for s: OnlineSession in r.all():
		if s.state != OnlineSession.PLAYING or s.rollback.truth.phase != K.PHASE_MATCH_RESULT:
			return false
	return true


func _watcher_caught_up(r: Room, w: OnlineSession) -> bool:
	return w.rollback.confirmed >= r.host.rollback.confirmed - 2 and w.rollback.truth.phase == K.PHASE_MATCH_RESULT


func _close_all(r: Room) -> void:
	for s in r.all():
		s.quit()


## PORT-119: four machines, four seats (0, then 2, 1, 3 as they join),
## over jittery lines: a doubles match to the end, the same on every
## machine as on one, no desync.
func test_four_machines_play_doubles() -> void:
	Rollback.log_all = true
	var r := _room(K.MODE_DOUBLES, 1, [{}, {}, {}])
	eq(r.guests.map(func(g): return g.my_slots), [[2], [1], [3]], "seats in turn: 2, 1, 3")
	eq(r.host.state, OnlineSession.CONNECTED, "the host has company")
	var names: Array = []
	for s in 4:
		names.append(r.guests[2].seat_name(s))
	eq(names, ["ANN", "CY", "BO", "DEE"], "everyone hears who sits where")
	var cfg := _cfg(r)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	eq(r.host.netcode(), OnlineSession.ROLLBACK, "doubles plays rollback")
	var n := _until(r, _all_over.bind(r))
	check(n < 30000, "a doubles match to 3, played through on all four (%d frames)" % n)
	var compared := _agree(r, "four machines")
	check(compared >= 3 * 3, "every machine's hashes agree (%d compared)" % compared)
	var last: int = r.host.rollback.hash_log.keys().max()
	var local := _local_hashes(cfg, 2, last + 1)
	var same := 0
	for f in r.host.rollback.hash_log:
		if local.has(f):
			eq(r.host.rollback.hash_log[f], local[f], "frame %d: the one-machine match" % f)
			same += 1
	check(same >= 3, "the room's match is the one-machine match (%d hashes)" % same)
	check(r.all().all(func(s): return s.rollback.desync < 0), "no desync anywhere")
	check(r.all().any(func(s): return s.rollback.corrections > 0), "guesses were corrected along the way")
	Rollback.log_all = false
	_close_all(r)


## PORT-119: a couch of two on one machine shares a side's pair, and the
## host's couch takes 0 and 1; a machine arriving mid-match isn't seated.
func test_a_couch_takes_a_pair() -> void:
	Rollback.log_all = true
	var r := _room(K.MODE_DOUBLES, 2, [{"players": 2}])
	eq(r.host.host_slots(), [0, 1], "the host's couch: 0 and 1")
	eq(r.guests[0].my_slots, [2, 3], "the guest's couch: 2 and 3")
	var cfg := _cfg(r)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	_until(r, func(): return r.all().all(func(s): return s.rollback and s.rollback.confirmed > 800), 3000)
	check(_agree(r, "couch") >= 5, "both machines play one match, two seats each")
	var local := _local_hashes(cfg, 2, 721)
	eq(r.host.rollback.hash_log.get(720), local[720], "the one-machine match")
	var extra := LoopbackLink.pair(0)
	r.host.add_peer(extra[0])
	var late := OnlineSession.new(extra[1], false)
	late.my_hello = OnlineSession.hello({}, "LATE")
	for i in 20:
		late.poll()
		r.host.poll()
	eq(late.reason, "THEY'RE PLAYING: JOIN TO WATCH", "a match under way takes no new player")
	Rollback.log_all = false
	_close_all(r)


## PORT-120: a seat's line drops at a serve, mid-rally and on the result
## card; everyone waits and counts down, it dials back in and resumes from
## the confirmed state, and every machine still plays one match.
func test_drop_and_rejoin() -> void:
	Rollback.log_all = true
	for when in ["serve", "rally", "result"]:
		_drop_and_rejoin(when)
	Rollback.log_all = false


func _drop_and_rejoin(when: String) -> void:
	var r := _room(K.MODE_DOUBLES, 1, [{}, {}, {}])
	var cfg := _cfg(r, 2)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	var gone: OnlineSession = r.guests[1]              # seat 1, the host's partner
	var arrived := func() -> bool:
		var s: Sim = r.host.rollback.truth
		match when:
			"serve":
				return s.phase <= K.PHASE_SERVE_TOSS and s.team_score[0] + s.team_score[1] >= 1
			"rally":
				return s.phase == K.PHASE_LIVE and s.shot_serial >= 2
		return s.phase == K.PHASE_MATCH_RESULT
	var n := _until(r, arrived)
	check(n < 30000, "%s: got there (%d frames)" % [when, n])
	# the line drops; the guest's dialling fails twice, then works
	var tries := [0]
	gone.redial = func() -> Variant:
		tries[0] += 1
		if tries[0] < 3:
			return null
		var pair := LoopbackLink.pair(LATENCY, JITTER)
		r.host.add_peer(pair[0])
		return pair[1]
	gone.link.close()
	var paused_at: int = r.host.rollback.confirmed
	for i in 90:
		_frame(r)
	check(not r.host.drop.is_empty(), "%s: the host knows the seat dropped" % when)
	check(r.guests[0].drop_seconds() > 50, "%s: the others count down (%d s)" % [when, r.guests[0].drop_seconds()])
	check(r.host.rollback.confirmed <= paused_at + r.host.rollback.window + 4, "%s: and wait" % when)
	_until(r, func(): return gone.state == OnlineSession.PLAYING and r.all().all(func(s): return s.drop.is_empty()), 1000)
	eq([gone.state, r.host.drop.is_empty(), r.guests[0].drop.is_empty()], [OnlineSession.PLAYING, true, true],
		"%s: back in, and everyone hears it" % when)
	var before := r.host.rollback.confirmed
	_until(r, func(): return r.all().all(func(s): return s.rollback.confirmed > before + 500), 3000)
	check(r.all().all(func(s): return s.rollback.confirmed > before + 500), "%s: the match goes on" % when)
	var compared := _agree(r, when)
	check(compared >= 8, "%s: every machine still plays one match (%d hashes)" % [when, compared])
	check(r.all().all(func(s): return s.rollback.desync < 0), "%s: no desync" % when)
	_close_all(r)


## PORT-120: a seat that doesn't come back: past the wait the host gives
## it to a CPU, every machine runs it from the same frame, and the match
## is the one-machine match with a CPU from there.
func test_a_cpu_takes_the_seat() -> void:
	Rollback.log_all = true
	var r := _room(K.MODE_DOUBLES, 1, [{}, {}, {}])
	var cfg := _cfg(r, 5)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	_until(r, func(): return r.host.rollback.confirmed > 400)
	var gone: OnlineSession = r.guests[2]              # seat 3
	gone.link.close()
	_until(r, func(): return not r.host.drop.is_empty(), 400, [gone])
	check(not r.host.drop.is_empty(), "the host sees seat 3 gone")
	r.host.drop["left"] = 1                            # the minute, gone by
	_frame(r, [gone])
	check(bool(r.host.drop.get("expired", false)), "the wait ran out")
	var from := r.host.rollback.last_known(3) + 1
	r.host.seat_to_cpu()
	var rest := [r.host, r.guests[0], r.guests[1]]
	_until(r, func(): return rest.all(func(s): return s.rollback.confirmed > from + 600), 4000, [gone])
	for s: OnlineSession in rest:
		eq(s.rollback.truth.owners[3], K.OWNER_CPU, "seat 3 is a CPU's on %s" % str(s.my_slots))
		check(s.rollback.desync < 0)
	check(_agree(r, "cpu", rest) >= 6, "the three machines agree")
	var last: int = r.host.rollback.hash_log.keys().max()
	var local := _local_hashes(cfg, 2, last + 1, {3: from})
	var after := 0
	for f in r.host.rollback.hash_log:
		if int(f) > from and local.has(f):
			eq(r.host.rollback.hash_log[f], local[f], "frame %d: a CPU in seat 3 from %d" % [f, from])
			after += 1
	check(after >= 3, "the one-machine match with a CPU from the drop (%d hashes)" % after)
	Rollback.log_all = false
	_close_all(r)


## PORT-121: two players and a watcher: the watcher draws the confirmed
## match a beat behind and ends on the same score; a watcher arriving mid-
## match is handed the state, as a rejoin is.
func test_a_watcher_sees_the_match() -> void:
	var r := _room(K.MODE_SINGLES, 1, [{}, {"watch": true}])
	var w: OnlineSession = r.guests[1]
	eq([w.state, w.watcher, w.my_slots], [OnlineSession.CONNECTED, true, []], "a watcher, no seat")
	var cfg := _cfg(r)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	eq(r.host.netcode(), OnlineSession.ROLLBACK, "a room with a watcher plays rollback")
	_until(r, func(): return r.host.rollback.truth.phase == K.PHASE_MATCH_RESULT)
	_until(r, _watcher_caught_up.bind(r, w), 600)
	eq(w.rollback.truth.team_score, r.host.rollback.truth.team_score, "the watcher's final score")
	check(w.rollback.watching and w.rollback.predicted == 0, "it never predicted (it has no seat)")
	# a second watcher, mid-match of a new room
	var r2 := _room(K.MODE_SINGLES, 1, [{}])
	r2.host.begin({"cfg": OnlineSession.config_to_dict(_cfg(r2)), "venue": "park", "delay": 2})
	_until(r2, func(): return r2.host.rollback.confirmed > 500)
	var pair := LoopbackLink.pair(LATENCY)
	r2.host.add_peer(pair[0])
	var late := OnlineSession.new(pair[1], false)
	late.my_hello = OnlineSession.hello({}, "FAN", null, 1, true)
	r2.guests.append(late)
	_until(r2, func(): return late.state == OnlineSession.PLAYING and late.rollback.confirmed > r2.host.rollback.confirmed - 30, 800)
	eq(late.state, OnlineSession.PLAYING, "a late watcher is handed the match")
	var c: int = mini(late.rollback.confirmed, r2.host.rollback.confirmed)
	check(late.rollback.confirmed > 500, "from where it was (%d)" % late.rollback.confirmed)
	check(late.rollback.desync < 0, "and agrees with the host's hashes")
	c = c + 0
	_close_all(r)
	_close_all(r2)


## PORT-122: quick chat: a line goes to every machine, one line in 3 s,
## watchers can't talk, every line in the font's characters.
func test_quick_chat() -> void:
	var r := _room(K.MODE_DOUBLES, 1, [{}, {"watch": true}])
	var g: OnlineSession = r.guests[0]
	var w: OnlineSession = r.guests[1]
	check(g.say(0), "NICE SHOT! goes")
	check(not g.say(1), "a second line inside 3 s doesn't")
	check(not w.say(2), "a watcher doesn't talk")
	for i in 20:
		_frame(r)
	eq(r.host.take_chats(), [[2, 0]], "the host hears seat 2's line")
	eq(w.take_chats(), [[2, 0]], "and so does the watcher, through the host")
	for i in OnlineSession.CHAT_GAP:
		_frame(r)
	check(g.say(1), "3 s on, another")
	for line in OnlineSession.CHAT:
		for ch in String(line):
			check(ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,:-'/%+ ", "%s: the font has %s" % [line, ch])
	_close_all(r)


func _room_view(s: OnlineSession, f: Array) -> MatchView:
	var v := MatchView.new()
	v.net = s
	if not s.my_slots.is_empty():
		var a: int = s.my_slots[0]
		v.input.script_intent = func() -> SimTypes.Intent: return _script(a, f[0])
		if s.my_slots.size() > 1:
			var b: int = s.my_slots[1]
			v.input.script_intent2 = func() -> SimTypes.Intent: return _script(b, f[0])
	runner.root.add_child(v)
	v.setup(OnlineSession.config_from_dict(s.start["cfg"]), "park", false)
	v.input_lock = 0
	return v


## The views in a room (port ADR-111): the host's, a couch of two on the
## guest's (both pads), and a watcher's: the guest's side on the left, the
## watcher drawing the confirmed match, the sides named, quick chat in a
## bubble on the others' screens (not with CHAT MUTED), and one match.
func test_views_in_a_room() -> void:
	Rollback.log_all = true
	var r := _room(K.MODE_DOUBLES, 1, [{"players": 2}, {"watch": true}])
	var cfg := _cfg(r)
	r.host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	for i in 20:
		for s in r.all():
			s.poll()
	var f := [0]
	var hv := _room_view(r.host, f)
	var gv := _room_view(r.guests[0], f)
	var wv := _room_view(r.guests[1], f)
	eq([hv.my_team(), gv.my_team(), hv.mirrored(), gv.mirrored(), wv.mirrored()], [0, 1, false, true, false],
		"the couch's side drawn on the left for them; the watcher's plain")
	check(wv.sim == wv.truth, "the watcher draws the confirmed match")
	eq([hv._hud._team_label(0), hv._hud._team_label(1)], ["YOU + CPU", "BO + P4"], "the host's HUD names the sides")
	eq(gv._hud._team_label(1), "YOU + YOU", "a couch is both YOU")
	eq(wv._hud._team_label(0), "ANN + CPU", "the watcher's by name")
	for i in 700:
		for v in [hv, gv, wv]:
			v._physics_process(1.0 / 60.0)
		f[0] += 1
	check(gv.truth.step_count > 400, "the couch played on (%d frames)" % gv.truth.step_count)
	check(_agree(r, "views") >= 3, "one match on the three machines")
	# quick chat: the couch says NICE SHOT!; the host's screen shows it over seat 2
	Settings.mute_chat = false
	check(r.guests[0].say(0))
	for i in 20:
		for v in [hv, gv, wv]:
			v._physics_process(1.0 / 60.0)
	check([2, 0] in hv.chat.said, "the host sees the couch's line over seat 2")
	check([2, 0] in wv.chat.said, "and so does the watcher")
	check([2, 0] in gv.chat.said, "and the couch sees its own")
	Settings.mute_chat = true
	r.guests[0]._last_chat = -OnlineSession.CHAT_GAP
	check(r.guests[0].say(6))
	for i in 20:
		for v in [hv, gv]:
			v._physics_process(1.0 / 60.0)
	check(not [2, 6] in hv.chat.said, "CHAT MUTED: the others' lines don't show")
	check([2, 6] in gv.chat.said, "but your own still does")
	Settings.mute_chat = false
	Rollback.log_all = false
	for v in [hv, gv, wv]:
		v.free()
	_close_all(r)
