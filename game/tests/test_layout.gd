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
	for i in ts.size():
		var r: Rect2 = rects[i]
		for pr in panels:
			# inside a panel means clear of its frame; otherwise fully outside it
			if r.intersects(pr.grow(-SLACK)) and not pr.grow_individual(-PANEL_EDGE_X, -PANEL_EDGE_Y,
					-PANEL_EDGE_X, -PANEL_EDGE_Y).encloses(r):
				_fail("%s: \"%s\" %s crosses a panel's edge %s" % [where, ts[i].text,
					r.position.round(), pr], ts[i].text + "|edge")
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
	var s := SaveGame.new()
	s.dir = "user://test_layout/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(s.dir))
	for f in SaveGame.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(s.dir + f))
	s.load_game()
	# big numbers and holders, so the record lines are at their widest
	var r: Dictionary = s.data["records"]
	for k in ["singles_wins", "singles_losses", "doubles_wins", "doubles_losses", "points_won",
			"points_lost", "longest_rally", "best_streak", "practice_best", "shutouts", "aces",
			"winners", "ladder_clears", "cups"]:
		r[k] = 188
	s.data["initials"] = {"best_streak": "WWW", "longest_rally": "MMM"}
	return s


func _title() -> TitleScreen:
	var t := TitleScreen.new()
	t.save = _save()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	return t


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


## The HUD in its states, against every ladder team (the longest names).
func test_hud() -> void:
	for opp in range(-1, Opponents.count()):
		for doubles in [false, true]:
			var v := _view(Settings.config_for(doubles, opp, K.DIFFICULTY_MEDIUM, 11))
			var tag := "hud %s vs %d" % ["doubles" if doubles else "singles", opp]
			check_layout(v, tag)
			v.sim.team_score = [10, 9]
			v._hud.refresh()
			check_layout(v, tag + " match point")
			v.sim.paused = 1
			v._update_visuals()
			check_layout(v, tag + " paused")
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
	var t := TitleScreen.new()
	t.save = s
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
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
	var title := TitleScreen.new()
	title.save = s2
	runner.root.add_child(title)
	if not title.is_node_ready():
		title._ready()
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
