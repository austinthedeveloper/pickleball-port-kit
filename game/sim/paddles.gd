## Paddle stats (ADR-020) from data/paddles.json: every point away from the
## baseline 3 moves a tunable by 3/64 of its standard value.
##
## The SNES generator (tools/assetgen, not in the kit) emitted these tables;
## this rebuilds them from the documented rule. POWER scales pace, CONTROL
## shrinks a stretched contact's spray, SPEED shortens recovery and raises
## the swing speed limit. The standard (blue) paddle gives exactly the C
## constants, so the default game and the golden trace don't depend on it.
class_name Paddles
extends RefCounted

const WOOD := 0
const BLUE := 1
const RED := 2
const GOLD := 3
const STANDARD := BLUE
const NAMES := ["wood", "blue", "red", "gold"]
const STATS := [   # power, control, speed
	[2, 5, 2],
	[3, 3, 3],
	[5, 2, 2],
	[2, 2, 5],
]
const STEP_64THS := 3
const STAT_MAX := 5
## Every paddle with every career hat (ADR-047 stage 4, paddle_stats.h):
## row hat x COUNT + paddle; rows 0-3 are the plain paddles. A hat moves
## one point between stats (career.json's gear); a stat can't pass
## STAT_MAX, so a hat whose raise has no room changes nothing.
const COUNT := 4
static var _profiles: Array = []


static func profile(paddle: int, hat: int) -> int:
	return hat * COUNT + paddle


static func profiles() -> Array:
	if _profiles.is_empty():
		for hat in Career.hats():
			var gear: Array = Career.hat_gear[hat]
			for paddle in COUNT:
				var row: Array = STATS[paddle].duplicate()
				var shifted: Array = []
				var room := true
				for i in 3:
					shifted.append(int(row[i]) + int(gear[i]))
					if shifted[i] > STAT_MAX:
						room = false
				_profiles.append(shifted if room else row)
	return _profiles


## ROAD TRIP (port ADR-087): a slot's own stats, 1 to 20, as a profile
## past every paddle's. The game's standard paddle (3/3/3) is about 8 on
## that scale; each point moves a tunable TRIP_STEP_64THS of its standard
## value, so 1 is about four fifths and 20 about one and a third.
const TRIP_BASE := 1 << 20
const TRIP_MID := 8
const TRIP_STEP_64THS := 2


static func trip_profile(power: int, control: int, speed: int) -> int:
	return TRIP_BASE | (clampi(power, 1, 20) << 10) | (clampi(control, 1, 20) << 5) | clampi(speed, 1, 20)


static func is_trip(p: int) -> bool:
	return p >= TRIP_BASE


## A trip profile's stat k (0 power, 1 control, 2 speed), 1 to 20.
static func trip_stat(p: int, k: int) -> int:
	return (p >> (10 - 5 * k)) & 31


## FEET, 1 to 20: the top running speed (12.4 px a frame), 24 the game's
## at 8, 20 at 1, 31 (the most the diagonal table holds) at 20.
static func trip_feet(feet: int) -> int:
	var f := clampi(feet, 1, 20)
	if f <= TRIP_MID:
		return K.PLAYER_MAX_SPEED_FP - ((TRIP_MID - f) * 4) / 7
	return mini(31, K.PLAYER_MAX_SPEED_FP + ((f - TRIP_MID) * 7) / 12)


static func _trip_mul(p: int, k: int, sign: int) -> int:
	return maxi(16, 64 + sign * (trip_stat(p, k) - TRIP_MID) * TRIP_STEP_64THS)


## A row's [power, control, speed] (a plain paddle or a pairing).
static func stats(p: int) -> Array:
	return STATS[p] if p < COUNT else profiles()[p]

static func power_mul(p: int) -> int:
	if is_trip(p):
		return _trip_mul(p, 0, 1)
	return 64 + (int(stats(p)[0]) - 3) * STEP_64THS

static func control_mul(p: int) -> int:
	if is_trip(p):
		return _trip_mul(p, 1, -1)
	return 64 - (int(stats(p)[1]) - 3) * STEP_64THS

static func recovery(p: int) -> int:
	if is_trip(p):
		return (K.PLAYER_RECOVERY_FRAMES * _trip_mul(p, 2, -1) + 32) >> 6
	var k: int = 64 - (int(stats(p)[2]) - 3) * STEP_64THS
	return (K.PLAYER_RECOVERY_FRAMES * k + 32) >> 6

static func swing_limit(p: int) -> int:
	if is_trip(p):
		return mini(31, (K.PLAYER_SWING_MAX_SPEED_FP * _trip_mul(p, 2, 1) + 32) >> 6)
	var k: int = 64 + (int(stats(p)[2]) - 3) * STEP_64THS
	return (K.PLAYER_SWING_MAX_SPEED_FP * k + 32) >> 6
