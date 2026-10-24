## Title: the logo and the menu over a live CPU demo at the chosen venue.
## The menu is a tree of MenuPages (ADR-025/030, regrouped by ADR-079):
## MAIN has STORY, PLAY, PRACTICE, PLAYER and OPTIONS. PLAY has QUICK
## MATCH (MATCH SETUP: the mode, VS, COURT, MODIFIERS..., then START to
## Player Select, ADR-020), TOURNAMENT, OPEN PLAY (the park, ADR-034) and
## MULTIPLAYER; PLAYER has CAREER's players (ADR-047), the records, the
## achievements and the HAT MUSEUM; PRACTICE the lessons and the drill
## editor (PracticePage, ADR-028).
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
signal open_story               ## ADR-069: STORY, the chapter you're on
signal open_trip                ## port ADR-087: ROAD TRIP's home
signal open_course              ## ADR-070: PICKLEBALL 101, the real game's rules

const SWITCH_LOCK := MenuPage.TRANSITION   ## no menu input while a page slides in

## The main page's cursor, kept across matches.
static var main_cursor := 1             ## PLAY (STORY is above it)
## The page to come back to after a match ("" MAIN): MATCH SETUP after a
## quick match, PLAY after the other modes there.
static var return_to := ""
## Where each page sits in the menu: BACK goes to the page it was opened
## from (and its row), else to its place here.
const TREE := {"play": "main", "setup": "play", "multi": "play", "court": "setup",
	"modifiers": "setup", "rules": "modifiers", "learn": "main", "options": "main",
	"controls": "options", "access": "options", "player": "main", "records": "player",
	"achievements": "player", "replays": "player", "pad": "controls", "notice": "main"}

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
var _parents := {}               ## page -> [the page it was opened from, its row]
var _museum_from := "career_card"   ## where the HAT MUSEUM goes back to


func _load_settings() -> void:
	Settings.load_from(save)
	if Settings.opponent_i == Opponents.DAWSON and not dawson_unlocked():
		Settings.opponent_i = -2          # records erased: Dale is locked again


func _store_settings() -> void:
	Settings.store_to(save)


## The settings, and the save written now (a choice that must outlast a
## quit from the title: DON'T SHOW AGAIN, a pad's map).
func _save_settings() -> void:
	Settings.store_to(save)
	if save:
		save.save_game()


## The title's music (PORT-22), on every page.
func music_track() -> String:
	return "title"


var achieve_how: BitmapText          ## under ACHIEVEMENTS (ADR-077)
static var _greeted := false       ## the announcer has said the name this session
## The "a controller is recommended" card has had its chance this session
## (port ADR-082; the tests' runner sets it, so the title opens on MAIN).
static var notice_done := false

func _ready() -> void:
	_load_settings()
	if not _greeted:
		_greeted = true                  # ADR-076: once a session, as the logo comes up
		Announcer.speak("title_logo", Announcer.TOP)
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
	pad_map_screen = PadMapScreen.new().setup(pad_mapper)
	pad_map_screen.visible = false
	_ui.add_child(pad_map_screen)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	pages["main"].cursor = clampi(main_cursor, 0, pages["main"].rows.size() - 1)
	_show("main")
	if return_to != "" and pages.has(return_to):
		reveal_page(return_to)
	return_to = ""
	if not notice_done:
		notice_done = true               # port ADR-082: once a session, at startup
		# not on a touch screen's pad (PORT-81): that's the controller
		if Settings.pad_notice and GameControls.connected_pads().is_empty() and not TouchPad.wanted():
			open_page("notice")
			_lock = 10                   # the title's own opening wait, as without it
	Settings.apply_window(get_window())    # last: a mode change can run a frame


func _add_page(id: String, title: String, rows: Array, help: Array,
		at := Rect2(300, 172, 360, 0)) -> void:
	if not id in ["main", "notice"]:          # the notice's OK is its way back
		rows.append({"id": "back", "label": "BACK", "press": back})
	# top pad, the rows, then a footer that keeps the prompt bar clear of them
	# (MAIN has none: the key legend under it says HIT, and its rows need the room)
	var h := 18 + rows.size() * MenuPage.ROW_H + (52 if not help.is_empty() else 12) \
		+ (46 if title != "" else 0)
	at.size.y = h if id in ["main", "play", "player", "pad", "notice"] else maxi(h, 300)     # the short ones fit their rows
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
	TitlePages.build(self)


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


