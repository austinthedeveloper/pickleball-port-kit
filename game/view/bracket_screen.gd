## The tournament's bracket (PORT-25): eight entries in four quarterfinals,
## the semifinals and the final, connected, with each match's score, and
## the champion on the right. Under it, three rows: before the first match
## START, MODE and BACK; while you're in it PLAY (your next match: its round
## and opponent), FORFEIT (pressed twice) and BACK; when it's over NEW
## TOURNAMENT, MODE and BACK. Coming back from a match, the results you
## haven't seen appear one at a time. Reads a Tournament; the save holds
## the bracket in play (SaveGame.tournament()).
class_name BracketScreen
extends Node2D

signal play(cfg: SimTypes.MatchConfig, venue: String)   ## your next match
## The couch cup's next match (PORT-29): each human slot's pad and number.
signal play_couch(cfg: SimTypes.MatchConfig, venue: String, pads: Array, players: Array)
signal leave                                            ## BACK: the title

const LOCK := MenuPage.TRANSITION      ## the press that opened it isn't a menu press
const REVEAL_FRAMES := 24              ## between results appearing
## The bracket's columns (x, width) by round, and the champion's.
const COLS := [[40.0, 200.0], [290.0, 200.0], [540.0, 200.0]]
const CHAMP := Rect2(790, 0, 140, 64)
const TOP := 112.0                     ## the first quarterfinal's top
const PAIR_STEP := 64.0                ## quarterfinal pairs, top to top
const ENTRY_H := 24.0
const ENTRY_GAP := 4.0
const DIM := Color(0.62, 0.66, 0.78)
const GOLD := Color("fbe46a")
const YOU_TINT := Color("6aa0ff")

var save: SaveGame
var t: Tournament                      ## the bracket shown (unsaved until START)
var started := false                   ## the save holds it
var page: MenuPage
var forfeit_armed := false
var shown := 0                         ## decided matches on screen
var _lock := LOCK
var _reveal_in := 0
var _sfx: Sfx
var _ui: CanvasLayer
var _board: Node2D                     ## boxes, names and scores, rebuilt as results show
var _lines: Node2D
var _sub: BitmapText
var _champ_name: BitmapText
var _champ_title: BitmapText
var _champ_box: NinePatchRect
var couch := false                     ## the couch cup's bracket (PORT-29)


func setup(game_save: SaveGame, reveal := false, is_couch := false) -> BracketScreen:
	save = game_save
	couch = is_couch
	var saved := save.tournament(key()) if save else null
	if saved:
		t = saved
		started = true
		shown = saved.seen if reveal else decided()
	else:
		t = _fresh(false)
	return self


func music_track() -> String:
	return "title"


func key() -> String:
	return "couch" if couch else "bracket"


func _fresh(doubles: bool) -> Tournament:
	return Tournament.create(Time.get_ticks_usec(), doubles, Settings.difficulty_i,
		Settings.POINTS[Settings.points_i])


func _ready() -> void:
	_backdrop()
	_ui = CanvasLayer.new()
	add_child(_ui)
	UiKit.panel(Rect2(290, 6, 380, 80), _ui)
	UiKit.text("big_gold", "COUCH CUP" if couch else "TOURNAMENT", Vector2(480, 16), 0.5, Color.WHITE, _ui)
	_sub = UiKit.text("small", "", Vector2(480, 56), 0.5, DIM, _ui)
	UiKit.panel(Rect2(20, 92, 920, 282), _ui)
	_lines = Node2D.new()
	_lines.draw.connect(_draw_lines)
	_ui.add_child(_lines)
	_board = Node2D.new()
	_ui.add_child(_board)
	var cy := champ_y()
	_champ_box = UiKit.panel(Rect2(CHAMP.position.x, cy - 40, CHAMP.size.x, 78), _ui, "gold")
	_champ_title = UiKit.text("small", "", Vector2(CHAMP.get_center().x, 0), 0.5, GOLD, _ui)
	_champ_name = UiKit.text("small", "", Vector2(CHAMP.get_center().x, 0), 0.5, Color.WHITE, _ui)
	_build_page()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_refresh()
	GameControls.clear_latch()


## The venue of your next match (or the final's), dimmed behind it all.
func _backdrop() -> void:
	var venue := "park"
	var nm := t.next_match()
	if not nm.is_empty() and not Tournament.is_human(nm["right"]):
		venue = Settings.home_venue(int(nm["right"]))
	for layer in ["far", "ground", "fence"]:
		var path := "res://assets/levels/venues/%s/%s.png" % [venue, layer]
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.position = Vector2(-48, -24)
		add_child(s)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.62)
	shade.size = Vector2(960, 540)
	add_child(shade)


