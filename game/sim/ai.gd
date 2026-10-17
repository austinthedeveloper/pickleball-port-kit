## The CPU controller: a port of reference/snes-src/src/ai.c. Legible, not
## optimal: it predicts the landing with the ball's own constants, meets
## the ball near the top of its bounce, swings when the first contact of a
## swing pressed now would be in the sweet spot (or as a last chance), and
## is deliberately late every Nth ball. No randomness, and it never reads a
## human's future input.
class_name SimAI
extends RefCounted

const Ball := SimTypes.Ball
const Player := SimTypes.Player
const Intent := SimTypes.Intent
const AiState := SimTypes.AiState
const AiStyle := SimTypes.AiStyle

var sim  # Sim (untyped: the two classes reference each other)
var slots: Array = []           # AiState per slot (traced)
var styles: Array = []          # AiStyle per slot

# Per-think context (C statics).
var g: AiState                  # the slot being updated
var style: AiStyle
var slot := 0
var has_partner := false
var partner_human := false
var mate: Player
var impact_vz := 0
var contact_volley := false
var contact_z := 0
var reach_x := 0
var reach_y := 0
var block_volley := [0, 0, 0, 0]
var open_aim := [2, 2, 2, 2]
var volley_check := [0, 0, 0, 0]
var last_think := [0, 0, 0, 0]
var held_intent: Array = []

# Landing cache.
var land_valid := false
var land_serial := 0
var land_bounces := 0
var land_step := 0
var land_x := 0
var land_y := 0
var land_impact_vz := 0

# Probe (the swing lookahead's ball).
var px := 0
var py := 0
var pz := 0
var pvx := 0
var pvy := 0
var pvz := 0
var pbounces := 0


func _init(owner_sim) -> void:
	sim = owner_sim
	for i in K.MAX_PLAYERS:
		slots.append(AiState.new())
		styles.append(Opponents.default_style())
		held_intent.append(Intent.new())


func initialize() -> void:
	for i in K.MAX_PLAYERS:
		slots[i] = AiState.new()
		styles[i] = Opponents.default_style()
		held_intent[i] = Intent.new()
	land_valid = false
	contact_volley = false
	block_volley = [0, 0, 0, 0]
	open_aim = [K.AI_AIM_PATTERN, K.AI_AIM_PATTERN, K.AI_AIM_PATTERN, K.AI_AIM_PATTERN]
	volley_check = [0, 0, 0, 0]
	last_think = [0, 0, 0, 0]


func _volleys_legal() -> bool:
	return sim.required_bounce == K.REQUIRED_BOUNCE_NONE

func _volleys(s: AiStyle) -> bool:
	return s.volley != 0 and _volleys_legal()


## Next ground contact using the ball's own constants: steps (<= cap).
func predict_landing(b: Ball) -> Array:
	var z := b.z_fp
	var vz := b.vz_fp
	var steps := 0
	impact_vz = 0
	if z <= 0 and vz <= 0:
		return [0, K.from_fp(b.x_fp), K.from_fp(b.y_fp)]
	var block_fall := 28 * K.BALL_GRAVITY_FP
	while steps + K.AI_PREDICT_BLOCK <= K.AI_PREDICT_MAX_STEPS:
		var rise := 8 * vz + block_fall
		if z + rise <= 0:
			break
		z += rise
		vz += K.AI_PREDICT_BLOCK * K.BALL_GRAVITY_FP
		steps += K.AI_PREDICT_BLOCK
	while steps < K.AI_PREDICT_MAX_STEPS:
		z += vz
		vz += K.BALL_GRAVITY_FP
		steps += 1
		if z <= 0:
			break
	impact_vz = vz - K.BALL_GRAVITY_FP
	return [steps, K.from_fp(b.x_fp + b.vx_fp * steps), K.from_fp(b.y_fp + b.vy_fp * steps)]


