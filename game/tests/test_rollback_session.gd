## Rollback in the online session (port ADR-103, PORT-108): START names the
## netcode and both sides build it; two sessions over a jittery line (and
## over ENet on this machine) play the same confirmed match; a desync
## closes them; lockstep stays the fallback, and the host starts it until
## the view plays rollback (VIEW_PLAYS_ROLLBACK).
extends TestSuite


const CORE := preload("res://tests/test_rollback.gd")


static func _script(f: int, side: int) -> SimTypes.Intent:
	return CORE._script(f, side)            # the core's scripted players


## Host and guest over `links`, said hello, the host's START sent with `info`.
func _connect(links: Array, info: Dictionary) -> Array:
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN")
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 2), "BO")
	for i in 400:
		host.poll()
		guest.poll()
		if host.state == OnlineSession.CONNECTED and guest.state == OnlineSession.CONNECTED:
			break
		if links[0] is ENetLink:
			OS.delay_msec(2)
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello.get("look", {}))
	cfg.points_to_win = 21
	var start := info.duplicate()
	start["cfg"] = OnlineSession.config_to_dict(cfg)
	start["venue"] = "park"
	host.begin(start)
	for i in 400:
		guest.poll()
		if guest.state == OnlineSession.PLAYING:
			break
		if links[0] is ENetLink:
			OS.delay_msec(2)
	return [host, guest]


## Ticks both sessions `frames` frames each, then lets what's in flight
## arrive and be confirmed. Returns each side's counted events by step.
func _play(s: Array, frames: int, enet := false) -> Array:
	var trail := [{}, {}]
	var steps := [0, 0]
	var loops := 0
	while (steps[0] < frames or steps[1] < frames) and loops < frames * 40:
		loops += 1
		for side in 2:
			var ses: OnlineSession = s[side]
			ses.poll()
			if steps[side] >= frames or ses.closed():
				continue
			var out := ses.tick(_script(steps[side], side))
			if out["stepped"]:
				steps[side] += 1
			for c: Array in out["counted"]:
				trail[side][c[0]] = c[1]
		if enet:
			OS.delay_msec(1)
	for i in 200:
		for side in 2:
			var ses: OnlineSession = s[side]
			ses.poll()
			if ses.rollback:
				var out := ses.rollback.catch_up()
				for m in out["send"]:
					ses.link.send(m)
				for c: Array in out["counted"]:
					trail[side][c[0]] = c[1]
		if s[0].rollback.confirmed == frames and s[1].rollback.confirmed == frames:
			break
		if enet:
			OS.delay_msec(2)
	return trail


func test_start_names_the_netcode() -> void:
	var s := _connect(LoopbackLink.pair(2), {"netcode": OnlineSession.ROLLBACK, "delay": 2})
	for side in 2:
		var ses: OnlineSession = s[side]
		eq(ses.netcode(), OnlineSession.ROLLBACK, "rollback on both")
		check(ses.rollback != null and ses.lockstep == null, "built: rollback, not lockstep")
		eq(ses.rollback.delay, 2, "the host's delay")
	eq([s[0].rollback.local_slot, s[1].rollback.local_slot], [0, 2], "the host left, the guest right")
	s[0].quit()
	for i in 4:
		s[1].poll()
	check(s[1].closed(), "a quit closes the other side")


