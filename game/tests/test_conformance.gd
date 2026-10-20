## The SNES repo's conformance traces (SNES ADR-068, 069; docs/TUNING.md
## there), replayed (PORT-35): each scenario plays from a new match with
## P1 the stats bot and the CPUs on main.c's schedule, as
## tools/conformance.c does, and every frame's line (the intents each
## active slot played, then the game, ball and players after the step) is
## compared with the C's. game/tools/conformance_import.sh brings the
## traces in (as a hash per line); the first frame that differs is where
## the port went wrong.
##
## The port's remaster-only rules are off here (MatchConfig.overhead): the
## traces are the ROM's.
extends TestSuite

const DIR := "res://tests/conformance/"
const FULL := "res://tests/conformance/full/"
const FRAMES := 5400

## name: [doubles, opponent (-1 none), difficulty, modifiers, bot late]
const SCENARIOS := {
	"singles": [false, 3, K.DIFFICULTY_MEDIUM, 0, 4],
	"doubles": [true, 6, K.DIFFICULTY_MEDIUM, 0, 4],
	"kid": [false, -1, K.DIFFICULTY_KID, 0, 5],
	"modifiers": [false, 5, K.DIFFICULTY_HARD,
		K.MOD_BIG_BALL | K.MOD_FAST_BALL | K.MOD_LAVA | K.MOD_POPCORN | K.MOD_ICE, 3],
}


static func config(s: Array) -> SimTypes.MatchConfig:
	var cfg := Settings.config_for(s[0], s[1], s[2], K.POINTS_TO_WIN)
	if s[1] < 0:
		cfg = SimTypes.MatchConfig.doubles() if s[0] else SimTypes.MatchConfig.singles()
		cfg.difficulty = s[2]
	cfg.modifiers = s[3]
	cfg.overhead = 0
	cfg.ball_speed = 100            # the ROM's ball (ADR-071, 072)
	return cfg


## One frame's line, as tools/conformance.c print_frame writes it.
static func line(frame: int, sim: Sim) -> String:
	var b := sim.ball
	var out := "%d G %d %d %d %d %d %d %d B %d %d %d %d %d %d %d %d %d" % [frame,
		sim.phase, sim.phase_timer, sim.team_score[0], sim.team_score[1],
		sim.serving_team, sim.server_index, sim.hit_stop,
		b.active, b.x_fp, b.y_fp, b.z_fp, b.vx_fp, b.vy_fp, b.vz_fp, b.bounce_count, b.last_hitter]
	for slot in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[slot]
		var i: SimTypes.Intent = sim.intents[slot]
		if not p.active:
			continue
		out += " I%d %d %d %d %d %d %d %d P%d %d %d %d %d %d %d %d" % [slot,
			i.move_x, i.move_y, i.aim_x, i.aim_y, i.hit_pressed, i.shot, i.hit_held,
			slot, p.x_fp, p.y_fp, p.vx_fp, p.vy_fp, p.state, p.state_frames_remaining, p.shot_type]
	return out


static func start(s: Array) -> Sim:
	var sim := Sim.new(config(s))
	sim.p1_bot = true
	sim.set_bot_skill(s[4], 0)
	return sim


## Plays a scenario; calls `each(frame, line)` per frame until it returns
## false. Returns the frames played.
static func play(s: Array, each: Callable) -> int:
	var sim := start(s)
	for frame in FRAMES:
		var it := SimTypes.Intent.new()
		if sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0 and (frame & 31) == 0:
			it.hit_pressed = 1
		if sim.phase == K.PHASE_MATCH_RESULT and (frame & 63) == 0:
			it.hit_pressed = 1
		sim.step([it, null, null, null])
		sim.drain_events()
		# game_update_match_result: a ladder win moves on after the frame
		# (start() again); any other rematch is game_new_match within it.
		var next_opponent: bool = sim.rematch_requested and s[1] >= 0 and sim.match_winner == 0
		if sim.rematch_requested and not next_opponent:
			sim.new_match()
		if not each.call(frame, line(frame, sim)):
			sim.dispose()
			return frame + 1
		if next_opponent:
			sim.dispose()
			sim = start(s)
	sim.dispose()
	return FRAMES


static func expected(name: String) -> Array:
	var out := []
	for l in FileAccess.get_file_as_string(DIR + name + ".hashes").split("\n"):
		if l != "" and not l.begins_with("#"):
			out.append(l)
	return out


static func c_line(name: String, frame: int) -> String:
	var path := FULL + name + ".trace"
	if not FileAccess.file_exists(path):
		return "(KEEP=1 game/tools/conformance_import.sh keeps the C's lines)"
	var n := 0
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.begins_with("#") or l == "":
			continue
		if n == frame:
			return l
		n += 1
	return "?"


func _check(name: String) -> void:
	var want := expected(name)
	eq(want.size(), FRAMES, "%s: the imported trace" % name)
	var bad := [-1, ""]
	var played := play(SCENARIOS[name], func(frame: int, l: String) -> bool:
		if l.md5_text().left(12) != want[frame]:
			bad[0] = frame
			bad[1] = l
			return false
		return true)
	if bad[0] >= 0:
		runner.fail("%s: differs from the ROM at frame %d\n      port: %s\n      C:    %s" % [
			name, bad[0], bad[1], c_line(name, bad[0])])
	else:
		eq(played, FRAMES, "%s: every frame the ROM's" % name)


## The imported traces are the TUNING_VERSION the port says it matches:
## a newer import fails here until the port catches up (and says so).
func test_tuning_version() -> void:
	for name in SCENARIOS:
		var head := FileAccess.get_file_as_string(DIR + name + ".hashes").split("\n")
		var v := -1
		for l in head:
			if l.begins_with("# tuning version "):
				v = int(l.split(" ")[3].trim_suffix(","))
		eq(v, K.TUNING_VERSION, "%s: traces at the port's TUNING_VERSION" % name)


func test_singles() -> void:
	_check("singles")


func test_doubles() -> void:
	_check("doubles")


func test_kid() -> void:
	_check("kid")


func test_modifiers() -> void:
	_check("modifiers")
