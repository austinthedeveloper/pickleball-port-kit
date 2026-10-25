## The title's pages as data (PORT-42 split it out of title_screen.gd, as
## title_career.gd was): every MenuPage's rows, their values and what
## Left/Right and a press do. A component of TitleScreen (`t`); the rows
## call back into it.
class_name TitlePages
extends RefCounted


static func build(t: TitleScreen) -> void:
	var help := [["hit", "SELECT"], ["back", "BACK"]]
	# ADR-079: five places to go; a match's settings are on MATCH SETUP, on
	# the way to the match, not beside the modes
	t._add_page("main", "", [
		{"id": "story", "label": "STORY", "value": func(): return StoryMode.label(t.save),
			"press": func():
				t._store_settings()
				TitleScreen.main_cursor = t.pages["main"].cursor
				t.open_story.emit()},
		{"id": "trip", "label": "ROAD TRIP", "value": func(): return RoadTrip.title_label(t.save),
			"press": func():
				t._store_settings()
				TitleScreen.main_cursor = t.pages["main"].cursor
				t.open_trip.emit()},
		{"id": "play", "label": "PLAY", "press": func(): t.open_page("play")},
		{"id": "practice", "label": "PRACTICE", "value": t._learn_label,
			"press": func(): t.open_page("learn")},
		{"id": "player", "label": "PLAYER", "value": t._career_label, "press": func(): t.open_page("player")},
		{"id": "options", "label": "OPTIONS", "press": func(): t.open_page("options")},
	], [], Rect2(300, 214, 360, 0))
	# QUICK MATCH and MATCH SETUP's MODE are one setting
	var doubles_label := func(): return "DOUBLES" if Settings.quick_doubles else "SINGLES"
	var flip_doubles := func(_d): Settings.quick_doubles = not Settings.quick_doubles
	t._add_page("play", "PLAY", [
		{"id": "quick", "label": "QUICK MATCH", "value": doubles_label,
			"change": flip_doubles,
			"press": func(): t.open_page("setup")},
		{"id": "tournament", "label": "TOURNAMENT", "value": t._cup_label, "press": t._open_tournament},
		{"id": "openplay", "label": "OPEN PLAY", "value": func(): return Settings.park_name(),
			"change": func(d): Settings.park_i = (Settings.park_i + d + Settings.PARKS.size()) \
				% Settings.PARKS.size(),
			"press": t._open_park},
		{"id": "multiplayer", "label": "MULTIPLAYER",
			"press": func(): t.open_page("multi")},
	], help, Rect2(300, 172, 360, 0))
	t._add_page("setup", "MATCH SETUP", [
		{"id": "start", "label": "START", "press": func(): t.open_select(Settings.quick_doubles)},
		{"id": "mode", "label": "MODE", "value": doubles_label,
			"change": flip_doubles},
		{"id": "players", "label": "PLAYERS", "value": func(): return "2P VS" if Settings.two_players else "1P",
			"change": func(_d):
				Settings.two_players = not Settings.two_players
				GameControls.refresh_pads()},
		{"id": "vs", "label": "VS", "value": t._opponent_label, "change": t._change_opponent},
		{"id": "difficulty", "label": "DIFFICULTY", "value": func(): return Settings.DIFFICULTIES[Settings.difficulty_i],
			"change": func(d): Settings.difficulty_i = clampi(Settings.difficulty_i + d, 0, Settings.DIFFICULTIES.size() - 1)},
		SettingRows.slider("cpu_errors"),          # ADR-073
		{"id": "points", "label": "POINTS", "value": func(): return str(Settings.POINTS[Settings.points_i]),
			"change": func(d): Settings.points_i = clampi(Settings.points_i + d, 0, Settings.POINTS.size() - 1)},
		{"id": "court", "label": "COURT", "value": func(): return Settings.VENUE_NAMES[Settings.venue_i] + (
			"" if Settings.time_i == 0 else " " + CourtStyle.time_names()[Settings.time_i]),
			"press": func(): t.open_page("court")},
		{"id": "modifiers", "label": "MODIFIERS", "value": t._mods_label,
			"press": func(): t.open_page("modifiers")},
	], [["hit", "SELECT"], ["back", "BACK"]], Rect2(270, 66, 420, 0))
	t._add_page("player", "PLAYER", [
		{"id": "career", "label": "PLAYERS", "value": t._career_label, "press": t.open_career},
		{"id": "records", "label": "RECORDS", "press": func(): t.open_page("records")},
		{"id": "achievements", "label": "ACHIEVEMENTS", "value": func(): return Achievements.label(t.save),
			"press": func(): t.open_page("achievements")},
		{"id": "replays", "label": "REPLAYS", "value": func(): return "%d SAVED" % SavedReplays.list().size(),
			"press": func(): t.open_page("replays")},
		{"id": "hats", "label": "HAT MUSEUM", "value": func(): return "" if t._career().active_player() else "NO PLAYER",
			"press": t.open_player_museum},
	], help, Rect2(300, 172, 360, 0))
	# PORT-69: the saved rallies; a press watches one (or, set to, deletes it)
	var replay_rows := []
	for i in SavedReplays.MAX:
		replay_rows.append({"id": "replay%d" % i, "label": func(): return t.replay_label(i),
			"value": func(): return t.replay_value(i), "press": func(): t.replay_press(i)})
	replay_rows.append({"id": "on_press", "label": "ON PRESS",
		"value": func(): return "DELETE" if t.replay_delete else "WATCH",
		"change": func(_d): t.replay_delete = not t.replay_delete})
	replay_rows.append({"id": "demo", "label": "IN THE DEMO",
		"value": func(): return "ON" if Settings.replays_in_demo else "OFF",
		"change": func(_d): Settings.replays_in_demo = not Settings.replays_in_demo})
	t._add_page("replays", "REPLAYS", replay_rows, help, Rect2(260, 60, 440, 0))
	var court_rows := [{"id": "venue", "label": "VENUE", "value": func(): return Settings.VENUE_NAMES[Settings.venue_i],
		"change": func(d): Settings.venue_i = (Settings.venue_i + d + Settings.venue_count()) % Settings.venue_count(); t._start_demo()},
		{"id": "time", "label": "TIME", "value": func(): return CourtStyle.time_names()[Settings.time_i],
			"change": func(d):
				var n := CourtStyle.time_names().size()
				Settings.time_i = (Settings.time_i + d + n) % n
				t._start_demo()}]
	for i in CourtStyle.PARTS.size():
		var part: String = CourtStyle.PARTS[i]
		court_rows.append({"id": part, "label": CourtStyle.PART_NAMES[i],
			"value": func(): return CourtStyle.names(part)[Settings.court[i]],
			"change": func(d):
				Settings.court[i] = (Settings.court[i] + d + CourtStyle.count(part)) % CourtStyle.count(part)
				t._demo.set_court(Settings.court)})
	t._add_page("court", "COURT", court_rows, help, Rect2(590, 150, 350, 0))
	# ADR-071: the ball's speed, in 1% steps
	var mod_rows := {"modifiers": [SettingRows.slider("ball_speed"), SettingRows.slider("ball_size")],
		"rules": []}
	for m in Settings.MOD_ROWS:
		var bit: int = m[2]
		mod_rows[m[3]].append({"id": m[0], "label": m[1],
			"value": func(): return "ON" if Settings.mod_bits & bit else "OFF",
			"change": func(_d): Settings.mod_bits ^= bit})
	mod_rows["modifiers"].append({"id": "rules", "label": "RULES", "value": func(): return t._mods_label("rules"),
		"press": func(): t.open_page("rules")})
	# over the logo (hidden, as on CONTROLS), clear of the key legend
	t._add_page("modifiers", "MODIFIERS", mod_rows["modifiers"], help, Rect2(300, 20, 360, 0))
	t._add_page("rules", "RULES", mod_rows["rules"], help, Rect2(300, 60, 360, 0))
	# PORT-31: local (the lobby, up to four pads) or online (1 vs 1)
	t._add_page("multi", "MULTIPLAYER", [
		{"id": "local", "label": "LOCAL", "value": func(): return "UP TO 4 PADS", "press": t.open_lobby},
		{"id": "online", "label": "ONLINE", "value": func(): return "1 VS 1", "press": func():
			if t._sfx:
				t._sfx.play("confirm")
			t._store_settings()
			TitleScreen.main_cursor = t.pages["main"].cursor
			TitleScreen.return_to = "multi"
			t.open_online.emit()},
	], help)
	# PORT-30: HOW TO PLAY's lessons, and the ball machine
	t._add_page("learn", "PRACTICE", [
		{"id": "course", "label": "PICKLEBALL 101", "value": func(): return Course.label(t.save),
			"press": func():
				t._store_settings()
				t.open_course.emit()},
		{"id": "lessons", "label": "HOW TO PLAY", "value": func(): return "%d/%d" % [
			t.save.lessons_done() if t.save else 0, Tutorial.LESSONS.size()],
			"press": func(): t._start_lesson(t.save.next_lesson() if t.save else 0)},
		{"id": "lesson", "label": "LESSON", "value": func(): return "%d %s" % [t.lesson_i + 1,
			Tutorial.LESSONS[t.lesson_i]["title"]],
			"change": func(d): t.lesson_i = (t.lesson_i + d + Tutorial.LESSONS.size()) % Tutorial.LESSONS.size(),
			"press": func(): t._start_lesson(t.lesson_i)},
		{"id": "machine", "label": "BALL MACHINE", "press": t._open_practice},
	], help)
	OptionsPages.build(t)
	# the card at startup with no pad connected (port ADR-082)
	t._add_page("notice", "CONTROLLER", [
		{"id": "ok", "label": "OK", "press": t.back},
		{"id": "never", "label": "DON'T SHOW AGAIN", "press": func():
			Settings.pad_notice = false
			t._save_settings()
			t.back()},
	], [["hit", "SELECT"]], Rect2(220, 150, 520, 0))
	t.pages["notice"].set_body(["A CONTROLLER IS RECOMMENDED:", "THE GAME PLAYS BEST ON A GAMEPAD.",
		"THE KEYS ARE ON OPTIONS, CONTROLS."], MenuPage.DIM)
	t.career.build_pages()
	t._add_page("records", "RECORDS", [
		{"id": "singles", "label": "SINGLES", "value": func(): return t._wl("singles")},
		{"id": "doubles", "label": "DOUBLES", "value": func(): return t._wl("doubles")},
		{"id": "streak", "label": "BEST STREAK", "value": func(): return t._held("best_streak")},
		{"id": "rally", "label": "LONGEST RALLY", "value": func(): return t._held("longest_rally")},
		{"id": "points", "label": "POINTS", "value": func(): return "%d-%d" % [t._rec("points_won"), t._rec("points_lost")]},
		{"id": "aces", "label": "ACES  WINNERS", "value": func(): return "%d  %d" % [t._rec("aces"), t._rec("winners")]},
		{"id": "shutouts", "label": "SHUTOUTS  CUPS", "value": func(): return "%d  %d" % [
			t._rec("shutouts"), t._rec("cups")]},    # PORT-25: tournaments won
		{"id": "ladder", "label": "LADDER", "value": func(): return "S %d/%d  D %d/%d  CLEARS %d" % [
			t._rung() + 1, Opponents.count(), t._rung(true) + 1, Opponents.count(), t._rec("ladder_clears")]},
		{"id": "practice", "label": "PRACTICE BEST", "value": func(): return str(t._rec("practice_best"))},
		{"id": "achievements", "label": "ACHIEVEMENTS", "value": func(): return Achievements.label(t.save),
			"press": func(): t.open_page("achievements")},      # ADR-077
		{"id": "vs", "label": "VS", "value": t._vs_label,
			"change": func(d): t.vs_i = (t.vs_i + d + Opponents.count()) % Opponents.count()},
		{"id": "erase", "label": "ERASE RECORDS", "value": func(): return "PRESS AGAIN" if t._erase_armed else "",
			"press": t._erase},
	], [["back", "BACK"]], Rect2(230, 46, 500, 0))   # wide: LADDER shows both modes
	# ADR-077: every achievement, DONE or not; how to earn the one selected
	# shows under the panel
	var achieve_rows := []
	for a in Achievements.LIST:
		var id: String = a[0]
		achieve_rows.append({"id": id, "label": a[1],
			"value": func(): return "DONE" if Achievements.unlocked(t.save, id) else ""})
	t._add_page("achievements", "ACHIEVEMENTS", achieve_rows, [], Rect2(230, 16, 500, 0))
	t.achieve_how = UiKit.text("small", "", Vector2(480, 486), 0.5, Color("fbe46a"), t._ui)
	t.achieve_how.visible = false
