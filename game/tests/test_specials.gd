## SPECIALS (port ADR-080): a meter for each player that fills with play,
## and SPECIAL, which spends a full one on PICKLE SMASH. Off (the ROM's
## game) nothing fills and SPECIAL is a standard hit.
extends TestSuite


func _sim(modifiers: int, doubles := false) -> Sim:
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.modifiers = modifiers
	var s := Sim.new(cfg)
	s.p1_bot = true
	return s


func _run(s: Sim, frames: int) -> Array:
	var hits := []
	for f in frames:
		s.step()
		for e in s.drain_events():
			if e[0] == K.EVENT_HIT:
				hits.append(e)
	return hits


func test_off_by_default() -> void:
	eq(SimTypes.MatchConfig.singles().modifiers & K.MOD_SPECIALS, 0, "the ROM's game")
	var s := _sim(0)
	var size := s.snapshot().size()
	var hits := _run(s, 3000)
	eq(s.meter, [0, 0, 0, 0], "nothing fills")
	check(hits.all(func(e): return e[3] >> 4 != K.SHOT_SPECIAL), "no PICKLE SMASH")
	eq(s.snapshot().size(), size, "the traced state is the ROM's")
	s.dispose()


func test_the_meter_fills_with_play() -> void:
	var s := _sim(K.MOD_SPECIALS)
	s.set_phase(K.PHASE_LIVE)
	s.contact(0)
	eq(s.meter[0], K.SPECIAL_FILL_HIT, "a shot you hit")
	s.resolve_point(1, K.FAULT_OUT)
	eq(s.meter[0], K.SPECIAL_FILL_HIT + K.SPECIAL_FILL_POINT, "a point your side wins")
	eq(s.meter[2], 0, "the other side's doesn't")
	s.meter[0] = K.SPECIAL_METER_MAX - 1
	s.contact(0)
	eq(s.meter[0], K.SPECIAL_METER_MAX, "full, and no more")
	check(s.special_ready(0))
	s.dispose()
	# time: one every SPECIAL_FILL_PERIOD frames of a live rally
	s = _sim(K.MOD_SPECIALS)
	s.set_phase(K.PHASE_LIVE)
	s.ball.rally_state = K.BALL_RALLY_LIVE
	for f in K.SPECIAL_FILL_PERIOD * 3:
		s.frame_count = f
		s._update_live()
		if s.phase != K.PHASE_LIVE:
			break
	check(s.meter[0] >= 1, "the clock fills it too (%d)" % s.meter[0])
	s.dispose()


## Without a full meter (or the rule), SPECIAL is a standard hit; with
## one, the contact plays PICKLE SMASH and spends it.
func test_special_spends_a_full_meter() -> void:
	var s := _sim(K.MOD_SPECIALS)
	s.p1_bot = false
	s.set_phase(K.PHASE_LIVE)
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	it.shot = K.SHOT_SPECIAL
	s.step([it])
	eq(s.intents[0].shot, K.SHOT_STANDARD, "not full: a standard hit")
	s.dispose()
	s = _sim(K.MOD_SPECIALS)
	s.p1_bot = false
	s.set_phase(K.PHASE_LIVE)
	s.meter[0] = K.SPECIAL_METER_MAX
	s.players[0].frozen = 0
	s.players[0].state = K.STATE_IDLE
	s.step([it])
	eq(s.intents[0].shot, K.SHOT_SPECIAL, "full: SPECIAL")
	eq(s.players[0].shot_type, K.SHOT_SPECIAL, "the swing is PICKLE SMASH")
	s.contact(0)
	eq(s.meter[0], 0, "the contact spends the meter")
	s.dispose()


## PICKLE SMASH: faster than a drive, never stretched off the sweet spot,
## and over the net.
func _launch(s: Sim, shot: int, off_y: int) -> Array:
	var p: SimTypes.Player = s.players[0]
	Sim.place(p, 60, K.COURT_CENTERLINE_Y)
	var b := s.ball
	b.x_fp = p.x_fp + K.to_fp(6)
	b.y_fp = p.y_fp + K.to_fp(off_y)
	b.z_fp = K.to_fp(6)
	b.vx_fp = 0
	b.vy_fp = 0
	b.vz_fp = 0
	p.shot_type = shot
	Sim.apply_targeted_shot(b, p, SimTypes.Intent.new())
	return [b.vx_fp, b.vy_fp, b.vz_fp]


func test_pickle_smash_flies() -> void:
	var s := _sim(K.MOD_SPECIALS)
	var stretch := K.HIT_SWEET_Y + 3                     # off the sweet spot
	var drive := _launch(s, K.SHOT_DRIVE, 0)
	var smash := _launch(s, K.SHOT_SPECIAL, 0)
	check(absi(smash[0]) > absi(drive[0]), "faster than a drive (%d against %d)" % [smash[0], drive[0]])
	check(Sim.net_clearance(s.ball, K.HIT_SPECIAL_MAX_FRAMES) > K.to_fp(K.COURT_NET_HEIGHT),
		"over the net from a low ball")
	check(_launch(s, K.SHOT_DRIVE, stretch) != drive, "a stretched drive goes astray")
	eq(_launch(s, K.SHOT_SPECIAL, stretch)[0], smash[0], "a stretched PICKLE SMASH doesn't")
	s.dispose()


