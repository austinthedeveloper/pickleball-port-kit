## Online by room (port ADR-105): RelayLink against a stand-in relay (the
## relay's frames, in this process: always runs), then the ONLINE screens
## through the real relay server (pickleball-relay, beside the port kit,
## started with Node; skipped when either is missing, as on CI).
extends TestSuite

const DT := 1.0 / 60.0
const FAKE_PORT := 24994 + 13
const NODE_PORT := 24994 + 14


static func _script(f: int, seed: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	var r := (f * 1103515245 + seed * 12345) & 0x7fffffff
	it.move_x = ((r >> 8) % 3) - 1
	it.move_y = ((r >> 12) % 3) - 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	it.hit_pressed = 1 if (r >> 16) % 11 == 0 else 0
	it.hit_held = it.hit_pressed
	it.shot = (r >> 20) % 3 if it.hit_pressed else 0
	return it


## The relay's side of one room, as pickleball-relay frames it: the first
## to dial is the host (room BXKM), the second the guest (number 0). The
## host's frames carry the guest's number; the guest's are bare.
class FakeRelay:
	var server := TCPServer.new()
	var peers: Array = []            ## [WebSocketPeer, greeted]

	func _init(port: int) -> void:
		server.listen(port, "127.0.0.1")

	func pump() -> void:
		while server.is_connection_available():
			var ws := WebSocketPeer.new()
			ws.accept_stream(server.take_connection())
			peers.append([ws, false])
		for i in peers.size():
			var ws: WebSocketPeer = peers[i][0]
			ws.poll()
			if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
				continue
			if not peers[i][1]:
				peers[i][1] = true
				if i == 0:
					ws.send_text(JSON.stringify({"op": "room", "code": "BXKM"}))
				else:
					ws.send_text(JSON.stringify({"op": "welcome", "you": 0, "ver": ""}))
					say(0, {"op": "joined", "guest": 0, "ver": ""})
			while ws.get_available_packet_count() > 0:
				var b := ws.get_packet()
				if ws.was_string_packet() or peers.size() < 2:
					continue
				if i == 0:
					(peers[1][0] as WebSocketPeer).send(b.slice(1))
				else:
					var out := PackedByteArray([0])
					out.append_array(b)
					(peers[0][0] as WebSocketPeer).send(out)

	func say(i: int, msg: Dictionary) -> void:
		(peers[i][0] as WebSocketPeer).send_text(JSON.stringify(msg))

	func stop() -> void:
		for p in peers:
			(p[0] as WebSocketPeer).close()
		server.stop()


## Polls both sessions (and the fake relay, if any) until `done` or `tries` run out.
func _until(sessions: Array, done: Callable, tries := 600, relay: FakeRelay = null) -> int:
	var n := 0
	while not done.call() and n < tries:
		if relay:
			relay.pump()
		for s in sessions:
			s.poll()
		OS.delay_msec(2)
		n += 1
	return n


func test_a_room_name_is_cleaned() -> void:
	eq(RelayLink.clean_room("bxkm"), "BXKM", "capitals")
	eq(RelayLink.clean_room("b-x k!mz"), "BXKM", "only the alphabet, four at most")
	eq(RelayLink.clean_room("BOAT"), "BT", "no vowels in a room")
	var l := RelayLink.new()
	check(not l.join("BX"), "a short room isn't dialled")
	eq(l.error, "A ROOM IS 4 LETTERS")


## Two sessions through the stand-in: the room, the handshake, the line's
## round trip measured, 300 frames of lockstep the same on both, then the
## guest leaving and a relay's refusal said in the game's words.
func test_two_games_through_a_relay() -> void:
	var relay := FakeRelay.new(FAKE_PORT)
	var url := "ws://127.0.0.1:%d" % FAKE_PORT
	var hl := RelayLink.new()
	check(hl.host(url), "the host dials")
	var host := OnlineSession.new(hl, true)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1))
	_until([host], func(): return hl.room != "", 300, relay)
	eq(hl.room, "BXKM", "the relay names the room")
	eq(host.state, OnlineSession.WAITING, "the host waits")
	var gl := RelayLink.new()
	check(gl.join("bxkm", url), "the guest dials the room")
	var guest := OnlineSession.new(gl, false)
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 1))
	var both := func(): return host.state == OnlineSession.CONNECTED and guest.state == OnlineSession.CONNECTED \
		and hl.rtt_ms() > 0 and gl.rtt_ms() > 0
	var tries := _until([host, guest], both, 600, relay)
	eq([host.state, guest.state], [OnlineSession.CONNECTED, OnlineSession.CONNECTED],
		"the handshake through the relay (%d polls; %s %s)" % [tries, host.reason, guest.reason])
	check(hl.rtt_ms() > 0 and gl.rtt_ms() > 0, "both measured the line (%d, %d ms)" % [hl.rtt_ms(), gl.rtt_ms()])
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello["look"])
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "netcode": OnlineSession.LOCKSTEP})
	var sims := [Sim.new(cfg), null]
	var steps := [0, 0]
	var trail := [[], []]
	var loops := 0
	while (steps[0] < 300 or steps[1] < 300) and loops < 20000:
		loops += 1
		relay.pump()
		for side in 2:
			var s: OnlineSession = [host, guest][side]
			s.poll()
			if s.state == OnlineSession.PLAYING and sims[side] == null:
				sims[side] = Sim.new(OnlineSession.config_from_dict(s.start["cfg"]))
			if sims[side] == null or steps[side] >= 300:
				continue
			var human = s.intents(_script(steps[side], 11 + side))
			if human == null:
				continue
			sims[side].step(human)
			s.after_step(sims[side])
			steps[side] += 1
			trail[side].append(str(sims[side].snapshot()).hash())
		OS.delay_msec(1)
	eq(steps, [300, 300], "300 frames each (%d loops)" % loops)
	eq(trail[0], trail[1], "the same sim on both, every frame")
	# The relay's words for a guest leaving, then for the host going.
	relay.say(0, {"op": "left", "guest": 0})
	_until([host], func(): return host.closed(), 100, relay)
	eq(host.reason, "YOUR FRIEND LEFT", "the host hears the guest left (lockstep: no rejoin)")
	relay.say(1, {"op": "error", "reason": "HOST LEFT"})
	_until([guest], func(): return guest.closed(), 100, relay)
	eq(guest.reason, "THE OTHER PLAYER LEFT", "and the guest, the host")
	hl.close()
	gl.close()
	relay.stop()
	for s in sims:
		if s:
			s.dispose()


