## A match on screen: the venue's parallax layers, the y-sorted players,
## ball, and near net post, effects from sim events, crowd, and the HUD.
## Runs the sim at a fixed 60 Hz and only ever reads it (playbook rule 2).
class_name MatchView
extends Node2D

signal finished(to_title: bool)
signal next_rung

const LEVELS := "res://assets/levels/"
const TEAM_NAMES := ["BLUE", "RED", "GREEN", "GOLD"]
const TEAM_TINTS := [Color("6aa0ff"), Color("ff5a50"), Color("6ad860"), Color("ffd040")]
const FRAME := 128
const ANCHOR := Vector2(56, 116)
const SLOTS := ["idle0", "idle1", "run0", "run1", "run2", "run3", "windup", "swing",
	"follow", "toss", "cheer", "overhead_windup", "overhead_contact", "reach", "scoop",
	"thumbs_up", "flex", "en_garde", "slump", "dive", "scramble"]
## Input is ignored this long after a match starts, so the press that
## started it can't also serve (playbook rule 9).
const INPUT_LOCK_FRAMES := 12

var glide := BallGlide.new()       ## a paced ball drawn gliding (ADR-073)
var tuning: TuningPanel            ## F2 / TUNE (ADR-074); null in the demo
var highlight: Highlight           ## PLAY OF THE MATCH (ADR-075); null when there's none
var _base_time := CourtStyle.DAY    ## the owner's time and court, before GLOW's
var _base_court: Array = []
var sim: Sim
var venue := "park"
var manifest: Dictionary
var demo := false
var input_lock := 0
var save: SaveGame              ## records (null: none kept)
var ladder := false             ## a ladder match: intro card, next rung
## A tournament match (PORT-25): the intro card, the result recorded in the
## bracket, and B on the result goes back to it (finished(false)).
var tournament := false
var cup_key := "bracket"        ## the save's bracket: "bracket", or the couch cup's (PORT-29)
## HOW TO PLAY (PORT-30): the lesson this match is, or null; its overlay.
## A lesson finishes with finished(false); its match never ends (a
## finished one starts again) and nothing is recorded (save is null).
var lesson: Tutorial
var lesson_view: TutorialView
## Online (PORT-31, ADR-056): the session (null offline). The host plays
## slot 0, the guest slot 2. Nothing is recorded (save is null); Menu never
## pauses: pressed twice in play (once on the result) it leaves.
var net: OnlineSession
var leave_frames := 0            ## counting down after a first Menu press online
var _net_text: BitmapText


## The team this machine plays (online, the guest's is 1).
func my_team() -> int:
	return 1 if net and not net.host else 0
## From the park (ADR-034): B on the result, or PARK on practice's pause
## menu, goes back there (finished(false)).
var park := false
## STORY (ADR-069): a chapter's match; B on the result goes on (main.gd).
var story_mode := false
var story := Story.new()
## The intro card (ADR-026): the match waits under it, no sim, no AI.
var card_frames := -1
const CARD_MIN_FRAMES := 30
const CARD_MAX_FRAMES := 300
var _prev_phase := -1
var cleared := false            ## this match cleared the ladder
## Camera (ADR-050/051): the lean toward the ball (CameraLean).
var camera := CameraLean.new()
var _layers: Array = []          # [Sprite2D, origin, parallax]
## Court colours (ADR-022/027): [surface, kitchen, surround, lines] presets.
var court: Array = CourtStyle.DEFAULTS.duplicate()
## Time of day (ADR-045): CourtStyle.DAY, DUSK or NIGHT.
var time := CourtStyle.DAY
var _ground: Sprite2D

var _actors: Node2D
var _shadows: Node2D
var _fx: Node2D
var crowd: Crowd
var watcher: Watcher             ## the partner sitting out, or null
var _players: Array = []         # per slot: {root, body, cap, shadow, choice, look}
var _ball_root: Node2D
var _ball_sprite: Sprite2D
var _ball_shadow: Sprite2D
var _multi_balls: Array = []     ## MULTI BALL's other balls: [root, sprite, shadow]
var _ball_frame := 0.0
var _hud: Hud
var _sfx: Sfx
var _debug: DebugOverlay
var feel: Feel
var flair: Flair                 ## SNES ADR-064: reactions, emotes, the net's shiver
## SNES ADR-054: GLOW plays at NIGHT with the LINES preset LIME.
const GLOW_TIME := 2
const GLOW_LINES := 4
var critter: Critter             ## SNES ADR-064: the venue's gull, satellite or fish
var wind_view: WindView          ## WIND's streaks (port ADR-065)
var heat: RallyHeat              ## PORT-43: a long rally's fire
var focus: RallyHeat.FocusDim    ## ... and its focus
## This match's stats (PORT-13), from the events; display only.
var stats := MatchStats.new()
## The parts (PORT-27): the people and ball, the input, the match's end.
var actors := MatchActors.new(self)
var input := MatchInput.new(self)
var end := MatchEnd.new(self)
## Kept on the view for the HUD, the tools and the tests.
var initials: Initials:
	get: return end.initials
