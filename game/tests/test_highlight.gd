## PLAY OF THE MATCH (PORT-51, ADR-075): a match's longest rally, replayed
## when it ends by running a second sim through the recorded inputs. The
## replay is exact (through a RESTART and the tuning panel's retune), the
## live match is untouched, and the result follows.
extends TestSuite


func _view(points := 5) -> MatchView:
	return match_view(Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, points))


## Frames until the match ends (a bot for P1, who serves on its own).
func _play_out(v: MatchView, limit := 60 * 60 * 10) -> bool:
	for f in limit:
		v._physics_process(1.0 / 60.0)
		if v.sim.phase == K.PHASE_MATCH_RESULT or (v.highlight and v.highlight.playing()):
			return true
	return false


## Through the highlight; the replay's snapshot where the rally ended.
func _watch(v: MatchView) -> Array:
	var h := v.highlight
	var at_end: Array = []
	for f in 20000:
		if not h.playing():
			break
		if h.replay and h._frame == int(h.best["to"]) + 1 and at_end.is_empty():
			at_end = h.replay.snapshot()
		v._physics_process(1.0 / 60.0)
	return at_end


func test_where_it_is() -> void:
	var v := _view()
	check(v.highlight != null, "a match")
	v.free()
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(SimTypes.MatchConfig.doubles(), "park", true)
	check(d.highlight == null, "not the demo")
	d.free()
	var cfg := SimTypes.MatchConfig.singles()
	cfg.modifiers = K.MOD_MULTI_BALL
	var m := MatchView.new()
	runner.root.add_child(m)
	m.setup(cfg, "park", false)
	check(m.highlight == null, "not MULTI BALL")
	m.free()
	var p := MatchView.new()
	runner.root.add_child(p)
	p.setup(SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0), "park", false)
	check(p.highlight == null, "not practice")
	p.free()


## A match to its end: the longest rally plays back, exactly, then the
## result; the live sim never moves while it does.
func test_a_match() -> void:
	var v := _view()
	check(_play_out(v), "the match ends")
	var h := v.highlight
	check(not h.best.is_empty(), "a rally worth showing (%d shots)" % int(h.best.get("shots", 0)))
	check(h.playing(), "PLAY OF THE MATCH")
	var live := v.sim
	var live_snap := live.snapshot()
	var at_end := _watch(v)
	eq(at_end, h.best["snap_to"], "the replay is the rally, exactly")
	check(not h.playing() and v.sim == live, "back to the match")
	eq(live.snapshot(), live_snap, "which never moved")
	eq(v.sim.phase, K.PHASE_MATCH_RESULT, "on its result")
	check(h.overlay == null and h.replay == null, "the replay let go")
	v.free()


## A RESTART and a retune mid-match are replayed too.
func test_through_restart_and_retune() -> void:
	var k := [Settings.ball_speed, Settings.cpu_errors]
	var v := _view()
	for f in 900:
		v._physics_process(1.0 / 60.0)
	v.highlight.op(["new_match"])
	v.sim.new_match()
	for f in 300:
		v._physics_process(1.0 / 60.0)
	Settings.ball_speed = 92
	Settings.cpu_errors = 30
	v.tuning._retune()
	check(_play_out(v), "the match ends")
	var h := v.highlight
	check(h.playing(), "PLAY OF THE MATCH (%d shots)" % int(h.best.get("shots", 0)))
	eq(_watch(v), h.best["snap_to"], "exact through both")
	v.free()
	Settings.ball_speed = k[0]
	Settings.cpu_errors = k[1]


## Skipping goes straight to the result; a short match with no long rally
## has none.
func test_skip_and_none() -> void:
	var v := _view()
	check(_play_out(v))
	var h := v.highlight
	v._physics_process(1.0 / 60.0)
	h._finish()
	check(not h.playing() and v.sim.phase == K.PHASE_MATCH_RESULT, "skipped to the result")
	v.free()
	var w := _view()
	w.highlight.best = {}
	w.sim.set_phase(K.PHASE_MATCH_RESULT)
	var called := []
	check(not w.highlight.start(func(): called.append(1)), "no rally, no replay")
	w.free()


func test_caption() -> void:
	var v := _view()
	v.highlight.best = {"shots": 14, "winner": 0, "fault": K.FAULT_OUT}
	eq(v.highlight.ending(), "POINT P1: THE LAST SHOT SAILED OUT")
	v.highlight.best["fault"] = K.FAULT_SECOND_BOUNCE
	v.highlight.best["winner"] = 1
	check(v.highlight.ending().ends_with(": NO ONE GOT TO IT"))
	v.free()


## The replayed players animate (the live match's end reaction, held by
## flair, isn't drawn over them), and the reaction is back after.
func test_players_move_in_the_replay() -> void:
	var v := _view()
	check(_play_out(v))
	var h := v.highlight
	var held := []
	for slot in K.MAX_PLAYERS:
		held.append(v.flair.body_frame(slot))
	var frames := {}
	for f in 20000:
		if not h.playing():
			break
		v._physics_process(1.0 / 60.0)
		if v.replaying():
			check(not v.flair.visible, "flair waits")
			check(not v._hud._rally.visible, "the RALLY sign is under the card: hidden")
			for slot in [0, 2]:
				if not frames.has(slot):
					frames[slot] = {}
				frames[slot][v.actors.frame_for(slot)] = true
	for slot in [0, 2]:
		check(frames.has(slot) and frames[slot].size() >= 4,
			"slot %d runs, swings, stands (%s)" % [slot, frames.get(slot, {}).keys()])
	check(v.flair.visible, "and back")
	var after := []
	for slot in K.MAX_PLAYERS:
		after.append(v.flair.body_frame(slot))
	eq(after, held, "the live reaction resumes")
	v.free()
