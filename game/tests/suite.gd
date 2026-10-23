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


## Saved replays (PORT-69) in a folder of the tests' own, emptied.
static func wipe_replays(dir := "user://test_replays/") -> void:
	SavedReplays.dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	SavedReplays._cached = false         # re-read on the next list()


## A save in its own folder, wiped and loaded fresh (each suite its own
## dir, so suites never see each other's).
static func fresh_save(dir: String) -> SaveGame:
	wipe_saves(dir)
	var s := SaveGame.new()
	s.dir = dir
	s.load_game()
	return s


## A match on screen, as a test drives one: no intro card, a bot for P1
## (it serves and plays as the CPUs do), in the runner's tree.
func match_view(cfg: SimTypes.MatchConfig, venue := "park", demo := false) -> MatchView:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, venue, demo)
	v.card_frames = -1
	v.sim.p1_bot = true
	return v


## A title screen on the runner's root, ready (the root isn't during the
## suites), on `save` if given.
func title_screen(save: SaveGame = null) -> TitleScreen:
	var t := TitleScreen.new()
	if save:
		t.save = save
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	return t


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
