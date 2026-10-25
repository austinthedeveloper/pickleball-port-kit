## Text layout: on every screen, no two pieces of visible text overlap
## and none leaves the 960x540 screen. Pages are checked with every value
## of every row (the longest names included), and Player Select, the
## lobby, the HUD's states and the park with theirs. A failure names both
## texts and where they are.
extends TestSuite

const SCREEN := Rect2(0, 0, 960, 540)
const SLACK := 1.0               ## px of touching allowed
## A panel's frame: text inside stays this far in (glyph boxes carry their
## outline, so less is needed top and bottom).
const PANEL_EDGE_X := 6.0
const PANEL_EDGE_Y := 2.0

var _seen := {}                  ## failure messages already reported


## The screen-space box of a BitmapText (scale and alignment included).
static func text_rect(t: BitmapText) -> Rect2:
	var xf := t.get_global_transform()
	var s := xf.get_scale()
	var w := BitmapText.measure(t.font, t.text, t.spacing) * s.x
	var h := t.height() * s.y
	var origin := xf.origin
	return Rect2(origin.x - w * t.align, origin.y, w, h)


static func _shown(n: Node) -> bool:
	var c: Node = n
	while c != null:
		if c is CanvasItem and not c.visible:
			return false
		if c is CanvasLayer and not c.visible:
			return false
		c = c.get_parent()
	return true


