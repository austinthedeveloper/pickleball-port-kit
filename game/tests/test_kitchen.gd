## The kitchen rule (ADR-055, port-only): a volley (a contact before the
## ball bounces) made from inside your own kitchen loses the point with
## KITCHEN!. Standing in it is fine, and so is hitting a ball that has
## bounced there; a volley from behind the line is fine. The CPUs obey it:
## from the kitchen they let the ball bounce.
extends TestSuite

var sim: Sim


## A rally past both required bounces, a ball coming at `slot` at `x`,
## in the air (or bounced once), the player swinging.
func _rally(slot: int, x: int, bounced: bool, required := K.REQUIRED_BOUNCE_NONE) -> SimTypes.Player:
	sim = Sim.new(SimTypes.MatchConfig.doubles())
	sim._players_initialize()
	sim._activate_players()
	sim.ball_initialize()
	sim._game_initialize()
	sim.serve_initialize()
	sim.phase = K.PHASE_LIVE
	sim.required_bounce = required
	var p: SimTypes.Player = sim.players[slot]
	for q in sim.players:
		q.contact_consumed = 1
	p.x_fp = K.to_fp(x)
	p.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	p.state = K.STATE_ACTIVE
	p.contact_consumed = 0
	var b := sim.ball
	b.rally_state = K.BALL_RALLY_LIVE
	b.last_hitter = 2 if p.team == 0 else 0
	b.x_fp = p.x_fp
	b.y_fp = p.y_fp
	b.z_fp = K.to_fp(12)
	b.vx_fp = -20 if p.team == 0 else 20
	b.vz_fp = -8
	b.bounce_count = 1 if bounced else 0
	return p


func _hit() -> void:
	var slot := sim.resolve_player_hits()
	check(slot > 0, "contact")
	sim.contact(slot - 1)
	sim.rules_process_player_hit(slot - 1)


func test_a_volley_from_the_kitchen_faults() -> void:
	var inside := K.COURT_KITCHEN_LEFT_X + 10
	_rally(0, inside, false)
	_hit()
	eq([sim.phase, sim.last_fault, sim.point_winner], [K.PHASE_POINT_RESULT, K.FAULT_KITCHEN, 1],
		"KITCHEN!, the point to the other side")
	eq(K.fault_word(sim.last_fault), "KITCHEN!")
	# the far side, mirrored
	_rally(2, K.COURT_KITCHEN_RIGHT_X - 10, false)
	_hit()
	eq([sim.last_fault, sim.point_winner], [K.FAULT_KITCHEN, 0], "the right side's kitchen too")


func test_what_stays_legal() -> void:
	_rally(0, K.COURT_KITCHEN_LEFT_X + 10, true)
	_hit()
	eq(sim.phase, K.PHASE_LIVE, "in the kitchen, a ball that bounced: fine")
	_rally(0, K.COURT_KITCHEN_LEFT_X - 2, false)
	_hit()
	eq(sim.phase, K.PHASE_LIVE, "a volley from behind the line: fine")
	_rally(2, K.COURT_KITCHEN_LEFT_X + 10, false)
	sim.players[2].x_fp = K.to_fp(K.COURT_KITCHEN_RIGHT_X + 4)
	sim.ball.x_fp = sim.players[2].x_fp
	_hit()
	eq(sim.phase, K.PHASE_LIVE, "the other side's player, behind their own line: fine")


## While the return must bounce, the receivers may volley the third shot,
## but not from the kitchen; the servers' early volley stays VOLLEY!.
func test_during_the_two_bounce_rule() -> void:
	_rally(2, K.COURT_KITCHEN_RIGHT_X - 8, false, K.REQUIRED_BOUNCE_RETURN)
	sim.serving_team = 0
	_hit()
	eq(sim.last_fault, K.FAULT_KITCHEN, "a receiver's kitchen volley")
	_rally(0, K.COURT_KITCHEN_LEFT_X + 8, false, K.REQUIRED_BOUNCE_RETURN)
	sim.serving_team = 0
	_hit()
	eq(sim.last_fault, K.FAULT_EARLY_VOLLEY, "the servers before the return bounced: VOLLEY!")


