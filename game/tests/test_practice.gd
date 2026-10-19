## ADR-028 practice: settings, feeds that land where asked, streaks
## (reference/snes-src/test/test_practice.c).
extends TestSuite

const DIR := "user://test_practice/"

var sim: Sim
var save: SaveGame
var zone_setting := Practice.ZONE_ANY   ## RETURN TO for the next start()


## A blank save in the test folder (save_initialize on cleared SRAM).
func _blank_save() -> SaveGame:
	wipe_saves(DIR)
	return _reload()


func _reload() -> SaveGame:
	var s := SaveGame.new()
	s.dir = DIR
	s.load_game()
	return s


func _start(shot: int, target: int, rate: int, difficulty: int) -> void:
	save = _blank_save()
	save.data["settings"]["practice"] = [shot, target, rate, zone_setting]
	sim = Sim.new(save.practice_config(difficulty))


func _step_while(cond: Callable, limit: int) -> void:
	for f in limit:
		if not cond.call():
			return
		sim.step()


func test_settings() -> void:
	var values := [9, 9, 9, 9]
	var edit := Practice.Edit.new()
	eq(Practice.practice_shot(9), Practice.SHOT_MIX)
	eq(Practice.target_name(Practice.TARGET_AT_YOU), "AT YOU")
	edit.begin(values)
	eq(values, [Practice.SHOT_MIX, Practice.TARGET_RANDOM, Practice.RATE_NORMAL,
		Practice.ZONE_ANY], "invalid settings become the defaults")
	edit.input(values, Practice.PAD_RIGHT)
	eq(values[0], Practice.SHOT_DRIVE, "wraps")
	edit.input(values, Practice.PAD_UP)
	eq(edit.row, Practice.ROW_ZONE)
	edit.input(values, Practice.PAD_LEFT)
	eq(values[3], Practice.ZONE_RIGHT, "wraps")
	eq(Practice.zone_name(values[3]), "RIGHT LINE")
	edit.input(values, Practice.PAD_UP)
	eq(edit.row, Practice.ROW_RATE)
	edit.input(values, Practice.PAD_LEFT)
	eq(values[2], Practice.RATE_SLOW)
	check(edit.changed(values), "changed")
	eq(edit.input(values, Practice.PAD_Y), Practice.EDIT_CANCEL)
	check(not edit.changed(values), "Y puts the values back")
	eq(edit.input(values, Practice.PAD_B), Practice.EDIT_DONE)


## Every shot to every target: the machine's ball clears the net and first
## bounces in on P1's side, where asked (no one swings).
func test_feeds_land() -> void:
	for shot in Practice.SHOTS:
		for target in Practice.TARGETS:
			_start(shot, target, Practice.RATE_FAST, K.DIFFICULTY_MEDIUM)
			var tag := "%s to %s" % [Practice.shot_name(shot), Practice.target_name(target)]
			if not check(not sim.players[2].active, "no opponent"):
				return
			for feed in 6:
				_step_while(func(): return sim.practice.state == Practice.WAIT, 400)
				if not eq(sim.practice.state, Practice.FEED, tag + " feeds"):
					return
				_step_while(func(): return sim.ball.bounce_count == 0, 200)
				var b := sim.ball
				var ok := b.bounce_count == 1 and Sim.x_on_side(b.x_fp, 0) \
					and Sim.contains_ground_fp(b.x_fp, b.y_fp)
				if target == Practice.TARGET_KITCHEN or shot == Practice.SHOT_DINK:
					ok = ok and b.x_fp > K.to_fp(K.COURT_KITCHEN_LEFT_X - 8)
				if target == Practice.TARGET_DEEP and shot != Practice.SHOT_DINK:
					ok = ok and b.x_fp < K.to_fp(K.COURT_BASELINE_LEFT + 40)
				if not check(ok, "%s feed %d lands in at (%d, %d), %d bounces" % [tag, feed,
						K.from_fp(b.x_fp), K.from_fp(b.y_fp), b.bounce_count]):
					return
				# Unreturned, it bounces twice and the streak stays 0.
				_step_while(func(): return sim.practice.state != Practice.WAIT, 300)
				if not check(sim.practice.state == Practice.WAIT and sim.practice.streak == 0,
						tag + " an unreturned feed ends at 0"):
					return


