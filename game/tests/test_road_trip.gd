## ROAD TRIP (PORT-82, port ADR-087): the data the screens show, the map a
## seed draws (always the same, always keeping the leg rules), a trip
## played through (wins, losses, hearts, picks, the shop, detours), the
## save, and the trip's stats and one-sided rules in the sim (off, the sim
## is unchanged).
extends TestSuite

const CARD_LINE := 30            ## characters a gear card's line holds
const PAGE_LINE := 46


func _glyphs_ok(s: String, chars: String) -> bool:
	for ch in s:
		if ch != " " and not chars.contains(ch):
			return false
	return true


func test_the_data() -> void:
	var d := RoadTrip.data()
	var chars := String(BitmapText.load_font("small")["chars"])
	var bad := []
	var ids := []
	for g in d["gear"]:
		ids.append(String(g["id"]))
		if String(g["name"]).length() > 18:
			bad.append("name: " + String(g["name"]))
		if g["lines"].size() != 2:
			bad.append("lines: " + String(g["id"]))
		for l in g["lines"]:
			if String(l).length() > CARD_LINE or not _glyphs_ok(String(l), chars):
				bad.append("line: " + String(l))
		if not _glyphs_ok(String(g["name"]), chars):
			bad.append("glyph: " + String(g["name"]))
		check(int(g["icon"]) >= -1 and int(g["icon"]) < TripArt.ICONS_1 + 24, "an icon on the sheets: " + String(g["id"]))
		check(String(g["kind"]) in ["bag", "paddle", "hat", "partner", "perk"])
		check(String(g["rarity"]) in ["start", "common", "uncommon", "rare"])
		if g.has("hat"):
			check(Career.hat_names.has(String(g["hat"])) or Career.hats() > 0 and Career.hat_names.has(String(g["hat"])),
				"a hat the game has: " + String(g["hat"]))
	for id in d["start_pool"]:
		check(ids.has(String(id)), "the pool's " + String(id))
	for step in d["ladder"]:
		for id in step.get("pool", []):
			check(ids.has(String(id)), "the ladder's " + String(id))
		if step.has("start_paddle"):
			check(ids.has(String(step["start_paddle"])))
	for h in d["hazards"]:
		check(RoadTrip.mod_bits(String(h["mod"])) != 0, "a modifier the game has: " + String(h["mod"]))
		if String(h["line"]).length() > PAGE_LINE or not _glyphs_ok(String(h["line"]), chars):
			bad.append("hazard: " + String(h["line"]))
	for m in d["grudge_mods"]:
		check(RoadTrip.mod_bits(String(m)) != 0, "a grudge twist the game has: " + String(m))
	for dt in d["detours"]:
		check(dt["lines"].size() <= 3)
		for l in dt["lines"]:
			if String(l).length() > PAGE_LINE or not _glyphs_ok(String(l), chars):
				bad.append("detour: " + String(l))
		for ch in dt["choices"]:
			if String(ch["label"]).length() > 32 or not _glyphs_ok(String(ch["label"]), chars):
				bad.append("choice: " + String(ch["label"]))
			if ch["do"].has("hazard"):
				check(not RoadTrip.hazard(String(ch["do"]["hazard"])).is_empty())
	for key in d["scenes"]:
		var pages: Array = []
		if key in ["teams", "partner_start"]:
			for t in d["scenes"][key]:
				pages.append_array(t)
		else:
			pages = d["scenes"][key]
		for p in pages:
			check(String(p["who"]) in ["partner", "you", "captain", "mate", "narrator"])
			check(p["lines"].size() >= 1 and p["lines"].size() <= 3)
			for l in p["lines"]:
				if String(l).length() > PAGE_LINE or not _glyphs_ok(String(l), chars):
					bad.append("scene: " + String(l))
	eq(d["scenes"]["teams"].size(), Opponents.count() + 1, "a scene for every ladder team and Dawson")
	for i in RoadTrip.data()["ladder"].size():
		var l := RoadTrip.step_label(i)
		if l.length() > PAGE_LINE or not _glyphs_ok(l, chars):
			bad.append("step: " + l)
	for name in d["locals"]:
		if String(name).length() > 13 or not _glyphs_ok(String(name), chars):   # the HUD fits 13
			bad.append("locals: " + String(name))
	eq(bad, [], "every text the trip shows fits and can be drawn")


func test_a_seed_draws_the_same_map() -> void:
	eq(RoadTrip.generate(4127, 0), RoadTrip.generate(4127, 0), "the same seed, the same map")
	check(RoadTrip.generate(4127, 0) != RoadTrip.generate(4128, 0), "another seed, another map")
	var m := RoadTrip.generate(99, 0)
	eq(m.size(), RoadTrip.LEGS)
	eq(String(m[2]["gate"]["type"]), "final")
	eq(int(m[2]["gate"]["team"]), 7, "the Champs at the SUMMER OPEN")
	eq(String(m[2]["gate"]["venue"]), "sunset")


