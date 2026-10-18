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
	if ladder and cfg.opponent >= 0 and not cfg.human[2]:
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
	_build_players()
	_build_ball()
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


func _sheet(variant: String, team: String, cap: bool) -> Texture2D:
	return _tex("sprites/players/player_%s_%s%s.png" % [variant, team, "_cap" if cap else ""])


func _build_players() -> void:
	var shadow_tex := _tex(manifest["sprites"]["player_shadow"]["file"])
	for i in K.MAX_PLAYERS:
		var entry := {}
		var pal: int = sim.config.palette[i]
		var team_name: String = ["blue", "red", "green", "gold"][maxi(pal, 0)]
		var variant := "female" if sim.config.variant[i] == K.VARIANT_FEMALE else "male"
		var root := Node2D.new()
		var body := Sprite2D.new()
		var cap := Sprite2D.new()
		var look := PlayerLook.for_slot(sim.config, i, manifest)
		if look:
			# a ladder opponent: role sheets in their colours, their hat
			body.texture = _tex(look.body_sheet(manifest))
			var hat := look.hat_sheet(manifest)
			cap.texture = _tex(hat) if hat != "" else null
			body.material = look.material()
			cap.material = body.material
		else:
			body.texture = _sheet(variant, team_name, false)
			cap.texture = _sheet(variant, team_name, true)
		for s in [body, cap]:
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, FRAME, FRAME)
			root.add_child(s)
		var shadow := Sprite2D.new()
		shadow.texture = shadow_tex
		_shadows.add_child(shadow)
		_actors.add_child(root)
		entry["root"] = root
		entry["body"] = body
		entry["cap"] = cap
		entry["shadow"] = shadow
		entry["choice"] = "standard"
		entry["look"] = look
		_players.append(entry)


func _build_ball() -> void:
	var meta: Dictionary = manifest["sprites"]["ball"]
	_ball_root = Node2D.new()
	_ball_sprite = Sprite2D.new()
	_ball_sprite.texture = _tex(meta["file"])
	_ball_sprite.region_enabled = true
	var fw: int = meta["frame_size"][0]
	_ball_sprite.region_rect = Rect2(0, 0, fw, meta["frame_size"][1])
	_ball_root.add_child(_ball_sprite)
	if sim.config.modifiers & K.MOD_BIG_BALL:
		_ball_sprite.scale = Vector2(2, 2)        # BIG BALL reads as big
	_actors.add_child(_ball_root)
	_ball_shadow = Sprite2D.new()
	_ball_shadow.texture = _tex(manifest["sprites"]["ball_shadow"]["file"])
	if sim.config.modifiers & K.MOD_BIG_BALL:
		_ball_shadow.scale = Vector2(2, 1.6)
	_shadows.add_child(_ball_shadow)


# --- Frame ------------------------------------------------------------------------

## Rumble on a human's contact (PORT-15): a drive kicks harder, a soft
## shot barely; never in the demo.
func _rumble_hit(slot: int, shot: int) -> void:
	if demo or sim.config.human[slot] == 0:
		return
	var strength: Array = {K.SHOT_DRIVE: [0.3, 0.7, 0.12], K.SHOT_SOFT: [0.2, 0.0, 0.06]}.get(
		shot, [0.35, 0.25, 0.08])
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


## Every human slot's intent from its own pad. Any player's Menu pauses
## (the sim reads the pause on slot 0), and while paused any pad drives
## the pause menu. Empty when the pause menu took the frame.
func _multiplayer_intents() -> Array:
	var human := [null, null, null, null]
	var menu := SimTypes.Intent.new()        # the pause menu: anyone's presses
	for s in K.MAX_PLAYERS:
		var dev: int = slot_pads[s] if s < slot_pads.size() else -1
		if dev < 0 or not sim.config.human[s]:
			continue
		var it := GameControls.read_pad_intent(dev)
		menu.hit_pressed |= it.hit_pressed
		menu.pause_pressed |= it.pause_pressed
		human[s] = it
	if input_lock > 0:
		input_lock -= 1
		for s in K.MAX_PLAYERS:
			if human[s] != null:
				human[s] = SimTypes.Intent.new()
		menu = SimTypes.Intent.new()
	if human[0] == null:
		human[0] = SimTypes.Intent.new()
	if _pause_on_lost_pad():
		menu.pause_pressed = 1
	human[0].pause_pressed = menu.pause_pressed
	if sim.paused:
		menu.pause_pressed = human[0].pause_pressed
		if _pause_input(menu):
			return []
		human[0].pause_pressed = menu.pause_pressed
	return human