static func texts(root: Node) -> Array:
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BitmapText and n.text.strip_edges() != "" and _shown(n) and n.modulate.a > 0.05:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## Checks a screen; `where` says which state it was in.
func check_layout(root: Node, where: String) -> void:
	var ts := texts(root)
	var rects := ts.map(func(t): return text_rect(t))
	var panels := []
	var stack := [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is NinePatchRect and _shown(n):
			panels.append(Rect2(n.get_global_transform().origin, n.size))
		for c in n.get_children():
			stack.append(c)
	for pr in panels:                    # every panel on the screen, edges and all
		if not SCREEN.grow(SLACK).encloses(pr):
			_fail("%s: a panel leaves the screen: %s" % [where, pr], "panel|%s" % pr)
	for i in ts.size():
		var r: Rect2 = rects[i]
		for pr in panels:
			# inside a panel means clear of its frame; otherwise fully outside it
			if r.intersects(pr.grow(-SLACK)) and not pr.grow_individual(-PANEL_EDGE_X, -PANEL_EDGE_Y,
					-PANEL_EDGE_X, -PANEL_EDGE_Y).encloses(r):
				_fail("%s: \"%s\" %s crosses a panel's edge %s" % [where, ts[i].text,
					r.position.round(), pr], ts[i].text + "|edge")
				break
		# every character has a glyph (the fonts: caps, digits, !?.,:-'/%+)
		var chars := String(BitmapText.load_font(ts[i].font)["chars"])
		for c in ts[i].text:
			if c != " " and not chars.contains(c):
				_fail("%s: \"%s\" has a character the font can't draw: '%s'" % [where, ts[i].text, c],
					ts[i].text + "|glyph")
				break
		if not SCREEN.grow(SLACK).encloses(r):
			_fail("%s: \"%s\" leaves the screen at %s" % [where, ts[i].text, r], ts[i].text)
		for j in range(i + 1, ts.size()):
			var q: Rect2 = rects[j]
			if r.grow(-SLACK).intersects(q.grow(-SLACK)):
				_fail("%s: \"%s\" %s overlaps \"%s\" %s" % [where, ts[i].text, r.position.round(),
					ts[j].text, q.position.round()], ts[i].text + "|" + ts[j].text)
	asserts += 1


## Reports each overlapping pair once (the first state it shows up in).
func _fail(msg: String, key: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	runner.fail(msg)


func _save() -> SaveGame:
	var s := fresh_save("user://test_layout/")
	# big numbers and holders, so the record lines are at their widest
	var r: Dictionary = s.data["records"]
	for k in ["singles_wins", "singles_losses", "doubles_wins", "doubles_losses", "points_won",
			"points_lost", "longest_rally", "best_streak", "practice_best", "shutouts", "aces",
			"winners", "ladder_clears", "cups"]:
		r[k] = 188
	s.data["initials"] = {"best_streak": "WWW", "longest_rally": "MMM"}
	return s


func _title() -> TitleScreen:
	return title_screen(_save())


## Every title page, with every value of every row.
func test_title_pages() -> void:
	var kept := [Settings.venue_i, Settings.difficulty_i, Settings.points_i, Settings.opponent_i,
		Settings.court.duplicate(), Settings.time_i, Settings.camera_i, Sfx.setting]
	var t := _title()
	for id in t.pages:
		t._show(id)
		var p: MenuPage = t.pages[id]
		p.settle()
		check_layout(t, "title %s" % id)
		for row in p.rows:
			if not row.has("change") or row["id"] in ["fullscreen", "scale", "vibration"]:
				continue
			p.select(row["id"])
			for k in 24:                       # every value (the longest lists have 14)
				p.change(1)
				p.settle()
				check_layout(t, "title %s / %s = %s" % [id, row["id"], p.value_of(row["id"])])
	t._show("practice")
	check_layout(t, "title practice")
	t.free()
	Settings.venue_i = kept[0]
	Settings.difficulty_i = kept[1]
	Settings.points_i = kept[2]
	Settings.opponent_i = kept[3]
	Settings.court = kept[4]
	Settings.time_i = kept[5]
	Settings.camera_i = kept[6]
	Sfx.setting = kept[7]


## The lite (Web) build's title (port ADR-089): MAIN without ROAD TRIP,
## OPTIONS without the announcer's rows.
func test_lite_title() -> void:
	var kept := Settings.lite
	Settings.lite = true
	var t := _title()
	for id in ["main", "options", "court"]:
		t._show(id)
		t.pages[id].settle()
		check_layout(t, "lite title %s" % id)
	t.free()
	Settings.lite = kept


func test_player_select() -> void:
	var t := _title()
	t.open_select(true)
	var s := t.select
	for variant in [K.VARIANT_MALE, K.VARIANT_FEMALE]:
		for paddle in Paddles.NAMES.size():
			for colour in 4:
				s.choice[0] = PlayerSelect.new_choice(colour, variant, paddle)
				for row in PlayerSelect.ROWS:
					s.row = row
					t.select_screen.refresh()
					check_layout(t, "select v%d p%d c%d row %d" % [variant, paddle, colour, row])
	t.free()


func test_lobby() -> void:
	GameControls.fake_pads = {0: {}, 1: {}, 2: {}, 3: {}}
	var t := _title()
	t.open_lobby()
	var l := t.lobby
	check_layout(t, "lobby empty")
	for d in 4:
		l.join(d)
	for mode in [K.MODE_SINGLES, K.MODE_DOUBLES]:
		l.set_mode(mode)
		for variant in [K.VARIANT_MALE, K.VARIANT_FEMALE]:
			for paddle in Paddles.NAMES.size():
				for i in 4:
					l.cards[i]["variant"] = variant
					l.cards[i]["paddle"] = paddle
					l.cards[i]["side"] = Lobby.LEFT if i % 2 == 0 else Lobby.RIGHT
					l.cards[i]["ready"] = paddle % 2 == 1
				t.lobby_screen.refresh()
				check_layout(t, "lobby m%d v%d p%d" % [mode, variant, paddle])
	t.free()
	GameControls.fake_pads = {}


func _view(cfg: SimTypes.MatchConfig, venue := "park", time := CourtStyle.DAY) -> MatchView:
	var v := MatchView.new()
	v.save = _save()
	v.time = time
	runner.root.add_child(v)
	v.setup(cfg, venue, false)
	v._hud.refresh()
	return v


## Every venue at every time (ADR-046's three too): a singles match
## against the venue's home team, the watcher out, the scores and a quip.
func test_every_venue() -> void:
	for venue in Settings.VENUES:
		var home := range(Opponents.count()).filter(func(o): return Settings.home_venue(o) == venue)
		var opp: int = home[0] if home.size() > 0 else -1
		for t in CourtStyle.time_names().size():
			var v := _view(Settings.config_for(false, opp, K.DIFFICULTY_MEDIUM, 11), venue, t)
			var tag := "%s %s vs %d" % [venue, CourtStyle.time_names()[t], opp]
			check_layout(v, tag)
			v.sim.team_score = [10, 9]
			v._hud.show_quip("WHAT A SHOT THAT WAS", Color.WHITE)
			v._hud.refresh()
			check_layout(v, tag + " quip")
			v.free()


## The HUD in its states, against every ladder team (the longest names)
## and Dale Dawson (his card, and his name alone in doubles).
func test_hud() -> void:
	for opp in range(-1, Opponents.DAWSON + 1):
		for doubles in [false, true]:
			var v := _view(Settings.config_for(doubles, opp, K.DIFFICULTY_MEDIUM, 11))
			var tag := "hud %s vs %d" % ["doubles" if doubles else "singles", opp]
			check_layout(v, tag)
			if v.card_frames >= 0:
				# Dale's intro card (it's modal: dismissed before play)
				v.card_frames = -1
				v._hud.close_card()
				check_layout(v, tag + " card closed")
			v.sim.team_score = [10, 9]
			v._hud.refresh()
			check_layout(v, tag + " match point")
			v.sim.paused = 1
			v._update_visuals()
			check_layout(v, tag + " paused")
			if v.highlight:                      # PORT-69: SAVE LAST RALLY at its widest
				v.highlight.last = {"shots": 188}
				v._hud.pause_menu.refresh()
				check_layout(v, tag + " paused, a rally to save")
				v.highlight.last = {}
			v.sim.paused = 0
			v.sim.phase = K.PHASE_POINT_RESULT
			v.sim.point_winner = 0
			v.sim.last_fault = K.FAULT_SECOND_BOUNCE
			v._hud.on_point(0)
			v._hud.show_quip("WHAT A SHOT THAT WAS", Color.WHITE)
			v._hud.refresh()
			check_layout(v, tag + " point result")
			v.sim.phase = K.PHASE_MATCH_RESULT
			v.sim.match_winner = 0
			v.sim.phase_timer = 999
			v._hud.refresh()
			check_layout(v, tag + " result with stats")
			v.free()
	var v := _view(SimTypes.MatchConfig.singles())
	v.save.new_records = SaveGame.NEW_STREAK | SaveGame.NEW_RALLY
	v.initials.begin(v.save)
	v._hud.refresh()
	check_layout(v, "hud initials")
	v.free()
	var p := _view(SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 40))
	check_layout(p, "hud practice")
	p.free()
	# SPECIALS (port ADR-080): the meters full, the prompts up, at match point
	for doubles in [false, true]:
		var cfg := Settings.config_for(doubles, -1, K.DIFFICULTY_MEDIUM, 11)
		cfg.modifiers |= K.MOD_SPECIALS
		cfg.human[2] = 1                      # both sides' prompts
		var sv := _view(cfg)
		sv.sim.meter = [K.SPECIAL_METER_MAX, K.SPECIAL_METER_MAX, K.SPECIAL_METER_MAX, K.SPECIAL_METER_MAX]
		sv.sim.phase = K.PHASE_LIVE
		sv.sim.team_score = [10, 10]
		sv._hud.refresh()
		check(sv._hud.specials.prompts[0].visible, "the PICKLE SMASH prompt is up")
		check_layout(sv, "hud specials %s" % ("doubles" if doubles else "singles"))
		# ADR-080 (PORT-68): the bars ride under the feet; with the players at the
		# corners of their runoff (the nearest the bottom texts) and at the
		# net, no bar meets a text or leaves the screen
		for spot in [[K.PLAYER_CLAMP_MIN_X, K.PLAYER_RIGHT_CLAMP_MAX_X, K.PLAYER_CLAMP_MAX_Y],
				[K.PLAYER_CLAMP_MIN_X, K.PLAYER_RIGHT_CLAMP_MAX_X, K.PLAYER_CLAMP_MIN_Y],
				[K.PLAYER_CLAMP_MAX_X, K.PLAYER_RIGHT_CLAMP_MIN_X, K.PLAYER_CLAMP_MAX_Y]]:
			for slot in K.MAX_PLAYERS:
				var pl: SimTypes.Player = sv.sim.players[slot]
				pl.x_fp = K.to_fp(spot[0] if pl.team == 0 else spot[1])
				pl.y_fp = K.to_fp(spot[2] - (slot % 2) * 30)
			sv._update_visuals()
			sv._hud.refresh()
			_check_meters(sv, "hud specials %s at %s" % ["doubles" if doubles else "singles", spot])
		sv.free()


## SPECIALS' bars (ADR-080, PORT-68): each shown one on screen and clear of every text.
func _check_meters(v: MatchView, where: String) -> void:
	var m: SpecialMeters = v._hud.specials
	var rects := texts(v).map(func(t): return text_rect(t))
	var ts := texts(v)
	for slot in K.MAX_PLAYERS:
		if not m.shown(slot):
			continue
		var r := m.bar(slot).grow(1)
		if not SCREEN.encloses(r):
			_fail("%s: slot %d's meter leaves the screen at %s" % [where, slot, r], "meter|screen")
		for i in ts.size():
			if r.intersects(rects[i].grow(-SLACK)):
				_fail("%s: slot %d's meter %s overlaps \"%s\" %s" % [where, slot, r.position,
					ts[i].text, rects[i].position.round()], "meter|" + ts[i].text)
	asserts += 1


## CAREER (ADR-047): the slots, the card, the editor with every value of
## every row, the name keyboard at every length and key, the widest
## names and numbers, and the HUD and UNLOCKED! card of a career match.
func test_career_screens() -> void:
	var s := _save()
	for i in Career.SLOTS:
		s.career.create(i, ["WWWWWWWW", "MMMMMMMM", "W-M W-M"][i])
		var p: Career.Player = s.career.players[i]
		for k in ["points_won", "aces", "shutouts", "best_streak", "longest_rally"]:
			p.set(k, Career.COUNTER_MAX)
		p.wins = [Career.COUNTER_MAX, Career.COUNTER_MAX]
		p.losses = [Career.COUNTER_MAX, Career.COUNTER_MAX]
	s.career.select(0)
	var t := title_screen(s)
	t.open_career()
	t.pages["career"].settle()
	check_layout(t, "career slots")
	s.career.select(Career.NONE)
	t.pages["career"].refresh()
	check_layout(t, "career slots, nobody")
	s.career.players[2].used = 0
	t.pages["career"].refresh()
	check_layout(t, "career slots, a new one")
	s.career.select(0)
	t.pages["career"].select("slot0")
	t.pages["career"].press()
	var card: MenuPage = t.pages["career_card"]
	card.settle()
	# every unlock count, the next one's hint (the longest), and all
	var p0: Career.Player = s.career.players[0]
	for n in Career.unlocks() + 1:
		p0.unlocked = (1 << n) - 1
		t.career_preview.show_player(p0)
		card.refresh()
		check_layout(t, "career card, %d unlocked" % n)
	# the HAT MUSEUM: every case picked, all locked (the hints) and all won
	for mask in [0, 0xffff]:
		p0.unlocked = mask
		card.select("hats")
		card.press()
		eq(t.page, "museum")
		for i in Museum.hats():
			t.museum.cursor = i
			t.museum.changed = true
			t.hat_museum._process(0.0)
			check_layout(t, "museum, unlocked %x, case %d" % [mask, i])
		t.museum_input(Practice.PAD_Y)
		card.settle()
	card.select("delete")
	card.press()
	check_layout(t, "career card, delete armed")
	p0.unlocked = 0x1ff
	card.select("edit")
	card.press()
	var edit: MenuPage = t.pages["career_edit"]
	edit.settle()
	for row in edit.rows:
		if not row.has("change"):
			continue
		edit.select(row["id"])
		for k in 12:
			edit.change(1)
			edit.settle()
			check_layout(t, "career edit %s = %s" % [row["id"], edit.value_of(row["id"])])
	edit.select("name")
	edit.press()
	eq(t.page, "career_name", "typing")
	var page := t.career_page
	for length in Career.NAME + 1:
		page.cursor = length
		p0.name = ("WWWWWWWW".substr(0, length) + "        ").substr(0, Career.NAME)
		for k in CareerPage.KEYS:
			page.pick_key(k)
			t.career_keyboard.refresh()
			check_layout(t, "career name %d, key %d" % [length, k])
	t.free()
	# the match: the name on the panel, and the unlocks card at its widest
	for doubles in [false, true]:
		var cfg := Settings.config_for(doubles, 7, K.DIFFICULTY_MEDIUM, 11)
		cfg.set_career(s.career.players[0])
		var v := _view(cfg)
		v.sim.team_score = [10, 10]
		v._hud.refresh()
		check_layout(v, "hud career %s" % ("doubles" if doubles else "singles"))
		v.save.career = s.career
		v.save.career.new_unlocks = 0x1ff
		v.sim.phase = K.PHASE_MATCH_RESULT
		v.sim.match_winner = 0
		v.unlock_frames = 0
		v._hud.refresh()
		check_layout(v, "hud unlocked card")
		v.save.career.new_unlocks = 1 << 8
		v._hud.refresh()
		check_layout(v, "hud unlocked card, one")
		# the park's result: the rating line under the story line
		v.unlock_frames = -1
		v.save.career.new_unlocks = 0
		v.park = true
		for opened in [OpenPlay.NONE, 1]:
			v.save.career.park_before = 38
			v.save.career.park_after = 40
			v.save.career.park_opened = opened
			v._hud.refresh()
			check_layout(v, "hud park rating, opened %d" % opened)
		v.park = false
		v.save.career.park_before = OpenPlay.RATING_NONE
		v.free()


func test_park() -> void:
	var park := OpenPlay.new()
	park.begin(1234, false)
	var view := ParkView.new()
	runner.root.add_child(view)
	view.setup(park, _save(), false)
	for f in 1500:
		view.step_frame(SimTypes.Intent.new())
		if f % 150 == 0:
			view.refresh()
			check_layout(view, "park frame %d" % f)
	# inside the clubhouse, reading the records board
	park.x_fp = K.to_fp(OpenPlay.BOARD_X + 4)
	park.y_fp = K.to_fp(OpenPlay.BOARD_Y + 6)
	park.update(0, 0, true)
	for f in 60:
		view.step_frame(SimTypes.Intent.new())
	check_layout(view, "park clubhouse board")
	view.free()
	# Rated (SNES ADR-070..072): every panel the rating, the stay and the
	# pick add, at their widest.
	var s := _save()
	s.career.create(0, "WWWWWWWW")
	var player := s.career.active_player()
	player.park = OpenPlay.RATING_MAX - Career.PARK_BASE - 2  # 38 points, CHAMP not reached
	for t in Career.TEAMS:
		player.beaten[t] = 1
	park = OpenPlay.new()
	park.begin(1234, false)
	view = ParkView.new()
	runner.root.add_child(view)
	view.setup(park, s, false)
	var cases := []
	park.x_fp = K.to_fp(OpenPlay.rack_x(1))
	park.y_fp = K.to_fp(OpenPlay.RACK_Y)
	player.park = 18 - Career.PARK_BASE + 20             # 18 points: CLUB locked
	view.rate_park()
	view.refresh()
	cases.append(["park locked rack", "OPENS AT 15"])
	check_layout(view, "park locked rack")
	check(view.message.begins_with("OPENS AT"), "a locked rack says so: " + view.message)
	player.park = (2 << Career.PARK_COURT_SHIFT) | 30
	view.rate_park()
	park.x_fp = K.to_fp(OpenPlay.rack_x(2))
	park.update(0, 0, true)
	for pick in OpenPlay.TEAMS + 1:
		park.pick_next()
		view.refresh()
		check_layout(view, "park pick %d" % park.pick)
	check(view.message.begins_with("PARTNER:"), "the pick panel: " + view.message)
	park.update(0, 0, true)                                # your paddle back
	park.x_fp = K.to_fp(128)
	park.y_fp = K.to_fp(200)
	view.refresh()
	check_layout(view, "park rated hello")
	check(view.message.ends_with("PTS"), "your points: " + view.message)
	park.last_won = 1
	park.last_score = [11, 10]
	park.last_streak = OpenPlay.STAY_MAX
	for timer in [ParkView.RESULT_FRAMES, 10]:
		view.result_timer = timer
		view.refresh()
		check_layout(view, "park won, timer %d: %s" % [timer, view.message])
	view.result_timer = 0
	park.called = 2
	park.stay_court = 2
	park.opponent = 4
	view.refresh()
	check_layout(view, "park winners stay")
	eq(view.message.left(13), "WINNERS STAY:")
	# PORT-60: staying on at the rack (with STEP OFF), and the widest wait
	park.called = OpenPlay.NONE
	park.x_fp = K.to_fp(OpenPlay.rack_x(2))
	park.y_fp = K.to_fp(OpenPlay.RACK_Y)
	view.refresh()
	check_layout(view, "park staying on, at the rack")
	eq(view.message, "YOU STAY ON COURT 3")
	park.stay_court = OpenPlay.NONE
	park.your_court = 2
	park.court[2].stack = [5, 6, OpenPlay.YOU, 0]
	park.court[2].stack_count = 3
	park.x_fp = K.to_fp(OpenPlay.START_X)
	park.y_fp = K.to_fp(OpenPlay.START_Y)
	view.refresh()
	check_layout(view, "park teams ahead")
	eq(view.message, "2 TEAMS AHEAD OF YOU ON COURT 3")
	view.free()


## PORT-25: the bracket fresh, in play, out, won (singles and doubles,
## the career player's name in your boxes), and MAIN's TOURNAMENT row at
## its widest value.
func test_tournament() -> void:
	for doubles in [false, true]:
		for state in ["fresh", "semi", "out", "won"]:
			var s := _save()
			s.career.players[0] = Career.Player.new()
			s.career.players[0].name = "WWWWWWWW"
			s.career.active = 0
			var t := Tournament.create(1994, doubles, K.DIFFICULTY_MEDIUM, 21)
			if state != "fresh":
				t.record(true, 21, 19)
			if state == "out":
				t.record(false, 19, 21)
			elif state == "won":
				t.record(true, 21, 19)
				t.record(true, 23, 21)
			t.seen = 99
			if state != "fresh":
				s.store_tournament(t)
			var b := BracketScreen.new().setup(s, false)
			runner.root.add_child(b)
			if not b.is_node_ready():
				b._ready()
			for row in ["play", "mode", "back"]:
				b.page.select(row)
				b.forfeit_armed = row == "mode"
				b.page.refresh()
				check_layout(b, "bracket %s %s on %s" % ["doubles" if doubles else "singles", state, row])
			b.free()
	var s2 := _save()
	var t2 := Tournament.create(3, false, K.DIFFICULTY_MEDIUM, 11)
	s2.store_tournament(t2)
	var title := title_screen(s2)
	title.pages["main"].refresh()
	check_layout(title, "title main, QF on TOURNAMENT")
	title.free()


## PORT-28: on a pad, every family's prompts (PlayStation's OPTIONS and
## CREATE pills are the widest) on the screens that show them: every title
## page, the lobby, a match's HUD (the serve prompt, the pause menu), and
## the bracket.
func test_pad_families() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	GameControls.last_device = GameControls.PAD
	for fam in range(1, Prompts.FAMILIES.size()):
		Settings.pad_glyphs = fam
		GameControls.device_serial += 1
		var name: String = Prompts.FAMILY_NAMES[fam]
		var t := _title()
		for id in t.pages:
			t._show(id)
			t.pages[id].settle()
			check_layout(t, "%s: title %s" % [name, id])
		t.free()
		GameControls.fake_pads = {0: {}, 1: {}}
		var tl := _title()
		tl.open_lobby()
		tl.lobby.join(0)
		tl.lobby_screen.refresh()
		check_layout(tl, "%s: lobby" % name)
		tl.free()
		GameControls.fake_pads = {}
		var v := _view(SimTypes.MatchConfig.singles())
		check_layout(v, "%s: the serve" % name)
		v.sim.paused = 1
		v._hud.refresh()
		check_layout(v, "%s: paused" % name)
		v.free()
		var b := BracketScreen.new().setup(_save(), false)
		runner.root.add_child(b)
		if not b.is_node_ready():
			b._ready()
		check_layout(b, "%s: bracket" % name)
		b.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## PORT-81: the touch pad over every title page, a match (the serve and
## paused) and the bracket, with its prompts: its letters clear of the
## screens' text.
func test_touch_pad() -> void:
	var kept := [GameControls.last_device, Settings.touch_pad]
	GameControls.last_device = GameControls.TOUCH
	Settings.touch_pad = TouchPad.ON
	GameControls.device_serial += 1
	var with_pad := func(n: Node) -> TouchPad:
		var pad := TouchPad.new()
		pad._ready()
		pad.visible = true
		n.add_child(pad)
		return pad
	# the pad steps aside from the screen's panels, as it does each frame
	var settle := func(n: Node, pad: TouchPad) -> void:
		var boxes := []
		var stack := [n]
		while not stack.is_empty():
			var c: Node = stack.pop_back()
			if c is NinePatchRect and _shown(c):
				boxes.append(Rect2(c.get_global_transform().origin, c.size))
			stack.append_array(c.get_children())
		pad.avoid(boxes)
	var t := _title()
	var tp: TouchPad = with_pad.call(t)
	for id in t.pages:
		t._show(id)
		t.pages[id].settle()
		settle.call(t, tp)
		check_layout(t, "touch: title %s" % id)
	t.free()
	var v := _view(SimTypes.MatchConfig.singles())
	var vp: TouchPad = with_pad.call(v)
	settle.call(v, vp)
	check_layout(v, "touch: the serve")
	v.sim.paused = 1
	v._hud.refresh()
	settle.call(v, vp)
	check_layout(v, "touch: paused")
	v.free()
	var b := BracketScreen.new().setup(_save(), false)
	runner.root.add_child(b)
	if not b.is_node_ready():
		b._ready()
	settle.call(b, with_pad.call(b))
	check_layout(b, "touch: bracket")
	b.free()
	GameControls.last_device = kept[0]
	Settings.touch_pad = kept[1]
	GameControls.device_serial += 1


## PORT-29: the lobby in both cup modes with four players, and the couch
## bracket (doubles teams' names) fresh, in play and over.
func test_couch_cup() -> void:
	GameControls.fake_pads = {0: {}, 1: {}, 2: {}, 3: {}}
	var t := _title()
	t.open_lobby()
	for d in 4:
		t.lobby.join(d)
	for mode in [K.MODE_SINGLES, K.MODE_DOUBLES]:
		t.lobby.cup = true
		t.lobby.set_mode(mode)
		t.lobby_screen.refresh()
		check_layout(t, "lobby %s" % t.lobby.mode_name())
	var entries := t.lobby.entries()
	t.free()
	# a couch match's HUD: P1 + P2 against P3 + P4, and a team against a CPU team
	var hc := Tournament.create(8, true, K.DIFFICULTY_MEDIUM, 21, entries)
	for i in 3:
		var cm := hc.couch_match(0, "park")
		var v := MatchView.new()
		v.save = _save()
		v.slot_pads = cm["pads"]
		v.slot_players = cm["players"]
		runner.root.add_child(v)
		v.setup(cm["cfg"], cm["venue"], false)
		v.card_frames = -1
		v._hud.close_card()
		v.sim.team_score = [20, 20]
		v._hud.refresh()
		check_layout(v, "couch match %s: %s vs %s" % [i, v._hud._team_label(0), v._hud._team_label(1)])
		if i == 0:
			eq(v._hud._team_label(0), "P1 + P2", "a side by its players")
		v.free()
		hc.record_left(true, 21, 3)
	GameControls.fake_pads = {}
	for state in ["fresh", "semi", "over"]:
		var s := _save()
		var cup := Tournament.create(8, true, K.DIFFICULTY_MEDIUM, 21, entries)
		if state != "fresh":
			cup.record_left(true, 21, 19)
			cup.record_left(true, 21, 19)
		if state == "over":
			cup.record_left(true, 23, 21)
			cup.record_left(false, 19, 21)
		cup.seen = 99
		s.store_tournament(cup, "couch")
		var b := BracketScreen.new().setup(s, false, true)
		runner.root.add_child(b)
		if not b.is_node_ready():
			b._ready()
		check_layout(b, "couch bracket %s" % state)
		b.free()


## PORT-30: every lesson's card, its banner with advice up, and LESSON
## DONE!, on the keyboard and a PlayStation pad (the widest prompts).
func test_tutorial() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	for dev in [GameControls.KEYBOARD, GameControls.PAD]:
		GameControls.last_device = dev
		Settings.pad_glyphs = 2
		GameControls.device_serial += 1
		for i in Tutorial.LESSONS.size():
			var v := MatchView.new()
			v.lesson = Tutorial.new(i)
			runner.root.add_child(v)
			v.setup(v.lesson.config({}), "park", false)
			var lv := v.lesson_view
			check_layout(v, "lesson %d card (device %d)" % [i, dev])
			lv.card_frames = -1
			v.lesson.progress = 1
			v.lesson.message = "SERVE CORNER TO CORNER, PAST THE KITCHEN."
			lv.refresh()
			v._hud.refresh()
			check_layout(v, "lesson %d playing, with advice" % i)
			v.lesson.done = true
			lv.update_done()
			check_layout(v, "lesson %d done" % i)
			v.free()
	var t := _title()
	t.open_page("learn")
	t.pages["learn"].settle()
	check_layout(t, "title PRACTICE page")
	t.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## PORT-31: the ONLINE screen in each state (idle, an error, hosting with
## two addresses, calling, connected as host and guest, closed, typing the
## longest address), the MULTIPLAYER page, and an online match's HUD and
## result for host and guest (YOU against an 8-letter name).
func test_online() -> void:
	var o := OnlineScreen.new().setup(_save())
	runner.root.add_child(o)
	if not o.is_node_ready():
		o._ready()
	o.address = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	o.refresh()
	check_layout(o, "online idle, the longest address")
	o.editing = true
	o.refresh()
	check_layout(o, "online typing")
	o.editing = false
	o.last_reason = "CAN'T REACH WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	o.refresh()
	check_layout(o, "online, an error")
	o.last_reason = ""
	var links := LoopbackLink.pair(0)
	for host in [true, false]:
		o.session = OnlineSession.new(links[0], host)
		o.session.my_hello = OnlineSession.hello({})
		o.refresh()
		check_layout(o, "online waiting (host %s)" % host)
		o.session.state = OnlineSession.CONNECTED
		o.session.peer_hello = {"name": "WWWWWWWW"}
		o.refresh()
		check_layout(o, "online connected (host %s)" % host)
	o.session.reason = "VERSIONS DIFFER: 10.10.10 AND 10.10.11"
	o.session.state = OnlineSession.CLOSED
	o.refresh()
	check_layout(o, "online closed")
	o.free()
	var t := _title()
	t.open_page("multi")
	t.pages["multi"].settle()
	check_layout(t, "title MULTIPLAYER")
	t.free()
	for host in [true, false]:
		var pair := LoopbackLink.pair(0)
		var s := OnlineSession.new(pair[0], host)
		s.peer_hello = {"name": "WWWWWWWW"}
		var cfg := PlayerSelect.config_select(K.MODE_SINGLES, PlayerSelect.new_choice(0, 0, 1),
			PlayerSelect.new_choice(1, 0, 1))
		var v := MatchView.new()
		v.net = s
		runner.root.add_child(v)
		v.setup(cfg, "park", false)
		v.sim.team_score = [10, 10]
		v._hud.refresh()
		check_layout(v, "online match (host %s)" % host)
		v.sim.phase = K.PHASE_MATCH_RESULT
		v.sim.match_winner = 1
		v.sim.phase_timer = K.POINT_RESULT_MIN_FRAMES + 1
		v._hud.refresh()
		check_layout(v, "online result (host %s)" % host)
		v.sim.phase = K.PHASE_LIVE
		v.leave_frames = 60
		v._net_refresh(false)
		v._hud.refresh()
		check_layout(v, "online, press again to leave (host %s)" % host)
		v.free()


## PORT-32: OPTIONS with UPDATES in every state (the longest version), and
## the title's line under the logo with every notice.
func test_updater() -> void:
	var u := Updater.new()
	Updater.instance = u
	u.latest = "10.10.10"
	u.error = "THE DOWNLOAD WAS DAMAGED: TRY AGAIN"
	var t := _title()
	t.open_page("options")
	t.pages["options"].settle()
	for st in range(Updater.OFF, Updater.FAILED + 1):
		u.state = st
		t.pages["options"].refresh()
		t._refresh_record()
		check_layout(t, "updater state %d: %s / %s" % [st, u.label(), u.notice()])
	t.free()
	Updater.instance = null
	u.free()


## PORT-34: the update screen in every state, the longest version and error.
func test_update_screen() -> void:
	for st in range(Updater.IDLE, Updater.FAILED + 1):
		var u := Updater.new()
		u.state = st
		u.latest = "10.10.10"
		u.error = "THE DOWNLOAD WAS DAMAGED: TRY AGAIN"
		u.manifest = {"size": 999999999}
		var s := UpdateScreen.new().setup(u)
		runner.root.add_child(s)
		if not s.is_node_ready():
			s._ready()
		s.refresh()
		if s.page:
			s.page.settle()
		check_layout(s, "update screen, state %d" % st)
		s.free()
		u.free()


## PORT-44: every page of every story scene (the chapter cards, the talk,
## Grimsby's letters and loudspeaker, the petition, THE END), typed out.
func test_story() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var me := PlayerLook.for_team(0, 0, 0, MatchView.levels_manifest())
	for dev in [GameControls.KEYBOARD, GameControls.PAD]:
		GameControls.last_device = dev
		Settings.pad_glyphs = 2
		GameControls.device_serial += 1
		for ch in StoryMode.CHAPTERS:
			for kind in ["intro", "win", "lose"] + (["ending"] if ch == StoryMode.CHAPTERS - 1 else []):
				var s := StoryScene.new().setup(null, ch, kind, me)
				runner.root.add_child(s)
				for i in s.pages.size():
					s.page = i
					s._show_page()
					var p := s._page()
					s.shown = s._text_of(p).length()
					s._type(p, s._text_of(p))
					check_layout(s, "story chapter %d %s page %d (device %d)" % [ch + 1, kind, i, dev])
				s.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## PORT-45: PICKLEBALL 101, the list on every lesson (none done, all
## perfect), and every page of every lesson: quizzes unanswered, answered
## right and wrong, and the closing page.
func test_course() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := fresh_save("user://test_layout_course/")
	for dev in [GameControls.KEYBOARD, GameControls.PAD]:
		GameControls.last_device = dev
		Settings.pad_glyphs = 2
		GameControls.device_serial += 1
		var c := CourseScreen.new().setup(sv)
		runner.root.add_child(c)
		if not c.is_node_ready():
			c._ready()
		for pass_i in 2:
			for i in Course.count() + 1:
				c.list.cursor = i
				c.list.refresh()
				c._show_preview()
				c.list.settle()
				check_layout(c, "PICKLEBALL 101 list, row %d (pass %d, device %d)" % [i, pass_i, dev])
			for i in Course.count():
				Course.finish(sv, i, true)
			c.show_list()
		for i in Course.count():
			c.open_lesson(i)
			while true:
				var p := c._page()
				if c.choices:
					c.choices.settle()
				check_layout(c, "%s page %d (device %d)" % [Course.lesson(i)["title"], c.page, dev])
				if Course.is_quiz(p):
					for wrong in [true, false]:
						c.answers[c.page] = (int(p["answer"]) + (1 if wrong else 0)) % p["choices"].size()
						c.choices.refresh()
						c._text()
						check_layout(c, "%s quiz %d, answered %s" % [Course.lesson(i)["title"], c.page,
							"wrong" if wrong else "right"])
				if p.has("end"):
					break
				c.next_page()
		c.free()
	wipe_saves("user://test_layout_course/")
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## PORT-49: the tuning panel's pages over a match, at the sliders' ends
## and with every modifier on, keyboard and pad prompts.
func test_tuning() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs, Settings.ball_speed, Settings.ball_size,
		Settings.cpu_errors]
	for dev in [GameControls.KEYBOARD, GameControls.PAD]:
		GameControls.last_device = dev
		Settings.pad_glyphs = 2
		GameControls.device_serial += 1
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11), "park", false)
		v.card_frames = -1
		v.tuning.open_panel()
		for ends in [[K.BALL_SPEED_MIN, Settings.BALL_SIZE_MIN, 0],
				[K.BALL_SPEED_MAX, Settings.BALL_SIZE_MAX, Settings.CPU_ERRORS_MAX]]:
			Settings.ball_speed = ends[0]
			Settings.ball_size = ends[1]
			Settings.cpu_errors = ends[2]
			for id in ["tune", "modifiers", "rules"]:
				for all_on in [false, true]:
					v.tuning.mods = 0x7fffffff if all_on else 0
					v.tuning._show(id)
					v.tuning._process(0.0)
					for f in TuningPanel.SLIDE_FRAMES:
						v.tuning._process(0.0)
					v.tuning.page.settle()
					check_layout(v, "tuning %s (device %d, mods %s, %s)" % [id, dev, all_on, ends])
		v.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	Settings.ball_speed = kept[2]
	Settings.ball_size = kept[3]
	Settings.cpu_errors = kept[4]
	GameControls.device_serial += 1