func test_every_leg_keeps_the_rules() -> void:
	var broken := 0
	var types := {}
	var dawson := 0
	for s in range(1, 301):
		var m := RoadTrip.generate(s * 7919, s % 6)
		for leg in RoadTrip.LEGS:
			if not RoadTrip.valid_leg(m[leg], leg, s % 6):
				broken += 1
			for col in m[leg]["cols"]:
				for n in col:
					types[n["type"]] = int(types.get(n["type"], 0)) + 1
					if int(n["team"]) == Opponents.DAWSON:
						dawson += 1
			check(m[leg]["gate"]["type"] in ["big", "final"])
			var bigs: Array = RoadTrip.leg_info(leg)["big"].map(func(x): return int(x))
			check(bigs.has(int(m[leg]["gate"]["team"])), "seed %d leg %d: a big match of the leg's" % [s, leg])
			# every stop reachable: each column's lanes all have a road in
			if leg == 0:
				for c in range(1, RoadTrip.COLS):
					for lane in RoadTrip.LANES:
						var fed := false
						for prev in m[leg]["cols"][c - 1]:
							if prev["edges"].has(lane):
								fed = true
						check(fed, "seed %d leg %d: every stop has a road in" % [s, leg])
	eq(broken, 0, "300 seeds' legs all keep the rules")
	for t in ["pickup", "grudge", "yard", "shop", "motel", "detour"]:
		check(int(types.get(t, 0)) > 0, "the maps have %s stops" % t)
	check(dawson > 0, "Dale Dawson turns up on a back road now and then")


func test_roads_never_cross() -> void:
	for s in range(1, 60):
		var m := RoadTrip.generate(s, 0)
		for leg in RoadTrip.LEGS:
			for c in RoadTrip.COLS - 1:
				var col: Array = m[leg]["cols"][c]
				for lane in RoadTrip.LANES - 1:
					var down: bool = col[lane]["edges"].has(lane + 1)
					var up: bool = col[lane + 1]["edges"].has(lane)
					check(not (down and up), "seed %d: two roads cross" % s)


## Plays a trip by always taking the first road and winning or losing
## every match as `outcome` says (index: the match number).
func _play(t: RoadTrip, outcome: Callable, limit := 40) -> int:
	var matches := 0
	for i in limit:
		if t.state != "on":
			break
		if not t.pending.is_empty():
			t.take(String(t.pending["items"][0]))
			continue
		var r := t.reachable()
		if r.is_empty():
			# at a big match not yet won: play it again
			if t.is_gate():
				t.record_match(outcome.call(matches))
				matches += 1
			continue
		var n := t.go(int(r[0][0]), int(r[0][1]))
		match String(n["type"]):
			"pickup", "grudge", "big", "final":
				t.record_match(outcome.call(matches))
				matches += 1
			"detour":
				t.choose(RoadTrip.detour(String(n["detour"])), 1)
				t.finish_stop()
			"yard":
				t.offer_pick("yard", 0)
				t.finish_stop()
			"motel":
				t.rest(true)
				t.finish_stop()
			_:
				t.finish_stop()
	return matches


func test_a_trip_won() -> void:
	var t := RoadTrip.create(4127, 0, RoadTrip.PEPPER)
	var played := _play(t, func(_i): return true)
	eq(t.state, "won", "winning every match reaches and wins the SUMMER OPEN")
	check(played >= 6 and played <= 12, "a trip is 6 to 12 matches (%d)" % played)
	eq(t.hearts, t.max_hearts)
	check(t.beaten.has(7), "the Champs beaten")
	check(t.stops >= 9 and t.stops <= 12, "12 stops at most (%d)" % t.stops)
	check(t.bag.size() + (1 if t.paddle != "plain_paddle" else 0) + (1 if t.hat != "plain_cap" else 0) >= 3,
		"gear picked on the way")


func test_a_trip_lost() -> void:
	var t := RoadTrip.create(4127, 0, RoadTrip.PEPPER)
	_play(t, func(_i): return false)
	eq(t.state, "over", "losing every match ends the trip")
	eq(t.hearts, 0)
	eq(t.losses, RoadTrip.HEARTS, "three hearts, three losses")
	var t2 := RoadTrip.create(4127, 2, RoadTrip.PEPPER)
	eq(t2.max_hearts, 2, "HEAT 2: two hearts")
	var t3 := RoadTrip.create(4127, 3, RoadTrip.PEPPER)
	eq(t3.hazards.size(), 1, "HEAT 3: a hazard to start with")


func test_a_lost_big_match_is_played_again() -> void:
	var t := RoadTrip.create(11, 0, RoadTrip.PEPPER)
	# win everything up to the first big match, then lose it once
	for i in 20:
		var r := t.reachable()
		if not t.pending.is_empty():
			t.skip_pick()
			continue
		if r.is_empty():
			break
		var n := t.go(int(r[0][0]), int(r[0][1]))
		if t.is_gate():
			break
		if t.is_match(n):
			t.record_match(true)
		else:
			t.finish_stop()
	check(t.is_gate(), "at the big match")
	var hearts := t.hearts
	t.record_match(false)
	eq(t.hearts, hearts - 1, "a heart lost")
	check(t.is_gate(), "still at the big match: it's played again")
	eq(t.reachable(), [], "no driving past it")
	t.record_match(true)
	eq(t.leg(), 1, "won: on to the next leg")
	eq(t.col(), RoadTrip.START)