func _after_press(id: String) -> void:
	if id not in ["start", "back"]:
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


## How many toggles are on (one: its name), on a page or all of them.
func _mods_label(on_page := "") -> String:
	var on := Settings.MOD_ROWS.filter(func(m): return Settings.mod_bits & m[2] \
		and (on_page == "" or m[3] == on_page))
	if on_page == "" and Settings.ball_speed != Settings.BALL_SPEED_DEFAULT:
		on.append([0, "BALL %d%%" % Settings.ball_speed])     # ADR-071
	if on.is_empty():
		return "NONE"
	return on[0][1] if on.size() == 1 else "%d ON" % on.size()


## Dale Dawson (port ADR-066) joins VS once a ladder has been cleared.
func dawson_unlocked() -> bool:
	return _rec("ladder_clears") > 0 or StoryMode.cleared(save) > 0   # ADR-069: or the park saved


func _change_opponent(dir: int) -> void:
	var last := Opponents.DAWSON if dawson_unlocked() else Opponents.count() - 1
	Settings.opponent_i += dir
	if Settings.opponent_i < -2:
		Settings.opponent_i = last
	elif Settings.opponent_i > last:
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
	if pad_map_screen:
		pad_map_screen.visible = id == "padmap"
	for n in _header:
		n.visible = not id in ["select", "setup", "records", "achievements", "replays", "controls", "options", "modifiers", "rules", "lobby", "museum", "career_card", "career_edit",
			"career_name", "pad", "padmap"]
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
	if pages.has(page) and page != id:
		_parents[id] = [page, pages[page].current_id()]
	_show(id)
	pages[id].appear(1)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## Y or BACK: a page returns to the one it was opened from, the cursor on
## the row that opened it.
func back() -> void:
	if page == "main":
		return
	# CAREER's pages and its records go back through the page's logic (Y)
	if page.begins_with("career") or (page == "records" and career_page.view == CareerPage.VIEW_RECORDS):
		_career_input(CareerPage.PAD_Y)
		if _sfx:
			_sfx.play("back")
		return
	var from := page
	var to: Array = _parents.get(from, [TREE.get(from, "main"), from])
	back_to(to[0], to[1], true)


## Back on `to` (its `row` selected, if given), sliding in from the left,
## with the closing press swallowed (rule 9) and the back sound if `sound`.
func back_to(to: String, row := "", sound := false) -> void:
	_show(to)
	if row != "":
		pages[to].select(row)
	pages[to].appear(-1)
	_lock = SWITCH_LOCK
	GameControls.clear_latch()
	if sound and _sfx:
		_sfx.play("back")


func page_open() -> bool:
	return page == "practice"


## Opens a page where it sits in the menu (its parents first, each with the
## cursor on the row that leads on), as if the rows had been pressed.
func reveal_page(id: String) -> MenuPage:
	var chain := [id]
	while TREE.has(chain[0]):
		chain.push_front(TREE[chain[0]])
	_show("main")
	for i in range(1, chain.size()):
		var from: String = chain[i - 1]
		var row := _row_to(from, chain[i])
		pages[from].select(row)
		_parents[chain[i]] = [from, row]
	_show(id)
	return pages[id]


## The row on `from` that opens `to` (its id, for the pages whose row is
## named otherwise).
func _row_to(from: String, to: String) -> String:
	var named := {"learn": "practice", "setup": "quick", "multi": "multiplayer"}
	return named.get(to, to) if pages[from].index_of(named.get(to, to)) >= 0 else to


## A row anywhere in the menu: its page opened (reveal_page) with the
## cursor on it. Tests use this to reach a row by id.
func reveal(row: String) -> MenuPage:
	for id in ["main", "play", "setup", "player", "learn", "options", "multi", "modifiers", "rules", "court",
			"controls", "pad", "access", "records"]:
		if pages.has(id) and pages[id].index_of(row) >= 0:
			var p := reveal_page(id)
			p.select(row)
			return p
	return null


