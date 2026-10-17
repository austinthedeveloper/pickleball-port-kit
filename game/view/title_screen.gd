## Title: the logo and menu over a live CPU demo at the chosen venue.
## Up/Down pick a row, Left/Right change it, B/Start on a PLAY row starts.
class_name TitleScreen
extends Node2D

signal start_match(cfg: SimTypes.MatchConfig, venue: String, ladder: bool)

const VENUES := ["park", "lakeside", "sunset"]
const VENUE_NAMES := ["PARK", "LAKESIDE", "SUNSET"]
const DIFFICULTIES := ["KID", "EASY", "MEDIUM", "HARD"]
const POINTS := [3, 5, 7, 9, 11, 15, 21]
const ROWS := ["SINGLES", "DOUBLES", "VENUE", "VS", "DIFFICULTY", "POINTS", "MODS", "PLAYERS", "CAMERA"]
const MODS := [[0, "NONE"], [K.MOD_BIG_BALL, "BIG BALL"], [K.MOD_FAST_BALL, "FAST BALL"],
	[K.MOD_WIN_BY_2, "WIN BY 2"], [K.MOD_LAVA, "LAVA"], [15, "ALL FOUR"]]
const ROW_H := 29
const CAMERAS := [0, 50, 75, 100]

static var venue_i := 0
static var difficulty_i := K.DIFFICULTY_MEDIUM
static var points_i := 1
## -2 = the ladder's current rung, -1 = the default CPU, else a team.
static var opponent_i := -2
static var cursor := 0
static var two_players := false
static var camera_i := 0
static var mods_i := 0

var _demo: MatchView
var _ui: CanvasLayer
var _rows: Array = []
var _values: Array = []
var _arrow: Sprite2D
var _sfx: Sfx
var _lock := 10
var _demo_doubles := true
var save: SaveGame
var _record: BitmapText


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
	mods_i = clampi(int(st.get("mods", 0)), 0, MODS.size() - 1)


func _store_settings() -> void:
	if save == null:
		return
	save.data["settings"] = {"venue": venue_i, "difficulty": difficulty_i,
		"points": points_i, "players": 2 if two_players else 1, "opponent": opponent_i,
		"camera": camera_i, "mods": mods_i}


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
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 12)
	panel.position = Vector2(300, 172)
	panel.size = Vector2(360, 300)
	_ui.add_child(panel)
	for i in ROWS.size():
		var label := BitmapText.new()
		label.font = "small"
		label.text = ROWS[i]
		label.position = Vector2(340, 190 + i * ROW_H)
		_ui.add_child(label)
		_rows.append(label)
		var value := BitmapText.new()
		value.font = "small"
		value.align = 1.0
		value.position = Vector2(624, 190 + i * ROW_H)
		value.tint = Color("fbe46a")
		_ui.add_child(value)
		_values.append(value)
	_arrow = Sprite2D.new()
	_arrow.texture = load("res://assets/levels/ui/icon_ball.png")
	_arrow.centered = false
	_ui.add_child(_arrow)
	var help := BitmapText.new()
	help.font = "small"
	help.text = "D-PAD CHOOSE   B START"
	help.align = 0.5
	help.position = Vector2(480, 488)
	_ui.add_child(help)
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
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_refresh()


func _start_demo() -> void:
	if _demo:
		_demo.queue_free()
	_demo = MatchView.new()
	add_child(_demo)
	move_child(_demo, 0)
	var cfg := SimTypes.MatchConfig.doubles() if _demo_doubles else SimTypes.MatchConfig.singles()
	_demo.setup(cfg, VENUES[venue_i], true)
	_demo._hud.visible = false


func _refresh() -> void:
	_values[0].text = ""
	_values[1].text = ""
	_values[2].text = VENUE_NAMES[venue_i]
	_values[3].text = _opponent_label()
	_values[4].text = DIFFICULTIES[difficulty_i]
	_values[5].text = str(POINTS[points_i])
	_values[6].text = MODS[mods_i][1]
	_values[7].text = "2P VS" if two_players else "1P"
	_values[8].text = "OFF" if camera_i == 0 else "%d%%" % CAMERAS[camera_i]
	_arrow.position = Vector2(318, 190 + cursor * ROW_H)
	for i in _rows.size():
		_rows[i].tint = Color.WHITE if i == cursor else Color(0.7, 0.74, 0.85)
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
	var cfg := config_for(doubles, opp, difficulty_i, POINTS[points_i])
	cfg.modifiers = MODS[mods_i][0]
	if two_players:
		cfg.human[2] = 1
	return cfg


## A match against a ladder team (or the default CPU, -1): their look's
## body variant and paddle on slots 2-3 (match_config_opponent).
static func config_for(doubles: bool, opponent: int, difficulty: int, points: int) -> SimTypes.MatchConfig:
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.difficulty = difficulty
	cfg.points_to_win = points
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
	var moved := false
	if Input.is_action_just_pressed("move_up"):
		cursor = (cursor + ROWS.size() - 1) % ROWS.size()
		moved = true
	elif Input.is_action_just_pressed("move_down"):
		cursor = (cursor + 1) % ROWS.size()
		moved = true
	var dir := 0
	if Input.is_action_just_pressed("move_left"):
		dir = -1
	elif Input.is_action_just_pressed("move_right"):
		dir = 1
	if dir != 0:
		match cursor:
			2:
				venue_i = (venue_i + dir + VENUES.size()) % VENUES.size()
				_start_demo()
			3:
				opponent_i += dir
				if opponent_i < -2:
					opponent_i = Opponents.count() - 1
				elif opponent_i >= Opponents.count():
					opponent_i = -2
				var team := _rung() if opponent_i == -2 else opponent_i
				if opponent_i != -1:
					venue_i = VENUES.find(home_venue(team))
					_start_demo()
			4:
				difficulty_i = clampi(difficulty_i + dir, 0, DIFFICULTIES.size() - 1)
			5:
				points_i = clampi(points_i + dir, 0, POINTS.size() - 1)
			6:
				mods_i = (mods_i + dir + MODS.size()) % MODS.size()
			7:
				two_players = not two_players
			8:
				camera_i = clampi(camera_i + dir, 0, CAMERAS.size() - 1)
		moved = true
	if moved:
		_sfx.play("blip")
		_refresh()
	if Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		if cursor <= 1:
			_sfx.play("confirm")
			_store_settings()
			start_match.emit(config(cursor == 1), VENUES[venue_i],
				opponent_i == -2 and not two_players)
