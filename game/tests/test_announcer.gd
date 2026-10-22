## The announcer (PORT-52, ADR-076): the voice says one line at a time, by
## priority, variants never twice running, score calls in pieces; the
## commentary picks the lines from the match, as much as COMMENTARY says,
## display only; every line it can ask for was recorded.
extends TestSuite


func _voice() -> Announcer:
	var a := Announcer.new()
	a.silent = true
	a.rng.seed = 94
	runner.root.add_child(a)
	return a


func _kept() -> Array:
	return [Announcer.volume, Announcer.chatter, Sfx.setting, Announcer.enabled]


func _restore(k: Array) -> void:
	Announcer.volume = k[0]
	Announcer.chatter = k[1]
	Sfx.setting = k[2]
	Announcer.enabled = k[3]


## Every clip is there, and every line the commentary can ask for.
func test_the_clips() -> void:
	var a := _voice()
	eq(a.clips.size(), 298, "the full script recorded (lines.csv: the first batch and the additions, less removed.txt)")
	check(a.families.keys().filter(func(f): return f.begins_with("team_")).is_empty(), "no team intros")
	var missing := []
	for id in a.clips:
		if not ResourceLoader.exists(Announcer.DIR + id + ".wav"):
			missing.append(id)
	var wanted := ["score_all", "ace", "match_point", "match_point_saved", "sudden_death", "comeback",
		"streak_3", "streak_5", "win_by_2", "quip", "side_out", "close_call", "potm", "match_win",
		"match_loss", "match_win_shutout", "match_win_close", "ladder_cleared", "story_saved",
		"story_stakes_1", "story_stakes_2", "rematch", "pause", "resume", "title_logo", "winner",
		"match_doubles", "match_singles", "shot_drive", "shot_slice", "shot_smash",
		"shot_lob", "shot_dink", "shot_volley"]
	wanted.append_array(Commentary.FAULT_LINES.values())
	# the second batch (PORT-55), recorded with the rest in 2026-10
	wanted.append_array(["deuce", "deuce_long", "advantage_server", "advantage_receiver", "special_ready",
		"pickle_smash", "smash_return", "smash_winner", "smash_finish", "achievement"])
	for ach in Achievements.LIST:
		wanted.append("achievement_" + ach[0])
	for m in Commentary.MOD_LINES:
		wanted.append(m[1])
	for n in Commentary.RALLY_CALLS:
		wanted.append("rally_%d" % n)
	for v in Settings.VENUES:
		wanted.append("venue_" + v)
	for n in 26:
		wanted.append_array(["num_%02d_up" % n, "num_%02d_down" % n])
	for f in wanted:
		if not a.families.has(f) and not a.clips.has(f):
			missing.append(f)
	eq(missing, [], "nothing asked for that wasn't recorded")
	eq(a.family_of("ace_3"), "ace")
	eq(a.family_of("num_04_up"), "num_04_up")
	eq(a.family_of("venue_park_1"), "venue_park")
	eq(a.family_of("rally_25"), "rally_25")
	eq(a.family_of("mod_win_by_2"), "mod_win_by_2")
	a.free()


func test_the_voice() -> void:
	var k := _kept()
	Announcer.volume = 8
	Sfx.setting = AudioMap.SOUND_ALL
	var a := _voice()
	check(a.say("ace", Announcer.MID))
	check(a.busy())
	check(not a.say("net", Announcer.LOW), "a lower one, now or never: no")
	check(a.say("match_point", Announcer.HIGH), "a higher one cuts in")
	eq(a.family_of(a.said[-1]), "match_point")
	check(a.say("net", Announcer.MID, 0.5), "waits")
	a.tick(0.4)
	check(a.family_of(a.said[-1]) == "match_point", "still the match point")
	a.tick(10.0)
	a.tick(0.01)
	check(a.family_of(a.said[-1]) != "net", "gone stale while it waited")
	# variants: never the same twice running
	var last := ""
	for i in 20:
		a.hush()
		a.say("ace", Announcer.MID)
		check(a.said[-1] != last, "a different ace")
		last = a.said[-1]
	# a score call: its pieces in order, one after the other
	a.hush()
	var start := a.said.size()
	a.say_ids(["num_04_up", "num_02_down"], Announcer.MID)
	eq(a.said.slice(start), ["num_04_up"])
	for i in 200:
		a.tick(1.0 / 60.0)
	eq(a.said.slice(start), ["num_04_up", "num_02_down"], "four... two")
	# OFF, and SOUND OFF
	a.hush()
	Announcer.enabled = false
	check(not a.say("ace", Announcer.TOP), "ANNOUNCER OFF")
	Announcer.enabled = true
	Sfx.setting = AudioMap.SOUND_OFF
	check(not a.say("ace", Announcer.TOP), "SOUND OFF")
	a.free()
	_restore(k)


