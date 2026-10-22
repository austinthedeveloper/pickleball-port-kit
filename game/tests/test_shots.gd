## The four swings and SHORT (PORT-41, SNES ADR-056 and 057), ported from
## the SNES repo's test_collision.c (test_slice_and_fast_drop),
## test_input.c (test_slice_and_short_hold) and test_ai.c (test_slice).
## HIT, DRIVE, SOFT and SLICE swing; SHORT (L or R on a pad) aims away
## from your own net, so any shot goes short; CPUs with a slice period
## slice some rally shots.
extends TestSuite

var sim: Sim
var offset_y := 0


func _fly(team: int, shot: int, aim_x: int) -> Array:
	sim = Sim.new()
	for i in K.MAX_PLAYERS:
		sim.players[i] = SimTypes.Player.new()
		sim.players[i].contact_consumed = 0
		sim.intents[i].clear()
	var p: SimTypes.Player = sim.players[0]
	p.paddle = Paddles.STANDARD
	p.active = 1
	p.y_fp = K.to_fp(112)
	sim.ball = SimTypes.Ball.new()
	sim.ball.active = 1
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.ball.z_fp = K.to_fp(10)
	sim.ball.y_fp = p.y_fp + K.to_fp(offset_y)
	# mid-court, where lobs and drives differ most from a standard shot
	p.x_fp = K.to_fp(146 if team else 110)
	sim.ball.x_fp = p.x_fp
	p.team = team
	p.shot_type = shot
	p.state = K.STATE_ACTIVE
	sim.intents[0].aim_x = aim_x
	eq(sim.resolve_player_hits(), 1)
	var frames := 0
	var apex := 0
	while not (Sim.simulate_step(sim.ball) & K.BALL_EVENT_BOUNCE):
		apex = maxi(apex, sim.ball.z_fp)
		frames += 1
		if frames >= 80:
			runner.fail("never landed")
			break
	return [frames, apex]


func _near(x_fp: int, x: int, msg: String) -> void:
	check(absi(x_fp - K.to_fp(x)) < K.to_fp(3), "%s (lands at %d, not %d)" % [msg, K.from_fp(x_fp), x])


## test_slice_and_fast_drop: a slice is slower than a standard shot and no
## higher than its ceiling, neutral when aimed deep, short when aimed away,
## mirrored, and sprays less; a fast drop lands short in the sweet spot and
## past neutral off a stretch.
func test_slice_and_fast_drop() -> void:
	var standard: int = _fly(0, K.SHOT_STANDARD, 0)[0]
	var frames: int = _fly(0, K.SHOT_SLICE, 0)[0]
	check(frames > standard + 6, "a slice is slower (%d frames, a standard shot %d)" % [frames, standard])
	check(frames <= K.HIT_FLIGHT_MAX_FRAMES, "no higher than a standard shot's ceiling")
	_near(sim.ball.x_fp, K.HIT_TARGET_NEUTRAL_RIGHT, "neutral")
	_fly(0, K.SHOT_SLICE, 1)
	_near(sim.ball.x_fp, K.HIT_TARGET_NEUTRAL_RIGHT, "never deep")
	_fly(0, K.SHOT_SLICE, -1)
	_near(sim.ball.x_fp, K.HIT_TARGET_SHORT_RIGHT, "short when aimed away")
	_fly(1, K.SHOT_SLICE, 1)
	_near(sim.ball.x_fp, Sim.target_x_for(1, K.HIT_TARGET_SHORT_RIGHT), "mirrored")
	offset_y = K.HIT_SWEET_Y + 4
	_fly(0, K.SHOT_STANDARD, 0)
	var standard_y := sim.ball.y_fp
	_fly(0, K.SHOT_SLICE, 0)
	check(sim.ball.y_fp < standard_y, "off a stretch a slice sprays less")
	check(sim.ball.y_fp > K.to_fp(K.HIT_TARGET_LANE_CENTER), "but still sprays")
	_fly(0, K.SHOT_DRIVE, -1)
	_near(sim.ball.x_fp, K.HIT_TARGET_SHORT_RIGHT + K.HIT_FAST_DROP_STRETCH_LONG, "a stretched fast drop flies long")
	check(sim.ball.x_fp > K.to_fp(K.HIT_TARGET_NEUTRAL_RIGHT), "past neutral, where it sits up")
	offset_y = 0
	frames = _fly(0, K.SHOT_DRIVE, -1)[0]
	_near(sim.ball.x_fp, K.HIT_TARGET_SHORT_RIGHT, "a clean fast drop lands short")
	check(frames < _fly(0, K.SHOT_STANDARD, -1)[0], "and faster than a short standard shot")


