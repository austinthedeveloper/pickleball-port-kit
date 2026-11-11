## The WEEKLY CHALLENGE's screen (port ADR-109, PORT-159): this week's
## challenge (its name, what it asks, your best and tries), PLAY and BACK,
## and the week's board from the relay. After a try, its result first.
class_name WeeklyScreen
extends Control

signal play(cfg: SimTypes.MatchConfig, venue: String, time: int)
signal leave

const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)
const LEFT := Rect2(24, 24, 440, 300)

var save: SaveGame
var page: MenuPage
var board: BoardPanel
var result: Dictionary = {}        ## the try just played, shown first
var posted := false                ## the result went to the board
var lines: Array = []              ## the left panel's text, for tests
var _lock := MenuPage.TRANSITION
var _sfx: Sfx


func setup(game_save: SaveGame, last: Dictionary = {}, new_best := false) -> WeeklyScreen:
	save = game_save
	result = last
	posted = new_best
	return self


func music_track() -> String:
	return "title"


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Weekly.current()
	var venue := String(c["venue"])
	for layer in ["far", "ground", "fence"]:
		var path := "res://assets/levels/venues/%s/%s.png" % [venue, layer]
		if ResourceLoader.exists(path):
			var s := Sprite2D.new()
			s.texture = load(path)
			s.centered = false
			s.position = Vector2(-48, -24)
			add_child(s)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.6)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	UiKit.panel(LEFT, self)
	var w := Weekly.week()
	UiKit.text("big_gold", "WEEKLY", Vector2(LEFT.get_center().x, LEFT.position.y + 14), 0.5, Color.WHITE, self)
	var m := Weekly.meta(save)
	lines = ["WEEK %d: %s" % [int(w[1]), String(c["name"])]]
	for t in c["text"]:
		lines.append(String(t))
	lines.append("TO %d, %s" % [int(c["points"]), "DOUBLES" if bool(c["doubles"]) else "SINGLES"])
	if not result.is_empty():
		lines.append("YOUR TRY: " + String(result["detail"]) + ("  +%d" % int(result["score"]) if bool(result["met"]) else ""))
	lines.append("BEST %s   TRIES %d" % [str(int(m["best"])) if int(m["best"]) >= 0 else "-", int(m["tries"])])
	for k in lines.size():
		var tint := GOLD if k == 0 else (Color.WHITE if k < lines.size() - 1 else DIM)
		UiKit.text("small", String(lines[k]), Vector2(LEFT.position.x + 24, LEFT.position.y + 70 + k * 28), 0.0, tint, self)
	page = MenuPage.new().setup("weekly", "", [
		{"id": "play", "label": "PLAY", "value": func(): return String(c["goal"]), "press": func(): _play()},
		# SCORE BOARDS: your best to the boards (this week's and TODAY'S TRIP's), or not
		{"id": "post", "label": "SCORE BOARDS", "value": func(): return "POST MINE" if Settings.board_post else "OFF",
			"change": func(_d): Settings.board_post = not Settings.board_post},
		{"id": "back", "label": "BACK", "press": func(): _leave()},
	], Rect2(24, 340, 440, 18 + 3 * MenuPage.ROW_H + 50), [["hit", "SELECT"], ["back", "BACK"]])
	add_child(page)
	page.back_requested.connect(_leave)
	board = BoardPanel.new().setup(Rect2(488, 24, 448, 300), "THIS WEEK'S BOARD", Boards.initials(save))
	add_child(board)
	if posted:
		board.load_board(Weekly.board(), [Boards.initials(save), int(result["score"]), String(result["detail"])])
	else:
		board.load_board(Weekly.board())
	GameControls.clear_latch()


func _play() -> void:
	_sfx.play("confirm")
	Settings.store_to(save)
	var c := Weekly.current()
	var me: Career.Player = save.career.active_player() if save else null
	play.emit(Weekly.config(c, Settings.p1_choice, me), String(c["venue"]), int(c["time"]))


func _leave() -> void:
	_sfx.play("back")
	Settings.store_to(save)                  # SCORE BOARDS
	leave.emit()


func _process(_delta: float) -> void:
	if _lock > 0:
		_lock -= 1
		return
	var nav := page.drive()
	if nav & MenuPage.NAV_MOVED:
		_sfx.play("blip")
	if nav & MenuPage.NAV_BACK:
		_leave()
