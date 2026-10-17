## Port of reference/snes-src/test/test_serve.c (serve setup, boxes, the
## charged serve of ADR-044).
extends TestSuite

var sim: Sim


func _reset(team: int) -> void:
	sim = Sim.new()
	sim.owners = [K.OWNER_NONE, K.OWNER_NONE, K.OWNER_NONE, K.OWNER_NONE]
	sim.config.difficulty = K.DIFFICULTY_MEDIUM
	sim._players_initialize()
	sim.players[2].active = 1
	sim.ball_initialize()
	sim._game_initialize()
	sim.serve_initialize()
	for it in sim.intents:
		it.clear()
	sim.serve_setup(team)


## As game_update: the phase timer advances before serve_update.
func _step() -> void:
	sim.phase_timer += 1
	sim.serve_update()


func _serve_now(slot: int) -> void:
	while sim.phase_timer < K.SERVE_READY_FRAMES:
		_step()
	sim.intents[slot].hit_pressed = 1
	_step()
	sim.intents[slot].hit_pressed = 0
	while sim.phase == K.PHASE_SERVE_TOSS:
		_step()


func _fly_to_first_bounce() -> int:
	var ev := 0
	var f := 0
	while f < 80:
		ev = Sim.simulate_step(sim.ball)
		sim.serve_process_ball_events(ev)
		if ev & (K.BALL_EVENT_BOUNCE | K.BALL_EVENT_NET_FAULT):
			break
		f += 1
	check(ev & K.BALL_EVENT_BOUNCE, "serve bounced")
	return f


func test_setup_positions() -> void:
	_reset(0)
	eq(sim.phase, K.PHASE_SERVE_SETUP)
	eq(sim.server_index, 0)
	eq(sim.receiver_index, 2)
	var p0: SimTypes.Player = sim.players[0]
	var p2: SimTypes.Player = sim.players[2]
	eq(p0.x_fp, K.to_fp(K.COURT_BASELINE_LEFT - K.SERVE_BASELINE_GAP))
	check(p0.y_fp > K.to_fp(K.COURT_CENTERLINE_Y), "even: left server on the bottom half")
	check(p2.y_fp < K.to_fp(K.COURT_CENTERLINE_Y), "receiver diagonal")
	eq(p2.x_fp, K.to_fp(K.COURT_BASELINE_RIGHT + K.SERVE_RECEIVER_GAP))
	eq(p0.frozen, 1)
	eq(p2.frozen, 0)
	eq(sim.ball.rally_state, K.BALL_RALLY_INACTIVE)
	eq(sim.ball.x_fp, p0.x_fp + K.to_fp(K.SERVE_HAND_OFFSET_X))
	eq(sim.ball.z_fp, K.to_fp(K.SERVE_HAND_Z))
	sim.team_score[0] = 1
	sim.serve_setup(0)
	check(p0.y_fp < K.to_fp(K.COURT_CENTERLINE_Y), "odd: top half")
	check(p2.y_fp > K.to_fp(K.COURT_CENTERLINE_Y), "receiver bottom")
	_reset(1)
	p0 = sim.players[0]
	p2 = sim.players[2]
	eq(sim.server_index, 2)
	check(p2.y_fp < K.to_fp(K.COURT_CENTERLINE_Y), "right team's right hand is the top")
	eq(p2.x_fp, K.to_fp(K.COURT_BASELINE_RIGHT + K.SERVE_BASELINE_GAP))
	eq(p0.x_fp, K.to_fp(K.COURT_BASELINE_LEFT - K.SERVE_RECEIVER_GAP))
	eq(sim.ball.x_fp, p2.x_fp - K.to_fp(K.SERVE_HAND_OFFSET_X))
	check(sim.ball.x_fp > K.to_fp(K.COURT_BASELINE_RIGHT), "struck behind the baseline")