var unlock_frames: int:
	get: return end.unlock_frames
	set(value): end.unlock_frames = value
var cup_finish: String:
	get: return end.cup_finish
func unlock_open() -> bool: return end.unlock_open()
func pause_rows() -> Array: return input.pause_rows()
func _spawn_fx(kind: String, at: Vector2, start: int) -> void: actors.spawn_fx(kind, at, start)


## The venue's match loop (PORT-22); a match's end stings over it.
func music_track() -> String:
	return Music.match_track(venue)


## The art's manifest.json, read once: every screen that draws the
## generated art reads it, and nothing writes to it.
static var _manifest := {}

static func levels_manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(LEVELS + "manifest.json"))
	return _manifest


func setup(cfg: SimTypes.MatchConfig, venue_name: String, is_demo: bool) -> void:
	venue = venue_name
	demo = is_demo
	_base_time = time
	_base_court = court.duplicate()
	if cfg.modifiers & K.MOD_GLOW:
		# SNES ADR-054: lights out (NIGHT), LIME lines
		time = GLOW_TIME
		court = court.duplicate()
		court[3] = GLOW_LINES
	manifest = levels_manifest()
	sim = Sim.new(cfg)
	if tuning == null and not demo:
		tuning = TuningPanel.new().setup(self)     # before the HUD: the pause menu's TUNE
	if demo:
		sim.start_attract()
	input_lock = INPUT_LOCK_FRAMES
	if (ladder or tournament or cfg.opponent == Opponents.DAWSON) and cfg.opponent >= 0 \
			and not cfg.human[2]:
		card_frames = 0
	_build()
	# place everyone now: until the first tick they'd stand at the origin,
	# which showed as a player in the top-left corner each time the title
	# restarted its demo (a new venue or time of day)
	_update_visuals()


## Freed (a match over, the title's demo restarting): release the sim,
## which otherwise lives on in its own reference cycle.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and sim:
		sim.dispose()


func _tex(rel: String) -> Texture2D:
	return load(LEVELS + rel)