## pickleball-relay's server.js, beside the port kit ("" if it isn't there
## or Node isn't installed).
func _relay_server() -> String:
	var js := ProjectSettings.globalize_path("res://").path_join("../../pickleball-relay/server.js").simplify_path()
	var env := OS.get_environment("PB94_RELAY_JS")    # another checkout's (a worktree's)
	if env != "":
		js = env.path_join("server.js") if not env.ends_with(".js") else env
	if not FileAccess.file_exists(js):
		return ""
	var out := []
	if OS.execute("node", ["--version"], out) != 0:
		return ""
	return js


## The ONLINE screens through the real relay: HOST shows the room, the
## other screen types it and JOINS, a wrong room is refused, and the host
## starts the match.
func test_the_screens_through_the_real_relay() -> void:
	var js := _relay_server()
	if js == "":
		check(true, "skipped: no ../pickleball-relay or no Node (as on CI)")
		return
	var pid := OS.create_process("node", ["-e",
		"require(%s).createRelay({log: () => {}}).listen(%d)" % [JSON.stringify(js), NODE_PORT]])
	check(pid > 0, "the relay starts")
	OS.delay_msec(700)
	var url := "ws://127.0.0.1:%d" % NODE_PORT
	var a := OnlineScreen.new().setup(null)
	var b := OnlineScreen.new().setup(null)
	for s in [a, b]:
		s.relay_url = url
		runner.root.add_child(s)
		if not s.is_node_ready():
			s._ready()
	var played := [[], []]
	a.play.connect(func(s): played[0].append(s))
	b.play.connect(func(s): played[1].append(s))
	eq(a.way, OnlineScreen.BY_ROOM, "by room, by default")
	a.page.select("host")
	a.page.press()
	var tries := 0
	while a._room() == "" and tries < 500:
		a._process(DT)
		OS.delay_msec(2)
		tries += 1
	var room := a._room()
	eq(room.length(), 4, "the host has a room (%s)" % a.info()[0])
	eq(a.info()[0], "YOUR ROOM: " + room, "and says it")
	eq(a._host_value(), "ROOM " + room, "on the HOST row too")
	# A wrong room first.
	b.page.select("address")
	b.page.press()
	check(b.editing, "ROOM: typing")
	b._type("zzzz")
	b.page.press()
	b.page.select("join")
	b.page.press()
	tries = 0
	while not (b.session and b.session.closed()) and tries < 500:
		b._process(DT)
		OS.delay_msec(2)
		tries += 1
	eq(b.info()[0], "NO SUCH ROOM: CHECK THE LETTERS", "a wrong room is refused, and says what to do")
	# The right room on the letter grid (PORT-116), as a pad picks it:
	# rows by id, a letter at a time, then JOIN.
	b.room = ""
	b.page.select("address")
	b.page.press()
	check(b.grid.visible and not b.page.visible, "ROOM: the letter grid")
	b.grid_type(room)
	eq(b.room, room, "typed on the grid")
	eq([b.grid.current_id(), b.grid_cols[OnlineScreen.grid_rows() - 1]], ["g%d" % (OnlineScreen.grid_rows() - 1), 1],
		"four letters: the cursor on JOIN")
	b.grid.press()
	check(not b.grid.visible and b.session != null, "JOIN on the grid joins")
	tries = 0
	while (a._state() != OnlineSession.CONNECTED or b._state() != OnlineSession.CONNECTED) and tries < 800:
		a._process(DT)
		b._process(DT)
		OS.delay_msec(2)
		tries += 1
	eq([a._state(), b._state()], [OnlineSession.CONNECTED, OnlineSession.CONNECTED], "connected through the relay")
	a.page.select("host")
	a.page.press()
	tries = 0
	while played[1].is_empty() and tries < 500:
		b._process(DT)
		a.session.poll()
		OS.delay_msec(2)
		tries += 1
	eq([played[0].size(), played[1].size()], [1, 1], "both play the match")
	a.session.quit()
	b.session.quit()
	a.free()
	b.free()
	_real_refusals(url)
	_real_doubles(url)
	OS.kill(pid)