## The bot P1 (the CPU's own AI on slot 0) returns feeds: streaks build,
## the best is kept and saved on leaving, and the score panels show them.
## kid: the AI moves, but only the KID swing assist swings.
func _run_bot(shot: int, target: int, difficulty: int, kid: bool, frames: int) -> int:
	_start(shot, target, Practice.RATE_FAST, difficulty)
	sim.p1_bot = not kid
	for f in frames:
		sim.set_bot_skill(9, 0)
		if kid:
			var it := SimTypes.Intent.new()
			sim.ai.update(0, it)
			it.hit_pressed = 0
			sim.step([it])
		else:
			sim.step()
	return sim.practice.best


func test_streaks() -> void:
	var best := _run_bot(Practice.SHOT_MIX, Practice.TARGET_RANDOM, K.DIFFICULTY_MEDIUM,
		false, 6000)
	print("    practice: bot best streak (MIX, RANDOM) %d in 100 s" % best)
	check(best >= 3, "the bot builds a streak (%d)" % best)
	eq(best, 8, "the C host test's streak (ADR-028)")
	eq(sim.team_score[1], sim.practice.best, "BEST on the right panel")
	eq(sim.team_score[0], sim.practice.streak, "the streak on P1's")

	var kid_best := _run_bot(Practice.SHOT_DINK, Practice.TARGET_KITCHEN, K.DIFFICULTY_KID,
		true, 6000)
	print("    practice: KID assist only (DINK, KITCHEN) best streak %d" % kid_best)
	check(kid_best >= 3, "the KID assist alone builds a streak (%d)" % kid_best)
	eq(kid_best, 32, "the C host test's streak (ADR-028)")

	# Leaving saves a new best; a lower one does not overwrite it.
	check(save.finish_practice(sim.practice.zone, sim.practice.best), "a new best is saved")
	eq(save.data["records"]["practice_best"], kid_best)
	save = _reload()
	eq(save.data["records"]["practice_best"], kid_best, "and survives a reload")
	check(not save.finish_practice(Practice.ZONE_ANY, 1), "a lower best isn't")
	eq(save.data["records"]["practice_best"], kid_best)


## The nozzle shows where each feed goes: it turns one pose at a time
## toward the next lane during the wait, points there when the ball leaves
## (up for the far sideline, down for the near one), and kicks back.
func test_machine_aim() -> void:
	var seen := [false, false, false]
	_start(Practice.SHOT_MIX, Practice.TARGET_RANDOM, Practice.RATE_FAST, K.DIFFICULTY_MEDIUM)
	var pr := sim.practice
	var pose := pr.pose
	for feed in 30:
		for f in 400:
			if pr.state == Practice.FEED:
				break
			sim.step()
			if pr.pose > Practice.POSE_DOWN or pr.pose + 1 < pose or pr.pose > pose + 1:
				check(false, "the nozzle turns one pose at a time (%d -> %d)" % [pose, pr.pose])
				return
			pose = pr.pose
		if not eq(pr.state, Practice.FEED, "feed %d" % feed):
			return
		check(pr.pose == pr.aim, "points where it feeds")
		eq(pr.kick, Practice.KICK_FRAMES, "kicks back")
		if pr.aim == Practice.POSE_UP:
			check(sim.ball.vy_fp < 0, "up feeds go toward the far sideline")
		elif pr.aim == Practice.POSE_DOWN:
			check(sim.ball.vy_fp > 0, "down feeds go toward the near sideline")
		else:
			check(pr.next_ty >= Practice.MACHINE_Y - Practice.AIM_SPREAD
				and pr.next_ty <= Practice.MACHINE_Y + Practice.AIM_SPREAD, "centre feeds")
		seen[pr.aim] = true
		# Unreturned, it ends and the machine turns toward the next.
		_step_while(func(): return pr.state != Practice.WAIT, 300)
		pose = pr.pose
	eq(seen, [true, true, true], "every pose over 30 RANDOM feeds")

	# AT YOU follows P1: stand by the far sideline and it turns up.
	_start(Practice.SHOT_LOB, Practice.TARGET_AT_YOU, Practice.RATE_SLOW, K.DIFFICULTY_MEDIUM)
	sim.players[0].y_fp = K.to_fp(K.HIT_TARGET_LANE_TOP)
	_step_while(func(): return sim.practice.state != Practice.FEED, 400)
	eq(sim.practice.aim, Practice.POSE_UP, "AT YOU aims up")
	eq(sim.practice.pose, Practice.POSE_UP)
	check(sim.ball.vy_fp < 0, "and feeds that way")


