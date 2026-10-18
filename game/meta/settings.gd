## The player's settings (match setup, court, options, Player Select's
## last choice), shared by every screen and kept in the save's
## "settings". The title edits them; matches read them. SOUND lives on
## Sfx.setting and MUSIC on Music.volume (the audio reads them there).
class_name Settings
extends RefCounted

## data/venues.json's six, in its order (ADR-024, the fun three ADR-046).
const VENUES := ["park", "lakeside", "sunset", "dinosaur", "space", "undersea"]
const VENUE_NAMES := ["PARK", "LAKESIDE", "SUNSET", "DINOSAUR", "SPACE", "UNDERSEA"]
const DIFFICULTIES := ["KID", "EASY", "MEDIUM", "HARD"]
const POINTS := [3, 5, 7, 9, 11, 15, 21]
const CAMERAS := [0, 50, 75, 100]
## The modifier toggles: [id, label, MOD_* bit].
const MOD_ROWS := [["big_ball", "BIG BALL", K.MOD_BIG_BALL], ["fast_ball", "FAST BALL", K.MOD_FAST_BALL],
	["win_by_2", "WIN BY 2", K.MOD_WIN_BY_2], ["lava", "LAVA", K.MOD_LAVA]]
## Saves before the MODIFIERS page kept one preset index ("mods"); these
## are its bits, read only when loading such a save.
const OLD_MOD_PRESETS := [0, K.MOD_BIG_BALL, K.MOD_FAST_BALL, K.MOD_WIN_BY_2, K.MOD_LAVA, 15]

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
## Court colours: [surface, kitchen, surround, lines] presets (CourtStyle).
static var court: Array = CourtStyle.DEFAULTS.duplicate()
static var time_i := CourtStyle.DAY
## The last Player Select choices (PlayerSelect.new_choice; 1P's is saved).
static var p1_choice := PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, Paddles.STANDARD)
static var p2_choice := PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD)
## Accessibility (PORT-12): screen shake, the white hit flashes, a larger
## HUD text, and the serve assist (holding B releases a strong serve).
static var shake := true
static var flashes := true
static var hud_large := false
static var serve_assist := false
## Controller rumble on hits (PORT-15).
static var vibration := true


## Reads the save's settings, each made valid.
static func load_from(save: SaveGame) -> void:
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
	mod_bits = (bits & 15) if bits >= 0 else \
		OLD_MOD_PRESETS[clampi(int(st.get("mods", 0)), 0, OLD_MOD_PRESETS.size() - 1)]
	Sfx.setting = clampi(int(st.get("sound", 0)), 0, AudioMap.SOUND_NAMES.size() - 1)
	Music.volume = clampi(int(st.get("music", Music.DEFAULT_VOLUME)), 0, Music.VOLUMES)
	fullscreen = int(st.get("fullscreen", 0)) != 0
	integer_scale = int(st.get("integer_scale", 1)) != 0
	var ct: Array = st.get("court", CourtStyle.DEFAULTS)
	court = CourtStyle.DEFAULTS.duplicate()
	for i in mini(ct.size(), 4):
		var n := CourtStyle.count(CourtStyle.PARTS[i])
		court[i] = int(ct[i]) if int(ct[i]) >= 0 and int(ct[i]) < n else 0
	time_i = clampi(int(st.get("time", 0)), 0, CourtStyle.time_names().size() - 1)
	shake = int(st.get("shake", 1)) != 0
	flashes = int(st.get("flash", 1)) != 0
	hud_large = int(st.get("hud_large", 0)) != 0
	serve_assist = int(st.get("serve_assist", 0)) != 0
	vibration = int(st.get("vibration", 1)) != 0
	Bindings.from_save(st.get("bindings", {}))
	GameControls.refresh_pads()
	var pl: Array = st.get("player", [0, 0, 1])
	if pl.size() == 3:
		p1_choice = PlayerSelect.new_choice(clampi(int(pl[0]), 0, 3), clampi(int(pl[1]), 0, 1),
			clampi(int(pl[2]), 0, Paddles.NAMES.size() - 1))


static func store_to(save: SaveGame) -> void:
	if save == null:
		return
	save.data["settings"].merge({"venue": venue_i, "difficulty": difficulty_i,
		"points": points_i, "players": 2 if two_players else 1, "opponent": opponent_i,
		"camera": camera_i, "mod_bits": mod_bits, "sound": Sfx.setting,
		"music": Music.volume,
		"fullscreen": 1 if fullscreen else 0, "integer_scale": 1 if integer_scale else 0,
		"player": [p1_choice["palette"], p1_choice["variant"], p1_choice["paddle"]],
		"court": court.duplicate(), "time": time_i,
		"shake": 1 if shake else 0, "flash": 1 if flashes else 0,
		"hud_large": 1 if hud_large else 0, "serve_assist": 1 if serve_assist else 0,
		"vibration": 1 if vibration else 0,
		"bindings": Bindings.to_save()}, true)


## Applies the window options (a no-op headless, where there's no window).
static func apply_window(win: Window) -> void:
	if win == null or DisplayServer.get_name() == "headless":
		return
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scale \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


static func venue() -> String:
	return VENUES[venue_i]


static func home_venue(team: int) -> String:
	var home: String = String(Opponents.team(team).get("venue", "PARK")).to_lower()
	return home if home in VENUES else VENUES[0]


## The match the settings describe; `rung` is the ladder's current team.
static func match_config(doubles: bool, rung: int) -> SimTypes.MatchConfig:
	var opp := -1 if two_players else (rung if opponent_i == -2 else opponent_i)
	var cfg := config_for(doubles, opp, difficulty_i, POINTS[points_i], p1_choice,
		p2_choice if two_players else {})
	cfg.modifiers = mod_bits
	return cfg


## Your game in the park (ADR-034, main.c start_open_play_match): doubles
## against the team drawn with you, with the captain next in line as your
## partner (or 2P, on slot 1), the saved points and modifiers, at the
## court's difficulty (KID keeps its assist). You play in your last Player
## Select choice.
static func open_play_config(op: OpenPlay) -> SimTypes.MatchConfig:
	var cfg := config_for(true, op.opponent if op.opponent < OpenPlay.TEAMS else -1,
		OpenPlay.court_difficulty(op.called, difficulty_i), POINTS[points_i], p1_choice)
	if op.two_players:
		cfg.human[1] = 1
	else:
		cfg.set_partner(op.partner if op.partner < OpenPlay.TEAMS else -1)
	cfg.modifiers = mod_bits
	cfg.open_play = 1
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
