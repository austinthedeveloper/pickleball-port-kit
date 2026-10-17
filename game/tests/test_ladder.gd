## Stats harness (playbook phase 3): bots vs the CPU, deterministic.
## OPT-02: wins fall with difficulty. OPP-03: the ladder's first rung is
## beaten clearly more than its last.
extends TestSuite

const MATCHES := 10


func _bot_wins(cfg_maker: Callable, late: int) -> int:
	var wins := 0
	for i in MATCHES:
		var sim := Sim.new(cfg_maker.call())
		sim.p1_bot = true
		var frames := 0
		while sim.phase != K.PHASE_MATCH_RESULT and frames < 60 * 60 * 10:
			sim.set_bot_skill(late, i)
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0
				and (frames & 31) == 0) else 0
			sim.step([it, null, null, null])
			frames += 1
		if sim.team_score[0] > sim.team_score[1]:
			wins += 1
	return wins


func test_difficulty_order() -> void:
	var wins := []
	for d in [K.DIFFICULTY_KID, K.DIFFICULTY_EASY, K.DIFFICULTY_MEDIUM, K.DIFFICULTY_HARD]:
		wins.append(_bot_wins(func():
			var c := SimTypes.MatchConfig.singles()
			c.difficulty = d
			return c, 4))
	print("    bot wins of %d by difficulty KID..HARD: %s" % [MATCHES, str(wins)])
	for i in 3:
		check(wins[i] >= wins[i + 1], "wins fall with difficulty: %s" % str(wins))
	check(wins[0] > wins[3], "KID clearly easier than HARD")


func test_ladder_order() -> void:
	var n := Opponents.count()
	var first := _bot_wins(func():
		var c := SimTypes.MatchConfig.singles()
		c.opponent = 0
		return c, 4)
	var last := _bot_wins(func():
		var c := SimTypes.MatchConfig.singles()
		c.opponent = n - 1
		return c, 4)
	print("    bot wins of %d: first rung %s %d, last rung %s %d" % [MATCHES,
		Opponents.team(0)["team"], first, Opponents.team(n - 1)["team"], last])
	check(first > last, "the first rung is easier than the last")
