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
var _toast_queue: Array = []       ## achievements waiting for the toast
var _chime: AudioStreamPlayer      ## an achievement's sound
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
	add_child(Announcer.new())             # ADR-076: the voice, for the session
	Achievements.on_unlock = _on_achievement
	_chime = AudioStreamPlayer.new()
	_chime.stream = load(Sfx.DIR + "8_achievement.wav")
	_chime.volume_db = -4.0
	add_child(_chime)
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
	if _toast_frames <= 0 and not _toast_queue.is_empty():
		toast(_toast_queue.pop_front())
		_toast_text.tint = Color("fbe46a")
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
	t.open_trip.connect(func(): show_trip_home())
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
	m.setup(cfg, Settings.park_venue(), false)    # ADR-078: the location's venue


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


# --- ROAD TRIP (port ADR-087) ------------------------------------------------------

## ROAD TRIP's home; `ended`: the results of a trip that just ended.
func show_trip_home(ended: Dictionary = {}) -> void:
	save.save_game()
	var h := TripHome.new().setup(save, ended)
	h.leave.connect(show_title)
	h.start.connect(func(t: RoadTrip): show_trip_scene(t, RoadTrip.data()["scenes"]["start"],
		{"art": "garage"}, func(_c): show_trip_map(t)))
	h.resume.connect(show_trip_map)
	_swap(h)


func show_trip_map(t: RoadTrip) -> void:
	t.store(save)
	save.save_game()
	var m := TripMap.new().setup(save, t)
	m.leave.connect(func(): show_trip_home())
	m.go.connect(func(target: Array): _on_trip_go(t, target))
	_swap(m)


## You in a trip's scenes: the career player (or MATCH SETUP's 1P) in the
## trip's hat and paddle.
func _trip_me(t: RoadTrip) -> PlayerLook:
	var d := t.driver(save.career.active_player(), Settings.p1_choice)
	return PlayerLook.for_career(d, d.shirt, d.variant, d.paddle, MatchView.levels_manifest())


func _trip_me_name() -> String:
	var me := save.career.active_player()
	return me.shown_name() if me else "YOU"


func show_trip_scene(t: RoadTrip, pages: Array, opts: Dictionary, then: Callable) -> void:
	var s := TripScene.new().setup(t, pages, _trip_me(t), _trip_me_name(), opts)
	s.done.connect(then)
	_swap(s)


## A stop driven to (or a lost big match, again): what happens there.
func _on_trip_go(t: RoadTrip, target: Array) -> void:
	if not (t.is_gate() and int(target[0]) == RoadTrip.GATE):
		t.go(int(target[0]), int(target[1]))
	var n := t.here()
	t.store(save)
	save.save_game()
	var scenes: Dictionary = RoadTrip.data()["scenes"]
	match String(n["type"]):
		"pickup":
			_trip_match(t, n)
		"grudge", "big", "final":
			var team := int(n["team"])
			var pages: Array = scenes["teams"][team] if team >= 0 and team < scenes["teams"].size() else []
			var card_lines := ["VS " + RoadTrip.opponent_name(n)]
			var info := t.info(n)
			card_lines.append(String(info[1]))
			if String(info[2]).begins_with("TODAY:"):
				card_lines.append(String(info[2]).split("   ")[0])
			var over := "LEG %d: %s" % [t.leg() + 1, String(RoadTrip.leg_info(t.leg())["name"])]
			show_trip_scene(t, pages, {"venue": String(n["venue"]), "time": int(n["time"]), "team": team,
				"card": {"over": over, "title": RoadTrip.stop_name(n), "lines": card_lines}},
				func(_c): _trip_match(t, n))
		"yard":
			show_trip_scene(t, scenes["yard_sale"], {"art": "yard_sale"}, func(_c):
				t.offer_pick("yard", 0)
				t.finish_stop()
				show_trip_map(t))
		"shop":
			var shop := TripShop.new().setup(save, t)
			shop.leave.connect(func():
				t.finish_stop()
				show_trip_map(t))
			_swap(shop)
		"motel":
			var heal_ok := t.hearts < t.max_hearts
			show_trip_scene(t, scenes["motel"], {"art": "motel", "choices": [
				{"label": "SLEEP IT OFF: A HEART BACK", "enabled": heal_ok, "value": "" if heal_ok else "FULL"},
				{"label": "PARTNER PRACTISES: +1 EACH STAT", "enabled": true}]}, func(c: int):
					t.rest(c == 0)
					t.finish_stop()
					show_trip_map(t))
		"detour":
			var d := RoadTrip.detour(String(n["detour"]))
			var choices := t.detour_choices(d)
			show_trip_scene(t, [{"who": "narrator", "lines": d["lines"]}],
				{"art": String(d.get("art", "roadside")), "choices": choices}, func(c: int):
					t.choose(d, maxi(0, c))
					t.finish_stop()
					show_trip_map(t))
		_:
			t.finish_stop()
			show_trip_map(t)