static func _move_toward(from: int, to: int) -> int:
	var d := to - from
	if d > K.AI_DEAD_ZONE:
		return 1
	if d < -K.AI_DEAD_ZONE:
		return -1
	return 0

func _ball_incoming(p: Player) -> bool:
	var b: Ball = sim.ball
	if b.rally_state != K.BALL_RALLY_LIVE:
		return false
	if b.last_hitter < K.MAX_PLAYERS and int(b.last_hitter >= 2) == p.team:
		return false
	return true

func _owns_y(y: int) -> bool:
	if not has_partner:
		return true
	return (y < K.COURT_CENTERLINE_Y) == Sim.lane_top(slot)

func _owns_point(p: Player, x: int, y: int, volley: bool) -> bool:
	var dy := y - K.COURT_CENTERLINE_Y
	if not has_partner or style.team == 0 \
			or absi(dy) > (K.AI_POACH_BAND if volley else K.AI_MIDDLE_BAND):
		return _owns_y(y)
	var me := absi(x - K.from_fp(p.x_fp)) + absi(y - K.from_fp(p.y_fp))
	var them := absi(x - K.from_fp(mate.x_fp)) + absi(y - K.from_fp(mate.y_fp))
	if me + K.AI_MIDDLE_MARGIN < them:
		return true
	if partner_human:
		return _owns_y(y)
	if them + K.AI_MIDDLE_MARGIN < me:
		return false
	return _owns_y(y)

func _opponent_at_net(team: int, distance: int) -> bool:
	var a: Player = sim.players[0] if team else sim.players[2]
	var b: Player = sim.players[1] if team else sim.players[3]
	if a.active and absi(K.from_fp(a.x_fp) - K.COURT_NET_X) < distance:
		return true
	return b.active and absi(K.from_fp(b.x_fp) - K.COURT_NET_X) < distance

static func _open_by(t: int, a: int, b: int) -> int:
	return mini(absi(a - t), absi(b - t))

## The open spot (ADR-039), doubles with tactics.
func _open_spot(team: int) -> int:
	var P: Array = sim.players
	var ya: int
	var yb: int
	var xa: int
	var xb: int
	if team:
		ya = P[0].y_fp
		yb = P[1].y_fp
		xa = K.to_fp(K.COURT_NET_X) - P[0].x_fp
		xb = K.to_fp(K.COURT_NET_X) - P[1].x_fp
	else:
		ya = P[2].y_fp
		yb = P[3].y_fp
		xa = P[2].x_fp - K.to_fp(K.COURT_NET_X)
		xb = P[3].x_fp - K.to_fp(K.COURT_NET_X)
	if xa > xb + K.to_fp(K.AI_SPLIT_DISTANCE):
		return -1 if ya < K.to_fp(K.COURT_CENTERLINE_Y) else 1
	if xb > xa + K.to_fp(K.AI_SPLIT_DISTANCE):
		return -1 if yb < K.to_fp(K.COURT_CENTERLINE_Y) else 1
	var top := _open_by(K.to_fp(K.HIT_TARGET_LANE_TOP), ya, yb)
	var bottom := _open_by(K.to_fp(K.HIT_TARGET_LANE_BOTTOM), ya, yb)
	var middle := _open_by(K.to_fp(K.HIT_TARGET_LANE_CENTER), ya, yb) \
		+ K.to_fp(K.AI_OPEN_MARGIN)
	if top >= bottom and top > middle:
		return -1
	if bottom > top and bottom > middle:
		return 1
	return 0 if (g.shot_counter & 1) else K.AI_AIM_PATTERN

