## Base for test suites: assertions report to the runner and keep going.
class_name TestSuite
extends RefCounted

var runner
var asserts := 0


## A save folder, made if missing, with no save files in it.
static func wipe_saves(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f in SaveGame.FILES:
		if FileAccess.file_exists(dir + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))


## A save in its own folder, wiped and loaded fresh (each suite its own
## dir, so suites never see each other's).
static func fresh_save(dir: String) -> SaveGame:
	wipe_saves(dir)
	var s := SaveGame.new()
	s.dir = dir
	s.load_game()
	return s


func check(cond: bool, msg: String = "check failed") -> bool:
	asserts += 1
	if not cond:
		runner.fail(msg)
	return cond


func eq(actual, expected, msg: String = "") -> bool:
	asserts += 1
	if actual != expected:
		runner.fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])
		return false
	return true


## Runs the sim until `cond` is true or `limit` frames pass; returns frames.
func run_until(sim: Sim, cond: Callable, limit: int = 20000, human: Array = []) -> int:
	for i in limit:
		if cond.call():
			return i
		sim.step(human)
	return -1
