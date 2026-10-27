## MatchView under rollback (port ADR-103, PORT-109): two views over a
## jittery line play a match. Each draws its prediction and counts its
## confirmed sim: every real event is played, none twice for a step; both
## count the same events; the match ends once on each; a correction at
## its worst fits in a frame.
extends TestSuite

const DT := 1.0 / 60.0
const ONLINE := preload("res://tests/test_online.gd")   # its scripted players


## A view that keeps what it played, counted, and ended.
class Recorder extends MatchView:
	var plays := []
	var counts := []
	var ends := 0

	func _on_event(e: Array) -> void:
		plays.append(e)
		super(e)

	func _count_event(e: Array) -> void:
		counts.append(e)
		super(e)

	func _match_over() -> void:
		ends += 1
		super()


func _sessions(latency: int, jitter: Array, points: int) -> Array:
	var links := LoopbackLink.pair(latency, jitter)
	var host := OnlineSession.new(links[0], true)
	var guest := OnlineSession.new(links[1], false)
	host.my_hello = OnlineSession.hello(PlayerSelect.new_choice(0, 0, 1), "ANN")
	guest.my_hello = OnlineSession.hello(PlayerSelect.new_choice(1, 1, 2), "BO")
	for i in 20:
		host.poll()
		guest.poll()
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, host.my_hello["look"], host.peer_hello["look"])
	cfg.points_to_win = points
	host.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": "park", "netcode": OnlineSession.ROLLBACK,
		"delay": Rollback.DELAY})
	for i in 20:
		guest.poll()
	return [host, guest]


func _view(session: OnlineSession, f: Array, seed: int) -> Recorder:
	var v := Recorder.new()
	v.net = session
	v.input.script_intent = func() -> SimTypes.Intent:
		var it: SimTypes.Intent = ONLINE._script(f[0], seed)
		if v.sim.phase == K.PHASE_SERVE_SETUP and f[0] % 40 == 0:
			it.hit_pressed = 1           # serve when it's yours
		return it
	runner.root.add_child(v)
	v.setup(OnlineSession.config_from_dict(session.start["cfg"]), "park", false)
	return v


func test_two_views_play_a_match_under_rollback() -> void:
	var s := _sessions(5, [0, 2, 1, 0], 7)
	eq([s[0].netcode(), s[1].netcode()], [OnlineSession.ROLLBACK, OnlineSession.ROLLBACK])
	var f := [0]
	var views: Array[Recorder] = [_view(s[0], f, 1), _view(s[1], f, 2)]
	check(views[0].sim == s[0].rollback.pred and views[0].truth == s[0].rollback.truth,
		"the view draws the prediction and counts the confirmed sim")
	check(views[0].sim != views[0].truth, "two sims")
	while f[0] < 6000 and (views[0].ends == 0 or views[1].ends == 0):
		for v in views:
			v._physics_process(DT)
		f[0] += 1
	for i in 120:                            # what's still in flight
		for v in views:
			v._physics_process(DT)
	var rb: Rollback = s[0].rollback
	check(rb.corrections > 0, "guesses corrected (%d)" % rb.corrections)
	eq([views[0].ends, views[1].ends], [1, 1], "the match ended once on each (frame %d)" % f[0])
	eq(views[0].truth.match_winner, views[1].truth.match_winner, "the same winner")
	var n := mini(views[0].counts.size(), views[1].counts.size())
	check(n > 20, "a match's events counted (%d)" % n)
	eq(views[0].counts.slice(0, n), views[1].counts.slice(0, n), "both counted the same events, step for step")
	for side in 2:
		var v: Recorder = views[side]
		var who: String = ["host", "guest"][side]
		var missed := 0
		var twice := 0
		for e in v.counts:
			missed += int(v.plays.count(e) < v.counts.count(e))
		for e in v.plays:
			twice += int(v.plays.count(e) > maxi(1, v.counts.count(e)))
		eq(missed, 0, "%s: counted events never played" % who)
		eq(twice, 0, "%s: events played twice for a step" % who)
		eq(v.stats.teams[0]["points"] + v.stats.teams[1]["points"], v.truth.team_score[0] + v.truth.team_score[1],
			"%s: the stats are the confirmed match's" % who)
	for v in views:
		v.free()
	for ses: OnlineSession in s:
		ses.quit()


## The worst a frame can cost under rollback: doubles, a full window of
## guesses to run again after a correction. Well inside a 16.6 ms frame
## (the bound is loose: machines and CI differ).
func test_a_worst_correction_fits_in_a_frame() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.human = [1, 0, 1, 0]
	var rb := Rollback.new(cfg)
	for i in 600:
		rb.truth.step()
	var t0 := Time.get_ticks_usec()
	for i in 20:
		rb.pred.load_state(rb.truth.save_state())
		for k in Rollback.WINDOW:
			rb.pred.step()
			rb.pred.drain_events()
	var ms := (Time.get_ticks_usec() - t0) / 20000.0
	check(ms < 8.0, "a full-window correction: %.2f ms" % ms)
	rb.dispose()
