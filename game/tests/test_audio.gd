## Port of test_audio.c (ADR-029/031): event to effect, pitch by shot, pan
## by x, crowd by rally, NO CROWD / OFF, the demo silent.
extends TestSuite


func _first(e: Array, setting := AudioMap.SOUND_ALL, rally := 0, won := false) -> Array:
	var s := AudioMap.for_event(e, setting, rally, won)
	return s[0] if s.size() else []


func test_events_to_effects() -> void:
	eq(_first([K.EVENT_SERVE, 20, 150, 0])[0], "hit", "a serve is a hit")
	eq(_first([K.EVENT_BOUNCE, 200, 110, 1])[0], "bounce")
	eq(_first([K.EVENT_FAULT, 128, 130, K.FAULT_NET])[0], "net", "a net fault thumps")
	eq(_first([K.EVENT_FAULT, 250, 130, K.FAULT_OUT])[0], "whistle", "other faults whistle")
	eq(_first([K.EVENT_POINT, 100, 130, 0])[0], "applause")


## The HD set gives each shot its own sample (the SNES pitched one).
func test_sound_by_shot() -> void:
	eq(_first([K.EVENT_HIT, 60, 130, 0 | (K.SHOT_STANDARD << 4)])[0], "hit")
	eq(_first([K.EVENT_HIT, 60, 130, 0 | (K.SHOT_DRIVE << 4)])[0], "hit_drive", "a drive's own crack")
	eq(_first([K.EVENT_HIT, 60, 130, 0 | (K.SHOT_SOFT << 4)])[0], "hit_soft", "a soft shot's own pock")
	check(_first([K.EVENT_HIT, 60, 130, 0 | (K.SHOT_DRIVE << 4)])[2]
		> _first([K.EVENT_HIT, 60, 130, 0 | (K.SHOT_STANDARD << 4)])[2], "a drive is louder")


## Every effect the map names has its samples in the game.
func test_every_effect_has_samples() -> void:
	for name in Sfx.EFFECTS:
		for stem in Sfx.EFFECTS[name]:
			check(ResourceLoader.exists(Sfx.DIR + stem + ".wav"), "%s: %s.wav" % [name, stem])
	for name in AudioMap.HIT_EFFECTS.values():
		check(Sfx.EFFECTS.has(name), "the map's %s has samples" % name)
	check(Sfx.EFFECTS["hit"].size() >= 3, "hits come in variants")


## Every venue has its own ambience loop (ADR-031; the fun three ADR-046),
## and plays it by day.
func test_every_venue_has_its_ambience() -> void:
	for venue in Settings.VENUES:
		check(Sfx.AMBIENCE.has(venue), "%s has an ambience" % venue)
		check(ResourceLoader.exists(Sfx.DIR + String(Sfx.AMBIENCE.get(venue, "")) + ".wav"),
			"%s: its loop exists" % venue)
		var s := Sfx.new()
		runner.root.add_child(s)
		s.setup(venue, false)
		eq(s.ambience_name, venue, "%s plays its own loop by day" % venue)
		s.free()


func test_pan_by_court_x() -> void:
	check(_first([K.EVENT_BOUNCE, K.COURT_BASELINE_LEFT, 130, 1])[3] <= -0.99, "left baseline: left")
	check(absf(_first([K.EVENT_BOUNCE, K.COURT_NET_X, 130, 1])[3]) < 0.01, "the net: centre")
	check(_first([K.EVENT_BOUNCE, K.COURT_BASELINE_RIGHT, 130, 1])[3] >= 0.99, "right: right")


func test_later_bounces_are_quieter() -> void:
	check(_first([K.EVENT_BOUNCE, 100, 130, 2])[2] < _first([K.EVENT_BOUNCE, 100, 130, 1])[2], "quieter")


func test_crowd_scales_with_the_rally() -> void:
	var short: int = _first([K.EVENT_POINT, 0, 0, 0], AudioMap.SOUND_ALL, 1)[2]
	var long: int = _first([K.EVENT_POINT, 0, 0, 0], AudioMap.SOUND_ALL, 20)[2]
	var won: int = _first([K.EVENT_POINT, 0, 0, 0], AudioMap.SOUND_ALL, 1, true)[2]
	check(short >= 6 and long <= 13 and long > short, "6..13 by rally (%d, %d)" % [short, long])
	eq(won, 15, "the match-winning point is loudest")
	check(AudioMap.ambience_level(AudioMap.SOUND_ALL, true, 15, false)
		> AudioMap.ambience_level(AudioMap.SOUND_ALL, true, 1, false), "the murmur swells")
	check(AudioMap.ambience_level(AudioMap.SOUND_ALL, true, 15, true)
		< AudioMap.ambience_level(AudioMap.SOUND_ALL, true, 15, false), "and hushes on match point")


func test_no_crowd_and_off() -> void:
	eq(AudioMap.for_event([K.EVENT_POINT, 0, 0, 0], AudioMap.SOUND_NO_CROWD, 5, false), [], "NO CROWD: no applause")
	check(AudioMap.for_event([K.EVENT_HIT, 60, 130, 0], AudioMap.SOUND_NO_CROWD, 0, false).size() == 1,
		"but the hits stay")
	eq(AudioMap.ambience_level(AudioMap.SOUND_NO_CROWD, true, 5, false), 0.0, "and no murmur")
	eq(AudioMap.for_event([K.EVENT_HIT, 60, 130, 0], AudioMap.SOUND_OFF, 0, false), [], "OFF: nothing")


func test_demo_is_silent_and_matches_play() -> void:
	for demo in [true, false]:
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(SimTypes.MatchConfig.singles(), "park", demo)
		if not demo:
			v.sim.p1_bot = true
		v._sfx.last = []
		for f in 900:
			if not demo and v.sim.phase == K.PHASE_SERVE_SETUP and f % 32 == 0:
				v.sim.serve_requested = 1
			v._physics_process(1.0 / 60.0)
		if demo:
			eq(v._sfx.last, [], "the title's demo makes no game sounds")
		else:
			check(v._sfx.last.size() == 4, "a match makes sounds (%s)" % str(v._sfx.last))
		v.queue_free()
