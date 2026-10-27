## The soundtrack (PORT-22, ADR-052): which track plays where, the
## crossfade between screens, the stingers at a match's end, the duck under
## the crowd and the whistle, and the MUSIC setting (OPTIONS, the save).
extends TestSuite

const DIR := "user://test_music/"
const DT := 1.0 / 60.0


func _music() -> Music:
	var m := Music.new()
	runner.root.add_child(m)
	m.silent = true
	return m


func _run(m: Music, seconds: float) -> void:
	for f in int(seconds / DT) + 1:
		m.update(DT)


func _save() -> SaveGame:
	var s := fresh_save(DIR)
	return s


func test_every_track_has_a_file() -> void:
	for d in [Music.LOOPS, Music.STINGERS]:
		for name in d:
			check(ResourceLoader.exists(Music.DIR + d[name] + Music.EXT), ("%s: %s" + Music.EXT) % [name, d[name]])
	for venue in Settings.VENUES:
		eq(Music.match_track(venue), "match_" + venue, "%s has its own match loop" % venue)


## The soundtrack is Ogg (ADR-083): a loop plays round, a stinger once.
func test_loops_loop_and_stingers_dont() -> void:
	var m := _music()
	m.play_loop("match_park")
	var loop: AudioStreamOggVorbis = m._decks[m._active].stream
	check(loop != null and loop.loop, "the loop is Ogg, and loops")
	m.play_sting("won")
	var sting: AudioStreamOggVorbis = m._sting.stream
	check(sting != null and not sting.loop, "the stinger plays once")
	m.free()


func test_each_screen_names_its_track() -> void:
	var t := TitleScreen.new()
	eq(t.music_track(), "title")
	t.free()
	var p := ParkView.new()
	eq(p.music_track(), "park", "the park in open play")
	p.free()
	var v := MatchView.new()
	v.venue = "sunset"
	eq(v.music_track(), "match_sunset", "a match plays its venue's loop")
	v.venue = "space"
	eq(v.music_track(), "match_space", "the fun venues have their own too")
	v.venue = "moon"
	eq(v.music_track(), "match_park", "a venue without one plays the park's")
	v.free()


## The real main scene: the title, the park, a match and back, each
## crossfading to its own loop.
func test_main_plays_each_screens_track() -> void:
	var kept := SaveGame.default_dir
	SaveGame.default_dir = DIR
	_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	var music: Music = main.music
	check(Music.current == music, "main's player is the session's")
	eq(music.track, "title", "the title theme")
	var settle := func():
		for f in main.FADE_OUT + main.FADE_IN + 1:
			main._physics_process(DT)
	main._on_open_park(false)
	settle.call()
	eq(music.track, "park", "open play: the park's theme")
	_run(music, Music.CROSSFADE)
	main._on_start(SimTypes.MatchConfig.singles(), "lakeside", false)
	settle.call()
	check(main._screen is MatchView, "a match")
	eq(music.track, "match_lakeside", "a match at the lake: its loop")
	_run(music, 0.5)
	check(music.gain_of("match_lakeside") > 0.0 and music.gain_of("park") > 0.0,
		"mid-crossfade both play")
	main.show_title()
	settle.call()
	eq(music.track, "title", "back to the title theme")
	main.free()
	check(Music.current == null, "the player goes with main")
	SaveGame.default_dir = kept


func test_crossfade_is_equal_power() -> void:
	var m := _music()
	m.play_loop("title")
	var last := -1.0
	var rising := true
	for f in int(Music.CROSSFADE / DT) + 2:
		m.update(DT)
		rising = rising and m.gain_of("title") >= last
		last = m.gain_of("title")
	check(rising, "the first loop fades in")
	eq(m.gain_of("title"), 1.0, "and arrives")
	m.play_loop("park")
	_run(m, Music.CROSSFADE / 2.0)
	var a := sin(m.gain_of("title") * PI / 2.0)
	var b := sin(m.gain_of("park") * PI / 2.0)
	check(m.gain_of("title") > 0.3 and m.gain_of("park") > 0.3, "halfway: both")
	check(absf(a * a + b * b - 1.0) < 0.02, "equal power through the fade (%.3f)" % (a * a + b * b))
	_run(m, Music.CROSSFADE)
	eq([m.gain_of("title"), m.gain_of("park")], [0.0, 1.0], "the new loop has taken over")
	m.play_loop("park")
	_run(m, 0.1)
	eq(m.gain_of("park"), 1.0, "the same track again doesn't restart")
	m.play_loop("")
	_run(m, Music.CROSSFADE + 0.1)
	eq([m.track, m.gain_of("park")], ["", 0.0], "nothing fades to silence")
	m.free()


