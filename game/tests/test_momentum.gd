## The momentum rule (port ADR-064, the Pickleball '95 promise): after a
## volley, a step into your kitchen before the ball next bounces or is hit
## loses the point (MOMENTUM!), forgiving MOMENTUM_GRACE px past the line.
## Off, the kitchen is called at contact only, as in the ROM.
extends TestSuite


func _volley(modifiers: int) -> Sim:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = modifiers
	var s := Sim.new(cfg)
	s.set_phase(K.PHASE_LIVE)
	s.ball.rally_state = K.BALL_RALLY_LIVE
	s.contact_volley = 1
	s.contact(0)                          # slot 0 volleys
	return s


func _step_into(s: Sim, past_line: int) -> void:
	var p: SimTypes.Player = s.players[0]
	p.x_fp = K.to_fp(K.COURT_KITCHEN_LEFT_X + past_line)
	p.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	s._update_live()


func test_carried_into_the_kitchen() -> void:
	var s := _volley(K.MOD_MOMENTUM)
	eq(s.momentum_slot, 0, "the volley carries")
	_step_into(s, K.MOMENTUM_GRACE + 1)
	eq(s.phase, K.PHASE_POINT_RESULT)
	eq(s.last_fault, K.FAULT_MOMENTUM)
	eq(s.point_winner, 1, "the volleyer's side loses it")
	eq(K.fault_word(K.FAULT_MOMENTUM), "MOMENTUM!")
	eq(s.momentum_slot, -1)
	s.dispose()


func test_the_grace() -> void:
	var s := _volley(K.MOD_MOMENTUM)
	_step_into(s, K.MOMENTUM_GRACE)
	eq(s.phase, K.PHASE_LIVE, "a toe over the line is forgiven")
	s.dispose()


func test_balance_back() -> void:
	var s := _volley(K.MOD_MOMENTUM)
	s.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	eq(s.momentum_slot, -1, "the ball bounced")
	s.set_phase(K.PHASE_LIVE)            # (that test bounce also scored the stray ball)
	_step_into(s, 10)
	eq(s.phase, K.PHASE_LIVE, "then the kitchen is yours to walk into")
	s.dispose()
	s = _volley(K.MOD_MOMENTUM)
	s.contact_volley = 0
	s.contact(2)                          # the other side hits (off the bounce)
	eq(s.momentum_slot, -1, "the next hit ends it")
	s.dispose()


func test_off() -> void:
	var s := _volley(0)
	eq(s.momentum_slot, -1)
	_step_into(s, 10)
	eq(s.phase, K.PHASE_LIVE, "the ROM's rule: contact only")
	s.dispose()


## The CPUs keep out of their kitchen after volleying: in bot play none
## faults, so the rule catches only a human who charges in.
func test_cpus_never_fault() -> void:
	var cfg := Settings.config_for(true, 7, K.DIFFICULTY_MEDIUM, 11)
	cfg.modifiers = K.MOD_MOMENTUM
	var s := Sim.new(cfg)
	s.p1_bot = true
	s.set_bot_skill(4, 0)
	var faults := 0
	var volleys := 0
	for f in 60 * 60 * 10:
		var it := SimTypes.Intent.new()
		it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
		if s.phase == K.PHASE_MATCH_RESULT:
			s.new_match()
		s.step([it, null, null, null])
		for e in s.drain_events():
			if e[0] == K.EVENT_HIT and s.contact_volley:
				volleys += 1
			if e[0] == K.EVENT_POINT and s.last_fault == K.FAULT_MOMENTUM:
				faults += 1
	print("    momentum: %d volleys, %d faults" % [volleys, faults])
	check(volleys > 50)
	eq(faults, 0)
	s.dispose()
