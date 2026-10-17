## A match on screen: the venue's parallax layers, the y-sorted players,
## ball, and near net post, effects from sim events, crowd, and the HUD.
## Runs the sim at a fixed 60 Hz and only ever reads it (playbook rule 2).
class_name MatchView
extends Node2D

signal finished(to_title: bool)

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

var _actors: Node2D
var _shadows: Node2D
var _fx: Node2D
var _crowd: Array = []           # [Sprite2D, base_region, person]
var _crowd_cheer := 0
var _players: Array = []         # per slot: {root, body, cap, shadow, choice}
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
		z += 1
		if layer["name"] == "stands":
			_build_crowd(vm, z)
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
		body.texture = _sheet(variant, team_name, false)
		var cap := Sprite2D.new()
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
	_actors.add_child(_ball_root)
	_ball_shadow = Sprite2D.new()
	_ball_shadow.texture = _tex(manifest["sprites"]["ball_shadow"]["file"])
	_shadows.add_child(_ball_shadow)


# --- Frame ------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var human := []
	if not demo:
		var it := GameControls.read_intent()
		var it2: SimTypes.Intent = GameControls.read_pad_intent(1) if sim.config.human[2] else null
		if input_lock > 0:
			input_lock -= 1
			it = SimTypes.Intent.new()
			it2 = null
		human = [it, null, it2, null]
	sim.step(human)
	for e in sim.drain_events():
		_on_event(e)
	if sim.rematch_requested:
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


func _update_visuals() -> void:
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
	if _crowd_cheer > 0:
		_crowd_cheer -= 1
	for c in _crowd:
		var cheer: bool = _crowd_cheer > 0 and ((_crowd_cheer / 8 + c[1]) % 2 == 0)
		c[0].region_rect = Rect2(c[2] if cheer else 0, c[1] * c[3], c[2], c[3])
	_hud.refresh()
	_debug.refresh()
