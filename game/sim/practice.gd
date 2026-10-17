## Practice mode (ADR-028): a ball machine on the far baseline feeds the
## chosen shot to the chosen target; returns that land in (in the chosen
## return zone, if any) count toward a streak. No points, no serves, no
## rules faults. A port of reference/snes-src/src/practice.c, in its order.
##
## Pure like the rest of the sim: the saved settings and best come in on
## the MatchConfig, and leaving (practice_finish) is SaveGame's job.
class_name Practice
extends RefCounted

const Ball := SimTypes.Ball

const SHOT_DRIVE := 0
const SHOT_LOB := 1
const SHOT_DINK := 2
const SHOT_MIX := 3
const SHOTS := 4

const TARGET_KITCHEN := 0
const TARGET_DEEP := 1
const TARGET_FOREHAND := 2
const TARGET_BACKHAND := 3
const TARGET_AT_YOU := 4
const TARGET_RANDOM := 5
const TARGETS := 6

const RATE_SLOW := 0
const RATE_NORMAL := 1
const RATE_FAST := 2
const RATES := 3

## Where returns must land to count (M4-PRACTICE-03), on the machine's
## side. LEFT and RIGHT are P1's, facing the net: the far and near
## sidelines.
const ZONE_ANY := 0
const ZONE_KITCHEN := 1
const ZONE_DEEP := 2
const ZONE_LEFT := 3
const ZONE_RIGHT := 4
const ZONES := 5

## The machine: on the far baseline, centred; feeds leave its nozzle (the
## sprite's left edge, 8 px up).
const MACHINE_X := 232
const MACHINE_Y := 130
const MACHINE_Z := 8
const FIRST_FEED_FRAMES := 60
const FEED_TIMEOUT_FRAMES := 300     ## a stuck feed ends anyway
const STREAK_MAX := 99               ## two digits on the score panel
## The nozzle turns one pose per TURN_FRAMES toward the next feed's lane
## (up through centre to down), and kicks back on a feed.
const TURN_FRAMES := 6
const KICK_FRAMES := 6
const AIM_SPREAD := 12               ## lanes this far off centre turn
const ZONE_DEEP_DEPTH := 36          ## the DEEP zone, from the baseline
const ZONE_LINE_WIDTH := 22          ## LEFT and RIGHT, from the sideline
const ZONE_FLASH_FRAMES := 32        ## the zone's corners blink on a hit

## Nozzle poses, as seen on screen: toward the far sideline (up), the
## centre, or the near sideline (down).
const POSE_UP := 0
const POSE_CENTER := 1
const POSE_DOWN := 2

## Feed state.
const WAIT := 0
const FEED := 1
const RETURN := 2

## The left team's targets (collision.h COURT_MIRROR_X of the right's).
const HIT_TARGET_NEUTRAL_LEFT := 2 * K.COURT_NET_X - K.HIT_TARGET_NEUTRAL_RIGHT
const HIT_TARGET_DEEP_LEFT := 2 * K.COURT_NET_X - K.HIT_TARGET_DEEP_RIGHT
const HIT_TARGET_DINK_LEFT := 2 * K.COURT_NET_X - K.HIT_TARGET_DINK_RIGHT

## Practice page editor (like OPTIONS, ADR-025).
const ROW_SHOT := 0
const ROW_TARGET := 1
const ROW_RATE := 2
const ROW_ZONE := 3
const ROWS := 4
const EDIT_STAY := 0
const EDIT_DONE := 1
const EDIT_CANCEL := 2

## SNES pad bits (input.h), for the editor's `pressed`.
const PAD_B := 0x8000
const PAD_Y := 0x4000
const PAD_START := 0x1000
const PAD_UP := 0x0800
const PAD_DOWN := 0x0400
const PAD_LEFT := 0x0200
const PAD_RIGHT := 0x0100

const COUNTS := [SHOTS, TARGETS, RATES, ZONES]
## Defaults: MIX to RANDOM targets at a NORMAL rate, returns anywhere in.
const DEFAULTS := [SHOT_MIX, TARGET_RANDOM, RATE_NORMAL, ZONE_ANY]