## Returning PICKLE SMASH knocks the paddle back: the return is a soft
## pop-up to the middle, whatever was pressed or held; it aims deep, down
## the lane away from the other side.
func test_the_return_pops_up() -> void:
	var s := _sim(K.MOD_SPECIALS)
	Sim.place(s.players[2], 400, K.COURT_SIDELINE_TOP + 10)     # the other side, up the screen
	var aim := s.special_aim(0)
	eq([aim.aim_x, aim.aim_y], [1, 1], "deep, down the far lane from them")
	s.set_phase(K.PHASE_LIVE)
	s.smash_team = 0
	var r: SimTypes.Player = s.players[2]
	r.state = K.STATE_ACTIVE
	r.contact_consumed = 0
	r.shot_type = K.SHOT_DRIVE
	s.ball.last_hitter = 0
	s.ball.x_fp = r.x_fp
	s.ball.y_fp = r.y_fp
	s.ball.z_fp = K.to_fp(8)
	s.ball.active = 1
	s.ball.rally_state = K.BALL_RALLY_LIVE
	eq(s.resolve_player_hits(), 3, "returned")
	eq(r.shot_type, K.SHOT_SOFT, "a pop-up, not the drive")
	eq(s.smash_team, -1, "the smash is answered")
	s.dispose()


## The CPUs and the bot fire it when their meter is full; it's spent each
## time, and the same inputs play the same match.
func test_the_cpus_use_it() -> void:
	var a := _sim(K.MOD_SPECIALS, true)
	var b := _sim(K.MOD_SPECIALS, true)
	var smashes := _run(a, 6000).filter(func(e): return e[3] >> 4 == K.SHOT_SPECIAL)
	_run(b, 6000)
	check(smashes.size() >= 2, "PICKLE SMASHES in a doubles match (%d)" % smashes.size())
	check(smashes.any(func(e): return (e[3] & 3) >= 2), "the CPUs too")
	eq(a.snapshot(), b.snapshot(), "deterministic")
	a.dispose()
	b.dispose()


## Not in practice or MULTI BALL.
func test_not_everywhere() -> void:
	var s := _sim(K.MOD_SPECIALS | K.MOD_MULTI_BALL)
	check(not s.specials_on(), "MULTI BALL")
	s.dispose()
	var cfg := SimTypes.MatchConfig.practice_session([Practice.SHOT_MIX, Practice.TARGET_RANDOM,
		Practice.RATE_NORMAL, 0], 0)
	cfg.modifiers |= K.MOD_SPECIALS
	s = Sim.new(cfg)
	check(not s.specials_on(), "practice")
	s.dispose()


## Online: the shot's third bit rides in the packed intent.
func test_online_carries_it() -> void:
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	it.shot = K.SHOT_SPECIAL
	eq(Lockstep.unpack(Lockstep.pack(it)).shot, K.SHOT_SPECIAL)
	it.shot = K.SHOT_SLICE
	eq(Lockstep.unpack(Lockstep.pack(it)).shot, K.SHOT_SLICE)


## The HUD's meters only read the sim: a view and a bare sim stay alike.
func test_the_meters_are_display_only() -> void:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_SPECIALS
	var v := match_view(cfg)
	v.highlight = null
	check(v._hud.specials != null, "the meters are up")
	var bare_cfg := SimTypes.MatchConfig.singles()
	bare_cfg.modifiers = K.MOD_SPECIALS
	var bare := Sim.new(bare_cfg)
	bare.p1_bot = true
	for f in 1500:
		v._physics_process(1.0 / 60.0)
		bare.step()
		bare.drain_events()
	eq(v.sim.snapshot(), bare.snapshot(), "1500 frames with the meters on")
	bare.dispose()
	v.queue_free()
	var off := match_view(SimTypes.MatchConfig.singles())
	eq(off._hud.specials, null, "no meters when SPECIALS is off")
	off.queue_free()


## ADR-080 (PORT-68): each player's bar sits under their feet, the same width
## whatever the names, and goes where they go (doubles: all four).
func test_the_meters_follow_the_players() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.modifiers = K.MOD_SPECIALS
	var v := match_view(cfg)
	v.highlight = null
	var m: SpecialMeters = v._hud.specials
	for f in 300:
		v._physics_process(1.0 / 60.0)
	for slot in K.MAX_PLAYERS:
		var feet: Vector2 = v._players[slot]["root"].position + v._actors.position
		var r := m.bar(slot)
		check(m.shown(slot), "slot %d's bar is up" % slot)
		eq(r.size.x, float(SpecialMeters.BAR_W), "a fixed width")
		eq(r.get_center().x, feet.x, "centred on slot %d's feet" % slot)
		check(r.position.y > feet.y, "under slot %d's feet" % slot)
	v.queue_free()