func _build_page() -> void:
	page = MenuPage.new().setup("bracket", "", [
		{"id": "play", "label": func(): return _play_label(),
			"value": func(): return _play_value(), "press": _press_play},
		{"id": "mode", "label": func(): return "FORFEIT" if _in_play() else "MODE",
			"value": func(): return _mode_value(), "change": _change_mode, "press": _press_mode},
		{"id": "back", "label": "BACK", "press": func(): _leave()},
	], Rect2(260, 384, 440, 146), [["hit", "SELECT"], ["back", "BACK"]])
	page.pressed.connect(func(_id): _refresh())
	page.changed.connect(func(_id): _refresh())
	page.back_requested.connect(_leave)
	_ui.add_child(page)


# --- The rows -------------------------------------------------------------------

func _in_play() -> bool:
	return started and not t.next_match().is_empty()


func _play_label() -> String:
	if _in_play():
		return "PLAY"
	if couch:
		return "DONE"                    # a new cup starts in the lobby
	return "NEW TOURNAMENT" if started else "START"


func _play_value() -> String:
	var nm := t.next_match()
	if nm.is_empty():
		return ""
	var r: int = nm["round"]
	if couch:
		return "%s VS %s" % [t.name_of(nm["left"]), t.name_of(nm["right"])]   # the round shows above
	return "%s VS %s" % [Tournament.ROUND_SHORT[r], Tournament.entry_name(nm["opponent"])]


func _mode_value() -> String:
	if _in_play():
		return "PRESS AGAIN" if forfeit_armed else ""
	return "DOUBLES" if t.doubles else "SINGLES"


func _change_mode(_dir: int) -> void:
	if _in_play() or couch:
		return                           # the cup's mode came from the lobby
	t = _fresh(not t.doubles)
	started = false
	shown = 0
	_refresh()


func _press_mode() -> void:
	if not _in_play():
		_change_mode(1)
		return
	if not forfeit_armed:
		forfeit_armed = true
		return
	# a forfeit: the next match goes to the right side, and play goes on
	t.record_left(false, 0, t.points)
	if not couch:
		save.record_cup(t.finish())
	_store()
	forfeit_armed = false


func _press_play() -> void:
	if couch and not _in_play():
		_leave()                         # DONE
		return
	if started and not _in_play():
		t = _fresh(t.doubles)            # NEW TOURNAMENT
		started = false
		shown = 0
		_refresh()
		return
	if not started:
		started = true
		_store()
	_sfx.play("confirm")
	if couch:
		var cm := t.couch_match(Settings.mod_bits, Settings.venue())
		play_couch.emit(cm["cfg"], cm["venue"], cm["pads"], cm["players"])
		return
	var nm := t.next_match()
	play.emit(match_config(), Settings.home_venue(int(nm["opponent"])))


## Your next match: you in your last Player Select choice, or as the active
## career player (ADR-047), with the saved modifiers.
func match_config() -> SimTypes.MatchConfig:
	var me: Career.Player = save.career.active_player() if save else null
	var p1 := Settings.p1_choice
	if me != null:
		p1 = PlayerSelect.new_choice(me.shirt, me.variant, me.paddle)
	var cfg := t.match_config(p1, Settings.mod_bits)
	if me != null:
		cfg.set_career(me)
	return cfg


func _store() -> void:
	if save == null:
		return
	t.seen = shown
	save.store_tournament(t, key())
	save.save_game()


func _leave() -> void:
	if _sfx:
		_sfx.play("back")
	if started:
		_store()
	leave.emit()


# --- The bracket ----------------------------------------------------------------

## Matches with a result, in round order.
func decided() -> int:
	var n := 0
	for r in Tournament.ROUNDS:
		for m in Tournament.matches_in(r):
			if not t.results[r][m].is_empty():
				n += 1
	return n


## The champion's centre: level with the final's line out.
static func champ_y() -> float:
	return (entry_y(2, 0, 0) + entry_y(2, 0, 1) + ENTRY_H) / 2.0


## The y of an entry's box top: round r, match m, place k (0 top, 1 bottom).
static func entry_y(r: int, m: int, k: int) -> float:
	if r == 0:
		return TOP + m * PAIR_STEP + k * (ENTRY_H + ENTRY_GAP)
	var a := entry_y(r - 1, 2 * m + k, 0)
	var b := entry_y(r - 1, 2 * m + k, 1)
	return (a + b) / 2.0