func test_stats_and_gear() -> void:
	var t := RoadTrip.create(5, 0, RoadTrip.PEPPER)
	eq(t.stats(), [1, 1, 1, 1], "you start with nothing")
	t.take("red_paddle")
	eq(t.paddle, "red_paddle")
	eq(t.stats()[0], 6, "+5 POWER")
	t.take("visor")
	eq(t.hat, "visor")
	eq(t.stats()[1], 4, "+3 CONTROL")
	t.take("grip_tape")
	t.take("grip_tape")
	eq(t.stats()[1], 8, "GRIP TAPE stacks")
	check(not t.can_take("visor"), "the hat you wear isn't offered again")
	check(t.can_take("grip_tape"), "stacking items are")
	t.take("spare_paddle")
	eq(t.max_hearts, 4)
	eq(t.hearts, 4)
	for i in 20:
		t.take("wrist_weights")
	eq(t.stats()[0], RoadTrip.STAT_MAX, "20 at most")
	var cfg := t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": "MOD_ICE"}, Settings.p1_choice)
	eq(cfg.mode, K.MODE_DOUBLES)
	eq(cfg.trip, 1)
	eq(cfg.trip_stats[0], t.stats())
	eq(cfg.partner, Opponents.PEPPER, "Pepper partners you")
	eq(cfg.points_to_win, 3, "a pickup game is short")
	eq(cfg.paddle[0], Paddles.RED, "the red paddle's look")
	check(cfg.modifiers & K.MOD_ICE, "the stop's twist")
	t.take("umbrella")
	cfg = t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": "MOD_ICE"}, Settings.p1_choice, true)
	check(not (cfg.modifiers & K.MOD_ICE), "an UMBRELLA lifts it")
	cfg = t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": "MOD_ICE"}, Settings.p1_choice)
	check(cfg.modifiers & K.MOD_ICE, "once")
	t.take("dink_drill")
	eq(t.partner_style().net, 44, "the partner's play changes")
	t.take("head_start")
	check(t.perk_bits() & K.PERK_HEAD_START)
	var cap := RoadTrip.create(5, 0, 3)
	eq(cap.config_for({"type": "big", "team": 1}, Settings.p1_choice).partner, 3, "a captain as your partner")


func test_picks_are_the_same_each_time() -> void:
	var a := RoadTrip.create(77, 0, RoadTrip.PEPPER)
	var b := RoadTrip.create(77, 0, RoadTrip.PEPPER)
	a.offer_pick("yard", 0)
	b.offer_pick("yard", 0)
	eq(a.pending, b.pending, "the same stop, the same cards")
	eq(a.pending["items"].size(), 3)
	var distinct := {}
	for id in a.pending["items"]:
		distinct[id] = true
		check(a.can_take(String(id)))
	eq(distinct.size(), 3, "three different cards")
	a.take("lucky_penny")
	a.offer_pick("yard", 1)
	eq(a.pending["items"].size(), 4, "a LUCKY PENNY: four")


func test_the_shop_and_detours() -> void:
	var t := RoadTrip.create(3, 0, RoadTrip.PEPPER)
	var stock := t.shop_stock({})
	eq(stock.size(), 4)
	eq(stock, t.shop_stock({}), "the same stock each visit")
	check(not t.buy(String(stock[0])), "no cash, no sale")
	t.cash = 200
	var p := t.price(String(stock[0]))
	check(t.buy(String(stock[0])))
	eq(t.cash, 200 - p)
	t.take("coupon_book")
	eq(t.price("visor"), 30 - 30 / 4, "a COUPON BOOK takes a quarter off")
	t.hearts = 1
	check(t.buy_soda())
	eq(t.hearts, 2)
	t.hazards = ["storm"]
	check(t.buy_fix())
	eq(t.hazards, [])
	var bet := RoadTrip.detour("bet")
	t.cash = 0
	var offered := t.detour_choices(bet)
	eq(offered[-1]["label"], "DRIVE ON", "a detour you can't afford: DRIVE ON")
	check(t.choose(bet, offered.size() - 1))
	t.cash = 50
	eq(t.detour_choices(bet).size(), bet["choices"].size(), "no DRIVE ON when you can pay")
	var noise := RoadTrip.detour("noise")
	t.cash = 5
	check(not t.choose(noise, 0), "can't pay to fix the van")
	check(t.choose(noise, 1))
	eq(t.hazards, ["flat_tire"])
	eq(String(t.pending.get("kind", "")), "pick", "and a pick")
	var cfg := t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice)
	check(cfg.modifiers & K.MOD_ICE, "a FLAT TIRE: the next match on ICE")
	t.pending = {}
	var r := t.reachable()
	t.go(int(r[0][0]), int(r[0][1]))
	t.record_match(true)
	eq(t.hazards, [], "spent after the match")


func test_the_save_and_the_garage() -> void:
	var sv := fresh_save("user://test_road_trip/")
	var m := RoadTrip.meta(sv)
	eq(int(m["miles"]), 0)
	eq(RoadTrip.current(sv), null, "no trip in progress")
	var t := RoadTrip.begin(sv, 4127, 0, RoadTrip.PEPPER)
	eq(int(RoadTrip.meta(sv)["trips"]), 1)
	_play(t, func(i): return i < 4, 6)
	t.store(sv)
	sv.save_game()
	var again := SaveGame.new()
	again.dir = "user://test_road_trip/"
	again.load_game()
	var back := RoadTrip.current(again)
	check(back != null, "the trip in progress survives a restart")
	eq(back.to_dict(), t.to_dict(), "exactly as it was")
	_play(back, func(_i): return false)
	eq(back.state, "over")
	var miles := back.miles
	back.finish(again)
	m = RoadTrip.meta(again)
	eq(int(m["miles"]), miles, "the trip's miles go to the GARAGE")
	eq(m["now"], {}, "no trip in progress")
	check(m["partners"].size() >= 1, "the captains beaten can partner you")
	# the ladder: enough miles reach steps, which start the next trip stronger
	m["miles"] = 60 + 80 + 100 + 120
	eq(RoadTrip.steps_reached(m), 4)
	var g := RoadTrip.garage(m)
	eq(g["stats"], [1, 0, 0, 1], "+1 FEET, then +1 POWER")
	check(g["pool"].has("grip_tape"))
	check(g["vans"].has(1), "a paint job")
	var next := RoadTrip.create(1, 0, RoadTrip.PEPPER, m)
	eq(next.stats(), [2, 1, 1, 2])
	eq(RoadTrip.miles_to_next(m), 140)
	# nothing outside the trip changed
	eq(int(again.data["records"]["doubles_wins"]), 0, "the records don't count a trip's matches")
	eq(again.career.active_player(), null)