## Each zone's ground rectangle: x0, y0, x1, y1, edges in (ANY: the side).
const ZONE_RECTS := [
	[K.COURT_NET_X, K.COURT_SIDELINE_TOP, K.COURT_BASELINE_RIGHT, K.COURT_SIDELINE_BOTTOM],
	[K.COURT_NET_X, K.COURT_SIDELINE_TOP, K.COURT_KITCHEN_RIGHT_X, K.COURT_SIDELINE_BOTTOM],
	[K.COURT_BASELINE_RIGHT - ZONE_DEEP_DEPTH, K.COURT_SIDELINE_TOP,
		K.COURT_BASELINE_RIGHT, K.COURT_SIDELINE_BOTTOM],
	[K.COURT_NET_X, K.COURT_SIDELINE_TOP, K.COURT_BASELINE_RIGHT,
		K.COURT_SIDELINE_TOP + ZONE_LINE_WIDTH],
	[K.COURT_NET_X, K.COURT_SIDELINE_BOTTOM - ZONE_LINE_WIDTH,
		K.COURT_BASELINE_RIGHT, K.COURT_SIDELINE_BOTTOM],
]

var sim: Sim

# PracticeState (practice.h)
var shot := SHOT_MIX            ## settings for this session
var target := TARGET_RANDOM
var rate := RATE_NORMAL
var zone := ZONE_ANY
var zone_flash := 0             ## frames left of the corners' blink
var state := WAIT
var timer := 0                  ## u16: frames until the next feed, or in this feed
var streak := 0
var best := 0                   ## this session, with the saved best folded in
var feeds := 0                  ## u8: drives the lanes and the MIX/RANDOM pattern
var rng := 0x5a
var last_shot := K.SHOT_STANDARD   ## ShotType of the last feed
var next_shot := K.SHOT_STANDARD   ## the planned next feed: ShotType, dink, target
var next_dink := 0
var next_target := TARGET_KITCHEN
var next_tx := 0                ## where it lands (AT YOU follows P1 in the wait)
var next_ty := 0
var aim := POSE_CENTER          ## POSE_* toward next_ty
var pose := POSE_CENTER         ## the nozzle on screen, turning toward aim
var turn_timer := 0
var kick := 0                   ## frames left of the feed's kick


func _init(owner: Sim) -> void:
	sim = owner


# --- Settings (saved): a valid value, or the default -----------------------------

static func practice_shot(saved: int) -> int:
	return saved if saved >= 0 and saved < SHOTS else SHOT_MIX

static func practice_target(saved: int) -> int:
	return saved if saved >= 0 and saved < TARGETS else TARGET_RANDOM

static func practice_rate(saved: int) -> int:
	return saved if saved >= 0 and saved < RATES else RATE_NORMAL

static func practice_zone(saved: int) -> int:
	return saved if saved >= 0 and saved < ZONES else ZONE_ANY

static func shot_name(s: int) -> String:
	return ["DRIVE", "LOB", "DINK", "MIX"][practice_shot(s)]

static func target_name(t: int) -> String:
	return ["KITCHEN", "DEEP", "FOREHAND", "BACKHAND", "AT YOU", "RANDOM"][practice_target(t)]

static func rate_name(r: int) -> String:
	return ["SLOW", "NORMAL", "FAST"][practice_rate(r)]

static func zone_name(z: int) -> String:
	return ["ANY", "KITCHEN", "DEEP", "LEFT LINE", "RIGHT LINE"][practice_zone(z)]

## A ground point (whole pixels) in a zone's rectangle.
static func in_zone(z: int, x: int, y: int) -> bool:
	var rect: Array = ZONE_RECTS[practice_zone(z)]
	return x >= rect[0] and y >= rect[1] and x <= rect[2] and y <= rect[3]

## Frames between one feed ending and the next.
static func rate_frames(r: int) -> int:
	return [120, 75, 40][practice_rate(r)]


## The score panels read P1 <streak> and BEST <best> (hud_scene.c).
func _show_score() -> void:
	sim.team_score[0] = streak
	sim.team_score[1] = best


## Starts a session (called by new_match in practice): no serve; the first
## feed comes after FIRST_FEED_FRAMES. The saved settings and the zone's
## saved best (practice_saved_best) arrive on the config.
func begin() -> void:
	var cfg := sim.config
	var settings: Array = cfg.practice_settings
	var saved_best := cfg.practice_best
	shot = practice_shot(int(settings[ROW_SHOT]))
	target = practice_target(int(settings[ROW_TARGET]))
	rate = practice_rate(int(settings[ROW_RATE]))
	zone = practice_zone(int(settings[ROW_ZONE]))
	zone_flash = 0
	state = WAIT
	timer = FIRST_FEED_FRAMES
	streak = 0
	best = STREAK_MAX if saved_best > STREAK_MAX else saved_best
	feeds = 0
	rng = 0x5a
	last_shot = K.SHOT_STANDARD
	pose = POSE_CENTER
	turn_timer = 0
	kick = 0
	sim.ball.active = 0
	sim.ball.rally_state = K.BALL_RALLY_INACTIVE
	sim.set_phase(K.PHASE_LIVE)
	_plan()
	_show_score()


