## The player's settings (match setup, court, options, Player Select's
## last choice), shared by every screen and kept in the save's
## "settings". The title edits them; matches read them. SOUND lives on
## Sfx.setting and MUSIC on Music.volume (the audio reads them there).
class_name Settings
extends RefCounted

## data/venues.json's six, in its order (ADR-024, the fun three ADR-046).
const VENUES := ["park", "lakeside", "sunset", "dinosaur", "space", "undersea", "gym"]
const VENUE_NAMES := ["PARK", "LAKESIDE", "SUNSET", "DINOSAUR", "SPACE", "UNDERSEA", "GYM"]
## Indoors (ADR-078): the lights are always on, whatever COURT's TIME says.
const INDOOR := ["gym"]
const DIFFICULTIES := ["KID", "EASY", "MEDIUM", "HARD"]
const POINTS := [3, 5, 7, 9, 11, 15, 21]
const CAMERAS := [0, 50, 75, 100]
## SCREEN SHAKE strength, % of the full shake (KNOWN_ISSUES #58: on/off
## before; the full one was too jarring, so 50 is the default).
const SHAKES := [0, 25, 50, 75, 100]
const SHAKE_DEFAULT := 2
## The modifier toggles: [id, label, MOD_* bit, page]. The MODIFIERS page
## holds the play and look ones and a RULES row; RULES the scoring and
## fault rules (PORT-40: the page outgrew the screen).
const MOD_ROWS := [["big_ball", "BIG BALL", K.MOD_BIG_BALL, "modifiers"],
	["fast_ball", "FAST BALL", K.MOD_FAST_BALL, "modifiers"],
	# SNES ADR-053 (PORT-35), ADR-054 (PORT-39)
	["ghost", "GHOST BALL", K.MOD_GHOST_BALL, "modifiers"], ["popcorn", "POPCORN", K.MOD_POPCORN, "modifiers"],
	["ice", "ICE", K.MOD_ICE, "modifiers"], ["glow", "GLOW", K.MOD_GLOW, "modifiers"],
	["inverse", "INVERSE", K.MOD_INVERSE, "modifiers"],
	# the Pickleball '95 promises (PORT-40, ADR-065)
	["moon", "MOON", K.MOD_MOON, "modifiers"], ["bouncy", "BOUNCY", K.MOD_BOUNCY, "modifiers"],
	["wind", "WIND", K.MOD_WIND, "modifiers"],
	["specials", "SPECIALS", K.MOD_SPECIALS, "rules"],      # port ADR-080
	["win_by_2", "WIN BY 2", K.MOD_WIN_BY_2, "rules"], ["lava", "LAVA", K.MOD_LAVA, "rules"],
	# the Pickleball '95 promises (PORT-40)
	["side_out", "SIDE-OUT", K.MOD_SIDE_OUT, "rules"], ["momentum", "MOMENTUM", K.MOD_MOMENTUM, "rules"],
	["dink_or_die", "DINK OR DIE", K.MOD_DINK_OR_DIE, "rules"],
	["sudden_death", "SUDDEN DEATH", K.MOD_SUDDEN_DEATH, "rules"],
	["multi_ball", "MULTI BALL", K.MOD_MULTI_BALL, "rules"]]
## The bits MODIFIERS saves (an older save's are a subset).
const MOD_SAVED := K.MOD_BIG_BALL | K.MOD_FAST_BALL | K.MOD_WIN_BY_2 | K.MOD_LAVA \
	| K.MOD_GHOST_BALL | K.MOD_POPCORN | K.MOD_ICE | K.MOD_GLOW | K.MOD_INVERSE | K.MOD_SIDE_OUT \
	| K.MOD_MOMENTUM | K.MOD_MOON | K.MOD_BOUNCY | K.MOD_WIND | K.MOD_DINK_OR_DIE | K.MOD_SUDDEN_DEATH \
	| K.MOD_MULTI_BALL | K.MOD_SPECIALS