## The pause menu's OPTIONS (ADR-090): every page over a paused match,
## every value of every row tried.
func test_pause_options() -> void:
	var kept := [Settings.camera_i, Sfx.setting, Music.volume, Announcer.volume, Announcer.chatter,
		Settings.shake_i, Settings.pad_glyphs, Settings.touch_pad, Settings.hud_large]
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 11), "park", false)
	v.card_frames = -1
	v.sim.paused = 1
	v._update_visuals()
	v.options.open_panel()
	for id in ["options", "access", "controls", "pad"]:
		v.options._show(id)
		var p: MenuPage = v.options.pages[id]
		p.settle()
		check_layout(v, "pause options %s" % id)
		for row in p.rows:
			if not row.has("change") or row["id"] in ["fullscreen", "scale", "vibration"]:
				continue
			p.select(row["id"])
			for k in 12:
				p.change(1)
				p.settle()
				check_layout(v, "pause options %s / %s = %s" % [id, row["id"], p.value_of(row["id"])])
	v.free()
	Settings.camera_i = kept[0]
	Sfx.setting = kept[1]
	Music.volume = kept[2]
	Announcer.volume = kept[3]
	Announcer.chatter = kept[4]
	Settings.shake_i = kept[5]
	Settings.pad_glyphs = kept[6]
	Settings.touch_pad = kept[7]
	Settings.hud_large = kept[8]
	GameControls.device_serial += 1