## The overhead (the port's ADR-053) stays HIT and DRIVE only: a slice at a
## high, falling ball is still a slice, as in the ROM.
func test_a_high_slice_is_a_slice() -> void:
	sim = Sim.new()
	for i in K.MAX_PLAYERS:
		sim.players[i] = SimTypes.Player.new()
		sim.players[i].contact_consumed = 0
		sim.intents[i].clear()
	var p: SimTypes.Player = sim.players[0]
	p.active = 1
	p.state = K.STATE_ACTIVE
	p.shot_type = K.SHOT_SLICE
	p.x_fp = K.to_fp(100)
	p.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	sim.ball = SimTypes.Ball.new()
	sim.ball.active = 1
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.ball.last_hitter = 2
	sim.ball.x_fp = p.x_fp
	sim.ball.y_fp = p.y_fp
	sim.ball.z_fp = K.to_fp(K.HIT_OVERHEAD_Z + 2)
	sim.ball.vz_fp = -40
	sim.resolve_player_hits()
	eq(p.shot_type, K.SHOT_SLICE)


## test_slice_and_short_hold, on the port's input: the slice is a swing;
## SHORT aims away from your own net for either team while the D-pad still
## moves and aims at a sideline; SHORT alone isn't a swing.
func test_slice_and_short_hold() -> void:
	var dev := 41
	GameControls.fake_pads = {dev: {"buttons": []}}
	GameControls.read_pad_intent(dev)                 # nothing held before
	GameControls.fake_pads[dev]["buttons"] = [JOY_BUTTON_Y, JOY_BUTTON_DPAD_RIGHT]
	var it := GameControls.read_pad_intent(dev, 0)
	check(it.hit_pressed == 1 and it.hit_held == 1, "the slice button swings")
	eq([it.shot, it.aim_x], [K.SHOT_SLICE, 1], "a slice, aimed by the D-pad")
	GameControls.fake_pads[dev]["buttons"] = []
	GameControls.read_pad_intent(dev, 1)
	GameControls.fake_pads[dev]["buttons"] = [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT]
	it = GameControls.read_pad_intent(dev, 1)
	eq([it.shot, it.aim_x, it.move_x], [K.SHOT_DRIVE, 1, -1], "the right team: RB aims away (+1), the D-pad still moves")
	GameControls.fake_pads[dev] = {"buttons": []}
	GameControls.read_pad_intent(dev, 1)
	GameControls.fake_pads[dev] = {"buttons": [], "rt": 1.0}
	it = GameControls.read_pad_intent(dev, 1)
	eq([it.hit_pressed, it.shot], [1, K.SHOT_SPECIAL], "the right trigger is SPECIAL (port ADR-080)")
	it = GameControls.read_pad_intent(dev, 1)
	eq(it.hit_pressed, 0, "held, it doesn't swing again")
	GameControls.fake_pads[dev] = {"buttons": []}
	GameControls.read_pad_intent(dev, 0)
	GameControls.fake_pads[dev]["buttons"] = [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP]
	it = GameControls.read_pad_intent(dev, 0)
	eq(it.hit_pressed, 0, "SHORT alone isn't a swing")
	eq([it.aim_x, it.move_x, it.aim_y], [-1, 1, -1], "the left team: LB aims away (-1), still a sideline")
	GameControls.fake_pads[dev]["buttons"] = [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_A]
	it = GameControls.read_pad_intent(dev, 0)
	eq([it.shot, it.aim_x], [K.SHOT_STANDARD, -1], "LB + HIT: a short standard shot")
	GameControls.fake_pads = {}


