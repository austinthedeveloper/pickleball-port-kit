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
	eq(host.reason, "THE OTHER PLAYER LEFT", "the host hears the guest left")
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
		print("  (skipped: no ../pickleball-relay or no Node)")
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
	eq(b.info()[0], "NO SUCH ROOM", "a wrong room is refused")
	b.room = ""
	b._type(room.to_lower())
	b.page.select("join")
	b.page.press()
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
	OS.kill(pid)
