## Renders a ROAD TRIP screen (port ADR-087) and saves it (needs a display):
##   godot --path game --resolution 960x540 -s res://tools/trip_shot.gd -- <screen> <frames> <out.png> [seed=N] [pad]
## Screens: home, garage, results, map (a trip some stops in, gear on),
## map_start (a new trip), pick, shop, card (a big match's card), team (its
## scene), detour, motel, start; and port ADR-092's van (THE VAN),
## scrapbook, diner, rival (the ROAD HOGS' scene), old_court (a story
## detour), drive_in (a detour at a venue). A scratch save, nothing written.
extends SceneTree

var _frames := 0
var _target := 60
var _out := "user://trip_shot.png"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var screen: String = a[0] if a.size() > 0 else "map"
	_target = int(a[1]) if a.size() > 1 else 60
	_out = a[2] if a.size() > 2 else "user://trip_shot.png"
	var seed_value := 4127
	for arg in a.slice(3):
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		if arg == "pad":
			GameControls.last_device = GameControls.PAD
	var controls = load("res://game_ui/controls.gd").new()
	root.add_child(controls)
	var sv := SaveGame.new()
	sv.dir = "user://trip_shot_save/"
	sv.data = SaveGame.defaults()
	sv.career = Career.new()
	var m := RoadTrip.meta(sv)
	m["miles"] = 760
	m["trips"] = 6
	m["won"] = 1
	m["best_heat"] = 0
	m["best_leg"] = 3
	m["heat"] = 1
	m["partners"] = [0, 1, 3]
	m["looks"] = {"van": 2, "ornament": 1, "tape": 1}
	m["beats"] = ["van_1", "van_2", "hogs_1", "tape_1", "champs_1"]
	m["tapes"] = [1]
	var t := RoadTrip.create(seed_value, 0, RoadTrip.PEPPER, m)
	t._meta_for_draw = m
	if screen != "map_start" and screen != "start" and not "plain" in a:
		_advance(t, 4)
		for id in ["red_paddle", "visor", "grip_tape", "grip_tape", "spare_paddle", "pickle_jar", "dink_drill",
				"tricorn", "wood_paddle", "tip_jar"]:
			t.take(id)
		t.equip("red_paddle")
		t.meal = "pancakes"
		t.boost = [0, 1, 0, 0]
		t.cash = 85
		t.hearts = 3
		t.hazards = ["storm"]
	t.store(sv)
	var view: Node
	match screen:
		"home", "garage":
			var h := TripHome.new().setup(sv)
			view = h
			root.add_child(h)
			if screen == "garage":
				h.ready.connect(h._open_garage)
		"results":
			view = TripHome.new().setup(sv, {"won": false, "leg": 2, "wins": 5, "losses": 3, "stops": 7,
				"miles": 150, "steps": [12, 13]})
			root.add_child(view)
		"map", "map_start":
			view = TripMap.new().setup(sv, t)
			root.add_child(view)
		"pick":
			t.offer_pick("grudge", 1)
			view = TripMap.new().setup(sv, t)
			root.add_child(view)
		"shop":
			view = TripShop.new().setup(sv, t)
			root.add_child(view)
		"card", "team":
			var n: Dictionary = t.map[t.leg()]["gate"]
			var team := int(n["team"])
			var info := t.info(n)
			var s := TripScene.new().setup(t, RoadTrip.data()["scenes"]["teams"][team], _me(t, sv), "YOU",
				{"venue": String(n["venue"]), "time": int(n["time"]), "team": team,
				"card": {"over": "LEG 1: OUT OF TOWN", "title": RoadTrip.stop_name(n),
					"lines": ["VS " + RoadTrip.opponent_name(n), String(info[1])]}})
			if screen == "team":
				s.page = 1
				s._show_page()
			view = s
			root.add_child(s)
		"detour":
			var d := RoadTrip.detour("noise")
			var s2 := TripScene.new().setup(t, [{"who": "narrator", "lines": d["lines"]}], _me(t, sv), "YOU",
				{"art": "roadside", "choices": [{"label": String(d["choices"][0]["label"]), "enabled": true},
					{"label": String(d["choices"][1]["label"]), "enabled": true}]})
			s2._open_choices()
			view = s2
			root.add_child(s2)
		"motel":
			var s3 := TripScene.new().setup(t, RoadTrip.data()["scenes"]["motel"], _me(t, sv), "YOU",
				{"art": "motel"})
			view = s3
			root.add_child(s3)
		"match":
			var n2: Dictionary = {}
			for col in t.map[t.leg()]["cols"]:
				for nn in col:
					if String(nn["type"]) == "pickup" and n2.is_empty():
						n2 = nn
			var mv := MatchView.new()
			mv.trip = true
			mv.trip_name = RoadTrip.opponent_name(n2)
			mv.trip_members = t.local_members(n2)
			mv.trip_plain = "plain" in a
			root.add_child(mv)
			mv.time = int(n2["time"])
			mv.setup(t.config_for(n2, Settings.p1_choice, false, null), String(n2["venue"]), false)
			mv.card_frames = -1
			mv.sim.p1_bot = true
			view = mv
		"van":
			view = TripVan.new().setup(sv, t)
			root.add_child(view)
		"scrapbook":
			view = TripHome.new().setup(sv, {}, "scrapbook")
			root.add_child(view)
		"diner":
			var sd := TripScene.new().setup(t, RoadTrip.data()["scenes"]["diner"], _me(t, sv), "YOU",
				{"art": "diner", "choices": t.diner_choices()})
			sd._open_choices()
			view = sd
			root.add_child(sd)
		"rival":
			var sr := TripScene.new().setup(t, RoadTrip.beat("hogs_1")["pages"], _me(t, sv), "YOU",
				{"venue": "western", "time": CourtStyle.DUSK, "members": RoadTrip.rival_members()})
			sr.page = 1
			sr._show_page()
			view = sr
			root.add_child(sr)
		"old_court", "drive_in":
			var dd := RoadTrip.detour(screen)
			var sc := RoadTrip.detour_scene(dd)
			var opts: Dictionary = sc["opts"]
			opts["choices"] = t.detour_choices(dd)
			var so := TripScene.new().setup(t, sc["pages"], _me(t, sv), "YOU", opts)
			if screen == "old_court":
				so.page = 1
				so._show_page()
			view = so
			root.add_child(so)
		"start":

			var s4 := TripScene.new().setup(t, RoadTrip.data()["scenes"]["start"], _me(t, sv), "YOU",
				{"art": "garage"})
			view = s4
			root.add_child(s4)


func _me(t: RoadTrip, sv: SaveGame) -> PlayerLook:
	var d := t.driver(sv.career.active_player(), Settings.p1_choice)
	return PlayerLook.for_career(d, d.shirt, d.variant, d.paddle, MatchView.levels_manifest())


## Plays the first `n` stops of the trip on its first road, winning.
func _advance(t: RoadTrip, n: int) -> void:
	for i in n:
		var r := t.reachable()
		if r.is_empty():
			return
		var node := t.go(int(r[0][0]), int(r[0][1]))
		if t.is_match(node):
			t.record_match(true)
		else:
			t.finish_stop()
		t.pending = {}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= _target:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit()
	return false
