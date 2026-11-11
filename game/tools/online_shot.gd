## Renders the online screens of port ADR-110 (needs a display; nothing
## is sent): the guest's mirrored match in two career looks, the host's
## plain one, or ONLINE's letter grid.
##   godot --path game --resolution 960x540 -s res://tools/online_shot.gd -- <guest|host|grid> <frames> <out.png>
extends SceneTree

var _frames := 0
var _target := 60
var _out := "user://online_shot.png"
var _view: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var what := a[0] if a.size() > 0 else "guest"
	_target = int(a[1]) if a.size() > 1 else 60
	_out = a[2] if a.size() > 2 else _out
	root.add_child(load("res://game_ui/controls.gd").new())
	if what == "grid":
		var o := OnlineScreen.new().setup(null)
		root.add_child(o)
		if not o.is_node_ready():
			o._ready()
		o.page.select("address")
		o._press_address()
		o.grid_type("BXK")
		o.grid.select("g1")
		o.grid_cols[1] = 2
		_view = o
		return
	var ann := Career.Player.new()
	ann.used = 1
	ann.hat = 2
	ann.hair = 3
	ann.pattern = 1
	ann.head = 1
	var bo := Career.Player.new()
	bo.used = 1
	bo.shirt = 1
	bo.hat = 1
	bo.skin = 2
	bo.head = 2
	var pair := LoopbackLink.pair(0)
	var s := OnlineSession.new(pair[0], what == "host")
	s.peer_hello = {"name": "BO" if what == "host" else "ANN"}
	s.start = {"looks": {"0": OnlineSession.career_look(ann), "2": OnlineSession.career_look(bo)}}
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, PlayerSelect.new_choice(0, 0, 1),
		PlayerSelect.new_choice(1, 0, 1))
	var v := MatchView.new()
	v.net = s
	v.input.script_intent = func() -> SimTypes.Intent: return SimTypes.Intent.new()
	root.add_child(v)
	v.setup(cfg, "park", false)
	v.sim.team_score = [5, 2]
	_view = v


func _process(_delta: float) -> bool:
	_frames += 1
	if _view is MatchView:
		var v: MatchView = _view
		v.sim.step([SimTypes.Intent.new(), null, SimTypes.Intent.new(), null])
		v._update_visuals()
		v._hud.refresh()
	if _frames >= _target:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
