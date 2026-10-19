## A match's people and ball (split from MatchView in PORT-27): their
## sprites, which frame each shows (with the display-only swing choice),
## the hit sparks and dust, SMASH!, and placing them each frame. Display
## only: reads the view's sim.
class_name MatchActors
extends RefCounted

var v: MatchView


func _init(view: MatchView) -> void:
	v = view


func sheet(variant: String, team: String, cap: bool) -> Texture2D:
	return v._tex(PlayerLook.team_sheet(variant, team, cap))


const MARKER_RX := 32.0
const MARKER_RY := 11.0


func build_players() -> void:
	var shadow_tex := v._tex(v.manifest["sprites"]["player_shadow"]["file"])
	for i in K.MAX_PLAYERS:
		var entry := {}
		var pal: int = v.sim.config.palette[i]
		var team_name: String = ["blue", "red", "green", "gold"][maxi(pal, 0)]
		var variant := PlayerLook.variant_name(v.sim.config.variant[i])
		var root := Node2D.new()
		var body := Sprite2D.new()
		var cap := Sprite2D.new()
		var look := PlayerLook.for_slot(v.sim.config, i, v.manifest)
		if v.sim.config.modifiers & K.MOD_GLOW:
			# SNES ADR-054: every player on role sheets, neon
			if look == null:
				look = PlayerLook.for_team(maxi(pal, 0), v.sim.config.variant[i],
					v.sim.config.paddle[i], v.manifest)
			look.glow(v.manifest)
		if look:
			# a ladder opponent: role sheets in their colours, their hat
			body.texture = v._tex(look.body_sheet(v.manifest))
			var hat := look.hat_sheet(v.manifest)
			cap.texture = v._tex(hat) if hat != "" else null
			body.material = look.material()
			cap.material = body.material
		else:
			body.texture = sheet(variant, team_name, false)
			cap.texture = sheet(variant, team_name, true)
		for s in [body, cap]:
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, MatchView.FRAME, MatchView.FRAME)
			root.add_child(s)
		# SNES ADR-066's ring at the feet, as a filled circle (the ring was
		# the SNES's limit): who plays the slot, round its shadow
		var shadow := Sprite2D.new()
		shadow.texture = shadow_tex
		v._shadows.add_child(shadow)
		# over the shadow, which shows through as its darker middle
		var marker := Node2D.new()
		marker.draw.connect(draw_marker.bind(marker, v.marker_color(i)))
		marker.visible = false
		v._shadows.add_child(marker)
		v._actors.add_child(root)
		entry["root"] = root
		entry["body"] = body
		entry["cap"] = cap
		entry["shadow"] = shadow
		entry["marker"] = marker
		entry["choice"] = "standard"
		entry["look"] = look
		v._players.append(entry)


## A player's marker: a filled ellipse round the shadow, lighter at the
## rim (nothing for a slot without one).
static func draw_marker(n: Node2D, col: Color) -> void:
	if col.a == 0.0:
		return
	var rim := PackedVector2Array()
	var fill := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		rim.append(Vector2(cos(a) * MARKER_RX, sin(a) * MARKER_RY))
		fill.append(Vector2(cos(a) * (MARKER_RX - 3), sin(a) * (MARKER_RY - 2)))
	n.draw_colored_polygon(rim, Color(col.lightened(0.35), col.a))
	n.draw_colored_polygon(fill, col)