func test_a_match_end_stings() -> void:
	eq(Music.result_sting(true, false, false), "won")
	eq(Music.result_sting(false, false, false), "lost")
	eq(Music.result_sting(true, true, false), "cleared", "beating the last rung")
	eq(Music.result_sting(false, false, true), "won", "2P versus: somebody won")
	var m := _music()
	m.play_loop("match_park")
	_run(m, Music.CROSSFADE + 0.1)
	m.play_sting("won")
	eq([m.track, m.sting_name], ["", "won"], "the stinger, and no loop after it")
	_run(m, Music.STING_FADE + 0.05)
	eq(m.gain_of("match_park"), 0.0, "the loop got out of its way, quickly")
	m.play_loop("title")
	_run(m, Music.CROSSFADE + 0.1)
	eq(m.gain_of("title"), 1.0, "the next screen's loop fades in")
	m.free()


## A real match, bots on both sides: its end plays won or lost by the score,
## and a rematch brings the loop back. The title's demo never stings.
func test_a_real_match_stings_and_the_demo_doesnt() -> void:
	var m := _music()
	for demo in [false, true]:
		m.sting_name = ""
		var cfg := SimTypes.MatchConfig.singles()
		cfg.points_to_win = 3
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(cfg, "park", demo)
		v.sim.p1_bot = true
		v.highlight = null               # straight to the result (test_highlight has it)
		var f := 0
		while v.sim.phase != K.PHASE_MATCH_RESULT and f < 30000:
			if v.sim.phase == K.PHASE_SERVE_SETUP and f % 32 == 0:
				v.sim.serve_requested = 1
			v._physics_process(DT)
			f += 1
		if demo:
			eq(m.sting_name, "", "the demo behind the title makes no music")
		else:
			check(v.sim.phase == K.PHASE_MATCH_RESULT, "the match ended")
			eq(m.sting_name, "won" if v.sim.match_winner == 0 else "lost", "its stinger")
			v.sim.rematch_requested = true
			v._physics_process(DT)          # asked for: the next step's (ADR-102)
			v._physics_process(DT)
			eq(m.track, "match_park", "a rematch: the loop again")
		v.free()
	m.free()


func test_ducks_under_the_crowd_and_the_whistle() -> void:
	var kept := Sfx.setting
	Sfx.setting = AudioMap.SOUND_ALL
	var m := _music()
	m.play_loop("match_park")
	_run(m, Music.CROSSFADE + 0.1)
	var full := m.level_db()
	var sfx := Sfx.new()
	runner.root.add_child(sfx)
	sfx.setup("park", false)
	sfx.event([K.EVENT_HIT, 60, 130, 0], 1, false)
	_run(m, 0.3)
	eq(m.ducking(), 0.0, "a hit doesn't duck")
	sfx.event([K.EVENT_POINT, 100, 130, 0], 4, false)
	_run(m, 0.3)
	check(m.ducking() > 0.99 and m.level_db() < full - 8.0, "the applause ducks it (%.1f dB)" % (m.level_db() - full))
	_run(m, Music.DUCK_HOLD + Music.DUCK_RELEASE)
	eq(m.ducking(), 0.0, "and it comes back")
	sfx.event([K.EVENT_FAULT, 250, 130, K.FAULT_OUT], 1, false)
	_run(m, 0.3)
	check(m.ducking() > 0.99, "the whistle ducks it too")
	sfx.free()
	m.free()
	Sfx.setting = kept


func test_music_setting() -> void:
	var kept := [Music.volume, Sfx.setting]
	var m := _music()
	Sfx.setting = AudioMap.SOUND_ALL
	Music.volume = Music.VOLUMES
	var loud := m.level_db()
	Music.volume = Music.VOLUMES / 2
	check(absf(loud - m.level_db() - 6.0) < 0.1, "half the level is 6 dB down")
	Music.volume = 0
	eq(m.level_db(), -80.0, "MUSIC OFF: silent")
	Music.volume = 7
	Sfx.setting = AudioMap.SOUND_OFF
	eq(m.level_db(), -80.0, "SOUND OFF silences the music too")
	Sfx.setting = AudioMap.SOUND_NO_CROWD
	check(m.level_db() > -80.0, "NO CROWD keeps it")
	m.free()
	# the OPTIONS row
	var s := _save()
	var t := title_screen(s)
	eq(Music.volume, Music.DEFAULT_VOLUME, "a new save starts at the default")
	t.open_page("options")
	var o: MenuPage = t.pages["options"]
	check(o.select("music"), "MUSIC is on OPTIONS")
	eq(o.value_of("music"), "70%")
	o.change(1)
	eq(o.value_of("music"), "80%")
	for i in 12:
		o.change(-1)
	eq(o.value_of("music"), "OFF", "down to OFF, and no further")
	o.change(1)
	o.change(1)
	t._store_settings()
	s.save_game()
	t.free()
	Music.volume = 9
	var s2 := SaveGame.new()
	s2.dir = DIR
	s2.load_game()
	Settings.load_from(s2)
	eq(Music.volume, 2, "MUSIC is saved")
	# a save from before the music: the key fills in with the default
	s2.data["settings"].erase("music")
	s2.save_game()
	var s3 := SaveGame.new()
	s3.dir = DIR
	s3.load_game()
	Settings.load_from(s3)
	eq(Music.volume, Music.DEFAULT_VOLUME, "an older save gets the default")
	Music.volume = kept[0]
	Sfx.setting = kept[1]
