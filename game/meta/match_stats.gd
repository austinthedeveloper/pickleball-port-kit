## Post-match stats (PORT-13), collected from the sim's events: display
## only, nothing here reaches the sim. Per team:
##   points, serve points played and won, aces (an unreturned serve),
##   winners (the other side never returned it) by the winning shot's
##   type, errors (a fault: out, net, kitchen...) by kind, shots, drives,
##   smashes (the overhead, ADR-053);
## and every rally's length (shots, the serve included).
class_name MatchStats
extends RefCounted

const SHOT_NAMES := ["STD", "DRIVE", "SOFT", "SMASH"]

var teams: Array = [_team(), _team()]
var rallies: Array = []
var _serving := 0
var _rally := 0
var _last_team := -1
var _last_shot := K.SHOT_STANDARD
var _fault := K.FAULT_NONE


static func _team() -> Dictionary:
	return {"points": 0, "serve_points": 0, "serve_won": 0, "aces": 0,
		"winners": [0, 0, 0, 0], "errors": {}, "shots": 0, "drives": 0,
		"smashes": 0}


static func team_of(slot: int) -> int:
	return 1 if slot >= 2 else 0


func on_event(e: Array) -> void:
	match e[0]:
		K.EVENT_SERVE:
			_serving = team_of(e[3])
			_rally = 1
			_last_team = _serving
			_last_shot = K.SHOT_STANDARD
			_fault = K.FAULT_NONE
			teams[_serving]["shots"] += 1
		K.EVENT_HIT:
			var slot: int = e[3] & 15
			var shot: int = e[3] >> 4
			_rally += 1
			_last_team = team_of(slot)
			_last_shot = shot
			teams[_last_team]["shots"] += 1
			if shot == K.SHOT_DRIVE:
				teams[_last_team]["drives"] += 1
			elif shot == K.SHOT_OVERHEAD:
				teams[_last_team]["smashes"] += 1
		K.EVENT_FAULT:
			_fault = e[3]
		K.EVENT_POINT:
			_point(e[3])


func _point(winner: int) -> void:
	var loser := 1 - winner
	var w: Dictionary = teams[winner]
	w["points"] += 1
	teams[_serving]["serve_points"] += 1
	if winner == _serving:
		w["serve_won"] += 1
	if _fault == K.FAULT_NONE or _fault == K.FAULT_SECOND_BOUNCE:
		# never returned: the last shot was the winner's
		if _last_team == winner:
			if _rally == 1 and winner == _serving:
				w["aces"] += 1
			w["winners"][_last_shot] += 1
	else:
		var errs: Dictionary = teams[loser]["errors"]
		errs[_fault] = int(errs.get(_fault, 0)) + 1
	rallies.append(_rally)
	_fault = K.FAULT_NONE
	_rally = 0


func winners(team: int) -> int:
	var t: Array = teams[team]["winners"]
	return t[0] + t[1] + t[2] + t[3]


func errors(team: int) -> int:
	var n := 0
	for k in teams[team]["errors"]:
		n += int(teams[team]["errors"][k])
	return n


## The fault a team made most, as its word ("OUT 3"), or "-".
func top_error(team: int) -> String:
	var best := -1
	var count := 0
	for k in teams[team]["errors"]:
		if int(teams[team]["errors"][k]) > count:
			count = int(teams[team]["errors"][k])
			best = k
	return "-" if best < 0 else "%s %d" % [K.fault_word(best).replace("!", ""), count]


func longest_rally() -> int:
	var n := 0
	for r in rallies:
		n = maxi(n, r)
	return n


func average_rally() -> float:
	if rallies.is_empty():
		return 0.0
	var t := 0
	for r in rallies:
		t += r
	return float(t) / rallies.size()


## The card's rows: [label, left value, right value].
func rows() -> Array:
	var serve := func(t: int) -> String:
		return "%d/%d" % [teams[t]["serve_won"], teams[t]["serve_points"]]
	var shot := func(t: int) -> String:
		var w: Array = teams[t]["winners"]
		var best := 0
		for i in w.size():
			if w[i] > w[best]:
				best = i
		return "%d" % winners(t) if winners(t) == 0 else "%d %s" % [winners(t), SHOT_NAMES[best]]
	return [
		["POINTS", str(teams[0]["points"]), str(teams[1]["points"])],
		["SERVE WON", serve.call(0), serve.call(1)],
		["ACES", str(teams[0]["aces"]), str(teams[1]["aces"])],
		["WINNERS", shot.call(0), shot.call(1)],
		["ERRORS", top_error(0), top_error(1)],
		["SHOTS", str(teams[0]["shots"]), str(teams[1]["shots"])],
		["DRIVES", str(teams[0]["drives"]), str(teams[1]["drives"])],
		["SMASHES", str(teams[0]["smashes"]), str(teams[1]["smashes"])],
	]


func rally_line() -> String:
	return "LONGEST RALLY %d   AVERAGE %.1f" % [longest_rally(), average_rally()]
