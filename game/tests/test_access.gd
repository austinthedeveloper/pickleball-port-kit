## Controls and access (PORT-123..126, port ADR-108): COLOURS (the
## players apart under each colour deficiency, HIGH CONTRAST against
## every court), the rings' shapes, CAPTIONS (every line has one, in the
## font, and the bar shows and wraps them), ASSIST (in the sim, off in the
## ROM's play, not counted), and the couch cup's pads claimed on PLAY.
extends TestSuite

const DIR := "user://test_access/"


static func _surfaces() -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/court_colors.json"))
	var out := []
	for part in ["surface", "surround"]:
		for p: Array in d["parts"][part]["presets"]:
			var c: Array = p[1]
			out.append([String(p[0]), Color8(int(c[0]), int(c[1]), int(c[2]))])
	return out


## Each colour-blind set's four players stay apart as that eye sees them;
## STANDARD's don't for at least one (why the sets exist).
func test_colour_sets_apart() -> void:
	eq(Access.TINTS.size(), Access.SETS.size())
	for kind in [Access.DEUTAN, Access.PROTAN, Access.TRITAN]:
		var set: Array = Access.TINTS[kind]
		for i in 4:
			for j in range(i + 1, 4):
				var a := Access.simulate(set[i], kind)
				var b := Access.simulate(set[j], kind)
				check(Access.distance(a, b) >= 0.25, "%s: P%d and P%d apart (%.2f)" % [Access.SETS[kind],
					i + 1, j + 1, Access.distance(a, b)])
	var worst := 9.0
	var std: Array = Access.TINTS[Access.STANDARD]
	for i in 4:
		for j in range(i + 1, 4):
			worst = minf(worst, Access.distance(Access.simulate(std[i], Access.DEUTAN),
				Access.simulate(std[j], Access.DEUTAN)))
	check(worst < 0.25, "STANDARD's red and green run together for a deutan (%.2f)" % worst)


## HIGH CONTRAST's rings against every court surface and surround.
func test_high_contrast() -> void:
	for s: Array in _surfaces():
		for i in 4:
			var c: Color = Access.TINTS[Access.HIGH][i]
			# the ring's bright fill or its dark edge stands out from the court
			var best := maxf(Access.contrast(c, s[1]), Access.contrast(Access.EDGE, s[1]))
			check(best >= 3.0, "HIGH P%d on %s: %.2f" % [i + 1, s[0], best])
	check(Access.simulate(Color.RED, Access.HIGH) == Color.RED, "no simulation outside the three")


func test_player_tint_follows_the_setting() -> void:
	var kept := Settings.colours_i
	for k in Access.SETS.size():
		Settings.colours_i = k
		for i in 4:
			eq(Access.player_tint(i), Access.TINTS[k][i])
	Settings.colours_i = kept
	eq(Access.SHAPES.size(), 4, "a shape for each player")


## A match's ring takes the set; the ring's draw has the player's shape.
func test_marker_in_a_match() -> void:
	var kept := Settings.colours_i
	Settings.colours_i = Access.TRITAN
	var cfg := SimTypes.MatchConfig.new()
	var v := match_view(cfg)
	v.sim.p1_bot = false
	eq(v.marker_color(0), Color(Access.TINTS[Access.TRITAN][0], MatchView.MARKER_ALPHA))
	v.free()
	Settings.colours_i = Access.HIGH
	v = match_view(cfg)
	check(v._ball_sprite.material != null, "HIGH CONTRAST rims the ball")
	v.free()
	Settings.colours_i = kept


## Every clip the announcer has has a caption, in the font's letters.
func test_every_line_captioned() -> void:
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/announcer.json"))["clips"]
	var chars := String(BitmapText.load_font("small")["chars"])
	for id: String in clips:
		var text := Access.caption_for(id)
		check(text != "", "a caption for " + id)
		for ch in text:
			if ch != " " and not chars.contains(ch):
				check(false, "%s: '%s' isn't in the font" % [id, ch])
				break
		check(Captions.wrap_lines(text).size() <= 2, id + " fits two lines")
		for line: String in Captions.wrap_lines(text):
			check(BitmapText.measure("small", line) <= 900, id + " fits the screen")


func test_caption_bar() -> void:
	var kept := Settings.captions
	var bar := Captions.new()
	runner.root.add_child(bar)
	if not bar.is_node_ready():
		bar._ready()
	Settings.captions = false
	Access.say("GOOD AFTERNOON!", 2.0, true)
	bar.tick(0.016)
	eq(bar.visible_text(), "", "off: nothing shown")
	Settings.captions = true
	Access.say("GOOD AFTERNOON, AND WELCOME TO THE PARK!", 2.0, true)
	bar.tick(0.016)
	eq(bar.visible_text(), "GOOD AFTERNOON, AND WELCOME TO THE PARK!")
	Access.cue("whistle")
	bar.tick(0.016)
	eq(bar.visible_text(), "GOOD AFTERNOON, AND WELCOME TO THE PARK!", "a cue never covers a line")
	bar.tick(2.5)
	eq(bar.visible_text(), "", "the line runs out")
	Access.cue("net")
	bar.tick(0.016)
	eq(bar.visible_text(), "THE NET", "a sound-only cue")
	Access.say("WELCOME BACK TO RIVERDALE PARK, WHERE THE DINKS ARE SOFT AND THE STAKES ARE HIGH.", 3.0, true)
	bar.tick(0.016)
	check(String(bar._lines[1].text) != "", "a long line wraps to two")
	bar.free()
	Settings.captions = kept