## A controller dropping out mid-match pauses it (the pause menu waits
## for the player to come back), as most games do.
var _lost_seen := GameControls.lost_serial

func _pause_on_lost_pad() -> bool:
	if GameControls.lost_serial == _lost_seen:
		return false
	_lost_seen = GameControls.lost_serial
	return not sim.paused and sim.phase != K.PHASE_MATCH_RESULT and not initials.open


## SERVE ASSIST (PORT-12, an input aid, not a rule change): while P1
## holds B on the charged serve, the press lets go by itself on the way up
## at a strong charge, so holding is enough for a good serve.
const SERVE_ASSIST_LEVEL := 24

func _serve_assist(it: SimTypes.Intent) -> void:
	if not Settings.serve_assist or not it.hit_held or not sim.charge_charging:
		return
	var server: SimTypes.Player = sim.players[sim.server_index]
	if server.logical_input_slot == 0 and sim.charge_rising \
			and sim.charge_level >= SERVE_ASSIST_LEVEL:
		it.hit_held = 0


## The initials card (ADR-040): the match waits under it like the intro card.
var initials := Initials.new()


func _update_initials() -> void:
	var bits := GameControls.pad_bits()
	if not initials.update(bits[0], bits[1]):
		save.save_game()
		input_lock = INPUT_LOCK_FRAMES      # the closing press doesn't rematch
		GameControls.clear_latch()
		_sfx.play("confirm")
	elif bits[0]:
		_sfx.play("blip")


## The UNLOCKED! card (ADR-047, story.c's STORY_CARD_UNLOCK): after the
## initials card, the career unlocks the match just earned; B, A or Start
## closes it after UNLOCK_MIN_FRAMES, or it goes by itself.
const UNLOCK_MIN_FRAMES := 30
const UNLOCK_FRAMES := 300
var unlock_frames := -1


func unlock_open() -> bool:
	return unlock_frames >= 0 and not initials.open


func _update_unlock() -> void:
	unlock_frames += 1
	var pressed: int = GameControls.pad_bits()[0]
	if unlock_frames >= UNLOCK_FRAMES or (unlock_frames >= UNLOCK_MIN_FRAMES
			and pressed & (Practice.PAD_B | GameControls.PAD_A | Practice.PAD_START)):
		unlock_frames = -1
		if save:
			save.career.new_unlocks = 0
		input_lock = INPUT_LOCK_FRAMES      # the closing press doesn't rematch
		GameControls.clear_latch()
		_sfx.play("confirm")


## A career match (ADR-047): 1P's points and the result count for the
## active career player against the CPU, outside the demo, practice and
## multiplayer (as the records).
func career_counts() -> bool:
	return save != null and not demo and not multiplayer() and not sim.config.human[2] \
		and not sim.config.practice


