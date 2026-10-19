## Title: the logo and the menu over a live CPU demo at the chosen venue.
## The menu is a tree of MenuPages (ADR-025/030): MAIN opens MATCH SETUP,
## COURT, MODIFIERS, OPTIONS and CAREER (ADR-047: the players, their
## cards and editor, and the records); SINGLES and DOUBLES open Player
## Select (ADR-020), PRACTICE the drill editor (PracticePage, ADR-028),
## OPEN PLAY the park (ParkView, ADR-034).
## Up/Down pick a row, Left/Right change it, B/Start press it, Y goes
## back; every page change swallows the press that made it (rule 9). The
## values themselves live in Settings.
class_name TitleScreen
extends Node2D

## `pads`: each slot's controller in a multiplayer match ([] otherwise);
## `players`: each slot's player number (P1 = 0; -1 a CPU).
signal start_match(cfg: SimTypes.MatchConfig, venue: String, ladder: bool, pads: Array,
	players: Array)
## OPEN PLAY (ADR-034): the park; 2P comes along when PLAYERS is 2P.
signal open_park(two_players: bool)
signal open_tournament          ## PORT-25: the bracket
signal open_couch_cup(entries: Array, doubles: bool)   ## PORT-29: the lobby's cup
signal open_lesson(index: int)  ## PORT-30: HOW TO PLAY from this lesson on
signal open_online              ## PORT-31: 1 vs 1 over the internet

const SWITCH_LOCK := MenuPage.TRANSITION   ## no menu input while a page slides in

## The main page's cursor, kept across matches.
static var main_cursor := 0

var _demo: MatchView
var _ui: CanvasLayer
var _sfx: Sfx
var _lock := 10
var _demo_doubles := true
var save: SaveGame
var _record: BitmapText
var pages := {}                  ## id -> MenuPage
var page := "main"               ## the open page ("practice": the drill editor)
var practice_page: PracticePage  ## the drill editor, over the menu while open
var select := PlayerSelect.new()
var select_screen: SelectScreen
var _select_doubles := false
var _header: Array = []          # the logo and record line (hidden on Player Select)
var _pad2_prev := 0
var build_label: BitmapText
## MULTIPLAYER (PORT-16): the lobby and its screen.
var lobby := Lobby.new()
var lobby_screen: LobbyScreen
## CAREER (ADR-047): the page's logic (CareerPage), its name keyboard, and
## the player's portrait beside the card and the editor.
var career_page := CareerPage.new()
var career_keyboard: CareerKeyboard
var career_preview: CareerPreview
## The HAT MUSEUM (SNES ADR-061), from the career card.
var museum := Museum.new()
var hat_museum: HatMuseum
var _spare_career := Career.new()      ## no save (some tests): nobody


func _load_settings() -> void:
	Settings.load_from(save)


func _store_settings() -> void:
	Settings.store_to(save)


## The title's music (PORT-22), on every page.
func music_track() -> String:
	return "title"


func _ready() -> void:
	_load_settings()
	_start_demo()
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.35)
	shade.size = Vector2(960, 540)
	_ui.add_child(shade)
	var logo := BitmapText.new()
	logo.font = "big_gold"
	logo.text = "PICKLEBALL '94"
	logo.align = 0.5
	logo.position = Vector2(480, 30)
	logo.scale = Vector2(2, 2)
	logo.position.x = 480
	_ui.add_child(logo)
	var sub := BitmapText.new()
	sub.font = "small"
	sub.text = "ARCADE PICKLEBALL"
	sub.align = 0.5
	sub.position = Vector2(480, 94)
	_ui.add_child(sub)
	# the four swings and SHORT (SNES ADR-056); moving needs no telling
	var keys := PromptBar.new().setup([["hit", "HIT"], ["drive", "DRIVE"], ["soft", "SOFT"],
		["slice", "SLICE"], ["short", "SHORT"], ["start", "PAUSE"]], Vector2(480, 518))
	_ui.add_child(keys)
	_record = BitmapText.new()
	_record.font = "small"
	_record.align = 0.5
	_record.position = Vector2(480, 118)
	_record.tint = Color(0.8, 0.85, 0.95)
	_ui.add_child(_record)
	var build := BitmapText.new()
	build.font = "small"
	build.text = BuildInfo.label()
	build.align = 1.0
	build.position = Vector2(950, 6)
	build.tint = Color(0.75, 0.8, 0.9, 0.7)
	_ui.add_child(build)
	build_label = build
	_header = [logo, sub, _record, keys, build]
	_build_pages()
	lobby_screen = LobbyScreen.new().setup(lobby)
	lobby_screen.visible = false
	_ui.add_child(lobby_screen)
	career_preview = CareerPreview.new().setup()
	career_preview.visible = false
	_ui.add_child(career_preview)
	career_keyboard = CareerKeyboard.new().setup(career_page)
	career_keyboard.visible = false
	career_keyboard.typed.connect(func(_k):
		_career_input(CareerPage.PAD_B)
		_sfx.play("blip"))
	_ui.add_child(career_keyboard)
	practice_page = PracticePage.new()
	practice_page.visible = false
	_ui.add_child(practice_page)
	select_screen = SelectScreen.new().setup(select)
	select_screen.visible = false
	_ui.add_child(select_screen)
	hat_museum = HatMuseum.new().setup(museum)
	hat_museum.visible = false
	hat_museum.pressed.connect(museum_input)
	_ui.add_child(hat_museum)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	pages["main"].cursor = clampi(main_cursor, 0, pages["main"].rows.size() - 1)
	_show("main")
	Settings.apply_window(get_window())    # last: a mode change can run a frame


