## A long rally heats up (PORT-43), display only: the ball and the RALLY
## sign catch fire at RallyHeat.FIRE_AT shots; from FOCUS_AT, and a step
## every FOCUS_STEP after, everything but the court dims; the point's end
## lets it go. Not in the demo, practice or MULTI BALL.
extends TestSuite


func test_thresholds() -> void:
	check(not RallyHeat.on_fire(RallyHeat.FIRE_AT - 1) and RallyHeat.on_fire(RallyHeat.FIRE_AT))
	eq(RallyHeat.focus_for(RallyHeat.FOCUS_AT - 1), 0.0, "no focus yet")
	var steps := []
	for shots in [15, 19, 20, 25, 30, 60]:
		steps.append(RallyHeat.focus_for(shots))
	check(steps[0] > 0.0 and steps[0] == steps[1], "a step at 15, held to 19")
	check(steps[2] > steps[1] and steps[3] > steps[2] and steps[4] > steps[3], "darker every 5")
	eq(steps[5], RallyHeat.FOCUS_MAX, "never past the cap")
	check(RallyHeat.FOCUS_MAX < 1.0, "never black")


func _view(cfg: SimTypes.MatchConfig, demo := false) -> MatchView:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, "park", demo)
	v.sim.p1_bot = true
	v.card_frames = -1
	return v


## A live point held at a long rally's count (a test may write to the sim):
## the fire, the focus easing in, then out after the point.
func test_in_a_match() -> void:
	var v := _view(Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11))
	check(v.focus != null and v.heat != null)
	var fired := false
	var embers := 0
	var hud_flames := false
	for f in 4000:
		v._physics_process(1.0 / 60.0)
		if v.sim.phase == K.PHASE_LIVE and v.sim.ball.rally_state == K.BALL_RALLY_LIVE:
			v.sim.rally_start = (v.sim.shot_serial - 40) & 0xff
			fired = true
			embers = maxi(embers, v.heat.embers.size())
			hud_flames = hud_flames or v._hud._rally_flames.visible
		elif fired:
			break
	check(fired, "a live point")
	check(embers > 0, "the ball trails embers")
	check(hud_flames, "the RALLY sign burns")
	check(v.focus.amount > 0.2, "the focus came in (%.2f)" % v.focus.amount)
	# the point is over: it lets go
	v.sim.set_phase(K.PHASE_POINT_RESULT)
	for f in 240:
		v._update_visuals()
	eq(v.focus.amount, 0.0, "and out again")
	eq(v._ball_sprite.modulate, Color.WHITE, "the ball cools")
	v.free()


func test_not_in_the_demo_practice_or_multi_ball() -> void:
	var d := _view(SimTypes.MatchConfig.doubles(), true)
	d.sim.set_phase(K.PHASE_LIVE)
	d.sim.rally_start = (d.sim.shot_serial - 40) & 0xff
	eq(RallyHeat.rally(d), 0, "the demo")
	d.free()
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_MULTI_BALL
	var m := _view(cfg)
	m.sim.rally_start = (m.sim.shot_serial - 40) & 0xff
	eq(RallyHeat.rally(m), 0, "MULTI BALL")
	m.free()


## Display only: a match with the heat plays as a bare sim does.
func test_display_only() -> void:
	var cfg := Settings.config_for(true, 7, K.DIFFICULTY_MEDIUM, 11)
	var v := _view(cfg)
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	for f in 2000:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % f)
			break
	eq(v.sim.snapshot(), bare.snapshot(), "2000 frames match a bare sim")
	bare.dispose()
	v.free()