func _physics_process(_delta: float) -> void:
	if initials.open:
		_update_initials()
		_update_visuals()
		return
	if unlock_frames >= 0:
		_update_unlock()
		_update_visuals()
		return
	if card_frames >= 0:
		_update_card()
		_update_visuals()
		return
	var human := []
	if not demo and multiplayer():
		human = _multiplayer_intents()
		if human.is_empty():
			return
	elif not demo:
		var it := GameControls.read_intent()
		var it2: SimTypes.Intent = GameControls.read_pad_intent(GameControls.p2_pad) if sim.config.human[2] else null
		# 2P partnering you in the park (ADR-034): slot 1, on their pad
		var it1: SimTypes.Intent = GameControls.read_pad_intent(GameControls.p2_pad) \
			if sim.config.human[1] and not sim.config.human[2] else null
		if input_lock > 0:
			input_lock -= 1
			it = SimTypes.Intent.new()
			it1 = null
			it2 = null
			GameControls.clear_latch()
		_serve_assist(it)
		if _pause_on_lost_pad():
			it.pause_pressed = 1
		human = [it, it1, it2, null]
		if sim.paused and _pause_input(it):
			return
	sim.step(human)
	for e in sim.drain_events():
		_on_event(e)
	if sim.phase != _prev_phase:
		if _prev_phase == K.PHASE_POINT_RESULT:
			_end_close_call()
		if sim.phase == K.PHASE_POINT_RESULT:
			_check_close_call()
		if sim.phase == K.PHASE_MATCH_RESULT:
			_on_match_over()
			if not demo:
				Music.sting(Music.result_sting(sim.match_winner == 0, cleared,
					sim.config.human[2] or sim.config.human[3]))
		_prev_phase = sim.phase
	if sim.rematch_requested:
		if park:
			finished.emit(false)             # ADR-034: back to the park
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


## The pause menu (ADR-030): RESUME, RESTART (not in practice), MAIN MENU.
func pause_rows() -> Array:
	var rows := [{"id": "resume", "label": "RESUME", "press": func(): pause_choice = "resume"}]
	if not sim.config.practice:
		rows.append({"id": "restart", "label": "RESTART", "press": func(): pause_choice = "restart"})
	rows.append({"id": "menu", "label": "PARK" if park and sim.config.practice else "MAIN MENU",
		"press": func(): pause_choice = "menu"})
	return rows


var pause_choice := ""

## One paused frame: Up/Down move, B picks (Start still resumes, in the
## sim). True when the frame is done (the sim doesn't step).
func _pause_input(it: SimTypes.Intent) -> bool:
	var menu: MenuPage = _hud.pause_menu
	if GameControls.menu_pressed("move_up"):
		menu.move(-1)
		_sfx.play("blip")
	elif GameControls.menu_pressed("move_down"):
		menu.move(1)
		_sfx.play("blip")
	if it.hit_pressed and not it.pause_pressed:
		menu.press()
	it.hit_pressed = 0              # a menu press is never a swing
	var choice := pause_choice      # set by a press: keys above, or a click
	pause_choice = ""
	match choice:
		"resume":
			_sfx.play("back")
			it.pause_pressed = 1         # the sim unpauses on its own Start
		"restart":
			_sfx.play("confirm")
			if save:
				save.drop_new_records()          # only a finished match asks
				save.career.new_unlocks = 0
			sim.new_match()
			_prev_phase = -1
			input_lock = INPUT_LOCK_FRAMES   # the closing press doesn't serve
			stats = MatchStats.new()
			_hud.on_rematch()
			_hud.on_new_match()
			_update_visuals()
			return true
		"menu":
			_sfx.play("back")
			if save:
				save.drop_new_records()
			if sim.config.practice:
				leave_practice()
			else:
				finished.emit(true)
			return true
	if it.pause_pressed and choice == "":
		_sfx.play("back")
	return false


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
			_spawn_fx("spark", CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp)
				+ Vector2(lead, 0), 1 if (e[3] >> 4) == K.SHOT_DRIVE else 0)
		K.EVENT_BOUNCE:
			_spawn_fx("dust", at, 0)
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
			if career_counts():
				save.career.record_point(rally, e[3] == 0, sim.server_index == 0)


func _update_card() -> void:
	card_frames += 1
	var it := GameControls.read_intent()
	if card_frames >= CARD_MAX_FRAMES or (card_frames >= CARD_MIN_FRAMES
			and (it.hit_pressed or it.pause_pressed)):
		card_frames = -1
		input_lock = INPUT_LOCK_FRAMES      # the closing press doesn't serve
		_hud.close_card()