func _plan_shot(p: Player, cz: int) -> void:
	var n := g.shot_counter
	var dink := style.dink_period
	var to_net := absi(K.from_fp(p.x_fp) - K.COURT_NET_X)
	block_volley[slot] = 0
	if cz >= K.to_fp(style.putaway_z) and to_net < style.putaway_distance:
		g.planned_shot = K.SHOT_DRIVE
		g.planned_depth = 0
	elif contact_volley:
		g.planned_shot = K.SHOT_STANDARD
		g.planned_depth = 0
		block_volley[slot] = 1
	elif style.tactics and (not partner_human or to_net < K.AI_UP_DISTANCE) \
			and _opponent_at_net(p.team, K.AI_UP_DISTANCE):
		g.planned_shot = K.SHOT_SOFT
		g.planned_depth = 1 if (to_net >= K.AI_UP_DISTANCE and style.lob_distance \
			and (n % 3) == 2) else -1
	elif style.lob_distance and _opponent_at_net(p.team, style.lob_distance):
		g.planned_shot = K.SHOT_SOFT
		g.planned_depth = 1
	elif dink and (n % dink) == dink - 1:
		g.planned_shot = K.SHOT_SOFT
		g.planned_depth = -1
	else:
		g.planned_shot = K.SHOT_STANDARD
		g.planned_depth = 1 if (style.depth == K.DEPTH_DEEP or (n & 1)) else 0

func _choose_aim(p: Player, intent: Intent) -> void:
	var P: Array = sim.players
	var opponent: Player = P[0] if p.team else P[2]
	if not opponent.active:
		opponent = P[1] if p.team else P[3]
	if block_volley[slot]:
		intent.aim_y = 0
	elif open_aim[slot] < K.AI_AIM_PATTERN:
		intent.aim_y = open_aim[slot]
	elif has_partner:
		intent.aim_y = -1 if ((g.shot_counter ^ (g.shot_counter >> 1)) & 1) else 1
	elif style.aim == K.AIM_MIX:
		intent.aim_y = -1 if ((g.shot_counter ^ (g.shot_counter >> 2)) & 1) else 1
	else:
		intent.aim_y = 1 if opponent.y_fp < K.to_fp(K.COURT_CENTERLINE_Y) else -1
		if style.aim == K.AIM_BODY:
			intent.aim_y = -intent.aim_y
	intent.aim_x = -g.planned_depth if p.team else g.planned_depth
	intent.shot = g.planned_shot


# --- Swing lookahead ----------------------------------------------------------------

func _probe_load(b: Ball) -> void:
	px = b.x_fp
	py = b.y_fp
	pz = b.z_fp
	pvx = b.vx_fp
	pvy = b.vy_fp
	pvz = b.vz_fp
	pbounces = b.bounce_count

## One probe step, exactly as Sim.simulate_step moves the ball.
func probe_step() -> void:
	if pz == 0 and pvz <= 0:
		pvx = 0
		pvy = 0
		pvz = 0
		return
	var prev_z := pz
	px += pvx
	py += pvy
	pz += pvz
	pvz += K.BALL_GRAVITY_FP
	if prev_z > 0 and pz <= 0:
		var iv := pvz - K.BALL_GRAVITY_FP
		pz = 0
		pvx = Sim.retain(pvx, K.BALL_BOUNCE_PLANAR_256)
		pvy = Sim.retain(pvy, K.BALL_BOUNCE_PLANAR_256)
		pvz = -Sim.retain(iv, K.BALL_BOUNCE_VERTICAL_256)
		pbounces += 1
		if pvz <= K.BALL_MIN_BOUNCE_VZ_FP:
			pvx = 0
			pvy = 0
			pvz = 0

## The probe through frame `frame`'s ball steps (one at a steady pace).
func _probe_frame(frame: int) -> void:
	if not sim.ball_paced:
		probe_step()
		return
	for n in sim.steps_ahead(frame):
		probe_step()

## How far a player slides after pressing swing (ADR-038 footwork).
static func _slide(v: int, limit: int) -> int:
	v = Sim._approach_zero(v)
	v = clampi(v, -limit, limit)
	var total := v
	while v:
		v = Sim._approach_zero(v)
		total += v
	return total

