## A score board on a screen (port ADR-109): a panel with its title, the
## top ten from the relay (Boards), and a word while it loads or if it
## can't (OFFLINE, NO BOARD YET); your row in gold.
class_name BoardPanel
extends Control

const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)

var area := Rect2()
var you := ""                     ## your initials (your rows in gold)
var status := ""                  ## the word shown, for tests
var rows: Array = []              ## the board's lines, for tests
var _title: BitmapText
var _lines: Array = []
var _req: Boards


func setup(rect: Rect2, title: String, initials: String) -> BoardPanel:
	area = rect
	you = initials
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.panel(rect, self)
	_title = UiKit.text("small", title, Vector2(rect.get_center().x, rect.position.y + 14), 0.5, GOLD, self)
	for k in Boards.SHOWN:
		_lines.append(UiKit.text("small", "", Vector2(rect.position.x + 24, rect.position.y + 46 + k * 24),
			0.0, Color.WHITE, self))
	show_board([], "LOADING")
	return self


## Asks the relay: `post` a score first if given ([initials, score, detail]).
func load_board(board: String, post: Array = []) -> void:
	if _req:
		_req.queue_free()
	_req = Boards.new()
	add_child(_req)
	_req.done.connect(show_board)
	if post.is_empty():
		_req.fetch(board)
	else:
		_req.post(board, String(post[0]), int(post[1]), String(post[2]))


func show_board(board: Array, error: String) -> void:
	rows = Boards.lines(board)
	status = error if error != "" or not rows.is_empty() else "NO SCORES YET"
	for k in _lines.size():
		var t: BitmapText = _lines[k]
		if k < rows.size():
			t.text = String(rows[k])
			t.tint = GOLD if String(board[k].get("initials", "")) == you else Color.WHITE
		elif k == rows.size() and status != "" and (rows.is_empty() or error != ""):
			t.text = status
			t.tint = DIM
		else:
			t.text = ""
