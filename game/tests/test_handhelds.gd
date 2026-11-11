## Phones and handhelds (PORT-151..154): SCALE AUTO for screens a whole
## scale would leave mostly empty (a handheld's 1280x800), the touch pad
## upright under the picture and with WORDS, the handhelds' pads, a match
## pausing when the app is left, and the Web build's sound pack.
extends TestSuite


func test_scale_auto() -> void:
	var kept := [Settings.scale_auto, Settings.integer_scale]
	Settings.scale_auto = true
	for case: Array in [[Vector2i(1920, 1080), true], [Vector2i(3840, 2160), true], [Vector2i(960, 540), true],
			[Vector2i(1280, 800), false], [Vector2i(1366, 768), false], [Vector2i(2560, 1440), false],
			[Vector2i(1280, 720), false], [Vector2i(1920, 1200), true], [Vector2i(390, 844), false]]:
		eq(Settings.integer_for(case[0]), case[1], "AUTO at %s" % case[0])
	Settings.scale_auto = false
	Settings.integer_scale = true
	check(Settings.integer_for(Vector2i(1280, 800)), "PIXEL: whole scales anyway")
	Settings.integer_scale = false
	check(not Settings.integer_for(Vector2i(1920, 1080)), "FILL: never")
	# SCALE's three values, round
	Settings.scale_auto = true
	eq(Settings.scale_name(), "AUTO")
	Settings.change_scale(1)
	eq(Settings.scale_name(), "PIXEL")
	Settings.change_scale(1)
	eq(Settings.scale_name(), "FILL")
	Settings.change_scale(1)
	eq(Settings.scale_name(), "AUTO")
	Settings.scale_auto = kept[0]
	Settings.integer_scale = kept[1]


## A save from before SCALE AUTO: the default (PIXEL) becomes AUTO; a
## FILL chosen stays FILL.
func test_scale_old_saves() -> void:
	var kept := [Settings.scale_auto, Settings.integer_scale]
	var sv := fresh_save("user://test_handhelds/")
	var st: Dictionary = sv.data["settings"]
	st.erase("scale_auto")
	st["integer_scale"] = 1
	Settings.load_from(sv)
	eq(Settings.scale_name(), "AUTO", "the old default goes AUTO")
	st["integer_scale"] = 0
	Settings.load_from(sv)
	eq(Settings.scale_name(), "FILL", "FILL stays FILL")
	Settings.scale_auto = kept[0]
	Settings.integer_scale = kept[1]


func test_portrait() -> void:
	check(Settings.portrait(Vector2i(390, 844)), "a phone upright")
	check(not Settings.portrait(Vector2i(844, 390)), "on its side")
	check(not Settings.portrait(Vector2i(1280, 800)), "a handheld")


## Upright phones: the pad's parts in the space under the picture, on the
## screen, apart, bigger than on its side, and each under its own touch.
func test_touch_pad_upright() -> void:
	var kept := Settings.touch_words
	for words in [false, true]:
		Settings.touch_words = words
		for phone: Vector2 in [Vector2(390, 844), Vector2(412, 915), Vector2(360, 780), Vector2(430, 932)]:
			var view := Vector2(960, 960.0 * phone.y / phone.x)
			var pad := TouchPad.new()
			pad._ready()
			pad.relayout(view)
			var where := "%s%s" % [phone, " WORDS" if words else ""]
			check(pad.k > 1.5, "bigger upright, %s: %.2f" % [where, pad.k])
			var parts := pad.parts()
			var keys := parts.keys()
			for i in keys.size():
				var r: Rect2 = parts[keys[i]]
				check(r.position.y >= 540.0, "%s: %s under the picture: %s" % [where, keys[i], r])
				check(Rect2(Vector2.ZERO, view).encloses(r), "%s: %s on the screen: %s" % [where, keys[i], r])
				for j in range(i + 1, keys.size()):
					check(not r.intersects(parts[keys[j]]), "%s: %s and %s apart" % [where, keys[i], keys[j]])
			for a in TouchPad.FACES:
				eq(pad.target_at(pad.centre_of(a)), a, "%s: %s under its button" % [where, a])
			for a in pad.pills:
				eq(pad.target_at((pad.pills[a] as Rect2).get_center()), a, "%s: %s" % [where, a])
			eq(pad.target_at(pad.dpad_at), "dpad", where + ": the D-pad")
			eq(pad.target_at(Vector2(480, 270)), "", where + ": the picture is nobody's")
			for a in pad._letters:
				var letter: BitmapText = pad._letters[a]
				var w := BitmapText.measure(letter.font, letter.text) * letter.scale.x
				check(letter.position.x - w / 2.0 >= 0 and letter.position.x + w / 2.0 <= view.x,
					"%s: %s's label on the screen" % [where, a])
			pad.free()
	Settings.touch_words = kept


