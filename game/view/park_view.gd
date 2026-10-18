## The park (ADR-034, render_park.c): three courts at three skill levels,
## their paddle racks, the clubhouse, and you walking it. Runs OpenPlay at
## a fixed 60 Hz and only ever reads it, apart from the input it passes
## to update() (as MatchView does with the Sim).
##
## Redrawn for the HD port (PORT-19): a 3/4 view from about a second
## storey, closer in, the camera following you. The art and its layout come
## from art/park/build_park.py (assets/park/park.json): park pixels map to
## the world 4x across and 3x down; fences, nets, walls, trees and the rest
## stand as sprites sorted by depth with the people; the clubhouse's roof
## and front wall fade while you're inside. The people are the match
## sprites: the ladder captains and partners in their own looks, you in your
## Player Select colours.
class_name ParkView
extends Node2D

signal play(cfg: SimTypes.MatchConfig)      ## your game is up
signal practice(cfg: SimTypes.MatchConfig)  ## B at the ball machine
signal leave                                ## Start: back to the title

const ART := "res://assets/park/"
const VIEW := Vector2(960, 540)
const PERSON_SCALE := 0.58          ## a person ~62 px tall, by a 64 px fence
const FRAME := 128
const ANCHOR := Vector2(56, 116)
const SLOTS := ["idle0", "idle1", "run0", "run1", "run2", "run3", "windup", "swing",
	"follow", "toss", "cheer", "overhead_windup", "overhead_contact", "reach", "scoop"]
## Display only (render_park.c).
const LEVEL_Y := 32                  ## each court's skill level
const SCORE_Y := 40                  ## over the courts (court top 48)
const RESULT_FRAMES := 240           ## "YOU WON" after a match
const TWO_P_FRAMES := 120            ## "2P JOINED" / "2P LEFT"
const TOP_Y := OpenPlay.COURT_TOP + 24
const BOTTOM_Y := OpenPlay.COURT_TOP + OpenPlay.COURT_H - 10
## A new park ignores input this long (rule 9: the press that opened it).
const INPUT_LOCK_FRAMES := 12
## The courts' aprons (ADR-034 skill levels): teal, gold, red.
const APRONS := [Color("2f9d96"), Color("d2a33a"), Color("c4473c")]
## The labels in the bitmap font, which has no "<".
const LEVEL_LABELS := ["UNDER 3.5", "3.5-4.5", "4.5+"]
const YOU_TINT := Color("6aa0ff")
const SCORE_TINT := Color("fbe46a")

var op: OpenPlay
var save: SaveGame
var anim := 0
var result_timer := 0
var input_lock := INPUT_LOCK_FRAMES
var cam := Vector2.ZERO              ## the view's top-left, in world px
var layout: Dictionary               ## assets/park/park.json
var _world: Node2D                   ## everything that scrolls
var _fading: Array = []              ## sprites that fade while you're inside
var _canopies: Array = []            ## [holder, rect in world]: trees that fade over you
var _fade := 1.0
var message := ""                    ## the panel's text, for tests
var _2p_shown := -1
var _2p_timer := 0
var manifest: Dictionary
var _actors: Node2D
var _overlay: Node2D
var _you: Dictionary
var _court_people: Array = []        ## per court: 4 people (side * 2 + p)
var _bench_people: Array = []
var _scores: Array = []
var _labels: Array = []
var _panel: NinePatchRect
var _panel_text: BitmapText
var _panel_prompts: PromptBar
var _call: BitmapText
var _sfx: Sfx
var _looks := {}                     ## "team:member" -> PlayerLook
var _prompt_key := ""


## `back`: returning from your game (its result shows for a while).
## The park's own music in open play (PORT-22).
func music_track() -> String:
	return "park"


func setup(park: OpenPlay, s: SaveGame, back: bool) -> ParkView:
	op = park
	save = s
	result_timer = RESULT_FRAMES if back and op.last_won != OpenPlay.NONE else 0
	_2p_shown = op.two_players
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/manifest.json"))
	_build()
	_follow(true)
	refresh()
	return self