## Saves before the MODIFIERS page kept one preset index ("mods"); these
## are its bits, read only when loading such a save.
const OLD_MOD_PRESETS := [0, K.MOD_BIG_BALL, K.MOD_FAST_BALL, K.MOD_WIN_BY_2, K.MOD_LAVA, 15]

static var venue_i := 0
static var difficulty_i := K.DIFFICULTY_MEDIUM
static var points_i := 1
## -2 = the ladder's current rung, -1 = the default CPU, else a team.
static var opponent_i := -2
static var two_players := false
static var quick_doubles := false       ## QUICK MATCH's MODE (ADR-079)
static var camera_i := 1                ## CAMERAS: 50% (since 0.9.1; was OFF)
const BALL_SPEED_DEFAULT := 85         ## the user's pick for 0.18 (ADR-072; 78 in 0.17); the ROM's is 100
const BALL_SIZE_DEFAULT := 110         ## the user's pick for 0.18 (105 in 0.17)
const BALL_DEFAULTS_V := 2             ## the settings' "ball_speed_v": which defaults a save last saw
const CPU_ERRORS_MAX := 200
const CPU_ERRORS_DEFAULT := 50        ## half the ROM's late swings: longer rallies (ADR-073)
const BALL_SIZE_MIN := 80
const BALL_SIZE_MAX := 150             ## BIG BALL is 200
static var mod_bits := 0
## OPEN PLAY's locations (ADR-078): [id, name, art folder, its games' venue].
## One plan (the sim's), three looks.
const PARKS := [["park", "THE PARK", "res://assets/park/", "park"],
	["dino", "DINO PARK", "res://assets/park/dino/", "dinosaur"],
	["gym", "THE GYM", "res://assets/park/gym/", "gym"]]
static var park_i := 0                ## OPEN PLAY's location
static var ball_speed := BALL_SPEED_DEFAULT   ## MODIFIERS > BALL SPEED, percent (ADR-071)
static var cpu_errors := CPU_ERRORS_DEFAULT   ## CPU ERRORS, percent of the ROM's (ADR-073)
static var ball_size := BALL_SIZE_DEFAULT     ## MODIFIERS > BALL SIZE, percent, display only (ADR-072)
## Window options: fullscreen, and integer scaling (crisp) or fit (fills).
static var fullscreen := false
static var integer_scale := true
## Court colours: [surface, kitchen, surround, lines] presets (CourtStyle).
static var court: Array = CourtStyle.DEFAULTS.duplicate()
static var time_i := CourtStyle.DAY
## The last Player Select choices (PlayerSelect.new_choice; 1P's is saved).
static var p1_choice := PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, Paddles.STANDARD)
static var p2_choice := PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD)
## The screen shake's strength, 0 (off) to 1.
static func shake_scale() -> float:
	return SHAKES[shake_i] / 100.0


## Accessibility (PORT-12): screen shake, the white hit flashes, a larger
## HUD text, and the serve assist (holding B releases a strong serve).
static var shake_i := SHAKE_DEFAULT   ## SHAKES
static var flashes := true
static var hud_large := false
static var serve_assist := false
## Controller rumble on hits (PORT-15).
static var vibration := true
## BUTTON ICONS (PORT-28): 0 AUTO (from the pad's name), then XBOX,
## PLAYSTATION, NINTENDO (Prompts.FAMILIES).
static var pad_glyphs := 0


