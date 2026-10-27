## The confirmed sim (port ADR-103, stage 1): what's counted and what can't
## be taken back follows MatchView.truth, never the drawn sim. Offline
## they're one sim; here truth is made a second sim, as rollback's will
## be, so the two can differ.
extends TestSuite

const DT := 1.0 / 60.0


func _view() -> MatchView:
	var save := fresh_save("user://test_confirmed_sim/")
	var v := MatchView.new()
	v.save = save
	runner.root.add_child(v)
	v.setup(Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5), "park", false)
	v.card_frames = -1
	v.input_lock = 0
	return v


## A second sim for truth, the same match as the drawn one so far.
func _split(v: MatchView) -> Sim:
	var t := Sim.new(v.sim.config)
	t.load_state(v.sim.save_state())
	v.truth = t
	return t


## The point that wins `s` its match, played out to the result.
static func _win(s: Sim) -> void:
	s.team_score[0] = s.config.points_to_win - 1
	s.phase = K.PHASE_LIVE
	s.ball.rally_state = K.BALL_RALLY_LIVE
	s.resolve_point(1, K.FAULT_OUT)


static func _matches(v: MatchView) -> int:
	var r: Dictionary = v.save.data["records"]
	return int(r["singles_wins"]) + int(r["singles_losses"])


func test_offline_they_are_one_sim() -> void:
	var v := _view()
	check(v.truth == v.sim, "one sim")
	v.free()


## The drawn sim reaching its result ends nothing; the confirmed one does.
func test_the_match_ends_with_the_confirmed_sim() -> void:
	var v := _view()
	var t := _split(v)
	var before := _matches(v)
	_win(v.sim)
	for f in K.POINT_RESULT_FRAMES + 5:
		v._physics_process(DT)
	eq(v.sim.phase, K.PHASE_MATCH_RESULT, "the drawn match is over")
	eq(_matches(v), before, "but nothing is recorded: it isn't confirmed")
	_win(t)
	for f in K.POINT_RESULT_FRAMES + 5:
		t.step()
		v._physics_process(DT)
	eq(t.phase, K.PHASE_MATCH_RESULT)
	eq(_matches(v), before + 1, "confirmed: the match is recorded, once")
	for f in 30:
		t.step()
		v._physics_process(DT)
	eq(_matches(v), before + 1, "and only once")
	v.free()
	t.dispose()


## A counted point reads the confirmed score, not the drawn one.
func test_counting_reads_the_confirmed_sim() -> void:
	var v := _view()
	var t := _split(v)
	t.team_score = [3, 1]
	v.sim.team_score = [0, 4]
	v._count_event([K.EVENT_POINT, 100, 120, 0, 1])
	var fresh := MatchStats.new()
	fresh.on_event([K.EVENT_POINT, 100, 120, 0, 1])
	fresh.note_score([3, 1])
	eq(v.stats.behind, fresh.behind, "the confirmed sim's score")
	v.free()
	t.dispose()


## The rematch is the confirmed sim's to ask for.
func test_the_rematch_is_the_confirmed_sims() -> void:
	var v := _view()
	var t := _split(v)
	v.sim.rematch_requested = true
	v._physics_process(DT)
	check(not v._new_match_queued, "the drawn sim's rematch isn't asked for")
	t.rematch_requested = true
	v._physics_process(DT)
	check(v._new_match_queued, "the confirmed sim's is")
	v.free()
	t.dispose()