func _build() -> void:
	var vm: Dictionary = manifest["venues"][venue]
	var z := 0
	for layer in vm["layers"]:
		if layer["name"] == "net":
			# PORT-43: a long rally dims everything behind the net but the
			# court (the backdrop, stands, crowd and surround)
			focus = RallyHeat.FocusDim.new().setup(self, z)
			add_child(focus)
			z += 1
		var s := Sprite2D.new()
		s.texture = _tex(layer["file"])
		s.centered = false
		s.position = Vector2(layer["origin"][0], layer["origin"][1])
		s.z_index = z
		add_child(s)
		_layers.append([s, s.position, float(layer["parallax"])])
		var scales := CourtStyle.time_scales(time)
		if layer["name"] == "ground":
			_ground = s
			s.material = CourtStyle.material(court, venue, manifest, time)
		else:
			# the net is under the lights; the backdrop and the stands aren't
			s.modulate = scales[1] if layer["name"] == "net" else scales[0]
		z += 1
		if layer["name"] == "stands":
			var dark: Color = CourtStyle.time_scales(time)[0]       # they sit in the dark
			crowd = Crowd.new().setup(manifest, venue, dark)
			crowd.z_index = z
			add_child(crowd)
			if Watcher.wanted(sim.config, demo, manifest, venue):
				watcher = Watcher.new().setup(sim.config, manifest, venue, dark)
				watcher.z_index = z
				add_child(watcher)
				crowd.vacate(watcher.spot)
				watcher.update(sim)
			z += 1
		if layer["name"] == "ground" and sim.config.modifiers & K.MOD_LAVA:
			_build_lava(z)
			z += 1
		if layer["name"] == "front" and focus:
			focus.dim_too(s)
		if layer["name"] == "net":
			_shadows = Node2D.new()
			_shadows.z_index = z
			add_child(_shadows)
			_actors = Node2D.new()
			_actors.y_sort_enabled = true
			_actors.z_index = z + 1
			add_child(_actors)
			z += 2
	_fx = Node2D.new()
	_fx.z_index = z + 1
	add_child(_fx)
	actors.build_players()
	actors.build_ball()
	feel = Feel.new()
	_fx.add_child(feel)
	feel.setup(self)
	flair = Flair.new().setup(sim, demo)
	_fx.add_child(flair)
	heat = RallyHeat.new().setup(self)
	_fx.add_child(heat)
	critter = Critter.for_venue(venue, sim)
	if critter:
		add_child(critter)
	if sim.config.modifiers & K.MOD_WIND:
		wind_view = WindView.new().setup(sim)
		add_child(wind_view)
	# the sky's critter and the wind dim with the backdrop on a long rally
	for n: CanvasItem in [critter, wind_view]:
		if n and focus:
			focus.dim_too(n)
	if sim.config.practice and not demo:
		_shadows.add_child(PracticeView.zone(sim.practice))
		_actors.add_child(PracticeView.machine(sim.practice))
	var post_meta: Dictionary = manifest["sprites"]["net_post"]
	var post := Sprite2D.new()
	post.texture = _tex(post_meta["file"])
	post.centered = false
	post.offset = -Vector2(post_meta["anchor"][0], post_meta["anchor"][1])
	post.position = Vector2(post_meta["position"][0], post_meta["position"][1])
	_actors.add_child(post)
	if sim.config.modifiers & K.MOD_INVERSE:
		var layer := CanvasLayer.new()
		layer.layer = 9                  # just under the HUD's
		var neg := ColorRect.new()
		neg.set_anchors_preset(Control.PRESET_FULL_RECT)
		neg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		neg.material = ShaderMaterial.new()
		neg.material.shader = preload("res://view/invert.gdshader")
		layer.add_child(neg)
		add_child(layer)
	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(self)
	if lesson:
		lesson_view = TutorialView.new().setup(self)
		_hud.add_child(lesson_view)
	if net:
		_net_text = UiKit.text("small", "", Vector2(480, 452), 0.5, Color("fbe46a"), _hud)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup(venue, demo, CourtStyle.time_ambience(time))
	_tint_shadows()
	_debug = DebugOverlay.new()
	_debug.view = self
	add_child(_debug)
	if tuning and tuning.get_parent() == null:
		add_child(tuning)
	highlight = Highlight.new(self)
	if not highlight.wanted():
		highlight = null


## The tuning panel's APPLY (ADR-074): the match rebuilt in place with a new
## config, from 0-0, as RESTART does (its new records dropped). The owner's
## fields (save, ladder, story, the venue, time and court) stay.
func rebuild(cfg: SimTypes.MatchConfig) -> void:
	if tuning:
		remove_child(tuning)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	sim.dispose()
	_layers = []
	_players = []
	_multi_balls = []
	for f in ["crowd", "watcher", "critter", "wind_view", "focus", "heat", "close_call",
			"lesson_view", "_ground", "_net_text"]:
		set(f, null)
	glide = BallGlide.new()
	stats = MatchStats.new()
	actors = MatchActors.new(self)
	input = MatchInput.new(self)
	end = MatchEnd.new(self)
	card_frames = -1
	_prev_phase = -1
	cleared = false
	time = _base_time
	court = _base_court.duplicate()
	if save:
		save.drop_new_records()
		save.career.new_unlocks = 0
	setup(cfg, venue, demo)


## Recolours the court (the title's COURT page previews on the demo).
func set_court(choice: Array) -> void:
	court = choice.duplicate()
	if _ground:
		_ground.material = CourtStyle.material(court, venue, manifest, time)
	_tint_shadows()


## The ground layer's top-left at rest (the close-up crops it).
func _ground_origin() -> Vector2:
	for l in _layers:
		if l[0] == _ground:
			return l[1]
	return Vector2.ZERO


# --- The close call (ADR-041) and the watcher (ADR-042) ------------------------------

var close_call: CloseCall