func _add_page(id: String, title: String, rows: Array, help: Array,
		at := Rect2(300, 172, 360, 0)) -> void:
	if id != "main":
		rows.append({"id": "back", "label": "BACK", "press": back})
	# top pad, the rows, then a footer that keeps the prompt bar clear of them
	# (MAIN has none: the key legend under it says HIT, and its rows need the room)
	var h := 18 + rows.size() * MenuPage.ROW_H + (52 if not help.is_empty() else 12) \
		+ (46 if title != "" else 0)
	at.size.y = maxi(h, 300)
	var p := MenuPage.new().setup(id, title, rows, at, help)
	# the mouse: hover selects, click presses, wheel changes, right click backs
	p.pressed.connect(func(row): _after_press(row))
	p.changed.connect(func(_row):
		_sfx.play("blip")
		_refresh())
	p.hovered.connect(func(_row): _sfx.play("blip"))
	p.back_requested.connect(back)
	p.visible = false
	_ui.add_child(p)
	pages[id] = p


func _build_pages() -> void:
	var help := [["hit", "SELECT"], ["back", "BACK"]]
	_add_page("main", "", [
		{"id": "singles", "label": "SINGLES", "press": func(): open_select(false)},
		{"id": "doubles", "label": "DOUBLES", "press": func(): open_select(true)},
		{"id": "openplay", "label": "OPEN PLAY", "value": func(): return "THE PARK",
			"press": _open_park},
		{"id": "multiplayer", "label": "MULTIPLAYER", "value": func(): return "ONLINE",
			"press": func(): open_page("multi")},
		{"id": "tournament", "label": "TOURNAMENT", "value": _cup_label, "press": _open_tournament},
		{"id": "play", "label": "MATCH SETUP", "value": _play_summary,
			"press": func(): open_page("play")},
		{"id": "practice", "label": "PRACTICE", "value": _learn_label,
			"press": func(): open_page("learn")},
		{"id": "court", "label": "COURT", "value": func(): return Settings.VENUE_NAMES[Settings.venue_i] + (
			"" if Settings.time_i == 0 else " " + CourtStyle.time_names()[Settings.time_i]),
			"press": func(): open_page("court")},
		{"id": "modifiers", "label": "MODIFIERS", "value": _mods_label,
			"press": func(): open_page("modifiers")},
		{"id": "options", "label": "OPTIONS", "press": func(): open_page("options")},
		{"id": "career", "label": "CAREER", "value": _career_label, "press": open_career},
	], [], Rect2(300, 146, 360, 0))
	_add_page("play", "MATCH SETUP", [
		{"id": "vs", "label": "VS", "value": _opponent_label, "change": _change_opponent},
		{"id": "difficulty", "label": "DIFFICULTY", "value": func(): return Settings.DIFFICULTIES[Settings.difficulty_i],
			"change": func(d): Settings.difficulty_i = clampi(Settings.difficulty_i + d, 0, Settings.DIFFICULTIES.size() - 1)},
		{"id": "points", "label": "POINTS", "value": func(): return str(Settings.POINTS[Settings.points_i]),
			"change": func(d): Settings.points_i = clampi(Settings.points_i + d, 0, Settings.POINTS.size() - 1)},
		{"id": "players", "label": "PLAYERS", "value": func(): return "2P VS" if Settings.two_players else "1P",
			"change": func(_d):
				Settings.two_players = not Settings.two_players
				GameControls.refresh_pads()},
	], help)
	var court_rows := [{"id": "venue", "label": "VENUE", "value": func(): return Settings.VENUE_NAMES[Settings.venue_i],
		"change": func(d): Settings.venue_i = (Settings.venue_i + d + Settings.VENUES.size()) % Settings.VENUES.size(); _start_demo()},
		{"id": "time", "label": "TIME", "value": func(): return CourtStyle.time_names()[Settings.time_i],
			"change": func(d):
				var n := CourtStyle.time_names().size()
				Settings.time_i = (Settings.time_i + d + n) % n
				_start_demo()}]
	for i in CourtStyle.PARTS.size():
		var part: String = CourtStyle.PARTS[i]
		court_rows.append({"id": part, "label": CourtStyle.PART_NAMES[i],
			"value": func(): return CourtStyle.names(part)[Settings.court[i]],
			"change": func(d):
				Settings.court[i] = (Settings.court[i] + d + CourtStyle.count(part)) % CourtStyle.count(part)
				_demo.set_court(Settings.court)})
	_add_page("court", "COURT", court_rows, help, Rect2(590, 150, 350, 0))
	var mod_rows := []
	for m in Settings.MOD_ROWS:
		var bit: int = m[2]
		mod_rows.append({"id": m[0], "label": m[1],
			"value": func(): return "ON" if Settings.mod_bits & bit else "OFF",
			"change": func(_d): Settings.mod_bits ^= bit})
	_add_page("modifiers", "MODIFIERS", mod_rows, help, Rect2(300, 146, 360, 0))   # 7 rows: as high as MAIN
	# PORT-31: local (the lobby, up to four pads) or online (1 vs 1)
	_add_page("multi", "MULTIPLAYER", [
		{"id": "local", "label": "LOCAL", "value": func(): return "UP TO 4 PADS", "press": open_lobby},
		{"id": "online", "label": "ONLINE", "value": func(): return "1 VS 1", "press": func():
			if _sfx:
				_sfx.play("confirm")
			_store_settings()
			main_cursor = pages["main"].cursor
			open_online.emit()},
	], help)
	# PORT-30: HOW TO PLAY's lessons, and the ball machine
	_add_page("learn", "PRACTICE", [
		{"id": "lessons", "label": "HOW TO PLAY", "value": func(): return "%d/%d" % [
			save.lessons_done() if save else 0, Tutorial.LESSONS.size()],
			"press": func(): _start_lesson(save.next_lesson() if save else 0)},
		{"id": "lesson", "label": "LESSON", "value": func(): return "%d %s" % [lesson_i + 1,
			Tutorial.LESSONS[lesson_i]["title"]],
			"change": func(d): lesson_i = (lesson_i + d + Tutorial.LESSONS.size()) % Tutorial.LESSONS.size(),
			"press": func(): _start_lesson(lesson_i)},
		{"id": "machine", "label": "BALL MACHINE", "press": _open_practice},
	], help)
	_add_page("options", "OPTIONS", [
		{"id": "camera", "label": "CAMERA",
			"value": func(): return "OFF" if Settings.camera_i == 0 else "%d%%" % Settings.CAMERAS[Settings.camera_i],
			"change": func(d): Settings.camera_i = clampi(Settings.camera_i + d, 0, Settings.CAMERAS.size() - 1)},
		{"id": "sound", "label": "SOUND", "value": func(): return AudioMap.SOUND_NAMES[Sfx.setting],
			"change": func(d): Sfx.setting = (Sfx.setting + d + 3) % 3},
		{"id": "music", "label": "MUSIC", "value": func(): return Music.volume_name(),
			"change": func(d): Music.volume = clampi(Music.volume + d, 0, Music.VOLUMES)},
		{"id": "fullscreen", "label": "FULLSCREEN", "value": func(): return "ON" if Settings.fullscreen else "OFF",
			"change": func(_d): Settings.fullscreen = not Settings.fullscreen; Settings.apply_window(get_window())},
		{"id": "scale", "label": "SCALE", "value": func(): return "PIXEL" if Settings.integer_scale else "FILL",
			"change": func(_d): Settings.integer_scale = not Settings.integer_scale; Settings.apply_window(get_window())},
		{"id": "controls", "label": "CONTROLS", "press": func(): open_page("controls")},
		{"id": "access", "label": "ACCESSIBILITY", "press": func(): open_page("access")},
		# PORT-32: the in-game updater
		{"id": "updates", "label": "UPDATES", "value": func():
			return Updater.instance.label() if Updater.instance else "DEV BUILD",
			"press": func():
				if Updater.instance:
					Updater.instance.press()},
	], [], Rect2(300, 146, 360, 0))
	var onoff := func(on: bool) -> String: return "ON" if on else "OFF"
	_add_page("access", "ACCESSIBILITY", [
		{"id": "shake", "label": "SCREEN SHAKE", "value": func(): return onoff.call(Settings.shake),
			"change": func(_d): Settings.shake = not Settings.shake},
		{"id": "flashes", "label": "FLASHES", "value": func(): return onoff.call(Settings.flashes),
			"change": func(_d): Settings.flashes = not Settings.flashes},
		{"id": "hud", "label": "HUD TEXT", "value": func(): return "LARGE" if Settings.hud_large else "NORMAL",
			"change": func(_d): Settings.hud_large = not Settings.hud_large},
		{"id": "assist", "label": "SERVE ASSIST", "value": func(): return onoff.call(Settings.serve_assist),
			"change": func(_d): Settings.serve_assist = not Settings.serve_assist},
		{"id": "vibration", "label": "VIBRATION", "value": func(): return onoff.call(Settings.vibration),
			"change": func(_d):
				Settings.vibration = not Settings.vibration
				GameControls.rumble(0, 0.4, 0.4, 0.15)},       # a taste of it
	], help, Rect2(280, 172, 400, 0))
	var control_rows := []
	for a in Bindings.ACTIONS:
		var action: String = a
		control_rows.append({"id": action, "label": Bindings.NAMES[action],
			"value": func(): return "PRESS A KEY OR BUTTON" if listening == action else Bindings.describe(action),
			"press": func(): listen(action)})
	control_rows.append({"id": "icons", "label": "BUTTON ICONS",
		"value": func(): return Prompts.FAMILY_NAMES[Settings.pad_glyphs],
		"change": func(d):
			Settings.pad_glyphs = (Settings.pad_glyphs + d + Prompts.FAMILIES.size()) % Prompts.FAMILIES.size()
			GameControls.device_serial += 1})        # every prompt bar redraws
	control_rows.append({"id": "reset", "label": "RESET DEFAULTS", "press": func():
		Bindings.reset()
		_store_settings()})
	_add_page("controls", "CONTROLS", control_rows, [["hit", "REBIND"], ["back", "BACK"]],
		Rect2(250, 34, 460, 0))          # high: SLICE and SHORT made it 13 rows
	career.build_pages()
	_add_page("records", "RECORDS", [
		{"id": "singles", "label": "SINGLES", "value": func(): return _wl("singles")},
		{"id": "doubles", "label": "DOUBLES", "value": func(): return _wl("doubles")},
		{"id": "streak", "label": "BEST STREAK", "value": func(): return _held("best_streak")},
		{"id": "rally", "label": "LONGEST RALLY", "value": func(): return _held("longest_rally")},
		{"id": "points", "label": "POINTS", "value": func(): return "%d-%d" % [_rec("points_won"), _rec("points_lost")]},
		{"id": "aces", "label": "ACES  WINNERS", "value": func(): return "%d  %d" % [_rec("aces"), _rec("winners")]},
		{"id": "shutouts", "label": "SHUTOUTS  CUPS", "value": func(): return "%d  %d" % [
			_rec("shutouts"), _rec("cups")]},    # PORT-25: tournaments won
		{"id": "ladder", "label": "LADDER", "value": func(): return "S %d/%d  D %d/%d  CLEARS %d" % [
			_rung() + 1, Opponents.count(), _rung(true) + 1, Opponents.count(), _rec("ladder_clears")]},
		{"id": "practice", "label": "PRACTICE BEST", "value": func(): return str(_rec("practice_best"))},
		{"id": "vs", "label": "VS", "value": _vs_label,
			"change": func(d): vs_i = (vs_i + d + Opponents.count()) % Opponents.count()},
		{"id": "erase", "label": "ERASE RECORDS", "value": func(): return "B AGAIN" if _erase_armed else "",
			"press": _erase},
	], [["back", "BACK"]], Rect2(230, 46, 500, 0))   # wide: LADDER shows both modes


