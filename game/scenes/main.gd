## Top level: title <-> match, with the save loaded once and written at
## safe points (leaving the title, a match's end). The music (PORT-22)
## lives here, across screens: each screen entered names its loop.
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
var _toast_panel: NinePatchRect
var _toast_frames := 0
var _news_seen := GameControls.news_serial
## Open play (ADR-034): the park waits here while you play; fresh each time
## it's entered from the title.
var park: OpenPlay
var music: Music


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
	_toast_panel = UiKit.panel(Rect2(330, 460, 300, 38), _toast)
	_toast_text = UiKit.text("small", "", Vector2(480, 470), 0.5, Color.WHITE, _toast)
	music = Music.new()
	add_child(music)
	save.load_game()
	Updater.mark_good()                # PORT-32: an updated launch reached the title
	if UpdateScreen.wanted():
		show_update()                  # PORT-34: first, any update (it can't be skipped)
	else:
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
	if music and n.has_method("music_track"):
		music.play_loop(n.music_track())
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
		_fit_toast()
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
	t.open_tournament.connect(show_bracket)
	t.open_couch_cup.connect(_on_couch_cup)
	t.open_lesson.connect(show_lesson)
	t.open_online.connect(show_online)
	t.open_story.connect(func(): show_story(StoryMode.current(save), "intro"))
	t.open_course.connect(show_course)
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
	var rung: int = save.ladder(prev.mode == K.MODE_DOUBLES)
	var p1 := PlayerSelect.new_choice(prev.palette[0], prev.variant[0], prev.paddle[0])
	var cfg := Settings.config_for(prev.mode == K.MODE_DOUBLES, rung, prev.difficulty,
		prev.points_to_win, p1)
	cfg.modifiers = prev.modifiers
	if prev.career_p1:
		cfg.set_career(save.career.active_player())      # ADR-047
	_on_start(cfg, Settings.home_venue(rung), true)


## The tournament's bracket (PORT-25), from the title or back from a match
## (`reveal`: the new results appear one at a time).
func show_bracket(reveal := false, couch := false) -> void:
	save.save_game()
	var b := BracketScreen.new().setup(save, reveal, couch)
	b.leave.connect(show_title)
	b.play.connect(_on_tournament_match)
	b.play_couch.connect(func(cfg, venue, pads, players):
		_on_tournament_match(cfg, venue, pads, players, true))
	_swap(b)


## The lobby's couch cup (PORT-29): a new bracket for its entries, with
## the MATCH SETUP difficulty and points, replacing any cup before it.
func _on_couch_cup(entries: Array, doubles: bool) -> void:
	var t := Tournament.create(Time.get_ticks_usec(), doubles, Settings.difficulty_i,
		Settings.POINTS[Settings.points_i], entries)
	save.store_tournament(t, "couch")
	show_bracket(false, true)


## A tournament match at the opponent's home court: the match records its
## result in the bracket; B on the result comes back to it, MENU to the title.
func _on_tournament_match(cfg: SimTypes.MatchConfig, venue: String, pads: Array = [],
		players: Array = [], couch := false) -> void:
	save.save_game()
	var m := MatchView.new()
	m.save = save
	m.tournament = true
	m.cup_key = "couch" if couch else "bracket"
	m.slot_pads = pads.duplicate()       # the couch cup: each human slot's controller
	m.slot_players = players.duplicate()
	m.finished.connect(func(to_title: bool):
		if to_title:
			show_title()
		else:
			show_bracket(true, couch))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = Settings.time_i
	m.setup(cfg, venue, false)


# --- STORY: SAVE THE PARK (ADR-069) ------------------------------------------------

## Your look in the story: the active career player's, or MATCH SETUP's 1P.
func _story_me() -> PlayerLook:
	var manifest := MatchView.levels_manifest()
	var me := save.career.active_player()
	if me:
		return PlayerLook.for_career(me, me.shirt, me.variant, me.paddle, manifest)
	var c: Dictionary = Settings.p1_choice
	return PlayerLook.for_team(int(c["palette"]), int(c["variant"]), int(c["paddle"]), manifest)


## A scene of chapter `ch`; what follows it: the intro, the match; a win,
## the next chapter (or, the last, the ending); a loss, the match again;
## the ending, the title. Start skips a scene, never the match.
func show_story(ch: int, kind: String) -> void:
	save.save_game()
	var s := StoryScene.new().setup(save, ch, kind, _story_me())
	s.done.connect(_on_story_scene_done.bind(ch, kind))
	_swap(s)


