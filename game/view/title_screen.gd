## Title: the logo and the menu over a live CPU demo at the chosen venue.
## The menu is a tree of MenuPages (ADR-025/030): MAIN (SINGLES, DOUBLES,
## MATCH SETUP, PRACTICE, MODIFIERS, OPTIONS, RECORDS) opens the others.
## Up/Down pick a row, Left/Right change it, B/Start presses it, Y goes
## back. SINGLES and DOUBLES open Player Select (ADR-020; 2P picks next
## on their own pad when PLAYERS is 2P VS), then the match. PRACTICE opens the practice page (ADR-028's editor: SHOT, TARGET,
## RATE, RETURN TO, and the BEST STREAK). Every page change swallows the
## press that made it (rule 9).
class_name TitleScreen
extends Node2D

signal start_match(cfg: SimTypes.MatchConfig, venue: String, ladder: bool)

const VENUES := ["park", "lakeside", "sunset"]
const VENUE_NAMES := ["PARK", "LAKESIDE", "SUNSET"]
const DIFFICULTIES := ["KID", "EASY", "MEDIUM", "HARD"]
const POINTS := [3, 5, 7, 9, 11, 15, 21]
const PAGE_ROWS := ["SHOT", "TARGET", "RATE", "RETURN TO"]
## The old single MODS row's presets (the save's "mods" before "mod_bits").
const MODS := [[0, "NONE"], [K.MOD_BIG_BALL, "BIG BALL"], [K.MOD_FAST_BALL, "FAST BALL"],
	[K.MOD_WIN_BY_2, "WIN BY 2"], [K.MOD_LAVA, "LAVA"], [15, "ALL FOUR"]]
const MOD_ROWS := [["big_ball", "BIG BALL", K.MOD_BIG_BALL], ["fast_ball", "FAST BALL", K.MOD_FAST_BALL],
	["win_by_2", "WIN BY 2", K.MOD_WIN_BY_2], ["lava", "LAVA", K.MOD_LAVA]]
const CAMERAS := [0, 50, 75, 100]
const SWITCH_LOCK := 6           ## frames of no menu input after a page change

static var venue_i := 0
static var difficulty_i := K.DIFFICULTY_MEDIUM
static var points_i := 1
## -2 = the ladder's current rung, -1 = the default CPU, else a team.
static var opponent_i := -2
static var two_players := false
static var camera_i := 0
static var mod_bits := 0
## Window options: fullscreen, and integer scaling (crisp) or fit (fills).
static var fullscreen := false
static var integer_scale := true
## The main page's cursor, kept across matches.
static var main_cursor := 0
## Court colours: [surface, kitchen, surround, lines] presets (CourtStyle).
static var court: Array = CourtStyle.DEFAULTS.duplicate()
## The last Player Select choices (PlayerSelect.new_choice; 1P's is saved).
static var p1_choice := PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, Paddles.STANDARD)
static var p2_choice := PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD)

var _demo: MatchView
var _ui: CanvasLayer
var _sfx: Sfx
var _lock := 10
var _demo_doubles := true
var save: SaveGame
var _record: BitmapText
var pages := {}                  ## id -> MenuPage
var page := "main"               ## the open page ("practice": the drill editor)
## The practice page (PracticeEdit), over the menu while open.
var _page: Control
var _page_values: Array = []
var _page_rows: Array = []
var _page_best: BitmapText
var _page_arrow: Sprite2D
var _edit := Practice.Edit.new()
var _drill: Array = []
var select := PlayerSelect.new()
var select_screen: SelectScreen
var _select_doubles := false
var _header: Array = []          # the logo and record line (hidden on Player Select)
var _pad2_prev := 0


