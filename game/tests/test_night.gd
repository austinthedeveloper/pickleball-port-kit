## PORT-06: night courts (ADR-045). DAY changes nothing; DUSK and NIGHT
## never brighten; the lines and the ball stay readable and a shadow stays
## visible at every time on every court (KNOWN_ISSUES #26); NIGHT plays
## the crickets; the view darkens the backdrop and lights the court.
extends TestSuite

const MIN_SHADOW := 1.2          ## shadow-over-court against the court (WCAG ratio)

var manifest: Dictionary


func _m() -> Dictionary:
	if manifest.is_empty():
		manifest = MatchView.levels_manifest()
	return manifest


func test_times_and_scales() -> void:
	eq(CourtStyle.time_names(), ["DAY", "DUSK", "NIGHT"])
	eq(CourtStyle.time_scales(CourtStyle.DAY), [Color.WHITE, Color.WHITE], "DAY is as painted")
	eq(CourtStyle.time_scales(7), [Color.WHITE, Color.WHITE], "out of range is DAY")
	for t in [CourtStyle.DUSK, CourtStyle.NIGHT]:
		for c in CourtStyle.time_scales(t):
			check(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0, "time %d never brightens" % t)
	var night := CourtStyle.time_scales(CourtStyle.NIGHT)
	check(night[0].b > night[0].r, "the night's dark shifts blue")
	check(night[1].get_luminance() > 0.8 and night[0].get_luminance() < 0.4,
		"the lights stay bright, the backdrop goes dark")
	eq(CourtStyle.time_ambience(CourtStyle.NIGHT), "sunset", "NIGHT plays the crickets (SUNSET's loop)")
	eq(CourtStyle.time_ambience(CourtStyle.DUSK), "", "DUSK keeps the venue's")


## ADR-045's build check: every line on every surface and kitchen under
## the lights, and the ball (which keeps its colour), at every time and
## venue; the lines against LAVA too.
func test_contrast_at_every_time() -> void:
	var m := _m()
	var d := CourtStyle.data()
	var ball := Color8(d["ball_color"][0], d["ball_color"][1], d["ball_color"][2])
	var lava := Color8(d["lava"][0], d["lava"][1], d["lava"][2])
	var worst := [99.0, 99.0, 99.0]
	for t in 3:
		var lit: Color = CourtStyle.time_scales(t)[1]
		for venue in Settings.VENUES:
			for part in ["surface", "kitchen"]:
				for gi in CourtStyle.count(part):
					var choice := [0, 0, 0, 0]
					choice[CourtStyle.PARTS.find(part)] = gi
					var g := CourtStyle.shown_at(choice, part, venue, m, t)
					var b := CourtStyle.contrast(ball, g)
					worst[1] = minf(worst[1], b)
					check(b >= d["min_ball_contrast"], "t%d %s %s %s: ball %.2f" % [t, venue, part,
						CourtStyle.names(part)[gi], b])
					for li in CourtStyle.count("lines"):
						choice[3] = li
						var l := CourtStyle.shown_at(choice, "lines", venue, m, t)
						var c := CourtStyle.contrast(l, g)
						worst[0] = minf(worst[0], c)
						check(c >= d["min_line_contrast"], "t%d %s %s %s / %s: %.2f" % [t, venue, part,
							CourtStyle.names(part)[gi], CourtStyle.names("lines")[li], c])
			for li in CourtStyle.count("lines"):
				var choice := [0, 0, 0, li]
				var l := CourtStyle.shown_at(choice, "lines", venue, m, t)
				var lv := Color(lava.r * lit.r, lava.g * lit.g, lava.b * lit.b)
				worst[2] = minf(worst[2], CourtStyle.contrast(l, lv))
	print("    worst at any time: lines %.2f, ball %.2f, lines on LAVA %.2f" % worst)


## A player's shadow (alpha blended over the court) stays visible on every
## court at every time; on the darkest (BLACK) it draws grey.
func test_shadow_visible_on_every_court() -> void:
	var m := _m()
	var worst := 99.0
	var worst_at := ""
	for t in 3:
		for venue in Settings.VENUES:
			for part in ["surface", "kitchen"]:
				for gi in CourtStyle.count(part):
					var choice := [0, 0, 0, 0]
					choice[CourtStyle.PARTS.find(part)] = gi
					if part == "kitchen":
						choice[0] = 0
					var g := CourtStyle.shown_at(choice, part, venue, m, t)
					var surf_choice := choice if part == "surface" else [choice[1] if choice[1] > 0 else 0, 0, 0, 0]
					var grey := CourtStyle.luminance(g) < CourtStyle.DARK_COURT_LUM
					var sh := CourtStyle.SHADOW_GREY if grey else CourtStyle.SHADOW
					var c := CourtStyle.contrast(CourtStyle.over(g, sh), g)
					if c < worst:
						worst = c
						worst_at = "t%d %s %s %s" % [t, venue, part, CourtStyle.names(part)[gi]]
					check(c >= MIN_SHADOW, "t%d %s %s %s: shadow %.2f" % [t, venue, part,
						CourtStyle.names(part)[gi], c])
	print("    worst shadow %.2f (%s)" % [worst, worst_at])
	var black := CourtStyle.names("surface").find("BLACK")
	check(CourtStyle.grey_shadows([black, 0, 0, 0], "park", m, CourtStyle.NIGHT), "BLACK at NIGHT: grey")
	check(not CourtStyle.grey_shadows([0, 0, 0, 0], "park", m, CourtStyle.NIGHT), "the painted court: dark")


