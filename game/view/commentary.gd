## A match's commentary (PORT-52, ADR-076): what the announcer says, from
## what the view sees (the sim's events and phases), display only. The
## voice is the session's Announcer; this decides the lines: the match's
## introduction, a score call at each serve, an ace, the calls at 10, 15,
## 20, 25 and 30 shots, how each point ended, streaks, comebacks, match
## point, now and then a shot or a pun, the close call, PLAY OF THE MATCH
## and the result. COMMENTARY says how much: LIGHT the big moments,
## NORMAL the score and the points too, LOTS more of the rally.
class_name Commentary
extends RefCounted

const RALLY_CALLS := [10, 15, 20, 25, 30]
const SHOT_GAP := 1.6              ## seconds between two calls in a rally, at least
const SHORT := 1.3                 ## a call in a rally fits between shots
## Chances, by COMMENTARY (LIGHT, NORMAL, LOTS)
const SHOT_CHANCE := [0.0, 0.12, 0.3]
const SMASH_CHANCE := [0.0, 0.5, 0.8]
const POINT_CHANCE := [0.0, 0.55, 0.85]
const QUIP_CHANCE := [0.0, 0.12, 0.3]
const PAUSE_CHANCE := [0.0, 0.5, 1.0]

const FAULT_LINES := {K.FAULT_NET: "net", K.FAULT_KITCHEN: "kitchen", K.FAULT_WRONG_BOX: "wrong_box",
	K.FAULT_OUT: "out", K.FAULT_SECOND_BOUNCE: "two_bounces", K.FAULT_EARLY_VOLLEY: "early_volley",
	K.FAULT_LAVA: "lava", K.FAULT_MOMENTUM: "momentum", K.FAULT_DRIVE: "drive_banned"}
const MOD_LINES := [[K.MOD_SUDDEN_DEATH, "mod_sudden_death"], [K.MOD_MULTI_BALL, "mod_multi_ball"],
	[K.MOD_DINK_OR_DIE, "mod_dink_or_die"], [K.MOD_LAVA, "mod_lava"], [K.MOD_BIG_BALL, "mod_big_ball"],
	[K.MOD_FAST_BALL, "mod_fast_ball"], [K.MOD_GHOST_BALL, "mod_ghost_ball"], [K.MOD_POPCORN, "mod_popcorn"],
	[K.MOD_ICE, "mod_ice"], [K.MOD_GLOW, "mod_glow"], [K.MOD_INVERSE, "mod_inverse"],
	[K.MOD_MOON, "mod_moon"], [K.MOD_BOUNCY, "mod_bouncy"], [K.MOD_WIND, "mod_wind"],
	[K.MOD_SIDE_OUT, "mod_side_out"], [K.MOD_MOMENTUM, "mod_momentum"], [K.MOD_WIN_BY_2, "mod_win_by_2"]]

var view: MatchView
var rng := RandomNumberGenerator.new()
var heard: Array = []              ## families asked for and taken (for the tests)
var _intro: Array = []             ## the introduction's lines still to say
var _called := {}                  ## this rally's calls made (10, 15, ...)
var _since_call := 99.0
var _streak := [0, 0]              ## points in a row, by team
var _was_down := [0, 0]            ## the most each team has trailed by
var _mp_before := -1               ## the team that had match point before this point
var _server_before := -1
var _was_paused := false
var _deuces := 0                   ## times level past game point (WIN BY 2)


func _init(v: MatchView) -> void:
	view = v
	rng.randomize()


func _level() -> int:
	return clampi(Announcer.chatter, Announcer.LIGHT, Announcer.LOTS)


func _say(family: String, priority: int, wait := 0.0, max_len := 0.0) -> bool:
	var a := Announcer.current
	if a == null:
		return false
	var fam := family
	if max_len > 0.0:
		# only a line short enough (a rally's call lands between shots)
		var fits: Array = a.families.get(family, []).filter(func(id): return float(a.clips[id]) <= max_len)
		if fits.is_empty():
			return false
		var ok := a.say_ids([fits[rng.randi_range(0, fits.size() - 1)]], priority, wait)
		if ok:
			heard.append(family)
		return ok
	if a.families.has(fam) and a.say(fam, priority, wait):
		heard.append(family)
		return true
	if not a.families.has(fam) and a.clips.has(fam) and a.say_ids([fam], priority, wait):
		heard.append(family)             # one clip by its id (story_stakes_1)
		return true
	return false


