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
signal leave                                ## Start: back to the title (CLUB: its home)
signal closed                               ## CLUB: closing time, the day is over

const ART := "res://assets/park/"
const VIEW := Vector2(960, 540)
const PERSON_SCALE := 0.58          ## a person ~62 px tall, by a 64 px fence
const FRAME := 128
const ANCHOR := Vector2(56, 116)
const SLOTS := MatchView.SLOTS
## Display only (render_park.c).
const RESULT_FRAMES := 240           ## "YOU WON" after a match
const TWO_P_FRAMES := 120            ## "2P JOINED" / "2P LEFT"
const ROAR_AT := 20                  ## DINO PARK: back from a win, the Carnotaurus roars (ADR-084)
const TOP_Y := OpenPlay.COURT_TOP + 24
const BOTTOM_Y := OpenPlay.COURT_TOP + OpenPlay.COURT_H - 10
## A new park ignores input this long (rule 9: the press that opened it).
const INPUT_LOCK_FRAMES := 12
## The courts' aprons (ADR-034 skill levels): teal, gold, red.
const APRONS := [Color("2f9d96"), Color("d2a33a"), Color("c4473c")]
const LOCKED_TINT := Color(0.55, 0.57, 0.62)
const YOU_TINT := Color("6aa0ff")
const SCORE_TINT := Color("fbe46a")

var op: OpenPlay
var save: SaveGame
var anim := 0
var result_timer := 0
var input_lock := INPUT_LOCK_FRAMES
var cam := Vector2.ZERO              ## the view's top-left, in world px
var layout: Dictionary               ## assets/park/park.json (or a location's)
var art := ART                        ## the location's art folder (ADR-078)
var _world: Node2D                   ## everything that scrolls
var _fading: Array = []              ## sprites that fade while you're inside
var _canopies: Array = []            ## [holder, rect in world]: trees that fade over you
var _fade := 1.0
var message := ""                    ## the panel's text, for tests
var message_text: ParkMessage        ## the panel's text (view/park_message.gd)
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
var dinos: Array = []                ## DINO PARK's dinosaurs (ADR-084): [DinoWalkers.Dino]
var dino_frame := 0                  ## their clock: frames since the park opened
var _prompt_key := ""
## CLUB (port ADR-106): the club whose day this is, or null for open play.
## Its clock runs while you walk (Club.CLOCK_FRAMES a minute), the stacks
## are sampled for the night's wait, and at closing time the park says so
## and closes. The upgrades show: the lamps lit (LIGHTS), the snack cart
## (SNACK BAR), the ball machine (BALL MACHINE), the annex courts on the
## COURTS panel; rain and heat in the air; the trophies in the clubhouse.
var club: Club
var closing_timer := 0
const CLOSING_FRAMES := 150
const SAMPLE_FRAMES := 60
var _club_frames := 0
var _clock: BitmapText
var _night: CanvasModulate
var _air: Node2D
var lamps: Array = []                ## the lamps' heads, in the world
var snack_props: Array = []          ## the SNACK BAR's cart and cooler, when bought
var machine_shown := true


## `back`: returning from your game (its result shows for a while).
## The park's own music in open play (PORT-22).
func _init() -> void:
	message_text = ParkMessage.new(self)


func music_track() -> String:
	return "park"


func setup(park: OpenPlay, s: SaveGame, back: bool, the_club: Club = null) -> ParkView:
	op = park
	save = s
	club = the_club
	result_timer = RESULT_FRAMES if back and op.last_won != OpenPlay.NONE else 0
	_2p_shown = op.two_players
	rate_park()
	manifest = MatchView.levels_manifest()
	_build()
	_follow(true)
	refresh()
	return self


## The career player's park (main.c's park entry): the teams they have
## beaten to pick as partners (SNES ADR-072), and their rating, which
## locks the courts above it (ADR-070); no player, or KID, rates nothing.
func rate_park() -> void:
	var player: Career.Player = save.career.active_player() if save else null
	var teams := 0
	for t in Career.TEAMS:
		if player and player.beaten[t]:
			teams |= 1 << t
	op.partners(teams)
	if player == null or Settings.difficulty_i == K.DIFFICULTY_KID:
		op.rate(OpenPlay.RATING_NONE, 0)
	else:
		op.rate(Career.park_rating(player), Career.park_court(player))