## PORT-51: PLAY OF THE MATCH's card, catching up and playing, with the
## longest caption (an 8-letter name, every ending), keyboard and pad.
func test_highlight() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	for dev in [GameControls.KEYBOARD, GameControls.PAD]:
		GameControls.last_device = dev
		Settings.pad_glyphs = 2
		GameControls.device_serial += 1
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(Settings.config_for(true, 4, K.DIFFICULTY_MEDIUM, 11), "park", false)
		v.card_frames = -1
		for f in [K.FAULT_OUT, K.FAULT_SECOND_BOUNCE, K.FAULT_NET, K.FAULT_MOMENTUM]:
			for winner in [0, 1]:
				v.highlight.best = {"shots": 188, "from": 0, "to": 0, "winner": winner, "fault": f,
					"snap_from": [], "snap_to": []}
				v.highlight.saved = winner == 1          # PORT-69's card: SAVED REPLAY
				v.highlight.start(func(): pass)
				v.highlight._caption[2].visible = true
				check_layout(v, "PLAY OF THE MATCH, fault %d, team %d (device %d)" % [f, winner, dev])
				if not v.highlight.saved:            # PORT-70: SAVE, then SAVED; and FULL
					v.highlight.saved_best = true
					v.highlight._refresh_save()
					check_layout(v, "PLAY OF THE MATCH, SAVED (device %d)" % dev)
					v.highlight.saved_best = false
					for i in SavedReplays.MAX:
						SavedReplays.save({"format": SavedReplays.FORMAT, "tuning": K.TUNING_VERSION,
							"saved": i, "cfg": {}, "inputs": PackedInt32Array(), "ops": {},
							"rally": {"shots": 1}})
					v.highlight._refresh_save()
					check_layout(v, "PLAY OF THE MATCH, REPLAYS FULL (device %d)" % dev)
					wipe_replays()
				v.highlight._state = ""
				v.highlight.overlay.free()
				v.highlight.overlay = null
				v.highlight.replay.dispose()
				v.highlight.replay = null
				v._hud.visible = true
		v.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## PORT-69: REPLAYS full, at its widest (188 shots, December 28th, an OLD