## On the point result's first frame (game.c calls replay_check there).
func _check_close_call() -> void:
	if sim.config.practice:
		return
	var c := Replay.check(sim.ball.x_fp, sim.ball.y_fp, (sim.shot_serial - sim.rally_start) & 0xff,
		sim.last_fault)
	if c.is_empty():
		return
	close_call = CloseCall.new().setup(self, c)
	_hud.add_child(close_call)
	_hud.move_child(close_call, 0)


func _end_close_call() -> void:
	if close_call:
		close_call.queue_free()
		close_call = null


## Shadows draw grey on a court too dark for them (CourtStyle.grey_shadows).
var shadow_grey := false

func _tint_shadows() -> void:
	shadow_grey = CourtStyle.grey_shadows(court, venue, manifest, time)
	var mat: ShaderMaterial = null
	if shadow_grey:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://view/shadow_tint.gdshader")
		mat.set_shader_parameter("tint", CourtStyle.SHADOW_GREY)
	if sim.config.modifiers & K.MOD_INVERSE:
		# drawn as their negative (white, or the grey's), so the inversion
		# over the picture leaves them dark, as on the SNES
		var tint: Color = CourtStyle.SHADOW_GREY if shadow_grey else Color(0, 0, 0, 1)
		mat = ShaderMaterial.new()
		mat.shader = preload("res://view/shadow_tint.gdshader")
		mat.set_shader_parameter("tint", Color(Color.WHITE - tint, tint.a if shadow_grey else 1.0))
		mat.set_shader_parameter("keep_alpha", not shadow_grey)
	for e in _players:
		e["shadow"].material = mat
	if _ball_shadow:
		_ball_shadow.material = mat


## LAVA (ADR-033): the kitchens glow, so the rule reads at a glance.
var _lava: Array = []

func _build_lava(z: int) -> void:
	for side in [[K.COURT_KITCHEN_LEFT_X, K.COURT_NET_X], [K.COURT_NET_X, K.COURT_KITCHEN_RIGHT_X]]:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		# inset a little so the painted lines stay crisp on top
		var inset := [[3, 3], [-3, 3], [-3, -2], [3, -2]]
		var k := 0
		for c in [[side[0], K.COURT_SIDELINE_TOP], [side[1], K.COURT_SIDELINE_TOP],
				[side[1], K.COURT_SIDELINE_BOTTOM], [side[0], K.COURT_SIDELINE_BOTTOM]]:
			pts.append(CourtView.ground(K.to_fp(c[0]), K.to_fp(c[1])).round()
				+ Vector2(inset[k][0], inset[k][1]))
			k += 1
		poly.polygon = pts
		poly.color = Color(1.0, 0.36, 0.06, 0.78) * CourtStyle.time_scales(time)[1]
		poly.color.a = 0.78
		poly.z_index = z
		add_child(poly)
		_lava.append(poly)


# --- Frame ------------------------------------------------------------------------

## Rumble on a human's contact (PORT-15): a drive kicks harder, a soft
## shot barely; never in the demo.
func _rumble_hit(slot: int, shot: int) -> void:
	if demo or sim.config.human[slot] == 0:
		return
	var strength: Array = {K.SHOT_DRIVE: [0.3, 0.7, 0.12], K.SHOT_SOFT: [0.2, 0.0, 0.06],
		K.SHOT_OVERHEAD: [0.5, 1.0, 0.18], K.SHOT_SLICE: [0.15, 0.1, 0.06]}.get(
		shot, [0.35, 0.25, 0.08])
	if net:                              # online: this machine's own player only, on P1's pad
		if slot == my_team() * 2:
			GameControls.rumble(0, strength[0], strength[1], strength[2])
		return
	if multiplayer():
		GameControls.rumble_device(slot_pads[slot], strength[0], strength[1], strength[2])
		return
	if slot != 0 and slot != 2:
		return
	GameControls.rumble(0 if slot == 0 else 1, strength[0], strength[1], strength[2])


# --- Multiplayer (PORT-16) ----------------------------------------------------------

## Each slot's controller in a multiplayer match (-1: a CPU or empty);
## empty = not multiplayer (P1 on the input map, 2P on its pad).
var slot_pads: Array = []
## Each slot's player number (0..3 for P1..P4; -1 for a CPU), for the tags.
var slot_players: Array = []
const MARKER_ALPHA := 0.7


func multiplayer() -> bool:
	return not slot_pads.is_empty()