## Without a netcode in START: the host's choice, or lockstep while the
## view can't play rollback; a START that names none (PROTOCOL 2) is lockstep.
func test_the_hosts_choice_and_the_fallback() -> void:
	var keep := Settings.netcode_i
	Settings.netcode_i = 0
	eq(Settings.netcode_name(), OnlineSession.ROLLBACK)
	var s := _connect(LoopbackLink.pair(1), {})
	var want := OnlineSession.ROLLBACK if OnlineSession.VIEW_PLAYS_ROLLBACK else OnlineSession.LOCKSTEP
	eq([s[0].netcode(), s[1].netcode()], [want, want], "what the host starts")
	var d: int = s[0].start["delay"]
	eq(d, Rollback.for_rtt(0) if want == OnlineSession.ROLLBACK else Lockstep.for_rtt(0), "its delay, from the line")
	Settings.netcode_i = 1
	eq(Settings.netcode_name(), OnlineSession.LOCKSTEP)
	var old := OnlineSession.new(null, false)
	old.start = {"cfg": {}}
	eq(old.netcode(), OnlineSession.LOCKSTEP, "a START without one: lockstep")
	Settings.netcode_i = keep
	for ses: OnlineSession in s:
		ses.quit()


func test_the_netcode_is_saved() -> void:
	var save := fresh_save("user://test_rollback_session/")
	var keep := Settings.netcode_i
	Settings.netcode_i = 1
	Settings.store_to(save)
	Settings.netcode_i = 0
	Settings.load_from(save)
	eq(Settings.netcode_i, 1, "LOCKSTEP kept")
	Settings.netcode_i = keep


## Two sessions over a jittery line: the same confirmed match on both.
func test_two_sessions_play_the_same_match() -> void:
	var s := _connect(LoopbackLink.pair(5, [0, 2, 1]), {"netcode": OnlineSession.ROLLBACK, "delay": 2})
	var counted := _play(s, 1800)
	eq(counted[0].size(), 1800, "every step counted")
	check(counted[0] == counted[1], "the same events counted on both, step for step")
	for side in 2:
		var rb: Rollback = s[side].rollback
		eq(rb.confirmed, 1800, "%s: everything confirmed" % ["host", "guest"][side])
		check(rb.corrections > 0, "guesses corrected (%d)" % rb.corrections)
		check(rb.desync < 0 and not s[side].closed(), "no desync")
	eq(s[0].rollback.truth.state_hash(), s[1].rollback.truth.state_hash(), "the whole state, the same")
	for ses: OnlineSession in s:
		ses.quit()


func test_a_desync_closes_both() -> void:
	var s := _connect(LoopbackLink.pair(1), {"netcode": OnlineSession.ROLLBACK, "delay": 1})
	var bugged := false
	for f in Rollback.HASH_EVERY * 3:
		for side in 2:
			var ses: OnlineSession = s[side]
			ses.poll()
			if not ses.closed():
				ses.tick(_script(f, side))
		if not bugged and s[1].rollback.confirmed > 5:
			s[1].rollback.truth.hot_streak += 7          # the bug: a field the trace doesn't keep
			bugged = true
		if s[0].closed() and s[1].closed():
			break
	check(s[0].closed() or s[1].closed(), "caught")
	var reasons := [s[0].reason, s[1].reason]
	check(reasons.any(func(r): return String(r).begins_with("OUT OF SYNC")), "out of sync (%s)" % str(reasons))


func test_enet_on_this_machine_under_rollback() -> void:
	var port := ENetLink.PORT + 11
	var hl := ENetLink.new()
	check(hl.host(port), "the host listens (%s)" % hl.error)
	var gl := ENetLink.new()
	check(gl.join("127.0.0.1", port), "the guest dials")
	var s := _connect([hl, gl], {"netcode": OnlineSession.ROLLBACK})
	if not check(s[0].state == OnlineSession.PLAYING and s[1].state == OnlineSession.PLAYING,
			"playing (%s %s)" % [s[0].reason, s[1].reason]):
		hl.close()
		gl.close()
		return
	eq(s[0].start["delay"], Rollback.DELAY_LAN, "this machine is a LAN: delay 1")
	_play(s, 600, true)
	eq([s[0].rollback.confirmed, s[1].rollback.confirmed], [600, 600], "600 frames confirmed on both")
	eq(s[0].rollback.truth.state_hash(), s[1].rollback.truth.state_hash(), "the same match")
	for ses: OnlineSession in s:
		ses.quit()