func _probe_in_reach() -> bool:
	var gw: int = sim.grow_fp
	return Sim._within(px - reach_x, K.to_fp(K.HIT_REACH_X) + gw) \
		and Sim._within(py - reach_y, K.to_fp(K.HIT_REACH_Y) + gw) \
		and pz >= 0 and pz <= K.to_fp(K.HIT_REACH_Z) + gw

func _probe_in_sweet() -> bool:
	var gw: int = sim.grow_fp
	return Sim._within(px - reach_x, K.to_fp(K.HIT_SWEET_X) + gw) \
		and Sim._within(py - reach_y, K.to_fp(K.HIT_SWEET_Y) + gw)

## R23: over the window's 7 steps the ball stays between where it is and
## 7 steps of velocity on: when that range misses the box, no step reaches.
static func _window_misses(at: int, v: int, box: int, half: int) -> bool:
	var a := at
	var b := at + 7 * v
	var low := box - half
	var span := 2 * half
	if a > b:
		return a < low or b > low + span
	return b < low or a > low + span

func _swing_connects(p: Player) -> bool:
	var b: Ball = sim.ball
	var step := 1
	var dx := K.from_fp(b.x_fp) - K.from_fp(p.x_fp)
	if dx > 64 or dx < -64:
		return false
	var volleys := _volleys(style)
	if b.bounce_count == 0 and not volleys \
			and g.predicted_frames > g.plan_age + K.PLAYER_WINDUP_FRAMES + K.PLAYER_ACTIVE_FRAMES:
		return false
	if not b.active or b.rally_state != K.BALL_RALLY_LIVE:
		return false
	_probe_load(b)
	reach_x = p.x_fp
	reach_y = p.y_fp
	if style.footwork:
		reach_x += _slide(p.vx_fp, Paddles.swing_limit(p.paddle))
		reach_y += _slide(p.vy_fp, Paddles.swing_limit(p.paddle))
	var paced: bool = sim.ball_paced
	if not paced and (_window_misses(b.x_fp, b.vx_fp, reach_x, K.to_fp(K.HIT_REACH_X) + sim.grow_fp) \
			or _window_misses(b.y_fp, b.vy_fp, reach_y, K.to_fp(K.HIT_REACH_Y) + sim.grow_fp)):
		return false
	if not paced and (pz != 0 or pvz > 0):
		var rise := 3 * pvz + 3 * K.BALL_GRAVITY_FP
		if pz + rise > 0:
			pz += rise
			pvz += 3 * K.BALL_GRAVITY_FP
			px += 3 * pvx
			py += 3 * pvy
			step = K.PLAYER_WINDUP_FRAMES
	elif paced and (pz != 0 or pvz > 0):
		# The paced steps of frames 0-2, airborne, are one exact block.
		var n: int = sim.steps_ahead(0) + sim.steps_ahead(1) + sim.steps_ahead(2)
		var rise2 := 0
		var fall := 0
		for k in n:
			rise2 += pvz + fall
			fall += K.BALL_GRAVITY_FP
		if pz + rise2 > 0:
			pz += rise2
			pvz += fall
			px += n * pvx
			py += n * pvy
			step = K.PLAYER_WINDUP_FRAMES
	var last := K.PLAYER_WINDUP_FRAMES + K.PLAYER_ACTIVE_FRAMES
	while step <= last:
		_probe_frame(step - 1)
		if step < K.PLAYER_WINDUP_FRAMES:
			step += 1
			continue
		if not _probe_in_reach():
			step += 1
			continue
		contact_z = pz
		contact_volley = pbounces == 0
		if pbounces == 0 and (not volleys or pz < K.AI_VOLLEY_MIN_Z \
				or not Sim.contains_ground_fp(K.to_fp(g.predicted_land_x),
					K.to_fp(g.predicted_land_y))):
			return false
		if not Sim.x_on_side(px, p.team):
			return false
		if partner_human and not _owns_point(p, K.from_fp(px), K.from_fp(py), pbounces == 0):
			return false
		if step == last:
			return false
		if _probe_in_sweet():
			if not g.late_this_ball:
				return true
			if not partner_human:
				return false
			while step < last:
				_probe_frame(step)
				step += 1
			return (px > reach_x if p.team else px < reach_x) \
				and not Sim.contains_ground_fp(px, py)
		while step < last:
			_probe_frame(step)
			step += 1
		return not _probe_in_reach()
	return false


