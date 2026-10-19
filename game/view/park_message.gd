## The park's panel (render_park.c park_message, PORT-42 split it out of
## park_view.gd): what the line at the bottom says where you stand, and
## the records board's pages. Reads the ParkView (`v`) and its park; the
## 2P note's timer lives on the view.
class_name ParkMessage
extends RefCounted

var v: ParkView


func _init(view: ParkView) -> void:
	v = view


## The panel (render_park.c park_message): [text, prompts, yellow].
func panel() -> Array:
	var rack := v.op.rack_near()
	if v._2p_shown != v.op.two_players:
		v._2p_shown = v.op.two_players
		v._2p_timer = ParkView.TWO_P_FRAMES
	if v._2p_timer and v.op.called == OpenPlay.NONE:
		v._2p_timer -= 1
		return ["2P JOINED: YOUR PARTNER!" if v._2p_shown else "2P LEFT", [], false]
	if v.op.called != OpenPlay.NONE:
		# "WITH ACE VS TWINS": the captain next in line partners you, or 2P;
		# called again as a winner, "WINNERS STAY: VS SNOWBIRDS" (ADR-071).
		var with := "COURT %d" % (v.op.called + 1)
		if v.op.stay_court == v.op.called:
			with = "WINNERS STAY:"
		elif v.op.two_players:
			with = "WITH 2P"
		elif v.op.partner < OpenPlay.TEAMS:
			with = "WITH " + String(Opponents.team(v.op.partner)["players"][0]["name"])
		return [with + " VS " + v._team_name(v.op.opponent), [], true]
	# Back from your game: its result first, for a few seconds.
	# Off after STAY_MAX wins in a row: that, then (rated) your points.
	if v.result_timer and v.op.last_won != OpenPlay.NONE:
		var s := "YOU %s %d-%d" % ["WON" if v.op.last_won else "LOST", v.op.last_score[0],
			v.op.last_score[1]]
		if v.op.last_won and v.op.last_streak >= OpenPlay.STAY_MAX and (v.op.rating == OpenPlay.RATING_NONE
				or v.result_timer > ParkView.RESULT_FRAMES / 2):
			s += "  %d IN A ROW" % v.op.last_streak
		elif v.op.rating != OpenPlay.RATING_NONE:
			s += "  %d PTS" % OpenPlay.rating_points(v.op.rating)
		return [s, [], false]
	if v.op.board_near():
		if v.op.board_page == OpenPlay.NONE:
			return ["THE RECORDS BOARD", [["hit", "READ"]], false]
		return [board_page(v.op.board_page), [["hit", "NEXT"]], false]
	if v.op.machine_near():
		return ["BALL MACHINE", [["hit", "PRACTICE"]], false]
	if v.op.bench_near() and v.op.waiting_team(0) != OpenPlay.NONE:
		var s := v._team_name(v.op.waiting_team(0))
		if v.op.waiting_team(1) != OpenPlay.NONE:
			s += " AND " + v._team_name(v.op.waiting_team(1))
		return [s + " WAIT", [], false]
	if rack != OpenPlay.NONE:
		if v.op.your_court == rack:
			# Teams to pick from, and no 2P (SNES ADR-072).
			if v.op.pickable and not v.op.two_players:
				var who := String(Opponents.team(v.op.pick)["players"][0]["name"]) \
					if v.op.pick < OpenPlay.TEAMS else "NEXT UP"
				return ["PARTNER: " + who, [["hit", "TAKE"], ["slice", "PARTNER"]], false]
			return ["COURT %d" % (rack + 1), [["hit", "TAKE YOUR PADDLE"]], false]
		if not v.op.court_open(rack):
			# "OPENS AT 15 PTS  YOU HAVE 12" (ADR-070)
			return ["OPENS AT %d PTS  YOU HAVE %d" % [OpenPlay.rating_points(OpenPlay.court_floor(rack)),
				OpenPlay.rating_points(v.op.rating)], [], false]
		if v.op.court[rack].stack_count >= OpenPlay.STACK_MAX:
			return ["THIS STACK IS FULL", [], false]
		return ["COURT %d  %s" % [rack + 1, OpenPlay.court_level_name(rack)], [["hit", "STACK YOUR PADDLE"]], false]
	var court := v.op.court_near()
	if court != OpenPlay.NONE and court != v.op.your_court \
			and v.op.court[court].state == OpenPlay.COURT_PLAYING:
		return [v._team_name(v.op.court[court].playing[0]) + " VS " + v._team_name(v.op.court[court].playing[1]),
			[], false]
	var wait := v.op.your_wait()
	if wait != OpenPlay.NONE:
		return ["YOU'RE NEXT ON COURT %d" % (v.op.your_court + 1) if wait == 0
			else "WAITING ON COURT %d" % (v.op.your_court + 1), [], false]
	if v.op.in_house():
		return ["THE CLUBHOUSE", [["start", "EXIT"]], false]
	# "OPEN PLAY 14 PTS": your points, when rated.
	if v.op.rating == OpenPlay.RATING_NONE:
		return ["YOU AND 2P" if v.op.two_players else "OPEN PLAY", [["start", "EXIT"]], false]
	return ["%s %d PTS" % ["YOU+2P" if v.op.two_players else "OPEN PLAY", OpenPlay.rating_points(v.op.rating)],
		[["start", "EXIT"]], false]


## A records board page: the title's RECORDS, a line each.
func board_page(page: int) -> String:
	var r: Dictionary = v.save.data["records"] if v.save else {}
	var n := func(key: String) -> int: return int(r.get(key, 0))
	match page:
		0:
			return "DOUBLES  WON %d  LOST %d" % [n.call("doubles_wins"), n.call("doubles_losses")]
		1:
			return "SINGLES  WON %d  LOST %d" % [n.call("singles_wins"), n.call("singles_losses")]
		2:
			return "BEST STREAK %d  RALLY %d" % [n.call("best_streak"), n.call("longest_rally")]
	return "CLEARS %d  DRILL BEST %d" % [n.call("ladder_clears"), n.call("practice_best")]
