## The tuning panel (PORT-49, ADR-074): F2 or the pause menu's TUNE, during
## a match. The match waits while it's open; BALL SPEED, BALL SIZE and CPU
## ERRORS change it live (a retuned sim plays as one that started so);
## APPLY rebuilds it with the modifiers set there. Not online, not the demo.
extends TestSuite


func _view(cfg: SimTypes.MatchConfig = null) -> MatchView:
	return match_view(cfg if cfg else Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 11))


func _kept() -> Array:
	return [Settings.ball_speed, Settings.ball_size, Settings.cpu_errors, Settings.mod_bits]


func _restore(k: Array) -> void:
	Settings.ball_speed = k[0]
	Settings.ball_size = k[1]
	Settings.cpu_errors = k[2]
	Settings.mod_bits = k[3]


## A sim retuned on its first frame plays as one built with those values.
func test_retune_is_exact() -> void:
	var a := SimTypes.MatchConfig.doubles()
	a.ball_speed = 83
	a.cpu_errors = 40
	var built := Sim.new(a)
	var tuned := Sim.new(SimTypes.MatchConfig.doubles())
	tuned.retune(83, 40)
	for s in [built, tuned]:
		s.p1_bot = true
	for f in 3000:
		built.step([SimTypes.Intent.new(), null, null, null])
		tuned.step([SimTypes.Intent.new(), null, null, null])
		built.drain_events()
		tuned.drain_events()
	eq(tuned.snapshot(), built.snapshot(), "3000 frames the same")
	eq(tuned.ai.slots[2].late_period, built.ai.slots[2].late_period)
	built.dispose()
	tuned.dispose()


func test_where_it_is() -> void:
	var v := _view()
	check(v.tuning != null and v.tuning.available(), "a match")
	check(v._hud.pause_menu.index_of("tune") >= 0, "TUNE on the pause menu")
	v.free()
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(SimTypes.MatchConfig.doubles(), "park", true)
	check(d.tuning == null, "not the demo")
	d.free()
	var o := MatchView.new()
	o.net = OnlineSession.new()
	runner.root.add_child(o)
	o.setup(SimTypes.MatchConfig.singles(), "park", false)
	check(not o.tuning.available() and o._hud.pause_menu.index_of("tune") < 0, "not online")
	o.tuning.toggle()
	check(not o.tuning.open)
	o.free()


## Open, the match waits; the sliders reach it live; closing swallows the
## press and keeps the settings.
func test_live() -> void:
	var k := _kept()
	var v := _view()
	for f in 120:
		v._physics_process(1.0 / 60.0)
	v.tuning.toggle()
	check(v.tuning.open)
	var frame := v.sim.frame_count
	for f in 60:
		v._physics_process(1.0 / 60.0)
	eq(v.sim.frame_count, frame, "the match waits")
	var page := v.tuning.page
	page.select("ball_speed")
	Settings.ball_speed = 90
	page.change(-1)
	eq(v.sim.config.ball_speed, 89, "BALL SPEED, live")
	var n := 0
	for i in Sim.BALL_CYCLE:
		n += int(v.sim.ball_pace[i])
	eq(n, Sim.ball_per_cycle(K.DIFFICULTY_MEDIUM, 89), "its pace")
	page.select("cpu_errors")
	Settings.cpu_errors = 50
	page.change(-1)
	eq(v.sim.config.cpu_errors, 45, "CPU ERRORS, 5% a step")
	page.select("ball_size")
	Settings.ball_size = 110
	page.change(1)
	eq(v._ball_sprite.scale, Vector2(1.11, 1.11), "BALL SIZE, live")
	eq(v.feel._ball_scale, Vector2(1.11, 1.11), "the squash follows it")
	page.select("close")
	page.press()
	check(not v.tuning.open and v.input_lock == MatchView.INPUT_LOCK_FRAMES, "closed, the press swallowed")
	v._physics_process(1.0 / 60.0)
	check(v.sim.frame_count > frame, "the match goes on")
	v.free()
	_restore(k)


## APPLY: the modifiers set here, the match from 0-0 with them, rebuilt in
## place; it plays; the old sim is let go.
func test_apply() -> void:
	var k := _kept()
	var v := _view()
	for f in 600:
		v._physics_process(1.0 / 60.0)
	var old := v.sim
	v.tuning.toggle()
	v.tuning._show("modifiers")
	v.tuning.page.select("wind")
	v.tuning.page.change(1)
	v.tuning._show("rules")
	v.tuning.page.select("win_by_2")
	v.tuning.page.change(1)
	check(v.tuning.pending())
	v.tuning._show("tune")
	v.tuning.page.select("apply")
	v.tuning.page.press()
	check(v.sim != old, "a new match")
	eq(v.sim.config.modifiers, K.MOD_WIND | K.MOD_WIN_BY_2, "with them")
	eq(v.sim.team_score, [0, 0], "from 0-0")
	check(v.wind_view != null, "WIND's streaks built")
	eq(Settings.mod_bits & (K.MOD_WIND | K.MOD_WIN_BY_2), K.MOD_WIND | K.MOD_WIN_BY_2, "kept for the next")
	check(v.tuning.open and not v.tuning.pending(), "the panel stays, nothing pending")
	v.tuning.close()
	var hits := 0
	for f in 1800:
		v._physics_process(1.0 / 60.0)
		for e in v.sim.events:
			hits += 1 if e[0] == K.EVENT_HIT else 0
	check(v.sim.frame_count > 1000, "it plays")
	check(v._hud.pause_menu.index_of("tune") >= 0, "and can be tuned again")
	v.free()
	_restore(k)


func test_from_the_pause_menu() -> void:
	var v := _view()
	v.sim.set_phase(K.PHASE_SERVE_SETUP)
	v.sim.paused = 1
	v._hud.pause_menu.select("tune")
	var it := SimTypes.Intent.new()
	it.hit_pressed = 1
	check(v.input.pause_input(it), "the frame is done")
	check(v.tuning.open, "TUNE opens it")
	v.tuning.back()
	check(not v.tuning.open, "back closes it")
	v.free()