func test_an_old_save_without_a_trip() -> void:
	var sv := fresh_save("user://test_road_trip_old/")
	sv.data.erase("trip")
	sv.save_game()
	var again := SaveGame.new()
	again.dir = "user://test_road_trip_old/"
	again.load_game()
	eq(RoadTrip.current(again), null)
	eq(int(RoadTrip.meta(again)["miles"]), 0, "a save from before ROAD TRIP starts at nothing")


# --- The sim ----------------------------------------------------------------------------

func test_trip_stats_in_the_sim() -> void:
	var p := Paddles.trip_profile(1, 20, 8)
	check(Paddles.is_trip(p))
	eq([Paddles.trip_stat(p, 0), Paddles.trip_stat(p, 1), Paddles.trip_stat(p, 2)], [1, 20, 8])
	check(Paddles.power_mul(p) < Paddles.power_mul(Paddles.STANDARD), "POWER 1 hits softer than the standard paddle")
	check(Paddles.control_mul(p) < Paddles.control_mul(Paddles.STANDARD), "CONTROL 20 sprays less")
	eq(Paddles.trip_feet(8), K.PLAYER_MAX_SPEED_FP, "FEET 8 is the game's speed")
	check(Paddles.trip_feet(1) < K.PLAYER_MAX_SPEED_FP)
	eq(Paddles.trip_feet(20), 31)
	var t := RoadTrip.create(9, 0, RoadTrip.PEPPER)
	var cfg := t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice)
	var s := Sim.new(cfg)
	check(Paddles.is_trip(s.players[0].paddle), "slot 0 plays with the trip's stats")
	eq(s.players[0].max_speed_fp, Paddles.trip_feet(1))
	check(Paddles.is_trip(s.players[1].paddle), "so does the partner")
	s.dispose()
	# off, a config is the game's: the same paddle and speed as ever
	var plain := Settings.config_for(true, 0, K.DIFFICULTY_MEDIUM, 5, Settings.p1_choice)
	plain.trip_stats = [[1, 1, 1, 1], [], [], []]
	var s2 := Sim.new(plain)
	eq(s2.players[0].paddle, plain.paddle[0], "trip_stats do nothing without `trip`")
	eq(s2.players[0].max_speed_fp, K.PLAYER_MAX_SPEED_FP)
	s2.dispose()


## Port ADR-091: leg 1 is a bit harder (its grudge and big matches
## MEDIUM, fewer CPU errors); the partner is late less often, less still
## with more CONTROL.
func test_the_tuning() -> void:
	var t := RoadTrip.create(9, 0, RoadTrip.PEPPER)
	var pickup := {"type": "pickup", "team": -1, "local": 0, "mod": ""}
	var big := {"type": "big", "team": 1, "mod": ""}
	eq(t.difficulty_for(pickup), K.DIFFICULTY_EASY, "leg 1's pickups are EASY")
	eq(t.difficulty_for(big), K.DIFFICULTY_MEDIUM, "its big match MEDIUM")
	eq(t.difficulty_for({"type": "final", "team": 7, "mod": ""}), K.DIFFICULTY_HARD)
	eq(t.config_for(big, Settings.p1_choice).cpu_errors, RoadTrip.LEG_1_ERRORS, "fewer CPU errors in leg 1")
	t.at = [1, 0, 0]
	eq(t.config_for(big, Settings.p1_choice).cpu_errors, 100, "the game's from leg 2")
	t.heat = 1
	eq(t.errors_for(), 75, "HEAT 1's from leg 2")
	t.at = [0, 0, 0]
	eq(t.errors_for(), 75 * RoadTrip.LEG_1_ERRORS / 100, "and less in leg 1")
	eq(Opponents.partner_style().late_period, 7, "a ladder partner's Pepper is late every 7th ball")
	eq(t.partner_style().late_period, RoadTrip.PARTNER_LATE, "ROAD TRIP's every 12th")
	t.partner_stats = [8, 10, 8, 8]
	eq(t.partner_style().late_period, RoadTrip.PARTNER_LATE + 4 * RoadTrip.PARTNER_LATE_STEP, "less often with CONTROL")
	var s := Sim.new(t.config_for(big, Settings.p1_choice))
	eq(s.ai.slots[1].late_period, Sim.late_period(t.partner_style().late_period, t.errors_for()),
		"the sim's partner is late as tuned")
	s.dispose()


