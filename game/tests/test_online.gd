## Online play (PORT-31, ADR-056): lockstep keeps two sims identical over
## a line with latency and jitter, waits when an input is late, catches a
## desync, and the session's handshake builds the same match on both
## sides; the real ENet link connects and plays on this machine.
extends TestSuite

const DT := 1.0 / 60.0


## A scripted player: deterministic presses and moves from the frame.
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


func test_pack_round_trips() -> void:
	for f in 400:
		var it := _script(f, 7)
		it.pause_pressed = f & 1
		var back := Lockstep.unpack(Lockstep.pack(it))
		eq([back.move_x, back.move_y, back.aim_x, back.aim_y, back.hit_pressed, back.shot,
			back.pause_pressed, back.hit_held], [it.move_x, it.move_y, it.aim_x, it.aim_y,
			it.hit_pressed, it.shot, it.pause_pressed, it.hit_held], "frame %d" % f)
	eq(Lockstep.pack(SimTypes.Intent.new()) != 0, true, "an empty intent isn't 0 (0 is none yet)")


## Two sessions over a loopback line run a 2P singles match: after many
## frames both sims are the same, frame for frame.
func _play(latency: int, jitter: Array, frames: int) -> Array:
	var links := LoopbackLink.pair(latency, jitter)
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1))
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 2))
	for i in 10:
		host.poll()
		guest.poll()
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], guest.peer_hello.get("look", {}))
	# the delay the host would pick for this line's round trip
	var rtt: int = (latency + (jitter.max() if not jitter.is_empty() else 0)) * 2 * 1000 / 60
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": Lockstep.for_rtt(rtt)})
	var sims := [Sim.new(cfg), null]
	var stalls := 0
	var steps := [0, 0]
	var trail := [[], []]                # each side's sim hash, frame by frame
	for f in frames:
		for side in 2:
			var s: OnlineSession = [host, guest][side]
			s.poll()
			if s.state == OnlineSession.PLAYING and sims[side] == null:
				sims[side] = Sim.new(OnlineSession.config_from_dict(s.start["cfg"]))
			if sims[side] == null:
				continue
			var human = s.intents(_script(f, 3 + side))
			if human == null:
				stalls += 1
				continue
			if sims[side].phase == K.PHASE_SERVE_SETUP and (sims[side].frame_count & 31) == 0:
				pass
			sims[side].step(human)
			sims[side].drain_events()
			s.after_step(sims[side])
			steps[side] += 1
			trail[side].append(str(sims[side].snapshot()).hash())
	return [host, guest, sims, stalls, steps, trail]


func fail_at(i: int, latency: int) -> void:
	runner.fail("latency %d: the sims differ from frame %d" % [latency, i])


func test_lockstep_keeps_two_sims_the_same() -> void:
	for net in [[0, []], [3, []], [7, [0, 2, 3, 1]]]:
		var r := _play(net[0], net[1], 3000)
		var host: OnlineSession = r[0]
		var guest: OnlineSession = r[1]
		var sims: Array = r[2]
		var steps: Array = r[4]
		eq([host.state, guest.state], [OnlineSession.PLAYING, OnlineSession.PLAYING],
			"latency %d: both still playing (%s / %s)" % [net[0], host.reason, guest.reason])
		check(steps[0] > 2000 and steps[1] > 2000, "latency %d: the match went on (%s steps, %d waits)" % [
			net[0], str(steps), r[3]])
		# compare at the same frame: step the one behind up to the other
		var a: Sim = sims[0]
		var b: Sim = sims[1]
		var n := mini(steps[0], steps[1])
		check(host.lockstep.desync < 0 and guest.lockstep.desync < 0, "no desync")
		var trail: Array = r[5]
		var same := true
		for i in n:
			if trail[0][i] != trail[1][i]:
				same = false
				fail_at(i, net[0])
				break
		check(same, "latency %d: the same sim on both sides, every one of %d frames" % [net[0], n])
		check(a.team_score[0] + a.team_score[1] > 0, "points were played (%s)" % str(a.team_score))
		check(r[3] <= 60, "latency %d, the delay fitted to it: hardly a wait (%d)" % [net[0], r[3]])
		a.dispose()
		b.dispose()