# --- Planning -------------------------------------------------------------------------

func _may_come_in(team: int) -> bool:
	if sim.phase != K.PHASE_LIVE:
		return false
	return sim.required_bounce == K.REQUIRED_BOUNCE_NONE \
		or (sim.required_bounce == K.REQUIRED_BOUNCE_RETURN and team != sim.serving_team)

func _plan_volley(p: Player, land_steps: int, lx: int) -> bool:
	var b: Ball = sim.ball
	var x := p.x_fp
	var pxx := K.from_fp(x)
	var bx := K.from_fp(b.x_fp)
	var vx := b.vx_fp
	if not vx or ((pxx - bx) < 0) != ((lx - pxx) < 0) or pxx == lx:
		return false
	var t := (x - b.x_fp) / vx
	if t <= 0 or t >= land_steps:
		return false
	var z := b.z_fp + t * b.vz_fp + K.BALL_GRAVITY_FP * (t * (t - 1) / 2)
	if z < K.AI_VOLLEY_MIN_Z or z > K.to_fp(K.HIT_REACH_Z) + sim.grow_fp - K.to_fp(2):
		return false
	g.target_x = K.from_fp(x)
	g.target_y = K.from_fp(b.y_fp + t * b.vy_fp)
	g.has_target = 1 if _owns_point(p, g.target_x, g.target_y, true) else 0
	return true

static func _steps_inside(x: int, y: int, vx: int, vy: int, steps: int) -> int:
	x += vx * steps
	y += vy * steps
	while steps and not Sim.contains_ground_fp(x, y):
		x -= vx
		y -= vy
		steps -= 1
	return steps

func _plan_intercept(p: Player) -> void:
	var b: Ball = sim.ball
	var behind := K.AI_CONTACT_OFFSET_X if p.team else -K.AI_CONTACT_OFFSET_X
	if b.bounce_count > 0 and Sim.x_on_side(b.x_fp, p.team):
		var rise := _steps_inside(b.x_fp, b.y_fp, b.vx_fp, b.vy_fp, 6) if partner_human else 6
		g.target_x = K.from_fp(b.x_fp + b.vx_fp * rise) + behind
		g.target_y = K.from_fp(b.y_fp + b.vy_fp * rise)
		if not style.team and land_valid and land_serial == sim.shot_serial \
				and land_bounces == 0:
			g.has_target = 1 if _owns_point(p, land_x, land_y, false) else 0
		else:
			g.has_target = 1 if _owns_point(p, K.from_fp(b.x_fp), K.from_fp(b.y_fp), false) else 0
		_avoid_lava(p)
		return
	var steps: int
	var lx: int
	var ly: int
	if land_valid and land_serial == sim.shot_serial and land_bounces == b.bounce_count:
		steps = (land_step - sim.ball_steps) & 0xff
		lx = land_x
		ly = land_y
		impact_vz = land_impact_vz
	else:
		var r := predict_landing(b)
		steps = r[0]
		lx = r[1]
		ly = r[2]
		land_valid = steps != 0 and steps < K.AI_PREDICT_MAX_STEPS
		land_serial = sim.shot_serial
		land_bounces = b.bounce_count
		land_step = (sim.ball_steps + steps) & 0xffff
		land_x = lx
		land_y = ly
		land_impact_vz = impact_vz
	# FAST BALL: N steps take at least N - N/4 - 1 frames (safe early-out).
	if (sim.config.modifiers & K.MOD_FAST_BALL) and steps > 1:
		steps -= (steps >> 2) + 1
	g.predicted_frames = steps
	g.predicted_land_x = lx
	g.predicted_land_y = ly
	volley_check[slot] = 1 if (_volleys(style) and b.bounce_count == 0 and land_valid \
		and Sim.contains_ground_fp(K.to_fp(lx), K.to_fp(ly)) \
		and Sim.x_on_side(K.to_fp(lx), p.team)) else 0
	if not Sim.contains_ground_fp(K.to_fp(lx), K.to_fp(ly)) \
			or not Sim.x_on_side(K.to_fp(lx), p.team):
		g.has_target = 0
		return
	var bounce_vz := Sim.retain(-impact_vz, K.BALL_BOUNCE_VERTICAL_256)
	var rise2 := (bounce_vz / -K.BALL_GRAVITY_FP) & 0xff
	if rise2 > 10:
		rise2 = 10
	var vx := Sim.retain(b.vx_fp, K.BALL_BOUNCE_PLANAR_256)
	var vy := Sim.retain(b.vy_fp, K.BALL_BOUNCE_PLANAR_256)
	if partner_human:
		rise2 = _steps_inside(K.to_fp(lx), K.to_fp(ly), vx, vy, rise2)
	g.target_x = lx + K.from_fp(vx * rise2) + behind
	g.target_y = ly + K.from_fp(vy * rise2)
	_avoid_lava(p)
	g.has_target = 1 if _owns_point(p, lx, ly, false) else 0


