## Smart play (port ADR-094), measured headless: doubles matches of a bot
## (with a CPU partner at the partner profile) against a ladder team, the
## opponents' smart play off and at each profile; then the opponents at
## hard with your partner's off. Prints, for the opponents: how far from the net they stand
## while the ball is on your side (px; the kitchen line is 36, measured
## once the two-bounce rule lets everyone in), how far apart in depth the two
## are, the share of their shots that are soft (dinks, drops), the mean
## rally, and the points they win; for your partner, how far their depth
## is from yours.
##   godot --headless --path game -s res://tools/smart_stats.gd -- [matches=6] [team=3]
extends SceneTree


func _initialize() -> void:
	var matches := 6
	var team := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("matches="):
			matches = int(arg.substr(8))
		if arg.begins_with("team="):
			team = int(arg.substr(5))
	Settings.smarts = Settings.smart_defaults()
	print("profile    their depth  their gap  soft shots  rally  their points  partner gap")
	for profile in ["off", "easy", "medium", "hard", "partner off"]:
		var depth := 0.0
		var gap := 0.0
		var pgap := 0.0
		var frames := 0
		var soft := 0
		var shots := 0
		var rallies := 0
		var rally_shots := 0
		var won := [0, 0]
		for m in matches:
			var cfg := Settings.config_for(true, team, K.DIFFICULTY_MEDIUM, 11)
			cfg.set_partner(Opponents.PEPPER)
			# your partner at the partner profile throughout; the opponents vary
			var them := [0, 0, 0] if profile in ["off", "partner off"] else Settings.smart_profile(profile)
			if profile == "partner off":
				them = Settings.smart_profile("hard")
			var mine := [0, 0, 0] if profile == "partner off" else Settings.smart_profile("partner")
			cfg.smarts = [0, 0, 0] + mine + them + them
			var s := Sim.new(cfg)
			s.p1_bot = true
			s.ai.slots[0].late_period = [0, 9, 7][m % 3]
			var in_rally := 0
			for f in 60 * 60 * 6:
				if s.phase == K.PHASE_MATCH_RESULT:
					break
				s.step([SimTypes.Intent.new(), null, null, null])
				for e in s.drain_events():
					if int(e[0]) == K.EVENT_HIT:
						in_rally += 1
						if int(e[3]) & 15 >= 2:
							shots += 1
							if (int(e[3]) >> 4) == K.SHOT_SOFT:
								soft += 1
					elif int(e[0]) == K.EVENT_POINT:
						won[int(e[3])] += 1
						rallies += 1
						rally_shots += in_rally
						in_rally = 0
				# where they wait: the ball on your side, the rules letting them in
				if s.phase == K.PHASE_LIVE and not Sim.x_on_side(s.ball.x_fp, 1) \
						and s.required_bounce == K.REQUIRED_BOUNCE_NONE:
					var d2 := absi(K.from_fp(s.players[2].x_fp) - K.COURT_NET_X)
					var d3 := absi(K.from_fp(s.players[3].x_fp) - K.COURT_NET_X)
					var d0 := absi(K.from_fp(s.players[0].x_fp) - K.COURT_NET_X)
					var d1 := absi(K.from_fp(s.players[1].x_fp) - K.COURT_NET_X)
					depth += (d2 + d3) / 2.0
					gap += absi(d2 - d3)
					pgap += absi(d0 - d1)
					frames += 1
			s.dispose()
		print("%-9s  %8.1f  %9.1f  %9d%%  %5.1f  %8d of %d  %9.1f" % [profile, depth / maxi(1, frames),
			gap / maxi(1, frames), 100 * soft / maxi(1, shots), rally_shots / float(maxi(1, rallies)),
			won[1], won[0] + won[1], pgap / maxi(1, frames)])
	quit()