## one), each row selected, watching and deleting.
func test_replays() -> void:
	wipe_replays("user://test_layout_replays/")
	var d := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 12, "day": 28,
		"hour": 12, "minute": 0, "second": 0})
	for i in SavedReplays.MAX:
		SavedReplays.save({"format": SavedReplays.FORMAT,
			"tuning": K.TUNING_VERSION + (1 if i == 0 else 0), "saved": d + i, "doubles": true,
			"cfg": {}, "inputs": PackedInt32Array(), "ops": {}, "rally": {"shots": 188}})
	var t := _title()
	t._show("replays")
	var p: MenuPage = t.pages["replays"]
	for row in p.rows:
		p.select(row["id"])
		p.settle()
		check_layout(t, "REPLAYS / %s" % row["id"])
	t.replay_delete = true
	p.refresh()
	check_layout(t, "REPLAYS, DELETE")
	t.free()
	wipe_replays()


## PORT-54: ACHIEVEMENTS with each row selected, done (with its day) and not.
func test_achievements() -> void:
	var t := _title()
	t.open_page("achievements")
	var p: MenuPage = t.pages["achievements"]
	p.settle()
	for done in [false, true]:
		for a in Achievements.LIST:
			if done:
				Achievements.unlock(t.save, a[0])
			p.select(a[0])
			p.refresh()
			t._refresh_achievement()
			check_layout(t, "ACHIEVEMENTS: %s (%s)" % [a[0], "done" if done else "not yet"])
	t.free()