## LAVA: an intercept never asks a CPU into its own kitchen.
func _avoid_lava(p: Player) -> void:
	if sim.config.modifiers & K.MOD_LAVA:
		g.target_x = Sim.lava_target(g.target_x, p.team)


# --- Entry points -------------------------------------------------------------------------

func _set_context(i: int) -> void:
	slot = i
	mate = sim.players[i ^ 1]
	style = styles[i]
	has_partner = mate.active != 0
	partner_human = has_partner and sim.owners[i ^ 1] == K.OWNER_HUMAN

## KID (ADR-025): a human's swing pressed now would meet the ball.
func assist_swing(i: int) -> bool:
	var p: Player = sim.players[i]
	if sim.phase == K.PHASE_SERVE_SETUP:
		return sim.server_index == i and sim.phase_timer >= K.AI_ASSIST_SERVE_FRAMES
	if sim.phase != K.PHASE_LIVE or Sim.is_swinging(p) or not _ball_incoming(p):
		return false
	var saved_g := g
	var saved_style := style
	g = _copy_state(slots[i])
	g.late_this_ball = 0
	g.predicted_frames = 0
	style = Opponents.default_style()
	slot = i
	has_partner = false
	partner_human = false
	var connects := _swing_connects(p)
	g = saved_g
	style = saved_style
	return connects

static func _copy_state(s: AiState) -> AiState:
	var c := AiState.new()
	var arr := s.to_array()
	var names := ["has_target", "target_x", "target_y", "predicted_land_x",
		"predicted_land_y", "predicted_frames", "plan_age", "shot_counter",
		"plan_key", "reaction_frames", "incoming_frames", "late_period",
		"returns", "late_this_ball", "seen_shot", "planned_shot", "planned_depth"]
	for k in names.size():
		c.set(names[k], arr[k])
	return c

func hold_intent(i: int, intent: Intent) -> void:
	intent.copy_from(held_intent[i])
	intent.hit_pressed = 0

func update(i: int, intent: Intent) -> void:
	_set_context(i)
	g = slots[i]
	_think(i, intent)
	held_intent[i].copy_from(intent)