## Four machines in a doubles room through the real relay (port ADR-111):
## the host sizes the room, three guests take seats 2, 1, 3, and the frames
## of rollback (360 frames, at the game's pace) agree on all four. The host's forwarding goes as one batch
## a guest a poll, inside the relay's rate (no TOO FAST).
func _real_doubles(url: String) -> void:
	var js := _relay_server()
	if not FileAccess.get_file_as_string(js).contains("ROOM_DEFAULT"):
		check(true, "skipped: this relay's rooms take one guest (before rooms of seats)")
		return
	var hl := RelayLink.new()
	hl.host(url, OnlineSession.room_guests(K.MODE_DOUBLES))
	var host := OnlineSession.new(hl, true)
	host.mode = K.MODE_DOUBLES
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN")
	var all := [host]
	for i in 300:
		host.poll()
		if hl.room != "":
			break
		OS.delay_msec(2)
	for k in 3:
		var gl := RelayLink.new()
		gl.join(hl.room, url)
		var g := OnlineSession.new(gl, false)
		g.my_hello = OnlineSession.hello(PlayerSelect.new_choice(k + 1, 0, 1), ["BO", "CY", "DEE"][k])
		all.append(g)
		for i in 600:
			for s: OnlineSession in all:
				s.poll()
			if g.state == OnlineSession.CONNECTED:
				break
			OS.delay_msec(2)
	eq(all.slice(1).map(func(g): return g.my_slots), [[2], [1], [3]], "three guests seated through the relay")
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.palette = [0, 1, 2, 3]
	cfg.human = [1, 1, 1, 1]
	Rollback.log_all = true
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 2})
	var loops := 0
	var start_ms := Time.get_ticks_msec()
	while loops < 3000 and not all.all(func(s): return s.rollback and s.rollback.confirmed > 360):
		loops += 1
		for s: OnlineSession in all:
			s.poll()
			if s.state == OnlineSession.PLAYING and s.rollback:
				var ins := []
				for slot in s.my_slots:
					ins.append(_script(s.rollback.predicted, 11 + int(slot)))
				s.tick(ins)
		# the game's pace: a frame every 1/60 s (the relay's rate is per second)
		var due := start_ms + loops * 1000 / 60
		OS.delay_msec(maxi(0, due - Time.get_ticks_msec()))
	check(all.all(func(s): return s.rollback and s.rollback.confirmed > 360), "360 frames on all four (%d loops; %s)" %
		[loops, ", ".join(all.map(func(s): return s.reason))])
	var first: Dictionary = host.rollback.hash_log
	var n := 0
	for s: OnlineSession in all.slice(1):
		for f in s.rollback.hash_log:
			if first.has(f):
				n += 1
				eq(s.rollback.hash_log[f], first[f], "frame %d the same on %s" % [f, str(s.my_slots)])
	check(n >= 6, "the four agree (%d hashes)" % n)
	check(all.all(func(s): return s.state == OnlineSession.PLAYING), "nobody was cut off (no TOO FAST)")
	Rollback.log_all = false
	for s in all:
		s.quit()