# --- CAREER (ADR-047): view/title_career.gd -------------------------------------------

var career: TitleCareer:
	get:
		if _career_c == null:
			_career_c = TitleCareer.new(self)    # also before _ready (some tests)
		return _career_c
var _career_c: TitleCareer


func _career() -> Career:
	return career.career()


func _career_label() -> String:
	return career.label()


func open_career() -> void:
	career.open()


func _career_input(bits: int) -> void:
	career.input(bits)


func _back_to_main(row: String) -> void:
	career.back_to_main(row)


func _after_press(id: String) -> void:
	if id not in ["singles", "doubles", "back"]:
		_sfx.play("confirm")
	_refresh()


func _rec(key: String) -> int:
	return int(save.data["records"][key]) if save else 0


## A named record (ADR-040): who holds it (--- for nobody) and the count.
func _held(key: String) -> String:
	var who: String = String(save.data["initials"].get(key, "")) if save else ""
	return "%s %d" % [who if who != "" else "---", _rec(key)]


var vs_i := 0
var _erase_armed := false

func _vs_label() -> String:
	var r: Array = save.data["records"]["vs"][vs_i] if save else [0, 0]
	return "%s %d-%d" % [String(Opponents.team(vs_i)["team"]), int(r[0]), int(r[1])]


## ERASE RECORDS: the first press arms, the second erases (the settings
## stay, as ADR-021's erase).
func _erase() -> void:
	if not _erase_armed:
		_erase_armed = true
		return
	_erase_armed = false
	if save:
		save.erase_records()
		save.save_game()
	_refresh()