func _think(i: int, intent: Intent) -> void:
	var p: Player = sim.players[i]
	var b: Ball = sim.ball
	var elapsed: int = (sim.frame_count - last_think[i]) & 0xffff
	last_think[i] = sim.frame_count
	intent.move_x = 0
	intent.move_y = 0
	intent.aim_x = 0
	intent.aim_y = 0
	intent.hit_pressed = 0
	intent.pause_pressed = 0
	if not p.active or sim.paused:
		return
	if sim.phase == K.PHASE_SERVE_SETUP or sim.phase == K.PHASE_SERVE_TOSS:
		if sim.server_index != i:
			return
		block_volley[i] = 0
		open_aim[i] = K.AI_AIM_PATTERN
		g.planned_shot = K.SHOT_STANDARD
		if (g.shot_counter & 3) == 3:
			g.planned_depth = -1
		else:
			g.planned_depth = 1 if (g.shot_counter & 1) else 0
		_choose_aim(p, intent)
		if sim.phase == K.PHASE_SERVE_SETUP and sim.phase_timer >= K.AI_SERVE_DELAY_FRAMES:
			intent.hit_pressed = 1
			g.shot_counter = (g.shot_counter + 1) & 0xff
		return
	if sim.phase != K.PHASE_LIVE:
		return
	var x := K.from_fp(p.x_fp)
	var y := K.from_fp(p.y_fp)
	if Sim.is_swinging(p):
		if p.state == K.STATE_WINDUP and p.state_frames_remaining == K.PLAYER_WINDUP_FRAMES:
			open_aim[i] = _open_spot(p.team) if (has_partner and style.tactics) \
				else K.AI_AIM_PATTERN
		_choose_aim(p, intent)
		return
	var incoming := _ball_incoming(p)
	if not incoming:
		g.incoming_frames = 0
	elif elapsed >= 255 - g.incoming_frames:
		g.incoming_frames = 255
	else:
		g.incoming_frames += elapsed
	if incoming and g.incoming_frames > g.reaction_frames:
		var key: int = ((b.last_hitter << 4) | (b.bounce_count & 15)) & 0xff
		if sim.shot_serial != g.seen_shot:
			g.seen_shot = sim.shot_serial
			g.returns = (g.returns + 1) & 0xff
			g.late_this_ball = 1 if (g.late_period and (g.returns % g.late_period) == 0) else 0
		if key != g.plan_key or b.bounce_count > 0:
			_plan_intercept(p)
			g.plan_key = key
			g.plan_age = 0
		else:
			if g.plan_age < 255:
				g.plan_age += 1
			if volley_check[i]:
				volley_check[i] = 0
				if b.bounce_count == 0 and _volleys(style) and land_serial == sim.shot_serial:
					_plan_volley(p, (land_step - sim.ball_steps) & 0xff, land_x)
		if (not has_partner or g.has_target) and not Sim.is_swinging(p) \
				and _swing_connects(p):
			_plan_shot(p, contact_z)
			_choose_aim(p, intent)
			intent.hit_pressed = 1
			g.shot_counter = (g.shot_counter + 1) & 0xff
			return
	else:
		g.has_target = 0
		g.plan_key = 0xff
	if not g.has_target:
		var home: int = style.net if (style.net and _may_come_in(p.team)) else style.recover
		if style.team and partner_human and home == style.net \
				and absi(K.from_fp(mate.x_fp) - K.COURT_NET_X) > K.AI_PAIR_UP_DISTANCE:
			home = style.recover
		g.target_x = K.COURT_NET_X + home if p.team else K.COURT_NET_X - home
		if not has_partner:
			g.target_y = K.AI_RECOVER_Y
		elif Sim.lane_top(i):
			g.target_y = K.AI_RECOVER_Y_TOP
		else:
			g.target_y = K.AI_RECOVER_Y_BOTTOM
		if has_partner and style.team and not Sim.x_on_side(b.x_fp, p.team):
			var shift := clampi((K.from_fp(b.y_fp) - K.COURT_CENTERLINE_Y) >> 2,
				-K.AI_SHIFT_MAX, K.AI_SHIFT_MAX)
			g.target_y += shift
	intent.move_x = _move_toward(x, g.target_x)
	intent.move_y = _move_toward(y, g.target_y)
