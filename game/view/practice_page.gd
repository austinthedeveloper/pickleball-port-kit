## The practice page (ADR-028): the drill editor over the title. SHOT,
## TARGET, RATE, RETURN TO, and the zone's BEST STREAK; Practice.Edit
## (practice_edit_input) does the editing, this draws it.
class_name PracticePage
extends Control

const ROWS := ["SHOT", "TARGET", "RATE", "RETURN TO"]
const ROW_H := 36

var edit := Practice.Edit.new()
var drill: Array = []
var save: SaveGame
var _values: Array = []
var _labels: Array = []
var _best: BitmapText
var _arrow: Sprite2D


func _init() -> void:
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 12)
	panel.position = Vector2(300, 172)
	panel.size = Vector2(360, 300)
	add_child(panel)
	_text("big_gold", "PRACTICE", Vector2(480, 190), 0.5, Color.WHITE)
	for i in ROWS.size():
		_labels.append(_text("small", ROWS[i], Vector2(340, 250 + i * ROW_H), 0.0, Color.WHITE))
		_values.append(_text("small", "", Vector2(624, 250 + i * ROW_H), 1.0, Color("fbe46a")))
	_best = _text("small", "", Vector2(480, 404), 0.5, Color.WHITE)
	add_child(PromptBar.new().setup([["hit", "PLAY"], ["back", "BACK"]], Vector2(480, 446)))
	_arrow = Sprite2D.new()
	_arrow.texture = load("res://assets/levels/ui/icon_ball.png")
	_arrow.centered = false
	add_child(_arrow)


func _text(font: String, s: String, at: Vector2, align: float, tint: Color) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.text = s
	t.align = align
	t.position = at
	t.tint = tint
	add_child(t)
	return t


## Opens on the saved drill.
func open(s: SaveGame) -> void:
	save = s
	drill = s.practice_settings() if s else Practice.DEFAULTS.duplicate()
	edit.begin(drill)
	refresh()


func refresh() -> void:
	_values[0].text = Practice.shot_name(drill[0])
	_values[1].text = Practice.target_name(drill[1])
	_values[2].text = Practice.rate_name(drill[2])
	_values[3].text = Practice.zone_name(drill[3])
	for i in _labels.size():
		_labels[i].tint = Color.WHITE if i == edit.row else Color(0.7, 0.74, 0.85)
	_arrow.position = Vector2(318, 250 + edit.row * ROW_H)
	_best.text = "BEST STREAK %d" % (save.practice_saved_best(drill[3]) if save else 0)


## One frame's presses (SNES pad bits): Practice.EDIT_* result. A done
## edit keeps the drill in the save's settings.
func input(pressed: int) -> int:
	var result := edit.input(drill, pressed)
	if result == Practice.EDIT_DONE and save:
		save.data["settings"]["practice"] = drill.duplicate()
	refresh()
	return result


## A practice session on the drill at the chosen difficulty, P1 in their
## last Player Select choice (or as the career player, ADR-047).
func config() -> SimTypes.MatchConfig:
	var cfg: SimTypes.MatchConfig
	if save:
		cfg = save.practice_config(Settings.difficulty_i)
	else:
		cfg = SimTypes.MatchConfig.practice_session(drill if drill.size() == Practice.ROWS
			else Practice.DEFAULTS, 0)
		cfg.difficulty = Settings.difficulty_i
	cfg.palette[0] = Settings.p1_choice["palette"]
	cfg.variant[0] = Settings.p1_choice["variant"]
	cfg.paddle[0] = Settings.p1_choice["paddle"]
	if save:
		cfg.set_career_p1(save.career.active_player())
	return cfg