## A desync (a bug) is caught at the next hash, and both sides stop: in the
## traced state or out of it (the hash is the whole state, port ADR-100).
func test_a_desync_is_caught() -> void:
	_desync("the ball", func(s: Sim): s.ball.x_fp += 1)
	_desync("an untraced field", func(s: Sim): s.hot_streak += 1)
	_desync("the AI's cache", func(s: Sim): s.ai.last_think[3] += 1)


func _desync(what: String, bug: Callable) -> void:
	var links := LoopbackLink.pair(1)
	var ls := [Lockstep.new(0, 2), Lockstep.new(2, 0)]
	var sims := [Sim.new(SimTypes.MatchConfig.singles()), Sim.new(SimTypes.MatchConfig.singles())]
	for s in sims:
		s.config.human[2] = 1
	var f := 0
	while f < Lockstep.HASH_EVERY * 3 and ls[0].desync < 0:
		for side in 2:
			var l: LoopbackLink = links[side]
			l.poll()
			for m in l.receive():
				ls[side].on_message(m)
			if not ls[side].ready():
				continue
			var out: Array = ls[side].advance(_script(f, side))
			l.send(out[0])
			sims[side].step(out[1])
			if ls[side].frame == Lockstep.HASH_EVERY + 1 and side == 1:
				bug.call(sims[1])
			var h: Array = ls[side].hash_after(ls[side].frame - 1, sims[side])
			if not h.is_empty():
				l.send(h)
		f += 1
	check(ls[0].desync > 0, "%s: the host saw the desync at frame %d" % [what, ls[0].desync])
	for s in sims:
		s.dispose()


## A late input makes both wait; nothing is stepped on a guess.
func test_waits_for_a_late_input() -> void:
	var links := LoopbackLink.pair(Lockstep.DELAY + 6)
	var a := Lockstep.new(0, 2)
	var steps := 0
	for f in 40:
		links[0].poll()
		for m in links[0].receive():
			a.on_message(m)
		if a.ready():
			links[0].send(a.advance(SimTypes.Intent.new())[0])
			steps += 1
	eq(steps, Lockstep.DELAY, "with no word from the other side, only the empty start frames")


func test_the_handshake() -> void:
	var links := LoopbackLink.pair(2)
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN")
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(2, 1, 3), "BO")
	for i in 8:
		host.poll()
		guest.poll()
	eq([host.state, guest.state], [OnlineSession.CONNECTED, OnlineSession.CONNECTED], "both said hello")
	eq(host.peer_hello["name"], "BO")
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello["look"])
	cfg.modifiers = K.MOD_BIG_BALL
	cfg.points_to_win = 7
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "space", "time": 2})
	for i in 4:
		guest.poll()
	eq(guest.state, OnlineSession.PLAYING, "START reached the guest")
	var back := OnlineSession.config_from_dict(guest.start["cfg"])
	eq(Sim.new(back).snapshot(), Sim.new(cfg).snapshot(), "the same match on both sides")
	eq([back.modifiers, back.points_to_win, back.human, back.palette[2]], [K.MOD_BIG_BALL, 7, [1, 0, 1, 0], 2])
	eq(guest.start["venue"], "space")
	guest.quit()
	for i in 4:
		host.poll()
	eq([host.state, host.reason], [OnlineSession.CLOSED, "YOUR FRIEND LEFT"], "a QUIT tells the host")


func test_versions_must_match() -> void:
	var links := LoopbackLink.pair(1)
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello({})
	guest.my_hello = OnlineSession.hello({})
	guest.my_hello["version"] = "0.0.1"
	for i in 8:
		host.poll()
		guest.poll()
	check(host.closed() and host.reason.begins_with("VERSIONS DIFFER"), "the host refuses: %s" % host.reason)
	check(guest.closed(), "and the guest hears it")