## Reads the save's settings, each made valid.
static func load_from(save: SaveGame) -> void:
	if save == null:
		return
	var st: Dictionary = save.data["settings"]
	venue_i = clampi(int(st["venue"]), 0, VENUES.size() - 1)
	difficulty_i = clampi(int(st["difficulty"]), 0, DIFFICULTIES.size() - 1)
	points_i = clampi(int(st["points"]), 0, POINTS.size() - 1)
	two_players = int(st["players"]) == 2
	quick_doubles = int(st.get("quick_doubles", 0)) != 0
	opponent_i = clampi(int(st["opponent"]), -2, Opponents.DAWSON)
	camera_i = clampi(int(st.get("camera", 1)), 0, CAMERAS.size() - 1)
	var bits := int(st.get("mod_bits", -1))
	mod_bits = (bits & MOD_SAVED) if bits >= 0 else \
		OLD_MOD_PRESETS[clampi(int(st.get("mods", 0)), 0, OLD_MOD_PRESETS.size() - 1)]
	# A save keeps the old defaults for everyone who never moved the sliders:
	# 0.16.0's 100%, 0.17.0's 78% and 105%. Those move to today's (ADR-072);
	# any other choice is kept.
	var seen := int(st.get("ball_speed_v", 0))
	var speed := int(st.get("ball_speed", BALL_SPEED_DEFAULT))
	if (seen < 1 and speed == 100) or (seen < 2 and speed == 78):
		speed = BALL_SPEED_DEFAULT
	ball_speed = clampi(speed, K.BALL_SPEED_MIN, K.BALL_SPEED_MAX)
	park_i = clampi(int(st.get("park_location", 0)), 0, PARKS.size() - 1)
	var size := int(st.get("ball_size", BALL_SIZE_DEFAULT))
	if seen < 2 and size == 105:
		size = BALL_SIZE_DEFAULT
	ball_size = clampi(size, BALL_SIZE_MIN, BALL_SIZE_MAX)
	cpu_errors = clampi(int(st.get("cpu_errors", CPU_ERRORS_DEFAULT)), 0, CPU_ERRORS_MAX)
	Sfx.setting = clampi(int(st.get("sound", 0)), 0, AudioMap.SOUND_NAMES.size() - 1)
	Music.volume = clampi(int(st.get("music", Music.DEFAULT_VOLUME)), 0, Music.VOLUMES)
	Announcer.enabled = int(st.get("announcer_on", 1)) != 0
	# 0.19.0's slider went down to OFF: that's the switch now
	var voice := int(st.get("announcer", Announcer.DEFAULT_VOLUME))
	if voice <= 0 and not st.has("announcer_on"):
		Announcer.enabled = false
		voice = Announcer.DEFAULT_VOLUME
	Announcer.volume = clampi(voice, 1, Announcer.VOLUMES)
	Announcer.chatter = clampi(int(st.get("commentary", Announcer.NORMAL)), Announcer.LIGHT, Announcer.LOTS)
	fullscreen = int(st.get("fullscreen", 0)) != 0
	integer_scale = int(st.get("integer_scale", 1)) != 0
	var ct: Array = st.get("court", CourtStyle.DEFAULTS)
	court = CourtStyle.DEFAULTS.duplicate()
	for i in mini(ct.size(), 4):
		var n := CourtStyle.count(CourtStyle.PARTS[i])
		court[i] = int(ct[i]) if int(ct[i]) >= 0 and int(ct[i]) < n else 0
	time_i = clampi(int(st.get("time", 0)), 0, CourtStyle.time_names().size() - 1)
	# a save from before the slider kept on/off: off stays off, on is 50%
	shake_i = clampi(int(st.get("shake_level", SHAKE_DEFAULT if int(st.get("shake", 1)) else 0)),
		0, SHAKES.size() - 1)
	flashes = int(st.get("flash", 1)) != 0
	hud_large = int(st.get("hud_large", 0)) != 0
	serve_assist = int(st.get("serve_assist", 0)) != 0
	vibration = int(st.get("vibration", 1)) != 0
	pad_glyphs = clampi(int(st.get("pad_glyphs", 0)), 0, Prompts.FAMILIES.size() - 1)
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
		"points": points_i, "players": 2 if two_players else 1, "quick_doubles": 1 if quick_doubles else 0, "opponent": opponent_i,
		"camera": camera_i, "mod_bits": mod_bits, "ball_speed": ball_speed, "park_location": park_i, "ball_speed_v": BALL_DEFAULTS_V, "ball_size": ball_size, "cpu_errors": cpu_errors, "sound": Sfx.setting,
		"music": Music.volume, "announcer": Announcer.volume, "announcer_on": 1 if Announcer.enabled else 0, "commentary": Announcer.chatter,
		"fullscreen": 1 if fullscreen else 0, "integer_scale": 1 if integer_scale else 0,
		"player": [p1_choice["palette"], p1_choice["variant"], p1_choice["paddle"]],
		"court": court.duplicate(), "time": time_i,
		"shake": 1 if shake_i else 0, "shake_level": shake_i, "flash": 1 if flashes else 0,
		"hud_large": 1 if hud_large else 0, "serve_assist": 1 if serve_assist else 0,
		"vibration": 1 if vibration else 0, "pad_glyphs": pad_glyphs,
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
## `p1`: 1P's choice when it isn't the saved one (a career player's).
static func match_config(doubles: bool, rung: int, p1: Dictionary = {}) -> SimTypes.MatchConfig:
	var opp := -1 if two_players else (rung if opponent_i == -2 else opponent_i)
	var cfg := config_for(doubles, opp, difficulty_i, POINTS[points_i], p1 if not p1.is_empty() else p1_choice,
		p2_choice if two_players else {})
	cfg.modifiers = mod_bits
	return cfg