func _build() -> void:
	art = Settings.park_art()                 # ADR-078: THE PARK, DINO PARK or THE GYM
	if club:
		art = String(Settings.PARKS[club.park_index()][2])   # the club's: the park, or the gym in the rain
	layout = JSON.parse_string(FileAccess.get_file_as_string(art + "park.json"))
	var bg := ColorRect.new()
	bg.color = Color(String(layout.get("bg", "356b2a")))
	bg.size = VIEW
	add_child(bg)
	_world = Node2D.new()
	add_child(_world)
	var ground := Sprite2D.new()
	ground.texture = load(art + "ground.png")
	ground.centered = false
	_world.add_child(ground)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	for spr in layout["sprites"]:
		if club and String(spr["file"]) == "machine.png" and not club.owns("machine"):
			machine_shown = false
			continue                          # the club hasn't bought one yet
		_add_prop(spr)
		if String(spr["file"]).begins_with("lamp_"):
			var tex: Texture2D = load(art + String(spr["file"]))
			lamps.append(Vector2(float(spr["x"]) + tex.get_width() / 2.0, float(spr["y"]) + 8.0))
	if club and club.owns("snack") and art == ART:
		# the SNACK BAR: the gym's cart and cooler, by the path at the clubhouse
		for prop in [{"file": "cart_0.png", "x": 1150, "y": 640}, {"file": "cooler_0.png", "x": 1236, "y": 690}]:
			var tex: Texture2D = load(ART + "gym/" + String(prop["file"]))
			var holder := Node2D.new()
			holder.position = Vector2(prop["x"], prop["y"] + tex.get_height())
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.position = Vector2(0, -tex.get_height())
			holder.add_child(sp)
			_actors.add_child(holder)
			snack_props.append(holder)
	if layout.get("theme", "") == "dino":
		for c: Dictionary in DinoWalkers.PARK_CAST:
			var d := DinoWalkers.Dino.new(c)
			if c["layer"] == "air":
				d.spr.z_index = 3              # over the trees' canopies
				_world.add_child(d.spr)
			else:
				_actors.add_child(d.spr)       # sorted by its feet with the people
			if result_timer and op.last_won == 1:
				d.roar(ROAR_AT)                # back from a win: the Carnotaurus roars
			dinos.append(d)
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
	if club:
		_build_club()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)


## A prop from the layout: placed by its foot so the y-sort puts it with
## the people; a long one running into the picture (a side fence or wall)
## is cut into slices, each sorted by its own depth.
func _add_prop(spr: Dictionary) -> void:
	var tex: Texture2D = load(art + String(spr["file"]))
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
	var plate := UiKit.panel(Rect2(Vector2(668, 10), Vector2(280, 30 + OpenPlay.COURTS * 24)), ui)
	plate.modulate.a = 0.92
	for c in OpenPlay.COURTS:
		var y := 22 + c * 24
		var stripe := ColorRect.new()
		stripe.color = APRONS[c]
		stripe.position = Vector2(682, y + 2)
		stripe.size = Vector2(6, 16)
		ui.add_child(stripe)
		var level := BitmapText.new()
		level.font = "small"
		level.text = OpenPlay.court_level_name(c)
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
	var chip := UiKit.panel(Rect2(Vector2(12, 10), Vector2(590 if club else 320, 44)), ui)
	var title := BitmapText.new()
	title.font = "small"
	title.text = "CLUB" if club else "OPEN PLAY"
	title.tint = SCORE_TINT
	title.position = Vector2(28, 22)
	ui.add_child(title)
	ui.add_child(PromptBar.new().setup([["start", "HOME" if club else "EXIT"]], Vector2(500 if club else 236, 32)))
	if club:
		_clock = UiKit.text("small", "", Vector2(96, 22), 0.0, Color.WHITE, ui)
	# bottom: what's here and what you can do
	_panel = UiKit.panel(Rect2(220, 474, 520, 56), ui)
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
	var t := UiKit.text(font, s, Vector2.ZERO, 0.5, tint, _world)
	t.z_index = 5
	return t


