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
		check(int(g["icon"]) >= -1 and int(g["icon"]) < 40, "an icon on the sheet: " + String(g["id"]))
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
		if key == "teams":
			for t in d["scenes"]["teams"]:
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
