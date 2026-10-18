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
			"winners", "ladder_clears"]:
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