func test_night_view() -> void:
	var day := MatchView.new()
	runner.root.add_child(day)
	day.setup(SimTypes.MatchConfig.singles(), "park", false)
	check(day._layers.all(func(l): return l[0].modulate == Color.WHITE), "DAY leaves every layer")
	check(day._ground.material == null, "and the ground unshaded")
	day.free()
	var view := MatchView.new()
	view.time = CourtStyle.NIGHT
	runner.root.add_child(view)
	view.setup(SimTypes.MatchConfig.singles(), "lakeside", false)
	var sc := CourtStyle.time_scales(CourtStyle.NIGHT)
	for l in view._layers:
		var s: Sprite2D = l[0]
		if s == view._ground:
			continue
		var want: Color = sc[1] if String(s.texture.resource_path).ends_with("net.png") else sc[0]
		eq(s.modulate, want, "%s's scale" % s.texture.resource_path.get_file())
	var mat: ShaderMaterial = view._ground.material
	check(mat != null and mat.get_shader_parameter("lit") == Vector3(sc[1].r, sc[1].g, sc[1].b),
		"the court is under the lights")
	check(view.crowd.people.all(func(c): return c[0].modulate == sc[0]), "the crowd dims")
	check(view._players.all(func(e): return e["root"].modulate == Color.WHITE), "players keep their colours")
	eq(view._sfx.ambience_name, "sunset", "the crickets at NIGHT")
	view.free()


## Every venue at NIGHT and DUSK (ADR-046's three too): the backdrop and
## the onlookers dim, the court is lit, the crickets play at NIGHT.
func test_every_venue_at_night() -> void:
	for venue in Settings.VENUES:
		if venue in Settings.INDOOR:
			continue                         # test_indoors_is_always_lit
		for t in [CourtStyle.DUSK, CourtStyle.NIGHT]:
			var view := MatchView.new()
			view.time = t
			runner.root.add_child(view)
			view.setup(SimTypes.MatchConfig.singles(), venue, false)
			var sc := CourtStyle.time_scales(t)
			var dim := view._layers.filter(func(l): return l[0] != view._ground \
				and not String(l[0].texture.resource_path).ends_with("net.png"))
			check(dim.size() >= 6 and dim.all(func(l): return l[0].modulate == sc[0]),
				"%s t%d: the backdrop takes the dark scale" % [venue, t])
			check(view._ground.material is ShaderMaterial, "%s t%d: the court under the lights" % [venue, t])
			check(view.crowd.people.all(func(c): return c[0].modulate == sc[0]), "%s t%d: the crowd dims" % [venue, t])
			eq(view._sfx.ambience_name, "sunset" if t == CourtStyle.NIGHT else venue,
				"%s t%d: the ambience" % [venue, t])
			view.free()


func test_time_row_and_save() -> void:
	var kept := Settings.time_i
	var save := fresh_save("user://test_night/")
	Settings.time_i = 0
	var t := TitleScreen.new()
	t.save = save
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	t.open_page("court")
	var p: MenuPage = t.pages["court"]
	eq(p.rows[1]["id"], "time", "TIME follows VENUE (ADR-045)")
	p.select("time")
	p.change(-1)
	eq(p.value_of("time"), "NIGHT", "wraps")
	eq(t._demo.time, CourtStyle.NIGHT, "the demo goes to night")
	eq(t.pages["main"].value_of("court"), "PARK NIGHT")
	t._store_settings()
	eq(int(save.data["settings"]["time"]), CourtStyle.NIGHT, "saved")
	t.free()
	Settings.time_i = kept


## ADR-078: indoors (THE GYM's venue) the lights are on whatever TIME says:
## the backdrop and the crowd keep their colours, the gym's own ambience.
func test_indoors_is_always_lit() -> void:
	for venue in Settings.INDOOR:
		for t in [CourtStyle.DUSK, CourtStyle.NIGHT]:
			var view := MatchView.new()
			view.time = t
			runner.root.add_child(view)
			view.setup(SimTypes.MatchConfig.singles(), venue, false)
			eq(view.time, CourtStyle.DAY, "%s t%d: lit" % [venue, t])
			check(view.crowd.people.all(func(c): return c[0].modulate == Color.WHITE), "the crowd in the light")
			eq(view._sfx.ambience_name, venue, "its own ambience")
			view.free()