## P1's return lands at (x, y): what the streak does.
func _return_to(x: int, y: int) -> bool:
	_step_while(func(): return sim.practice.state != Practice.FEED, 400)
	if not eq(sim.practice.state, Practice.FEED, "a feed"):
		return false
	# Stand in for P1's hit: the ball leaves P1's side toward (x, y).
	var b := sim.ball
	b.x_fp = K.to_fp(100)
	b.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	b.z_fp = K.to_fp(20)
	b.last_hitter = 0
	b.bounce_count = 0
	Sim.launch(b, x, y, 40)
	sim.practice.state = Practice.RETURN
	_step_while(func(): return sim.practice.state == Practice.RETURN, 200)
	return eq(sim.practice.state, Practice.WAIT, "the return ends the feed")


## Return zones (M4-PRACTICE-03): only returns that land in the zone add
## to its streak; anywhere else (even in) resets it. Each zone keeps its
## own saved best, apart from the plain streak's.
func test_zones() -> void:
	var inside := [[200, 100], [150, 130], [225, 140], [190, 98], [170, 162]]
	var outside := [[250, 130], [200, 130], [170, 130], [190, 130], [190, 130]]
	for zone in Practice.ZONES:
		var i: Array = inside[zone]
		var o: Array = outside[zone]
		check(Practice.in_zone(zone, i[0], i[1]), "zone %d inside" % zone)
		check(not Practice.in_zone(zone, o[0], o[1]), "zone %d outside" % zone)
		zone_setting = zone
		_start(Practice.SHOT_LOB, Practice.TARGET_DEEP, Practice.RATE_FAST, K.DIFFICULTY_MEDIUM)
		eq(sim.practice.zone, zone)
		if not _return_to(i[0], i[1]):
			break
		eq(sim.practice.streak, 1, "zone %d: in" % zone)
		eq(sim.practice.zone_flash, Practice.ZONE_FLASH_FRAMES if zone else 0, "the corners blink")
		_return_to(i[0], i[1])
		check(sim.practice.streak == 2 and sim.practice.best == 2, "zone %d: two in" % zone)
		_return_to(o[0], o[1])
		check(sim.practice.streak == 0 and sim.practice.best == 2, "zone %d: out resets" % zone)
		# The best is saved for this zone only.
		save.finish_practice(sim.practice.zone, sim.practice.best)
		save = _reload()
		for other in Practice.ZONES:
			eq(save.practice_saved_best(other), 2 if other == zone else 0,
				"zone %d's best after a zone %d session" % [other, zone])
		# And the next session in that zone starts from it.
		sim = Sim.new(save.practice_config(K.DIFFICULTY_MEDIUM))
		eq(sim.practice.best, 2, "the saved best is folded in")
	zone_setting = Practice.ZONE_ANY


## Leaving through the pause menu's MAIN MENU (ADR-030) saves the best and
## returns to the title (main.c calls practice_finish).
func test_exit() -> void:
	save = _blank_save()
	save.data["settings"]["practice"] = [Practice.SHOT_DRIVE, Practice.TARGET_AT_YOU,
		Practice.RATE_FAST, Practice.ZONE_ANY]
	var view := MatchView.new()
	view.save = save
	runner.root.add_child(view)
	view.setup(save.practice_config(K.DIFFICULTY_MEDIUM), "park", false)
	var left := [false]
	view.finished.connect(func(to_title: bool): left[0] = to_title)
	for f in 30:
		view._physics_process(1.0 / 60.0)
	view.sim.practice.best = 7
	view.leave_practice()
	check(left[0], "back to the title")
	eq(save.data["records"]["practice_best"], 7, "the best is saved")
	eq(_reload().data["records"]["practice_best"], 7, "and written")
	view.queue_free()
	check(Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5).practice == 0,
		"a match after it isn't practice")


## The traced match state is untouched by practice existing: a practice
## session's sim never runs the serve or rules (no point is ever scored).
func test_no_points_or_serves() -> void:
	_start(Practice.SHOT_MIX, Practice.TARGET_RANDOM, Practice.RATE_FAST, K.DIFFICULTY_MEDIUM)
	sim.p1_bot = true
	var kinds := {}
	for f in 3000:
		sim.step()
		for e in sim.drain_events():
			kinds[e[0]] = true
		if sim.phase != K.PHASE_LIVE:
			break
	eq(sim.phase, K.PHASE_LIVE, "always live")
	check(not kinds.has(K.EVENT_SERVE) and not kinds.has(K.EVENT_POINT)
		and not kinds.has(K.EVENT_FAULT), "no serves, points, or faults")
	check(kinds.has(K.EVENT_HIT) and kinds.has(K.EVENT_BOUNCE), "feeds and bounces")
