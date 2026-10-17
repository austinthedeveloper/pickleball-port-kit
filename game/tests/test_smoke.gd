extends TestSuite


func test_attract_singles_finishes_a_match() -> void:
	var sim := Sim.new()
	sim.start_attract()
	var frames := run_until(sim, func(): return sim.phase == K.PHASE_MATCH_RESULT, 60 * 60 * 6)
	check(frames > 0, "a CPU vs CPU match ends within 6 minutes")
	check(sim.team_won(sim.match_winner), "the winner reached the points")
	print("    singles demo: %d frames (%.1f s), score %d-%d" % [frames, frames / 60.0,
		sim.team_score[0], sim.team_score[1]])


func test_attract_doubles_finishes_a_match() -> void:
	var sim := Sim.new(SimTypes.MatchConfig.doubles())
	sim.start_attract()
	var frames := run_until(sim, func(): return sim.phase == K.PHASE_MATCH_RESULT, 60 * 60 * 8)
	check(frames > 0, "a doubles demo ends within 8 minutes")
	print("    doubles demo: %d frames (%.1f s), score %d-%d" % [frames, frames / 60.0,
		sim.team_score[0], sim.team_score[1]])