func _on_story_scene_done(_skipped: bool, ch: int, kind: String) -> void:
	if kind == "intro" or kind == "lose":
		_on_story_match(ch)
	elif kind == "win" and ch < StoryMode.CHAPTERS - 1:
		show_story(ch + 1, "intro")
	elif kind == "win":
		show_story(ch, "ending")
	else:
		show_title()


## A chapter's match at its venue and time. B on the result goes on: the
## win scene, or Pepper's word and a rematch; MENU leaves (the chapter is
## kept, as SNES ADR-077 has it).
func _on_story_match(ch: int) -> void:
	save.save_game()
	var cfg := StoryMode.config(ch, Settings.p1_choice, save.career.active_player())
	var m := MatchView.new()
	m.save = save
	m.story_mode = true
	m.finished.connect(func(to_title: bool):
		if to_title:
			show_title()
			return
		if m.sim.match_winner == 0:
			StoryMode.win(save, ch)
			save.save_game()
			show_story(ch, "win")
		else:
			show_story(ch, "lose"))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = StoryMode.time(ch)
	m.setup(cfg, StoryMode.venue(ch), false)


## PICKLEBALL 101 (ADR-070): the lessons list, its cursor on `at`. A
## lesson's TRY IT plays the HOW TO PLAY drill, then comes back here.
func show_course(at := -1) -> void:
	save.save_game()
	var c := CourseScreen.new().setup(save)
	c.leave.connect(show_title)
	c.try_lesson.connect(func(k: int): show_lesson(k, c.lesson))
	_swap(c)
	if at >= 0:
		c.ready.connect(func():
			c.list.cursor = at
			c.list.refresh()
			c._show_preview())


## HOW TO PLAY (PORT-30): lesson `i`, then the next, to the end (then the
## title). Each finished lesson is saved; MAIN MENU on the pause menu leaves.
## From PICKLEBALL 101 (`course`, its lesson), just the one, then back there.
func show_lesson(i: int, course := -1) -> void:
	save.save_game()
	var m := MatchView.new()
	m.lesson = Tutorial.new(i)
	m.finished.connect(func(to_title: bool):
		if to_title and course >= 0:
			show_course(course)
			return
		if to_title:
			show_title()
			return
		save.finish_lesson(i)
		save.save_game()
		if course >= 0:
			show_course(course)
		elif i + 1 < Tutorial.LESSONS.size():
			show_lesson(i + 1)
		else:
			show_title())
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = Settings.time_i
	m.setup(m.lesson.config(Settings.p1_choice), "park", false)


## ONLINE (PORT-31): host or join; the match when it starts.
func show_online() -> void:
	save.save_game()
	var o := OnlineScreen.new().setup(save)
	o.leave.connect(show_title)
	o.play.connect(_on_online_match)
	_swap(o)


## An online match from the session's START: the host's court, time and
## colours on both machines. Its end (or the line's) goes to the title,
## saying why if the other side left.
func _on_online_match(session: OnlineSession) -> void:
	var info := session.start
	var m := MatchView.new()
	m.net = session
	m.finished.connect(func(_to_title: bool):
		var why := session.reason
		session.quit()
		show_title()
		if why != "":
			toast(why))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	var court: Array = info.get("court", Settings.court)
	m.court = court.map(func(x): return int(x))
	m.time = int(info.get("time", 0))
	m.setup(OnlineSession.config_from_dict(info["cfg"]), String(info.get("venue", "park")), false)


## A message in the toast (the controller toast's panel).
func toast(text: String) -> void:
	_toast_text.text = text
	_toast_text.tint = Color("ff7060")
	_toast_frames = TOAST_FRAMES
	_fit_toast()


## The toast's panel around its text (300 px at least).
func _fit_toast() -> void:
	var w := maxf(300.0, BitmapText.measure("small", _toast_text.text) + 40.0)
	_toast_panel.size.x = w
	_toast_panel.position.x = 480.0 - w / 2.0


## The update screen (PORT-34): a newer version downloads and restarts the
## game; up to date (or no way to update), on to the title.
func show_update() -> void:
	var u := UpdateScreen.new().setup(Updater.instance)
	u.done.connect(show_title)
	_swap(u)