func test_the_one_sided_rules() -> void:
	var cfg := Settings.config_for(true, 0, K.DIFFICULTY_MEDIUM, 5, Settings.p1_choice)
	cfg.trip = 1
	cfg.perks = K.PERK_HEAD_START | K.PERK_SECOND_WIND
	var s := Sim.new(cfg)
	eq(s.team_score, [1, 0], "HEAD START: 1-0")
	s.team_score = [1, 4]
	s._second_wind()
	eq(s.players[0].max_speed_fp, K.PLAYER_MAX_SPEED_FP + K.SECOND_WIND_FP, "SECOND WIND at match point against")
	s.team_score = [3, 4]
	s._second_wind()
	eq(s.players[0].max_speed_fp, K.PLAYER_MAX_SPEED_FP + K.SECOND_WIND_FP, "still match point")
	s.team_score = [4, 3]
	s._second_wind()
	eq(s.players[0].max_speed_fp, K.PLAYER_MAX_SPEED_FP, "and back")
	s.dispose()
	var off := Sim.new(Settings.config_for(true, 0, K.DIFFICULTY_MEDIUM, 5, Settings.p1_choice))
	eq(off.team_score, [0, 0], "no perks: 0-0")
	off.dispose()
	# a trip match plays through, perks and all
	var t := RoadTrip.create(21, 0, RoadTrip.PEPPER)
	for id in ["head_start", "long_arms", "kitchen_pass", "second_serve", "second_wind"]:
		t.take(id)
	var s3 := Sim.new(t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice))
	s3.p1_bot = true
	var ended := run_until(s3, func(): return s3.phase == K.PHASE_MATCH_RESULT, 40000)
	check(ended >= 0, "a trip match with every rule ends")
	s3.dispose()


func test_the_locals_looks() -> void:
	var t := RoadTrip.create(31, 0, RoadTrip.PEPPER)
	var manifest := MatchView.levels_manifest()
	var hats: Dictionary = manifest["sprites"]["players"]["roles"]["files"]["male"]
	var n := {"type": "pickup", "local": 4}
	eq(t.local_members(n), t.local_members(n), "the same locals look the same each time")
	for local in RoadTrip.data()["locals"].size():
		for m in t.local_members({"type": "pickup", "local": local}):
			check(m["hat"] == "hair" or hats.has(String(m["hat"])), "a hat the rig draws: %s" % m["hat"])
			check(Opponents.skin(String(m["skin"])).size() == 3)
			var look := PlayerLook.from_member(m, manifest)
			eq(look.palette.size(), PlayerLook.ROLE_COUNT)
	var plain := PlayerLook.for_team(0, 0, Paddles.WOOD, manifest)
	plain.plain_paddle(manifest)
	var order := String(manifest["sprites"]["players"]["roles"]["order"])
	eq(plain.palette[order.find("f")], PlayerLook.PLAIN_PADDLE["f"], "the PLAIN PADDLE's plywood")


func test_lucky_line_and_hot_hand() -> void:
	var cfg := Settings.config_for(true, 0, K.DIFFICULTY_MEDIUM, 5, Settings.p1_choice)
	cfg.trip = 1
	cfg.perks = K.PERK_LUCKY_LINE
	var s := Sim.new(cfg)
	# a ball of yours lands just past their baseline
	s.set_phase(K.PHASE_LIVE)
	s.ball.last_hitter = 0
	s.ball.bounce_count = 1
	s.ball.x_fp = K.to_fp(K.COURT_BASELINE_RIGHT) + 8
	s.ball.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	s.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	eq(s.phase, K.PHASE_LIVE, "LUCKY LINE: out by a hair is in")
	check(s.lucky_line_used)
	check(s.drain_events().any(func(e): return e[0] == K.EVENT_PERK and e[3] == K.PERK_LUCKY_LINE))
	s.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	eq(s.phase, K.PHASE_POINT_RESULT, "once a match")
	eq(s.point_winner, 1)
	s.dispose()
	# far out is out, lucky or not
	var s2 := Sim.new(cfg)
	s2.set_phase(K.PHASE_LIVE)
	s2.ball.last_hitter = 0
	s2.ball.bounce_count = 1
	s2.ball.x_fp = K.to_fp(K.COURT_BASELINE_RIGHT + 40)
	s2.ball.y_fp = K.to_fp(K.COURT_CENTERLINE_Y)
	s2.rules_process_ball_events(K.BALL_EVENT_BOUNCE | K.BALL_EVENT_OUT)
	eq(s2.phase, K.PHASE_POINT_RESULT, "a ball well out is out")
	s2.dispose()
	# HOT HAND: three in a row fill your side's meters
	var t := RoadTrip.create(4, 0, RoadTrip.PEPPER)
	t.take("hot_hand")
	var hc := t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice)
	check(hc.modifiers & K.MOD_SPECIALS, "HOT HAND turns SPECIALS on")
	check(hc.perks & K.PERK_HOT_HAND)
	var s3 := Sim.new(hc)
	for k in 2:
		s3.set_phase(K.PHASE_LIVE)
		s3.resolve_point(1, K.FAULT_OUT)
	check(s3.meter[0] < K.SPECIAL_METER_MAX, "two in a row: not yet")
	s3.set_phase(K.PHASE_LIVE)
	s3.resolve_point(1, K.FAULT_OUT)
	eq(s3.meter[0], K.SPECIAL_METER_MAX, "three: the meter is full")
	eq(s3.meter[1], K.SPECIAL_METER_MAX, "your partner's too")
	check(s3.meter[2] < K.SPECIAL_METER_MAX, "theirs isn't")
	s3.dispose()


# --- The second round (port ADR-092) ----------------------------------------------