func test_the_delay_fits_the_line() -> void:
	eq(Lockstep.for_rtt(0), Lockstep.MIN_DELAY, "a LAN: the least")
	eq(Lockstep.for_rtt(60), 4, "60 ms round trip: 2 frames each way, plus 2")
	eq(Lockstep.for_rtt(150), 7)
	eq(Lockstep.for_rtt(2000), Lockstep.MAX_DELAY, "at most")


## The real ENet link on this machine: the host listens, the guest joins
## 127.0.0.1, they say hello, and play 600 frames in lockstep, the same.
func test_enet_on_this_machine() -> void:
	var port := ENetLink.PORT + 7          # out of a real game's way
	var hl := ENetLink.new()
	check(hl.host(port), "the host listens (%s)" % hl.error)
	var gl := ENetLink.new()
	check(gl.join("127.0.0.1", port), "the guest dials")
	var host := OnlineSession.new(hl, true)
	var guest := OnlineSession.new(gl, false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1))
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 1))
	var tries := 0
	while (host.state != OnlineSession.CONNECTED or guest.state != OnlineSession.CONNECTED) and tries < 400:
		host.poll()
		guest.poll()
		OS.delay_msec(2)
		tries += 1
	eq([host.state, guest.state], [OnlineSession.CONNECTED, OnlineSession.CONNECTED],
		"connected over ENet (%d polls; %s %s)" % [tries, host.reason, guest.reason])
	if host.state != OnlineSession.CONNECTED:
		hl.close()
		gl.close()
		return
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello["look"])
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park"})
	check(int(host.start["delay"]) >= Lockstep.MIN_DELAY, "a delay from the measured line (%d)" % host.start["delay"])
	var sims := [Sim.new(cfg), null]
	var steps := [0, 0]
	var trail := [[], []]
	var loops := 0
	while (steps[0] < 600 or steps[1] < 600) and loops < 20000:
		loops += 1
		for side in 2:
			var s: OnlineSession = [host, guest][side]
			s.poll()
			if s.state == OnlineSession.PLAYING and sims[side] == null:
				sims[side] = Sim.new(OnlineSession.config_from_dict(s.start["cfg"]))
			if sims[side] == null or steps[side] >= 600:
				continue
			var human = s.intents(_script(steps[side], 11 + side))
			if human == null:
				continue
			sims[side].step(human)
			s.after_step(sims[side])
			steps[side] += 1
			trail[side].append(str(sims[side].snapshot()).hash())
		OS.delay_msec(1)
	eq(steps, [600, 600], "600 frames each (%d loops)" % loops)
	eq(trail[0], trail[1], "the same sim on both, every frame")
	guest.quit()
	for i in 50:
		host.poll()
		OS.delay_msec(2)
		if host.closed():
			break
	check(host.closed(), "the guest leaving closes the host's side (%s)" % host.reason)
	hl.close()
	for s in sims:
		if s:
			s.dispose()


func _view(session: OnlineSession, f: Array, seed: int) -> MatchView:
	var v := MatchView.new()
	v.net = session
	v.input.script_intent = func() -> SimTypes.Intent:
		var it := _script(f[0], seed)
		if v.sim.phase == K.PHASE_SERVE_SETUP and f[0] % 40 == 0:
			it.hit_pressed = 1           # serve when it's yours
		return it
	runner.root.add_child(v)
	v.setup(OnlineSession.config_from_dict(session.start["cfg"]), "park", false)
	return v