func _wl(mode: String) -> String:
	return "%d-%d" % [_rec(mode + "_wins"), _rec(mode + "_losses")]


func _play_summary() -> String:
	return "%s  %d" % [Settings.DIFFICULTIES[Settings.difficulty_i], Settings.POINTS[Settings.points_i]]


func _mods_label() -> String:
	var on := Settings.MOD_ROWS.filter(func(m): return Settings.mod_bits & m[2])
	if on.is_empty():
		return "NONE"
	return on[0][1] if on.size() == 1 else "%d ON" % on.size()


func _change_opponent(dir: int) -> void:
	Settings.opponent_i += dir
	if Settings.opponent_i < -2:
		Settings.opponent_i = Opponents.count() - 1
	elif Settings.opponent_i >= Opponents.count():
		Settings.opponent_i = -2
	if Settings.opponent_i != -1:
		Settings.venue_i = Settings.VENUES.find(Settings.home_venue(_rung() if Settings.opponent_i == -2 else Settings.opponent_i))
		_start_demo()


## Shows one page (or "practice", the drill editor) and hides the rest.
func _show(id: String) -> void:
	page = id
	for k in pages:
		pages[k].visible = k == id
	if practice_page:
		practice_page.visible = id == "practice"
	if career_keyboard:
		career_keyboard.visible = id == "career_name"
	if career_preview:
		career_preview.visible = id in ["career_card", "career_edit", "career_name"]
	if id != "career_card":
		career.delete_armed = false
	if select_screen:
		select_screen.visible = id == "select"
	if hat_museum:
		hat_museum.visible = id == "museum"
	for n in _header:
		n.visible = not id in ["select", "records", "controls", "lobby", "museum", "career_card", "career_edit",
			"career_name"]
	if lobby_screen:
		lobby_screen.visible = id == "lobby"
	_erase_armed = false
	if pages.has(id):
		pages[id].refresh()
	_refresh()