## Records at the match's end (a safe point to write, playbook §6), and the
## ladder (ADR-023): a win moves to the next rung; beating the last clears.
## A record beaten (the rally, in 2P too) asks for initials (ADR-040).
func _on_match_over() -> void:
	if demo or save == null:
		return
	var won := sim.match_winner == 0
	if multiplayer():
		save.drop_new_records()          # friends' matches don't touch the records
		save.save_game()
		return
	if not sim.config.human[2]:
		# ADR-047: before record_match, whose write keeps both.
		if career_counts():
			save.career.record_match(sim.config.mode, won, sim.team_score[1],
				sim.config.opponent, sim.config.open_play != 0)
		save.record_match(sim.config.mode == K.MODE_DOUBLES, won, sim.config.opponent,
			sim.team_score[1] if won else -1)
		if ladder and won:
			cleared = save.advance_ladder(Opponents.count())
		save.record_stats(stats)
	save.save_game()
	initials.begin(save)
	# then what the career player unlocked (after the initials, if any)
	if save.career.new_unlocks:
		unlock_frames = 0


## Leaving practice: a new best streak (for the session's zone) is saved
## (main.c calls practice_finish), then back to the title, or to the park
## for the ball machine's practice.
func leave_practice() -> void:
	if save:
		save.finish_practice(sim.practice.zone, sim.practice.best)
	finished.emit(not park)


func _spawn_fx(kind: String, at: Vector2, start: int) -> void:
	var meta: Dictionary = manifest["sprites"][kind]
	var s := Sprite2D.new()
	s.texture = _tex(meta["file"])
	s.region_enabled = true
	var fw: int = meta["frame_size"][0]
	var fh: int = meta["frame_size"][1]
	s.region_rect = Rect2(start * fw, 0, fw, fh)
	s.position = at if kind == "spark" else at - Vector2(0, fh / 2.0)
	_fx.add_child(s)
	var frames: int = meta["frames"]
	var ms: float = meta.get("ms_per_frame", 60)
	var tw := create_tween()
	for f in range(start + 1, frames):
		tw.tween_interval(ms / 1000.0)
		tw.tween_callback(func(): s.region_rect = Rect2(f * fw, 0, fw, fh))
	tw.tween_interval(ms / 1000.0)
	tw.tween_callback(s.queue_free)


func _frame_for(i: int) -> String:
	var p: SimTypes.Player = sim.players[i]
	var entry: Dictionary = _players[i]
	if p.pose == K.POSE_TOSS:
		return "toss"
	if p.pose == K.POSE_CHEER:
		return "cheer"
	match p.state:
		K.STATE_WINDUP:
			if p.state_frames_remaining == K.PLAYER_WINDUP_FRAMES:
				entry["choice"] = _choose_swing(p)
			return {"overhead": "overhead_windup", "scoop": "scoop",
				"reach": "windup"}.get(entry["choice"], "windup")
		K.STATE_ACTIVE:
			return {"overhead": "overhead_contact", "scoop": "scoop",
				"reach": "reach"}.get(entry["choice"], "swing")
		K.STATE_RECOVERY:
			if entry["choice"] == "overhead":
				return "follow"
			if entry["choice"] in ["scoop", "reach"] and p.state_frames_remaining > 3:
				return entry["choice"]
			return "follow"
		K.STATE_MOVE:
			return "run%d" % (p.animation_frame % 4)
	return "idle%d" % (p.animation_frame % 2)


## Display-only choice of swing animation: an overhead at a high ball, a
## scoop for a soft shot at a low one, a reach when the ball is wide.
func _choose_swing(p: SimTypes.Player) -> String:
	var b := sim.ball
	var dy := absi(b.y_fp - p.y_fp)
	if b.rally_state == K.BALL_RALLY_LIVE and b.z_fp > K.to_fp(17):
		return "overhead"
	if p.shot_type == K.SHOT_SOFT and b.z_fp < K.to_fp(6):
		return "scoop"
	if dy > K.to_fp(K.HIT_SWEET_Y):
		return "reach"
	return "standard"


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
		var idx := SLOTS.find(_frame_for(i))
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
