## Prints why each point ended in a CPU demo: godot --headless --path game -s res://tools/point_log.gd -- [singles|doubles] [matches]
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var doubles := args.size() > 0 and args[0] == "doubles"
	var matches := int(args[1]) if args.size() > 1 else 1
	var sim := Sim.new(SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles())
	sim.start_attract()
	var tally := {}
	var done := 0
	var hitters := {}
	while done < matches:
		sim.step()
		for e in sim.drain_events():
			if e[0] == K.EVENT_HIT or e[0] == K.EVENT_SERVE:
				var who: int = e[3] & 15
				hitters[who] = hitters.get(who, 0) + 1
			if e[0] == K.EVENT_POINT:
				var key := "%s won=%d lasthit=%d rally=%d" % [K.fault_word(sim.last_fault), e[3], sim.ball.last_hitter, (sim.shot_serial - sim.rally_start) & 0xff]
				print(key)
				var k2 := "%s by team %d" % [K.fault_word(sim.last_fault), 1 - e[3]]
				tally[k2] = tally.get(k2, 0) + 1
		if sim.phase == K.PHASE_MATCH_RESULT and sim.phase_timer == 1:
			done += 1
			print("-- match %d: %d-%d" % [done, sim.team_score[0], sim.team_score[1]])
	print(tally)
	print("contacts per slot: ", hitters)
	quit()
