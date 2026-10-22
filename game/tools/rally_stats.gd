## Rally lengths and why points end, over CPU matches built as MATCH SETUP
## builds them (a bot for P1):
##   godot --headless --path game -s res://tools/rally_stats.gd -- [singles|doubles] [matches]
##     [speed=N] [errors=N] [difficulty=N] [opp=N] [mods=N]
## speed: BALL SPEED %; errors: CPU ERRORS % (ADR-072); difficulty 0-3;
## mods: MOD_* bits (131072: SPECIALS, port ADR-080, also counts PICKLE SMASHES).
extends SceneTree


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var doubles := a.size() > 0 and a[0] == "doubles"
	var matches := int(a[1]) if a.size() > 1 else 4
	var kv := {"speed": Settings.ball_speed, "errors": Settings.cpu_errors,
		"difficulty": K.DIFFICULTY_MEDIUM, "opp": 3, "mods": 0}
	for arg in a.slice(2):
		var p: PackedStringArray = arg.split("=")
		if p.size() == 2:
			kv[p[0]] = int(p[1])
	var rallies := []
	var why := {}
	var smashes := 0
	var smash_rallies := 0
	var smash_points := 0
	for m in matches:
		var cfg := Settings.config_for(doubles, (int(kv["opp"]) + m) % Opponents.count(),
			int(kv["difficulty"]), 11)
		cfg.ball_speed = int(kv["speed"])
		cfg.cpu_errors = int(kv["errors"])
		cfg.modifiers = int(kv["mods"])
		var s := Sim.new(cfg)
		var last_special := -1                 # the smasher's team this rally, or -1
		s.p1_bot = true
		for f in 60 * 60 * 20:
			s.step([SimTypes.Intent.new(), null, null, null])
			for e in s.drain_events():
				if e[0] == K.EVENT_HIT:
					if e[3] >> 4 == K.SHOT_SPECIAL:
						last_special = 1 if (e[3] & 15) >= 2 else 0
						smashes += 1
				if e[0] == K.EVENT_POINT:
					smash_rallies += 1 if last_special >= 0 else 0
					smash_points += 1 if last_special == e[3] else 0
					last_special = -1
					rallies.append((s.shot_serial - s.rally_start) & 0xff)
					var w := K.fault_word(s.last_fault)
					why[w] = why.get(w, 0) + 1
			if s.phase == K.PHASE_MATCH_RESULT:
				break
		s.dispose()
	rallies.sort()
	var total := 0
	for r in rallies:
		total += r
	var n := maxi(rallies.size(), 1)
	print("%s speed=%d errors=%d difficulty=%d: %d points, mean rally %.1f, median %d, 10+ %d%%" % [
		"doubles" if doubles else "singles", kv["speed"], kv["errors"], kv["difficulty"],
		rallies.size(), float(total) / n, rallies[rallies.size() / 2] if rallies.size() else 0,
		100 * rallies.filter(func(r): return r >= 10).size() / n])
	print("  ", why)
	if smashes:
		print("  PICKLE SMASHES %d in %d rallies; the (last) smasher's side won %d%% of them" % [smashes,
			smash_rallies, 100 * smash_points / maxi(smash_rallies, 1)])
	quit()