func _build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(ART + "park.json"))
	var bg := ColorRect.new()
	bg.color = Color("356b2a")
	bg.size = VIEW
	add_child(bg)
	_world = Node2D.new()
	add_child(_world)
	var ground := Sprite2D.new()
	ground.texture = load(ART + "ground.png")
	ground.centered = false
	_world.add_child(ground)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	for spr in layout["sprites"]:
		_add_prop(spr)
	_overlay = ParkOverlay.new()
	_overlay.view = self
	_overlay.z_index = 2
	_world.add_child(_overlay)
	for c in OpenPlay.COURTS:
		var people := []
		for i in 4:
			people.append(_person())
		_court_people.append(people)
		_labels.append(null)               # filled by _build_hud's COURTS panel
		_scores.append(null)
	for i in 4:
		_bench_people.append(_person())
	_you = _person()
	_dress(_you, null)
	_build_hud()
	_build_courts_panel()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)


## A prop from the layout: placed by its foot so the y-sort puts it with
## the people; a long one running into the picture (a side fence or wall)
## is cut into slices, each sorted by its own depth.
func _add_prop(spr: Dictionary) -> void:
	var tex: Texture2D = load(ART + String(spr["file"]))
	var top := Vector2(spr["x"], spr["y"])
	var sort := float(spr["sort"])
	var pieces := []
	if spr.get("slice", false):
		var step := 18
		var h := tex.get_height()
		var r := 0
		while r < h:
			var rh := mini(step, h - r)
			pieces.append([Rect2(0, r, tex.get_width(), rh), top.y + r + rh])
			r += rh
	else:
		pieces.append([Rect2(Vector2.ZERO, tex.get_size()), sort])
	for piece in pieces:
		var holder := Node2D.new()
		holder.position = Vector2(top.x, piece[1])
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = piece[0]
		sp.position = Vector2(0, top.y + piece[0].position.y - piece[1])
		holder.add_child(sp)
		if spr.get("roof", false):
			holder.z_index = 1                # over everyone outside
		_actors.add_child(holder)
		if spr.get("fade_inside", false):
			_fading.append(holder)
		if spr.get("canopy", false):
			_canopies.append([holder, Rect2(top, tex.get_size())])


## Top right: every court at a glance, its level (in its apron colour),
## its score (or NEXT, or YOU) and how many paddles wait in its rack.
func _build_courts_panel() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var plate := NinePatchRect.new()
	plate.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		plate.set(m, 12)
	plate.position = Vector2(668, 10)
	plate.size = Vector2(280, 30 + OpenPlay.COURTS * 24)
	plate.modulate.a = 0.92
	ui.add_child(plate)
	for c in OpenPlay.COURTS:
		var y := 22 + c * 24
		var stripe := ColorRect.new()
		stripe.color = APRONS[c]
		stripe.position = Vector2(682, y + 2)
		stripe.size = Vector2(6, 16)
		ui.add_child(stripe)
		var level := BitmapText.new()
		level.font = "small"
		level.text = LEVEL_LABELS[c]
		level.position = Vector2(696, y)
		ui.add_child(level)
		_labels[c] = level
		var score := BitmapText.new()
		score.font = "small"
		score.align = 1.0
		score.tint = SCORE_TINT
		score.position = Vector2(934, y)
		ui.add_child(score)
		_scores[c] = score


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	# top left: where you are, and the way out
	var chip := NinePatchRect.new()
	chip.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		chip.set(m, 12)
	chip.position = Vector2(12, 10)
	chip.size = Vector2(320, 44)
	ui.add_child(chip)
	var title := BitmapText.new()
	title.font = "small"
	title.text = "OPEN PLAY"
	title.tint = SCORE_TINT
	title.position = Vector2(28, 22)
	ui.add_child(title)
	ui.add_child(PromptBar.new().setup([["start", "EXIT"]], Vector2(236, 32)))
	# bottom: what's here and what you can do
	_panel = NinePatchRect.new()
	_panel.texture = chip.texture
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		_panel.set(m, 12)
	_panel.position = Vector2(220, 474)
	_panel.size = Vector2(520, 56)
	ui.add_child(_panel)
	_panel_text = BitmapText.new()
	_panel_text.font = "small"
	_panel_text.align = 0.5
	_panel_text.position = Vector2(480, 484)
	ui.add_child(_panel_text)
	_panel_prompts = PromptBar.new().setup([], Vector2(480, 514))
	ui.add_child(_panel_prompts)
	_call = BitmapText.new()
	_call.font = "big_gold"
	_call.align = 0.5
	_call.scale = Vector2(2, 2)
	_call.position = Vector2(480, 200)
	ui.add_child(_call)