func test_early_press_is_buffered_and_toss_runs() -> void:
	_reset(0)
	sim.intents[0].hit_pressed = 1
	_step()
	sim.intents[0].hit_pressed = 0
	eq(sim.phase, K.PHASE_SERVE_SETUP)
	while sim.phase == K.PHASE_SERVE_SETUP:
		_step()
	eq(sim.phase, K.PHASE_SERVE_TOSS)
	eq(sim.players[0].pose, K.POSE_TOSS)
	while sim.phase == K.PHASE_SERVE_TOSS:
		if not check(sim.ball.z_fp > 0, "ball up during the toss"):
			return
		_step()
	eq(sim.phase, K.PHASE_LIVE)
	eq(sim.ball.rally_state, K.BALL_RALLY_LIVE)
	eq(sim.ball.last_hitter, 0)
	eq(sim.landing_pending, 1)
	eq(sim.required_bounce, K.REQUIRED_BOUNCE_SERVE)
	eq(sim.players[0].frozen, 0)


func test_neutral_serves_land_diagonal() -> void:
	_reset(0)
	_serve_now(0)
	var frames := _fly_to_first_bounce()
	check(frames + 2 >= K.SERVE_FLIGHT_FRAMES and frames <= K.SERVE_FLIGHT_FRAMES, "flight %d" % frames)
	check(absi(sim.ball.x_fp - K.to_fp(K.SERVE_TARGET_NEUTRAL_RIGHT)) < K.to_fp(3), "neutral target")
	check(sim.ball.y_fp < K.to_fp(K.COURT_CENTERLINE_Y), "diagonal box")
	eq(sim.last_fault, K.FAULT_NONE)
	eq(sim.phase, K.PHASE_LIVE)
	_reset(1)
	_serve_now(2)
	_fly_to_first_bounce()
	check(sim.ball.x_fp < K.to_fp(K.COURT_KITCHEN_LEFT_X), "right team serves left")
	check(sim.ball.y_fp > K.to_fp(K.COURT_CENTERLINE_Y), "into the bottom box")
	eq(sim.last_fault, K.FAULT_NONE)
	_reset(0)
	sim.intents[0].aim_x = 1
	sim.intents[0].aim_y = -1
	_serve_now(0)
	_fly_to_first_bounce()
	check(sim.ball.x_fp > K.to_fp(K.SERVE_TARGET_DEEP_RIGHT - 3), "deep serve")
	eq(sim.last_fault, K.FAULT_NONE)


func test_service_box_faults() -> void:
	var bottom := K.to_fp(K.COURT_CENTERLINE_Y + K.SERVE_STANCE_OFFSET_Y)
	var top := K.to_fp(K.COURT_CENTERLINE_Y - K.SERVE_STANCE_OFFSET_Y)
	eq(Sim.serve_validate_landing(K.to_fp(200), K.to_fp(110), 0, bottom), K.FAULT_NONE)
	eq(Sim.serve_validate_landing(K.to_fp(200), K.to_fp(150), 0, bottom), K.FAULT_WRONG_BOX)
	eq(Sim.serve_validate_landing(K.to_fp(K.COURT_KITCHEN_RIGHT_X), K.to_fp(110), 0, bottom), K.FAULT_KITCHEN)
	eq(Sim.serve_validate_landing(K.to_fp(K.COURT_BASELINE_RIGHT) + 1, K.to_fp(110), 0, bottom), K.FAULT_OUT)
	eq(Sim.serve_validate_landing(K.to_fp(56), K.to_fp(150), 1, top), K.FAULT_NONE)
	eq(Sim.serve_validate_landing(K.to_fp(56), K.to_fp(110), 1, top), K.FAULT_WRONG_BOX)
	eq(Sim.serve_validate_landing(K.to_fp(K.COURT_KITCHEN_LEFT_X), K.to_fp(150), 1, top), K.FAULT_KITCHEN)


func test_net_fault_stops_serve() -> void:
	_reset(0)
	sim.phase = K.PHASE_LIVE
	sim.landing_pending = 1
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.serve_process_ball_events(K.BALL_EVENT_NET_FAULT)
	eq(sim.phase, K.PHASE_SERVE_FAULT)
	eq(sim.last_fault, K.FAULT_NET)
	eq(sim.landing_pending, 0)
	eq(sim.ball.rally_state, K.BALL_RALLY_INACTIVE)