## Two MatchViews, host and guest, over a line with latency: a real match
## through the views stays the same on both; the HUD says YOU and the
## friend's name; the guest leaving ends the host's match with the reason.
func test_two_views_play_online() -> void:
	var links := LoopbackLink.pair(3)
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN")
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 2), "BO")
	for i in 8:
		host.poll()
		guest.poll()
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello["look"])
	cfg.points_to_win = 3
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "delay": 6})
	for i in 4:
		guest.poll()
	var f := [0]
	var hv := _view(host, f, 1)
	var gv := _view(guest, f, 2)
	eq([hv.my_team(), gv.my_team()], [0, 1], "the host plays left, the guest right")
	eq([hv._hud._team_label(0), hv._hud._team_label(1)], ["YOU", "BO"], "the host's HUD")
	eq([gv._hud._team_label(0), gv._hud._team_label(1)], ["ANN", "YOU"], "the guest's HUD")
	var ended := []
	hv.finished.connect(func(t): ended.append(t))
	while f[0] < 4000 and hv.sim.phase != K.PHASE_MATCH_RESULT:
		hv._physics_process(DT)
		gv._physics_process(DT)
		f[0] += 1
	# let the one behind catch up
	for i in 20:
		if hv.net.lockstep.frame == gv.net.lockstep.frame:
			break
		(hv if hv.net.lockstep.frame < gv.net.lockstep.frame else gv)._physics_process(DT)
	eq(hv.sim.phase, K.PHASE_MATCH_RESULT, "a match to 3, played through (%d frames)" % f[0])
	eq(hv.net.lockstep.frame, gv.net.lockstep.frame)
	eq(hv.sim.snapshot(), gv.sim.snapshot(), "the same match on both machines")
	check(hv.net.lockstep.desync < 0)
	gv.net_leave_press()                 # on the result, one press leaves
	for i in 10:
		hv._physics_process(DT)
		if not ended.is_empty():
			break
	eq(ended, [true], "the host's match ends too")
	eq(host.reason, "YOUR FRIEND LEFT")
	hv.free()
	gv.free()


## The ONLINE screen over ENet on this machine: HOST, then the other screen
## types 127.0.0.1 and JOINs; both say hello; START MATCH plays on both.
func test_the_online_screens() -> void:
	var port := ENetLink.PORT + 9
	var a := OnlineScreen.new().setup(null)
	var b := OnlineScreen.new().setup(null)
	for s in [a, b]:
		s.port = port
		runner.root.add_child(s)
		if not s.is_node_ready():
			s._ready()
	var played := [[], []]
	a.play.connect(func(s): played[0].append(s))
	b.play.connect(func(s): played[1].append(s))
	check(a.page.select("host"))
	a.page.press()
	eq(a.session.state, OnlineSession.WAITING, "hosting")
	check(a.info()[0].begins_with("WAITING."), "says it's waiting: " + a.info()[0])
	b.page.select("address")
	b.page.press()
	check(b.editing, "ADDRESS: typing")
	b._type("127.0.0.1!")
	b.page.press()
	eq(b.address, "127.0.0.1", "typed (the ! isn't allowed)")
	b.page.select("join")
	b.page.press()
	var tries := 0
	while (a._state() != OnlineSession.CONNECTED or b._state() != OnlineSession.CONNECTED) and tries < 400:
		a._process(DT)
		b._process(DT)
		OS.delay_msec(2)
		tries += 1
	eq([a._state(), b._state()], [OnlineSession.CONNECTED, OnlineSession.CONNECTED], "connected")
	eq(a.page.rows[0]["label"].call(), "START MATCH", "the host can start")
	check(b.info()[1].begins_with("WAITING FOR THE HOST"), "the guest waits")
	a.page.select("host")
	a.page.press()
	eq(played[0].size(), 1, "the host's match")
	tries = 0
	while played[1].is_empty() and tries < 200:
		b._process(DT)
		a.session.poll()
		OS.delay_msec(2)
		tries += 1
	eq(played[1].size(), 1, "and the guest's")
	var gs: OnlineSession = played[1][0]
	eq(gs.start["cfg"]["human"], [1, 0, 1, 0], "1 vs 1")
	check(gs.start["cfg"]["palette"][0] != gs.start["cfg"]["palette"][2], "in different shirts")
	a.session.quit()
	b.session.quit()
	a.free()
	b.free()