func _text(font: String, s: String, tint: Color) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.text = s
	t.align = 0.5
	t.tint = tint
	t.z_index = 5
	_world.add_child(t)
	return t


func _person() -> Dictionary:
	var root := Node2D.new()
	root.scale = Vector2(PERSON_SCALE, PERSON_SCALE)
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/levels/" + String(manifest["sprites"]["player_shadow"]["file"]))
	root.add_child(shadow)
	var body := Sprite2D.new()
	var cap := Sprite2D.new()
	for s in [body, cap]:
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, FRAME, FRAME)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(s)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_actors.add_child(root)
	return {"root": root, "body": body, "cap": cap, "who": ""}


## A person's look: a ladder member (PlayerLook), or null for you (your
## Player Select colours, as in your matches).
func _dress(p: Dictionary, look: PlayerLook) -> void:
	var body: Sprite2D = p["body"]
	var cap: Sprite2D = p["cap"]
	if look:
		body.texture = load("res://assets/levels/" + look.body_sheet(manifest))
		var hat := look.hat_sheet(manifest)
		cap.texture = load("res://assets/levels/" + hat) if hat != "" else null
		body.material = look.material()
		cap.material = body.material
		return
	var ch: Dictionary = Settings.p1_choice
	var team: String = PlayerLook.TEAMS[ch["palette"]]
	var variant := "female" if ch["variant"] == K.VARIANT_FEMALE else "male"
	var mine := PlayerLook.for_team(ch["palette"], ch["variant"], ch["paddle"], manifest) \
		if not PlayerLook.sheet_has_paddle(ch["palette"], ch["paddle"]) else null
	if mine:
		body.texture = load("res://assets/levels/" + mine.body_sheet(manifest))
		cap.texture = load("res://assets/levels/" + mine.hat_sheet(manifest))
		body.material = mine.material()
		cap.material = body.material
	else:
		body.texture = load("res://assets/levels/sprites/players/player_%s_%s.png" % [variant, team])
		cap.texture = load("res://assets/levels/sprites/players/player_%s_%s_cap.png" % [variant, team])


func _look(team: int, member: int) -> PlayerLook:
	var key := "%d:%d" % [team, member]
	if not _looks.has(key):
		var members: Array = Opponents.team(team)["players"]
		_looks[key] = PlayerLook.from_member(members[mini(member, members.size() - 1)], manifest)
	return _looks[key]


## A team member on a person, re-dressed only when it changes.
func _show_member(p: Dictionary, team: int, member: int) -> void:
	var who := "%d:%d" % [team, member]
	if p["who"] != who:
		p["who"] = who
		_dress(p, _look(team, member))


func _place(p: Dictionary, x: int, y: int, frame: String, flip: bool) -> void:
	var root: Node2D = p["root"]
	root.visible = true
	root.position = to_world(Vector2(x, y))
	var idx := SLOTS.find(frame)
	for s in [p["body"], p["cap"]]:
		s.region_rect = Rect2(idx * FRAME, 0, FRAME, FRAME)
		s.flip_h = flip
		s.offset = -Vector2((FRAME - 1 - ANCHOR.x) if flip else ANCHOR.x, ANCHOR.y)