## Opens a page by id; the press that opened it is swallowed (rule 9).
func open_page(id: String) -> void:
	if not pages.has(id):
		return
	_show(id)
	pages[id].appear(1)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## Y or BACK: a sub-page returns to MAIN, its cursor on the page's row.
func back() -> void:
	if page == "main":
		return
	# CAREER's pages and its records go back through the page's logic (Y)
	if page.begins_with("career") or page == "records":
		_career_input(CareerPage.PAD_Y)
		if _sfx:
			_sfx.play("back")
		return
	var from := page
	_show("main")
	pages["main"].select(from)
	pages["main"].appear(-1)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	if _sfx:
		_sfx.play("back")


func page_open() -> bool:
	return page == "practice"


## HAT MUSEUM on the career card: the player's hats in their cases.
func open_museum() -> void:
	museum.begin(career.career(), career_page.slot)
	_show("museum")
	hat_museum.refresh()
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## One frame of the museum: Y or Start back to the card (writing the save
## if a hat was put on).
func museum_input(pressed: int) -> void:
	if pressed == 0:
		return
	var was := [museum.cursor, museum.player().hat]
	var result := museum.input(pressed)
	if result != Museum.STAY:
		if result == Museum.CLOSE_SAVE and save:
			save.save_game()
		_show("career_card")
		pages["career_card"].select("hats")
		pages["career_card"].appear(-1)
		career.sync(false)
		_lock = SWITCH_LOCK
		GameControls.clear_latch()
		_sfx.play("back")
	elif museum.player().hat != was[1]:
		_sfx.play("confirm")
	elif museum.cursor != was[0]:
		_sfx.play("blip")