## Port ADR-082: MAP BUTTONS at every step (each one being asked, then
## answered by the longest sources: an axis, a hat, a two-digit button),
## with the widest pad name; and the startup card about controllers.
## A generic pad's answer to MAP BUTTONS' step `i` (device 7): an axis for
## the first two, the d-pad's left and right, then a button each.
static func _pad_answer(i: int) -> InputEvent:
	var e: InputEvent
	if i < 2:
		e = InputEventJoypadMotion.new()
		e.axis = 9
		e.axis_value = -1.0 if i == 0 else 1.0
	elif i < 4:
		e = InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_DPAD_LEFT if i == 2 else JOY_BUTTON_DPAD_RIGHT
		e.pressed = true
	else:
		e = InputEventJoypadButton.new()
		e.button_index = 30 + i
		e.pressed = true
	e.device = 7
	return e


func test_pad_map() -> void:
	var t := _title()
	var m := t.pad_mapper
	m.begin(7, "03000000790000001100000000000000", "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW")
	t._show("padmap")
	for i in PadMapper.STEPS.size():
		t.pad_map_screen.refresh()
		check_layout(t, "MAP BUTTONS asking %s" % PadMapper.STEPS[i][0])
		m.feed(_pad_answer(i))
	t.pad_map_screen.refresh()
	check_layout(t, "MAP BUTTONS all answered")
	m.cancel()
	PadMaps.maps = {}
	TitleScreen.notice_done = false
	var n := _title()
	n.pages["notice"].settle()
	eq(n.page, "notice")
	check_layout(n, "the controller card")
	n.free()
	TitleScreen.notice_done = true
	t.free()


## The small font's ink rows (outline and shadow), read off its texture:
## [top, bottom) over every glyph.
static func _small_ink() -> Vector2:
	var f := BitmapText.load_font("small")
	var img: Image = (f["texture"] as Texture2D).get_image()
	var top := 99
	var bottom := 0
	for ch in String(f["chars"]):
		var g: Dictionary = f["glyphs"][ch]
		for y in int(g["h"]):
			for x in int(g["w"]):
				if img.get_pixel(int(g["x"]) + x, int(g["y"]) + y).a > 0.0:
					top = mini(top, y)
					bottom = maxi(bottom, y + 1)
	return Vector2(top, bottom)


## `ink` (top, bottom) sits inside `box` (top, bottom), as far from one
## edge as the other give or take a px (PORT-79: text sat 3 px low).
func _centred(ink: Vector2, box: Vector2, where: String) -> void:
	var above := ink.x - box.x
	var below := box.y - ink.y
	if above < 0 or below < 0 or absf(above - below) > 1.0:
		runner.fail("%s: text ink %s in %s (%.1f px above, %.1f below)" % [where, ink, box, above, below])
	asserts += 1


## PORT-79: the selected row's letters centred in the menus' bar and MAP
## BUTTONS', and every key's letters in its top face, their labels level.
func test_text_centred() -> void:
	var ink := _small_ink()
	eq(UiKit.SMALL_INK, ink, "UiKit.SMALL_INK matches the font")
	var t := _title()
	for id in t.pages:
		t._show(id)
		var p: MenuPage = t.pages[id]
		for row in p.rows:
			p.select(row["id"])
			p.settle()
			var y: float = p._labels[p.cursor].position.y
			var bar := p.bar_rect()
			_centred(Vector2(y + ink.x, y + ink.y), Vector2(bar.position.y, bar.end.y),
				"%s / %s's bar" % [id, row["id"]])
			# the mouse picks the row anywhere on its bar
			var mid := bar.get_center().x
			for at in [bar.position.y + 0.5, bar.end.y - 0.5]:
				if p.row_at(Vector2(mid, at)) != p.cursor:
					runner.fail("%s / %s: the mouse at y %.1f is on row %d" % [id, row["id"], at,
						p.row_at(Vector2(mid, at))])
			asserts += 1
	var m := t.pad_mapper
	m.begin(7, "03000000790000001100000000000000", "PAD")
	t._show("padmap")
	for i in PadMapper.STEPS.size():
		eq(m.step, i, "MAP BUTTONS asks step %d" % i)
		var y: float = t.pad_map_screen._labels[m.step].position.y
		var bar := t.pad_map_screen.bar_rect()
		_centred(Vector2(y + ink.x, y + ink.y), Vector2(bar.position.y, bar.end.y),
			"MAP BUTTONS step %d's bar" % m.step)
		m.feed(_pad_answer(i))
	m.cancel()
	t.free()
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var items := [["hit", "HIT"], ["drive", "DRIVE"], ["soft", "SOFT"], ["slice", "SLICE"],
		["short", "SHORT"], ["special", "SPECIAL"], ["start", "PAUSE"], ["esc", "BACK"], ["bksp", "STEP BACK"]]
	var kinds := {}
	for fam in Prompts.FAMILIES.size():
		GameControls.last_device = GameControls.KEYBOARD if fam == 0 else GameControls.PAD
		Settings.pad_glyphs = fam
		GameControls.device_serial += 1
		var b := PromptBar.new().setup(items, Vector2(480, 500))
		for k in b.key_faces():
			var face: Rect2 = k[0]
			var letters: BitmapText = k[1]
			var label: BitmapText = k[2]
			kinds[fam] = true
			_centred(Vector2(letters.position.y + ink.x, letters.position.y + ink.y),
				Vector2(face.position.y, face.end.y), "family %d: \"%s\"'s key" % [fam, letters.text])
			eq(label.position.y, letters.position.y, "\"%s\" level with its key" % label.text)
		b.free()
	eq(kinds.size(), Prompts.FAMILIES.size(), "every family has a key or pill to check")
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## CONTROLLER with a pad's longest name and each MAP BUTTONS status (the
## tests have no pads, so the rows are given those values).
func test_controller_page_widest() -> void:
	var t := _title()
	t._show("pad")
	var p: MenuPage = t.pages["pad"]
	p.settle()
	var name := PadMaps.short_name("USB,2-axis 8-button gamepad with a long name", 18)
	for st in [PadMaps.STANDARD, PadMaps.UNKNOWN, PadMaps.MAPPED, PadMaps.NO_PAD]:
		for row in p.rows:
			if row["id"] == "device":
				row["value"] = func(): return name
			elif row["id"] == "map":
				row["value"] = func(): return st
		p.refresh()
		eq(p.value_of("map"), st)
		check_layout(t, "CONTROLLER: %s, %s" % [name, st])
	t.free()


