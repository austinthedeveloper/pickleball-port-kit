## The tournament (PORT-25): an eight-entry knockout, you and seven ladder
## teams, three rounds (QUARTERFINAL, SEMIFINAL, FINAL), each of your
## matches at your opponent's home court. Pure and deterministic: the
## CPU-vs-CPU matches are decided from the tournament's seed, so a saved
## bracket replays the same.
##
## The draw is seeded by the ladder: you are the top seed (the home
## favourite), then the teams from the ladder's top down; the first rung
## (HENDERSON, the warm-up) sits it out. The bracket order is the usual
## 1-8, 4-5, 3-6, 2-7, so your road gets harder each round and the best
## teams meet late. A CPU match goes to the stronger team (the higher
## rung) more often the wider the gap, never always: upsets happen.
##
## The bracket is entries in order (`draw`), and per round its matches'
## results: [winner, winner's points, loser's points], or [] while
## unplayed. Your matches are recorded from the real match; the round's
## other matches are decided when you finish yours.
class_name Tournament
extends RefCounted

const SIZE := 8
const ROUNDS := 3
const ROUND_NAMES := ["QUARTERFINAL", "SEMIFINAL", "FINAL"]
const ROUND_SHORT := ["QF", "SEMI", "FINAL"]   ## where a row has little room
const YOU := -1
const SITS_OUT := 0                  ## the ladder's first rung, the warm-up
## The bracket's seed order: positions 0..7 hold seeds 1, 8, 4, 5, 3, 6, 2, 7.
const SEED_ORDER := [1, 8, 4, 5, 3, 6, 2, 7]

var seed := 1
var doubles := false
var difficulty := K.DIFFICULTY_MEDIUM
var points := 11
var draw: Array = []                 ## SIZE entries: a team index or YOU
var results: Array = []              ## per round, per match: [] or [winner, w_points, l_points]
var seen := 0                        ## decided matches the bracket has shown (it reveals the rest)
var _rng := 1


## A new tournament. `seed` decides the CPU matches.
static func create(seed_value: int, is_doubles: bool, diff: int, to_win: int) -> Tournament:
	var t := Tournament.new()
	t.seed = seed_value & 0x7fffffff
	t._rng = t.seed if t.seed else 1
	t.doubles = is_doubles
	t.difficulty = diff
	t.points = to_win
	var seeds := [YOU]                   # seed 1
	for i in range(Opponents.count() - 1, -1, -1):
		if i != SITS_OUT and seeds.size() < SIZE:
			seeds.append(i)
	for s in SEED_ORDER:
		t.draw.append(seeds[s - 1])
	for r in ROUNDS:
		var round := []
		for m in SIZE >> (r + 1):
			round.append([])
		t.results.append(round)
	return t


static func matches_in(round: int) -> int:
	return SIZE >> (round + 1)


## The two entries of a match, or null for a place not yet decided.
func entrants(round: int, m: int) -> Array:
	if round == 0:
		return [draw[2 * m], draw[2 * m + 1]]
	var a: Array = results[round - 1][2 * m]
	var b: Array = results[round - 1][2 * m + 1]
	return [a[0] if not a.is_empty() else null, b[0] if not b.is_empty() else null]


## Your next match: {round, match, opponent}, or {} if you're out or it's over.
func next_match() -> Dictionary:
	for r in ROUNDS:
		for m in matches_in(r):
			var e := entrants(r, m)
			if YOU in e and results[r][m].is_empty():
				return {"round": r, "match": m, "opponent": e[1] if e[0] == YOU else e[0]}
	return {}


## Your result, from the real match; then the round's other matches. If you
## lost, the rest of the tournament plays out.
func record(won: bool, your_points: int, their_points: int) -> void:
	var nm := next_match()
	if nm.is_empty():
		return
	var r: int = nm["round"]
	var w: int = YOU if won else int(nm["opponent"])
	results[r][nm["match"]] = [w, maxi(your_points, their_points), mini(your_points, their_points)]
	_decide_round(r)
	if not won:                          # the next round's CPU matches wait for yours
		for later in range(r + 1, ROUNDS):
			_decide_round(later)


func _decide_round(r: int) -> void:
	for m in matches_in(r):
		var e := entrants(r, m)
		if results[r][m].is_empty() and e[0] != null and e[1] != null and not (YOU in e):
			results[r][m] = _cpu_match(int(e[0]), int(e[1]))


## A CPU match: the higher rung wins 50% + 9% per rung apart, at most 90%;
## the loser's points come closer the closer the teams.
func _cpu_match(a: int, b: int) -> Array:
	var gap := absi(a - b)
	var favourite := maxi(a, b)
	var underdog := mini(a, b)
	var upset := _roll(100) >= mini(50 + 9 * gap, 90)
	var winner := underdog if upset else favourite
	var close := maxi(0, points - 2 - _roll(2 + gap * 2))
	return [winner, points, close]


func _roll(n: int) -> int:
	_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
	return (_rng >> 16) % n


func over() -> bool:
	return not results[ROUNDS - 1][0].is_empty()


func champion() -> Variant:
	return results[ROUNDS - 1][0][0] if over() else null


## You're out: you lost a match.
func knocked_out() -> bool:
	for r in ROUNDS:
		for m in matches_in(r):
			var res: Array = results[r][m]
			if not res.is_empty() and res[0] != YOU and YOU in entrants(r, m):
				return true
	return false


## How far you got, as words: CHAMPIONS, FINALIST, SEMIFINALIST,
## QUARTERFINALIST; "" while you're still in it.
func finish() -> String:
	if champion() == YOU:
		return "CHAMPIONS" if doubles else "CHAMPION"
	if not knocked_out():
		return ""
	for r in range(ROUNDS - 1, -1, -1):
		for m in matches_in(r):
			if YOU in entrants(r, m):
				return ["QUARTERFINALIST", "SEMIFINALIST", "FINALIST"][r]
	return ""


static func entry_name(e: Variant) -> String:
	if e == null:
		return ""
	if int(e) == YOU:
		return "YOU"
	return String(Opponents.team(int(e))["team"])


## The match config for your next match: Settings.config_for against the
## opponent with the tournament's mode, difficulty and points.
func match_config(p1: Dictionary, modifiers: int) -> SimTypes.MatchConfig:
	var nm := next_match()
	var cfg := Settings.config_for(doubles, int(nm.get("opponent", -1)), difficulty, points, p1)
	cfg.modifiers = modifiers
	return cfg


func to_dict() -> Dictionary:
	return {"seed": seed, "doubles": int(doubles), "difficulty": difficulty, "points": points,
		"draw": draw.duplicate(), "results": results.duplicate(true), "rng": _rng, "seen": seen}


static func from_dict(d: Dictionary) -> Tournament:
	if d.is_empty() or not d.has("draw"):
		return null
	var t := Tournament.new()
	t.seed = int(d["seed"])
	t.doubles = int(d["doubles"]) != 0
	t.difficulty = int(d["difficulty"])
	t.points = int(d["points"])
	for e in d["draw"]:
		t.draw.append(int(e))
	for round in d["results"]:
		var rr := []
		for res in round:
			var out := []
			for v in res:
				out.append(int(v))
			rr.append(out)
		t.results.append(rr)
	t._rng = int(d.get("rng", t.seed))
	t.seen = int(d.get("seen", 0))
	return t