## SINGLES / DOUBLES: Player Select for 1P (on their last choice), then 2P.
func open_select(doubles: bool) -> void:
	_select_doubles = doubles
	# ADR-047: 1P starts on the career player's body, shirt, and paddle;
	# changes here are for this match.
	var me := _career().active_player()
	var p1: Dictionary = Settings.p1_choice if me == null else PlayerSelect.new_choice(me.shirt, me.variant, me.paddle)
	select.begin(K.MODE_DOUBLES if doubles else K.MODE_SINGLES, 2 if Settings.two_players else 1, p1)
	select.choice[1] = Settings.p2_choice.duplicate()
	select_screen.career = me
	main_cursor = pages["main"].cursor
	_show("select")
	select_screen.refresh()
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## One frame of Player Select; while 2P chooses, their pad drives it (and
## P1's keys, so a single keyboard can still set up a 2P match).
func select_input(pressed: int) -> void:
	if pressed == 0:
		return
	var was := [select.row, select.current]
	var result := select.input(pressed)
	if result == PlayerSelect.BACK:
		_show("main")
		_lock = SWITCH_LOCK
		GameControls.clear_latch()
		_sfx.play("back")
	elif result == PlayerSelect.DONE:
		if _career().active_player() == null:
			Settings.p1_choice = select.choice[0].duplicate()
		if select.humans == 2:
			Settings.p2_choice = select.choice[1].duplicate()
		_start(_select_doubles)
	else:
		_sfx.play("confirm" if select.current != was[1] else "blip")
		select_screen.refresh()


## 2P's newly pressed buttons on pad 1 (the input map is P1's).
func _pad2_pressed() -> int:
	var held := 0
	var dev := GameControls.p2_pad
	if dev >= 0 and dev in Input.get_connected_joypads():
		for pair in [[JOY_BUTTON_DPAD_UP, Practice.PAD_UP], [JOY_BUTTON_DPAD_DOWN, Practice.PAD_DOWN],
				[JOY_BUTTON_DPAD_LEFT, Practice.PAD_LEFT], [JOY_BUTTON_DPAD_RIGHT, Practice.PAD_RIGHT],
				[JOY_BUTTON_A, Practice.PAD_B], [JOY_BUTTON_X, Practice.PAD_Y],
				[JOY_BUTTON_START, Practice.PAD_START]]:
			if Input.is_joy_button_pressed(dev, pair[0]):
				held |= pair[1]
	var pressed := held & ~_pad2_prev
	_pad2_prev = held
	return pressed


## MULTIPLAYER: a fresh lobby every time (pads may have changed).
func open_lobby() -> void:
	lobby = Lobby.new()
	lobby.mode = K.MODE_DOUBLES
	lobby_screen.lobby = lobby
	main_cursor = pages["main"].cursor
	_show("lobby")
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	for dev in GameControls.connected_pads():
		GameControls.pad_menu_bits(dev)  # a button already down isn't a press