## The announcer's line goes to the captions as it starts.
func test_announcer_captions() -> void:
	var a := Announcer.new()
	a.silent = true
	runner.root.add_child(a)
	var serial := Access.caption_serial
	check(a.say("time_night", Announcer.TOP), "a line")
	eq(Access.caption_serial, serial + 1)
	eq(Access.caption, "UNDER THE LIGHTS TONIGHT!")
	check(Access.caption_voice)
	a.free()


## ASSIST SWING swings for a human who never presses (KID's assist, any
## difficulty); SERVE slows a human's serve meter by half; OFF changes
## nothing (the golden traces and the conformance run say so too).
func test_assist() -> void:
	var won := []
	for assist in [K.ASSIST_OFF, K.ASSIST_SWING]:
		var cfg := SimTypes.MatchConfig.singles()
		cfg.difficulty = K.DIFFICULTY_MEDIUM
		cfg.points_to_win = 21
		cfg.assist = assist
		var sim := Sim.new(cfg)
		var rally := 0
		for f in 60 * 240:
			var it := SimTypes.Intent.new()
			if sim.phase == K.PHASE_SERVE_SETUP:
				it.hit_pressed = 1          # serve when it's yours; never swing
			sim.step([it])
			if sim.phase == K.PHASE_LIVE:
				rally += 1
		won.append(rally)
		sim.dispose()
	check(won[1] > won[0] * 2, "SWING plays your shots: rallies last (%d live frames against %d)" % [won[1], won[0]])
	var levels := []
	for assist in [K.ASSIST_OFF, K.ASSIST_SERVE]:
		var cfg := SimTypes.MatchConfig.singles()
		cfg.assist = assist
		var sim := Sim.new(cfg)
		var held := SimTypes.Intent.new()
		held.hit_held = 1
		for f in K.SERVE_READY_FRAMES + 12:
			sim.step([held])
		levels.append(sim.charge_level)
		sim.dispose()
	check(levels[1] < levels[0] and levels[1] > 0, "SERVE: the meter at half speed (%d against %d)" % [levels[1], levels[0]])


## An assisted match isn't counted.
func test_assist_not_recorded() -> void:
	var kept := Settings.assist_i
	var sv := fresh_save(DIR)
	var cfg := SimTypes.MatchConfig.new()
	cfg.assist = K.ASSIST_SWING
	var v := match_view(cfg)
	v.save = sv
	var wins := int(sv.data["records"]["singles_wins"])
	v.truth.match_winner = 0
	v.end.on_match_over()
	eq(int(sv.data["records"]["singles_wins"]), wins, "no win recorded")
	v.free()
	Settings.assist_i = K.ASSIST_SERVE
	eq(Settings.config_for(false, -1, K.DIFFICULTY_EASY, 5).assist, K.ASSIST_SERVE, "the setting rides on the config")
	Settings.assist_i = kept


## PORT-126: a saved couch cup asks for each player's pad on PLAY; the
## pads come back to their players whatever ids they have now.
func test_couch_cup_claims() -> void:
	var sv := fresh_save(DIR)
	var humans := [{"name": "P1", "cards": [{"device": 3, "palette": 0, "variant": 0, "paddle": 0, "number": 0}]},
		{"name": "P2", "cards": [{"device": 5, "palette": 1, "variant": 0, "paddle": 0, "number": 1}]}]
	var t := Tournament.create(77, false, K.DIFFICULTY_EASY, 5, humans)
	sv.store_tournament(t, "couch")
	var b := BracketScreen.new().setup(sv, false, true)
	runner.root.add_child(b)
	if not b.is_node_ready():
		b._ready()
	check(b.claim_needed, "a saved cup, opened: ask")
	var played := []
	b.play_couch.connect(func(cfg, venue, pads, players): played.append(pads))
	b._press_play()
	check(b.claiming, "PLAY asks for the pads")
	eq(b.page.value_of("play"), "P1: PRESS START")
	check(b.claim(9), "P1 on pad 9 now")
	check(not b.claim(9), "a pad taken once")
	eq(b.page.value_of("play"), "P2: PRESS START")
	check(b.claim(2), "P2 on pad 2")
	eq(played.size(), 1, "then the match")
	var back := sv.tournament("couch")
	eq(int(back.humans[0]["cards"][0]["device"]), 9, "P1's pad kept")
	eq(int(back.humans[1]["cards"][0]["device"]), 2, "P2's")
	b.free()
	# back from a match: the pads are known
	var b2 := BracketScreen.new().setup(sv, true, true)
	check(not b2.claim_needed, "back from a match: no asking")
	b2.free()
