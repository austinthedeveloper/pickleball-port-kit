## Top level: title <-> match, with the save loaded once and written at
## safe points (leaving the title, a match's end).
extends Node

var save := SaveGame.new()
var _screen: Node
## Fades between screens (PORT-11): out, swap, in. The old screen stops
## during the fade out, so nothing it would do with input happens.
const FADE_OUT := 8
const FADE_IN := 10
var _fader: ColorRect
var _fade := 0                   ## frames left; out while _next is waiting
var _next: Node
## A toast when a controller connects or drops (PORT-15).
const TOAST_FRAMES := 150
var _toast: Control
var _toast_text: BitmapText
var _toast_frames := 0
var _news_seen := GameControls.news_serial
## Open play (ADR-034): the park waits here while you play; fresh each time
## it's entered from the title.
var park: OpenPlay


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fader = ColorRect.new()
	_fader.color = Color(0.02, 0.03, 0.08, 0.0)
	_fader.size = Vector2(960, 540)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fader)
	_toast = Control.new()
	_toast.visible = false
	layer.add_child(_toast)
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 12)
	panel.position = Vector2(330, 460)
	panel.size = Vector2(300, 38)
	_toast.add_child(panel)
	_toast_text = BitmapText.new()
	_toast_text.font = "small"
	_toast_text.align = 0.5
	_toast_text.position = Vector2(480, 470)
	_toast.add_child(_toast_text)
	save.load_game()
	show_title()


func _swap(n: Node) -> void:
	if _screen == null:
		_enter(n)
		return
	_screen.process_mode = Node.PROCESS_MODE_DISABLED
	if _next:
		_next.free()                 # a second swap during the fade replaces the first
	_next = n
	_fade = FADE_OUT


func _enter(n: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = n
	add_child(n)
	_fade = FADE_IN
	GameControls.clear_latch()


func fading() -> bool:
	return _fade > 0


func _update_toast() -> void:
	if _news_seen != GameControls.news_serial:
		_news_seen = GameControls.news_serial
		var news: Array = GameControls.pad_news
		_toast_text.text = "CONTROLLER " + String(news[0])
		_toast_text.tint = Color("60e060") if news[0] == "CONNECTED" else Color("ff7060")
		_toast_frames = TOAST_FRAMES
	if _toast_frames > 0:
		_toast_frames -= 1
	_toast.visible = _toast_frames > 0
	_toast.modulate.a = clampf(_toast_frames / 20.0, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	_update_toast()
	if _fade <= 0:
		_fader.color.a = 0.0
		return
	_fade -= 1
	if _next:
		_fader.color.a = 1.0 - float(_fade) / FADE_OUT
		if _fade == 0:
			var n := _next
			_next = null
			_enter(n)
	else:
		_fader.color.a = float(_fade) / FADE_IN


func show_title() -> void:
	var t := TitleScreen.new()
	t.save = save
	t.start_match.connect(_on_start)
	t.open_park.connect(_on_open_park)
	_swap(t)
	park = null


## OPEN PLAY on the title: a fresh park (2P along if PLAYERS is 2P).
func _on_open_park(two_players: bool) -> void:
	save.save_game()
	park = OpenPlay.new()
	park.begin(Time.get_ticks_usec() & 0xffff, two_players)
	show_park(false)


## The park, from the title or back from your game (`back`: show its
## result) or the ball machine.
func show_park(back: bool) -> void:
	var v := ParkView.new().setup(park, save, back)
	v.leave.connect(show_title)
	v.play.connect(_on_park_match.bind(false))
	v.practice.connect(_on_park_match.bind(true))
	_swap(v)


## Your game, or practice at the ball machine: B on the result (PARK on
## practice's pause menu) comes back; MENU goes to the title.
func _on_park_match(cfg: SimTypes.MatchConfig, is_practice: bool) -> void:
	save.save_game()
	var m := MatchView.new()
	m.save = save
	m.park = true
	m.finished.connect(func(to_title: bool):
		if to_title:
			show_title()
			return
		if not is_practice:
			park.return_from_match(m.sim.match_winner == 0, m.sim.team_score[0], m.sim.team_score[1])
		show_park(not is_practice))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = Settings.time_i
	m.setup(cfg, "park", false)


func _on_start(cfg: SimTypes.MatchConfig, venue: String, ladder: bool, pads: Array = [],
		players: Array = []) -> void:
	save.save_game()
	var m := MatchView.new()
	m.save = save
	m.ladder = ladder
	m.slot_pads = pads.duplicate()       # multiplayer: each human slot's controller
	m.slot_players = players.duplicate()
	m.finished.connect(func(_to_title: bool): show_title())
	m.next_rung.connect(_on_next_rung.bind(cfg))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = Settings.time_i
	m.setup(cfg, venue, false)


## A ladder win: the next opponent, at their home court, with their card.
func _on_next_rung(prev: SimTypes.MatchConfig) -> void:
	var rung: int = save.data["records"]["ladder_rung"]
	var p1 := PlayerSelect.new_choice(prev.palette[0], prev.variant[0], prev.paddle[0])
	var cfg := Settings.config_for(prev.mode == K.MODE_DOUBLES, rung, prev.difficulty,
		prev.points_to_win, p1)
	cfg.modifiers = prev.modifiers
	if prev.career_p1:
		cfg.set_career(save.career.active_player())      # ADR-047
	_on_start(cfg, Settings.home_venue(rung), true)