func test_score_calls() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(Settings.config_for(true, 2, K.DIFFICULTY_MEDIUM, 11), "park", false)
	var c := v.commentary
	v.sim.team_score = [4, 2]
	v.sim.serving_team = 0
	eq(c.score_call(), ["num_04_up", "num_02_down"], "the server's score first")
	v.sim.serving_team = 1
	eq(c.score_call(), ["num_02_up", "num_04_down"])
	v.sim.team_score = [5, 5]
	eq(c.score_call(), ["num_05_up", "score_all"], "five all")
	v.sim.config.modifiers = K.MOD_SIDE_OUT
	v.sim.server_number = 2
	eq(c.score_call(), ["num_05_up", "num_05_up", "num_02_down"], "side-out: five, five, two")
	v.free()


## A bot match with the voice on: it introduces the team, calls scores,
## reacts to points, says the result; at LIGHT, no score calls; the match
## plays as a bare sim does.
func test_a_match() -> void:
	var k := _kept()
	Announcer.volume = 8
	Sfx.setting = AudioMap.SOUND_ALL
	for level in [Announcer.NORMAL, Announcer.LIGHT]:
		Announcer.chatter = level
		var a := _voice()
		var cfg := Settings.config_for(true, 2, K.DIFFICULTY_MEDIUM, 5)
		var v := match_view(cfg)
		v.highlight = null
		v.commentary.rng.seed = 7
		var bare := Sim.new(cfg)
		bare.p1_bot = true
		for f in 60 * 60 * 8:
			v._physics_process(1.0 / 60.0)
			a.tick(1.0 / 60.0)
			bare.step([SimTypes.Intent.new(), null, null, null])
			bare.drain_events()
			if v.sim.phase == K.PHASE_MATCH_RESULT:
				break
		var heard := v.commentary.heard
		eq(heard[0], "venue_park", "the venue introduced (no team intros)")
		check(heard[-1].begins_with("match_"), "the result (%s)" % heard[-1])
		if level == Announcer.NORMAL:
			check(heard.count("score") >= 3, "scores called (%d)" % heard.count("score"))
			check(heard.size() > 8, "a talker (%d lines)" % heard.size())
		else:
			eq(heard.count("score"), 0, "LIGHT: no score calls")
		print("    %s: %d lines, %s" % [Announcer.CHATTER_NAMES[level], heard.size(), heard.slice(0, 12)])
		eq(v.sim.snapshot(), bare.snapshot(), "display only")
		bare.dispose()
		v.free()
		a.free()
	_restore(k)


## Practice is quiet: no points there, so the rally talk would count the
## machine's feeds (returned or not) as one long rally.
func test_practice_is_quiet() -> void:
	wipe_saves("user://test_announcer/")
	var save := SaveGame.new()
	save.dir = "user://test_announcer/"
	save.load_game()
	var v := match_view(save.practice_config(K.DIFFICULTY_MEDIUM))
	check(v.sim.config.practice, "a practice match")
	eq(v.commentary, null, "no announcer in practice")
	for f in 600:
		v._physics_process(1.0 / 60.0)
	v.queue_free()


func test_settings() -> void:
	var k := _kept()
	var sv := fresh_save("user://test_announcer/")
	Announcer.enabled = false
	Announcer.volume = 3
	Announcer.chatter = Announcer.LOTS
	Settings.store_to(sv)
	Announcer.enabled = true
	Announcer.volume = 8
	Announcer.chatter = Announcer.NORMAL
	Settings.load_from(sv)
	eq([Announcer.enabled, Announcer.volume, Announcer.chatter], [false, 3, Announcer.LOTS], "saved")
	# a 0.19.0 save with the slider at OFF: the switch is OFF, the volume back
	sv.data["settings"].erase("announcer_on")
	sv.data["settings"]["announcer"] = 0
	Settings.load_from(sv)
	eq([Announcer.enabled, Announcer.volume], [false, Announcer.DEFAULT_VOLUME], "0.19.0's OFF")
	var t := TitleScreen.new()
	t.save = sv
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	var page: MenuPage = t.pages["options"]
	page.select("announcer")
	page.change(1)
	eq(page.value_of("announcer"), "ON", "ANNOUNCER: ON or OFF")
	page.change(1)
	eq(page.value_of("announcer"), "OFF")
	page.select("voice")
	Announcer.volume = 3
	page.change(-1)
	eq(page.value_of("voice"), "20%")
	for i in 5:
		page.change(-1)
	eq(page.value_of("voice"), "10%", "the volume never reaches OFF: that's the switch")
	page.select("commentary")
	Announcer.chatter = Announcer.LOTS
	page.change(-1)
	eq(page.value_of("commentary"), "NORMAL")
	t.free()
	wipe_saves("user://test_announcer/")
	_restore(k)


