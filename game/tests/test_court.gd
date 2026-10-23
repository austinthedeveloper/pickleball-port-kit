## PORT-05: court colours (ADR-022/027), test_court_style.c's checks for
## the port: DEFAULT is the paint pixel for pixel, a preset touches only
## its part's roles, out of range is DEFAULT, and every preset keeps the
## lines and the ball readable (playbook §4.7) at every venue.
extends TestSuite

var manifest: Dictionary


func _manifest() -> Dictionary:
	if manifest.is_empty():
		manifest = MatchView.levels_manifest()
	return manifest


func test_presets_match_the_data() -> void:
	var d := CourtStyle.data()
	eq(CourtStyle.count("surface"), d["parts"]["surface"]["presets"].size() + 1, "DEFAULT + surfaces")
	eq(CourtStyle.names("kitchen")[0], "SAME", "the kitchen starts on SAME")
	eq(CourtStyle.count("kitchen"), d["parts"]["kitchen"]["presets"].size())
	eq(CourtStyle.names("lines"), ["DEFAULT", "WHITE", "YELLOW", "CYAN", "LIME"])
	for part in CourtStyle.PARTS:
		for n in CourtStyle.names(part):
			check(String(n).length() <= 8, "%s fits eight cells" % n)
	eq(CourtStyle.preset("surface", 1), Color8(38, 92, 168), "BLUE")
	check(CourtStyle.preset("surface", 0) == null, "DEFAULT is the paint")
	check(CourtStyle.preset("surface", 99) == null and CourtStyle.preset("lines", -1) == null,
		"out of range counts as DEFAULT")


func test_default_is_the_paint_pixel_for_pixel() -> void:
	var m := _manifest()
	for venue in Settings.VENUES:
		check(CourtStyle.material(CourtStyle.DEFAULTS, venue, m) == null,
			"%s: all DEFAULT leaves the ground layer unshaded" % venue)
		var targets := CourtStyle.role_targets(CourtStyle.DEFAULTS, venue, m)
		var ground := (load(MatchView.LEVELS + "venues/%s/ground.png" % venue) as Texture2D).get_image()
		var same := true
		for y in range(0, ground.get_height(), 7):
			for x in range(0, ground.get_width(), 7):
				var c := ground.get_pixel(x, y)
				for role in 9:
					if CourtStyle.recolor(c, role, targets) != c:
						same = false
		check(same, "%s: the recolour is the identity" % venue)
	var view := MatchView.new()
	runner.root.add_child(view)
	view.setup(SimTypes.MatchConfig.singles(), "park", false)
	check(view._ground != null and view._ground.material == null, "a default match draws the paint")
	view.set_court([1, 0, 0, 0])
	check(view._ground.material is ShaderMaterial, "a preset shades the ground")
	view.set_court(CourtStyle.DEFAULTS)
	check(view._ground.material == null, "back to DEFAULT")
	view.free()


## ADR-046: the fun venues paint their venues.json ground presets, so
## DEFAULT there is the preset the SNES named (GREEN / ORANGE / GRASS /
## WHITE at DINOSAUR, and so on). (PARK, LAKESIDE and SUNSET keep the
## level mocks' own paint.)
func test_fun_venues_paint_their_presets() -> void:
	var m := _manifest()
	var venues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/venues.json"))
	var checked := 0
	for v in venues["venues"]:
		var venue := String(v["name"]).to_lower()
		if not venue in ["dinosaur", "space", "undersea", "gym", "ruins", "glacier", "lab", "station"]:
			continue
		check(venue in Settings.VENUES, "%s is a venue" % venue)
		for part in CourtStyle.PARTS:
			var want: Variant = CourtStyle.preset(part, CourtStyle.names(part).find(v["ground"][part]))
			check(want != null, "%s %s names a preset" % [venue, part])
			if want == null:
				continue
			var got := CourtStyle.venue_base(venue, part, m)
			var off := maxf(absf(got.r - want.r), maxf(absf(got.g - want.g), absf(got.b - want.b)))
			check(off <= 0.06 or (part == "lines" and got.get_luminance() > 0.85 * want.get_luminance()),
				"%s %s paints %s (%s vs %s)" % [venue, part, v["ground"][part], got, want])
			checked += 1
	eq(checked, 32, "eight venues (the fun ones, the GYM, the dinosaur game's four), four parts")