## Park px to world px (art/park/build_park.py's projection).
func to_world(park: Vector2) -> Vector2:
	var sc: Array = layout["scale"]
	var mg: Array = layout["margin"]
	return Vector2((park.x + mg[0]) * sc[0], (park.y + mg[1]) * sc[1])


func to_screen(park: Vector2) -> Vector2:
	return to_world(park) - cam


## The camera follows you, easing, a little ahead of where you walk, and
## stops at the park's edges; the clubhouse's roof and front wall fade
## while you're in.
func _follow(snap := false) -> void:
	var size := Vector2(layout["world"][0], layout["world"][1])
	var you := to_world(Vector2(K.from_fp(op.x_fp), K.from_fp(op.y_fp)))
	var lead := Vector2(-40 if op.facing_left else 40, 0) if op.walking else Vector2.ZERO
	# outdoors you sit low in the picture so the courts show; indoors the
	# camera frames the whole room
	var want := you + lead - VIEW * Vector2(0.5, 0.74)
	if op.in_house():
		var r0 := to_world(Vector2(OpenPlay.HOUSE_LEFT, OpenPlay.HOUSE_TOP))
		var r1 := to_world(Vector2(OpenPlay.HOUSE_RIGHT, OpenPlay.HOUSE_BOTTOM))
		want = Vector2((r0.x + r1.x) / 2.0, (r0.y + r1.y) / 2.0 - 40) - VIEW / 2.0
	want = want.clamp(Vector2.ZERO, size - VIEW)
	cam = want if snap or cam == Vector2.ZERO else cam.lerp(want, 0.12)
	_world.position = (-cam).round()
	var target := 0.0 if op.in_house() else 1.0
	_fade = target if snap else lerpf(_fade, target, 0.15)
	for h in _fading:
		# the roof goes; the front wall stays as a ghost so the door reads
		h.modulate.a = _fade if h.z_index > 0 else lerpf(0.25, 1.0, _fade)
	# a tree in front of you lets you show through its canopy
	for t in _canopies:
		var holder: Node2D = t[0]
		var over: bool = t[1].grow(-10).has_point(you - Vector2(0, 30)) and holder.position.y > you.y
		holder.modulate.a = lerpf(holder.modulate.a, 0.4 if over else 1.0, 1.0 if snap else 0.2)


func _physics_process(_delta: float) -> void:
	step_frame()


## One park frame (main.c update_park): Start on pad 2 joins or leaves,
## Start leaves, the D-pad walks, B stacks.
func step_frame(it: SimTypes.Intent = null, pad2_start := false) -> void:
	if it == null:
		it = GameControls.read_intent()
		pad2_start = _pad2_start()
	if input_lock > 0:
		input_lock -= 1
		it = SimTypes.Intent.new()
		pad2_start = false
		GameControls.clear_latch()
	anim = (anim + 1) & 0xff
	if result_timer:
		result_timer -= 1
	if pad2_start and op.called == OpenPlay.NONE:
		op.two_players ^= 1
		_sfx.play("confirm" if op.two_players else "back")
		# 2P's pad: theirs in the match, or back to the PLAYERS setting
		if op.two_players and GameControls.p2_pad == GameControls.NO_PAD:
			GameControls.assign_pads(GameControls.connected_pads(), true)
		elif not op.two_players:
			GameControls.refresh_pads()
	if it.pause_pressed and op.called == OpenPlay.NONE:
		_sfx.play("back")
		leave.emit()
		return
	var b := it.hit_pressed != 0 and it.shot == K.SHOT_STANDARD
	var event := op.update(it.move_x, it.move_y, b)
	if event == OpenPlay.EVENT_STACKED or event == OpenPlay.EVENT_CALLED:
		_sfx.play("confirm")
	elif event == OpenPlay.EVENT_UNSTACKED or event == OpenPlay.EVENT_FULL:
		_sfx.play("back")
	elif event == OpenPlay.EVENT_BOARD:
		_sfx.play("blip")
	if event == OpenPlay.EVENT_PLAY:
		play.emit(Settings.open_play_config(op))
		return
	if event == OpenPlay.EVENT_PRACTICE:
		_sfx.play("confirm")
		practice.emit(save.practice_config(Settings.difficulty_i) if save
			else SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0))
		return
	refresh()


