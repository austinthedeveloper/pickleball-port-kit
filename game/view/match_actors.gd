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
	if v.sim.config.modifiers & K.MOD_GLOW:
		v._ball_sprite.material = ShaderMaterial.new()
		v._ball_sprite.material.shader = preload("res://view/glow_outline.gdshader")
	v._actors.add_child(v._ball_root)
	v._ball_shadow = Sprite2D.new()
	v._ball_shadow.texture = v._tex(v.manifest["sprites"]["ball_shadow"]["file"])
	v._shadows.add_child(v._ball_shadow)
	apply_ball_size()
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
	# not during PLAY OF THE MATCH: the live match's end reaction (a held
	# celebration or slump) isn't the replayed rally's
	var react: String = v.flair.body_frame(i) if v.flair and not v.replaying() else ""
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
func smash_pop(at: Vector2, special := false) -> void:
	if not Feel.ON["shake"]:
		return
	var t := UiKit.text("big_gold" if special else "small", "PICKLE SMASH!" if special else "SMASH!",
		at + Vector2(0, -40 if special else -26), 0.5, Color.WHITE if special else Color("fbe46a"), v._fx)
	t.z_index = 5
	var tw := v.create_tween()
	tw.tween_property(t, "position:y", t.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.tween_callback(t.queue_free)


## Display-only choice of swing animation: an overhead at a high ball, the
## low reach at one on the near side (below the feet on screen: the ROM's
## hit area reaches there, KNOWN_ISSUES #69), a scoop for a soft shot at a
## low one, a reach when the ball is wide.
func choose_swing(p: SimTypes.Player) -> String:
	var b := v.sim.ball
	var dy := absi(b.y_fp - p.y_fp)
	if b.rally_state == K.BALL_RALLY_LIVE and b.z_fp > K.to_fp(K.HIT_OVERHEAD_Z - 3):
		return "overhead"
	if b.y_fp - p.y_fp > K.to_fp(NEAR_SIDE):
		return "reach"
	if p.shot_type == K.SHOT_SOFT and b.z_fp < K.to_fp(6):
		return "scoop"
	if dy > K.to_fp(K.HIT_SWEET_Y):
		return "reach"
	return "standard"


## BALL SIZE (ADR-072), display only; BIG BALL draws it at 200%. Again
## from the tuning panel (ADR-074), live.
func apply_ball_size() -> void:
	var big := v.sim.config.modifiers & K.MOD_BIG_BALL != 0
	var k := Settings.ball_size / 100.0
	v._ball_sprite.scale = Vector2(2, 2) if big else Vector2.ONE * k
	v._ball_shadow.scale = Vector2(2, 1.6) if big else Vector2.ONE * k
	for mb in v._multi_balls:
		mb[1].scale = v._ball_sprite.scale
		mb[2].scale = v._ball_shadow.scale
	if v.feel:
		v.feel._ball_scale = v._ball_sprite.scale


## A ball this far (world px) nearer the camera than the feet is on the
## near side: the low reach, and a step toward it.
const NEAR_SIDE := 5
const LEAN_MAX := 18.0             ## screen px, at most
const LEAN_IN := 0.35
const LEAN_OUT := 0.18


## Display only (KNOWN_ISSUES #69): during a reach at a ball on the near
## side, the drawn player steps down toward it, easing in through the
## windup and the contact, back out after; never the sim's player.
func swing_lean(i: int, feet: Vector2) -> Vector2:
	var p: SimTypes.Player = v.sim.players[i]
	var e: Dictionary = v._players[i]
	var target := 0.0
	if e.get("choice", "") == "reach" and p.state in [K.STATE_WINDUP, K.STATE_ACTIVE]:
		var b := v.sim.ball
		target = clampf(CourtView.ground(b.x_fp, b.y_fp).y - feet.y - 4.0, 0.0, LEAN_MAX)
	var now: float = e.get("lean", 0.0)
	now = lerpf(now, target, LEAN_IN if target > now else LEAN_OUT)
	if absf(now) < 0.3:
		now = 0.0
	e["lean"] = now
	return Vector2(0, roundf(now))