## Who plays a slot, for its marker (SNES ADR-066): 0..3 for P1..P4,
## -1 a CPU, -2 no marker (the title's demo).
func marker_player(slot: int) -> int:
	if demo:
		return -2
	if multiplayer():
		return int(slot_players[slot]) if slot < slot_players.size() else -1
	if sim.config.human[slot] == 0 or (slot == 0 and sim.p1_bot):
		return -1
	return 0 if slot == 0 else 1


## A slot's marker colour: the player's (the lobby's), a CPU grey, or
## clear (none).
func marker_color(slot: int) -> Color:
	var p := marker_player(slot)
	if p == -2:
		return Color(0, 0, 0, 0)
	var col: Color = Color(0.62, 0.64, 0.7) if p < 0 else LobbyScreen.PLAYER_TINTS[p]
	if sim.config.modifiers & K.MOD_INVERSE:
		col = Color.WHITE - col              # the inversion puts it back
	return Color(col, MARKER_ALPHA)


func _physics_process(_delta: float) -> void:
	if tuning and tuning.open:
		tuning.update()                      # the match waits (ADR-074)
		_update_visuals()
		return
	if highlight and highlight.playing():
		highlight.update()                   # PLAY OF THE MATCH (ADR-075)
		return
	if initials.open:
		end.update_initials()
		_update_visuals()
		return
	if unlock_frames >= 0:
		end.update_unlock()
		_update_visuals()
		return
	if card_frames >= 0:
		_update_card()
		_update_visuals()
		return
	if lesson_view and lesson_view.blocking():
		var it := GameControls.read_intent()
		lesson_view.update_card(it.hit_pressed != 0 or it.pause_pressed != 0)
		_update_visuals()
		return
	if lesson and lesson.done:
		if lesson_view.update_done():
			finished.emit(false)             # the next lesson
			return
		_update_visuals()
		return
	if net:
		net.poll()
		if net.closed():
			finished.emit(true)              # main says why
			return
	var human: Variant = input.read()
	if net:
		_net_refresh(human == null)
	if human == null:
		if net and net.closed():
			finished.emit(true)
		return                           # the pause menu took the frame, or online, the wait
	if highlight:
		highlight.record(human)
	sim.step(human)
	if net:
		net.after_step(sim)
	var events := sim.drain_events()
	for e in events:
		_on_event(e)
	if highlight:
		highlight.after_step(events)
	if lesson:
		lesson.observe(sim, events)
		lesson_view.refresh()
		if sim.phase == K.PHASE_MATCH_RESULT:
			sim.new_match()                  # a lesson's match goes on
	if sim.phase != _prev_phase:
		if _prev_phase == K.PHASE_POINT_RESULT:
			_end_close_call()
		if sim.phase == K.PHASE_POINT_RESULT:
			_check_close_call()
		if sim.phase == K.PHASE_MATCH_RESULT:
			_prev_phase = sim.phase
			if not (highlight and highlight.start(_match_over)):
				_match_over()
		_prev_phase = sim.phase
	flair.tick()
	if sim.rematch_requested:
		if park or tournament or story_mode:
			finished.emit(false)             # ADR-034: back to the park; PORT-25: the bracket
			return
		if ladder and sim.match_winner == 0:
			next_rung.emit()
			return
		if highlight:
			highlight.op(["new_match"])
		sim.new_match()
		flair.begin()
		Music.cue(music_track())             # the loop again after the stinger
		if save:
			save.career.new_unlocks = 0      # game_new_match clears them
		input_lock = INPUT_LOCK_FRAMES
		stats = MatchStats.new()
		_hud.on_rematch()
		_hud.on_new_match()
	elif sim.title_requested:
		finished.emit(true)
		return
	_update_visuals()


## The match is over (after PLAY OF THE MATCH, if there was one): the
## records and the result's sting.
func _match_over() -> void:
	end.on_match_over()
	if not demo:
		Music.sting(Music.result_sting(sim.match_winner == my_team(), cleared,
			sim.config.human[2] or sim.config.human[3]))


