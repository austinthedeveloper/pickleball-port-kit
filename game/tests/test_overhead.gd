## The overhead (PORT-24, ADR-053): a standard or drive swing at a falling
## ball HIT_OVERHEAD_Z or higher becomes a smash, fast and steep, that
## still clears the net; a soft swing stays soft, and a rising or lower
## ball is an ordinary shot. In real play (Sim.step) the smash shows up,
## and the view shows it (the overhead frames, SMASH!, the card's row).
extends TestSuite

var sim: Sim


func _reset(x: int = 100, z: int = 22, vz: int = -40, shot := K.SHOT_STANDARD) -> SimTypes.Player:
	sim = Sim.new()
	for i in K.MAX_PLAYERS:
		sim.players[i] = SimTypes.Player.new()
		sim.players[i].contact_consumed = 0
		sim.intents[i].clear()
	var p: SimTypes.Player = sim.players[0]
	p.paddle = Paddles.STANDARD
	p.active = 1
	p.state = K.STATE_ACTIVE
	p.shot_type = shot
	p.x_fp = K.to_fp(x)
	p.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	sim.ball = SimTypes.Ball.new()
	sim.ball.active = 1
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.ball.last_hitter = 2
	sim.ball.x_fp = p.x_fp
	sim.ball.y_fp = p.y_fp
	sim.ball.z_fp = K.to_fp(z)
	sim.ball.vz_fp = vz
	return p


## Frames to the first bounce, and the events on the way.
func _fly() -> Array:
	var ev := 0
	for f in 120:
		var e := Sim.simulate_step(sim.ball)
		ev |= e
		if e & K.BALL_EVENT_BOUNCE:
			return [f + 1, ev]
	return [-1, ev]


func test_a_high_falling_ball_is_smashed() -> void:
	for shot in [K.SHOT_STANDARD, K.SHOT_DRIVE]:
		var p := _reset(100, K.HIT_OVERHEAD_Z, -40, shot)
		eq(sim.resolve_player_hits(), 1, "contact")
		eq(p.shot_type, K.SHOT_OVERHEAD, "shot %d at a falling ball overhead: a smash" % shot)
		sim.contact(0)
		var e: Array = sim.drain_events()[0]
		eq([e[0], e[3] >> 4], [K.EVENT_HIT, K.SHOT_OVERHEAD], "the hit event says so")


func test_not_a_smash() -> void:
	var p := _reset(100, K.HIT_OVERHEAD_Z, -40, K.SHOT_SOFT)
	sim.resolve_player_hits()
	eq(p.shot_type, K.SHOT_SOFT, "a soft swing stays soft (the block, the reset)")
	p = _reset(100, K.HIT_OVERHEAD_Z, 24)
	sim.resolve_player_hits()
	eq(p.shot_type, K.SHOT_STANDARD, "a rising ball: an ordinary shot")
	p = _reset(100, K.HIT_OVERHEAD_Z - 1, -40)
	sim.resolve_player_hits()
	eq(p.shot_type, K.SHOT_STANDARD, "just under the line: an ordinary shot")


func test_a_smash_is_fast_steep_and_in() -> void:
	_reset(100, 22, -40, K.SHOT_DRIVE)
	sim.players[0].shot_type = K.SHOT_DRIVE
	sim.ball.vz_fp = 24            # rising: a drive from the same spot
	sim.resolve_player_hits()
	var drive_vz := sim.ball.vz_fp
	var drive := _fly()
	_reset(100, 22, -40)
	sim.resolve_player_hits()
	var vz := sim.ball.vz_fp
	var smash := _fly()
	check(smash[0] > 0 and smash[0] < drive[0], "a smash lands sooner than a drive (%d < %d frames)" % [smash[0], drive[0]])
	check(vz < drive_vz and vz <= 0, "it's hit flat or down, not up like the drive (vz %d, %d)" % [vz, drive_vz])
	eq(smash[1] & (K.BALL_EVENT_NET_FAULT | K.BALL_EVENT_OUT), 0, "over the net and in")
	check(sim.ball.x_fp > K.to_fp(K.COURT_NET_X), "on the far side")


## From anywhere on the near side, aimed anywhere, a smash at the height
## of the reach clears the tape (the flight lengthens if it must).
func test_a_smash_clears_the_net() -> void:
	for x in [K.COURT_BASELINE_LEFT, 48, 80, K.COURT_KITCHEN_LEFT_X, 112]:
		for aim in [-1, 0, 1]:
			_reset(x, K.HIT_OVERHEAD_Z, -40)
			sim.intents[0].aim_x = aim
			sim.resolve_player_hits()
			var r := _fly()
			eq(r[1] & K.BALL_EVENT_NET_FAULT, 0, "from x %d, aim %d: over the net" % [x, aim])
			check(r[0] <= K.HIT_OVERHEAD_MAX_FRAMES + 1, "and quick (%d frames)" % r[0])


## Real play, the shipped schedule: doubles CPUs lob and smash.
func test_smashes_happen_in_play() -> void:
	var smashes := 0
	var won := 0
	for i in 3:
		var cfg := SimTypes.MatchConfig.doubles()
		cfg.opponent = i
		var s := Sim.new(cfg)
		s.p1_bot = true
		var last := -1
		for f in 60 * 60 * 3:
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
			s.step([it, null, null, null])
			for e in s.drain_events():
				if e[0] == K.EVENT_HIT:
					last = e[3] >> 4
					if last == K.SHOT_OVERHEAD:
						smashes += 1
				elif e[0] == K.EVENT_POINT:
					if last == K.SHOT_OVERHEAD:
						won += 1
					last = -1
			if s.phase == K.PHASE_MATCH_RESULT:
				break
		s.dispose()
	print("    smashes in three doubles matches: %d, %d ended the point" % [smashes, won])
	check(smashes >= 5, "the CPUs smash in doubles (%d)" % smashes)
	check(won >= 1, "and some end the point")


## The view: the overhead frames at contact, SMASH! over it, and the view
## never writes to the sim.
func test_the_view_shows_a_smash() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.singles(), "park", false)
	var p: SimTypes.Player = v.sim.players[0]
	var kept := p.state
	var before := v.sim.snapshot()
	p.state = K.STATE_ACTIVE
	v._on_event([K.EVENT_HIT, 100, 130, 0 | (K.SHOT_OVERHEAD << 4)])
	eq(v._players[0]["choice"], "overhead", "the overhead swing")
	eq(v._frame_for(0), "overhead_contact", "on the contact frame")
	var pops := v._fx.get_children().filter(func(n): return n is BitmapText and n.text == "SMASH!")
	eq(pops.size(), 1, "SMASH! over it")
	check(v.feel.shake_amp >= Feel.SHAKE_SMASH[0] or not Settings.shake, "the biggest shake")
	p.state = kept
	eq(v.sim.snapshot(), before, "the view wrote nothing to the sim")
	v.free()