func _person() -> Dictionary:
	var root := Node2D.new()
	root.scale = Vector2(PERSON_SCALE, PERSON_SCALE)
	var shadow := Sprite2D.new()
	shadow.texture = load(MatchView.LEVELS + String(manifest["sprites"]["player_shadow"]["file"]))
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
## career player, else your Player Select colours, as in your matches).
func _dress(p: Dictionary, look: PlayerLook) -> void:
	var body: Sprite2D = p["body"]
	var cap: Sprite2D = p["cap"]
	if look:
		body.texture = look.body_texture(manifest)
		cap.texture = look.hat_texture(manifest)
		body.material = look.material()
		cap.material = body.material
		return
	# ADR-047: you walk the park as your career player.
	var me: Career.Player = save.career.active_player() if save else null
	if me:
		var mine := PlayerLook.for_career(me, me.shirt, me.variant, me.paddle, manifest)
		body.texture = mine.body_texture(manifest)
		cap.texture = mine.hat_texture(manifest)
		body.material = mine.material()
		cap.material = body.material
		return
	var ch: Dictionary = Settings.p1_choice
	var team: String = PlayerLook.TEAMS[ch["palette"]]
	var variant := PlayerLook.variant_name(ch["variant"])
	var mine := PlayerLook.for_team(ch["palette"], ch["variant"], ch["paddle"], manifest) \
		if not PlayerLook.sheet_has_paddle(ch["palette"], ch["paddle"]) else null
	if mine:
		body.texture = load(MatchView.LEVELS + mine.body_sheet(manifest))
		cap.texture = load(MatchView.LEVELS + mine.hat_sheet(manifest))
		body.material = mine.material()
		cap.material = body.material
	else:
		body.texture = load(MatchView.LEVELS + PlayerLook.team_sheet(variant, team, false))
		cap.texture = load(MatchView.LEVELS + PlayerLook.team_sheet(variant, team, true))


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
	dino_frame += 1
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
	if club and _club_frame():
		return
	# Y (SLICE) at your rack picks your partner (SNES ADR-072).
	if it.hit_pressed != 0 and it.shot == K.SHOT_SLICE and op.pick_next():
		_sfx.play("blip")
	var b := it.hit_pressed != 0 and it.shot == K.SHOT_STANDARD
	var event := op.update(it.move_x, it.move_y, b)
	if event == OpenPlay.EVENT_STACKED or event == OpenPlay.EVENT_CALLED:
		_sfx.play("confirm")
	elif event == OpenPlay.EVENT_UNSTACKED or event == OpenPlay.EVENT_FULL \
			or event == OpenPlay.EVENT_LOCKED:
		_sfx.play("back")
	elif event == OpenPlay.EVENT_BOARD:
		_sfx.play("blip")
	if event == OpenPlay.EVENT_PLAY:
		play.emit(Settings.open_play_config(op, save.career.active_player() if save else null))
		return
	if event == OpenPlay.EVENT_PRACTICE and not machine_shown:
		event = OpenPlay.EVENT_NONE           # the club has no ball machine yet
		_sfx.play("back")
	if event == OpenPlay.EVENT_PRACTICE:
		_sfx.play("confirm")
		var cfg: SimTypes.MatchConfig = save.practice_config(Settings.difficulty_i) if save \
			else SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0)
		if save:
			cfg.set_career_p1(save.career.active_player())     # ADR-047
		practice.emit(cfg)
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


# --- CLUB (port ADR-106) ---------------------------------------------------------------

