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
var story := Story.new()
## The intro card (ADR-026): the match waits under it, no sim, no AI.
var card_frames := -1
const CARD_MIN_FRAMES := 30
const CARD_MAX_FRAMES := 300
var _prev_phase := -1
var cleared := false            ## this match cleared the ladder
## Camera (ADR-050/051), display only: the picture leans toward the ball.
## Percent of the full lean; 0 = OFF (the SNES default).
var camera_percent := 0
var cam := Vector2.ZERO
var _layers: Array = []          # [Sprite2D, origin, parallax]
## Full lean at this density: the SNES 8 x 4 px, times the court's scale.
const CAM_MAX := Vector2(22, 10)

var _actors: Node2D
var _shadows: Node2D
var _fx: Node2D
var _crowd: Array = []           # [Sprite2D, base_region, person]
var _crowd_cheer := 0
var _players: Array = []         # per slot: {root, body, cap, shadow, choice, look}
var _ball_root: Node2D
var _ball_sprite: Sprite2D
var _ball_shadow: Sprite2D
var _ball_frame := 0.0
var _hud: Hud
var _sfx: Sfx
var _debug: DebugOverlay


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
		z += 1
		if layer["name"] == "stands":
			_build_crowd(vm, z)
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
	_sfx.setup(venue, demo)
	_debug = DebugOverlay.new()
	_debug.view = self
	add_child(_debug)


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
		poly.color = Color(1.0, 0.36, 0.06, 0.78)
		poly.z_index = z
		add_child(poly)
		_lava.append(poly)


func _build_crowd(vm: Dictionary, z: int) -> void:
	var crowd: Dictionary = manifest["sprites"]["crowd"]
	var tex := _tex(crowd["file"])
	var fw: int = crowd["frame_size"][0]
	var fh: int = crowd["frame_size"][1]
	for seat in vm["seats"]:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		var row: int = seat["person"]
		s.region_rect = Rect2(0, row * fh, fw, fh)
		var anchor: Array = crowd["sit_anchor"] if seat["pose"] == "sit" else crowd["stand_anchor"]
		s.position = Vector2(seat["x"] - anchor[0], seat["y"] - anchor[1])
		s.z_index = z
		add_child(s)
		_crowd.append([s, row, fw, fh])


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

func _physics_process(_delta: float) -> void:
	if card_frames >= 0:
		_update_card()
		_update_visuals()
		return
	var human := []
	if not demo:
		var it := GameControls.read_intent()
		var it2: SimTypes.Intent = GameControls.read_pad_intent(1) if sim.config.human[2] else null
		if input_lock > 0:
			input_lock -= 1
			it = SimTypes.Intent.new()
			it2 = null
			GameControls.clear_latch()
		human = [it, null, it2, null]
	sim.step(human)
	for e in sim.drain_events():
		_on_event(e)
	if sim.phase != _prev_phase:
		if sim.phase == K.PHASE_MATCH_RESULT:
			_on_match_over()
		_prev_phase = sim.phase
	if sim.rematch_requested:
		if ladder and sim.match_winner == 0:
			next_rung.emit()
			return
		sim.new_match()
		input_lock = INPUT_LOCK_FRAMES
		_hud.on_new_match()
	elif sim.title_requested:
		finished.emit(true)
		return
	_update_visuals()


func _on_event(e: Array) -> void:
	var kind: int = e[0]
	var at := CourtView.ground(K.to_fp(e[1]), K.to_fp(e[2]))
	match kind:
		K.EVENT_HIT, K.EVENT_SERVE:
			var slot: int = e[3] & 15
			var lead := -14.0 if sim.players[slot].team else 14.0
			_spawn_fx("spark", CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp)
				+ Vector2(lead, 0), 1 if (e[3] >> 4) == K.SHOT_DRIVE else 0)
			_sfx.play("hit")
		K.EVENT_BOUNCE:
			_spawn_fx("dust", at, 0)
			_sfx.play("bounce")
		K.EVENT_FAULT:
			if e[3] == K.FAULT_NET:
				_sfx.play("net")
		K.EVENT_POINT:
			_sfx.play("whistle")
			_sfx.play("applause")
			_crowd_cheer = 90
			_hud.on_point(e[3])
			var loser: int = 1 - e[3]
			var line := story.quip(sim.config, loser, sim.frame_count)
			if line != "":
				_hud.show_quip(line, _hud.team_tint(loser))
			if save and not demo:
				save.record_rally((sim.shot_serial - sim.rally_start) & 0xff)


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
func _on_match_over() -> void:
	if demo or save == null or sim.config.human[2]:
		return
	var won := sim.match_winner == 0
	save.record_match(sim.config.mode == K.MODE_DOUBLES, won)
	if ladder and won:
		cleared = save.advance_ladder(Opponents.count())
	save.save_game()


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


## ADR-050: the target is a sixteenth of the ball's distance from the net
## across the screen and an eighth of its distance from the centre line
## (SNES px, capped 8 x 4), scaled by the setting; ease an eighth of the
## way a frame, at most half a SNES pixel's worth.
func _update_camera() -> void:
	var target := Vector2.ZERO
	if camera_percent > 0 and sim.ball.rally_state == K.BALL_RALLY_LIVE:
		var dx := (sim.ball.x_fp / 16.0 - K.COURT_NET_X) / 16.0
		var dy := (sim.ball.y_fp / 16.0 - K.COURT_CENTERLINE_Y) / 8.0
		target = Vector2(clampf(dx, -8, 8) / 8.0 * CAM_MAX.x,
			clampf(dy, -4, 4) / 4.0 * CAM_MAX.y) * camera_percent / 100.0
	var step := (target - cam) / 8.0
	var limit := CAM_MAX.x / 16.0
	cam += step.limit_length(limit) if step.length() > 0.02 else target - cam
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
		if e["look"]:
			e["body"].material.set_shader_parameter("brighten", 1.8 if p.flash_timer > 0 else 1.0)
		else:
			e["body"].modulate = Color(1.8, 1.8, 1.8) if p.flash_timer > 0 else Color.WHITE
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
	for poly in _lava:
		poly.color.a = 0.74 + 0.08 * sin(Time.get_ticks_msec() / 260.0)
	if _crowd_cheer > 0:
		_crowd_cheer -= 1
	for c in _crowd:
		var cheer: bool = _crowd_cheer > 0 and ((_crowd_cheer / 8 + c[1]) % 2 == 0)
		c[0].region_rect = Rect2(c[2] if cheer else 0, c[1] * c[3], c[2], c[3])
	_hud.refresh()
	_debug.refresh()
