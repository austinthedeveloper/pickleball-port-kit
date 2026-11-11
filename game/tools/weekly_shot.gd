## Renders the WEEKLY CHALLENGE's screen (port ADR-109) with a made-up
## board and a try's result (needs a display; nothing is sent or saved):
##   godot --path game --resolution 960x540 -s res://tools/weekly_shot.gd -- <frames> <out.png>
extends SceneTree

var _frames := 0
var _target := 30
var _out := "user://weekly_shot.png"
var _view: WeeklyScreen


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_target = int(a[0]) if a.size() > 0 else 30
	_out = a[1] if a.size() > 1 else _out
	root.add_child(load("res://game_ui/controls.gd").new())
	Boards.base = "http://127.0.0.1:9"          # nothing answers: the board below stands in
	var sv := SaveGame.new()
	sv.dir = "user://weekly_shot_save/"
	sv.data = SaveGame.defaults()
	sv.career = Career.new()
	sv.career.create(0, "ACE")
	_view = WeeklyScreen.new().setup(sv, {"met": true, "score": 640, "detail": "7-3  DONE"}, false)
	root.add_child(_view)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == _target - 2:
		var rows := []
		for e in [["DOT", 1290, "7-0  DONE"], ["ACE", 640, "7-3  DONE"], ["GUS", 610, "7-4  DONE"], ["MAE", 420, "7-5  DONE"]]:
			rows.append({"initials": e[0], "score": e[1], "detail": e[2]})
		_view.board.show_board(rows, "")
	if _frames >= _target:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