## PLAYER's HAT MUSEUM: the active player's (nobody: nothing).
func open_player_museum() -> void:
	var me := _career().active_player()
	if me == null:
		return
	career_page.slot = _career().players.find(me)
	_museum_from = "player"
	open_museum()


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
		back_to(_museum_from, "hats", true)
		if _museum_from == "career_card":
			career.sync(false)
		_museum_from = "career_card"
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
		back_to("setup", "", true)
	elif result == PlayerSelect.DONE:
		if _career().active_player() == null:
			Settings.p1_choice = select.choice[0].duplicate()
		if select.humans == 2:
			Settings.p2_choice = select.choice[1].duplicate()
		_start(_select_doubles)
	else:
		_sfx.play("confirm" if select.current != was[1] else "blip")
		select_screen.refresh()


## 2P's newly pressed buttons on their pad (the input map is P1's): the
## menus' reading of a pad (D-pad or stick, A, B or X back, Start).
func _pad2_pressed() -> int:
	var dev := GameControls.p2_pad
	if dev < 0:
		return 0
	return int(GameControls.pad_menu_bits(dev)[0])


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
	back_to("multi", "local", true)


## Everyone's ready: the lobby's match at the chosen court, with the match
## settings (difficulty for the CPUs, points, modifiers).
func start_lobby_match() -> void:
	_sfx.play("confirm")
	_store_settings()
	return_to = "multi"
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
	return_to = "setup"
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
	return_to = "play"
	open_tournament.emit()


func _open_park() -> void:
	_store_settings()
	main_cursor = pages["main"].cursor
	return_to = "play"
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


## The title's demo: a live CPU match, or (every other one, from the
## cycle, with IN THE DEMO on) a saved replay, quietly (PORT-69).
func _start_demo(cycle := false) -> void:
	if cycle:
		_demo_count += 1
	var list := SavedReplays.list().filter(func(r): return r["playable"])
	if cycle and Settings.replays_in_demo and _demo_count % 2 == 0 and not list.is_empty():
		var data := SavedReplays.load_replay(list[(_demo_count / 2) % list.size()]["name"])
		if not data.is_empty() and _start_replay(data, true):
			return
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


# --- REPLAYS (PORT-69, ADR-081) ---------------------------------------------------------

var replay_delete := false       ## ON PRESS: DELETE
var watching := false            ## a replay from REPLAYS fills the screen
var _demo_count := 0


func replay_label(i: int) -> String:
	var list := SavedReplays.list()
	return SavedReplays.row_label(list[i]) if i < list.size() else "EMPTY"


func replay_value(i: int) -> String:
	var list := SavedReplays.list()
	return SavedReplays.row_value(list[i]) if i < list.size() else ""


func replay_press(i: int) -> void:
	var list := SavedReplays.list()
	if i >= list.size():
		_sfx.play("blip")
		return
	if replay_delete:
		SavedReplays.remove(list[i]["name"])
		_sfx.play("back")
		pages["replays"].refresh()
		return
	var data := SavedReplays.load_replay(list[i]["name"]) if list[i]["playable"] else {}
	if data.is_empty() or not _start_replay(data, false):
		_sfx.play("blip")
		return
	_sfx.play("confirm")
	watching = true
	_ui.visible = false


## A saved replay in the demo's place: on its own court, with the card and
## the score (from REPLAYS), or with neither (quiet, behind the menu).
func _start_replay(data: Dictionary, quiet: bool) -> bool:
	if _demo:
		_demo.queue_free()
	_demo = MatchView.new()
	add_child(_demo)
	move_child(_demo, 0)
	var cfg := OnlineSession.config_from_dict(data["cfg"])
	_demo.court = Array(data.get("court", Settings.court)).duplicate()
	_demo.time = int(data.get("time", Settings.time_i))
	_demo.setup(cfg, str(data.get("venue", Settings.venue())), true)
	_demo._hud.visible = false
	var h := Highlight.from_saved(_demo, data)
	h.quiet = quiet
	_demo.highlight = h
	return h.start(_replay_done.bind(quiet))


func _replay_done(quiet: bool) -> void:
	if not quiet:
		watching = false
		_ui.visible = true
		_lock = SWITCH_LOCK              # the skip's press isn't a menu press
		pages[page].refresh()
	_start_demo()