func _load_settings() -> void:
	if save == null:
		return
	var st: Dictionary = save.data["settings"]
	venue_i = clampi(int(st["venue"]), 0, VENUES.size() - 1)
	difficulty_i = clampi(int(st["difficulty"]), 0, DIFFICULTIES.size() - 1)
	points_i = clampi(int(st["points"]), 0, POINTS.size() - 1)
	two_players = int(st["players"]) == 2
	opponent_i = clampi(int(st["opponent"]), -2, Opponents.count() - 1)
	camera_i = clampi(int(st.get("camera", 0)), 0, CAMERAS.size() - 1)
	var bits := int(st.get("mod_bits", -1))
	mod_bits = (bits & 15) if bits >= 0 else MODS[clampi(int(st.get("mods", 0)), 0, MODS.size() - 1)][0]
	Sfx.setting = clampi(int(st.get("sound", 0)), 0, AudioMap.SOUND_NAMES.size() - 1)
	fullscreen = int(st.get("fullscreen", 0)) != 0
	integer_scale = int(st.get("integer_scale", 1)) != 0
	var ct: Array = st.get("court", CourtStyle.DEFAULTS)
	court = CourtStyle.DEFAULTS.duplicate()
	for i in mini(ct.size(), 4):
		var n := CourtStyle.count(CourtStyle.PARTS[i])
		court[i] = int(ct[i]) if int(ct[i]) >= 0 and int(ct[i]) < n else 0
	var pl: Array = st.get("player", [0, 0, 1])
	if pl.size() == 3:
		p1_choice = PlayerSelect.new_choice(clampi(int(pl[0]), 0, 3), clampi(int(pl[1]), 0, 1),
			clampi(int(pl[2]), 0, Paddles.NAMES.size() - 1))


func _store_settings() -> void:
	if save == null:
		return
	save.data["settings"].merge({"venue": venue_i, "difficulty": difficulty_i,
		"points": points_i, "players": 2 if two_players else 1, "opponent": opponent_i,
		"camera": camera_i, "mod_bits": mod_bits, "sound": Sfx.setting,
		"fullscreen": 1 if fullscreen else 0, "integer_scale": 1 if integer_scale else 0,
		"player": [p1_choice["palette"], p1_choice["variant"], p1_choice["paddle"]],
		"court": court.duplicate()}, true)


## Applies the window options (a no-op headless, where there's no window).
static func apply_window(win: Window) -> void:
	if win == null or DisplayServer.get_name() == "headless":
		return
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scale \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func _ready() -> void:
	_load_settings()
	apply_window(get_window())
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
	logo.position = Vector2(480, 70)
	logo.scale = Vector2(2, 2)
	logo.position.x = 480
	_ui.add_child(logo)
	var sub := BitmapText.new()
	sub.font = "small"
	sub.text = "ARCADE PICKLEBALL"
	sub.align = 0.5
	sub.position = Vector2(480, 136)
	_ui.add_child(sub)
	var keys := BitmapText.new()
	keys.font = "small"
	keys.text = "MOVE: ARROWS  B: SPACE  A: K  Y: L  START: ENTER"
	keys.align = 0.5
	keys.position = Vector2(480, 512)
	keys.tint = Color(0.75, 0.8, 0.9)
	_ui.add_child(keys)
	_record = BitmapText.new()
	_record.font = "small"
	_record.align = 0.5
	_record.position = Vector2(480, 156)
	_record.tint = Color(0.8, 0.85, 0.95)
	_ui.add_child(_record)
	_header = [logo, sub, _record, keys]
	_build_pages()
	_build_page()
	select_screen = SelectScreen.new().setup(select)
	select_screen.visible = false
	_ui.add_child(select_screen)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	pages["main"].cursor = clampi(main_cursor, 0, pages["main"].rows.size() - 1)
	_show("main")


func _add_page(id: String, title: String, rows: Array, help: String,
		at := Rect2(300, 172, 360, 0)) -> void:
	if id != "main":
		rows.append({"id": "back", "label": "BACK", "press": back})
	var h := 46 + rows.size() * MenuPage.ROW_H + (46 if title != "" else 0)
	at.size.y = maxi(h, 300)
	var p := MenuPage.new().setup(id, title, rows, at, help)
	p.visible = false
	_ui.add_child(p)
	pages[id] = p


