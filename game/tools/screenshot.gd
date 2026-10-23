## Renders a screen for N frames and saves the viewport (needs a display):
##   godot --path game -s res://tools/screenshot.gd -- <title|title_<page>|singles|doubles|demo|practice|practice_<zone>> <venue> <frames> <out.png> [human] [opp=N]
## "human" leaves P1 human (it serves on its own after the ready delay is
## not automatic, so the default makes P1 a bot for a moving picture).
## "opp=N" plays ladder team N (0-based) in their looks; "mods=N" sets
## the MOD_* bits. "title_options"
## (any page id) opens that title page; "court=S,K,R,L" sets the court
## colour presets; "time=N" DAY 0, DUSK 1, NIGHT 2;
## "meterfull" keeps P1's SPECIALS meter full (with mods=131072), "picklesmash" shoots a PICKLE SMASH;
## "camflash" a burst of the crowd's camera flashes (PORT-66);
## "pad" shows the controller prompts; "save" a save with records (title); "pause" pauses the match at the end; "tune" opens the tuning panel; "debug" the F3 overlay (hit volumes); "location=N" OPEN PLAY's location; "potm" a bot match to its PLAY OF THE MATCH ("potmsave" presses its SAVE); "nearreach" a near-side reach mid-step;
## "closecall" shows a forced close-up; "initials" the initials card;
## "result" plays a bot match and ends it (the stats card); "mp4" four
## humans on fake pads (doubles); title_lobby a lobby with three players.
## `smash`: the first overhead after half the frames, just after contact.
## "park" the open play park (ADR-034), you stacked at court 2's rack;
## "park_house" in the clubhouse at the records board; "park_call" your
## game called. "partner=N" puts ladder team N's captain on slot 1.
## "park_locked" a career player at 10 points at the CLUB court's rack;
## "park_pick" one who has beaten the ladder, picking a partner at the
## ROOKIE rack (SNES ADR-070, 072).
## "career" (ADR-047) plays as a scratch career player (ACE: green, pink
## hair, a visor) in a match, the park, or on title_career,
## title_career_card, title_career_edit and title_career_name (and
## title_career_museum: the HAT MUSEUM, half the hats won); "unlock"
## shows the UNLOCKED! card at the end of a match.
## "story<ch>_<kind>_<page>" a story scene (PORT-44); "course..." PICKLEBALL 101 (PORT-45).
## title_notice: the startup card about controllers; title_padmap: MAP
## BUTTONS halfway through a generic pad; title_pad: CONTROLLER (port ADR-082).
## "replays" (PORT-69) keeps saved replays in user://shot_replays/, not the
## player's: "savelast" there saves the last rally (and shows it SAVED on
## the pause menu, with "pause"); title_replays lists them, "watch" plays
## the newest from REPLAYS.
extends SceneTree

var _frames := 0
var _target := 120
var _out := "user://shot.png"
var _view: Node