func test_the_new_data() -> void:
	var d := RoadTrip.data()
	var chars := String(BitmapText.load_font("small")["chars"])
	var ids: Array = d["gear"].map(func(g): return String(g["id"]))
	var beats: Array = d["beats"].map(func(b): return String(b["id"]))
	var arcs: Array = d["arcs"].map(func(a): return String(a["id"]))
	var bad := []
	for st in d["sets"]:
		check(st["items"].size() >= 2, "a set of two or more: " + String(st["id"]))
		for id in st["items"]:
			check(ids.has(String(id)), "the set's " + String(id))
		var line := RoadTrip.bonus_label(st)
		if line.length() > 26 or not _glyphs_ok(String(st["name"]) + line, chars):
			bad.append("set: " + line)
	for dish in d["diner"]:
		if String(dish["label"]).length() > 32 or not _glyphs_ok(String(dish["label"]), chars):
			bad.append("dish: " + String(dish["label"]))
	eq(String(d["diner"][4]["id"]), "works", "THE WORKS last, the four dishes first")
	for b in d["beats"]:
		check(arcs.has(String(b["arc"])), "an arc: " + String(b["id"]))
		check(String(b["slot"]) in ["start", "motel", "leg", "team", "rival", "beaten", "won", "over", "detour"],
			"a slot: " + String(b["id"]))
		for id in b.get("when", {}).get("needs", []):
			check(beats.has(String(id)) and beats.find(String(id)) < beats.find(String(b["id"])),
				"needs an earlier beat: " + String(b["id"]))
		for id in b.get("reward", {}).get("pool", []):
			check(ids.has(String(id)), "a reward on the road: " + String(id))
		if b.get("reward", {}).has("tape"):
			check(int(b["reward"]["tape"]) < d["tapes"].size())
		if String(b["slot"]) != "detour":
			check(not b.get("pages", []).is_empty(), "pages: " + String(b["id"]))
		for p in b.get("pages", []):
			check(String(p["who"]) in ["partner", "you", "captain", "mate", "narrator"])
			check(p["lines"].size() >= 1 and p["lines"].size() <= 3)
			for l in p["lines"]:
				if String(l).length() > PAGE_LINE or not _glyphs_ok(String(l), chars):
					bad.append("beat: " + String(l))
		var hint := "NEXT: " + String(b["hint"])
		var title := "CHAPTER 9: " + String(b["title"])
		for l in [hint, title]:
			if l.length() > PAGE_LINE or not _glyphs_ok(l, chars):
				bad.append("scrapbook: " + l)
	for dt in d["detours"]:
		if dt.has("beat"):
			check(beats.has(String(dt["beat"])) and String(RoadTrip.beat(String(dt["beat"]))["slot"]) == "detour")
		if dt.has("venue"):
			check(Settings.VENUES.has(String(dt["venue"])), "a venue the game has: " + String(dt["venue"]))
		for p in dt.get("pages", []):
			for l in p["lines"]:
				if String(l).length() > PAGE_LINE or not _glyphs_ok(String(l), chars):
					bad.append("detour page: " + String(l))
	for tp in d["tapes"]:
		check(Music.LOOPS.has(String(tp["track"])), "a track the game has: " + String(tp["track"]))
		if String(tp["name"]).length() > 14 or not _glyphs_ok(String(tp["name"]), chars):
			bad.append("tape: " + String(tp["name"]))
	for m in d["rival"]["members"]:
		check(String(m["who"]).length() <= 8)
	eq(d["scenes"]["partner_start"].size(), Opponents.count(), "a start for every captain partner")
	eq(bad, [], "every new text fits and can be drawn")


func test_story_stops_on_the_map() -> void:
	var m := {"trips": 1, "won": 0, "hogs": 2, "beats": ["van_1", "van_2", "van_3"], "story_pool": [], "tapes": []}
	var ex := RoadTrip.story_extras(m, RoadTrip.PEPPER)
	check(ex["rival"], "the ROAD HOGS from the second trip on")
	eq(ex["detours"], [], "the old court once")
	check(ex["dawson"], "the stranger, once the old court is found")
	eq(RoadTrip.story_extras({"trips": 0, "beats": [], "hogs": 0}, RoadTrip.PEPPER)["rival"], false,
		"not on the first trip")
	check(not RoadTrip.story_extras(m, 3)["dawson"], "the van's story is Pepper's")
	m["beats"] = ["van_1", "van_2"]
	eq(RoadTrip.story_extras(m, RoadTrip.PEPPER)["detours"], ["old_court"])
	for s in 200:
		var ex2 := {"rival": true, "hogs": s % 6, "detours": ["old_court"], "dawson": true}
		var map := RoadTrip.generate(s * 31 + 7, s % 6, ex2)
		eq(map, RoadTrip.generate(s * 31 + 7, s % 6, ex2), "the same seed and story, the same map")
		var rivals: Array = map[RoadTrip.RIVAL_LEG]["cols"][1].filter(func(n): return n["type"] == "rival")
		eq(rivals.size(), 1, "the ROAD HOGS on the long drive")
		eq(int(rivals[0]["level"]), s % 6)
		eq(map[1]["cols"][0].filter(func(n): return String(n["detour"]) == "old_court").size(), 1, "the old court")
		eq(map[2]["cols"][1].filter(func(n): return int(n["team"]) == Opponents.DAWSON).size(), 1, "the stranger")
		for leg in RoadTrip.LEGS:
			check(RoadTrip.valid_leg(map[leg], leg, s % 6), "seed %d leg %d keeps the rules" % [s, leg])
			for col in map[leg]["cols"]:
				for n in col:
					if n["type"] == "detour" and leg != 1:
						check(not RoadTrip.detour(String(n["detour"])).has("beat"), "story detours only where placed")