func _build_pages() -> void:
	var help := "B: SELECT   Y: BACK"
	_add_page("main", "", [
		{"id": "singles", "label": "SINGLES", "press": func(): open_select(false)},
		{"id": "doubles", "label": "DOUBLES", "press": func(): open_select(true)},
		{"id": "play", "label": "MATCH SETUP", "value": _play_summary,
			"press": func(): open_page("play")},
		{"id": "practice", "label": "PRACTICE", "press": _open_practice},
		{"id": "court", "label": "COURT", "value": func(): return VENUE_NAMES[venue_i],
			"press": func(): open_page("court")},
		{"id": "modifiers", "label": "MODIFIERS", "value": _mods_label,
			"press": func(): open_page("modifiers")},
		{"id": "options", "label": "OPTIONS", "press": func(): open_page("options")},
		{"id": "records", "label": "RECORDS", "press": func(): open_page("records")},
	], "D-PAD CHOOSE   B START")
	_add_page("play", "MATCH SETUP", [
		{"id": "vs", "label": "VS", "value": _opponent_label, "change": _change_opponent},
		{"id": "difficulty", "label": "DIFFICULTY", "value": func(): return DIFFICULTIES[difficulty_i],
			"change": func(d): difficulty_i = clampi(difficulty_i + d, 0, DIFFICULTIES.size() - 1)},
		{"id": "points", "label": "POINTS", "value": func(): return str(POINTS[points_i]),
			"change": func(d): points_i = clampi(points_i + d, 0, POINTS.size() - 1)},
		{"id": "players", "label": "PLAYERS", "value": func(): return "2P VS" if two_players else "1P",
			"change": func(_d): two_players = not two_players},
	], help)
	var court_rows := [{"id": "venue", "label": "VENUE", "value": func(): return VENUE_NAMES[venue_i],
		"change": func(d): venue_i = (venue_i + d + VENUES.size()) % VENUES.size(); _start_demo()}]
	for i in CourtStyle.PARTS.size():
		var part: String = CourtStyle.PARTS[i]
		court_rows.append({"id": part, "label": CourtStyle.PART_NAMES[i],
			"value": func(): return CourtStyle.names(part)[court[i]],
			"change": func(d):
				court[i] = (court[i] + d + CourtStyle.count(part)) % CourtStyle.count(part)
				_demo.set_court(court)})
	_add_page("court", "COURT", court_rows, help, Rect2(590, 150, 350, 0))
	var mod_rows := []
	for m in MOD_ROWS:
		var bit: int = m[2]
		mod_rows.append({"id": m[0], "label": m[1],
			"value": func(): return "ON" if mod_bits & bit else "OFF",
			"change": func(_d): mod_bits ^= bit})
	_add_page("modifiers", "MODIFIERS", mod_rows, help)
	_add_page("options", "OPTIONS", [
		{"id": "camera", "label": "CAMERA",
			"value": func(): return "OFF" if camera_i == 0 else "%d%%" % CAMERAS[camera_i],
			"change": func(d): camera_i = clampi(camera_i + d, 0, CAMERAS.size() - 1)},
		{"id": "sound", "label": "SOUND", "value": func(): return AudioMap.SOUND_NAMES[Sfx.setting],
			"change": func(d): Sfx.setting = (Sfx.setting + d + 3) % 3},
		{"id": "fullscreen", "label": "FULLSCREEN", "value": func(): return "ON" if fullscreen else "OFF",
			"change": func(_d): fullscreen = not fullscreen; apply_window(get_window())},
		{"id": "scale", "label": "SCALE", "value": func(): return "PIXEL" if integer_scale else "FILL",
			"change": func(_d): integer_scale = not integer_scale; apply_window(get_window())},
	], help)
	_add_page("records", "RECORDS", [
		{"id": "singles", "label": "SINGLES", "value": func(): return _wl("singles")},
		{"id": "doubles", "label": "DOUBLES", "value": func(): return _wl("doubles")},
		{"id": "ladder", "label": "LADDER", "value": func(): return "%d OF %d" % [_rung() + 1, Opponents.count()]},
		{"id": "clears", "label": "CLEARS", "value": func(): return str(_rec("ladder_clears"))},
		{"id": "rally", "label": "LONGEST RALLY", "value": func(): return str(_rec("longest_rally"))},
		{"id": "streak", "label": "PRACTICE BEST", "value": func(): return str(_rec("practice_best"))},
	], "Y: BACK")


