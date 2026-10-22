## Simulation constants, ported from reference/snes-src/include (court.h,
## ball.h, collision.h, player.h, serve.h, game.h, ai.h). World units are
## the SNES ground pixels; motion is 12.4 fixed point (1/16 px) in ints.
## Change a value here and the golden trace must change with it.
class_name K
extends RefCounted

const FP_SHIFT := 4
const FP_ONE := 16

static func to_fp(v: int) -> int:
	return v << FP_SHIFT

static func from_fp(v: int) -> int:
	return v >> FP_SHIFT

# --- Court (court.h) -----------------------------------------------------
const COURT_BASELINE_LEFT := 16
const COURT_BASELINE_RIGHT := 240
const COURT_SIDELINE_TOP := 90
const COURT_SIDELINE_BOTTOM := 170
const COURT_NET_X := 128
const COURT_KITCHEN_LEFT_X := 92
const COURT_KITCHEN_RIGHT_X := 164
const COURT_CENTERLINE_Y := 130
const COURT_NET_HEIGHT := 12

const PLAYER_RUNOFF_BACK := 12
const PLAYER_RUNOFF_SIDE := 10
const PLAYER_NET_GAP := 8
const PLAYER_SPAWN_X := 40
const PLAYER_SPAWN_Y := 150
const PLAYER_CLAMP_MIN_X := COURT_BASELINE_LEFT - PLAYER_RUNOFF_BACK
const PLAYER_CLAMP_MAX_X := COURT_NET_X - PLAYER_NET_GAP
const PLAYER_CLAMP_MIN_Y := COURT_SIDELINE_TOP - PLAYER_RUNOFF_SIDE + 4
const PLAYER_CLAMP_MAX_Y := COURT_SIDELINE_BOTTOM + PLAYER_RUNOFF_SIDE
const PLAYER_RIGHT_CLAMP_MIN_X := COURT_NET_X + PLAYER_NET_GAP
const PLAYER_RIGHT_CLAMP_MAX_X := COURT_BASELINE_RIGHT + PLAYER_RUNOFF_BACK

static func mirror_x(x: int) -> int:
	return 2 * COURT_NET_X - x

# --- Ball (ball.h) ---------------------------------------------------------
const BALL_GRAVITY_FP := -3
const BALL_BOUNCE_VERTICAL_256 := 141
const BALL_BOUNCE_PLANAR_256 := 236
const BALL_MIN_BOUNCE_VZ_FP := 4
const BALL_START_X := 104
const BALL_START_Y := 112
const BALL_NO_HITTER := 0xff

const BALL_RALLY_INACTIVE := 0
const BALL_RALLY_LIVE := 1

const BALL_EVENT_NONE := 0
const BALL_EVENT_BOUNCE := 1
const BALL_EVENT_NET_FAULT := 2
const BALL_EVENT_OUT := 4

# --- Hits (collision.h) ------------------------------------------------------
const HIT_REACH_X := 22
const HIT_REACH_Y := 16
const HIT_REACH_Z := 24
const HIT_SWEET_X := 14
const HIT_SWEET_Y := 10
const HIT_STRETCH_WIDE := 20
const HIT_STRETCH_LONG := 16
const HIT_TARGET_LANE_TOP := COURT_SIDELINE_TOP + 14
const HIT_TARGET_LANE_CENTER := COURT_CENTERLINE_Y
const HIT_TARGET_LANE_BOTTOM := COURT_SIDELINE_BOTTOM - 14
const HIT_TARGET_SHORT_RIGHT := COURT_KITCHEN_RIGHT_X + 12
const HIT_TARGET_NEUTRAL_RIGHT := COURT_KITCHEN_RIGHT_X + 40
const HIT_TARGET_DEEP_RIGHT := COURT_BASELINE_RIGHT - 12
const HIT_PACE_DEEP_FP := 48
const HIT_PACE_NEUTRAL_FP := 44
const HIT_PACE_SHORT_FP := 40
const HIT_FLIGHT_MIN_FRAMES := 24
const HIT_FLIGHT_MAX_FRAMES := 46
const HIT_PACE_DRIVE_FP := 60
const HIT_DRIVE_MIN_FRAMES := 16
const HIT_DRIVE_MAX_FRAMES := 30
const HIT_DRIVE_STRETCH_WIDE := 26
const HIT_DRIVE_STRETCH_LONG := 22
const HIT_PACE_LOB_FP := 28
const HIT_LOB_MIN_FRAMES := 44
const HIT_LOB_MAX_FRAMES := 50
const HIT_PACE_DINK_FP := 24
const HIT_TARGET_DINK_RIGHT := COURT_NET_X + 18
# The slice and the fast drop (SNES ADR-056, collision.h)
const HIT_PACE_SLICE_FP := 30          ## 1.875 px/frame
const HIT_SLICE_MIN_FRAMES := 34
const HIT_SLICE_STRETCH_WIDE := 10
const HIT_SLICE_STRETCH_LONG := 8
const HIT_FAST_DROP_STRETCH_LONG := 34  ## a drive aimed short, off a stretch
# The overhead (ADR-053, port-only): a standard or drive swing at a falling
# ball this high becomes a smash, fast and steep.
const HIT_OVERHEAD_Z := 20
const HIT_PACE_OVERHEAD_FP := 120
const HIT_OVERHEAD_MIN_FRAMES := 10
const HIT_OVERHEAD_MAX_FRAMES := 22
const HIT_OVERHEAD_STRETCH_WIDE := 24
const HIT_OVERHEAD_STRETCH_LONG := 18
const HIT_OVERHEAD_NET_CLEAR := 3   ## px over the tape a smash keeps, if its flight allows