# --- ROAD TRIP (port ADR-087) ------------------------------------------------------------

## A save with a long ROAD TRIP behind it: every captain a partner, the
## records at their widest, the GARAGE's every look.
func _trip_save(dir: String) -> SaveGame:
	var sv := fresh_save(dir)
	var m := RoadTrip.meta(sv)
	m["miles"] = 99999
	m["trips"] = 888
	m["won"] = 888
	m["best_heat"] = 5
	m["best_leg"] = 3
	m["heat"] = 5
	m["partners"] = [0, 1, 2, 3, 4, 5, 6, 7]
	m["tapes"] = [1, 2, 3, 4]
	m["story_pool"] = ["grandpas_paddle", "hog_paddle", "champ_paddle"]
	return sv


## A trip some way in, with a bag full of everything and the widest numbers.
func _full_trip(seed_value: int) -> RoadTrip:
	var t := RoadTrip.create(seed_value, 0, RoadTrip.PEPPER)
	for g in RoadTrip.data()["gear"]:
		if String(g["rarity"]) != "start":
			t.take(String(g["id"]))
	t.max_hearts = RoadTrip.HEARTS_MAX
	t.hearts = 4
	t.cash = 999
	t.hazards = ["flat_tire", "storm"]
	return t


func _devices() -> Array:
	return [GameControls.KEYBOARD, GameControls.PAD]


func _device(dev: int) -> void:
	GameControls.last_device = dev
	Settings.pad_glyphs = 2
	GameControls.device_serial += 1


func test_trip_home() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := _trip_save("user://test_layout_trip/")
	var t := _full_trip(7)
	t.at = [2, 1, 0]
	t.store(sv)
	for dev in _devices():
		_device(dev)
		var h := TripHome.new().setup(sv)
		runner.root.add_child(h)
		if not h.is_node_ready():
			h._ready()
		for row in h.page.rows:
			h.page.select(String(row["id"]))
			if String(row["id"]) == "partner":
				for p in h.partners():
					h.partner = int(p)
					h.page.refresh()
					check_layout(h, "ROAD TRIP home, partner %s (device %d)" % [TripHome.partner_name(int(p)), dev])
			elif String(row["id"]) == "heat":
				for k in RoadTrip.HEAT_MAX + 1:
					h.heat = k
					h.page.refresh()
					check_layout(h, "ROAD TRIP home, HEAT %d" % k)
			else:
				check_layout(h, "ROAD TRIP home, row %s (device %d)" % [row["id"], dev])
		h.new_armed = true
		h.page.refresh()
		check_layout(h, "ROAD TRIP home, NEW TRIP armed")
		# the GARAGE at the bottom, the middle and the top of its ladder
		var m := RoadTrip.meta(sv)
		for miles in [0, 500, 3000, 99999]:
			m["miles"] = miles
			var g := RoadTrip.garage(m)
			h._open_garage()
			for v in g["vans"]:
				for o in g["ornaments"]:
					m["looks"] = {"van": int(v), "ornament": int(o), "tape": 0}
					h.garage_page.refresh()
					check_layout(h, "the GARAGE at %d miles, van %d, ornament %d (device %d)" % [miles, v, o, dev])
			for tp in g["tapes"]:
				m["looks"]["tape"] = int(tp)
				h.garage_page.select("tape")
				h.garage_page.refresh()
				check_layout(h, "the GARAGE at %d miles, cassette %d (device %d)" % [miles, tp, dev])

			var gnode := h._garage
			h._close_garage()
			gnode.free()
		h.free()
		# a trip's results, the longest ones
		var ladder: Array = RoadTrip.data()["ladder"]
		var longest := range(ladder.size())
		longest.sort_custom(func(a, b): return RoadTrip.step_label(a).length() > RoadTrip.step_label(b).length())
		for won in [false, true]:
			var r := TripHome.new().setup(sv, {"won": won, "leg": 3, "wins": 88, "losses": 88, "stops": 88,
				"miles": 9999, "steps": longest.slice(0, 5), "heat_open": 5})
			runner.root.add_child(r)
			if not r.is_node_ready():
				r._ready()
			check_layout(r, "a trip's results, won %s (device %d)" % [won, dev])
			r.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


func test_trip_map() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := _trip_save("user://test_layout_trip_map/")
	for dev in _devices():
		_device(dev)
		for seed_value in [1, 2, 3]:
			var t := _full_trip(seed_value)
			var map := TripMap.new().setup(sv, t)
			runner.root.add_child(map)
			if not map.is_node_ready():
				map._ready()
			# every stop on the map, as the one chosen
			for leg in RoadTrip.LEGS:
				for col in RoadTrip.COLS:
					for lane in RoadTrip.LANES:
						var n: Dictionary = t.map[leg]["cols"][col][lane]
						var lines := t.info(n)
						for k in 3:
							map._info[k].text = String(lines[k]) if k < lines.size() else ""
						check_layout(map, "the map, seed %d, %s (device %d)" % [seed_value, n["type"], dev])
				var g: Dictionary = t.map[leg]["gate"]
				var gl := t.info(g)
				gl[0] = "AGAIN: " + String(gl[0])
				for k in 3:
					map._info[k].text = String(gl[k]) if k < gl.size() else ""
				check_layout(map, "the map, seed %d, leg %d's %s, again" % [seed_value, leg, g["type"]])
			map.free()
	# every local's name on a match's HUD
	for name in RoadTrip.data()["locals"]:
		var cfg := RoadTrip.create(1, 0, RoadTrip.PEPPER).config_for(
			{"type": "pickup", "team": -1, "local": 0, "mod": ""}, Settings.p1_choice)
		var v := MatchView.new()
		v.trip = true
		v.trip_name = String(name)
		runner.root.add_child(v)
		v.setup(cfg, "park", false)
		v.card_frames = -1
		check_layout(v, "a trip match's HUD against %s" % name)
		v.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


func test_trip_pick_and_shop() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := _trip_save("user://test_layout_trip_pick/")
	var ids: Array = RoadTrip.data()["gear"].filter(func(g): return String(g["rarity"]) != "start") \
		.map(func(g): return String(g["id"]))
	for dev in _devices():
		_device(dev)
		var i := 0
		while i < ids.size():
			var four := ids.slice(i, i + 4)
			var t := RoadTrip.create(3, 0, RoadTrip.PEPPER)
			t.take("visor")
			t.take("red_paddle")
			t.pending = {"kind": "pick", "items": four}
			var p := TripPick.new().setup(sv, t)
			runner.root.add_child(p)
			if not p.is_node_ready():
				p._ready()
			for k in four.size():
				p.select("card_%d" % k)
				check_layout(p, "PICK ONE: %s (device %d)" % [four[k], dev])
			p.free()
			var shop := TripShop.new().setup(sv, t)
			shop.stock = four
			runner.root.add_child(shop)
			if not shop.is_node_ready():
				shop._ready()
			for row in shop.page.rows:
				shop.page.select(String(row["id"]))
				shop._refresh()
				check_layout(shop, "PRO SHOP: %s (device %d)" % [row["id"], dev])
			t.hazards = ["flat_tire", "power_cut", "late_start"]
			shop.page.select("fix")
			shop._refresh()
			check_layout(shop, "PRO SHOP: the fix, three hazards")
			shop.free()
			i += 4
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