func _refresh() -> void:
	_sub.text = "%s   %s   TO %d" % ["DOUBLES" if t.doubles else "SINGLES",
		Settings.DIFFICULTIES[clampi(t.difficulty, 0, Settings.DIFFICULTIES.size() - 1)],
		t.points]
	for c in _board.get_children():
		_board.remove_child(c)
		c.free()
	var order := 0
	for r in Tournament.ROUNDS:
		var col: Array = COLS[r]
		for m in Tournament.matches_in(r):
			var e := t.entrants(r, m)
			var res: Array = t.results[r][m]
			var visible_result := not res.is_empty() and order < shown
			if not res.is_empty():
				order += 1
			for k in 2:
				var who: Variant = e[k]
				if r > 0 and who != null and not _feeder_shown(r, m, k):
					who = null
				_entry(Rect2(col[0], entry_y(r, m, k), col[1], ENTRY_H), who, res, visible_result)
	var champ: Variant = t.champion() if decided() <= shown else null
	var cy := champ_y()
	_champ_title.position.y = cy - 28
	_champ_name.position.y = cy + 4
	_champ_title.text = "CHAMPIONS" if t.doubles else "CHAMPION"
	_champ_name.text = t.name_of(champ) if champ != null else "?"
	_champ_name.tint = Color.WHITE
	if Tournament.is_human(champ):
		var cp := t.palette_of(champ)
		_champ_name.tint = MatchView.TEAM_TINTS[cp] if cp >= 0 else YOU_TINT
	_lines.queue_redraw()
	if page:
		page.refresh()


## Whether the match that feeds this place has been revealed.
func _feeder_shown(r: int, m: int, k: int) -> bool:
	var order := 0
	for rr in Tournament.ROUNDS:
		for mm in Tournament.matches_in(rr):
			if rr == r - 1 and mm == 2 * m + k:
				return order < shown
			if not t.results[rr][mm].is_empty():
				order += 1
	return false


func _entry(rect: Rect2, who: Variant, res: Array, show_result: bool) -> void:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	var you := Tournament.is_human(who)
	box.color = Color(0.16, 0.24, 0.5, 0.85) if you else Color(0.05, 0.07, 0.14, 0.8)
	_board.add_child(box)
	var name := t.name_of(who) if who != null else "---"
	var tint := Color.WHITE
	if you:
		var pal := t.palette_of(who)
		tint = MatchView.TEAM_TINTS[pal] if pal >= 0 else YOU_TINT
	var score := ""
	if show_result and who != null:
		var won := int(res[0]) == int(who)
		score = str(res[1] if won else res[2])
		if not won:
			tint = DIM
		elif not you:
			tint = GOLD
	elif who == null:
		tint = DIM
	if you and not couch and save and save.career.active_player() != null:
		name = save.career.active_player().shown_name()
	UiKit.text("small", name, rect.position + Vector2(8, 4), 0.0, tint, _board)
	if score != "":
		UiKit.text("small", score, Vector2(rect.end.x - 8, rect.position.y + 4), 1.0, tint, _board)


func _draw_lines() -> void:
	var c := Color(0.55, 0.6, 0.75, 0.7)
	for r in Tournament.ROUNDS:
		var col: Array = COLS[r]
		for m in Tournament.matches_in(r):
			var x0: float = col[0] + col[1]
			var ya := entry_y(r, m, 0) + ENTRY_H / 2.0
			var yb := entry_y(r, m, 1) + ENTRY_H / 2.0
			var xm := x0 + 22.0
			var target_y := (ya + yb) / 2.0
			_lines.draw_line(Vector2(x0, ya), Vector2(xm, ya), c, 2.0)
			_lines.draw_line(Vector2(x0, yb), Vector2(xm, yb), c, 2.0)
			_lines.draw_line(Vector2(xm, ya), Vector2(xm, yb), c, 2.0)
			var x1: float = COLS[r + 1][0] if r + 1 < Tournament.ROUNDS else CHAMP.position.x
			_lines.draw_line(Vector2(xm, target_y), Vector2(x1, target_y), c, 2.0)


# --- Frame ------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if shown < decided():
		_reveal_in -= 1
		if _reveal_in <= 0:
			shown += 1
			_reveal_in = REVEAL_FRAMES
			_sfx.play("blip")
			if shown == decided():
				_store()
				if t.over():
					_sfx.play("confirm")
					if Tournament.is_human(t.champion()):
						Music.sting("cleared")
			_refresh()
	if _lock > 0:
		_lock -= 1
		return
	if GameControls.menu_pressed("move_up"):
		page.move(-1)
		_moved()
	elif GameControls.menu_pressed("move_down"):
		page.move(1)
		_moved()
	var dir := 0
	if GameControls.menu_pressed("move_left"):
		dir = -1
	elif GameControls.menu_pressed("move_right"):
		dir = 1
	if dir != 0 and page.change(dir):
		_sfx.play("blip")
		_refresh()
	if Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
		_leave()
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		if page.press():
			_sfx.play("blip")
			_refresh()


func _moved() -> void:
	forfeit_armed = false
	_sfx.play("blip")
	page.refresh()
