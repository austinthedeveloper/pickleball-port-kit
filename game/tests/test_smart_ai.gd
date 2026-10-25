## Smart play (port ADR-094): off unless MatchConfig.smarts says, so the
## ROM's AI is untouched; the profiles a match gives each slot; KITCHEN and
## TOGETHER's waiting spots (a CPU partner kept level, a human partner
## followed up the court and half way back); AIM's placements (the third
## shot dropped, dinks cross-court, the ball to whoever is back, drives
## down the middle); the knobs tuned live (replays too) and saved; and in
## play, smart opponents waiting closer to the net and level with each
## other.
extends TestSuite


func _doubles(smarts: Array) -> Sim:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.human = [1, 0, 0, 0]
	cfg.smarts = smarts
	return Sim.new(cfg)


func _place(s: Sim, slot: int, x: int, y: int) -> void:
	s.players[slot].x_fp = K.to_fp(x)
	s.players[slot].y_fp = K.to_fp(y)


## A slot's waiting spot (px from the net), as _think works it out.
func _home(s: Sim, slot: int, home: int) -> int:
	s.ai._set_context(slot)
	s.ai.g = s.ai.slots[slot]
	return s.ai._smart_home(s.players[slot], home)


func test_off_unless_asked() -> void:
	var s := Sim.new(SimTypes.MatchConfig.doubles())
	eq(s.config.smarts, [], "a bare config has none")
	eq(s.ai.smart, [[], [], [], []], "and the AI none")
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_HARD, 11)
	eq(cfg.smarts.size(), K.MAX_PLAYERS * K.SMART_KNOBS, "a match the settings build has them")
	s.dispose()


func test_the_profiles_a_match_gives() -> void:
	Settings.smarts = Settings.smart_defaults()
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_HARD, 11)
	eq(cfg.smarts.slice(0, 3), [0, 0, 0], "you: none")
	eq(cfg.smarts.slice(3, 6), Settings.smart_profile("partner"), "your CPU partner: the partner's")
	eq(cfg.smarts.slice(6, 9), Settings.smart_profile("hard"), "the opponents: their difficulty's")
	eq(cfg.smarts.slice(9, 12), Settings.smart_profile("hard"))
	cfg = Settings.config_for(true, 3, K.DIFFICULTY_KID, 11)
	eq(cfg.smarts.slice(6, 9), Settings.smart_profile("kid"))
	var sv := SaveGame.new()
	sv.data = SaveGame.defaults()
	Settings.nudge_smart("hard", K.SMART_AIM, -3)
	eq(int(Settings.smart_profile("hard")[K.SMART_AIM]), int(Settings.smart_defaults()["hard"][K.SMART_AIM]) - 15)
	Settings.store_to(sv)
	Settings.smarts = Settings.smart_defaults()
	Settings.load_from(sv)
	eq(int(Settings.smart_profile("hard")[K.SMART_AIM]), int(Settings.smart_defaults()["hard"][K.SMART_AIM]) - 15,
		"tuned knobs are saved")
	for i in 40:
		Settings.nudge_smart("hard", K.SMART_KITCHEN, 1)
	eq(int(Settings.smart_profile("hard")[K.SMART_KITCHEN]), 100, "100 at most")
	Settings.smarts = Settings.smart_defaults()


func test_kitchen_and_together() -> void:
	var s := _doubles([0, 0, 0, 0, 0, 0, 100, 0, 0, 100, 0, 0])
	s.phase = K.PHASE_LIVE
	s.required_bounce = K.REQUIRED_BOUNCE_NONE
	eq(_home(s, 2, 80), K.AI_SMART_KITCHEN, "KITCHEN 100: just behind the kitchen line")
	s.required_bounce = K.REQUIRED_BOUNCE_RETURN
	s.serving_team = 1
	eq(_home(s, 2, 80), 80, "not before the two-bounce rule lets the serving side in")
	s.required_bounce = K.REQUIRED_BOUNCE_NONE
	s.ai.smart[2] = [50, 0, 0]
	eq(_home(s, 2, 80), 80 + (K.AI_SMART_KITCHEN - 80) / 2, "KITCHEN 50: half way")
	# TOGETHER beside a CPU: no more than a few steps ahead of it
	s.ai.smart[2] = [100, 100, 0]
	_place(s, 3, K.COURT_NET_X + 90, 150)
	eq(_home(s, 2, 80), 90 - K.AI_SMART_AHEAD, "level with a partner still back")
	_place(s, 3, K.COURT_NET_X + 44, 150)
	eq(_home(s, 2, 80), K.AI_SMART_KITCHEN, "and up together once it's up")
	s.dispose()
	# TOGETHER with a human partner: you come up, they come up
	var h := _doubles([0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0])
	h.phase = K.PHASE_LIVE
	h.required_bounce = K.REQUIRED_BOUNCE_NONE
	_place(h, 0, K.COURT_NET_X - 40, 110)
	eq(_home(h, 1, 80), K.AI_SMART_KITCHEN, "you at the kitchen: your partner too")
	_place(h, 0, K.COURT_NET_X - 70, 110)
	eq(_home(h, 1, 80), 70, "you a step back: level with you")
	h.ai.smart[1] = [100, 100, 0]
	_place(h, 0, K.COURT_NET_X - 80, 110)
	eq(_home(h, 1, 80), K.AI_SMART_KITCHEN + (80 - K.AI_SMART_KITCHEN) / 2,
		"you at the back: they give half the ground")
	h.dispose()