## An event of PLAY OF THE MATCH's replay: the sounds and the show, never
## the stats, the score's animation, quips or records.
func on_replay_event(e: Array) -> void:
	feel.on_event(e)
	_sfx.event(e, (sim.shot_serial - sim.rally_start) & 0xff, false)
	match int(e[0]):
		K.EVENT_HIT, K.EVENT_SERVE:
			var slot: int = e[3] & 15
			var lead := -14.0 if sim.players[slot].team else 14.0
			var shot: int = e[3] >> 4 if e[0] == K.EVENT_HIT else K.SHOT_STANDARD
			actors.spawn_fx("spark", CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp)
				+ Vector2(lead, 0), 1 if shot == K.SHOT_DRIVE or shot == K.SHOT_OVERHEAD else 0)
			if shot == K.SHOT_OVERHEAD:
				_players[slot]["choice"] = "overhead"
				actors.smash_pop(CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp))
		K.EVENT_BOUNCE:
			actors.spawn_fx("dust", CourtView.ground(K.to_fp(e[1]), K.to_fp(e[2])), 0)
		K.EVENT_POINT:
			crowd.cheer(90)


func _on_event(e: Array) -> void:
	feel.on_event(e)
	flair.on_event(e)
	stats.on_event(e)
	var kind: int = e[0]
	var at := CourtView.ground(K.to_fp(e[1]), K.to_fp(e[2]))
	var rally: int = (sim.shot_serial - sim.rally_start) & 0xff
	var match_won := kind == K.EVENT_POINT and sim.team_won(e[3])
	_sfx.event(e, rally, match_won)
	match kind:
		K.EVENT_HIT, K.EVENT_SERVE:
			var slot: int = e[3] & 15
			_rumble_hit(slot, e[3] >> 4 if kind == K.EVENT_HIT else K.SHOT_STANDARD)
			var lead := -14.0 if sim.players[slot].team else 14.0
			var shot: int = e[3] >> 4 if kind == K.EVENT_HIT else K.SHOT_STANDARD
			actors.spawn_fx("spark", CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp)
				+ Vector2(lead, 0), 1 if shot == K.SHOT_DRIVE or shot == K.SHOT_OVERHEAD else 0)
			if shot == K.SHOT_OVERHEAD:
				_players[slot]["choice"] = "overhead"   # whatever the windup guessed
				actors.smash_pop(CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp))
		K.EVENT_BOUNCE:
			actors.spawn_fx("dust", at, 0)
		K.EVENT_CROWD:
			crowd.cheer(90 if e[3] >= 13 else 50)
		K.EVENT_POINT:
			crowd.cheer(90)
			if watcher and e[3] == 1:
				watcher.cheer(70)            # their teammate won it
			_hud.on_point(e[3])
			var loser: int = 1 - e[3]
			var line := story.quip(sim.config, loser, sim.frame_count)
			if line != "":
				_hud.show_quip(line, _hud.team_tint(loser))
				flair.quip(loser)
			if save and not demo:
				if not multiplayer():
					save.record_rally(rally)
			# ADR-047: the active career player's point (against the CPU);
			# the server is still the rally's (the next serve isn't set up).
			if end.career_counts():
				save.career.record_point(rally, e[3] == 0, sim.server_index == 0)


## GHOST BALL (SNES ADR-053, render_ball): high in a live rally the ball
## shows only in a brief blink, MOD_GHOST_SHOWN frames in every 16; the
## shadow always. Display only.
## MULTI BALL: a new ball blinks at the net before it flies.
func _multi_blink_off(i: int) -> bool:
	if not sim.multi_on or i >= sim.multi.size():
		return false
	var m: MultiBallPlay.Entry = sim.multi[i]
	return m.blink > 0 and (m.blink >> 3) & 1 == 0


## MULTI BALL: the balls past the first (sim.ball is the first).
func _draw_multi_balls() -> void:
	for k in _multi_balls.size():
		var e: Array = _multi_balls[k]
		var i := k + 1
		var live := sim.multi_on and i < sim.multi.size() and sim.phase != K.PHASE_MATCH_RESULT
		e[0].visible = live and not _multi_blink_off(i)
		e[2].visible = live
		if not live:
			continue
		var mb: SimTypes.Ball = sim.multi[i].ball
		var g := CourtView.ground(mb.x_fp, mb.y_fp)
		e[0].position = g.round() + Vector2(0, 1)
		e[1].position = (CourtView.air(mb.x_fp, mb.y_fp, mb.z_fp) - g).round()
		e[2].position = g.round()


func ghost_hidden() -> bool:
	var b := sim.ball
	return (sim.config.modifiers & K.MOD_GHOST_BALL) != 0 and b.z_fp >= K.to_fp(K.MOD_GHOST_Z) \
		and b.rally_state == K.BALL_RALLY_LIVE and (sim.frame_count & 15) >= K.MOD_GHOST_SHOWN


