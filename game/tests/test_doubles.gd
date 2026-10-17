## Port of reference/snes-src/test/test_doubles.c (ADR-018 arcade doubles).
extends TestSuite


func _doubles() -> Sim:
	return Sim.new(SimTypes.MatchConfig.doubles())


func _top(sim: Sim, slot: int) -> bool:
	return sim.players[slot].y_fp < K.to_fp(K.COURT_CENTERLINE_Y)


func test_activation_and_ownership() -> void:
	var sim := _doubles()
	for i in K.MAX_PLAYERS:
		eq(sim.players[i].active, 1, "slot %d active" % i)
	eq(sim.owners, [K.OWNER_HUMAN, K.OWNER_CPU, K.OWNER_CPU, K.OWNER_CPU])
	eq(sim.config.palette[0], 0, "left team blue")
	eq(sim.config.palette[2], 1, "right team red")
	var seen := {}
	for p in sim.config.palette:
		seen[p] = true
	eq(seen.size(), 4, "colours unique (ADR-010)")


func test_server_rotation() -> void:
	var sim := _doubles()
	eq(sim.server_index, 0)
	eq(sim.receiver_index, 2)
	check(not _top(sim, 0) and _top(sim, 2), "bottom serves to top")
	check(_top(sim, 1) and not _top(sim, 3), "partners in the other lanes")
	eq(sim.players[1].x_fp, K.to_fp(K.COURT_BASELINE_LEFT - K.SERVE_RECEIVER_GAP))
	eq(sim.players[3].x_fp, K.to_fp(K.COURT_KITCHEN_RIGHT_X + K.SERVE_PARTNER_KITCHEN_GAP))
	sim.team_score[0] = 1
	sim.serve_setup(0)
	eq([sim.server_index, sim.receiver_index], [1, 3], "odd: top-lane partner serves")
	sim.team_score[1] = 2
	sim.serve_setup(1)
	eq([sim.server_index, sim.receiver_index], [2, 0], "right team even")
	sim.team_score[1] = 3
	sim.serve_setup(1)
	eq([sim.server_index, sim.receiver_index], [3, 1], "right team odd")


func test_teammate_separation() -> void:
	var sim := _doubles()
	Sim.place(sim.players[2], 200, 130)
	Sim.place(sim.players[3], 202, 131)
	var gap: int = sim.players[3].y_fp - sim.players[2].y_fp
	sim.separate_teammates()
	eq(sim.players[3].y_fp - sim.players[2].y_fp, gap + 2 * K.FP_ONE)


func test_ai_doubles_matches() -> void:
	var sim := _doubles()
	var frames := 0
	var matches := 0
	var counted := false
	var serial := sim.shot_serial
	var hits := [0, 0, 0, 0]
	sim.ai.slots[0].late_period = 4
	while matches < 3:
		for i in K.MAX_PLAYERS:
			sim.intents[i].clear()
			sim.ai.update(i, sim.intents[i])
		if sim.phase == K.PHASE_MATCH_RESULT:
			sim.intents[0].hit_pressed = 1
			if not counted:
				counted = true
				matches += 1
		else:
			counted = false
		sim.game_update()
		if sim.rematch_requested:
			sim.new_match()
			sim.ai.slots[0].late_period = 4
		if sim.shot_serial != serial:
			serial = sim.shot_serial
			if sim.ball.last_hitter < K.MAX_PLAYERS:
				hits[sim.ball.last_hitter] += 1
		var a: Array = sim.ai.slots
		if a[2].has_target and a[3].has_target:
			runner.fail("both right-team CPUs plan the same ball (frame %d)" % frames)
			return
		if a[0].has_target and a[1].has_target \
				and absi(a[1].target_y - K.COURT_CENTERLINE_Y) > 30:
			runner.fail("the partner went deep into slot 0's half (frame %d)" % frames)
			return
		frames += 1
		if frames >= 60 * 60 * 20:
			runner.fail("3 doubles matches took over 20 minutes")
			return
	print("    doubles: 3 AI matches in %.1f s each, hits by slot %s" % [frames / 3.0 / 60.0, str(hits)])
	check(hits[0] * 2 >= hits[1], "slot 0 plays a fair share of its team's balls")


## 2P versus (ADR-020): slot 2 is human, reads its own intent, and only P1
## pauses.
func test_two_player_versus() -> void:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.human[2] = 1
	var sim := Sim.new(cfg)
	eq(sim.owners[2], K.OWNER_HUMAN, "slot 2 human")
	var p2 := SimTypes.Intent.new()
	p2.move_y = -1
	p2.pause_pressed = 1
	var y0: int = sim.players[2].y_fp
	for f in 10:
		sim.step([SimTypes.Intent.new(), null, p2, null])
	check(sim.players[2].y_fp < y0, "P2 moves with its own input")
	eq(sim.paused, 0, "P2 can't pause")
	sim.team_score[1] = 0
	sim.serve_setup(1)
	check(sim.serve_charged(), "a human P2 server gets the meter")
