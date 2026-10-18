## Contact heights (PORT-24): bot matches, every hit's z, shot, distance to
## the net, and how the point went for the hitter.
##   godot --headless --path game -s res://tools/contact_probe.gd -- [doubles] [matches]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var doubles := "doubles" in args
	var matches := 20
	for a in args:
		if a.is_valid_int():
			matches = int(a)
	var by_z := {}   # z bucket -> [hits, points won by the hitter's team on that shot as last hit]
	var shots := {}
	var falling := {}
	var won := [0, 0]
	var high := 0
	var oh := 0
	var oh_won := 0
	var rallies := 0
	var rally_total := 0
	var high_won := 0
	for i in matches:
		var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
		cfg.opponent = i % Opponents.count()
		var sim := Sim.new(cfg)
		sim.p1_bot = true
		var frames := 0
		var last_z := 0
		var last_team := -1
		var last_shot := 0
		var rally_hits := 0
		while sim.phase != K.PHASE_MATCH_RESULT and frames < 60 * 60 * 10:
			sim.set_bot_skill(4, i)
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if (sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0
				and (frames & 31) == 0) else 0
			var pre_z := sim.ball.z_fp
			var pre_vz := sim.ball.vz_fp
			sim.step([it, null, null, null])
			for e in sim.drain_events():
				if e[0] == K.EVENT_HIT and (e[3] & 15) < 4 and rally_hits == 0:
					rally_hits += 1   # the serve
				elif e[0] == K.EVENT_HIT and (e[3] & 15) < 4:
					rally_hits += 1
					var z := K.from_fp(pre_z)
					var p: SimTypes.Player = sim.players[e[3] & 15]
					var shot: int = e[3] >> 4
					var b := z / 4 * 4
					by_z[b] = by_z.get(b, 0) + 1
					if pre_vz < 0:
						falling[b] = falling.get(b, 0) + 1
					shots[shot] = shots.get(shot, 0) + 1
					last_z = z
					last_team = p.team
					last_shot = shot
				elif e[0] == K.EVENT_POINT:
					if last_shot == 3 and last_team >= 0:
						oh += 1
						if e[3] == last_team:
							oh_won += 1
					if last_z >= 16 and last_team >= 0:
						high += 1
						if e[3] == last_team:
							high_won += 1
					last_team = -1
					rallies += 1
					rally_total += rally_hits
					rally_hits = 0
			frames += 1
		won[0 if sim.team_score[0] > sim.team_score[1] else 1] += 1
		sim.dispose()
	var keys := by_z.keys()
	keys.sort()
	for k in keys:
		print("z %2d-%2d: %d (falling %d)" % [k, k + 3, by_z[k], falling.get(k, 0)])
	print("shots ", shots, " matches won ", won)
	print("points whose last hit was z>=16: ", high, " (hitter's team won ", high_won, ")")
	print("points ended on an overhead: ", oh, " (smasher won ", oh_won, "); mean rally ", float(rally_total) / maxi(rallies, 1))
	quit()
