## Frame-budget gate (playbook rule 6): the sim's worst case, named, with
## headroom reported. Budget: the sim may use at most a quarter of a 60 Hz
## frame on its worst frame, leaving the rest for rendering.
extends TestSuite

const FRAME_US := 16667
const WORST_ALLOWED_US := FRAME_US / 4
const MEAN_ALLOWED_US := 500


func _measure(name: String, cfg: SimTypes.MatchConfig, frames: int) -> void:
	var sim := Sim.new(cfg)
	sim.start_attract()
	var worst := 0
	var total := 0
	for f in frames:
		var t := Time.get_ticks_usec()
		sim.step()
		var dt := Time.get_ticks_usec() - t
		sim.drain_events()
		total += dt
		worst = maxi(worst, dt)
	var mean := total / frames
	print("    %s: mean %d us, worst %d us (%.0f%% of the worst-frame budget)" % [name,
		mean, worst, 100.0 * worst / WORST_ALLOWED_US])
	check(worst < WORST_ALLOWED_US, "%s worst frame %d us" % [name, worst])
	check(mean < MEAN_ALLOWED_US, "%s mean %d us" % [name, mean])


func test_singles_budget() -> void:
	_measure("singles demo", SimTypes.MatchConfig.singles(), 6000)


## The worst case: four CPUs thinking, on a paced (KID) ball, whose swing
## lookahead steps per tick.
func test_doubles_kid_worst_case_budget() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.difficulty = K.DIFFICULTY_KID
	_measure("doubles KID (worst case)", cfg, 9000)