func _shot(s: Sim, slot: int) -> Array:
	s.ai._set_context(slot)
	s.ai.g = s.ai.slots[slot]
	s.ai.contact_volley = false
	s.ai._plan_shot(s.players[slot], 0)
	return [s.ai.g.planned_shot, s.ai.g.planned_depth, s.ai.smart_aim[slot]]


func test_aim() -> void:
	var s := _doubles([0, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0, 100])
	s.phase = K.PHASE_LIVE
	s.serving_team = 1
	s.rally_start = 0
	s.shot_serial = 2
	_place(s, 2, K.COURT_NET_X + 100, 110)
	_place(s, 0, K.COURT_NET_X - 40, 110)
	_place(s, 1, K.COURT_NET_X - 40, 150)
	eq(_shot(s, 2), [K.SHOT_SOFT, -1, 1], "the serving side's third shot: dropped, cross-court")
	s.shot_serial = 5
	_place(s, 2, K.COURT_NET_X + 44, 150)
	eq(_shot(s, 2), [K.SHOT_SOFT, -1, -1], "both sides up: a dink, cross-court")
	_place(s, 1, K.COURT_NET_X - 100, 150)
	eq(_shot(s, 2), [K.SHOT_STANDARD, 0, 1], "one of them back: to them")
	_place(s, 0, K.COURT_NET_X - 100, 110)
	eq(_shot(s, 2), [K.SHOT_STANDARD, 0, 0], "both back: down the middle")
	s.ai.smart[2] = [0, 0, 0]
	check(_shot(s, 2)[2] == K.AI_AIM_PATTERN, "AIM 0: the style's own shots")
	s.dispose()


func test_tuned_live_and_replayed() -> void:
	var cfg := Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11)
	cfg.smarts = []
	var a := Sim.new(cfg)
	var b := Sim.new(OnlineSession.config_from_dict(OnlineSession.config_to_dict(cfg)))
	a.p1_bot = true
	b.p1_bot = true
	var hard: Array = [0, 0, 0, 0, 0, 0] + Settings.smart_profile("hard") + Settings.smart_profile("hard")
	for f in 1800:
		if f == 300:
			a.retune_smarts(hard)
			b.retune_smarts(hard)       # a replay applies the panel's op on the same frame
		a.step([SimTypes.Intent.new(), null, null, null])
		b.step([SimTypes.Intent.new(), null, null, null])
	eq(a.ai.smart[2], Settings.smart_profile("hard"), "tuned mid-match")
	eq([a.team_score, a.players[2].x_fp, a.ball.x_fp], [b.team_score, b.players[2].x_fp, b.ball.x_fp],
		"and the replay plays it the same")
	a.retune_smarts([])
	eq(a.ai.smart[2], [], "and off again")
	a.dispose()
	b.dispose()


## How far from the net the opponents wait (the ball on your side, the
## two-bounce rule met), and how far apart in depth, over a few matches.
func _waiting(smarts: Array) -> Array:
	var depth := 0
	var gap := 0
	var n := 0
	for m in 3:
		var cfg := Settings.config_for(true, 1, K.DIFFICULTY_MEDIUM, 11)
		cfg.set_partner(Opponents.PEPPER)
		cfg.smarts = smarts
		var s := Sim.new(cfg)
		s.p1_bot = true
		s.ai.slots[0].late_period = [0, 9, 7][m]
		for f in 60 * 60 * 2:
			if s.phase == K.PHASE_MATCH_RESULT:
				break
			s.step([SimTypes.Intent.new(), null, null, null])
			s.drain_events()
			if s.phase == K.PHASE_LIVE and not Sim.x_on_side(s.ball.x_fp, 1) \
					and s.required_bounce == K.REQUIRED_BOUNCE_NONE:
				var d2 := absi(K.from_fp(s.players[2].x_fp) - K.COURT_NET_X)
				var d3 := absi(K.from_fp(s.players[3].x_fp) - K.COURT_NET_X)
				depth += (d2 + d3) / 2
				gap += absi(d2 - d3)
				n += 1
		s.dispose()
	return [depth / maxi(1, n), gap / maxi(1, n)]


func test_smart_opponents_in_play() -> void:
	var off := _waiting([])
	var hard := _waiting([0, 0, 0, 0, 0, 0] + Settings.smart_defaults()["hard"] + Settings.smart_defaults()["hard"])
	print("    smart play, the SNOWBIRDS waiting: off %d px from the net (%d apart), hard %d (%d apart)" % [
		off[0], off[1], hard[0], hard[1]])
	check(hard[0] < off[0] - 10, "hard: they wait well closer to the net")
	check(hard[1] < off[1], "and level with each other")
