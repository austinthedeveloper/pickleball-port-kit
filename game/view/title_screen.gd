## Title: the logo and menu over a live CPU demo at the chosen venue.
## Up/Down pick a row, Left/Right change it, B/Start on a PLAY row starts.
class_name TitleScreen
extends Node2D

signal start_match(cfg: SimTypes.MatchConfig, venue: String)

const VENUES := ["park", "lakeside", "sunset"]
const VENUE_NAMES := ["PARK", "LAKESIDE", "SUNSET"]
const DIFFICULTIES := ["KID", "EASY", "MEDIUM", "HARD"]
const POINTS := [3, 5, 7, 9, 11, 15, 21]
const ROWS := ["SINGLES", "DOUBLES", "VENUE", "OPPONENT", "DIFFICULTY", "POINTS"]

static var venue_i := 0
static var difficulty_i := K.DIFFICULTY_MEDIUM
static var points_i := 1
static var opponent_i := -1
static var cursor := 0

var _demo: MatchView
var _ui: CanvasLayer
var _rows: Array = []
var _values: Array = []
var _arrow: Sprite2D
var _sfx: Sfx
var _lock := 10
var _demo_doubles := true


func _ready() -> void:
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
	panel.position = Vector2(300, 182)
	panel.size = Vector2(360, 228)
	_ui.add_child(panel)
	for i in ROWS.size():
		var label := BitmapText.new()
		label.font = "small"
		label.text = ROWS[i]
		label.position = Vector2(340, 204 + i * 32)
		_ui.add_child(label)
		_rows.append(label)
		var value := BitmapText.new()
		value.font = "small"
		value.align = 1.0
		value.position = Vector2(624, 204 + i * 32)
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
	help.position = Vector2(480, 470)
	_ui.add_child(help)
	var keys := BitmapText.new()
	keys.font = "small"
	keys.text = "MOVE: ARROWS  B: SPACE  A: K  Y: L  START: ENTER"
	keys.align = 0.5
	keys.position = Vector2(480, 500)
	keys.tint = Color(0.75, 0.8, 0.9)
	_ui.add_child(keys)
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
	_values[3].text = "CPU" if opponent_i < 0 else Opponents.team(opponent_i)["team"]
	_values[4].text = DIFFICULTIES[difficulty_i]
	_values[5].text = str(POINTS[points_i])
	_arrow.position = Vector2(318, 204 + cursor * 32)
	for i in _rows.size():
		_rows[i].tint = Color.WHITE if i == cursor else Color(0.7, 0.74, 0.85)


func config(doubles: bool) -> SimTypes.MatchConfig:
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.difficulty = difficulty_i
	cfg.points_to_win = POINTS[points_i]
	cfg.opponent = opponent_i
	if opponent_i >= 0:
		var members: Array = Opponents.team(opponent_i)["players"]
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
				if opponent_i < -1:
					opponent_i = Opponents.count() - 1
				elif opponent_i >= Opponents.count():
					opponent_i = -1
				if opponent_i >= 0:
					var home: String = String(Opponents.team(opponent_i).get("venue", "PARK")).to_lower()
					if home in VENUES:
						venue_i = VENUES.find(home)
						_start_demo()
			4:
				difficulty_i = clampi(difficulty_i + dir, 0, DIFFICULTIES.size() - 1)
			5:
				points_i = clampi(points_i + dir, 0, POINTS.size() - 1)
		moved = true
	if moved:
		_sfx.play("blip")
		_refresh()
	if Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		if cursor <= 1:
			_sfx.play("confirm")
			start_match.emit(config(cursor == 1), VENUES[venue_i])