## The CPUs, through the shipped schedule: doubles teams that come to the
## net (and the bot on P1's side) never volley from their kitchen.
func test_cpus_let_it_bounce() -> void:
	var faults := {}
	var volleys := 0
	for i in [3, 4, 6, 7]:
		var cfg := SimTypes.MatchConfig.doubles()
		cfg.opponent = i
		var s := Sim.new(cfg)
		s.p1_bot = true
		for f in 60 * 60 * 3:
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
			s.step([it, null, null, null])
			for e in s.drain_events():
				if e[0] == K.EVENT_FAULT:
					faults[e[3]] = faults.get(e[3], 0) + 1
				elif e[0] == K.EVENT_HIT and s.contact_volley:
					volleys += 1
			if s.phase == K.PHASE_MATCH_RESULT:
				break
		s.dispose()
	print("    four net-rushing doubles matches: %d volleys, faults %s" % [volleys, str(faults)])
	check(volleys > 0, "they still volley")
	eq(faults.get(K.FAULT_KITCHEN, 0), 0, "never from the kitchen")


## A volleying CPU (TWINS) with a ball coming at it in the air, standing in
## its kitchen: it never volleys from there (it steps back behind the line
## to volley, or lets the ball bounce). Without ADR-055's AI check it
## volleys where it stands and loses the point.
func _cpu_meets(x: int) -> Array:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.opponent = 6
	var s := Sim.new(cfg)
	s.new_match()
	s.phase = K.PHASE_LIVE
	s.required_bounce = K.REQUIRED_BOUNCE_NONE
	s.rally_start = s.shot_serial
	for i in K.MAX_PLAYERS:
		var q: SimTypes.Player = s.players[i]
		q.vx_fp = 0
		q.vy_fp = 0
		q.state = K.STATE_IDLE
	var cpu: SimTypes.Player = s.players[2]
	cpu.x_fp = K.to_fp(x)
	cpu.y_fp = K.to_fp(K.COURT_CENTERLINE_Y - 20)
	s.players[3].y_fp = K.to_fp(K.COURT_SIDELINE_BOTTOM - 4)
	var b := s.ball
	b.active = 1
	b.rally_state = K.BALL_RALLY_LIVE
	b.last_hitter = 0
	b.bounce_count = 0
	b.x_fp = K.to_fp(70)
	b.y_fp = cpu.y_fp
	b.z_fp = K.to_fp(14)
	Sim.launch(b, x + 40, K.from_fp(cpu.y_fp), 26)
	s.shot_serial = (s.shot_serial + 1) & 0xff
	var hit_in_air := false
	var hit_after := false
	var from_kitchen := false
	for f in 90:
		s.step([SimTypes.Intent.new(), null, null, null])
		for e in s.drain_events():
			if e[0] == K.EVENT_HIT and (e[3] & 15) == 2:
				if s.contact_volley:
					hit_in_air = true
					from_kitchen = Sim.in_kitchen(cpu.x_fp, cpu.y_fp, cpu.team)
				else:
					hit_after = true
		if s.phase != K.PHASE_LIVE:
			break
	var out := [hit_in_air, hit_after, s.last_fault, from_kitchen]
	s.dispose()
	return out


func test_a_cpu_in_the_kitchen_waits() -> void:
	var behind := _cpu_meets(K.COURT_KITCHEN_RIGHT_X + 6)
	var inside := _cpu_meets(K.COURT_KITCHEN_RIGHT_X - 10)
	print("    TWINS behind the line %s, in the kitchen %s ([volleyed, after the bounce, fault, from the kitchen])" % [
		str(behind), str(inside)])
	check(behind[0] and not behind[3], "behind the line it volleys")
	check(not inside[3], "from the kitchen it doesn't volley")
	check(inside[2] != K.FAULT_KITCHEN, "so no KITCHEN! fault")