# --- Shots and intents (input.h) ---------------------------------------------
## The SNES repo's TUNING_VERSION (include/tuning.h) this sim matches,
## proven by the conformance traces (PORT-35; docs/TUNING.md there).
const TUNING_VERSION := 4

const SHOT_STANDARD := 0
const SHOT_DRIVE := 1
const SHOT_SOFT := 2
const SHOT_SLICE := 3      ## X: slow, never deep, steady off a stretch (SNES ADR-056)
const SHOT_OVERHEAD := 4   ## never asked for: a high contact makes it (ADR-053; the port's)
## SPECIAL with a full meter (SPECIALS, port ADR-080): PICKLE SMASH, a smash
## from any height. Without a full meter the press is a standard hit.
const SHOT_SPECIAL := 5
const HIT_PACE_SPECIAL_FP := 128         ## twice a drive's pace
const HIT_SPECIAL_MIN_FRAMES := 10
const HIT_SPECIAL_MAX_FRAMES := 20
## SPECIALS' meter, one a player: full at SPECIAL_METER_MAX. It fills by
## SPECIAL_FILL_HIT a shot you hit, SPECIAL_FILL_POINT a point your side
## wins, and one every SPECIAL_FILL_PERIOD frames of a live rally.
const SPECIAL_METER_MAX := 96
const SPECIAL_FILL_HIT := 4
const SPECIAL_FILL_POINT := 8
const SPECIAL_FILL_PERIOD := 40

const OWNER_NONE := 0
const OWNER_HUMAN := 1
const OWNER_CPU := 2

# --- Players (player.h) --------------------------------------------------------
const MAX_PLAYERS := 4
const STATE_IDLE := 0
const STATE_MOVE := 1
const STATE_WINDUP := 2
const STATE_ACTIVE := 3
const STATE_RECOVERY := 4

const POSE_NONE := 0
const POSE_TOSS := 1
const POSE_CHEER := 2

const PLAYER_WINDUP_FRAMES := 4
const PLAYER_ACTIVE_FRAMES := 3
const PLAYER_RECOVERY_FRAMES := 7
const PLAYER_ACCEL_FP := 4
const PLAYER_DIAGONAL_ACCEL_FP := 3
const PLAYER_MAX_SPEED_FP := 24
const PLAYER_FRICTION_FP := 6
# ICE (SNES ADR-053): half the acceleration and a sixth of the friction, so
# a run takes 12 frames to reach top speed and slides about 18 px.
const PLAYER_ICE_ACCEL_FP := 2
const PLAYER_ICE_DIAGONAL_ACCEL_FP := 2
const PLAYER_ICE_FRICTION_FP := 1
const PLAYER_SWING_MAX_SPEED_FP := 12
const PLAYER_CPU_MAX_SPEED_FP := 19
const PLAYER_SEPARATION_X := 16
const PLAYER_SEPARATION_Y := 12
const VARIANT_MALE := 0
const VARIANT_FEMALE := 1

## limit * 181 / 256 for limits 0..31 (player.c's table).
const DIAGONAL_LIMIT := [0, 0, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 9, 10,
	11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 19, 19, 20, 21, 21]