## On its side the pad is as before; WORDS labels its buttons, which
## still fit the screen and keep apart.
func test_touch_words() -> void:
	var kept := Settings.touch_words
	Settings.touch_words = false
	var pad := TouchPad.new()
	pad._ready()
	eq(pad.dpad_at, TouchPad.DPAD, "landscape: the old layout")
	eq(pad.centre_of("hit"), TouchPad.face_centre("hit"))
	eq(Prompts.touch_glyph("hit")["text"], "B", "the SNES pad's letter")
	pad.free()
	Settings.touch_words = true
	pad = TouchPad.new()
	pad._ready()
	eq(Prompts.touch_glyph("hit")["text"], "HIT")
	eq(Prompts.touch_glyph("special")["text"], "SPECIAL")
	eq(String(pad._letters["drive"].text), "DRIVE", "the button says what it does")
	var parts := pad.parts()
	for k in parts:
		check(Rect2(0, 0, 960, 540).encloses(parts[k]), "WORDS: %s on the screen %s" % [k, parts[k]])
	for a in TouchPad.FACES:
		var letter: BitmapText = pad._letters[a]
		check(BitmapText.measure(letter.font, letter.text) <= pad.face_r * 2.0 - 4.0,
			"%s fits its button" % letter.text)
		eq(pad.target_at(pad.centre_of(a)), a)
	pad.free()
	Settings.touch_words = kept


## Handheld PCs' pads draw Xbox letters (their buttons are A B X Y there).
func test_handheld_pads() -> void:
	for name in ["Steam Deck", "Steam Virtual Gamepad", "Steam Deck Controller", "ROG Ally", "Legion Go"]:
		eq(Prompts.family_of(name), Prompts.XBOX, name)


## Leaving the app (focus lost, suspended) pauses a match; never the demo.
func test_leaving_pauses() -> void:
	var cfg := SimTypes.MatchConfig.new()
	var v := match_view(cfg)
	v.sim.p1_bot = false              # the bot's intent would drop the pause
	for f in 30:
		v._physics_process(1.0 / 60.0)
	check(not v.sim.paused, "playing")
	GameControls.away_serial += 1
	v._physics_process(1.0 / 60.0)
	v._physics_process(1.0 / 60.0)
	check(v.sim.paused, "the app was left: paused")
	v.free()
	var demo := match_view(cfg, "park", true)
	GameControls.away_serial += 1
	for f in 3:
		demo._physics_process(1.0 / 60.0)
	check(not demo.sim.paused, "the demo plays on")
	demo.free()


## The sound pack (PORT-154): a desktop build has the music; the pack's
## files are the music and ambience as imported, and the Web preset
## leaves them out of its own pack.
func test_sound_pack() -> void:
	check(not SoundPack.needed(), "this build has its music")
	var entries: Array = load("res://tools/sound_pack.gd").entries()
	var music := 0
	var imported := 0
	for e: Array in entries:
		var path := String(e[0])
		check(FileAccess.file_exists(path), "in the project: " + path)
		if path.ends_with(".ogg.import"):
			music += 1
			check(path.get_file().begins_with("music_") or path.get_file().begins_with("ambience_"), path)
		elif path.begins_with("res://.godot/imported/"):
			imported += 1
	check(music >= 20, "the music and ambience: %d" % music)
	eq(imported, music, "each with its imported file")
	check(SoundPack.PROBE + ".import" in entries.map(func(e): return e[0]), "the probe is in the pack")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var web := ""
	for s in presets.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options") and presets.get_value(s, "name", "") == "Web":
			web = String(presets.get_value(s, "exclude_filter", ""))
	check(web.contains("assets/audio/music_*.ogg") and web.contains("assets/audio/ambience_*.ogg"),
		"the Web pack leaves them out")
	var head := ""
	for s in presets.get_sections():
		if s.ends_with(".options") and presets.has_section_key(s, "html/head_include"):
			head = String(presets.get_value(s, "html/head_include", ""))
	check(head.contains("touch-action") and head.contains("contextmenu"),
		"the Web page keeps the browser's gestures off the game (PORT-151)")