func test_a_preset_touches_only_its_part() -> void:
	var m := _manifest()
	var parts_with := func(choice: Array) -> Array:
		var out := []
		var t := CourtStyle.role_targets(choice, "park", m)
		for role in 9:
			if t[role][0] != null and not CourtStyle.ROLE_PART[role] in out:
				out.append(CourtStyle.ROLE_PART[role])
		out.sort()
		return out
	eq(parts_with.call([1, 0, 0, 0]), ["kitchen", "surface"], "a surface takes a SAME kitchen along")
	eq(parts_with.call([0, 3, 0, 0]), ["kitchen"], "a kitchen alone")
	eq(parts_with.call([0, 0, 2, 0]), ["surround"])
	eq(parts_with.call([0, 0, 0, 1]), ["lines"])
	eq(CourtStyle.resolve([4, 0, 0, 0])["kitchen"], CourtStyle.preset("surface", 4), "SAME follows the surface")
	var targets := CourtStyle.role_targets([2, 0, 0, 0], "park", m)
	var base := CourtStyle.venue_base("park", "surface", m)
	var out := CourtStyle.recolor(base, 3, targets)
	check(out.is_equal_approx(CourtStyle.preset("surface", 2)), "the painted base becomes the preset")
	var dark := CourtStyle.recolor(base.darkened(0.3), 3, targets)
	check(CourtStyle.brightness(dark) < CourtStyle.brightness(out), "shading survives the recolour")


## The ADR-022 build checks, on what the port shows: every line colour
## against every surface and kitchen, and the ball against every surface
## and kitchen, at every venue (DEFAULT is that venue's paint).
func test_lines_and_ball_stay_readable() -> void:
	var m := _manifest()
	var d := CourtStyle.data()
	var min_line: float = d["min_line_contrast"]
	var min_ball: float = d["min_ball_contrast"]
	var ball := Color8(d["ball_color"][0], d["ball_color"][1], d["ball_color"][2])
	var worst_line := 99.0
	var worst_ball := 99.0
	for venue in Settings.VENUES:
		for ground_part in ["surface", "kitchen"]:
			for gi in CourtStyle.count(ground_part):
				var choice := [0, 0, 0, 0]
				choice[CourtStyle.PARTS.find(ground_part)] = gi
				var g := CourtStyle.shown(choice, ground_part, venue, m)
				worst_ball = minf(worst_ball, CourtStyle.contrast(ball, g))
				check(CourtStyle.contrast(ball, g) >= min_ball, "%s %s %s: ball %.2f" % [
					venue, ground_part, CourtStyle.names(ground_part)[gi], CourtStyle.contrast(ball, g)])
				for li in CourtStyle.count("lines"):
					choice[3] = li
					var l := CourtStyle.shown(choice, "lines", venue, m)
					var c := CourtStyle.contrast(l, g)
					worst_line = minf(worst_line, c)
					check(c >= min_line, "%s %s %s / lines %s: %.2f" % [venue, ground_part,
						CourtStyle.names(ground_part)[gi], CourtStyle.names("lines")[li], c])
	print("    worst line contrast %.2f (min %.1f), worst ball %.2f (min %.1f)" % [
		worst_line, min_line, worst_ball, min_ball])


func test_court_page_and_save() -> void:
	var kept: Array = Settings.court.duplicate()
	var save := fresh_save("user://test_court/")
	var t := title_screen(save)
	t.reveal("court").press()
	eq(t.page, "court")
	var p: MenuPage = t.pages["court"]
	p.select("surface")
	p.change(1)
	eq(p.value_of("surface"), "BLUE")
	check(t._demo._ground.material is ShaderMaterial, "the demo behind the page recolours at once")
	p.select("lines")
	p.change(-1)
	eq(p.value_of("lines"), "LIME", "rows wrap")
	t._store_settings()
	save.save_game()
	t.free()
	Settings.court = CourtStyle.DEFAULTS.duplicate()
	var s2 := SaveGame.new()
	s2.dir = save.dir
	s2.load_game()
	s2.data["settings"]["court"][1] = 99                       # out of range: DEFAULT
	var t2 := title_screen(s2)
	eq(Settings.court, [1, 0, 0, CourtStyle.count("lines") - 1], "saved, and a bad index loads as DEFAULT")
	t2.free()
	Settings.court = kept