## PORT-117: the real relay's refusals, each in the game's words: a full
## room, and a host on another version (the welcome says it, before the
## handshake).
func _real_refusals(url: String) -> void:
	var h := RelayLink.new()
	h.host(url)
	_poll_links([h], func(): return h.room != "")
	var g1 := RelayLink.new()
	g1.join(h.room, url)
	_poll_links([h, g1], func(): return g1.status() == NetLink.CONNECTED)
	var g2 := RelayLink.new()
	g2.join(h.room, url)
	_poll_links([h, g1, g2], func(): return g2.error != "")
	eq(g2.error, "THAT ROOM IS FULL: HOST YOUR OWN", "a full room")
	for l in [h, g1, g2]:
		l.close()
	var old := RelayLink.new()
	old._dial("%s/v1/host?game=%s&ver=0.1.0" % [url, RelayLink.GAME])
	old._hosting = true
	_poll_links([old], func(): return old.room != "")
	var g := RelayLink.new()
	g.join(old.room, url)
	_poll_links([old, g], func(): return g.error != "")
	eq(g.error, "YOUR FRIEND HAS 0.1.0: THEY NEED TO UPDATE", "a host on an older version")
	old.close()
	g.close()


func _poll_links(links: Array, done: Callable) -> void:
	for i in 600:
		for l in links:
			l.poll()
		if done.call():
			return
		OS.delay_msec(2)


## PORT-117: every refusal the relay sends (pickleball-relay server.js's
## refuse() words) has a line on the screen, short enough for it, in the
## font's characters; a welcome from a host on another version is told
## who updates; a dial asleep counts down.
func test_each_refusal_has_a_line() -> void:
	for r in ["NO SUCH ROOM", "ROOM FULL", "SERVER FULL", "TOO MANY TRIES", "TOO MANY ROOMS",
			"TOO FAST", "NO SUCH GAME", "HOST LEFT", "IDLE", "TIME UP"]:
		var l := RelayLink.new()
		l._control({"op": "error", "reason": r})
		check(l.error != r or r == "NO SUCH ROOM", "%s: said as %s" % [r, l.error])
		check(BitmapText.measure("small", l.error) < 820, "%s: fits the panel" % r)
	var mine := BuildInfo.version()
	var newer := RelayLink.new()
	newer._control({"op": "welcome", "you": 0, "ver": "99.0.0"})
	eq(newer.error, "THEY HAVE 99.0.0: UPDATE THIS GAME TO PLAY", "a newer host: update this one")
	var same := RelayLink.new()
	same._control({"op": "welcome", "you": 0, "ver": mine})
	eq(same.error, "", "the same version: in")
	var any := RelayLink.new()
	any._control({"op": "welcome", "you": 0, "ver": ""})
	eq(any.error, "", "a relay that doesn't say: the handshake checks")
	# asleep: the countdown runs from TIMEOUT_MS
	var slow := RelayLink.new()
	slow._started_ms = Time.get_ticks_msec() - 5000
	slow._hosting = true
	var left := slow.seconds_left()
	check(left <= RelayLink.TIMEOUT_MS / 1000 - 5 + 1 and left >= RelayLink.TIMEOUT_MS / 1000 - 6,
		"the wait counts down (%d s left)" % left)