func _refresh() -> void:
	if save:
		var r: Dictionary = save.data["records"]
		# just the record: the ladder's place resets when a ladder match is
		# quit, so it isn't progress to show here (RECORDS has it, and the
		# clears)
		_record_text = "RECORD %d-%d" % [int(r["singles_wins"]) + int(r["doubles_wins"]),
			int(r["singles_losses"]) + int(r["doubles_losses"])]
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
## MAP BUTTONS (port ADR-082): the steps being asked of a generic pad.
var pad_mapper := PadMapper.new()
var pad_map_screen: PadMapScreen


## MAP BUTTONS: asks the pad in hand for its buttons, if it's one SDL
## doesn't know (or one mapped before); a standard pad needs none.
func open_pad_map() -> void:
	var dev := PadMaps.target_pad()
	if not PadMaps.status(dev) in [PadMaps.UNKNOWN, PadMaps.MAPPED]:
		if _sfx:
			_sfx.play("back")
		return
	pad_mapper.begin(dev)
	_show("padmap")
	pad_map_screen.refresh()
	_lock = SWITCH_LOCK
	GameControls.clear_latch()


## Leaves MAP BUTTONS for CONTROLLER (its row), the closing press swallowed.
func _close_pad_map() -> void:
	back_to("pad", "map")


## One input event while MAP BUTTONS is open: the pad's answers; Esc
## cancels and Backspace steps back. All of it is swallowed (rule 9).
func pad_map_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventKey and event.is_pressed():
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code == KEY_ESCAPE:
			pad_mapper.cancel()
			_close_pad_map()
			if _sfx:
				_sfx.play("back")
		elif code == KEY_BACKSPACE:
			pad_mapper.undo()
			pad_map_screen.refresh()
			if _sfx:
				_sfx.play("blip")
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var r := pad_mapper.feed(event)
		if r == PadMapper.DONE:
			_save_settings()
			_close_pad_map()
		else:
			pad_map_screen.refresh()
		if r != PadMapper.IGNORED and _sfx:
			_sfx.play("confirm" if r == PadMapper.DONE else "blip")


func listen(action: String) -> void:
	listening = action
	pages["controls"].refresh()


## While listening, the next key or pad button press rebinds the action
## (Esc cancels) and is swallowed (rule 9).
func _input(event: InputEvent) -> void:
	if page == "padmap":
		pad_map_input(event)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
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


## ADR-077: under ACHIEVEMENTS, how to earn the one selected (and the day
## it was, once it's done).
func _refresh_achievement() -> void:
	if achieve_how == null:
		return
	achieve_how.visible = page == "achievements"
	if not achieve_how.visible:
		return
	var p: MenuPage = pages["achievements"]
	var id := p.current_id()
	var a := Achievements.entry(id)
	if a.is_empty():
		achieve_how.text = Achievements.label(save) + " DONE"
		return
	var day := Achievements.day(save, id)
	achieve_how.text = String(a[2]) + ("" if day == "" else "  " + day)


func _process(_delta: float) -> void:
	# a window-mode change in _ready can run a frame before the demo exists
	if _demo == null or _demo.sim == null:
		return
	_refresh_record()
	_refresh_achievement()
	if page == "options" and Updater.instance and Updater.instance.label() != _updates_label:
		_updates_label = Updater.instance.label()
		pages["options"].refresh()       # the download's percentage, and when it's done
	if _demo.sim.phase == K.PHASE_MATCH_RESULT and _demo.sim.phase_timer >= K.ATTRACT_RESULT_FRAMES - 1:
		_demo_doubles = not _demo_doubles
		_start_demo(true)
	if watching:
		return                           # REPLAYS' replay has the screen
	if _lock > 0:
		_lock -= 1
		return
	if listening != "" or page == "padmap":
		return
	if page == "notice" and not GameControls.connected_pads().is_empty():
		back()                           # a pad came: the card has made its point
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
	var on_edit_start := page == "career_edit" and Input.is_action_just_pressed("start")
	var nav := p.drive(true, page != "main", not on_edit_start)
	if nav & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
		_sfx.play("blip")
	if nav & MenuPage.NAV_CHANGED:
		_refresh()
	if nav & MenuPage.NAV_BACK:
		back()
	elif on_edit_start:
		_career_input(CareerPage.PAD_START)       # Start keeps, on any row
		_sfx.play("confirm")
	elif nav & MenuPage.NAV_PRESSED:
		_after_press(p.pressed_id)