func test_the_locker_and_trading() -> void:
	var t := RoadTrip.create(5, 0, RoadTrip.PEPPER)
	t.take("red_paddle")
	t.take("wood_paddle")
	t.take("visor")
	eq(t.paddle, "wood_paddle")
	eq(t.choices_of("paddle"), ["wood_paddle", "plain_paddle", "red_paddle"], "replaced paddles go in the locker")
	eq(t.choices_of("hat"), ["visor", "plain_cap"])
	check(not t.can_take("red_paddle"), "what's in the locker isn't offered again")
	check(t.equip("red_paddle"))
	eq(t.paddle, "red_paddle")
	eq(t.stats()[0], 6, "the red paddle's +5 POWER, in hand")
	check(t.locker.has("wood_paddle"))
	check(not t.equip("gold_paddle"), "only what's in the locker")
	eq(t.sellable(), ["wood_paddle"], "the locker's (the plain ones are worth nothing), then the bag's")
	t.take("spare_paddle")
	eq(t.max_hearts, 4)
	var cash := t.cash
	check(t.sell("spare_paddle"))
	eq(t.cash, cash + RoadTrip.PRICES["common"] / 2, "half the price")
	eq(t.max_hearts, 3, "a SPARE PADDLE sold takes its heart")
	check(not t.sell("red_paddle"), "not the paddle in hand")
	check(t.sell("wood_paddle"))
	eq(t.choices_of("paddle"), ["red_paddle", "plain_paddle"])
	var d := RoadTrip.from_dict(t.to_dict())
	eq(d.locker, t.locker, "the locker is saved")


func test_sets() -> void:
	var t := RoadTrip.create(5, 0, RoadTrip.PEPPER)
	t.take("tricorn")
	eq(t.active_sets(), [])
	t.take("red_paddle")
	eq(t.active_sets().map(func(s): return s["id"]), ["pirate"], "TRICORN and RED PADDLE: the PIRATE'S KIT")
	eq(t.stats(), [1 + 3 + 5 + 2, 1, 1, 1 + 1])
	t.take("gold_paddle")
	eq(t.active_sets(), [], "the red paddle in the locker breaks the set")
	t.equip("red_paddle")
	eq(t.active_sets().size(), 1)
	eq(t.stat_parts()["sets"], [2, 0, 0, 1])