## Pad 2's Start: the pad 2P plays on, or with none assigned, the second
## pad connected (P1 has the first).
func _pad2_start() -> bool:
	var dev := GameControls.p2_pad
	if dev == GameControls.NO_PAD:
		var pads := GameControls.connected_pads()
		pads.sort()
		if pads.size() < 2:
			return false
		dev = pads[1]
	return GameControls.read_pad_intent(dev).pause_pressed != 0


func refresh() -> void:
	_follow()
	var x := K.from_fp(op.x_fp)
	var y := K.from_fp(op.y_fp)
	var frame := "run%d" % ((op.step >> 3) & 3) if op.walking else "idle%d" % ((anim >> 5) & 1)
	_place(_you, x, y, frame, op.facing_left != 0)
	for c in OpenPlay.COURTS:
		_draw_court(c)
		_draw_score(c)
	_draw_bench()
	_draw_message()
	_overlay.queue_redraw()


## A court's two teams and its rally: the ball goes end to end every 32
## frames, landing at a new x each time; the players nearest it step.
func _draw_court(c: int) -> void:
	var ct: OpenPlay.OpenCourt = op.court[c]
	var left := OpenPlay.court_left(c)
	var people: Array = _court_people[c]
	var phase := ct.rally & 31
	var down := (ct.rally & 32) == 0
	var ball_x := ball_x_for(c)
	# Walking: off to the gate in the first 64 frames of a changeover, on
	# from it in the first 64 of a game. 0 at the players' spots, 64 at
	# the gate, -1 nobody on court.
	var walk := 0
	if ct.state == OpenPlay.COURT_CHANGEOVER:
		walk = OpenPlay.CHANGEOVER_FRAMES - ct.timer
		if walk >= OpenPlay.WALK_FRAMES:
			walk = -1
		elif not walk:
			walk = 1
	elif ct.state == OpenPlay.COURT_PLAYING and ct.age < OpenPlay.WALK_FRAMES:
		walk = OpenPlay.WALK_FRAMES - ct.age
	elif ct.state != OpenPlay.COURT_PLAYING:
		walk = -1
	for side in 2:
		for p in 2:
			var person: Dictionary = people[side * 2 + p]
			var team: int = ct.playing[side]
			if walk < 0 or team >= OpenPlay.TEAMS:
				person["root"].visible = false
				continue
			_show_member(person, team, p)
			var px := left + (40 if p else 16)
			var py := BOTTOM_Y if side else TOP_Y
			var frame := "idle%d" % ((anim >> 5) & 1)
			if walk:
				var gate_x := left + OpenPlay.COURT_W / 2
				var gate_y := OpenPlay.COURT_TOP + OpenPlay.COURT_H + 6
				px += ((gate_x - px) * walk) >> 6
				py += ((gate_y - py) * walk) >> 6
				frame = "run%d" % ((anim >> 3) & 3)
			else:
				# The receiving side follows the ball; at its end, a swing.
				var near := down == (side == 1)
				if near and (ball_x < left + OpenPlay.COURT_W / 2) == (p == 0):
					px = (px + ball_x) >> 1
					frame = "swing" if phase >= 28 else "run%d" % ((anim >> 3) & 3)
			_place(person, px, py, frame, p == 1)


## Where the ball lands on a court this rally: a new x at each end.
func ball_x_for(c: int) -> int:
	var ct: OpenPlay.OpenCourt = op.court[c]
	return OpenPlay.court_left(c) + 16 + ((ct.rally >> 5) * 13 + c * 7) % 25


