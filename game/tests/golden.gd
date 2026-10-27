## Golden traces: per-frame hashes of the full traced sim state over
## scripted runs. Any change to play changes a hash; display-only work
## never does (playbook rule 1).
##
## Regenerate (only for an intended change to play, with a reason in the
## commit): godot --headless --path game -s res://tests/golden.gd
class_name Golden
extends SceneTree

const DIR := "res://tests/golden/"
const SCENARIOS := ["singles_demo", "doubles_demo", "bot_vs_cpu"]


static func make_sim(scenario: String) -> Sim:
	match scenario:
		"singles_demo":
			var s := Sim.new()
			s.start_attract()
			return s
		"doubles_demo":
			var d := Sim.new(SimTypes.MatchConfig.doubles())
			d.start_attract()
			return d
		_:
			var b := Sim.new()
			b.p1_bot = true
			return b


## Frame hashes for a scenario: [frames..., final snapshot string].
static func run(scenario: String, frames: int = 9000) -> PackedStringArray:
	var sim := make_sim(scenario)
	var out := PackedStringArray()
	for f in frames:
		var human := []
		if scenario == "bot_vs_cpu":
			sim.set_bot_skill(4, 3)
			var it := SimTypes.Intent.new()
			it.hit_pressed = 1 if ((sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0
				and (f & 31) == 0) or (sim.phase == K.PHASE_MATCH_RESULT and (f & 63) == 0)) else 0
			human = [it, null, null, null]
			if sim.rematch_requested:
				sim.new_match()
		sim.step(human)
		var snap := sim.snapshot()
		var events := []
		for e: Array in sim.drain_events():
			events.append(e.slice(0, 4))     # the play, without its step (port ADR-101)
		out.append("%d %08x %s" % [f, str(snap).hash(), str(events) if events.size() else ""])
	out.append(str(sim.snapshot()))
	return out


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for sc in SCENARIOS:
		var lines := run(sc)
		var f := FileAccess.open(DIR + sc + ".txt", FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		print("wrote ", sc, " (", lines.size() - 1, " frames)")
	quit()
