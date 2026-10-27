## Commands (port ADR-102): the changes to a match that aren't a pad's
## (NEW MATCH, TUNE's sliders, SMART PLAY) go to Sim.step with the inputs,
## so they travel with them: online, in a replay, through a rollback.
extends TestSuite


func _two(cfg: SimTypes.MatchConfig) -> Array:
	var out := []
	for i in 2:
		var s := Sim.new(cfg)
		s.p1_bot = true
		out.append(s)
	return out


## A command stepped is the call it names, made just before that step.
func test_a_command_is_the_call_it_names() -> void:
	var smarts := [90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90]
	for c: Array in [["new_match"], ["retune", 70, 30], ["smarts", smarts]]:
		var s := _two(SimTypes.MatchConfig.doubles())
		for f in 700:
			s[0].step()
			s[1].step()
		s[0].step([], [c])
		match c[0]:
			"new_match":
				s[1].new_match()
			"retune":
				s[1].retune(70, 30)
			"smarts":
				s[1].retune_smarts(smarts)
		s[1].step()
		for f in 600:
			s[0].step()
			s[1].step()
		eq(s[0].save_state(), s[1].save_state(), "%s: the same match" % c[0])
		s[0].dispose()
		s[1].dispose()


## A step taken back and run again with its command comes out the same
## (the command is part of the step, ADR-100's state before it).
func test_a_command_survives_a_rollback() -> void:
	var s: Sim = _two(SimTypes.MatchConfig.singles())[0]
	for f in 500:
		s.step()
	var before := s.save_state()
	s.step([], [["retune", 120, 0]])
	for f in 300:
		s.step()
	var ahead := s.save_state()
	s.load_state(before)
	s.step([], [["retune", 120, 0]])
	for f in 300:
		s.step()
	eq(s.save_state(), ahead, "run again, the same")
	s.dispose()


## Lockstep carries each side's commands with its input: both sides get
## them on the same frame, the host's first.
func test_lockstep_carries_commands() -> void:
	var links := LoopbackLink.pair(2)
	var ls := [Lockstep.new(0, 2, 5), Lockstep.new(2, 0, 5)]
	var got := [{}, {}]
	for f in 60:
		for side in 2:
			var l: LoopbackLink = links[side]
			l.poll()
			for m in l.receive():
				ls[side].on_message(m)
			if not ls[side].ready():
				continue
			var cmds := []
			if ls[side].frame == 10:
				cmds = [["new_match"]] if side == 0 else [["retune", 90, 20]]
			var out: Array = ls[side].advance(SimTypes.Intent.new(), cmds)
			l.send(out[0])
			if not out[2].is_empty():
				got[side][ls[side].frame - 1] = out[2]
	eq(got[0], {15: [["new_match"], ["retune", 90, 20]]}, "the host: both, on frame 10 + delay")
	eq(got[1], got[0], "the guest: the same frame, the same order")