func build_ball() -> void:
	var meta: Dictionary = v.manifest["sprites"]["ball"]
	v._ball_root = Node2D.new()
	v._ball_sprite = Sprite2D.new()
	v._ball_sprite.texture = v._tex(meta["file"])
	v._ball_sprite.region_enabled = true
	var fw: int = meta["frame_size"][0]
	v._ball_sprite.region_rect = Rect2(0, 0, fw, meta["frame_size"][1])
	v._ball_root.add_child(v._ball_sprite)
	if v.sim.config.modifiers & K.MOD_BIG_BALL:
		v._ball_sprite.scale = Vector2(2, 2)        # BIG BALL reads as big
	if v.sim.config.modifiers & K.MOD_GLOW:
		v._ball_sprite.material = ShaderMaterial.new()
		v._ball_sprite.material.shader = preload("res://view/glow_outline.gdshader")
	v._actors.add_child(v._ball_root)
	v._ball_shadow = Sprite2D.new()
	v._ball_shadow.texture = v._tex(v.manifest["sprites"]["ball_shadow"]["file"])
	if v.sim.config.modifiers & K.MOD_BIG_BALL:
		v._ball_shadow.scale = Vector2(2, 1.6)
	v._shadows.add_child(v._ball_shadow)
	# MULTI BALL (port ADR-067): the balls past the first, the same art
	if v.sim.multi_on:
		for k in K.MULTI_MAX - 1:
			var root := Node2D.new()
			var spr: Sprite2D = v._ball_sprite.duplicate()
			root.add_child(spr)
			root.visible = false
			v._actors.add_child(root)
			var sh: Sprite2D = v._ball_shadow.duplicate()
			sh.visible = false
			v._shadows.add_child(sh)
			v._multi_balls.append([root, spr, sh])


func spawn_fx(kind: String, at: Vector2, start: int) -> void:
	var meta: Dictionary = v.manifest["sprites"][kind]
	var s := Sprite2D.new()
	s.texture = v._tex(meta["file"])
	s.region_enabled = true
	var fw: int = meta["frame_size"][0]
	var fh: int = meta["frame_size"][1]
	s.region_rect = Rect2(start * fw, 0, fw, fh)
	s.position = at if kind == "spark" else at - Vector2(0, fh / 2.0)
	v._fx.add_child(s)
	var frames: int = meta["frames"]
	var ms: float = meta.get("ms_per_frame", 60)
	var tw := v.create_tween()
	for f in range(start + 1, frames):
		tw.tween_interval(ms / 1000.0)
		tw.tween_callback(func(): s.region_rect = Rect2(f * fw, 0, fw, fh))
	tw.tween_interval(ms / 1000.0)
	tw.tween_callback(s.queue_free)


func frame_for(i: int) -> String:
	var p: SimTypes.Player = v.sim.players[i]
	var entry: Dictionary = v._players[i]
	var react: String = v.flair.body_frame(i) if v.flair else ""
	if react != "":
		return react                     # a point's reaction (SNES ADR-064)
	if p.pose == K.POSE_TOSS:
		return "toss"
	if p.pose == K.POSE_CHEER:
		return "cheer"
	match p.state:
		K.STATE_WINDUP:
			if p.state_frames_remaining == K.PLAYER_WINDUP_FRAMES:
				entry["choice"] = choose_swing(p)
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


## SMASH! over an overhead's contact (ADR-053): rises and fades in half a
## second. Display only; skipped in the demo's quiet and when effects are off.
func smash_pop(at: Vector2) -> void:
	if not Feel.ON["shake"]:
		return
	var t := UiKit.text("small", "SMASH!", at + Vector2(0, -26), 0.5, Color("fbe46a"), v._fx)
	t.z_index = 5
	var tw := v.create_tween()
	tw.tween_property(t, "position:y", t.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.tween_callback(t.queue_free)


## Display-only choice of swing animation: an overhead at a high ball, a
## scoop for a soft shot at a low one, a reach when the ball is wide.
func choose_swing(p: SimTypes.Player) -> String:
	var b := v.sim.ball
	var dy := absi(b.y_fp - p.y_fp)
	if b.rally_state == K.BALL_RALLY_LIVE and b.z_fp > K.to_fp(K.HIT_OVERHEAD_Z - 3):
		return "overhead"
	if p.shot_type == K.SHOT_SOFT and b.z_fp < K.to_fp(6):
		return "scoop"
	if dy > K.to_fp(K.HIT_SWEET_Y):
		return "reach"
	return "standard"