func _chance(table: Array) -> bool:
	return rng.randf() < float(table[_level()])


# --- The match --------------------------------------------------------------------------

## As the match starts: the venue (a story chapter: its stakes), then the
## first modifier or the format. No team intros: the user found them too
## long (design/announcer/removed.txt).
func begin() -> void:
	var cfg := view.sim.config
	_intro = []
	if view.story_mode:
		_intro.append("story_stakes_1")
	elif _first(["venue_" + view.venue]) != "":
		_intro.append("venue_" + view.venue)  # (the GYM's is still to record: PORT-55)
	for m in MOD_LINES:
		if cfg.modifiers & int(m[0]):
			_intro.append(m[1])
			break
	if _intro.size() == 1:
		_intro.append("match_doubles" if cfg.mode == K.MODE_DOUBLES else "match_singles")
	_server_before = view.sim.serving_team


## Once a frame (the introduction waits for a free voice).
func tick(delta: float) -> void:
	_since_call += delta
	if not _intro.is_empty() and Announcer.current and not Announcer.current.busy():
		_say(_intro.pop_front(), Announcer.TOP)
	var paused := view.sim.paused != 0
	if paused != _was_paused:
		_was_paused = paused
		if _chance(PAUSE_CHANCE):
			_say("pause" if paused else "resume", Announcer.LOW)


func on_event(e: Array) -> void:
	var s := view.sim
	match int(e[0]):
		K.EVENT_SERVE:
			_called = {}
			_server_before = s.serving_team
		K.EVENT_HIT:
			_on_hit(e)
		K.EVENT_POINT:
			_on_point(int(e[3]))


func _on_hit(e: Array) -> void:
	var s := view.sim
	var shots: int = (s.shot_serial - s.rally_start) & 0xff
	for n in RALLY_CALLS:
		if shots >= n and not _called.has(n):
			_called[n] = true
			if n == shots and (n >= 15 or _level() >= Announcer.NORMAL):
				if _say("rally_%d" % n, Announcer.HIGH, 0.4, SHORT * 2):
					_since_call = 0.0
					return
	if _since_call < SHOT_GAP or Announcer.current == null or Announcer.current.busy():
		return
	var shot: int = int(e[3]) >> 4
	var fam := ""
	var chance := SHOT_CHANCE
	match shot:
		K.SHOT_DRIVE:
			fam = "shot_drive"
		K.SHOT_SLICE:
			fam = "shot_slice"
		K.SHOT_OVERHEAD:
			fam = "shot_smash"
			chance = SMASH_CHANCE
		K.SHOT_SOFT:
			fam = "shot_lob" if s.ball.vz_fp > 40 else "shot_dink"
		_:
			if s.contact_volley:
				fam = "shot_volley"
	if fam != "" and _chance(chance) and _say(fam, Announcer.LOW, 0.0, SHORT):
		_since_call = 0.0


