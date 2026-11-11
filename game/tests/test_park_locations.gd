## OPEN PLAY's locations (PORT-57, ADR-078): THE PARK, DINO PARK and THE GYM,
## one plan (the sim's) in three looks; chosen on the title's OPEN PLAY
## row, saved; each park's games play at its venue (THE GYM's: the indoor
## GYM, always lit).
extends TestSuite


func test_the_locations() -> void:
	eq(Settings.PARKS.size(), 3)
	for k in Settings.PARKS.size():
		var loc: Array = Settings.PARKS[k]
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(loc[2]) + "park.json"))
		check(layout != null and layout["sprites"].size() > 20, "%s: its layout" % loc[1])
		eq([int(layout["world"][0]), int(layout["world"][1])], [2240, 870], "%s: the same world (the same plan)" % loc[1])
		check(ResourceLoader.exists(String(loc[2]) + "ground.png"), "%s: its ground" % loc[1])
		for spr in layout["sprites"]:
			check(ResourceLoader.exists(String(loc[2]) + String(spr["file"])), "%s: %s" % [loc[1], spr["file"]])
		check(String(loc[3]) in Settings.VENUES, "%s plays at a venue (%s)" % [loc[1], loc[3]])
	eq(Settings.PARKS[1][3], "dinosaur", "DINO PARK's games: the DINOSAUR venue")
	eq(Settings.PARKS[2][3], "gym", "THE GYM's: the indoor GYM")


## Each location's ParkView builds, with its own art and background.
func test_the_views() -> void:
	var kept := Settings.park_i
	for k in Settings.PARKS.size():
		Settings.park_i = k
		var op := OpenPlay.new()
		op.begin(4242, false)
		var pv := ParkView.new().setup(op, null, false)
		runner.root.add_child(pv)
		eq(pv.art, String(Settings.PARKS[k][2]), "%s: its art" % Settings.PARKS[k][1])
		check(pv.get_child_count() > 3, "it builds")
		pv.free()
	Settings.park_i = kept


## The title's OPEN PLAY row picks the location (Left/Right), saved.
func test_the_row() -> void:
	var kept := Settings.park_i
	var sv := fresh_save("user://test_park_locations/")
	var t := title_screen(sv)
	Settings.park_i = 0
	var p: MenuPage = t.reveal("openplay")
	eq(p.value_of("openplay"), "THE PARK")
	p.change(1)
	eq(p.value_of("openplay"), "DINO PARK")
	p.change(1)
	eq(p.value_of("openplay"), "THE GYM")
	p.change(1)
	eq(p.value_of("openplay"), "THE PARK", "around again")
	p.change(-1)
	t._store_settings()
	Settings.park_i = 0
	Settings.load_from(sv)
	eq(Settings.park_i, 2, "saved")
	eq(Settings.park_venue(), "gym")
	t.free()
	Settings.park_i = kept
	wipe_saves("user://test_park_locations/")


## PORT-163 (port ADR-112): 2P walks the park. With 2P in open play a
## follower in 2P's look (not your shirt) walks your trail and stands beside
## you when you stop; without 2P there's none. Display only: the park's
## state is the same as without the follower.
func test_two_p_walks_the_park() -> void:
	var states := []
	for with_view in [true, false]:
		var op := OpenPlay.new()
		op.begin(4242, false)
		op.two_players = 1
		var pv: ParkView = ParkView.new().setup(op, null, false) if with_view else null
		if pv:
			runner.root.add_child(pv)
			pv.input_lock = 0
			eq(int(pv.two_p_choice()["palette"]) != int(Settings.p1_choice["palette"]), true, "2P in another shirt")
		var it := SimTypes.Intent.new()
		it.move_x = 1
		var xs := []
		for f in 60:
			if pv:
				pv.step_frame(it, false)
			else:
				op.update(it.move_x, it.move_y, false)
			if pv and f > 30:
				var at: Variant = pv.two_p_at()
				check(at != null and pv._two["root"].visible, "2P is with you (frame %d)" % f)
				xs.append((at as Vector2).x - K.from_fp(op.x_fp))
		if pv:
			check(xs.all(func(d): return d < 0), "walking right, 2P is behind you: %s" % str(xs.slice(0, 4)))
			var still := SimTypes.Intent.new()
			for f in 30:
				pv.step_frame(still, false)
			var at: Vector2 = pv.two_p_at()
			eq(at, Vector2(K.from_fp(op.x_fp), K.from_fp(op.y_fp)) + ParkView.BESIDE, "stopped: 2P beside you")
			op.two_players = 0
			pv.step_frame(still, false)
			check(not pv._two["root"].visible, "2P left: no follower")
			op.two_players = 1
			pv.free()
		else:
			for f in 30:
				op.update(0, 0, false)
		states.append([op.x_fp, op.y_fp, op.facing_left, op.walking])
	eq(states[0], states[1], "the park's state doesn't know the follower is drawn")