## One frame of the lobby: every connected pad's presses; the keyboard
## can only leave (L or Esc) while nobody has joined.
func _update_lobby() -> void:
	for dev in GameControls.connected_pads():
		var bits: int = GameControls.pad_menu_bits(dev)[0]
		if bits == 0:
			continue
		var before := lobby.joined().size()
		var result := lobby.input(dev, bits)
		if result == Lobby.START:
			start_lobby_match()
			return
		if result == Lobby.LEAVE:
			_leave_lobby()
			return
		_sfx.play("confirm" if lobby.joined().size() > before else "blip")
	if lobby.joined().is_empty() and (Input.is_action_just_pressed("soft")
			or Input.is_action_just_pressed("start") or Input.is_action_just_pressed("drive")):
		_leave_lobby()


func _leave_lobby() -> void:
	_show("main")
	pages["main"].select("multiplayer")
	pages["main"].appear(-1)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	_sfx.play("back")


## Everyone's ready: the lobby's match at the chosen court, with the match
## settings (difficulty for the CPUs, points, modifiers).
func start_lobby_match() -> void:
	_sfx.play("confirm")
	_store_settings()
	if lobby.cup:
		open_couch_cup.emit(lobby.entries(), lobby.mode == K.MODE_DOUBLES)
		return
	var cfg := lobby.match_config(Settings.difficulty_i, Settings.POINTS[Settings.points_i],
		Settings.mod_bits)
	start_match.emit(cfg, Settings.venue(), false, lobby.slot_pads(), lobby.slot_players())


func _start(doubles: bool) -> void:
	if _sfx:
		_sfx.play("confirm")
	_store_settings()
	main_cursor = pages["main"].cursor
	start_match.emit(config(doubles), Settings.venue(), Settings.opponent_i == -2 and not Settings.two_players, [], [])


## TOURNAMENT's value: your round in a bracket in play, else cups won.
func _cup_label() -> String:
	var t := save.tournament() if save else null
	if t and not t.next_match().is_empty():
		return Tournament.ROUND_SHORT[int(t.next_match()["round"])]
	var cups: int = int(save.data["records"]["cups"]) if save else 0
	return "%d CUP%s" % [cups, "" if cups == 1 else "S"] if cups else "8 TEAMS"


func _open_tournament() -> void:
	if _sfx:
		_sfx.play("confirm")
	_store_settings()
	main_cursor = pages["main"].cursor
	open_tournament.emit()


func _open_park() -> void:
	_store_settings()
	main_cursor = pages["main"].cursor
	open_park.emit(Settings.two_players)


## PRACTICE's value on MAIN: an invitation until a lesson's been done.
func _learn_label() -> String:
	return "HOW TO PLAY" if save == null or save.lessons_done() == 0 else ""


var lesson_i := 0                ## PRACTICE's LESSON row


func _start_lesson(i: int) -> void:
	if _sfx:
		_sfx.play("confirm")
	_store_settings()
	main_cursor = pages["main"].cursor
	open_lesson.emit(i)


func _open_practice() -> void:
	practice_page.open(save)
	_show("practice")
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## One frame of the practice page: B or Start saves any change and plays;
## Y goes back with the old drill.
func _update_practice(pressed: int) -> void:
	if pressed == 0:
		return
	var result := practice_page.input(pressed)
	if result == Practice.EDIT_CANCEL:
		_show("learn")              # back to PRACTICE's page (PORT-30)
		_lock = SWITCH_LOCK         # the closing press isn't a menu press
		_sfx.play("back")
	elif result == Practice.EDIT_DONE:
		_sfx.play("confirm")
		_store_settings()
		main_cursor = pages["main"].cursor
		start_match.emit(practice_page.config(), Settings.venue(), false, [], [])
	else:
		_sfx.play("blip")


## A practice session on the saved drill (PracticePage.config).
func practice_config() -> SimTypes.MatchConfig:
	return practice_page.config()


func _start_demo() -> void:
	if _demo:
		_demo.queue_free()
	_demo = MatchView.new()
	add_child(_demo)
	move_child(_demo, 0)
	var cfg := SimTypes.MatchConfig.doubles() if _demo_doubles else SimTypes.MatchConfig.singles()
	_demo.court = Settings.court.duplicate()
	_demo.time = Settings.time_i
	_demo.setup(cfg, Settings.venue(), true)
	_demo._hud.visible = false


func _refresh() -> void:
	if save:
		var r: Dictionary = save.data["records"]
		_record_text = "RECORD %d-%d   LADDER S %d/%d D %d/%d   CLEARS %d" % [
			int(r["singles_wins"]) + int(r["doubles_wins"]),
			int(r["singles_losses"]) + int(r["doubles_losses"]),
			_rung() + 1, Opponents.count(), _rung(true) + 1, Opponents.count(),
			int(r["ladder_clears"])]
	_refresh_record()