func _rec(key: String) -> int:
	return int(save.data["records"][key]) if save else 0


func _wl(mode: String) -> String:
	return "%d-%d" % [_rec(mode + "_wins"), _rec(mode + "_losses")]


func _play_summary() -> String:
	return "%s  %d" % [DIFFICULTIES[difficulty_i], POINTS[points_i]]


func _mods_label() -> String:
	var on := MOD_ROWS.filter(func(m): return mod_bits & m[2])
	if on.is_empty():
		return "NONE"
	return on[0][1] if on.size() == 1 else "%d ON" % on.size()


func _change_opponent(dir: int) -> void:
	opponent_i += dir
	if opponent_i < -2:
		opponent_i = Opponents.count() - 1
	elif opponent_i >= Opponents.count():
		opponent_i = -2
	if opponent_i != -1:
		venue_i = VENUES.find(home_venue(_rung() if opponent_i == -2 else opponent_i))
		_start_demo()


## Shows one page (or "practice", the drill editor) and hides the rest.
func _show(id: String) -> void:
	page = id
	for k in pages:
		pages[k].visible = k == id
	if _page:
		_page.visible = id == "practice"
	if select_screen:
		select_screen.visible = id == "select"
	for n in _header:
		n.visible = id != "select"
	if pages.has(id):
		pages[id].refresh()
	_refresh()


## Opens a page by id; the press that opened it is swallowed (rule 9).
func open_page(id: String) -> void:
	if not pages.has(id):
		return
	_show(id)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## Y or BACK: a sub-page returns to MAIN, its cursor on the page's row.
func back() -> void:
	if page == "main":
		return
	var from := page
	_show("main")
	pages["main"].select(from)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	if _sfx:
		_sfx.play("back")


func page_open() -> bool:
	return page == "practice"


## SINGLES / DOUBLES: Player Select for 1P (on their last choice), then 2P.
func open_select(doubles: bool) -> void:
	_select_doubles = doubles
	select.begin(K.MODE_DOUBLES if doubles else K.MODE_SINGLES, 2 if two_players else 1, p1_choice)
	select.choice[1] = p2_choice.duplicate()
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
		p1_choice = select.choice[0].duplicate()
		if select.humans == 2:
			p2_choice = select.choice[1].duplicate()
		_start(_select_doubles)
	else:
		_sfx.play("confirm" if select.current != was[1] else "blip")
		select_screen.refresh()


## 2P's newly pressed buttons on pad 1 (the input map is P1's).
func _pad2_pressed() -> int:
	var held := 0
	var dev := 1
	if dev in Input.get_connected_joypads():
		for pair in [[JOY_BUTTON_DPAD_UP, Practice.PAD_UP], [JOY_BUTTON_DPAD_DOWN, Practice.PAD_DOWN],
				[JOY_BUTTON_DPAD_LEFT, Practice.PAD_LEFT], [JOY_BUTTON_DPAD_RIGHT, Practice.PAD_RIGHT],
				[JOY_BUTTON_A, Practice.PAD_B], [JOY_BUTTON_X, Practice.PAD_Y],
				[JOY_BUTTON_START, Practice.PAD_START]]:
			if Input.is_joy_button_pressed(dev, pair[0]):
				held |= pair[1]
	var pressed := held & ~_pad2_prev
	_pad2_prev = held
	return pressed


func _start(doubles: bool) -> void:
	if _sfx:
		_sfx.play("confirm")
	_store_settings()
	main_cursor = pages["main"].cursor
	start_match.emit(config(doubles), VENUES[venue_i], opponent_i == -2 and not two_players)