func _build_club() -> void:
	_night = CanvasModulate.new()
	add_child(_night)
	var air_layer := CanvasLayer.new()
	air_layer.layer = 5
	add_child(air_layer)
	_air = ParkAir.new()
	_air.view = self
	air_layer.add_child(_air)
	# the annex courts under the park's three on the COURTS panel
	var annexes := club.courts_today() - OpenPlay.COURTS   # none at the gym: they're outdoors
	if annexes > 0:
		var ui := CanvasLayer.new()
		ui.layer = 10
		add_child(ui)
		var top := 10 + 30 + OpenPlay.COURTS * 24 + 6
		var plate := UiKit.panel(Rect2(Vector2(668, top), Vector2(280, 18 + annexes * 24)), ui)
		plate.modulate.a = 0.92
		for a in annexes:
			var y := top + 10 + a * 24
			var stripe := ColorRect.new()
			stripe.color = Color("8a93a6")
			stripe.position = Vector2(682, y + 2)
			stripe.size = Vector2(6, 16)
			ui.add_child(stripe)
			UiKit.text("small", "ANNEX %d" % (a + 1), Vector2(696, y), 0.0, Color.WHITE, ui)
			UiKit.text("small", "MEMBERS", Vector2(934, y), 1.0, SCORE_TINT, ui)


## The club's frame: the clock, the stacks sampled, closing time. True
## when the park has closed (the signal is sent).
func _club_frame() -> bool:
	if op.called != OpenPlay.NONE:
		return false                          # the call banner: your game is up
	if closing_timer > 0:
		closing_timer -= 1
		if closing_timer == 0:
			closed.emit()
			return true
		refresh()
		return true
	_club_frames += 1
	if _club_frames % Club.CLOCK_FRAMES == 0:
		club.advance(1)
	if _club_frames % SAMPLE_FRAMES == 0:
		var waiting := 0
		for ct: OpenPlay.OpenCourt in op.court:
			waiting += ct.stack_count
		club.sample_wait(waiting)
	if club.closed_for_today():
		closing_timer = CLOSING_FRAMES
		_sfx.play("confirm")
		refresh()
		return true
	return false


## How dark the park is at the club's hour: day, dusk, night (display only).
func club_light() -> Color:
	var m := club.minute
	if m < Club.DUSK_AT:
		return Color(1.0, 0.95, 0.84) if club.weather() == Club.HOT else Color.WHITE
	var dusk := Color(1.0, 0.82, 0.68)
	var night := Color(0.42, 0.46, 0.66)
	if m < Club.CLOSE:
		return Color.WHITE.lerp(dusk, float(m - Club.DUSK_AT) / (Club.CLOSE - Club.DUSK_AT))
	return dusk.lerp(night, clampf(float(m - Club.CLOSE) / 60.0, 0.0, 1.0))


func lamps_lit() -> bool:
	return club != null and club.owns("lights") and club.minute >= Club.DUSK_AT and art != ART + "gym/"


func _refresh_club() -> void:
	_night.color = Color.WHITE if art == ART + "gym/" else club_light()
	_clock.text = club.day_label() + "  " + Club.clock_label(club.minute)
	_air.queue_redraw()


func refresh() -> void:
	if club:
		_refresh_club()
	_follow()
	var x := K.from_fp(op.x_fp)
	var y := K.from_fp(op.y_fp)
	var frame := "run%d" % ((op.step >> 3) & 3) if op.walking else "idle%d" % ((anim >> 5) & 1)
	_place(_you, x, y, frame, op.facing_left != 0)
	for c in OpenPlay.COURTS:
		_draw_court(c)
		_draw_score(c)
	_draw_bench()
	for d: DinoWalkers.Dino in dinos:
		d.spr.position = d.dress(dino_frame).round()
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
func ball_at(c: int) -> Variant:
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
	# A court above your rating (ADR-070): its name greyed, its floor shown.
	var label: BitmapText = _labels[c]
	label.tint = Color.WHITE if op.court_open(c) else LOCKED_TINT
	if not op.court_open(c):
		t.text = "%d PTS" % OpenPlay.rating_points(OpenPlay.court_floor(c))


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


## The panel's text, prompts and colour, and a board page (ParkMessage).
func panel() -> Array:
	return message_text.panel()