# --- Serve (serve.h) --------------------------------------------------------------
const SERVE_TOSS_FRAMES := 18
const SERVE_TOSS_POSE_FRAMES := 10
const SERVE_TOSS_VZ_FP := 32
const SERVE_HAND_OFFSET_X := 10
const SERVE_HAND_Z := 14
const SERVE_STANCE_OFFSET_Y := 22
const SERVE_BASELINE_GAP := PLAYER_RUNOFF_BACK
const SERVE_RECEIVER_GAP := 8
const SERVE_PARTNER_KITCHEN_GAP := 8
const SERVE_TARGET_LANE_SHIFT := 12
const SERVE_TARGET_SHORT_RIGHT := COURT_KITCHEN_RIGHT_X + 14
const SERVE_TARGET_NEUTRAL_RIGHT := COURT_KITCHEN_RIGHT_X + 36
const SERVE_TARGET_DEEP_RIGHT := COURT_BASELINE_RIGHT - 16
const SERVE_FLIGHT_FRAMES := 40
const SERVE_CHARGE_MAX := 30
const SERVE_CHARGE_DUD := 4
const SERVE_CHARGE_CLASSIC := SERVE_CHARGE_DUD
const SERVE_DUD_PAST_NET := 6
const SERVE_DUD_FRAMES := 30

# --- Game (game.h) -------------------------------------------------------------------
const PHASE_SERVE_SETUP := 0
const PHASE_SERVE_TOSS := 1
const PHASE_LIVE := 2
const PHASE_SERVE_FAULT := 3
const PHASE_POINT_RESULT := 4
const PHASE_MATCH_RESULT := 5

const FAULT_NONE := 0
const FAULT_NET := 1
const FAULT_KITCHEN := 2
const FAULT_WRONG_BOX := 3
const FAULT_OUT := 4
const FAULT_SECOND_BOUNCE := 5
const FAULT_EARLY_VOLLEY := 6
const FAULT_LAVA := 7
## The momentum rule (port ADR-064): a volley carried into your kitchen.
const FAULT_MOMENTUM := 8
const FAULT_DRIVE := 9          ## DINK OR DIE (port ADR-065)

const REQUIRED_BOUNCE_NONE := 0
const REQUIRED_BOUNCE_SERVE := 1
const REQUIRED_BOUNCE_RETURN := 2

const POINTS_TO_WIN := 5
const SERVE_READY_FRAMES := 20
const POINT_RESULT_MIN_FRAMES := 20
const POINT_RESULT_FRAMES := 90
const HIT_STOP_FRAMES := 2
const HIT_FLASH_FRAMES := 2
const NO_TEAM := 0xff
const ATTRACT_RESULT_FRAMES := 150
const ATTRACT_LATE_PERIOD := 5

# --- Events (events.h) ------------------------------------------------------------------
const EVENT_SERVE := 1
const EVENT_HIT := 2
const EVENT_BOUNCE := 3
const EVENT_FAULT := 4
const EVENT_POINT := 5
## audio_crowd (audio_events.h) as an event, so the sim stays silent:
## practice's every-fifth-return cheer (ADR-028/029); detail = level.
const EVENT_CROWD := 6

# --- Match (match.h) ----------------------------------------------------------------------
const MODE_SINGLES := 0
const MODE_DOUBLES := 1
const DIFFICULTY_KID := 0
const DIFFICULTY_EASY := 1
const DIFFICULTY_MEDIUM := 2
const DIFFICULTY_HARD := 3