## Your game in the park (ADR-034, main.c start_open_play_match): doubles
## against the team drawn with you, with the captain next in line as your
## partner (or 2P, on slot 1), the saved points and modifiers, at the
## court's difficulty (KID keeps its assist). You play in your last Player
## Select choice, or as the active career player in their saved look
## (ADR-047, match_config_career_p1).
static func open_play_config(op: OpenPlay, career: Career.Player = null) -> SimTypes.MatchConfig:
	var cfg := config_for(true, op.opponent if op.opponent < OpenPlay.TEAMS else -1,
		OpenPlay.court_difficulty(op.called, difficulty_i), POINTS[points_i], p1_choice)
	if op.two_players:
		cfg.human[1] = 1
	else:
		cfg.set_partner(op.partner if op.partner < OpenPlay.TEAMS else -1)
	cfg.modifiers = mod_bits
	cfg.open_play = op.called + 1      # the court + 1: the career rates it (SNES ADR-070)
	cfg.set_career_p1(career)
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
	cfg.ball_speed = ball_speed
	cfg.cpu_errors = cpu_errors
	if not p2.is_empty():
		return cfg
	cfg.opponent = opponent
	if opponent >= 0:
		var members: Array = Opponents.team(opponent)["players"]
		for slot in [2, 3]:
			var m: Dictionary = members[mini(slot - 2, members.size() - 1)]
			cfg.variant[slot] = K.VARIANT_FEMALE if m.get("variant", "male") == "female" else K.VARIANT_MALE
			cfg.paddle[slot] = maxi(0, Paddles.NAMES.find(m.get("paddle", "blue")))
		# Dale Dawson plays doubles alone (port ADR-066): two against one
		if doubles and Opponents.solo(opponent):
			cfg.palette[3] = -1
			cfg.human[3] = 0
	return cfg


## OPEN PLAY's location (ADR-078): its name, art and its games' venue.
## The sliders (BALL SPEED ADR-071, BALL SIZE ADR-072, CPU ERRORS ADR-073):
## [min, max, step], read by their rows on the title and the tuning panel.
const SLIDERS := {"ball_speed": [K.BALL_SPEED_MIN, K.BALL_SPEED_MAX, 1],
	"ball_size": [BALL_SIZE_MIN, BALL_SIZE_MAX, 1], "cpu_errors": [0, CPU_ERRORS_MAX, 5]}


static func slider(id: String) -> int:
	match id:
		"ball_speed":
			return ball_speed
		"ball_size":
			return ball_size
		"cpu_errors":
			return cpu_errors
	return 0


## A slider `d` steps along, within its range.
static func nudge(id: String, d: int) -> void:
	var r: Array = SLIDERS[id]
	var v := clampi(slider(id) + d * int(r[2]), int(r[0]), int(r[1]))
	match id:
		"ball_speed":
			ball_speed = v
		"ball_size":
			ball_size = v
		"cpu_errors":
			cpu_errors = v


static func park_name() -> String:
	return String(PARKS[park_i][1])


static func park_art() -> String:
	return String(PARKS[park_i][2])


static func park_venue() -> String:
	return String(PARKS[park_i][3])