## A court's rally ball in park pixels and its height, or null while
## nobody is playing (or walking).
func ball_at(c: int):
	var ct: OpenPlay.OpenCourt = op.court[c]
	if ct.state != OpenPlay.COURT_PLAYING or ct.age < OpenPlay.WALK_FRAMES:
		return null
	if ct.playing[0] >= OpenPlay.TEAMS or ct.playing[1] >= OpenPlay.TEAMS:
		return null
	var phase := ct.rally & 31
	var track := phase * (BOTTOM_Y - TOP_Y) / 32
	var arc := phase * (32 - phase) / 24          # up to 10 px
	var y := TOP_Y + track if (ct.rally & 32) == 0 else BOTTOM_Y - track
	return Vector3(ball_x_for(c), y - 4, arc + 6)


## "3-5" over a court; NEXT between games; YOU for yours.
func _draw_score(c: int) -> void:
	var ct: OpenPlay.OpenCourt = op.court[c]
	var t: BitmapText = _scores[c]
	var waiting := "  +%d" % ct.stack_count if ct.stack_count else ""
	if ct.state == OpenPlay.COURT_PLAYING:
		t.text = "%d-%d%s" % [ct.score[0], ct.score[1], waiting]
	else:
		t.text = ("YOU" if ct.state == OpenPlay.COURT_YOURS else "NEXT") + waiting


## The bench in the clubhouse: the first two teams waiting, two each
## (16 px apart here, where the SNES's 8 px people stood 12).
func _draw_bench() -> void:
	var x := OpenPlay.BENCH_X
	for team in 2:
		var who := op.waiting_team(team)
		for p in 2:
			var person: Dictionary = _bench_people[team * 2 + p]
			if who == OpenPlay.NONE:
				person["root"].visible = false
			else:
				_show_member(person, who, p)
				_place(person, x, OpenPlay.BENCH_Y + 4, "idle%d" % (((anim >> 5) + p) & 1), p == 1)
			x += 16


func _team_name(entry: int) -> String:
	if entry == OpenPlay.YOU:
		return "YOU"
	if entry < 0 or entry >= OpenPlay.TEAMS:
		return ""
	return String(Opponents.team(entry)["team"])


## The panel (render_park.c park_message): [text, prompts, yellow].
func panel() -> Array:
	var rack := op.rack_near()
	if _2p_shown != op.two_players:
		_2p_shown = op.two_players
		_2p_timer = TWO_P_FRAMES
	if _2p_timer and op.called == OpenPlay.NONE:
		_2p_timer -= 1
		return ["2P JOINED: YOUR PARTNER!" if _2p_shown else "2P LEFT", [], false]
	if op.called != OpenPlay.NONE:
		# "WITH ACE VS TWINS": the captain next in line partners you, or 2P.
		var with := "COURT %d" % (op.called + 1)
		if op.two_players:
			with = "WITH 2P"
		elif op.partner < OpenPlay.TEAMS:
			with = "WITH " + String(Opponents.team(op.partner)["players"][0]["name"])
		return [with + " VS " + _team_name(op.opponent), [], true]
	# Back from your game: its result first, for a few seconds.
	if result_timer and op.last_won != OpenPlay.NONE:
		return ["YOU %s %d-%d" % ["WON" if op.last_won else "LOST", op.last_score[0],
			op.last_score[1]], [], false]
	if op.board_near():
		if op.board_page == OpenPlay.NONE:
			return ["THE RECORDS BOARD", [["hit", "READ"]], false]
		return [board_page(op.board_page), [["hit", "NEXT"]], false]
	if op.machine_near():
		return ["BALL MACHINE", [["hit", "PRACTICE"]], false]
	if op.bench_near() and op.waiting_team(0) != OpenPlay.NONE:
		var s := _team_name(op.waiting_team(0))
		if op.waiting_team(1) != OpenPlay.NONE:
			s += " AND " + _team_name(op.waiting_team(1))
		return [s + " WAIT", [], false]
	if rack != OpenPlay.NONE:
		if op.your_court == rack:
			return ["COURT %d" % (rack + 1), [["hit", "TAKE YOUR PADDLE"]], false]
		if op.court[rack].stack_count >= OpenPlay.STACK_MAX:
			return ["THIS STACK IS FULL", [], false]
		return ["COURT %d  %s" % [rack + 1, LEVEL_LABELS[rack]], [["hit", "STACK YOUR PADDLE"]], false]
	var court := op.court_near()
	if court != OpenPlay.NONE and court != op.your_court \
			and op.court[court].state == OpenPlay.COURT_PLAYING:
		return [_team_name(op.court[court].playing[0]) + " VS " + _team_name(op.court[court].playing[1]),
			[], false]
	var wait := op.your_wait()
	if wait != OpenPlay.NONE:
		return ["YOU'RE NEXT ON COURT %d" % (op.your_court + 1) if wait == 0
			else "WAITING ON COURT %d" % (op.your_court + 1), [], false]
	if op.in_house():
		return ["THE CLUBHOUSE", [["start", "EXIT"]], false]
	return ["YOU AND 2P" if op.two_players else "OPEN PLAY", [["start", "EXIT"]], false]


