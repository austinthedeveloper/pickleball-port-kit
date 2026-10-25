## ROAD TRIP fuzzed (port ADR-087, 092, 093): whole trips played on paper
## with random choices (picks, redraws, the shop, selling, the locker,
## detours, the diner, the motel, wins and losses), checking after every
## step what must always hold: hearts, cash and stats in range, no paddle
## or hat lost or doubled, the save round trip exact, a way on while the
## trip is on, and an end in a bounded number of steps. Then the story
## across many trips on one lasting record (beats only after what they
## need, the SCRAPBOOK only growing), every map the story can draw, the
## islands and the day's trip end to end, and saves from before rounds
## two and three. Random but repeatable: every run uses the same seeds.
extends TestSuite

const TRIPS := 120
const STEPS := 140               ## a trip's stops, picks and replays, at most


## A lasting record as the save starts it (RoadTrip.meta fills it in).
func _meta() -> Dictionary:
	var sv := SaveGame.new()
	sv.data = {}
	return RoadTrip.meta(sv)


func _save_for(m: Dictionary) -> SaveGame:
	var sv := SaveGame.new()
	sv.data = {"trip": m}
	return sv


## The paddles (or hats) the trip holds: in hand and in the locker.
func _held(t: RoadTrip, kind: String) -> Array:
	var out: Array = t.choices_of(kind).duplicate()
	out.sort()
	return out


## What must hold at every step of a trip; the first breaks go in `bad`.
func _invariants(t: RoadTrip, owned: Dictionary, where: String, bad: Array) -> void:
	if bad.size() > 8:
		return
	if t.state == "on" and (t.hearts < 1 or t.hearts > t.max_hearts):
		bad.append("%s: hearts %d of %d" % [where, t.hearts, t.max_hearts])
	if t.max_hearts > RoadTrip.HEARTS_MAX or t.max_hearts < 1:
		bad.append("%s: max hearts %d" % [where, t.max_hearts])
	if t.cash < 0:
		bad.append("%s: cash %d" % [where, t.cash])
	for s in [t.stats(), t.stats(true), t.partner_now()]:
		for v in s:
			if int(v) < RoadTrip.STAT_MIN or int(v) > RoadTrip.STAT_MAX:
				bad.append("%s: a stat at %d (%s)" % [where, int(v), str(s)])
	for kind in ["paddle", "hat"]:
		var want: Array = owned[kind].duplicate()
		want.sort()
		if _held(t, kind) != want:
			bad.append("%s: %ss %s, owned %s" % [where, kind, str(_held(t, kind)), str(want)])
	var d := t.to_dict()
	if RoadTrip.from_dict(d).to_dict() != d:
		bad.append("%s: the save round trip changed the trip" % where)
	if t.state == "on" and t.pending.is_empty() and t.targets().is_empty():
		bad.append("%s: nowhere to go at %s" % [where, str(t.at)])
	var items: Array = t.pending.get("items", [])
	for id in items:
		if items.count(id) > 1:
			bad.append("%s: %s offered twice" % [where, String(id)])


## A trip's take of an item, kept in `owned` (paddles and hats).
func _take(t: RoadTrip, id: String, owned: Dictionary) -> void:
	var kind := String(RoadTrip.gear(id).get("kind", ""))
	t.take(id)
	if kind in ["paddle", "hat"]:
		owned[kind].append(id)


## A beat due at `slot`, seen, as main.gd shows it; `log` keeps the order.
func _beat(t: RoadTrip, m: Dictionary, slot: String, more: Dictionary, log: Array) -> void:
	if t.daily > 0:
		return
	var b := RoadTrip.beat_for(m, slot, t.ctx(m, more))
	if not b.is_empty():
		RoadTrip.see_beat(m, b)
		log.append(String(b["id"]))