## After a point: the one thing most worth saying about it.
func _on_point(winner: int) -> void:
	var s := view.sim
	var loser := 1 - winner
	var shots: int = (s.shot_serial - s.rally_start) & 0xff
	_streak[winner] += 1
	_streak[loser] = 0
	var diff: int = s.team_score[winner] - s.team_score[loser]
	_was_down[winner] = maxi(_was_down[winner], -diff + 1)
	var mp_before := _mp_before
	_mp_before = 0 if s.match_point(0) else (1 if s.match_point(1) else -1)
	if s.team_won(winner):
		return                             # the match's end has its own line
	var line := ""
	var pri := Announcer.MID
	if shots <= 1 and winner == _server_before and s.last_fault in [K.FAULT_SECOND_BOUNCE, K.FAULT_NONE]:
		line = "ace"
		pri = Announcer.HIGH
	elif _extended():
		# WIN BY 2, past game point: advantage or deuce (the second batch,
		# PORT-55; "win by two" until those are recorded)
		if diff == 0:
			_deuces += 1
			line = _first(["deuce_long" if _deuces >= 3 else "deuce", "win_by_2"])
		else:
			line = _first(["advantage_server" if winner == s.serving_team else "advantage_receiver",
				"win_by_2"])
		pri = Announcer.HIGH
	elif mp_before == loser:
		line = "match_point_saved"
		pri = Announcer.HIGH
	elif _mp_before >= 0:
		line = "sudden_death" if s.config.modifiers & K.MOD_SUDDEN_DEATH else "match_point"
		pri = Announcer.HIGH
	elif diff == 0 and _was_down[winner] >= 3:
		line = "comeback"
		pri = Announcer.HIGH
		_was_down[winner] = 0
	elif _streak[winner] in [3, 5] and _level() >= Announcer.NORMAL:
		line = "streak_%d" % _streak[winner]
	elif _chance(POINT_CHANCE):
		line = FAULT_LINES.get(s.last_fault, "winner")
		if line == "out" and view.close_call:
			line = ""                      # the close call says it
	elif _chance(QUIP_CHANCE):
		line = "quip"
		pri = Announcer.LOW
	if line != "":
		_say(line, pri, 0.3)
	if s.side_out_doubles() and s.serving_team != _server_before and _level() >= Announcer.NORMAL:
		_say("side_out", Announcer.MID, 1.0)


## WIN BY 2 and both sides at game point or past it: the extension.
func _extended() -> bool:
	var s := view.sim
	return s.config.modifiers & K.MOD_WIN_BY_2 != 0 and not (s.config.modifiers & K.MOD_SUDDEN_DEATH) \
		and mini(s.team_score[0], s.team_score[1]) >= s.config.points_to_win - 1


## The first of these lines the announcer has (a later batch may not be
## recorded yet).
func _first(families: Array) -> String:
	var a := Announcer.current
	for f in families:
		if a and (a.families.has(f) or a.clips.has(f)):
			return f
	return ""


## A phase begins: a serve's setup calls the score.
func on_phase(now: int) -> void:
	if now == K.PHASE_SERVE_SETUP and _level() >= Announcer.NORMAL and _intro.is_empty():
		var ids := score_call()
		if not ids.is_empty() and Announcer.current and Announcer.current.say_ids(ids, Announcer.MID, 1.5):
			heard.append("score")


## The score as the server calls it: theirs first, then the other side's,
## then (side-out doubles) which server; a tie is "five all".
func score_call() -> Array:
	var s := view.sim
	var srv: int = s.serving_team
	var a: int = s.team_score[srv]
	var b: int = s.team_score[1 - srv]
	if a > 25 or b > 25:
		return []
	if s.side_out_doubles():
		return ["num_%02d_up" % a, "num_%02d_up" % b, "num_%02d_down" % s.server_number]
	if a == b:
		return ["num_%02d_up" % a, "score_all"]
	return ["num_%02d_up" % a, "num_%02d_down" % b]


func on_close_call() -> void:
	_say("close_call", Announcer.HIGH, 0.5)


func on_highlight() -> void:
	_say("potm", Announcer.TOP)


## The match is over: who won and how (the player's side, when there is one).
func on_match_over() -> void:
	var s := view.sim
	var w: int = s.match_winner
	var lose: int = s.team_score[1 - w]
	var mine := view.my_team() if not view.multiplayer() else w
	_intro = []
	if view.story_mode and w == mine:
		# the save moves on after this (main's StoryMode.win): the last
		# chapter is the one being played
		var last := view.save != null and StoryMode.current(view.save) == StoryMode.CHAPTERS - 1
		_say("story_saved" if last else "story_stakes_2", Announcer.TOP)
	elif view.cleared:
		_say("ladder_cleared", Announcer.TOP)
	elif w != mine:
		_say("match_loss", Announcer.TOP)
	elif lose == 0:
		_say("match_win_shutout", Announcer.TOP)
	elif s.team_score[w] - lose <= 2 and s.team_score[w] > s.config.points_to_win:
		_say("match_win_close", Announcer.TOP)
	else:
		_say("match_win", Announcer.TOP)


func on_rematch() -> void:
	_streak = [0, 0]
	_deuces = 0
	_was_down = [0, 0]
	_mp_before = -1
	_say("rematch", Announcer.TOP)
	_server_before = view.sim.serving_team