## The keyboard and P1's pad through the input map: SLICE and SHORT are
## actions (remappable on CONTROLS), RB is SHORT too, SLICE is I;
## SPECIAL is O and the right trigger.
func test_the_input_map() -> void:
	for a in ["slice", "short", "special"]:
		check(InputMap.has_action(a), "%s is an action" % a)
		check(a in Bindings.ACTIONS, "and on CONTROLS")
	var pads := InputMap.action_get_events("short").filter(func(e): return e is InputEventJoypadButton) \
		.map(func(e): return e.button_index)
	check(JOY_BUTTON_LEFT_SHOULDER in pads and JOY_BUTTON_RIGHT_SHOULDER in pads, "SHORT is LB or RB")
	var sp := InputMap.action_get_events("special").filter(func(e): return e is InputEventJoypadMotion) \
		.map(func(e): return e.axis)
	check(JOY_AXIS_TRIGGER_RIGHT in sp, "SPECIAL is the right trigger")
	eq(Prompts.trigger_glyph(Prompts.XBOX)["text"], "RT")
	eq(Prompts.trigger_glyph(Prompts.PLAYSTATION)["text"], "R2")
	eq(Prompts.trigger_glyph(Prompts.NINTENDO)["text"], "ZR")
	# (the aim rule itself is the pad test's: pressing actions here would leave
	# "just pressed" set for every later suite, which never advances a frame)
	var keys := InputMap.action_get_events("slice").filter(func(e): return e is InputEventKey) \
		.map(func(e): return e.physical_keycode)
	check(KEY_I in keys, "SLICE is I on the keyboard, beside J K L")


## test_slice: RAVEN (GOTH CLUB) slices a share of her rally swings against
## the bot, through Sim.step; with her knob at 0, none. The default style
## and the partner style never slice.
func _raven(slice: int, matches: int) -> Array:
	var swings := 0
	var slices := 0
	var played := 0
	var cfg := SimTypes.MatchConfig.singles()
	cfg.opponent = 4
	var s := Sim.new(cfg)
	s.p1_bot = true
	var f := 0
	while played < matches and f < 60 * 60 * 30:
		s.ai.styles[2].slice = slice
		s.set_bot_skill(4, played)
		var it := SimTypes.Intent.new()
		it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and s.server_index == 0 and (f & 31) == 0) else 0
		s.step([it, null, null, null])
		for e in s.drain_events():
			if e[0] == K.EVENT_HIT and (e[3] & 15) == 2:
				swings += 1
				if (e[3] >> 4) == K.SHOT_SLICE:
					slices += 1
		if s.phase == K.PHASE_MATCH_RESULT:
			played += 1
			s.new_match()
		f += 1
	s.dispose()
	return [slices, swings]


func test_cpus_slice() -> void:
	var raven: SimTypes.AiStyle = Opponents.team(4)["players"][0]["style_obj"]
	check(raven.slice > 0, "RAVEN's style slices (%d)" % raven.slice)
	eq([Opponents.default_style().slice, Opponents.partner_style().slice], [0, 0],
		"the default CPU and a human's partner never do")
	var r := _raven(raven.slice, 6)
	print("    RAVEN sliced %d of %d rally swings in 6 singles matches" % r)
	check(r[0] * 10 >= r[1] and r[0] * 3 < r[1], "between a tenth and a third")
	eq(_raven(0, 2)[0], 0, "with the knob at 0, none")