func test_items_of_the_second_round() -> void:
	var t := RoadTrip.create(21, 0, RoadTrip.PEPPER)
	t.take("tip_jar")
	var r := t.reachable()
	var cash := t.cash
	t.go(int(r[0][0]), int(r[0][1]))
	eq(t.cash, cash + 3, "a TIP JAR at every stop")
	t.take("partner_paddle")
	t.take("team_jerseys")
	eq(t.partner_now(), [9, 9, 9, 9], "partner gear: +2 and +1")
	eq(t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice).trip_stats[1],
		[9, 9, 9, 9])
	t.take("sunscreen")
	t.add_hazard("storm")
	eq(t.hazards, [], "SUNSCREEN takes the first hazard")
	t.add_hazard("storm")
	eq(t.hazards, ["storm"], "once a trip")
	# a CB RADIO's redraw: once a leg
	t.offer_pick("yard", 0)
	check(not t.can_redraw(), "no radio, no redraw")
	t.take("cb_radio")
	t.offer_pick("yard", 0)
	var first: Array = t.pending["items"].duplicate()
	check(t.redraw())
	check(t.pending["items"] != first, "new cards")
	check(not t.redraw(), "once a leg")
	# the diner: three of the four dishes and THE WORKS, for the next match only
	var menu := t.diner_menu()
	eq(menu.size(), 4)
	eq(menu[3], "works")
	eq(t.diner_menu(), menu, "the same menu each time")
	var before := t.stats()
	check(t.order(0))
	eq(t.stats(), before, "the meal isn't in your stats...")
	check(t.stats(true) != before, "...until the match")
	var cfg := t.config_for({"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice)
	eq(cfg.trip_stats[0], t.stats(true))
	t.at = [0, 0, 0]
	t.record_match(true)
	eq(t.meal, "", "eaten")
	# GAS CARD, LUCKY DICE, the new effects
	var d := RoadTrip.detour("drive_in")
	t.cash = 0
	check(not t.detour_choices(d)[0]["enabled"], "the movie costs 10")
	t.take("gas_card")
	check(t.detour_choices(d)[0]["enabled"], "free on the GAS CARD")
	t.choose(d, 0)
	eq(t.cash, 0)
	eq(t.boost, [0, 1, 0, 0], "+1 CONTROL for the rest of the trip")
	t.take("lucky_dice")
	var wins := 0
	for i in 5:
		t.stops = i
		t.choose(RoadTrip.detour("pie_contest"), 0)
	eq(t.cash, 200, "LUCKY DICE: every coin flip won")
	var miles := t.miles
	t.choose(RoadTrip.detour("car_wash"), 1)
	eq(t.miles, miles + 20)


func test_heals_and_miles() -> void:
	var t := RoadTrip.create(11, 0, RoadTrip.PEPPER)
	t.take("first_aid")
	t.take("thermos")
	t.take("mixtape")
	t.hearts = 1
	t.at = [0, RoadTrip.GATE, 0]
	var miles := t.miles
	t.record_match(true)
	eq(t.hearts, 3, "a heart for the big match (FIRST AID KIT), one for the new leg (THERMOS)")
	eq(t.miles, miles + 10, "+5 for a win, +5 from the MIXTAPE")
	eq(t.leg(), 1)


func test_the_road_hogs() -> void:
	var m := {"trips": 1, "won": 0, "hogs": 0, "beats": [], "story_pool": [], "tapes": [], "now": {},
		"miles": 0, "best_leg": 0, "partners": [], "heat": 0, "best_heat": -1, "last_item": ""}
	var t := RoadTrip.create(33, 0, RoadTrip.PEPPER, m)
	m["trips"] = 2                       # as RoadTrip.begin counts it
	var n: Dictionary = t.map[RoadTrip.RIVAL_LEG]["cols"][1].filter(func(x): return x["type"] == "rival")[0]
	eq(RoadTrip.opponent_name(n), "ROAD HOGS")
	eq(t.difficulty_for(n), K.DIFFICULTY_MEDIUM)
	n["level"] = 3
	eq(t.difficulty_for(n), K.DIFFICULTY_HARD, "serious after two losses")
	eq(t.local_members(n).size(), 2)
	eq(String(t.local_members(n)[0]["who"]), "BUCK")
	var pages := t.rival_pages(m)
	eq(pages, RoadTrip.beat("hogs_1")["pages"], "their first scene")
	check(m["beats"].has("hogs_1"))
	eq(t.rival_pages(m), RoadTrip.data()["scenes"]["rival_again"], "then a taunt")
	t.at = [RoadTrip.RIVAL_LEG, 1, t.map[1]["cols"][1].find(n)]
	t.record_match(true)
	check(t.rival_won)
	eq(t.pending.get("source"), "grudge", "a pick, as a grudge match")
	t.state = "over"
	var sv := SaveGame.new()
	sv.data = {"trip": m}
	t.finish(sv)
	eq(int(m["hogs"]), 1, "beaten: their story goes on")


func test_beats() -> void:
	var m := {"trips": 2, "won": 0, "hogs": 0, "beats": [], "story_pool": [], "tapes": []}
	var t := RoadTrip.create(8, 0, RoadTrip.PEPPER, m)
	eq(t.start_pages(m), RoadTrip.beat("van_1")["pages"], "the second trip opens on the van's story")
	eq(t.start_pages(m), RoadTrip.data()["scenes"]["start_again"], "once")
	t.partner = 3
	eq(t.start_pages(m), RoadTrip.data()["scenes"]["partner_start"][3], "a captain's own start")
	t.partner = RoadTrip.PEPPER
	eq(RoadTrip.beat_for(m, "motel", t.ctx(m))["id"], "van_2")
	eq(RoadTrip.beat_for(m, "motel", t.ctx(m, {"partner": 3})), {}, "Pepper's story needs Pepper")
	eq(RoadTrip.beat_for(m, "leg", t.ctx(m, {"leg": 1}))["id"], "tape_1")
	eq(RoadTrip.beat_for(m, "leg", t.ctx(m, {"leg": 2})), {}, "side B after side A")
	RoadTrip.see_beat(m, RoadTrip.beat("tape_1"))
	eq(m["tapes"], [1], "a tape for the deck")
	eq(RoadTrip.garage(m)["tapes"], [0, 1])
	eq(RoadTrip.beat_for(m, "team", t.ctx(m, {"team": 7})), {}, "the Champs' story after a trip won")
	m["won"] = 1
	eq(RoadTrip.beat_for(m, "team", t.ctx(m, {"team": 7}))["id"], "champs_1")
	eq(RoadTrip.beat_for(m, "team", t.ctx(m, {"team": 3})), {})
	# a reward on the road
	for id in ["van_1", "van_2", "van_3", "van_4"]:
		RoadTrip.see_beat(m, RoadTrip.beat(id))
	var b := RoadTrip.beat_for(m, "beaten", t.ctx(m, {"team": Opponents.DAWSON}))
	eq(b["id"], "van_5")
	RoadTrip.see_beat(m, b)
	check(RoadTrip.pool(m).has("grandpas_paddle"), "GRANDPA'S PADDLE on the road")
	eq(RoadTrip.arc_seen(m, "van").size(), 5)
	eq(RoadTrip.arc_hint(m, "van"), RoadTrip.beat("van_6")["hint"])
	# every beat's scene can be built
	for bt in RoadTrip.data()["beats"]:
		var sc := RoadTrip.beat_scene(bt)
		check(not sc["pages"].is_empty(), "a scene for " + String(bt["id"]))


func test_an_old_trip_loads() -> void:
	# a trip saved before the second round: no locker, boost, meal; a gen 1 map
	var t := RoadTrip.create(4127, 0, RoadTrip.PEPPER)
	var d := t.to_dict()
	for k in ["locker", "boost", "meal", "rival_won"]:
		d.erase(k)
	d["gen"] = 1
	var back := RoadTrip.from_dict(d)
	eq(back.locker, [])
	eq(back.boost, [0, 0, 0, 0])
	eq(back.stats(), [1, 1, 1, 1])
	back.take("red_paddle")
	eq(back.locker, ["plain_paddle"])
	var sv := SaveGame.new()
	sv.data = {"trip": {"miles": 10, "looks": {"van": 1, "ornament": 0}}}
	var m := RoadTrip.meta(sv)
	eq(m["looks"]["tape"], 0, "an old save's looks get the cassette")
	eq(m["beats"], [])
	eq(int(m["hogs"]), 0)