# --- Modifiers (modifiers.h, ADR-033) --------------------------------------
const MOD_BIG_BALL := 1
const MOD_FAST_BALL := 2
const MOD_WIN_BY_2 := 4
const MOD_LAVA := 8
const MOD_GHOST_BALL := 16    ## SNES ADR-053: high in flight, the ball only blinks
const MOD_POPCORN := 32       ## every hit in a rally adds pace
const MOD_ICE := 64           ## players slide
const MOD_GLOW := 128         ## SNES ADR-054: lights out, neon outlines
## SNES ADR-054's INVERSE (its modifiers2 bit 0): the port's modifiers
## are wider than a byte. Display only, as GLOW is.
const MOD_INVERSE := 256
## The Pickleball '95 promises (PORT-40), remaster-only, so off in the
## ROM's conformance runs. SIDE-OUT (port ADR-063): traditional scoring,
## only the serving side scores; in doubles both partners serve before a
## side out (the first serve of a game is the second server's).
const MOD_SIDE_OUT := 512
## MOMENTUM (port ADR-064): after a volley, a step into your kitchen before
## the ball next bounces or is hit loses the point. MOMENTUM_GRACE px past
## the line are forgiven (players run fast in this game).
const MOD_MOMENTUM := 1024
const MOMENTUM_GRACE := 2
## The '95 modifiers (port ADR-065), remaster-only.
const MOD_MOON := 2048          ## low gravity: flights hang half as long again
const MOD_BOUNCY := 4096        ## the ball keeps more height on each bounce
const MOD_WIND := 8192          ## a crosswind, a new one each serve
const MOD_DINK_OR_DIE := 16384  ## a drive loses the point (DRIVE!)
const MOD_SUDDEN_DEATH := 32768 ## one point takes the match
## SPECIALS (port ADR-080), remaster-only: a meter that fills with play and
## a SPECIAL button that spends it on PICKLE SMASH.
const MOD_SPECIALS := 131072
const MOON_GRAVITY_FP := -2     ## a third less than BALL_GRAVITY_FP
const MOON_FLIGHT := [3, 2]     ## a shot's frames, times 3/2
const BALL_SPEED_MIN := 70       ## MODIFIERS > BALL SPEED, percent (port ADR-071)
const BALL_SPEED_MAX := 130
const BOUNCY_VERTICAL_256 := 175
const WIND_PERIOD := 8          ## the wind pushes vy by 1 (12.4) every 8 frames aloft
const WIND_DIRS := [1, -1, 0, -1, 1, 1, -1, 0]   ## a serve's wind, by frame
## MULTI BALL (port ADR-067): balls trickle in from the net, no serving.
const MOD_MULTI_BALL := 65536
const MULTI_MAX := 3            ## balls in play at most
const MULTI_EVERY := 240        ## frames between new balls (4 s)
const MULTI_BLINK := 60         ## a new ball blinks at the net this long
const MULTI_START_Z := 24       ## px: where it hangs, over the tape
const MULTI_FLIGHT := 32        ## frames from the net to its landing (a flat shot, not a lob)
const MULTI_DEPTH := 52         ## px past the net it lands (mid-court)
const MULTI_LANES := [0, 22, -22, 11, -11]   ## its landing's y off the centre line, in turn
const MOD_GHOST_Z := 8        ## GHOST: above this (px) the ball blinks
const MOD_GHOST_SHOWN := 2    ## ... shown this many frames in every 16
const MOD_POPCORN_STRIDE := 12   ## a level adds a step every 12 ticks (+8%)
const MOD_POPCORN_LEVELS := 6    ## up to +50%
const MOD_BIG_REACH := 4
const MOD_LAVA_MARGIN := 8

# --- AI (ai.h) ---------------------------------------------------------------------------------
const AI_PREDICT_MAX_STEPS := 60
const AI_RECOVER_Y := 130
const AI_RECOVER_Y_TOP := 110
const AI_RECOVER_Y_BOTTOM := 150
const AI_CONTACT_OFFSET_X := 10
const AI_DEAD_ZONE := 3
const AI_SERVE_DELAY_FRAMES := 50
const AI_ASSIST_SERVE_FRAMES := 90
const AI_AIM_PATTERN := 2
const AI_UP_DISTANCE := 64
const AI_PAIR_UP_DISTANCE := 80
const AI_SHIFT_MAX := 8
const AI_MIDDLE_BAND := 12
const AI_POACH_BAND := 20
const AI_MIDDLE_MARGIN := 10
const AI_OPEN_MARGIN := 12
const AI_SPLIT_DISTANCE := 32
const AI_PREDICT_BLOCK := 8
const AI_VOLLEY_MIN_Z := 4 << 4

const AIM_AWAY := 0
const AIM_BODY := 1
const AIM_MIX := 2
const DEPTH_ALTERNATE := 0
const DEPTH_DEEP := 1

static func fault_word(fault: int) -> String:
	match fault:
		FAULT_NET: return "NET!"
		FAULT_KITCHEN: return "KITCHEN!"
		FAULT_WRONG_BOX: return "FAULT!"
		FAULT_OUT: return "OUT!"
		FAULT_SECOND_BOUNCE: return "2 BOUNCES"
		FAULT_EARLY_VOLLEY: return "VOLLEY!"
		FAULT_LAVA: return "LAVA!"
		FAULT_MOMENTUM: return "MOMENTUM!"
		FAULT_DRIVE: return "DRIVE!"
	return "POINT!"
