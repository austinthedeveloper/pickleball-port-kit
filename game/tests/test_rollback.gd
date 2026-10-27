## Rollback's core (port ADR-103, PORT-107): two sides over a line with
## latency and jitter, each predicting the other. Their confirmed sims are
## the match as it was really played, frame for frame; their predictions
## agree with it once nothing is guessed; events are counted exactly once
## and played at most once a step; time sync keeps a slow clock in step.
extends TestSuite

const FRAMES := 2400
const RETUNE_AT := 700               ## the host's TUNE command (frames it predicts)
const REMATCH_AT := 1500             ## ... and a NEW MATCH, so a command arrives late too


## A scripted player: moves held for a few frames, presses now and then.
static func _script(f: int, side: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	var r := (((f >> 2) + side * 7919) * 1103515245 + 12345) & 0x7fffffff
	it.move_x = ((r >> 8) % 3) - 1
	it.move_y = ((r >> 12) % 3) - 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	var p := ((f + side * 31) * 2654435761) & 0x7fffffff
	it.hit_pressed = 1 if (p >> 9) % 9 == 0 else 0
	it.hit_held = 1 if it.hit_pressed or (r >> 16) % 4 == 0 else 0
	it.shot = (p >> 13) % 3 if it.hit_pressed else 0
	return it


static func _cfg() -> SimTypes.MatchConfig:
	var c := SimTypes.MatchConfig.singles()
	c.human = [1, 0, 1, 0]
	c.points_to_win = 21
	return c


static func _host_cmds(f: int) -> Array:
	if f == RETUNE_AT:
		return [["retune", 90, 60]]
	if f == REMATCH_AT:
		return [["new_match"]]
	return []


## The match as both sides really played it, on one sim: frame F has each
## side's input from its frame F - delay, and the host's commands.
func _reference(delay: int, frames: int) -> Dictionary:
	var s := Sim.new(_cfg())
	var snaps := {}
	var events := {}
	for f in frames:
		var human: Array = [null, null, null, null]
		if f >= delay:
			human[0] = _script(f - delay, 0)
			human[2] = _script(f - delay, 1)
		else:
			human[0] = SimTypes.Intent.new()
			human[2] = SimTypes.Intent.new()
		s.step(human, _host_cmds(f - delay) if f >= delay else [])
		snaps[f] = str(s.snapshot()).hash()
		events[s.step_count] = s.drain_events()
	s.dispose()
	return {"snaps": snaps, "events": events}


## Two sides over a line: `slow` > 0 makes the guest's clock skip a tick
## every `slow` ticks.
func _play(latency: int, jitter: Array, delay: int, slow := 0) -> Dictionary:
	var links := LoopbackLink.pair(latency, jitter)
	var rb := [Rollback.new(_cfg(), 0, 2, delay), Rollback.new(_cfg(), 2, 0, delay)]
	var ledgers := [EventLedger.new(), EventLedger.new()]
	var played := [{}, {}]                   # step -> events played
	var counted := [{}, {}]                  # step -> events counted
	var truth_snaps := [{}, {}]              # frame -> the confirmed sim's snapshot hash
	var pred_snaps := [{}, {}]               # frame -> the prediction's, when nothing's guessed
	var max_lead := 0
	for t in FRAMES + 40:
		for side in 2:
			if side == 1 and slow > 0 and t % slow == 0:
				continue
			var l: LoopbackLink = links[side]
			var r: Rollback = rb[side]
			l.poll()
			for m in l.receive():
				r.on_message(m)
			var f := r.predicted
			if f >= FRAMES:
				continue
			var was := r.confirmed
			var out := r.tick(_script(f, side), _host_cmds(f) if side == 0 else [])
			for m in out["send"]:
				l.send(m)
			for p: Array in out["played"]:
				var got: Array = played[side].get(p[0], [])
				got.append_array(ledgers[side].run(p[0], p[1]))
				played[side][p[0]] = got
			for c: Array in out["counted"]:
				counted[side][c[0]] = c[1]
			if r.confirmed > was:
				truth_snaps[side][r.confirmed - 1] = str(r.truth.snapshot()).hash()
			if out["stepped"] and r.guessing() == 0:
				pred_snaps[side][r.predicted - 1] = str(r.pred.snapshot()).hash()
			if t > 300:
				max_lead = maxi(max_lead, absi(rb[0].predicted - rb[1].predicted))
	# the end: no more frames, what's in flight arrives and is confirmed
	for t in 40:
		for side in 2:
			links[side].poll()
			for m in links[side].receive():
				rb[side].on_message(m)
			var out: Dictionary = rb[side].catch_up()
			for m in out["send"]:
				links[side].send(m)
			for p: Array in out["played"]:
				var got: Array = played[side].get(p[0], [])
				got.append_array(ledgers[side].run(p[0], p[1]))
				played[side][p[0]] = got
			for c: Array in out["counted"]:
				counted[side][c[0]] = c[1]
	return {"rb": rb, "played": played, "counted": counted, "truth": truth_snaps,
		"pred": pred_snaps, "max_lead": max_lead}


func _check(name: String, got: Dictionary, ref: Dictionary) -> void:
	for side in 2:
		var r: Rollback = got["rb"][side]
		var who := "%s, %s" % [name, ["host", "guest"][side]]
		check(r.desync < 0, "%s: no desync" % who)
		eq([r.confirmed, r.predicted], [FRAMES, FRAMES], "%s: everything confirmed at the end" % who)
		eq(r.pred.state_hash(), r.truth.state_hash(), "%s: the prediction is the confirmed match" % who)
		eq(str(r.truth.snapshot()).hash(), ref["snaps"][FRAMES - 1], "%s: which is the real match" % who)
		var bad := 0
		for f: int in got["truth"][side]:
			bad += int(got["truth"][side][f] != ref["snaps"][f])
		eq(bad, 0, "%s: confirmed frames unlike the real match (of %d)" % [who, got["truth"][side].size()])
		bad = 0
		for f: int in got["pred"][side]:
			bad += int(got["pred"][side][f] != ref["snaps"][f])
		eq(bad, 0, "%s: unguessed predictions unlike the real match (of %d)" % [who, got["pred"][side].size()])
		var wrong := 0
		var missed := 0
		var twice := 0
		for step: int in got["counted"][side]:
			var real: Array = ref["events"][step]
			wrong += int(got["counted"][side][step] != real)
			var p: Array = got["played"][side].get(step, [])
			for e in real:
				missed += int(p.count(e) < real.count(e))
			for e in p:
				twice += int(p.count(e) > maxi(1, real.count(e)))
		eq(wrong, 0, "%s: steps counted with other events than the real match's" % who)
		eq(missed, 0, "%s: real events never played" % who)
		eq(twice, 0, "%s: events played twice for a step" % who)
		r.dispose()


func test_a_quick_line_never_guesses_wrong() -> void:
	var ref := _reference(Rollback.DELAY_LAN, FRAMES)
	var got := _play(0, [], Rollback.DELAY_LAN)
	_check("no latency", got, ref)
	for side in 2:
		var r: Rollback = got["rb"][side]
		eq(r.corrections, 0, "nothing to correct")
		eq(r.stalls, 0, "never waits")


func test_latency_is_predicted_and_corrected() -> void:
	var ref := _reference(Rollback.DELAY, FRAMES)
	var got := _play(4, [], Rollback.DELAY)
	var rb: Array = got["rb"]
	var corrections: Array = [rb[0].corrections, rb[1].corrections]
	var stalls: Array = [rb[0].stalls, rb[1].stalls]
	_check("4 frames", got, ref)
	check(corrections[0] > 0 and corrections[1] > 0, "wrong guesses, corrected (%s)" % str(corrections))
	eq(stalls, [0, 0], "inside the window: never waits")


func test_a_jittery_line_stays_exact() -> void:
	var ref := _reference(Rollback.DELAY, FRAMES)
	var got := _play(6, [0, 3, 1, 0, 2], Rollback.DELAY)
	var rb: Array = got["rb"]
	var stalls: int = rb[0].stalls + rb[1].stalls
	_check("6 frames and jitter", got, ref)
	check(stalls < FRAMES / 50, "hardly waits (%d ticks)" % stalls)


## The guest's clock runs a tick slow in every 150: time sync holds the
## host now and then, so the two stay within a few frames and the host
## doesn't run into the window.
func test_time_sync_keeps_a_slow_clock_in_step() -> void:
	var ref := _reference(Rollback.DELAY, FRAMES)
	var got := _play(3, [], Rollback.DELAY, 150)
	var rb: Array = got["rb"]
	var holds: int = rb[0].holds
	var stalls: int = rb[0].stalls
	var lead: int = got["max_lead"]
	_check("a slow clock", got, ref)
	check(holds > 0, "the host held for it (%d frames)" % holds)
	check(stalls < 10, "and seldom met the window (%d ticks)" % stalls)
	check(lead <= 6, "the two stayed within %d frames" % lead)


func test_a_guess_repeats_held_state_not_presses() -> void:
	var it := SimTypes.Intent.new()
	it.move_x = 1
	it.aim_y = -1
	it.hit_held = 1
	it.hit_pressed = 1
	it.shot = K.SHOT_DRIVE
	it.pause_pressed = 1
	it.short_held = 1
	var g := Lockstep.unpack(Rollback.guess(Lockstep.pack(it)))
	eq([g.move_x, g.aim_y, g.hit_held, g.short_held], [1, -1, 1, 1], "held: repeated")
	eq([g.hit_pressed, g.pause_pressed], [0, 0], "pressed: never")
	eq(Rollback.guess(0), 0, "nothing known: nothing guessed")


## Each sim has its own config: a command run on a guess (TUNE's retune
## writes the config) mustn't reach the confirmed sim before it's confirmed.
func test_the_two_sims_share_nothing() -> void:
	var r := Rollback.new(_cfg())
	check(r.pred.config != r.truth.config, "two configs")
	r.pred.apply(["retune", 70, 10])
	eq([r.truth.config.ball_speed, r.truth.config.cpu_errors], [100, 100], "the confirmed sim's untouched")
	r.pred.load_state(r.truth.save_state())
	check(r.pred.config != r.truth.config, "still two after a correction")
	r.dispose()


func test_the_delay_fits_the_line() -> void:
	eq(Rollback.for_rtt(8), Rollback.DELAY_LAN, "a LAN")
	eq(Rollback.for_rtt(60), Rollback.DELAY, "the internet")
