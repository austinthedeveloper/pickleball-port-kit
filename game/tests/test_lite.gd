## The Web build is "lite" (port ADR-089): its preset's feature tag and
## exclude_filter leave out the announcer, ROAD TRIP and the painted venues,
## and the game, with Settings.lite on, never offers them.
extends TestSuite

const DIR := "user://test_lite/"


func _lite(on: bool) -> bool:
	var kept := Settings.lite
	Settings.lite = on
	return kept


func _preset(name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "the presets")
	for s in cfg.get_sections():
		if s.count(".") == 1 and String(cfg.get_value(s, "name", "")) == name:
			return {"features": String(cfg.get_value(s, "custom_features", "")),
				"exclude": String(cfg.get_value(s, "exclude_filter", "")).split(", ")}
	check(false, "a %s preset" % name)
	return {}


## Only the Web preset is lite, and it leaves out what the flag hides.
func test_the_presets() -> void:
	var web := _preset("Web")
	eq(web["features"], "lite", "the Web build is lite")
	var leaves: Array = web["exclude"]
	for p in ["assets/audio/announcer/*", "assets/trip/*"]:
		check(p in leaves, "the Web build leaves out %s" % p)
	for v in Settings.PAINTED:
		for p in ["assets/levels/venues/%s/*" % v, "assets/audio/music_match_%s.ogg" % v,
				"assets/audio/ambience_%s.ogg" % v]:
			check(p in leaves, "the Web build leaves out %s" % p)
	for p in ["macOS", "Windows", "Linux"]:
		eq(_preset(p)["features"], "", "%s has everything" % p)


## The painted venues are VENUES' last seven, so the rest keep their indexes.
func test_the_venues() -> void:
	var kept := _lite(true)
	eq(Settings.VENUES.slice(Settings.VENUES.size() - Settings.PAINTED.size()), Settings.PAINTED,
		"the painted venues are the last ones")
	eq(Settings.venue_count(), Settings.VENUES.size() - Settings.PAINTED.size())
	for v in Settings.venues():
		check(not v in Settings.PAINTED, "%s is in the lite build" % v)
	for team in Opponents.DAWSON + 1:
		check(Settings.home_venue(team) in Settings.venues(), "team %d plays at home" % team)
	for i in StoryMode.CHAPTERS:
		check(StoryMode.venue(i) in Settings.venues(), "chapter %d's venue" % (i + 1))
	# a saved painted venue (the 0.34.0 Web build had them) comes back as one it has
	var sv := fresh_save(DIR)
	sv.data["settings"]["venue"] = Settings.VENUES.find("mall")
	Settings.load_from(sv)
	check(Settings.venue() in Settings.venues(), "a saved MALL falls back")
	_lite(false)
	eq(Settings.venue_count(), Settings.VENUES.size(), "the desktop builds have all")
	Settings.load_from(sv)
	eq(Settings.venue(), "mall")
	Settings.venue_i = 0
	wipe_saves(DIR)
	_lite(kept)


## The title has no ROAD TRIP and no announcer rows; COURT's VENUE goes
## round the lite build's venues.
func test_the_title() -> void:
	var kept := _lite(true)
	var t := title_screen(fresh_save(DIR))
	var main: MenuPage = t.pages["main"]
	var options: MenuPage = t.pages["options"]
	for id in TitleScreen.LITE_HIDDEN:
		check(main.index_of(id) < 0 and options.index_of(id) < 0, "no %s row" % id)
	check(main.index_of("story") >= 0 and options.index_of("music") >= 0, "the rest are there")
	var court: MenuPage = t.pages["court"]
	court.select("venue")
	Settings.venue_i = 0
	var seen := {}
	for i in Settings.venue_count():
		seen[court.value_of("venue")] = true
		court.change(1)
	eq(Settings.venue_i, 0, "round and back to the first")
	eq(seen.size(), Settings.venue_count(), "each lite venue once")
	for i in Settings.PAINTED.size():
		check(not Settings.VENUE_NAMES[Settings.VENUES.size() - 1 - i] in seen, "no painted venue")
	court.change(-1)
	eq(Settings.venue(), Settings.venues()[-1], "back from the first is the last lite one")
	Settings.venue_i = 0
	t.free()
	_lite(false)
	t = title_screen(fresh_save(DIR))
	for id in TitleScreen.LITE_HIDDEN:
		check(t.pages["main"].index_of(id) >= 0 or t.pages["options"].index_of(id) >= 0,
			"the desktop builds have %s" % id)
	t.free()
	wipe_saves(DIR)
	_lite(kept)


## GLOBETROTTER is every venue the build has.
func test_globetrotter() -> void:
	var kept := _lite(true)
	var sv := fresh_save(DIR)
	var heard := []
	var unlock: Callable = Achievements.on_unlock
	Achievements.on_unlock = func(id): heard.append(id)
	for v in Settings.venues():
		Achievements.check_match(sv, {"won": true, "scores": [11, 4], "aces": 0, "longest": 6,
			"behind": 0, "mods": 0, "opponent": 2, "venue": v, "cleared": false})
	check("globetrotter" in heard, "won at every lite venue")
	Achievements.on_unlock = unlock
	wipe_saves(DIR)
	_lite(kept)


## No voice: main makes no Announcer, and a match's lines go nowhere.
func test_no_announcer() -> void:
	var kept := _lite(true)
	var dir := SaveGame.default_dir
	SaveGame.default_dir = DIR
	wipe_saves(DIR)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	eq(Announcer.current, null, "no announcer")
	for f in 30:
		main._physics_process(1.0 / 60.0)
	check(not Announcer.speak("achievement"), "nothing to say it")
	main.free()
	SaveGame.default_dir = dir
	wipe_saves(DIR)
	_lite(kept)