## 8-bit LCG: the MIX and RANDOM pattern, the same every session.
func _next() -> int:
	rng = (rng * 5 + 3) & 0xff
	return rng >> 4


## Flight frames for a feed, by the players' shot paces (ADR-019).
static func flight(shot_type: int, dink: int, distance_px: int) -> int:
	var distance := K.to_fp(distance_px)
	if shot_type == K.SHOT_DRIVE:
		return clampi(distance / K.HIT_PACE_DRIVE_FP, K.HIT_DRIVE_MIN_FRAMES,
			K.HIT_DRIVE_MAX_FRAMES)
	if shot_type == K.SHOT_SOFT and not dink:
		return clampi(distance / K.HIT_PACE_LOB_FP, K.HIT_LOB_MIN_FRAMES,
			K.HIT_LOB_MAX_FRAMES)
	return clampi(distance / (K.HIT_PACE_DINK_FP if dink else K.HIT_PACE_NEUTRAL_FP),
		K.HIT_FLIGHT_MIN_FRAMES, K.HIT_FLIGHT_MAX_FRAMES)


## Where the planned feed lands (next_tx, next_ty), and the aim. AT YOU
## reads where P1 stands, so it is aimed again each frame of the wait.
func _aim() -> void:
	var lanes := [K.HIT_TARGET_LANE_TOP, K.HIT_TARGET_LANE_CENTER, K.HIT_TARGET_LANE_BOTTOM]
	var p1: SimTypes.Player = sim.players[0]
	var tx: int
	var ty: int = lanes[feeds % 3]
	match next_target:
		TARGET_DEEP:
			tx = HIT_TARGET_DEEP_LEFT
		TARGET_FOREHAND:            # facing the net, right hand is +y
			tx = HIT_TARGET_NEUTRAL_LEFT
			ty = K.HIT_TARGET_LANE_BOTTOM
		TARGET_BACKHAND:
			tx = HIT_TARGET_NEUTRAL_LEFT
			ty = K.HIT_TARGET_LANE_TOP
		TARGET_AT_YOU:
			tx = clampi(K.from_fp(p1.x_fp), K.COURT_BASELINE_LEFT + 8, HIT_TARGET_DINK_LEFT)
			ty = clampi(K.from_fp(p1.y_fp), K.HIT_TARGET_LANE_TOP, K.HIT_TARGET_LANE_BOTTOM)
		_:                          # the kitchen
			tx = HIT_TARGET_DINK_LEFT
	if next_dink:
		tx = HIT_TARGET_DINK_LEFT   # a dink always lands short
	next_tx = tx
	next_ty = ty
	if ty < MACHINE_Y - AIM_SPREAD:
		aim = POSE_UP
	elif ty > MACHINE_Y + AIM_SPREAD:
		aim = POSE_DOWN
	else:
		aim = POSE_CENTER


## Picks the next feed as the wait starts, so the machine turns toward it
## before it leaves. MIX and RANDOM draw in the same order as before.
func _plan() -> void:
	var s := shot
	var t := target
	if s == SHOT_MIX:
		s = _next() & 3             # DRIVE, LOB, DINK, or standard
	if t == TARGET_RANDOM:
		t = _next() % TARGET_RANDOM
	next_dink = 1 if s == SHOT_DINK else 0
	if s == SHOT_DRIVE:
		next_shot = K.SHOT_DRIVE
	elif s == SHOT_LOB or next_dink:
		next_shot = K.SHOT_SOFT
	else:
		next_shot = K.SHOT_STANDARD
	next_target = t
	_aim()


## The nozzle turns one pose at a time (up passes the centre to go down).
func _turn() -> void:
	if kick:
		kick -= 1
	if zone_flash:
		zone_flash -= 1
	if pose == aim:
		turn_timer = 0
		return
	turn_timer += 1
	if turn_timer < TURN_FRAMES:
		return
	turn_timer = 0
	if pose < aim:
		pose += 1
	else:
		pose -= 1


