## Port of reference/snes-src/test/test_match_flow.c (SCR-01, RST-01,
## M3-MATCH-04): the same numbers the SNES build asserted.
extends TestSuite


func _press(b: int) -> Array:
	var it := SimTypes.Intent.new()
	it.hit_pressed = b
	return [it, null, null, null]


func _play_match(sim: Sim, late: int, index: int) -> Array:
	var frames := 0
	sim.p1_bot = true
	sim.set_bot_skill(late, index)
	while sim.phase != K.PHASE_MATCH_RESULT:
		sim.set_bot_skill(late, index)
		var b := 1 if (sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0 \
			and (frames & 31) == 0) else 0
		sim.step(_press(b))
		frames += 1
		if frames >= 60 * 60 * 10:
			runner.fail("match did not finish in 10 minutes")
			break
	return [frames, sim.team_score[0], sim.team_score[1]]


func test_first_to_five() -> void:
	var sim := Sim.new()
	sim.team_score[0] = 4
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1, K.FAULT_OUT)
	eq(sim.phase, K.PHASE_POINT_RESULT, "point result")
	eq(sim.team_score[0], 5, "score")
	sim.step(_press(1))
	eq(sim.phase, K.PHASE_POINT_RESULT, "B ignored before the minimum")
	for n in K.POINT_RESULT_FRAMES + 2:
		sim.step(_press(0))
	eq(sim.phase, K.PHASE_MATCH_RESULT, "match result")
	eq(sim.match_winner, 0, "winner")
	for n in 600:
		sim.step(_press(0))
	eq(sim.phase, K.PHASE_MATCH_RESULT, "match result never times out")
	sim.step(_press(1))
	check(sim.rematch_requested, "B on the match result asks for a rematch")
	sim.new_match()
	eq(sim.phase, K.PHASE_SERVE_SETUP, "rematch serves")
	eq(sim.team_score, [0, 0], "rematch score")


func test_rematch_matches_fresh_state() -> void:
	var sim := Sim.new()
	var fresh := sim.snapshot()
	var total := 0
	var wins := 0
	for i in 20:
		var r := _play_match(sim, 4, i)
		total += r[0]
		if r[1] > r[2]:
			wins += 1
		sim.p1_bot = false
		while sim.phase == K.PHASE_MATCH_RESULT and not sim.rematch_requested:
			sim.step(_press(1))
		sim.new_match()
		var again := sim.snapshot()
		again[12] = fresh[12]          # frame_count, as the C test aligns it
		if not eq(again, fresh, "RST-01 rematch %d equals a fresh match" % i):
			break
	print("    20 rematches: avg %.1f s, bot won %d" % [total / 20.0 / 60.0, wins])


func _bot_wins(late: int) -> int:
	var wins := 0
	for i in 20:
		var sim := Sim.new()
		var r := _play_match(sim, late, i)
		if r[1] > r[2]:
			wins += 1
	return wins


func test_cpu_is_beatable_but_not_trivial() -> void:
	var novice := _bot_wins(2)
	var strong := _bot_wins(10)
	print("    bot wins of 20: mistimes every 2nd shot %d, every 10th %d" % [novice, strong])
	check(novice <= 5, "a sloppy player mostly loses (%d/20)" % novice)
	check(strong >= 15, "a sharp player mostly wins (%d/20)" % strong)


## ADR-025: KID's ball takes 2 steps in 3, EASY's 3 in 4, evenly spread;
## MEDIUM steps every frame (so the golden traces don't move).
func test_slow_ball_pace() -> void:
	eq(Sim.ball_per_cycle(K.DIFFICULTY_KID), 40)
	eq(Sim.ball_per_cycle(K.DIFFICULTY_EASY), 45)
	eq(Sim.ball_per_cycle(K.DIFFICULTY_MEDIUM), 60)
	var kid := Sim.make_ball_pace(K.DIFFICULTY_KID)
	var total := 0
	for i in 60:
		total += kid[i]
		check(kid[i] <= 1, "never two steps on one frame")
	eq(total, 40, "40 steps a cycle")
	var cfg := SimTypes.MatchConfig.singles()
	cfg.difficulty = K.DIFFICULTY_MEDIUM
	check(not Sim.new(cfg).ball_paced, "MEDIUM is unpaced")


## On every difficulty a CPU-vs-CPU match still finishes (the paced swing
## lookahead finds contacts), and KID's human assist returns balls.
func test_every_difficulty_finishes() -> void:
	for d in [K.DIFFICULTY_KID, K.DIFFICULTY_EASY, K.DIFFICULTY_HARD]:
		var cfg := SimTypes.MatchConfig.singles()
		cfg.difficulty = d
		var sim := Sim.new(cfg)
		var r := _play_match(sim, 4, 1)
		check(r[0] < 60 * 60 * 10, "difficulty %d finishes" % d)
		print("    difficulty %d: %.1f s, %d-%d" % [d, r[0] / 60.0, r[1], r[2]])
