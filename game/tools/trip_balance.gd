## ROAD TRIP's balance (port ADR-087), headless: a bot in your place (as
## rally_stats.gd's) plays a trip's kinds of match at a range of stats,
## and the win rate and the minutes a match takes are printed.
##   godot --headless --path game -s res://tools/trip_balance.gd -- [matches=20]
## The bot isn't you; read the numbers against each other (how much a
## stat point is worth, how a leg's matches compare), not as your odds.
extends SceneTree


func _initialize() -> void:
	var matches := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("matches="):
			matches = int(arg.substr(8))
	var scenarios := [
		["leg 1 pickup (locals, EASY, to 3)", 0, {"type": "pickup", "team": -1, "local": 0, "mod": "", "venue": "park", "time": 0}],
		["leg 1 big match (Snowbirds, to 5)", 0, {"type": "big", "team": 1, "mod": "", "venue": "lakeside", "time": 0}],
		["leg 2 grudge (Pirates, ICE, to 5)", 1, {"type": "grudge", "team": 3, "mod": "MOD_ICE", "venue": "dinosaur", "time": 0}],
		["leg 2 big match (Goth Club, to 5)", 1, {"type": "big", "team": 4, "mod": "", "venue": "space", "time": 0}],
		["the final (Champs, HARD, to 7)", 2, {"type": "final", "team": 7, "mod": "", "venue": "sunset", "time": 2}],
	]
	print("stats  " + "  ".join(scenarios.map(func(s): return String(s[0]))))
	for level in [1, 4, 8, 12, 16, 20]:
		var row := "%5d  " % level
		for sc in scenarios:
			var won := 0
			var frames := 0
			for i in matches:
				var t := RoadTrip.create(1000 + i, 0, RoadTrip.PEPPER)
				t.base = [level, level, level, level]
				t.partner_stats = [maxi(6, level), maxi(6, level), maxi(6, level), maxi(6, level)]
				t.at = [int(sc[1]), 0, 0]
				var cfg := t.config_for(sc[2], Settings.p1_choice)
				var s := Sim.new(cfg)
				var f := 0
				# the sim has no chance in it: each match's bot errs at its own
				# rate (a late swing every Nth ball, 0 never), a range of players
				s.p1_bot = true
				s.ai.slots[0].late_period = [0, 9, 7, 5, 4][i % 5]
				while s.phase != K.PHASE_MATCH_RESULT and f < 60 * 60 * 15:
					s.step([SimTypes.Intent.new(), null, null, null])
					s.drain_events()
					f += 1
				if s.match_winner == 0:
					won += 1
				frames += f
				s.dispose()
			row += "%3d%% %4.1f min    " % [100 * won / matches, frames / 60.0 / 60.0 / matches]
		print(row)
	quit()
