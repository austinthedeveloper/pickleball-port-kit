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
