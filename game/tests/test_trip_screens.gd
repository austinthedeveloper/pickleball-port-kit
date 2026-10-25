## ROAD TRIP's screens (port ADR-087), driven through the real main scene:
## the title's ROAD TRIP row, the home (NEW TRIP, PARTNER, HEAT, GARAGE),
## the start scene, the map (stops by id, the van's drive), each kind of
## stop (a match and its result, the yard sale's pick, the shop, the
## motel, a detour), a trip lost and its results, and a match that records
## nothing outside the trip.
extends TestSuite

const DIR := "user://test_trip_main/"


func _main() -> Node:
	SaveGame.default_dir = DIR
	wipe_saves(DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	return main


func _settle(main: Node) -> Node:
	for f in main.FADE_OUT + main.FADE_IN + 2:
		main._physics_process(1.0 / 60.0)
	var s: Node = main._screen
	if not s.is_node_ready() and s.has_method("_ready"):
		s._ready()
	return s


## A node added under a screen in the tests' tree, made ready (the root
## isn't during the suites).
func _ready(n: Node) -> void:
	if not n.is_node_ready():
		n._ready()


## A scene's first choice you can take.
func _choose_any(s: TripScene) -> void:
	for i in s.choices.size():
		if s.choices[i].get("enabled", true):
			s.choose("choice_%d" % i)
			return


func _done(main: Node, kept: String) -> void:
	main.free()
	wipe_saves(DIR)
	SaveGame.default_dir = kept


## Title > ROAD TRIP > NEW TRIP > the start scene > the map.
func _to_map(main: Node) -> TripMap:
	var t: TitleScreen = main._screen
	if not t.is_node_ready():
		t._ready()
	t.pages["main"].select("trip")
	t.pages["main"].press()
	var home: TripHome = _settle(main)
	home.page.select("new")
	home.page.press()
	var sc: TripScene = _settle(main)
	sc.done.emit(-1)
	return _settle(main)


func test_title_to_the_map() -> void:
	var kept := SaveGame.default_dir
	var main := _main()
	var t: TitleScreen = main._screen
	if not t.is_node_ready():
		t._ready()
	eq(t.pages["main"].value_of("trip"), "", "no trips yet")
	t.pages["main"].select("trip")
	t.pages["main"].press()
	var home: TripHome = _settle(main)
	check(home is TripHome, "ROAD TRIP's home")
	eq(home.page.index_of("continue"), -1, "nothing to continue")
	eq(home.page.value_of("partner"), "PEPPER")
	home.page.select("partner")
	home.page.change(1)
	eq(home.page.value_of("partner"), "PEPPER", "no captains beaten yet: Pepper only")
	home.page.select("heat")
	home.page.change(1)
	eq(home.page.value_of("heat"), "0", "HEAT 1 opens with a trip won")
	home.page.select("new")
	home.page.press()
	var sc: TripScene = _settle(main)
	check(sc is TripScene, "the start scene")
	var trip := RoadTrip.current(main.save)
	check(trip != null, "a trip in progress, saved")
	eq(trip.stats(), [1, 1, 1, 1])
	sc.done.emit(-1)
	var map: TripMap = _settle(main)
	check(map is TripMap, "the map")
	eq(map._targets.size(), RoadTrip.LANES, "the first column's three stops")
	check(map.select("stop_0_0_2"), "a stop by id")
	eq(map.current_id(), "stop_0_0_2")
	check(not map.select("stop_0_1_0"), "not a stop out of reach")
	# the title shows it in progress
	map._leave()
	home = _settle(main)
	eq(home.page.index_of("continue"), 0, "CONTINUE comes first")
	eq(home.page.value_of("continue"), "LEG 1, 3 HEARTS")
	home.page.select("back")
	home.page.press()
	t = _settle(main)
	eq(t.pages["main"].value_of("trip"), "LEG 1/3")
	_done(main, kept)


## Drives to a stop of a type; true if there was one.
func _drive_to(main: Node, map: TripMap, type: String) -> bool:
	for target in map._targets:
		if String(map.trip.node_for(target)["type"]) == type:
			map.select(map.target_id(target))
			map.press()
			for f in TripMap.DRIVE_FRAMES + 2:
				map._process(1.0 / 60.0)
			return true
	return false


func test_every_kind_of_stop() -> void:
	for s in [4127, 11, 2026]:
		_every_kind_of_stop(s)


func _every_kind_of_stop(seed_value: int) -> void:
	var kept := SaveGame.default_dir
	TripHome.seed_override = seed_value
	var main := _main()
	var map := _to_map(main)
	var seen := {}
	for step in 40:
		if map.pick:
			_ready(map.pick)
			map.pick.take()
		var trip: RoadTrip = map.trip
		if trip.state != "on":
			break
		var target: Array = map._targets[0]
		var n := trip.node_for(target)
		map.select(map.target_id(target))
		map.press()
		for f in TripMap.DRIVE_FRAMES + 2:
			map._process(1.0 / 60.0)
		var type := String(n["type"])
		seen[type] = true
		var s: Node = _settle(main)
		match type:
			"pickup":
				check(s is MatchView and s.trip, "a pickup game is a match")
				_win(main, s)
			"grudge", "big", "final", "rival":
				check(s is TripScene and s.pages[0].get("card", false), "%s: its card first" % type)
				s.done.emit(-1)
				var m: MatchView = _settle(main)
				check(m.trip and m.sim.config.trip == 1, "a trip match")
				eq(m.sim.config.opponent, int(n["team"]))
				_win(main, m)
			"diner":
				check(s is TripScene and s.choices.size() == 4, "the diner's menu")
				_choose_any(s)
			"yard":
				check(s is TripScene)
				s.done.emit(-1)
				map = _settle(main)
				check(map.pick != null, "the yard sale's pick, over the map")
				continue
			"shop":
				check(s is TripShop)
				s.page.select("leave")
				s.page.press()
			"motel":
				check(s is TripScene and not s.choices.is_empty())
				_choose_any(s)
			"detour":
				check(s is TripScene and s.choices.size() >= 2, "a detour's choices")
				_choose_any(s)
		var next: Node = _settle(main)
		for k in 4:                            # the story's scenes after a match, the closing one
			if not next is TripScene:
				break
			next.done.emit(-1)
			next = _settle(main)

		if next is TripHome:
			break
		check(next is TripMap, "back to the map after a %s" % type)
		map = next
	check(seen.has("pickup") or seen.has("grudge"), "matches were played")
	check(seen.has("big") and seen.has("final"), "the big matches and the final")
	var home: Node = main._screen
	check(home is TripHome and home.view == "results", "the trip won: its results at home")
	eq(int(RoadTrip.meta(main.save)["won"]), 1)
	eq(RoadTrip.current(main.save), null)
	eq(int(main.save.data["records"]["doubles_wins"]), 0, "a trip's wins count only in the trip")
	TripHome.seed_override = 0
	_done(main, kept)


## Ends a match on screen as a win and goes on (B on the result).
func _win(main: Node, m: MatchView) -> void:
	m.sim.team_score = [m.sim.config.points_to_win, 0]
	m.sim.match_winner = 0
	m.sim.set_phase(K.PHASE_MATCH_RESULT)
	m.finished.emit(false)


func test_a_trip_lost() -> void:
	var kept := SaveGame.default_dir
	TripHome.seed_override = 9
	var main := _main()
	var map := _to_map(main)
	for step in 30:
		var trip: RoadTrip = map.trip
		if trip.state != "on":
			break
		if map.pick:
			_ready(map.pick)
			map.pick.skip()
		var n := trip.node_for(map._targets[0])
		map.select(map.target_id(map._targets[0]))
		map.press()
		for f in TripMap.DRIVE_FRAMES + 2:
			map._process(1.0 / 60.0)
		var s: Node = _settle(main)
		if s is TripScene and s.choices.is_empty() and s.pages[0].get("card", false):
			s.done.emit(-1)
			s = _settle(main)
		if s is MatchView:
			s.finished.emit(true)        # MENU before it's over: a loss
			var home: Node = _settle(main)
			if home is TripHome:
				var t2 := RoadTrip.current(main.save)
				if t2 == null:
					break
				home.page.select("continue")
				home.page.press()
				map = _settle(main)
				continue
			if home is TripScene:
				home.done.emit(-1)
				break
		elif s is TripScene:
			if s.choices.is_empty():
				s.done.emit(-1)
			else:
				_choose_any(s)
		elif s is TripShop:
			s.page.select("leave")
			s.page.press()
		var nxt: Node = _settle(main)
		if not nxt is TripMap:
			break
		map = nxt
	var home2: Node = _settle(main)
	check(home2 is TripHome and home2.view == "results", "the trip over: its results")
	var m := RoadTrip.meta(main.save)
	eq(m["now"], {})
	check(int(m["miles"]) > 0, "the miles go to the GARAGE")
	home2._close_results()
	home2.page.select("garage")
	home2.page.press()
	eq(home2.view, "garage")
	home2.garage_page.select("van")
	home2.garage_page.change(1)
	eq(home2.garage_page.value_of("van"), "CREAM AND SKY", "no paint jobs yet")
	home2._close_garage()
	TripHome.seed_override = 0
	_done(main, kept)


## A second trip (port ADR-092): it opens on the van's story, THE VAN opens
## over the map and swaps a paddle from the locker, the ROAD HOGS turn up
## on the long drive (their scene, their names, their match), and the
## SCRAPBOOK plays a chapter again and comes back.
func test_the_story_across_trips() -> void:
	var kept := SaveGame.default_dir
	TripHome.seed_override = 77
	var main := _main()
	var m := RoadTrip.meta(main.save)
	m["trips"] = 1
	m["won"] = 1
	var map := _to_map(main)
	check(m["beats"].has("van_1"), "the second trip opened on the van's story")
	var trip: RoadTrip = map.trip
	trip.take("red_paddle")
	trip.take("gold_paddle")
	map.open_van()
	_ready(map.van)
	check(map.van is TripVan, "THE VAN over the map")
	map.van.page.select("paddle")
	map.van.page.change(1)
	eq(trip.paddle, "plain_paddle", "the next paddle in the locker")
	map.van.close()
	eq(map.van, null)
	eq(RoadTrip.current(main.save).paddle, "plain_paddle", "the swap is saved")
	# drive to the ROAD HOGS: win everything on the way
	var met := false
	for step in 30:
		if map.pick:
			_ready(map.pick)
			map.pick.take()
		trip = map.trip
		if trip.state != "on" or trip.leg() > RoadTrip.RIVAL_LEG:
			break
		var target: Array = map._targets[0]
		var rl: int = trip.map[RoadTrip.RIVAL_LEG]["cols"][1].map(func(x): return x["type"]).find("rival")
		for tg in map._targets:
			if trip.leg() == RoadTrip.RIVAL_LEG and int(tg[1]) == rl:
				target = tg                  # the road to the ROAD HOGS (every stop has one to its own lane)
		var n := trip.node_for(target)
		map.select(map.target_id(target))
		map.press()
		for f in TripMap.DRIVE_FRAMES + 2:
			map._process(1.0 / 60.0)
		var s: Node = _settle(main)
		if String(n["type"]) == "rival":
			check(s is TripScene and not s.members.is_empty(), "the ROAD HOGS' scene")
			eq(s.who_name("captain"), "BUCK")
			eq(s.pages[1], RoadTrip.beat("hogs_1")["pages"][0], "their first meeting")
			s.done.emit(-1)
			var mv: MatchView = _settle(main)
			eq(mv.trip_name, "ROAD HOGS")
			met = true
			_win(main, mv)
		elif s is MatchView:
			_win(main, s)
		elif s is TripScene:
			if s.choices.is_empty():
				s.done.emit(-1)
				s = _settle(main)
				if s is MatchView:
					_win(main, s)
			else:
				_choose_any(s)
		elif s is TripShop:
			s.page.select("leave")
			s.page.press()
		var nxt: Node = _settle(main)
		for k in 4:
			if not nxt is TripScene:
				break
			nxt.done.emit(-1)
			nxt = _settle(main)
		if not nxt is TripMap:
			break
		map = nxt
	check(met, "the ROAD HOGS on the long drive")
	check(map.trip.rival_won, "and beaten")
	# the SCRAPBOOK
	map._leave()
	var home: TripHome = _settle(main)
	home.page.select("scrapbook")
	home.page.press()
	eq(home.view, "scrapbook")
	home.scrap_page.select("van")
	home.scrap_page.press()
	var sc: Node = _settle(main)
	check(sc is TripScene, "a chapter watched again")
	eq(sc.pages, RoadTrip.beat("van_1")["pages"])
	sc.done.emit(-1)
	home = _settle(main)
	eq(home.view, "scrapbook", "back in the SCRAPBOOK")
	TripHome.seed_override = 0
	_done(main, kept)