func _build_page() -> void:
	_page = Control.new()
	_page.visible = false
	_ui.add_child(_page)
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 12)
	panel.position = Vector2(300, 172)
	panel.size = Vector2(360, 300)
	_page.add_child(panel)
	var title := BitmapText.new()
	title.font = "big_gold"
	title.text = "PRACTICE"
	title.align = 0.5
	title.position = Vector2(480, 190)
	_page.add_child(title)
	for i in PAGE_ROWS.size():
		var label := BitmapText.new()
		label.font = "small"
		label.text = PAGE_ROWS[i]
		label.position = Vector2(340, 250 + i * 36)
		_page.add_child(label)
		_page_rows.append(label)
		var value := BitmapText.new()
		value.font = "small"
		value.align = 1.0
		value.position = Vector2(624, 250 + i * 36)
		value.tint = Color("fbe46a")
		_page.add_child(value)
		_page_values.append(value)
	_page_best = BitmapText.new()
	_page_best.font = "small"
	_page_best.align = 0.5
	_page_best.position = Vector2(480, 404)
	_page.add_child(_page_best)
	var help := BitmapText.new()
	help.font = "small"
	help.text = "B: PLAY   Y: BACK"
	help.align = 0.5
	help.position = Vector2(480, 438)
	help.tint = Color(0.75, 0.8, 0.9)
	_page.add_child(help)
	_page_arrow = Sprite2D.new()
	_page_arrow.texture = load("res://assets/levels/ui/icon_ball.png")
	_page_arrow.centered = false
	_page.add_child(_page_arrow)


func _open_practice() -> void:
	_drill = save.practice_settings() if save else Practice.DEFAULTS.duplicate()
	_edit.begin(_drill)
	_show("practice")
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	_refresh_page()


func _refresh_page() -> void:
	_page_values[0].text = Practice.shot_name(_drill[0])
	_page_values[1].text = Practice.target_name(_drill[1])
	_page_values[2].text = Practice.rate_name(_drill[2])
	_page_values[3].text = Practice.zone_name(_drill[3])
	for i in _page_rows.size():
		_page_rows[i].tint = Color.WHITE if i == _edit.row else Color(0.7, 0.74, 0.85)
	_page_arrow.position = Vector2(318, 250 + _edit.row * 36)
	var best := save.practice_saved_best(_drill[3]) if save else 0
	_page_best.text = "BEST STREAK %d" % best


## The page's presses as SNES pad bits (practice_edit_input).
static func _pad_pressed() -> int:
	var bits := 0
	for pair in [["move_up", Practice.PAD_UP], ["move_down", Practice.PAD_DOWN],
			["move_left", Practice.PAD_LEFT], ["move_right", Practice.PAD_RIGHT],
			["hit", Practice.PAD_B], ["start", Practice.PAD_START], ["soft", Practice.PAD_Y]]:
		if Input.is_action_just_pressed(pair[0]):
			bits |= pair[1]
	return bits


## One frame of the page: B or Start saves any change and plays; Y goes
## back with the old drill.
func _update_page(pressed: int) -> void:
	if pressed == 0:
		return
	var result := _edit.input(_drill, pressed)
	if result == Practice.EDIT_CANCEL:
		_show("main")
		_lock = SWITCH_LOCK         # the closing press isn't a menu press
		_sfx.play("back")
		return
	if result == Practice.EDIT_DONE:
		_sfx.play("confirm")
		_store_settings()
		if save:
			save.data["settings"]["practice"] = _drill.duplicate()
		main_cursor = pages["main"].cursor
		start_match.emit(practice_config(), VENUES[venue_i], false)
		return
	_sfx.play("blip")
	_refresh_page()


## A practice session on the saved drill at the chosen difficulty.
## P1 in their last Player Select choice.
func practice_config() -> SimTypes.MatchConfig:
	var cfg: SimTypes.MatchConfig
	if save:
		cfg = save.practice_config(difficulty_i)
	else:
		cfg = SimTypes.MatchConfig.practice_session(_drill if _drill.size() == Practice.ROWS
			else Practice.DEFAULTS, 0)
		cfg.difficulty = difficulty_i
	cfg.palette[0] = p1_choice["palette"]
	cfg.variant[0] = p1_choice["variant"]
	cfg.paddle[0] = p1_choice["paddle"]
	return cfg