## Plays one trip on paper to its end with `rng`'s choices (a win
## `win_pct` in 100), the story's slots as main.gd plays them. Returns
## the steps it took (STEPS + 1: it didn't end).
func _play(t: RoadTrip, m: Dictionary, rng: RandomNumberGenerator, win_pct: int, bad: Array, log: Array) -> int:
	var owned := {"paddle": [t.paddle], "hat": [t.hat]}
	var label := "seed %d" % t.seed
	for step in STEPS:
		_invariants(t, owned, "%s step %d" % [label, step], bad)
		if t.state != "on":
			return step
		if not t.pending.is_empty():
			var items: Array = t.pending.get("items", [])
			var reopened := RoadTrip.from_dict(t.to_dict())
			if reopened.pending.get("items", []) != items:
				bad.append("%s: a pick reopened shows other cards" % label)
			if t.can_redraw() and rng.randi_range(0, 3) == 0:
				t.redraw()
				continue
			if items.is_empty() or rng.randi_range(0, 5) == 0:
				t.skip_pick()
			else:
				_take(t, String(items[rng.randi_range(0, items.size() - 1)]), owned)
			continue
		# now and then a swap from the locker
		for kind in ["paddle", "hat"]:
			var all := t.choices_of(kind)
			if all.size() > 1 and rng.randi_range(0, 4) == 0:
				t.equip(String(all[rng.randi_range(1, all.size() - 1)]))
		var targets := t.targets()
		var target: Array = targets[rng.randi_range(0, targets.size() - 1)]
		var leg_before := t.leg()
		if not (t.is_gate() and int(target[0]) == RoadTrip.GATE):
			t.go(int(target[0]), int(target[1]))
		var n := t.here()
		var type := String(n["type"])
		match type:
			"pickup", "grudge", "rival", "big", "final", "encore":
				var team := int(n.get("team", -1))
				if type == "rival":
					t.rival_pages(m)
				elif team >= 0:
					_beat(t, m, "team", {"team": team, "encore": type == "encore"}, log)
				var won := rng.randi_range(0, 99) < win_pct
				t.record_match(won)
				if t.meal != "" or not t.hazards.is_empty():
					bad.append("%s: the meal or a hazard outlived the match" % label)
				if won:
					_beat(t, m, "beaten", {"team": team, "rival": type == "rival"}, log)
				if t.state == "on" and t.leg() != leg_before:
					_beat(t, m, "leg", {}, log)
			"yard":
				t.offer_pick("yard", 0)
				t.finish_stop()
			"shop":
				for k in rng.randi_range(0, 3):
					match rng.randi_range(0, 4):
						0:
							var stock := t.shop_stock(m)
							if not stock.is_empty():
								var id := String(stock[rng.randi_range(0, stock.size() - 1)])
								var kind := String(RoadTrip.gear(id).get("kind", ""))
								if t.buy(id) and kind in ["paddle", "hat"]:
									owned[kind].append(id)
						1:
							t.buy_soda()
						2:
							t.buy_fix()
						_:
							var sell := t.sellable()
							if not sell.is_empty():
								var sid := String(sell[rng.randi_range(0, sell.size() - 1)])
								var skind := String(RoadTrip.gear(sid).get("kind", ""))
								if t.sell(sid) and skind in ["paddle", "hat"]:
									owned[skind].erase(sid)
				t.finish_stop()
			"motel":
				_beat(t, m, "motel", {}, log)
				t.rest(rng.randi_range(0, 1) == 0)
				t.finish_stop()
			"diner":
				t.order(rng.randi_range(0, 3))
				t.finish_stop()
			"detour":
				var d := RoadTrip.detour(String(n["detour"]))
				if d.has("beat"):
					RoadTrip.see_beat(m, RoadTrip.beat(String(d["beat"])))
					log.append(String(d["beat"]))
				t.choose(d, rng.randi_range(-1, d["choices"].size() - 1))
				t.finish_stop()
	return STEPS + 1


func test_random_trips_keep_their_rules() -> void:
	var bad: Array = []
	var log: Array = []
	var rng := RandomNumberGenerator.new()
	var longest := 0
	for i in TRIPS:
		rng.seed = 9000 + i
		var m := _meta()
		m["miles"] = [0, 400, 99999][i % 3]
		m["trips"] = i % 4
		var t := RoadTrip.create(rng.randi(), i % (RoadTrip.HEAT_MAX + 1), RoadTrip.PEPPER, m)
		t._meta_for_draw = m
		var steps := _play(t, m, rng, [20, 50, 80, 100][i % 4], bad, log)
		longest = maxi(longest, steps)
		if steps > STEPS:
			bad.append("seed %d: no end after %d steps (at %s)" % [t.seed, STEPS, str(t.at)])
		t.finish(_save_for(m))
	eq(bad.slice(0, 8), [], "%d random trips keep every rule" % TRIPS)
	check(longest > 5, "the trips went somewhere (longest %d steps)" % longest)