## WIN BY 2's extension: advantage and deuce once recorded (PORT-55), "win
## by two" until then; an achievement's line, its own or the general one.
## SPECIALS' lines (the second batch): PICKLE SMASH, its pop-up return,
## a smash that wins, and a meter filling up; before they're recorded, a
## smash's line.
func test_the_specials_lines() -> void:
	var k := _kept()
	Announcer.volume = 8
	Sfx.setting = AudioMap.SOUND_ALL
	var a := _voice()
	var v := MatchView.new()
	runner.root.add_child(v)
	var cfg := Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 11)
	cfg.modifiers = K.MOD_SPECIALS
	v.setup(cfg, "park", false)
	var c := v.commentary
	c._intro = []
	var smash := [K.EVENT_HIT, 100, 100, 0 | (K.SHOT_SPECIAL << 4)]
	if not a.families.has("pickle_smash"):
		c._on_hit(smash)
		eq(c.heard.back(), "shot_smash", "not recorded yet: a smash's line")
		a.hush()
	for fam in ["pickle_smash", "smash_return", "smash_winner", "special_ready"]:
		a.clips[fam + "_1"] = 0.5
		a.families[fam] = [fam + "_1"]
	c._on_hit(smash)
	eq(c.heard.back(), "pickle_smash", "PICKLE SMASH")
	a.hush()
	c._on_hit([K.EVENT_HIT, 300, 100, 2 | (K.SHOT_SOFT << 4)])
	eq(c.heard.back(), "smash_return", "the pop-up")
	a.hush()
	c._on_hit(smash)
	a.hush()
	v.sim.rally_start = (v.sim.shot_serial - 8) & 0xff
	c._on_point(0)
	eq(c.heard.back(), "smash_winner", "never returned: a winner")
	a.hush()
	v.sim.meter[0] = K.SPECIAL_METER_MAX
	c._meters()
	eq(c.heard.back(), "special_ready", "P1's meter filled up")
	a.hush()
	c._meters()
	eq(c.heard.count("special_ready"), 1, "once")
	v.free()
	a.free()
	_restore(k)


func test_the_second_batch() -> void:
	var k := _kept()
	Announcer.volume = 8
	Sfx.setting = AudioMap.SOUND_ALL
	var a := _voice()
	var v := MatchView.new()
	runner.root.add_child(v)
	var cfg := Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, 11)
	cfg.modifiers = K.MOD_WIN_BY_2
	v.setup(cfg, "park", false)
	var c := v.commentary
	c._intro = []
	v.sim.team_score = [10, 10]
	check(c._extended(), "10-10 to 11, win by 2: the extension")
	eq(c._first(["deuce", "win_by_2"]), "win_by_2" if not a.families.has("deuce") else "deuce",
		"what's recorded is what's said")
	# a later batch, recorded: it's said
	a.clips["deuce_1"] = 1.0
	a.families["deuce"] = ["deuce_1"]
	a.clips["advantage_server_1"] = 1.0
	a.families["advantage_server"] = ["advantage_server_1"]
	v.sim.serving_team = 0
	c._server_before = 0
	v.sim.rally_start = (v.sim.shot_serial - 8) & 0xff      # an 8-shot rally, not an ace
	c._on_point(0)
	check(c.heard.has("deuce"), "10-10: deuce (%s)" % [c.heard])
	a.hush()
	v.sim.team_score = [11, 10]
	c._on_point(0)
	check(c.heard.has("advantage_server"), "11-10: advantage to the server (%s)" % [c.heard])
	v.sim.team_score = [9, 10]
	check(not c._extended(), "not before both reach game point")
	v.free()
	a.free()
	_restore(k)