var _record_text := ""
var _updates_label := ""


## The line under the logo: the updater's news while there is some
## (PORT-32), else the record.
func _refresh_record() -> void:
	var news: String = Updater.instance.notice() if Updater.instance else ""
	_record.text = news if news != "" else _record_text
	_record.tint = Color("fbe46a") if news != "" else Color(0.8, 0.85, 0.95)


func _rung(doubles := false) -> int:
	return save.ladder(doubles) if save else 0


func _opponent_label() -> String:
	if Settings.opponent_i == -2:
		return "LADDER: " + String(Opponents.team(_rung())["team"])
	if Settings.opponent_i == -1:
		return "CPU"
	return String(Opponents.team(Settings.opponent_i)["team"])


## The match SINGLES or DOUBLES starts: with a career player (ADR-047), 1P
## is them in this Player Select's choice (their saved look before one).
func config(doubles: bool) -> SimTypes.MatchConfig:
	var me := _career().active_player()
	if me == null:
		return Settings.match_config(doubles, _rung(doubles))
	var p1: Dictionary = select.choice[0] if not select.choice.is_empty() \
		else PlayerSelect.new_choice(me.shirt, me.variant, me.paddle)
	var cfg := Settings.match_config(doubles, _rung(doubles), p1)
	cfg.set_career(me)
	return cfg


## CONTROLS: the action waiting for its new key or button ("" = none).
var listening := ""


func listen(action: String) -> void:
	listening = action
	pages["controls"].refresh()


## While listening, the next key or pad button press rebinds the action
## (Esc cancels) and is swallowed (rule 9).
func _input(event: InputEvent) -> void:
	if listening == "" or not event.is_pressed() or event.is_echo():
		return
	var done := false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code != KEY_ESCAPE:
			Bindings.rebind_key(listening, code)
		done = true
	elif event is InputEventJoypadButton:
		Bindings.rebind_pad(listening, event.button_index)
		done = true
	if done:
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		listening = ""
		_store_settings()
		_lock = SWITCH_LOCK
		GameControls.clear_latch()
		pages["controls"].refresh()
		if _sfx:
			_sfx.play("confirm")


func _process(_delta: float) -> void:
	# a window-mode change in _ready can run a frame before the demo exists
	if _demo == null or _demo.sim == null:
		return
	_refresh_record()
	if page == "options" and Updater.instance and Updater.instance.label() != _updates_label:
		_updates_label = Updater.instance.label()
		pages["options"].refresh()       # the download's percentage, and when it's done
	if _demo.sim.phase == K.PHASE_MATCH_RESULT and _demo.sim.phase_timer >= K.ATTRACT_RESULT_FRAMES - 1:
		_demo_doubles = not _demo_doubles
		_start_demo()
	if _lock > 0:
		_lock -= 1
		return
	if listening != "":
		return
	if page == "practice":
		_update_practice(GameControls.pad_bits()[0])
		return
	if page == "career_name":
		var bits: int = GameControls.pad_bits()[0]
		if bits:
			_career_input(bits)
			_sfx.play("blip")
		return
	if page == "lobby":
		_update_lobby()
		return
	if page == "museum":
		museum_input(GameControls.pad_bits()[0])
		return
	if page == "select":
		var pressed: int = GameControls.pad_bits()[0]
		var p2 := _pad2_pressed()
		select_input(pressed | (p2 if select.current == 1 else 0))
		return
	var p: MenuPage = pages[page]
	if GameControls.menu_pressed("move_up"):
		p.move(-1)
		_sfx.play("blip")
	elif GameControls.menu_pressed("move_down"):
		p.move(1)
		_sfx.play("blip")
	var dir := 0
	if GameControls.menu_pressed("move_left"):
		dir = -1
	elif GameControls.menu_pressed("move_right"):
		dir = 1
	if dir != 0 and p.change(dir):
		_sfx.play("blip")
		_refresh()
	if (Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive")) \
			and page != "main":
		back()
	elif page == "career_edit" and Input.is_action_just_pressed("start"):
		_career_input(CareerPage.PAD_START)       # Start keeps, on any row
		_sfx.play("confirm")
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		var id := p.current_id()
		if p.press():
			_after_press(id)
