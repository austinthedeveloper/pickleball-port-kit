## Port of reference/snes-src/test/test_ball.c (PHY-01..05).
extends TestSuite


func _ball(x: int, y: int, z: int, vx: int, vy: int, vz: int) -> SimTypes.Ball:
	var b := SimTypes.Ball.new()
	b.active = 1
	b.rally_state = K.BALL_RALLY_LIVE
	b.x_fp = x
	b.y_fp = y
	b.z_fp = z
	b.vx_fp = vx
	b.vy_fp = vy
	b.vz_fp = vz
	return b


func test_initial_state() -> void:
	var sim := Sim.new()
	sim.ball_initialize()
	var b := sim.ball
	eq(b.active, 1)
	eq(b.x_fp, K.to_fp(K.BALL_START_X))
	eq(b.y_fp, K.to_fp(K.BALL_START_Y))
	eq(b.z_fp, 0)
	eq(b.last_hitter, K.BALL_NO_HITTER)
	eq(b.bounce_count, 0)
	eq(b.rally_state, K.BALL_RALLY_LIVE)


func test_deterministic_flight() -> void:
	var a := _ball(K.to_fp(64), K.to_fp(112), 0, 44, -19, 0)
	var b := a.copy()
	for f in 240:
		if not eq(Sim.simulate_step(a), Sim.simulate_step(b)):
			return
		if not eq(a.to_array(), b.to_array()):
			return


func test_position_and_gravity_order() -> void:
	var b := _ball(K.to_fp(10), K.to_fp(20), K.to_fp(3), 4, -2, 8)
	eq(Sim.simulate_step(b), 0)
	eq(b.x_fp, K.to_fp(10) + 4)
	eq(b.y_fp, K.to_fp(20) - 2)
	eq(b.z_fp, K.to_fp(3) + 8)
	eq(b.vz_fp, 8 + K.BALL_GRAVITY_FP)


func test_single_bounce_event() -> void:   # PHY-05
	var b := _ball(K.to_fp(K.COURT_NET_X - 16), K.to_fp(K.COURT_CENTERLINE_Y), 2, 100, -100, -64)
	eq(Sim.simulate_step(b), K.BALL_EVENT_BOUNCE)
	eq(b.z_fp, 0)
	eq(b.vx_fp, 92)
	eq(b.vy_fp, -92)
	eq(b.vz_fp, 35, "55% vertical retention")
	eq(b.bounce_count, 1)
	eq(Sim.simulate_step(b), 0)
	eq(b.bounce_count, 1)


func test_swept_net_height_boundaries() -> void:   # PHY-01/02
	var net := K.to_fp(K.COURT_NET_X)
	var t := K.to_fp(K.COURT_NET_HEIGHT)
	eq(Sim.net_crossing_height(net - 256, t + 1, net + 256, t + 1), t + 1)
	eq(Sim.net_crossing_height(net - 256, t - 1, net + 256, t - 1), t - 1)
	eq(Sim.net_crossing_height(net + 256, t + 1, net - 256, t + 1), t + 1)
	eq(Sim.net_crossing_height(net - 512, t, net - 1, t), null)


func test_net_fault_event() -> void:
	var b := _ball(K.to_fp(K.COURT_NET_X) - 1, 0, K.to_fp(K.COURT_NET_HEIGHT) - 1, 2, 0, 0)
	check(Sim.simulate_step(b) & K.BALL_EVENT_NET_FAULT, "one unit below: NET")
	b = _ball(K.to_fp(K.COURT_NET_X) - 1, 0, K.to_fp(K.COURT_NET_HEIGHT) + 1, 2, 0, 0)
	check(not (Sim.simulate_step(b) & K.BALL_EVENT_NET_FAULT), "one unit above: over")


func _ground_event_at(x: int, y: int) -> int:
	return Sim.simulate_step(_ball(x, y, 1, 0, 0, -2))


func test_inclusive_court_boundaries() -> void:   # PHY-03/04
	var l := K.to_fp(K.COURT_BASELINE_LEFT)
	var r := K.to_fp(K.COURT_BASELINE_RIGHT)
	var t := K.to_fp(K.COURT_SIDELINE_TOP)
	var bt := K.to_fp(K.COURT_SIDELINE_BOTTOM)
	var ev := _ground_event_at(l, t)
	check(ev & K.BALL_EVENT_BOUNCE, "bounce")
	check(not (ev & K.BALL_EVENT_OUT), "corner is in")
	for p in [[r, t], [l, bt], [r, bt]]:
		check(not (_ground_event_at(p[0], p[1]) & K.BALL_EVENT_OUT), "lines are in")
	for p in [[l - 1, t], [r + 1, t], [l, t - 1], [l, bt + 1]]:
		check(_ground_event_at(p[0], p[1]) & K.BALL_EVENT_OUT, "one unit outside is out")


func test_inactive_ball_does_not_move() -> void:
	var b := _ball(K.to_fp(50), K.to_fp(50), K.to_fp(5), 10, 10, 10)
	b.active = 0
	var before := b.to_array()
	eq(Sim.simulate_step(b), 0)
	eq(b.to_array(), before)


func test_opening_ball_remains_at_rest() -> void:
	var sim := Sim.new()
	sim.ball_initialize()
	for f in 600:
		Sim.simulate_step(sim.ball)
	eq(sim.ball.x_fp, K.to_fp(K.BALL_START_X))
	eq([sim.ball.z_fp, sim.ball.vx_fp, sim.ball.vy_fp, sim.ball.vz_fp], [0, 0, 0, 0])


func test_fast_ball_eventually_settles() -> void:
	var b := _ball(K.to_fp(64), K.to_fp(112), 0, 44, 0, 40)
	var f := 0
	while f < 600:
		Sim.simulate_step(b)
		if b.z_fp == 0 and b.vz_fp == 0:
			break
		f += 1
	check(f < 300, "settles within 300 frames")
	eq([b.z_fp, b.vx_fp, b.vy_fp, b.vz_fp], [0, 0, 0, 0])


func test_standard_shot_has_meaningful_first_flight() -> void:
	var b := _ball(K.to_fp(64), K.to_fp(K.COURT_CENTERLINE_Y), 0, 44, 0, 40)
	var f := 0
	while f < 60:
		if Sim.simulate_step(b) & K.BALL_EVENT_BOUNCE:
			break
		f += 1
	eq(f, 27)
	eq(b.x_fp, K.to_fp(64) + 44 * 28)
	eq(b.bounce_count, 1)