## A scratch save with a career player (nothing is written).
static func _career_save() -> SaveGame:
	var sv := SaveGame.new()
	sv.dir = "user://shot_save/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sv.dir))
	sv.data = SaveGame.defaults()
	sv.career = Career.new()
	sv.career.create(0, "ACE")
	sv.career.create(2, "GRANDPA")
	var p: Career.Player = sv.career.players[0]
	p.unlocked = (1 << 0) | (1 << 5) | (1 << 3)        # VISOR, PINK HAIR, TRICORN
	p.hair = 6
	p.hat = 1
	p.skin = 1
	p.shirt = PlayerSelect.PAL_GREEN
	p.variant = K.VARIANT_FEMALE
	p.paddle = Paddles.RED
	p.wins = [23, 9]
	p.losses = [11, 6]
	p.aces = 14
	p.shutouts = 2
	p.best_streak = 4
	p.longest_rally = 17
	p.beaten[3] = 1
	sv.career.players[2].wins = [3, 0]
	sv.career.select(0)
	return sv


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mode: String = a[0] if a.size() > 0 else "singles"
	var venue: String = a[1] if a.size() > 1 else "park"
	_target = int(a[2]) if a.size() > 2 else 120
	_out = a[3] if a.size() > 3 else "user://shot.png"
	if "replays" in a.slice(4):
		SavedReplays.dir = "user://shot_replays/"
	for arg in a.slice(4):
		if arg == "pad":
			GameControls.last_device = GameControls.PAD
		if arg.begins_with("update="):          # PORT-32: a stand-in updater in this state
			var u := Updater.new()
			Updater.instance = u
			u.state = int(arg.substr(7))
			u.latest = "0.9.0"
		if arg.begins_with("icons="):           # PORT-28: 1 XBOX, 2 PLAYSTATION, 3 NINTENDO, 4 SNES
			Settings.pad_glyphs = int(arg.substr(6))
		if arg.begins_with("location="):        # ADR-078: OPEN PLAY's location (0 park, 1 dino, 2 gym)
			Settings.park_i = int(arg.substr(9))
		if arg.begins_with("time="):
			Settings.time_i = int(arg.substr(5))
		if arg.begins_with("court="):
			Settings.court = Array(arg.substr(6).split(",")).map(func(x): return int(x))
	var controls = load("res://game_ui/controls.gd").new()
	root.add_child(controls)
	TitleScreen.notice_done = mode != "title_notice"    # port ADR-082: the startup card
	if mode.begins_with("park"):
		var op := OpenPlay.new()
		op.begin(4242, false)
		for f in 400:                       # the games get going
			op.update(0, 0, false)
		op.x_fp = K.to_fp(OpenPlay.rack_x(1))
		op.y_fp = K.to_fp(OpenPlay.RACK_Y + 2)
		op.update(0, 0, true)
		if mode == "park_house":
			op.x_fp = K.to_fp(OpenPlay.BOARD_X + 4)
			op.y_fp = K.to_fp(OpenPlay.BOARD_Y + 6)
			op.update(0, 0, true)
		elif mode == "park_call":
			op.x_fp = K.to_fp(OpenPlay.START_X + 20)
			op.y_fp = K.to_fp(OpenPlay.START_Y)
			while op.called == OpenPlay.NONE:
				op.update(0, 0, false)
		elif mode == "park":
			op.x_fp = K.to_fp(OpenPlay.rack_x(1) + 30)
			op.y_fp = K.to_fp(OpenPlay.RACK_Y + 14)
		var sv: SaveGame = _career_save() if "career" in a.slice(4) or mode in ["park_locked", "park_pick"] \
			else null
		if mode == "park_locked":
			op.update(0, 0, true)           # your paddle back: you stand at the rack
		elif mode == "park_pick":
			op.update(0, 0, true)
			op.x_fp = K.to_fp(OpenPlay.rack_x(0))
			op.update(0, 0, true)
			for t in Career.TEAMS:
				sv.career.active_player().beaten[t] = 1
		var pv := ParkView.new().setup(op, sv, false)
		if mode == "park_pick":
			op.pick_next()
			op.pick_next()
		root.add_child(pv)
		_view = pv
	elif mode == "update":
		# PORT-34: the update screen in update=<state> (a stand-in updater)
		var u := Updater.instance if Updater.instance else Updater.new()
		u.manifest = {"size": 24156944}
		u.error = "THE DOWNLOAD WAS DAMAGED: TRY AGAIN"
		var us := UpdateScreen.new().setup(u)
		root.add_child(us)
		if not us.is_node_ready():
			us._ready()
		us.refresh()
		_view = us
	elif mode.begins_with("online"):
		# PORT-31: online (idle, an address typed), online_host (waiting),
		# online_connected (as host, a friend in)
		var o := OnlineScreen.new().setup(null)
		o.port = ENetLink.PORT + 11
		o.address = "100.101.12.7"
		root.add_child(o)
		if not o.is_node_ready():
			o._ready()
		if mode != "online":
			o.page.select("host")
			o.page.press()
		if mode == "online_connected":
			o.session.state = OnlineSession.CONNECTED
			o.session.peer_hello = {"name": "BO"}
		_view = o
	elif mode.begins_with("lesson"):
		# PORT-30: lesson<N> (the card) or lesson<N>_play (the banner, advice up)
		var m := MatchView.new()
		m.lesson = Tutorial.new(int(mode.substr(6, 1)))
		root.add_child(m)
		m.setup(m.lesson.config({}), venue, false)
		if mode.ends_with("_play"):
			m.lesson_view.card_frames = -1
			m.lesson.progress = 1
			m.lesson.message = "NO VOLLEYS FROM THE KITCHEN: STEP BACK."
			m.lesson.message_frames = 9999
			m.lesson_view.refresh()
		_view = m
	elif mode.begins_with("bracket"):
		# PORT-25: bracket (a fresh draw), bracket_semi (your quarterfinal
		# won), bracket_out (out in the semifinal), bracket_won (champions)
		var sv := SaveGame.new()
		sv.data = SaveGame.defaults()
		sv.career = Career.from_dict(sv.data["career"])
		var couch := "couch" in a.slice(4)    # PORT-29: P1 + P2 and P3 + P4 (doubles), or four players
		var lob := Lobby.new()
		for d in 4:
			lob.join(d)
		lob.cup = true
		lob.set_mode(K.MODE_DOUBLES if "doubles" in a.slice(4) else K.MODE_SINGLES)
		var tour := Tournament.create(1994, "doubles" in a.slice(4), K.DIFFICULTY_MEDIUM, 11,
			lob.entries() if couch else [])
		if mode != "bracket":
			tour.record(true, 11, 6)
		if mode == "bracket_out":
			tour.record(false, 8, 11)
		elif mode == "bracket_won":
			tour.record(true, 11, 9)
			tour.record(true, 12, 10)
		if mode != "bracket" or couch:
			tour.seen = 99
			sv.store_tournament(tour, "couch" if couch else "bracket")
		var bs := BracketScreen.new().setup(sv, false, couch)
		bs.save = null                      # nothing written
		root.add_child(bs)
		_view = bs
	elif mode.begins_with("course"):
		# PORT-45: course (the list, cursor on lesson N with "at=N"),
		# course<lesson>_<page> (a page), course<lesson>_<page>_<choice> (a
		# quiz, answered)
		var parts := mode.split("_")
		var cs := CourseScreen.new().setup(null, int(parts[0].substr(6)) if parts.size() > 1 else -1)
		root.add_child(cs)
		if not cs.is_node_ready():
			cs._ready()
		if parts.size() > 1:
			for k in int(parts[1]):
				if Course.is_quiz(cs._page()):
					cs.answer(int(cs._page()["answer"]))
				cs.next_page()
			if parts.size() > 2:
				cs.answer(int(parts[2]))
		for arg in a.slice(4):
			if arg.begins_with("at="):
				cs.list.cursor = int(arg.substr(3))
				cs.list.refresh()
				cs._show_preview()
		_view = cs
	elif mode.begins_with("story"):
		# PORT-44: story<chapter>_<intro|win|lose|ending>_<page>, e.g.
		# story3_intro_0 (the chapter card), story0_intro_1 (a letter)
		var parts := mode.split("_")
		var ch := int(parts[0].substr(5))
		var sc := StoryScene.new().setup(null, ch, parts[1] if parts.size() > 1 else "intro",
			PlayerLook.for_team(0, 0, 0, MatchView.levels_manifest()))
		root.add_child(sc)
		sc.page = int(parts[2]) if parts.size() > 2 else 0
		sc._show_page()
		_view = sc
	elif mode.begins_with("title"):
		Settings.venue_i = maxi(0, Settings.VENUES.find(venue))
		_view = TitleScreen.new()
		if "save" in a.slice(4):
			# a scratch save with records, so the RECORD line shows
			var sv := SaveGame.new()
			sv.dir = "user://shot_save/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sv.dir))
			sv.data = SaveGame.defaults()
			sv.data["records"]["singles_wins"] = 12
			sv.data["records"]["singles_losses"] = 7
			_view.save = sv
		if mode.begins_with("title_career") or "career" in a.slice(4):
			_view.save = _career_save()
		root.add_child(_view)
		if mode.begins_with("title_"):
			_view.ready.connect(func():
				if mode == "title_lobby":
					# three fake pads: P1 ready on the left, P2 picking, P3 on the right
					GameControls.fake_pads = {0: {"buttons": []}, 1: {"buttons": []}, 2: {"buttons": []}}
					_view.open_lobby()
					var l: Lobby = _view.lobby
					l.join(0)
					l.join(1)
					l.join(2)
					l.cards[0]["ready"] = true
					l.cards[1]["row"] = Lobby.ROW_PADDLE
					l.cards[1]["paddle"] = Paddles.RED
					l.cards[1]["variant"] = K.VARIANT_FEMALE
					l.cards[2]["palette"] = 3
				elif mode == "title_select":
					_view.open_select(false)
					_view.select_input(PlayerSelect.PAD_DOWN)
					_view.select_input(PlayerSelect.PAD_RIGHT)    # RED
					_view.select_input(PlayerSelect.PAD_DOWN)
					_view.select_input(PlayerSelect.PAD_LEFT)     # WOOD
					_view.select.choice[0]["variant"] = K.VARIANT_FEMALE
					_view.select_screen.refresh()
				elif mode == "title_padmap":
					# port ADR-082: a generic pad halfway through MAP BUTTONS (D-pad
					# on axes, faces as buttons)
					var t: TitleScreen = _view
					t.reveal_page("pad")
					t.pad_mapper.begin(7, "03000000790000001100000000000000", "USB Gamepad")
					for ev in [[1, -1.0], [1, 0.0], [1, 1.0], [1, 0.0], [0, -1.0], [0, 0.0], [0, 1.0],
							[0, 0.0], [2], [1]]:
						var e: InputEvent
						if ev.size() == 2:
							e = InputEventJoypadMotion.new()
							e.axis = ev[0]
							e.axis_value = ev[1]
						else:
							e = InputEventJoypadButton.new()
							e.button_index = ev[0]
							e.pressed = true
						e.device = 7
						t.pad_mapper.feed(e)
					t._show("padmap")
					t.pad_map_screen.refresh()
				elif mode.begins_with("title_career"):
					var t: TitleScreen = _view
					t.open_career()
					if mode != "title_career":
						t.pages["career"].press()                  # ACE: the card
					if mode in ["title_career_edit", "title_career_name"]:
						t.pages["career_card"].select("edit")
						t.pages["career_card"].press()
						t.pages["career_edit"].select("hat")
					if mode == "title_career_museum":
						var me: Career.Player = t.save.career.players[0]
						for u in ["BEANIE", "BUCKET", "WHIRLY", "VIKING"]:
							me.unlocked |= 1 << Career.unlock_names.find(u)
						me.hat = Career.hat_names.find("WHIRLY")
						t.pages["career_card"].select("hats")
						t.pages["career_card"].press()
						t.museum_input(Practice.PAD_RIGHT)
					if mode == "title_career_name":
						t.pages["career_edit"].select("name")
						t.pages["career_edit"].press()
						t.career_page.pick_key(14)
						t.career_keyboard.refresh()
				else:
					_view.reveal_page(mode.substr(6)))
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
		if "mp4" in a.slice(4):
			# four humans (fake pads), tags over each
			GameControls.fake_pads = {0: {"buttons": []}, 1: {"buttons": []}, 2: {"buttons": []},
				3: {"buttons": []}}
			var l := Lobby.new()
			for d in 4:
				l.join(d)
			cfg = l.match_config(K.DIFFICULTY_MEDIUM, 11, 0)
			m.slot_pads = l.slot_pads()
			m.slot_players = l.slot_players()
		for arg in a.slice(4):
			if arg.begins_with("opp="):
				cfg = Settings.config_for(mode == "doubles", int(arg.substr(4)),
					cfg.difficulty, cfg.points_to_win)
		for arg in a.slice(4):
			if arg.begins_with("partner="):
				cfg.set_partner(int(arg.substr(8)))
			if arg.begins_with("mods="):
				cfg.modifiers = int(arg.substr(5))         # MOD_* bits (GLOW 128, INVERSE 256)
		if "career" in a.slice(4):
			m.save = _career_save()
			cfg.set_career(m.save.career.active_player())
			cfg.palette[0] = PlayerSelect.PAL_GREEN
			cfg.paddle[0] = Paddles.RED
			cfg.variant[0] = K.VARIANT_FEMALE
			for slot in range(1, K.MAX_PLAYERS):
				if cfg.palette[slot] == PlayerSelect.PAL_GREEN:
					cfg.palette[slot] = PlayerSelect.PAL_BLUE
		m.court = Settings.court.duplicate()
		m.time = Settings.time_i
		if "potm" in a.slice(4):
			cfg = Settings.config_for(mode == "doubles", 2, K.DIFFICULTY_MEDIUM, 5)
		m.setup(cfg, venue, mode == "demo")
		if mode != "demo" and not "human" in a.slice(4):
			m.sim.p1_bot = true
		if "nearreach" in a.slice(4):
			# KNOWN_ISSUES #69: run until a near-side reach has stepped down
			m.card_frames = -1
			for f in 60 * 60 * 5:
				m._physics_process(1.0 / 60.0)
				var hit := false
				for i in K.MAX_PLAYERS:
					hit = hit or float(m._players[i].get("lean", 0.0)) >= 10.0
				if hit:
					break
		if "potm" in a.slice(4):
			# PORT-51: a short bot match to its PLAY OF THE MATCH, near the
			# rally's end (potm_title: the title card, still catching up)
			m.card_frames = -1
			for f in 60 * 60 * 15:
				m._physics_process(1.0 / 60.0)
				var h := m.highlight
				if h and h.playing() and ("potm_title" in a.slice(4) or (h._state == "play"
						and h._frame >= int(h.best["to"]) - 12)):
					break
			if "potmsave" in a.slice(4) and m.highlight and m.highlight.playing():
				m.highlight.on_save()        # PORT-70: its SAVE (with "replays": not the player's)
		_view = m
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	# (not with "replays": a press put in the sim isn't in the recording)
	if _view is MatchView and _view.sim.p1_bot and not (_view.highlight and _view.highlight.playing()) \
			and not "replays" in OS.get_cmdline_user_args() \
			and _view.sim.phase == K.PHASE_SERVE_SETUP \
			and _view.sim.server_index == 0 and _frames % 32 == 0:
		# the bot presses B to serve, like the test harness
		_view.sim.intents[0].hit_pressed = 1
		_view.sim.serve_requested = 1
	if _frames == _target - 12 and _view is MatchView and "savelast" in OS.get_cmdline_user_args():
		print("saved the last rally: ", _view.save_rally())
	if _frames == _target - 10 and _view is MatchView and "pause" in OS.get_cmdline_user_args():
		_view.sim.paused = 1
	if _frames == 10 and _view is TitleScreen and "watch" in OS.get_cmdline_user_args():
		_view.replay_press(0)
	if _frames == 2 and _view is MatchView and "debug" in OS.get_cmdline_user_args():
		_view._debug.visible = true        # F3: positions, hit volumes, landing marks
	if _frames == _target - 20 and _view is MatchView and "tune" in OS.get_cmdline_user_args():
		_view.tuning.open_panel()         # PORT-49: the tuning panel, slid in
	if _frames == _target - 50 and _view is MatchView and "closecall" in OS.get_cmdline_user_args():
		# a forced close call (display only): 1.25 px past the right baseline
		var v: MatchView = _view
		v.sim.ball.x_fp = K.to_fp(K.COURT_BASELINE_RIGHT) + 20
		v.sim.ball.y_fp = K.to_fp(150)
		v.close_call = CloseCall.new().setup(v, Replay.check(v.sim.ball.x_fp, v.sim.ball.y_fp,
			Replay.MIN_SHOTS, K.FAULT_OUT))
		v._hud.add_child(v.close_call)
		for i in 70:                   # past the drop and the bounce
			v.close_call.update()
	if _frames == _target - 20 and _view is MatchView and "initials" in OS.get_cmdline_user_args():
		# the initials card over a forced record (nothing is written)
		var v: MatchView = _view
		v.save = SaveGame.new()
		v.save.data = SaveGame.defaults()
		v.save.data["records"]["best_streak"] = 5
		v.save.data["records"]["longest_rally"] = 14
		v.save.new_records = SaveGame.NEW_STREAK | SaveGame.NEW_RALLY
		v.initials.begin(v.save)
		v.initials.letters = [0, 1, 4]
		v.initials.cursor = 2
	if _frames == 2 and _view is MatchView and "result" in OS.get_cmdline_user_args():
		# play ~70 s of bot match, then end it (P1 wins): the stats card
		var v: MatchView = _view
		for f in 4200:
			if v.sim.phase == K.PHASE_SERVE_SETUP and v.sim.server_index == 0:
				v.sim.serve_requested = 1
			v._physics_process(1.0 / 60.0)
			if v.sim.phase == K.PHASE_MATCH_RESULT:
				break
		if v.sim.phase != K.PHASE_MATCH_RESULT:
			v.sim.team_score[0] = maxi(v.sim.team_score[0], v.sim.config.points_to_win - 1)
			v.sim.team_score[1] = mini(v.sim.team_score[1], v.sim.team_score[0] - 1)
			v.sim.phase = K.PHASE_LIVE
			v.sim.ball.rally_state = K.BALL_RALLY_LIVE
			v.sim.resolve_point(1, K.FAULT_OUT)
		for f in K.POINT_RESULT_FRAMES + 40:
			v._physics_process(1.0 / 60.0)
	if _frames == _target - 20 and _view is MatchView and "unlock" in OS.get_cmdline_user_args():
		# the UNLOCKED! card over a won match (nothing is written)
		var v: MatchView = _view
		v.sim.phase = K.PHASE_MATCH_RESULT
		v.sim.match_winner = 0
		v.save.career.new_unlocks = (1 << 0) | (1 << 3) | (1 << 5)
		v.unlock_frames = 0
	if _view is MatchView and "smash" in OS.get_cmdline_user_args() and _target > _frames + 6:
		# the first overhead after <frames>/2: shoot 4 frames after its contact
		for pl in _view.sim.players:
			if _frames > _target / 2 and pl.shot_type == K.SHOT_OVERHEAD and pl.contact_consumed \
					and pl.state == K.STATE_ACTIVE:
				_target = _frames + 4
	if _view is MatchView and "meterfull" in OS.get_cmdline_user_args() and _view.sim.specials_on():
		# SPECIALS (port ADR-080): P1's meter kept full, so the prompt shows
		# and the bot plays PICKLE SMASH; "picklesmash" shoots 4 frames after
		# the first one past <frames>/2
		_view.sim.meter[0] = K.SPECIAL_METER_MAX
		for pl in _view.sim.players:
			if "picklesmash" in OS.get_cmdline_user_args() and _frames > _target / 2 \
					and pl.shot_type == K.SHOT_SPECIAL and pl.contact_consumed and pl.state == K.STATE_ACTIVE \
					and _target > _frames + 6:
				_target = _frames + 4
	if _frames == _target - 12 and _view is MatchView and "camflash" in OS.get_cmdline_user_args():
		_view.effects.flash(CourtEffects.FLASH_BURST)     # PORT-66: the stands' camera flashes
	if _frames == _target - 3 and _view is MatchView and "score10" in OS.get_cmdline_user_args():
		_view.sim.team_score = [10, 10]
	if _frames >= _target:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit()