## A stop's match. B on the result goes on (its result recorded in the
## trip); MENU leaves for ROAD TRIP's home, and leaving before the match
## is over counts as a loss.
func _trip_match(t: RoadTrip, n: Dictionary) -> void:
	var cfg := t.config_for(n, Settings.p1_choice, true, save.career.active_player())
	t.store(save)
	save.save_game()
	var m := MatchView.new()
	m.save = save
	m.trip = true
	if int(n.get("team", -1)) < 0:
		m.trip_name = RoadTrip.opponent_name(n)
	m.finished.connect(func(to_title: bool):
		var over := m.sim.phase == K.PHASE_MATCH_RESULT
		_after_trip_match(t, over and m.sim.match_winner == 0, to_title))
	_swap(m)
	m.camera.percent = Settings.CAMERAS[Settings.camera_i]
	m.court = Settings.court.duplicate()
	m.time = int(n.get("time", CourtStyle.DAY))
	m.setup(cfg, String(n["venue"]), false)


func _after_trip_match(t: RoadTrip, won: bool, leave: bool) -> void:
	t.record_match(won)
	var scenes: Dictionary = RoadTrip.data()["scenes"]
	if t.state == "won":
		show_trip_scene(t, scenes["won"], {"art": "summer_open"}, func(_c): _end_trip(t))
	elif t.state == "over":
		show_trip_scene(t, scenes["over"], {"art": "roadside"}, func(_c): _end_trip(t))
	elif leave:
		t.store(save)
		show_trip_home()
	else:
		show_trip_map(t)


## The trip's end: its miles to the GARAGE, then the results at home.
func _end_trip(t: RoadTrip) -> void:
	var heat_before := int(RoadTrip.meta(save)["heat"])
	var steps := t.finish(save)
	save.save_game()
	var heat_now := int(RoadTrip.meta(save)["heat"])
	show_trip_home({"won": t.state == "won", "leg": t.leg() + 1, "wins": t.wins, "losses": t.losses,
		"stops": t.stops, "miles": t.miles, "steps": steps,
		"heat_open": heat_now if heat_now > heat_before else -1})


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
			if StoryMode.win(save, ch):
				Achievements.unlock(save, "park_saved")    # ADR-077
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


## ADR-077: an achievement unlocked, as a toast (several wait their turn)
## and its chime.
func _on_achievement(id: String) -> void:
	_toast_queue.append("ACHIEVEMENT: " + String(Achievements.entry(id)[1]))
	if _chime and Sfx.setting != AudioMap.SOUND_OFF:
		_chime.play()
	# the announcer says so, after the result's line (its own, else a general
	# one; the second batch, PORT-55: nothing until it's recorded)
	if not Announcer.speak("achievement_" + id, Announcer.TOP, 4.0):
		Announcer.speak("achievement", Announcer.TOP, 4.0)


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

