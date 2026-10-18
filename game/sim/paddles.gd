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


## A row's [power, control, speed] (a plain paddle or a pairing).
static func stats(p: int) -> Array:
	return STATS[p] if p < COUNT else profiles()[p]

static func power_mul(p: int) -> int:
	return 64 + (int(stats(p)[0]) - 3) * STEP_64THS

static func control_mul(p: int) -> int:
	return 64 - (int(stats(p)[1]) - 3) * STEP_64THS

static func recovery(p: int) -> int:
	var k: int = 64 - (int(stats(p)[2]) - 3) * STEP_64THS
	return (K.PLAYER_RECOVERY_FRAMES * k + 32) >> 6

static func swing_limit(p: int) -> int:
	var k: int = 64 + (int(stats(p)[2]) - 3) * STEP_64THS
	return (K.PLAYER_SWING_MAX_SPEED_FP * k + 32) >> 6