func _feed() -> void:
	# The muzzle of each pose, on the ground under the nozzle.
	var muzzle_y := [-4, 0, 3]
	var shot_type := next_shot
	var tx := next_tx
	var y: int = MACHINE_Y + muzzle_y[aim]
	# From the low nozzle a flat drive cannot clear the net and still land
	# in the kitchen: a "drive" there is a firm standard shot.
	if shot_type == K.SHOT_DRIVE and tx == HIT_TARGET_DINK_LEFT:
		shot_type = K.SHOT_STANDARD
	var b: Ball = sim.ball
	b.active = 1
	b.x_fp = K.to_fp(MACHINE_X)
	b.y_fp = K.to_fp(y)
	b.z_fp = K.to_fp(MACHINE_Z)
	b.rally_state = K.BALL_RALLY_LIVE
	b.last_hitter = 2               # the machine plays the right team
	b.bounce_count = 0
	Sim.launch(b, tx, next_ty, flight(shot_type, next_dink, MACHINE_X - tx))
	sim.shot_serial = (sim.shot_serial + 1) & 0xff
	sim.emit(K.EVENT_HIT, MACHINE_X, y, 2 | (shot_type << 4))
	last_shot = shot_type
	state = FEED
	timer = 0
	kick = KICK_FRAMES
	feeds = (feeds + 1) & 0xff


## A feed is over: a return that landed in (good) adds to the streak.
func _end_feed(good: bool) -> void:
	if not good:
		streak = 0
	elif streak < STREAK_MAX:
		streak += 1
	if streak > best:
		best = streak
	# The crowd notices every fifth return in a row (ADR-029).
	if good and streak % 5 == 0:
		sim.emit(K.EVENT_CROWD, MACHINE_X, MACHINE_Y, 13 if streak >= 20 else 9)
	sim.ball.active = 0
	sim.ball.rally_state = K.BALL_RALLY_INACTIVE
	state = WAIT
	timer = rate_frames(rate)
	_plan()
	_show_score()


## One frame of the session, after the players moved (game_update).
func update() -> void:
	_turn()
	if state == WAIT:
		# AT YOU follows P1 through the wait; then the machine finishes
		# turning before it feeds, so it always points where the ball goes.
		if timer:
			timer -= 1
			if next_target == TARGET_AT_YOU:
				_aim()
		elif pose == aim:
			_feed()
		return
	timer = (timer + 1) & 0xffff
	if timer > FEED_TIMEOUT_FRAMES:
		_end_feed(false)
		return
	var hit := sim.resolve_player_hits()
	if hit:
		sim.contact(hit - 1)
		state = RETURN
	var ev := sim.step_ball()
	if ev & K.BALL_EVENT_NET_FAULT:
		_end_feed(false)
		return
	if not (ev & K.BALL_EVENT_BOUNCE):
		return
	var b: Ball = sim.ball
	# Bounces sound like a match's (ADR-029).
	sim.emit(K.EVENT_BOUNCE, K.from_fp(b.x_fp), K.from_fp(b.y_fp), b.bounce_count)
	if state == RETURN:
		# The return's first bounce: in on the machine's side, and in the
		# zone if there is one, is good; the zone's corners blink.
		var good: bool = not (ev & K.BALL_EVENT_OUT) and Sim.x_on_side(b.x_fp, 1) \
			and in_zone(zone, K.from_fp(b.x_fp), K.from_fp(b.y_fp))
		if good and zone != ZONE_ANY:
			zone_flash = ZONE_FLASH_FRAMES
		_end_feed(good)
	elif b.bounce_count >= 2:
		_end_feed(false)            # the feed bounced twice: missed


## The best to save on leaving (practice_finish's test): higher than the
## zone's saved best. SaveGame.finish_practice writes it.
func new_best() -> bool:
	return best > sim.config.practice_best


# --- The practice page editor (PracticeEdit) ----------------------------------------

class Edit:
	var row := ROW_SHOT
	var original := [0, 0, 0, 0]

	## values: shot, target, rate, zone (the saved settings, made valid in
	## place).
	func begin(values: Array) -> void:
		for i in ROWS:
			if int(values[i]) < 0 or int(values[i]) >= COUNTS[i]:
				values[i] = DEFAULTS[i]
			original[i] = values[i]
		row = ROW_SHOT

	func changed(values: Array) -> bool:
		for i in ROWS:
			if values[i] != original[i]:
				return true
		return false

	## Up/Down rows, Left/Right values (wrapping), B or Start plays, Y cancels.
	func input(values: Array, pressed: int) -> int:
		var count: int = COUNTS[row]
		if pressed & PAD_Y:
			for i in ROWS:
				values[i] = original[i]
			return EDIT_CANCEL
		if pressed & (PAD_B | PAD_START):
			return EDIT_DONE
		if pressed & PAD_UP:
			row = row - 1 if row else ROWS - 1
		elif pressed & PAD_DOWN:
			row = 0 if row == ROWS - 1 else row + 1
		elif pressed & PAD_LEFT:
			values[row] = values[row] - 1 if values[row] else count - 1
		elif pressed & PAD_RIGHT:
			values[row] = 0 if values[row] + 1 >= count else values[row] + 1
		return EDIT_STAY