## The real main scene: MULTIPLAYER > ONLINE opens the screen; BACK closes
## any session and goes to the title.
func test_main_opens_online() -> void:
	var dir := "user://test_online_main/"
	var kept := SaveGame.default_dir
	SaveGame.default_dir = dir
	wipe_saves(dir)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	var settle := func():
		for i in main.FADE_OUT + main.FADE_IN + 1:
			main._physics_process(DT)
	var title: TitleScreen = main._screen
	if not title.is_node_ready():
		title._ready()
	title.reveal("multiplayer").press()
	check(title.pages["multi"].select("online"), "ONLINE on MULTIPLAYER")
	title.pages["multi"].press()
	settle.call()
	check(main._screen is OnlineScreen, "the ONLINE screen")
	var o: OnlineScreen = main._screen
	if not o.is_node_ready():
		o._ready()
	o.address = "10.0.0.5"
	o._store_address()
	eq(main.save.data["settings"]["net_address"], "10.0.0.5", "the address is kept")
	o.page.select("back")
	o.page.press()
	settle.call()
	check(main._screen is TitleScreen, "BACK: the title")
	main.free()
	SaveGame.default_dir = kept


## The HOST screen offers only addresses a friend can reach, labelled:
## the home network's and Tailscale's, never a virtual adapter's.
func test_the_addresses_offered() -> void:
	var windows := [
		{"name": "{A1}", "friendly": "vEthernet (WSL)", "addresses": ["172.28.80.1"]},
		{"name": "{B2}", "friendly": "Wi-Fi", "addresses": ["192.168.1.40", "fe80::1"]},
		{"name": "{C3}", "friendly": "VirtualBox Host-Only Network", "addresses": ["192.168.56.1"]},
		{"name": "{D4}", "friendly": "Tailscale", "addresses": ["100.101.12.7"]},
		{"name": "{E5}", "friendly": "Loopback Pseudo-Interface 1", "addresses": ["127.0.0.1"]},
	]
	eq(OnlineScreen.pick_addresses(windows), [["WI-FI", "192.168.1.40"], ["TAILSCALE", "100.101.12.7"]],
		"Windows: Wi-Fi and Tailscale, not WSL or VirtualBox")
	# a second home-network address listed first (a VPN's or a second card's):
	# both shown, 192.168 first (0.9.1 showed only the 10.x, which didn't answer)
	var two := [
		{"name": "{F6}", "friendly": "Ethernet 2", "addresses": ["10.5.0.2"]},
		{"name": "{B2}", "friendly": "Wi-Fi", "addresses": ["192.168.1.40"]},
	]
	eq(OnlineScreen.pick_addresses(two), [["WI-FI", "192.168.1.40"], ["ETHERNET 2", "10.5.0.2"]],
		"both, the home router's first")
	var mac := [
		{"name": "en0", "friendly": "en0", "addresses": ["192.168.1.198"]},
		{"name": "utun4", "friendly": "utun4", "addresses": ["100.70.1.2"]},
		{"name": "bridge100", "friendly": "bridge100", "addresses": ["192.168.64.1"]},
	]
	eq(OnlineScreen.pick_addresses(mac), [["NETWORK", "192.168.1.198"], ["TAILSCALE", "100.70.1.2"]],
		"macOS: en0 and Tailscale's utun, not a VM bridge")
	eq(OnlineScreen.address_kind("172.20.0.5", "ethernet eth0"), "SAME WI-FI", "a real 172.16/12 network")
	eq(OnlineScreen.address_kind("172.17.0.1", "docker0"), "", "Docker's")
	eq(OnlineScreen.address_kind("10.0.0.12", "wlan0"), "SAME WI-FI")
	eq(OnlineScreen.pick_addresses([]), [], "none")
	# Windows' wired adapter is "Ethernet", not NETWORK; on the same range
	# it comes before Wi-Fi (0.12.0: the Wi-Fi address didn't answer)
	var desk := [
		{"name": "{B2}", "friendly": "Wi-Fi", "addresses": ["192.168.1.40"]},
		{"name": "{F6}", "friendly": "Ethernet", "addresses": ["192.168.1.41"]},
	]
	eq(OnlineScreen.pick_addresses(desk), [["ETHERNET", "192.168.1.41"], ["WI-FI", "192.168.1.40"]],
		"wired first, by name")
	eq(OnlineScreen.adapter_label("eth0", "eth0"), "NETWORK", "a Linux id")
	eq(OnlineScreen.adapter_label("Ethernet", "{F6}"), "ETHERNET")
