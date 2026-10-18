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
	"follow", "toss", "cheer", "overhead_windup", "overhead_contact", "reach", "scoop"]
## Input is ignored this long after a match starts, so the press that
## started it can't also serve (playbook rule 9).
const INPUT_LOCK_FRAMES := 12

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
var _ball_frame := 0.0
var _hud: Hud
var _sfx: Sfx
var _debug: DebugOverlay
var feel: Feel
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
func _pause_input(it: SimTypes.Intent) -> bool: return input.pause_input(it)
func _serve_assist(it: SimTypes.Intent) -> void: input.serve_assist(it)
func _frame_for(i: int) -> String: return actors.frame_for(i)
func _spawn_fx(kind: String, at: Vector2, start: int) -> void: actors.spawn_fx(kind, at, start)


## The venue's match loop (PORT-22); a match's end stings over it.
func music_track() -> String:
	return Music.match_track(venue)


func setup(cfg: SimTypes.MatchConfig, venue_name: String, is_demo: bool) -> void:
	venue = venue_name
	demo = is_demo
	manifest = JSON.parse_string(FileAccess.get_file_as_string(LEVELS + "manifest.json"))
	sim = Sim.new(cfg)
	if demo:
		sim.start_attract()
	input_lock = INPUT_LOCK_FRAMES
	if (ladder or tournament) and cfg.opponent >= 0 and not cfg.human[2]:
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
		K.SHOT_OVERHEAD: [0.5, 1.0, 0.18]}.get(
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


func multiplayer() -> bool:
	return not slot_pads.is_empty()


func _physics_process(_delta: float) -> void:
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
	sim.step(human)
	if net:
		net.after_step(sim)
	var events := sim.drain_events()
	for e in events:
		_on_event(e)
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
			end.on_match_over()
			if not demo:
				Music.sting(Music.result_sting(sim.match_winner == my_team(), cleared,
					sim.config.human[2] or sim.config.human[3]))
		_prev_phase = sim.phase
	if sim.rematch_requested:
		if park or tournament:
			finished.emit(false)             # ADR-034: back to the park; PORT-25: the bracket
			return
		if ladder and sim.match_winner == 0:
			next_rung.emit()
			return
		sim.new_match()
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


func _on_event(e: Array) -> void:
	feel.on_event(e)
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
			if save and not demo:
				if not multiplayer():
					save.record_rally(rally)
			# ADR-047: the active career player's point (against the CPU);
			# the server is still the rally's (the next serve isn't set up).
			if end.career_counts():
				save.career.record_point(rally, e[3] == 0, sim.server_index == 0)


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
	_fx.position = court_shift


func _update_visuals() -> void:
	_update_camera()
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = sim.players[i]
		var e: Dictionary = _players[i]
		var root: Node2D = e["root"]
		root.visible = p.active != 0
		e["shadow"].visible = p.active != 0
		if not p.active:
			continue
		var feet := CourtView.ground(p.x_fp, p.y_fp).round()
		root.position = feet
		e["shadow"].position = feet
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
	_ball_root.visible = show
	_ball_shadow.visible = show
	if show:
		var g := CourtView.ground(b.x_fp, b.y_fp)
		_ball_root.position = g.round() + Vector2(0, 1)
		_ball_sprite.position = (CourtView.air(b.x_fp, b.y_fp, b.z_fp) - g).round()
		_ball_shadow.position = g.round()
		var speed := absf(b.vx_fp) + absf(b.vy_fp)
		_ball_frame = fmod(_ball_frame + speed / 80.0, 4.0)
		var fw := _ball_sprite.region_rect.size.x
		_ball_sprite.region_rect.position.x = int(_ball_frame) * fw
	feel.update()
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