func test_trip_scenes() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var me := PlayerLook.for_team(0, 0, 0, MatchView.levels_manifest())
	var scenes: Dictionary = RoadTrip.data()["scenes"]
	var t := _full_trip(5)
	for dev in _devices():
		_device(dev)
		var all := []
		for key in ["start", "won", "over", "motel", "yard_sale", "pro_shop", "lost", "diner", "start_again"]:
			all.append([key, scenes[key], -1])
		for key in ["rival_again", "rival_friendly"]:
			all.append([key, scenes[key], -1, RoadTrip.rival_members()])
		for team in scenes["teams"].size():
			all.append(["team %d" % team, scenes["teams"][team], team])
		for p in scenes["partner_start"].size():
			all.append(["partner start %d" % p, scenes["partner_start"][p], -1])
		for b in RoadTrip.data()["beats"]:
			var sc := RoadTrip.beat_scene(b)
			all.append(["beat " + String(b["id"]), sc["pages"], int(sc["opts"].get("team", -1)),
				sc["opts"].get("members", [])])
		for e in all:
			for partner in [RoadTrip.PEPPER, 3]:
				t.partner = partner
				var s := TripScene.new().setup(t, e[1], me, "WWWWWWWW", {"venue": "park", "team": int(e[2]),
					"members": e[3] if e.size() > 3 else [],
					"card": {"over": "LEG 2: THE LONG DRIVE", "title": "THE SUMMER OPEN",

						"lines": ["VS " + (RoadTrip.opponent_name({"team": int(e[2])}) if int(e[2]) >= 0 else "SCHOOL GUARDS"),
							"STATION NIGHT, FIRST TO 7", "TODAY: GHOST BALL, SUDDEN DEATH"]}})
				runner.root.add_child(s)
				for i in s.pages.size():
					s.page = i
					s._show_page()
					s.shown = s._text_of(s._page()).length()
					s._process(0.0)
					check_layout(s, "trip scene %s page %d, partner %d (device %d)" % [e[0], i, partner, dev])
				s.free()
		for d in RoadTrip.data()["detours"]:
			var choices := []
			for ch in d["choices"]:
				choices.append({"label": String(ch["label"]), "enabled": false, "value": "NEED 20"})
			var sc := RoadTrip.detour_scene(d)
			var opts: Dictionary = sc["opts"]
			opts["choices"] = choices
			var s2 := TripScene.new().setup(t, sc["pages"], me, "YOU", opts)
			runner.root.add_child(s2)
			for i in s2.pages.size():
				s2.page = i
				s2._show_page()
				s2.shown = s2._text_of(s2._page()).length()
				s2._process(0.0)
				check_layout(s2, "detour %s, page %d (device %d)" % [d["id"], i, dev])
			s2._open_choices()
			for i in choices.size():
				s2.choice_page.select("choice_%d" % i)
				check_layout(s2, "detour %s, choice %d (device %d)" % [d["id"], i, dev])
			s2.free()
		var diner := TripScene.new().setup(t, scenes["diner"], me, "YOU", {"art": "diner", "choices": [
			{"label": "PANCAKES: +3 POWER NEXT MATCH", "enabled": true},
			{"label": "PIE: +3 CONTROL NEXT MATCH", "enabled": true},
			{"label": "COFFEE: +3 SPEED NEXT MATCH", "enabled": true},
			{"label": "THE WORKS: +2 ALL, 20 CASH", "enabled": false, "value": "NEED 20"}]})
		runner.root.add_child(diner)
		diner._open_choices()
		for i in 4:
			diner.choice_page.select("choice_%d" % i)
			check_layout(diner, "the diner's menu, choice %d (device %d)" % [i, dev])
		diner.free()
		var motel := TripScene.new().setup(t, scenes["motel"], me, "YOU", {"art": "motel", "choices": [

			{"label": "SLEEP IT OFF: A HEART BACK", "enabled": false, "value": "FULL"},
			{"label": "PARTNER PRACTISES: +1 EACH STAT", "enabled": true}]})
		runner.root.add_child(motel)
		motel._open_choices()
		check_layout(motel, "the motel's choices (device %d)" % dev)
		motel.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## THE VAN (port ADR-092): every row, every bag item and set, the longest
## names in hand, the locker full, a meal and hazards along the bottom.
func test_trip_van() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := _trip_save("user://test_layout_trip_van/")
	for dev in _devices():
		_device(dev)
		for full in [false, true]:
			var t := RoadTrip.create(4, 5, 3) if full else RoadTrip.create(4, 0, RoadTrip.PEPPER)
			if full:
				t = _full_trip(4)
				t.hearts = RoadTrip.HEARTS_MAX
				t.take("champ_paddle")
				t.take("viking")
				t.meal = "works"
				t.hazards = ["wrong_glasses", "heat_wave", "flat_tire", "storm"]
				t.seed = 99999
				t.partner = 3
			var v := TripVan.new().setup(sv, t)
			runner.root.add_child(v)
			if not v.is_node_ready():
				v._ready()
			for row in v.page.rows:
				v.page.select(String(row["id"]))
				v._refresh()
				check_layout(v, "THE VAN, %s, full %s (device %d)" % [row["id"], full, dev])
			v.page.select("bag")
			for i in v.bag_items().size():
				v.bag_i = i
				v._refresh()
				check_layout(v, "THE VAN, bag item %s" % v.bag_items()[i])
			v.page.select("sets")
			for i in v.sets_shown().size():
				v.set_i = i
				v._refresh()
				check_layout(v, "THE VAN, set %s" % v.sets_shown()[i]["id"])
			for kind in ["paddle", "hat"]:
				v.page.select(kind)
				for k in t.choices_of(kind).size():
					v.page.change(1)
					v._refresh()
					check_layout(v, "THE VAN, %s %s" % [kind, t.paddle if kind == "paddle" else t.hat])
			v.free()
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## The SCRAPBOOK (port ADR-092): every arc with nothing seen, then with
## every chapter seen, each chapter chosen.
func test_trip_scrapbook() -> void:
	var kept := [GameControls.last_device, Settings.pad_glyphs]
	var sv := _trip_save("user://test_layout_trip_scrap/")
	var m := RoadTrip.meta(sv)
	for dev in _devices():
		_device(dev)
		for seen in [false, true]:
			m["beats"] = RoadTrip.data()["beats"].map(func(b): return String(b["id"])) if seen else []
			var h := TripHome.new().setup(sv, {}, "scrapbook")
			runner.root.add_child(h)
			if not h.is_node_ready():
				h._ready()
			eq(h.view, "scrapbook")
			for row in h.scrap_page.rows:
				var id := String(row["id"])
				h.scrap_page.select(id)
				h._scrap_refresh()
				check_layout(h, "the SCRAPBOOK, %s, seen %s (device %d)" % [id, seen, dev])
				if id != "back":
					for k in RoadTrip.arc_seen(m, id).size():
						h.scrap_page.change(1)
						h._scrap_refresh()
						check_layout(h, "the SCRAPBOOK, %s chapter %d" % [id, h.chosen(id)])
			h.free()
	m["beats"] = []
	GameControls.last_device = kept[0]
	Settings.pad_glyphs = kept[1]
	GameControls.device_serial += 1


## The story's stops on the map's panel: the ROAD HOGS, a story detour
## (with and without the ROAD ATLAS), the diner.
func test_trip_story_stops() -> void:
	var sv := _trip_save("user://test_layout_trip_story/")
	var m := RoadTrip.meta(sv)
	m["beats"] = ["van_1", "van_2"]
	m["trips"] = 3
	var t := RoadTrip.create(12, 0, RoadTrip.PEPPER, m)
	t.take("road_atlas")
	var map := TripMap.new().setup(sv, t)
	runner.root.add_child(map)
	if not map.is_node_ready():
		map._ready()
	for n in [t.map[1]["cols"][1].filter(func(x): return x["type"] == "rival")[0],
			t.map[1]["cols"][0].filter(func(x): return x["type"] == "detour")[0],
			{"type": "diner"}]:
		var lines := t.info(n)
		for k in 3:
			map._info[k].text = String(lines[k]) if k < lines.size() else ""
		check_layout(map, "the map's panel on a %s" % n["type"])
	map.free()
