## The sim's events by step (port ADR-101): a step run again (a rollback)
## plays only what it didn't play before, and only a confirmed step's last
## run is counted, so a guess taken back is never counted.
extends TestSuite

const HIT := [K.EVENT_HIT, 100, 130, 0, 5]
const BOUNCE := [K.EVENT_BOUNCE, 200, 120, 1, 5]
const POINT := [K.EVENT_POINT, 220, 120, 0, 5]


func test_a_step_run_again_plays_only_whats_new() -> void:
	var l := EventLedger.new(4)
	eq(l.run(5, [HIT, BOUNCE], "first"), [HIT, BOUNCE], "the first run plays everything")
	eq(l.run(5, [HIT, POINT], "again"), [POINT], "run again: only the new event")
	eq(l.run(5, [HIT, BOUNCE], "third"), [], "the bounce came back: it played already")
	eq(l.confirm(5), [[HIT, "third"], [BOUNCE, "third"]], "counted: the last run, its context")
	eq(l.confirm(5), [], "counted once")
	eq(l.run(5, [HIT], null), [], "a confirmed step can't run again")


func test_an_event_made_twice_plays_twice() -> void:
	var l := EventLedger.new()
	eq(l.run(1, [HIT, HIT]), [HIT, HIT])
	eq(l.run(1, [HIT, HIT, HIT]), [HIT], "the third copy")


func test_steps_confirm_in_order() -> void:
	var l := EventLedger.new()
	l.run(1, [HIT], 1)
	l.run(2, [], 2)
	l.run(3, [BOUNCE], 3)
	eq(l.confirm(2), [[HIT, 1]], "through step 2")
	l.run(3, [POINT], 3)
	eq(l.confirm(3), [[POINT, 3]], "step 3's last run")


## A scripted 2P input for slot 2: the real one, which the other machine
## only learns WINDOW frames late.
static func _real(f: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	var r := ((f >> 3) * 1103515245 + 4321) & 0x7fffffff     # a move held 8 frames
	it.move_x = ((r >> 8) % 3) - 1
	it.move_y = ((r >> 12) % 3) - 1
	it.hit_pressed = 1 if (r >> 16) % 5 == 0 else 0
	it.hit_held = it.hit_pressed
	it.shot = (r >> 20) % 3 if it.hit_pressed else 0
	return it


static func _guess(f: int) -> SimTypes.Intent:
	var it := _real(f)
	it.move_x = -it.move_x
	it.move_y = -it.move_y
	it.hit_pressed = 0
	it.hit_held = 0
	return it


static func _sim() -> Sim:
	var cfg := SimTypes.MatchConfig.singles()
	cfg.human = [1, 0, 1, 0]
	cfg.difficulty = K.DIFFICULTY_KID       # the sim swings for slot 2 when it can
	cfg.points_to_win = 21
	var s := Sim.new(cfg)
	s.p1_bot = true
	return s


## A naive rollback: every frame, back to the last confirmed state and run
## to the present again, the real input where it's known and a guess where
## it isn't: a bad one (the other way, no swing), so guesses go wrong. What's counted is exactly the straight run's
## events; nothing real is missed, and no event plays twice for a step.
func test_a_rollback_counts_the_real_events_and_plays_each_once() -> void:
	const WINDOW := 12
	const FRAMES := 3000
	var straight := _sim()
	var real := {}                          # step -> events
	var real_all := []
	for f in range(1, FRAMES + 1):
		straight.step([null, null, _real(f), null])
		var ev := straight.drain_events()
		real[f] = ev
		real_all.append_array(ev)
	straight.dispose()

	var s := _sim()
	var l := EventLedger.new(s.step_count)
	var base := s.save_state()              # after the last confirmed step
	var played := {}                         # step -> events played
	var counted := []
	for present in range(1, FRAMES + 1):
		var known := present - WINDOW           # the real input is here up to this step
		s.load_state(base)
		for f in range(l.confirmed + 1, present + 1):
			var it := _real(f) if f <= known else _guess(f)
			s.step([null, null, it, null])
			eq(s.step_count, f, "the stamp is the step")
			var fresh := l.run(f, s.drain_events(), f)
			var p: Array = played.get(f, [])
			p.append_array(fresh)
			played[f] = p
			if f == known:
				base = s.save_state()
		if known >= 1:
			for c: Array in l.confirm(known):
				counted.append(c[0])
	for c: Array in l.confirm(FRAMES - WINDOW):
		counted.append(c[0])
	var in_window := 0
	for f in range(FRAMES - WINDOW + 1, FRAMES + 1):
		in_window += real[f].size()
	eq(counted, real_all.slice(0, real_all.size() - in_window), "counted: the real events, in order")
	var taken_back := 0
	for f: int in real:
		var p: Array = played.get(f, [])
		for e in real[f]:
			check(p.count(e) >= real[f].count(e), "step %d: a real event played" % f)
		for e in p:
			check(p.count(e) <= maxi(1, real[f].count(e)), "step %d: %s played twice" % [f, str(e)])
			if not e in real[f]:
				taken_back += 1
	check(taken_back > 0, "some guesses made events that were taken back (%d)" % taken_back)
	check(counted.size() > 30, "a real match's worth of events (%d)" % counted.size())
	s.dispose()


## Offline, a step is confirmed as it runs: the view's stats are a bare
## sim's events counted as they come.
func test_offline_counts_each_step_as_it_runs() -> void:
	var v := match_view(SimTypes.MatchConfig.singles())
	v.input_lock = 0
	var bare := Sim.new(SimTypes.MatchConfig.singles())
	bare.p1_bot = true
	var stats := MatchStats.new()
	for f in 2500:
		v._physics_process(1.0 / 60.0)
		bare.step()
		for e in bare.drain_events():
			stats.on_event(e)
			if e[0] == K.EVENT_POINT:
				stats.note_score(bare.team_score)
		if v.sim.phase == K.PHASE_MATCH_RESULT:
			break
	eq(v.ledger.confirmed, v.sim.step_count, "every step run is confirmed")
	eq(v.stats.teams, stats.teams, "the same stats")
	eq(v.stats.longest_rally(), stats.longest_rally())
	check(stats.longest_rally() > 0, "a rally was played")
	v.queue_free()
	bare.dispose()