func _start_demo() -> void:
	if _demo:
		_demo.queue_free()
	_demo = MatchView.new()
	add_child(_demo)
	move_child(_demo, 0)
	var cfg := SimTypes.MatchConfig.doubles() if _demo_doubles else SimTypes.MatchConfig.singles()
	_demo.court = court.duplicate()
	_demo.setup(cfg, VENUES[venue_i], true)
	_demo._hud.visible = false


func _refresh() -> void:
	if save:
		var r: Dictionary = save.data["records"]
		_record.text = "RECORD %d-%d   LADDER %d OF %d   CLEARS %d" % [
			int(r["singles_wins"]) + int(r["doubles_wins"]),
			int(r["singles_losses"]) + int(r["doubles_losses"]),
			int(r["ladder_rung"]) + 1, Opponents.count(), int(r["ladder_clears"])]


func _rung() -> int:
	return int(save.data["records"]["ladder_rung"]) if save else 0


func _opponent_label() -> String:
	if opponent_i == -2:
		return "LADDER: " + String(Opponents.team(_rung())["team"])
	if opponent_i == -1:
		return "CPU"
	return String(Opponents.team(opponent_i)["team"])


static func home_venue(team: int) -> String:
	var home: String = String(Opponents.team(team).get("venue", "PARK")).to_lower()
	return home if home in VENUES else VENUES[0]


func config(doubles: bool) -> SimTypes.MatchConfig:
	var opp := -1 if two_players else (_rung() if opponent_i == -2 else opponent_i)
	var cfg := config_for(doubles, opp, difficulty_i, POINTS[points_i], p1_choice,
		p2_choice if two_players else {})
	cfg.modifiers = mod_bits
	return cfg


## A match from Player Select's choices (match_config_select: 1P, and 2P
## on slot 2 if given) against a ladder team or the default CPU (-1):
## their look's body variant and paddle on slots 2-3 (match_config_opponent).
static func config_for(doubles: bool, opponent: int, difficulty: int, points: int,
		p1: Dictionary = {}, p2: Dictionary = {}) -> SimTypes.MatchConfig:
	var cfg := PlayerSelect.config_select(K.MODE_DOUBLES if doubles else K.MODE_SINGLES,
		p1 if not p1.is_empty() else PlayerSelect.new_choice(PlayerSelect.PAL_BLUE,
			K.VARIANT_MALE, Paddles.STANDARD), p2)
	cfg.difficulty = difficulty
	cfg.points_to_win = points
	if not p2.is_empty():
		return cfg
	cfg.opponent = opponent
	if opponent >= 0:
		var members: Array = Opponents.team(opponent)["players"]
		for slot in [2, 3]:
			var m: Dictionary = members[mini(slot - 2, members.size() - 1)]
			cfg.variant[slot] = K.VARIANT_FEMALE if m.get("variant", "male") == "female" else K.VARIANT_MALE
			cfg.paddle[slot] = maxi(0, Paddles.NAMES.find(m.get("paddle", "blue")))
	return cfg


func _process(_delta: float) -> void:
	if _demo.sim.phase == K.PHASE_MATCH_RESULT and _demo.sim.phase_timer >= K.ATTRACT_RESULT_FRAMES - 1:
		_demo_doubles = not _demo_doubles
		_start_demo()
	if _lock > 0:
		_lock -= 1
		return
	if page == "practice":
		_update_page(_pad_pressed())
		return
	if page == "select":
		var pressed := _pad_pressed()
		var p2 := _pad2_pressed()
		select_input(pressed | (p2 if select.current == 1 else 0))
		return
	var p: MenuPage = pages[page]
	if Input.is_action_just_pressed("move_up"):
		p.move(-1)
		_sfx.play("blip")
	elif Input.is_action_just_pressed("move_down"):
		p.move(1)
		_sfx.play("blip")
	var dir := 0
	if Input.is_action_just_pressed("move_left"):
		dir = -1
	elif Input.is_action_just_pressed("move_right"):
		dir = 1
	if dir != 0 and p.change(dir):
		_sfx.play("blip")
		_refresh()
	if Input.is_action_just_pressed("soft") and page != "main":
		back()
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		var id := p.current_id()
		if p.press():
			if id not in ["singles", "doubles", "back"]:
				_sfx.play("confirm")
			_refresh()