## A records board page: the title's RECORDS, a line each.
func board_page(page: int) -> String:
	var r: Dictionary = save.data["records"] if save else {}
	var n := func(key: String) -> int: return int(r.get(key, 0))
	match page:
		0:
			return "DOUBLES  WON %d  LOST %d" % [n.call("doubles_wins"), n.call("doubles_losses")]
		1:
			return "SINGLES  WON %d  LOST %d" % [n.call("singles_wins"), n.call("singles_losses")]
		2:
			return "BEST STREAK %d  RALLY %d" % [n.call("best_streak"), n.call("longest_rally")]
	return "CLEARS %d  DRILL BEST %d" % [n.call("ladder_clears"), n.call("practice_best")]


func _draw_message() -> void:
	var m := panel()
	message = m[0]
	_panel_text.text = m[0]
	_panel_text.tint = SCORE_TINT if m[2] else Color.WHITE
	var key := str(m[1])
	if key != _prompt_key:
		_prompt_key = key
		_panel_prompts.set_items(m[1])
	_panel_text.position.y = 482 if not m[1].is_empty() else 494
	_call.text = "YOUR GAME!" if op.called != OpenPlay.NONE else ""


## What moves over the ground: the rally balls and their shadows, and the
## paddles on the racks (yours in your colour, the others grey).
class ParkOverlay:
	extends Node2D

	var view: ParkView

	func _draw() -> void:
		for c in OpenPlay.COURTS:
			var at = view.ball_at(c)
			if at != null:
				var ground := view.to_world(Vector2(at.x, at.y))
				draw_circle(ground + Vector2(0, 3), 4.0, Color(0, 0, 0, 0.35))
				draw_circle(ground - Vector2(0, at.z * 4.0), 5.0, Color("e8f04a"))
				draw_arc(ground - Vector2(0, at.z * 4.0), 5.0, 0, TAU, 12, Color(0.1, 0.12, 0.1), 1.0)
			var ct: OpenPlay.OpenCourt = view.op.court[c]
			# the paddles waiting in the rack: yours in your colour
			var base := view.to_world(Vector2(OpenPlay.rack_x(c), OpenPlay.RACK_Y))
			for i in ct.stack_count:
				var mine: bool = ct.stack[i] == OpenPlay.YOU
				var col := ParkView.YOU_TINT if mine else Color("b8bcc4")
				var top := base + Vector2(-27 + i * 15, -46)
				draw_rect(Rect2(top, Vector2(12, 20)), col)
				draw_rect(Rect2(top, Vector2(12, 20)), Color(0.1, 0.12, 0.16), false, 1.0)
				draw_rect(Rect2(top + Vector2(4, 20), Vector2(4, 12)), Color("4a3a2a"))