## Many trips on one lasting record, partners and HEAT changing: beats
## only once and only after what they need, the SCRAPBOOK, the postcards
## and the bonds only ever growing, the islands opening once a story ends.
func test_the_story_across_many_trips() -> void:
	var m := _meta()
	var sv := _save_for(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var bad: Array = []
	var log: Array = []
	var before_beats: Array = []
	var before_cards := 0
	var before_bonds := 0
	for i in 50:
		var who: int = RoadTrip.PEPPER if i % 3 != 2 or m["partners"].is_empty() \
			else int(m["partners"][rng.randi_range(0, m["partners"].size() - 1)])
		var heat := rng.randi_range(0, int(m["heat"]))
		var t := RoadTrip.begin(sv, rng.randi(), heat, who)
		t.start_pages(m)
		var steps := _play(t, m, rng, 85, bad, log)
		if steps > STEPS:
			bad.append("trip %d never ended" % i)
		for leg in t.legs():
			for col in t.map[leg]["cols"]:
				for n in col:
					if n["type"] in ["pickup", "grudge", "rival"] and n["done"]:
						RoadTrip.postcard(m, "v:" + String(n["venue"]))
		var b := RoadTrip.beat_for(m, "won" if t.won_title() else "over", t.ctx(m, {"encore": t.encore_won()}))
		if not b.is_empty():
			RoadTrip.see_beat(m, b)
			log.append(String(b["id"]))
		t.finish(sv)
		var beats: Array = m["beats"]
		if beats.slice(0, before_beats.size()) != before_beats:
			bad.append("trip %d: the SCRAPBOOK lost or reordered a chapter" % i)
		if m["postcards"].size() < before_cards:
			bad.append("trip %d: a postcard went missing" % i)
		var bonds := 0
		for k in m["bonds"]:
			bonds += int(m["bonds"][k])
		if bonds < before_bonds:
			bad.append("trip %d: a bond went down" % i)
		before_beats = beats.duplicate()
		before_cards = m["postcards"].size()
		before_bonds = bonds
		eq(m["now"], {}, "trip %d: nothing left in progress" % i)
	var seen: Array = m["beats"]
	for k in seen.size():
		if seen.count(seen[k]) > 1:
			bad.append("%s seen twice" % seen[k])
		for need in RoadTrip.beat(String(seen[k])).get("when", {}).get("needs", []):
			if seen.find(String(need)) < 0 or seen.find(String(need)) > k:
				bad.append("%s before %s" % [seen[k], need])
	eq(bad.slice(0, 8), [], "50 trips on one record keep the story in order")
	check(seen.size() >= 6, "the story moved on over 50 trips (%d chapters: %s)" % [seen.size(), str(seen)])
	check(m["postcards"].size() > 0 and int(m["trips"]) == 50)
	if RoadTrip.islands_open(m):
		check(RoadTrip.create(1, 0, RoadTrip.PEPPER, m).legs() == 4, "the islands, once open, on every new trip")


## Every map the story can draw: every stop reachable from the leg's start,
## every stop with a way on to the gate, the gates right. (The leg rules
## are test_road_trip's: the generator keeps its 400th try when none keeps
## them, about 1 leg in 7,000, e.g. seed 123472's leg 3; reported, not
## asserted here.)
func test_every_story_map() -> void:
	var bad: Array = []
	for mask in 16:
		var ex := {"rival": mask & 1 != 0, "hogs": mask % 6, "detours": ["old_court"] if mask & 2 else [],
			"dawson": mask & 4 != 0, "islands": mask & 8 != 0}
		for s in 30:
			var heat := s % (RoadTrip.HEAT_MAX + 1)
			var map := RoadTrip.generate(s * 7717 + mask, heat, ex)
			if map.size() != (4 if ex["islands"] else 3):
				bad.append("mask %d seed %d: %d legs" % [mask, s, map.size()])
			for leg in map.size():
				var lm: Dictionary = map[leg]
				var reach := [0, 1, 2]
				for c in RoadTrip.COLS - 1:
					var next := []
					for lane in reach:
						var edges: Array = lm["cols"][c][lane]["edges"]
						if edges.is_empty():
							bad.append("mask %d seed %d: a dead end at %d %d %d" % [mask, s, leg, c, lane])
						for e in edges:
							if int(e) < 0 or int(e) >= RoadTrip.LANES or absi(int(e) - int(lane)) > 1:
								bad.append("mask %d seed %d: a bad road %d %d %d -> %d" % [mask, s, leg, c, lane, e])
							if not next.has(int(e)):
								next.append(int(e))
					next.sort()
					if next != [0, 1, 2]:
						bad.append("mask %d seed %d: leg %d column %d unreachable lanes" % [mask, s, leg, c + 1])
					reach = next
				var gate: Dictionary = lm["gate"]
				var want := "big"
				if leg == RoadTrip.LEGS - 1:
					want = "final"
				elif leg == RoadTrip.ISLANDS:
					want = "encore"
				if String(gate["type"]) != want:
					bad.append("mask %d seed %d leg %d: a %s gate" % [mask, s, leg, gate["type"]])
				if leg == RoadTrip.ISLANDS and int(gate["team"]) != Opponents.DAWSON:
					bad.append("mask %d seed %d: the encore against %d" % [mask, s, int(gate["team"])])
				for col in lm["cols"]:
					for n in col:
						if not Settings.VENUES.has(String(n["venue"])):
							bad.append("a venue the game hasn't: %s" % n["venue"])
	eq(bad.slice(0, 8), [], "every story map keeps its roads")


## The islands on paper: won from start to encore with every match won,
## more stops than a closed trip, the title and the encore both counted.
func test_the_islands_end_to_end() -> void:
	var m := _meta()
	m["best_heat"] = 5
	var rng := RandomNumberGenerator.new()
	for s in 10:
		rng.seed = 77 + s
		var t := RoadTrip.create(500 + s, 0, RoadTrip.PEPPER, m)
		t._meta_for_draw = m
		var bad: Array = []
		var steps := _play(t, m, rng, 100, bad, [])
		eq(bad.slice(0, 4), [], "seed %d" % t.seed)
		check(steps <= STEPS, "it ends")
		eq(t.state, "won")
		check(t.title and t.encore_won(), "the SUMMER OPEN and the encore")
		check(t.stops >= 15, "four legs of stops (%d)" % t.stops)
		check(t.beaten.has(Opponents.DAWSON) and t.beaten.has(7), "the Champs and the stranger beaten")
		var won_before := int(m["won"])
		t.finish(_save_for(m))
		eq(int(m["won"]), won_before + 1, "one trip won")
		check(not m["partners"].has(Opponents.DAWSON), "the stranger never partners you")


## TODAY'S TRIP is the same for every record: a full GARAGE, the islands
## open and a strong bond change nothing about it.
func test_the_days_trip_is_everyones() -> void:
	RoadTrip.date_override = 20261225
	var full := _meta()
	full["miles"] = 99999
	full["best_heat"] = 5
	full["bonds"] = {"-1": 99}
	full["trips"] = 9
	full["beats"] = ["van_1", "van_2"]
	var sv := _save_for(full)
	var a := RoadTrip.begin_daily(sv, RoadTrip.today())
	var b := RoadTrip.begin_daily(_save_for(_meta()), RoadTrip.today())
	eq(a.to_dict(), b.to_dict(), "the same trip from a full record and a new one")
	eq(a.legs(), 3, "no islands")
	eq(a.bag, [], "no bond item")
	eq(a.partner_stats, [RoadTrip.PARTNER_STAT, RoadTrip.PARTNER_STAT, RoadTrip.PARTNER_STAT,
		RoadTrip.PARTNER_STAT])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var log: Array = []
	var bad: Array = []
	_play(a, full, rng, 70, bad, log)
	eq(bad.slice(0, 4), [], "the day's trip keeps the rules")
	eq(log.filter(func(id): return not String(id).begins_with("van_3")), [], "and tells no story (%s)" % str(log))
	RoadTrip.date_override = 0


## Bonds rise with the points a trip earns and never skip a level's gifts.
func test_bonds_across_finishes() -> void:
	var m := _meta()
	var sv := _save_for(m)
	var levels: Array = []
	for i in 12:
		var t := RoadTrip.create(60 + i, 0, 4, m)
		var lv := RoadTrip.bond_level(m, 4)
		eq(t.partner_stats[0], RoadTrip.PARTNER_STAT + (1 if lv >= 1 else 0) + (1 if lv >= 3 else 0),
			"Raven's stats at level %d" % lv)
		eq(t.bag.has("ravens_parasol"), lv >= 2, "her parasol from level 2")
		t.wins = 2
		t.state = "over"
		t.finish(sv)
		levels.append(RoadTrip.bond_level(m, 4))
	for k in range(1, levels.size()):
		check(int(levels[k]) - int(levels[k - 1]) in [0, 1], "a level at a time: %s" % str(levels))
	eq(levels.back(), 3, "24 points: level 3")
	eq(RoadTrip.bond_points(m, RoadTrip.PEPPER), 0, "another partner's bond untouched")


## Saves from before rounds two and three: a lasting record and a trip
## in progress without any of the keys they added load and play to the end.
func test_old_saves_play_on() -> void:
	var sv := SaveGame.new()
	sv.data = {"trip": {"miles": 300, "trips": 4, "won": 1, "best_heat": 0, "best_leg": 3, "heat": 1,
		"partners": [0, 1], "seen": 0, "looks": {"van": 1, "ornament": 0}, "last_item": "", "now": {}}}
	var m := RoadTrip.meta(sv)
	for k in ["hogs", "beats", "story_pool", "tapes", "bonds", "bond_seen", "daily", "daily_won", "postcards", "pens"]:
		check(m.has(k), "an old record gets " + k)
	eq(m["looks"], {"van": 1, "ornament": 0, "tape": 0, "pen": 0})
	var t := RoadTrip.create(4127, 1, 0, m)
	var d := t.to_dict()
	for k in ["locker", "boost", "meal", "rival_won", "daily", "title"]:
		d.erase(k)
	d["gen"] = 1
	m["now"] = d
	var back := RoadTrip.current(sv)
	check(back != null, "the old trip in progress loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad: Array = []
	var steps := _play(back, m, rng, 60, bad, [])
	eq(bad.slice(0, 4), [], "and keeps every rule")
	check(steps <= STEPS, "to its end")
	back.finish(sv)
	eq(m["now"], {})


## The data's references: venues the game has, the bonds' items, the
## encore's venue, every gear id the trip names anywhere.
func test_the_datas_references() -> void:
	var d := RoadTrip.data()
	var ids: Array = d["gear"].map(func(g): return String(g["id"]))
	var bad: Array = []
	for leg in d["legs"]:
		for v in leg["venues"] + ([leg["encore_venue"]] if leg.has("encore_venue") else []):
			if not Settings.VENUES.has(String(v)):
				bad.append("venue " + String(v))
		for t in leg["grudge"] + leg["big"]:
			if not Opponents.exists(int(t)):
				bad.append("team %d" % int(t))
	for k in ["-1", "0", "1", "2", "3", "4", "5", "6", "7"]:
		if not d["bonds"].has(k):
			bad.append("no bond for partner " + k)
			continue
		var item := String(d["bonds"][k]["item"])
		if not ids.has(item) or String(RoadTrip.gear(item)["rarity"]) != "bond":
			bad.append("bond item " + item)
	for st in d["sets"]:
		for id in st["items"]:
			if not ids.has(String(id)):
				bad.append("set item " + String(id))
	for b in d["beats"]:
		for id in b.get("reward", {}).get("pool", []):
			if not ids.has(String(id)):
				bad.append("reward " + String(id))
		if b.get("reward", {}).has("pen") and int(b["reward"]["pen"]) >= d["pens"].size():
			bad.append("pen %d" % int(b["reward"]["pen"]))
	for g in d["gear"]:
		if String(g["rarity"]) == "bond" and (d["start_pool"].has(g["id"]) or _on_ladder(String(g["id"]))):
			bad.append("a bond item on the road: " + String(g["id"]))
	eq(bad, [], "every reference in trip.json is to something there")


func _on_ladder(id: String) -> bool:
	for step in RoadTrip.data()["ladder"]:
		if step.get("pool", []).has(id):
			return true
	return false