func board_page(page: int) -> String:
	return message_text.board_page(page)


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
		if view.lamps_lit():
			for head: Vector2 in view.lamps:
				draw_circle(head, 46.0, Color(1.0, 0.92, 0.6, 0.12))
				draw_circle(head, 22.0, Color(1.0, 0.95, 0.7, 0.25))
				draw_circle(head, 7.0, Color(1.0, 0.98, 0.85, 0.9))
		if view.club and view.op.in_house():
			_draw_trophies()
		for c in OpenPlay.COURTS:
			var at: Variant = view.ball_at(c)
			if at != null:
				var ground := view.to_world(Vector2(at.x, at.y))
				draw_circle(ground + Vector2(0, 3), 4.0, Color(0, 0, 0, 0.35))
				draw_circle(ground - Vector2(0, at.z * 4.0), 5.0, Color("e8f04a"))
				draw_arc(ground - Vector2(0, at.z * 4.0), 5.0, 0, TAU, 12, Color(0.1, 0.12, 0.1), 1.0)
			var ct: OpenPlay.OpenCourt = view.op.court[c]
			# the paddles waiting in the rack, a pair for each team waiting
			# (one a player, as real paddle stacking reads; PORT-60), the
			# teams a little apart, yours in your colour
			var base := view.to_world(Vector2(OpenPlay.rack_x(c), OpenPlay.RACK_Y))
			for i in ct.stack_count:
				var mine: bool = ct.stack[i] == OpenPlay.YOU
				var col := ParkView.YOU_TINT if mine else Color("b8bcc4")
				for k in 2:
					var top := base + Vector2(-31 + i * 16 + k * 7, -46 + k * 2)
					draw_rect(Rect2(top, Vector2(7, 17)), col if k == 0 else col.darkened(0.12))
					draw_rect(Rect2(top, Vector2(7, 17)), Color(0.1, 0.12, 0.16), false, 1.0)
					draw_rect(Rect2(top + Vector2(2, 17), Vector2(3, 11)), Color("4a3a2a"))


	## The WEEKEND CUPs won, on the clubhouse's back wall by the board.
	func _draw_trophies() -> void:
		var shelf := view.to_world(Vector2(OpenPlay.BOARD_X + 34, OpenPlay.BOARD_Y - 6))
		var n := mini(view.club.trophies.size(), 12)
		if n == 0:
			return
		draw_rect(Rect2(shelf + Vector2(-6, 30), Vector2(n * 26 + 8, 6)), Color("6b4a2e"))
		for i in n:
			var at := shelf + Vector2(i * 26, 0)
			var gold := Color("f2c84b")
			draw_rect(Rect2(at + Vector2(6, 22), Vector2(10, 8)), gold.darkened(0.25))
			draw_rect(Rect2(at + Vector2(9, 14), Vector2(4, 8)), gold.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([at, at + Vector2(22, 0), at + Vector2(17, 14),
				at + Vector2(5, 14)]), gold)
			draw_polyline(PackedVector2Array([at, at + Vector2(22, 0), at + Vector2(17, 14),
				at + Vector2(5, 14), at]), Color(0.3, 0.2, 0.05), 1.0)


## CLUB's air over the park (display only): rain on a wet day, the heat's
## shimmer on a hot one; never at the gym.
class ParkAir:
	extends Node2D

	var view: ParkView

	func _draw() -> void:
		if view.club == null or view.art == ParkView.ART + "gym/":
			return
		var w := view.club.weather()
		if w == Club.SHOWERS or w == Club.RAIN:
			ClubHome.ClubWeather.draw_rain(self, view.anim + view._club_frames, 70)
		elif w == Club.HOT:
			for i in 6:
				var y := 120.0 + i * 64.0 + sin((view._club_frames + i * 20) * 0.05) * 6.0
				var pts := PackedVector2Array()
				for k in 25:
					pts.append(Vector2(k * 40.0, y + sin(k * 0.9 + view._club_frames * 0.08 + i) * 3.0))
				draw_polyline(pts, Color(1.0, 0.92, 0.75, 0.2), 8.0)