func _charge_and_serve(slot: int, level: int, falling: bool) -> bool:
	sim.owners[slot] = K.OWNER_HUMAN
	while sim.phase_timer < K.SERVE_READY_FRAMES:
		_step()
	sim.intents[slot].hit_held = 1
	_step()
	if not check(sim.charge_charging and sim.charge_level == 0, "meter starts at 0"):
		return false
	if falling:
		while sim.charge_rising:
			_step()
	while sim.charge_level != level:
		_step()
	sim.intents[slot].hit_held = 0
	_step()
	var want := K.SERVE_CHARGE_CLASSIC if (level < K.SERVE_CHARGE_DUD and not falling) else level
	if not eq(sim.charge_power, want, "power at release"):
		return false
	while sim.phase == K.PHASE_SERVE_TOSS:
		_step()
	return true


func _serve_flight_event() -> int:
	var ev := 0
	var f := 0
	while f < 80 and not ev:
		ev = Sim.simulate_step(sim.ball)
		sim.serve_process_ball_events(ev)
		f += 1
	return ev


func test_charged_meter() -> void:
	_reset(0)
	sim.owners[0] = K.OWNER_HUMAN
	check(sim.serve_charged(), "a human server charges")
	sim.intents[0].hit_held = 1
	while sim.phase_timer < K.SERVE_READY_FRAMES - 1:
		_step()
	check(not sim.charge_charging, "waits for the ready frame")
	_step()
	check(sim.charge_charging and sim.charge_level == 0, "meter on")
	var frames := 0
	while true:
		_step()
		frames += 1
		if sim.charge_level == 0:
			break
	eq(frames, 2 * K.SERVE_CHARGE_MAX, "up and back down")
	eq(sim.phase, K.PHASE_SERVE_SETUP)
	eq(Sim.serve_flight_frames(K.SERVE_CHARGE_CLASSIC), K.SERVE_FLIGHT_FRAMES)
	eq(Sim.serve_flight_frames(K.SERVE_CHARGE_MAX), 27)
	sim.owners[0] = K.OWNER_CPU
	check(not sim.serve_charged(), "no meter for the CPU")
	sim.owners[0] = K.OWNER_HUMAN
	sim.config.difficulty = K.DIFFICULTY_KID
	check(not sim.serve_charged(), "no meter on KID")
	sim.config.difficulty = K.DIFFICULTY_MEDIUM
	sim.attract = 1
	check(not sim.serve_charged(), "no meter in the demo")


func test_charged_serves_land() -> void:
	for team in 2:
		var slot := 2 if team else 0
		for parity in 2:
			for falling in [false, true]:
				for level in K.SERVE_CHARGE_MAX + 1:
					if falling and level == K.SERVE_CHARGE_MAX:
						continue
					for aim in [-1, 0, 1]:
						_reset(team)
						sim.team_score[team] = parity
						sim.serve_setup(team)
						sim.intents[slot].aim_x = aim
						sim.intents[slot].aim_y = aim
						if not _charge_and_serve(slot, level, falling):
							return
						var ev := _serve_flight_event()
						var tag := "team %d parity %d level %d falling %s aim %d" % [team, parity, level, falling, aim]
						if falling and level < K.SERVE_CHARGE_DUD:
							if not (check(ev & K.BALL_EVENT_NET_FAULT, "dud hits the net: " + tag)
									and eq(sim.last_fault, K.FAULT_NET, tag)):
								return
						elif not (eq(ev, K.BALL_EVENT_BOUNCE, tag) and eq(sim.last_fault, K.FAULT_NONE, tag)):
							return


func test_tap_is_classic() -> void:
	_reset(0)
	sim.owners[0] = K.OWNER_HUMAN
	sim.intents[0].hit_pressed = 1
	sim.intents[0].hit_held = 1
	_step()
	sim.intents[0].hit_pressed = 0
	sim.intents[0].hit_held = 0
	while sim.phase == K.PHASE_SERVE_SETUP:
		_step()
	check(sim.phase_timer <= 2, "served at the ready frame")
	check(not sim.charge_charging, "no meter")
	eq(sim.charge_power, K.SERVE_CHARGE_CLASSIC)
	while sim.phase == K.PHASE_SERVE_TOSS:
		_step()
	eq(_serve_flight_event(), K.BALL_EVENT_BOUNCE)
