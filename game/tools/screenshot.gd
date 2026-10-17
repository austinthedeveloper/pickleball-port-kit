## Renders a screen for N frames and saves the viewport (needs a display):
##   godot --path game -s res://tools/screenshot.gd -- <title|title_<page>|singles|doubles|demo|practice|practice_<zone>> <venue> <frames> <out.png> [human] [opp=N]
## "human" leaves P1 human (it serves on its own after the ready delay is
## not automatic, so the default makes P1 a bot for a moving picture).
## "opp=N" plays ladder team N (0-based) in their looks. "title_options"
## (any page id) opens that title page; "pause" pauses the match at the end.
extends SceneTree

var _frames := 0
var _target := 120
var _out := "user://shot.png"
var _view: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mode: String = a[0] if a.size() > 0 else "singles"
	var venue: String = a[1] if a.size() > 1 else "park"
	_target = int(a[2]) if a.size() > 2 else 120
	_out = a[3] if a.size() > 3 else "user://shot.png"
	var controls = load("res://game_ui/controls.gd").new()
	root.add_child(controls)
	if mode.begins_with("title"):
		TitleScreen.venue_i = maxi(0, TitleScreen.VENUES.find(venue))
		_view = TitleScreen.new()
		root.add_child(_view)
		if mode.begins_with("title_"):
			_view.ready.connect(func(): _view.open_page(mode.substr(6)))
	else:
		var m := MatchView.new()
		root.add_child(m)
		var cfg := SimTypes.MatchConfig.doubles() if mode == "doubles" else SimTypes.MatchConfig.singles()
		if mode.begins_with("practice"):
			# practice_kitchen, practice_deep, ...: that RETURN TO zone.
			var zone := 0
			for z in Practice.ZONES:
				if mode.ends_with("_" + Practice.zone_name(z).to_lower().split(" ")[0]):
					zone = z
			cfg = SimTypes.MatchConfig.practice_session([Practice.SHOT_MIX,
				Practice.TARGET_RANDOM, Practice.RATE_NORMAL, zone], 12)
		for arg in a.slice(4):
			if arg.begins_with("opp="):
				cfg = TitleScreen.config_for(mode == "doubles", int(arg.substr(4)),
					cfg.difficulty, cfg.points_to_win)
		m.setup(cfg, venue, mode == "demo")
		if mode != "demo" and not "human" in a.slice(4):
			m.sim.p1_bot = true
		_view = m
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _view is MatchView and _view.sim.p1_bot and _view.sim.phase == K.PHASE_SERVE_SETUP \
			and _view.sim.server_index == 0 and _frames % 32 == 0:
		# the bot presses B to serve, like the test harness
		_view.sim.intents[0].hit_pressed = 1
		_view.sim.serve_requested = 1
	if _frames == _target - 10 and _view is MatchView and "pause" in OS.get_cmdline_user_args():
		_view.sim.paused = 1
	if _frames >= _target:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit()