## Online: Menu's leave (twice in play, once on the result).
func net_leave_press() -> void:
	if leave_frames > 0 or sim.phase == K.PHASE_MATCH_RESULT:
		net.quit()
		return
	leave_frames = 120


func _net_refresh(waiting: bool) -> void:
	if leave_frames > 0:
		leave_frames -= 1
	var text := ""
	if sim.phase == K.PHASE_MATCH_RESULT:
		pass                             # the stats card is up; one press leaves there
	elif leave_frames > 0:
		text = "PRESS AGAIN TO LEAVE"
	elif waiting and net.lockstep and net.lockstep.waited > 20:
		text = "WAITING FOR YOUR FRIEND..."
	_net_text.text = text


func _update_card() -> void:
	card_frames += 1
	var it := GameControls.read_intent()
	if card_frames >= CARD_MAX_FRAMES or (card_frames >= CARD_MIN_FRAMES
			and (it.hit_pressed or it.pause_pressed)):
		card_frames = -1
		input_lock = INPUT_LOCK_FRAMES      # the closing press doesn't serve
		_hud.close_card()


## Leaving practice: a new best streak (for the session's zone) is saved
## (main.c calls practice_finish), then back to the title, or to the park
## for the ball machine's practice.
func leave_practice() -> void:
	if save:
		save.finish_practice(sim.practice.zone, sim.practice.best)
	finished.emit(not park)


func _update_camera() -> void:
	var cam := camera.update(sim.ball)
	for l in _layers:
		l[0].position = (l[1] - cam * l[2]).round()
	var court_shift := (-cam).round()
	_actors.position = court_shift
	_shadows.position = court_shift
	if focus:
		focus.position = court_shift
	_fx.position = court_shift


func _update_visuals() -> void:
	_update_camera()
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[i]
		var e: Dictionary = _players[i]
		var root: Node2D = e["root"]
		root.visible = p.active != 0
		e["shadow"].visible = p.active != 0
		e["marker"].visible = p.active != 0
		if not p.active:
			continue
		var feet := CourtView.ground(p.x_fp, p.y_fp).round()
		root.position = feet
		e["shadow"].position = feet
		e["marker"].position = feet
		var idx := SLOTS.find(actors.frame_for(i))
		var flip := p.team == 1
		for s in [e["body"], e["cap"]]:
			s.region_rect = Rect2(idx * FRAME, 0, FRAME, FRAME)
			s.flip_h = flip
			s.offset = -Vector2((FRAME - 1 - ANCHOR.x) if flip else ANCHOR.x, ANCHOR.y)
		var flash := p.flash_timer > 0 and Settings.flashes     # FLASHES off: no white
		if e["look"]:
			e["body"].material.set_shader_parameter("brighten", 1.8 if flash else 1.0)
		else:
			e["body"].modulate = Color(1.8, 1.8, 1.8) if flash else Color.WHITE
	var b := sim.ball
	var show := b.active != 0 and sim.phase != K.PHASE_MATCH_RESULT
	_ball_root.visible = show and not ghost_hidden() and not _multi_blink_off(0)
	_ball_shadow.visible = show
	if show:
		var q := glide.position(sim)         # a paced ball, gliding (ADR-073)
		var g := CourtView.ground(q.x, q.y)
		_ball_root.position = g.round() + Vector2(0, 1)
		_ball_sprite.position = (CourtView.air(q.x, q.y, q.z) - g).round()
		_ball_shadow.position = g.round()
		var speed := absf(b.vx_fp) + absf(b.vy_fp)
		_ball_frame = fmod(_ball_frame + speed / 80.0, 4.0)
		var fw := _ball_sprite.region_rect.size.x
		_ball_sprite.region_rect.position.x = int(_ball_frame) * fw
	_draw_multi_balls()
	feel.update()
	var shots := RallyHeat.rally(self)
	heat.update()
	if focus:
		focus.update(shots)
	if critter:
		critter.update()
	if wind_view:
		wind_view.update()
	_sfx.update_ambience(sim.phase == K.PHASE_LIVE, (sim.shot_serial - sim.rally_start) & 0xff,
		sim.match_point(0) or sim.match_point(1), 1.0 / 60.0)
	for poly in _lava:
		poly.color.a = 0.74 + 0.08 * sin(Time.get_ticks_msec() / 260.0)
	crowd.update()
	if watcher:
		watcher.update(sim)
	if close_call:
		close_call.update()
	_hud.refresh()
	_debug.refresh()
