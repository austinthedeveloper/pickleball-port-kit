## Port of reference/snes-src/test/test_rules.c (RUL-01..03).
extends TestSuite

var sim: Sim


func _live() -> void:
	sim = Sim.new()
	sim._players_initialize()
	sim.ball_initialize()
	sim._game_initialize()
	sim.serve_initialize()
	sim.phase = K.PHASE_LIVE
	var b := sim.ball
	b.rally_state = K.BALL_RALLY_LIVE
	b.last_hitter = 0
	b.vx_fp = 31
	b.vy_fp = 6
	b.vz_fp = 12
	b.x_fp = K.to_fp(200)
	b.bounce_count = 1


func _stopped(winner: int, fault: int) -> void:
	eq(sim.phase, K.PHASE_POINT_RESULT, "phase")
	eq(sim.point_winner, winner, "winner")
	eq(sim.last_fault, fault, "fault")
	eq(sim.team_score[winner], 1, "winner's score")
	eq(sim.team_score[winner ^ 1], 0, "loser's score")
	eq(sim.ball.rally_state, K.BALL_RALLY_INACTIVE, "ball dead")
	eq([sim.ball.vx_fp, sim.ball.vy_fp, sim.ball.vz_fp], [0, 0, 0], "ball stopped")


func test_net_penalizes_last_hitter() -> void:
	_live()
	sim.rules_process_ball_events(K.BALL_EVENT_NET_FAULT)
	_stopped(1, K.FAULT_NET)


func test_out_penalizes_last_hitter() -> void:
	_live()
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	_stopped(1, K.FAULT_OUT)


func test_second_bounce_penalizes_court_team() -> void:   # RUL-03
	_live()
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	eq(sim.phase, K.PHASE_LIVE, "first bounce plays on")
	sim.ball.bounce_count = 2
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	_stopped(0, K.FAULT_SECOND_BOUNCE)
	_live()
	sim.ball.x_fp = K.to_fp(56)
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	_stopped(1, K.FAULT_OUT)
	_live()
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	sim.ball.x_fp = K.to_fp(K.COURT_BASELINE_RIGHT + 10)
	sim.ball.bounce_count = 2
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	_stopped(0, K.FAULT_SECOND_BOUNCE)


func test_dead_ball_ends_rally() -> void:
	_live()
	sim.ball.z_fp = 0
	sim.ball.vx_fp = 0
	sim.ball.vy_fp = 0
	sim.ball.vz_fp = 0
	sim.rules_process_ball_events(K.BALL_EVENT_NONE)
	_stopped(0, K.FAULT_SECOND_BOUNCE)


func test_serve_fault_resolves_point() -> void:
	_live()
	sim.phase = K.PHASE_SERVE_FAULT
	sim.last_fault = K.FAULT_KITCHEN
	sim.rules_process_ball_events(K.BALL_EVENT_NONE)
	_stopped(1, K.FAULT_KITCHEN)


func test_resolution_is_idempotent() -> void:
	_live()
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	eq(sim.team_score[1], 1)


func test_legal_required_bounce_sequence() -> void:   # RUL-01
	_live()
	sim.required_bounce = K.REQUIRED_BOUNCE_SERVE
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	eq(sim.required_bounce, K.REQUIRED_BOUNCE_RETURN)
	sim.ball.last_hitter = 2
	sim.rules_process_player_hit(2)
	eq(sim.required_bounce, K.REQUIRED_BOUNCE_RETURN)
	eq(sim.phase, K.PHASE_LIVE)
	sim.ball.x_fp = K.to_fp(56)
	sim.ball.bounce_count = 1
	sim.rules_process_ball_events(K.BALL_EVENT_BOUNCE)
	eq(sim.required_bounce, K.REQUIRED_BOUNCE_NONE)
	sim.ball.last_hitter = 0
	sim.rules_process_player_hit(0)
	eq(sim.phase, K.PHASE_LIVE, "volley legal after both bounces")


func test_serve_volley_before_bounce_loses_point() -> void:
	_live()
	sim.required_bounce = K.REQUIRED_BOUNCE_SERVE
	sim.rules_process_player_hit(2)
	_stopped(0, K.FAULT_EARLY_VOLLEY)


func test_return_volley_before_bounce_loses_point() -> void:   # RUL-02
	_live()
	sim.required_bounce = K.REQUIRED_BOUNCE_RETURN
	sim.ball.last_hitter = 2
	sim.rules_process_player_hit(0)
	_stopped(1, K.FAULT_EARLY_VOLLEY)
