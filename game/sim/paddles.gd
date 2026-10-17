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

static func power_mul(p: int) -> int:
	return 64 + (STATS[p][0] - 3) * STEP_64THS

static func control_mul(p: int) -> int:
	return 64 - (STATS[p][1] - 3) * STEP_64THS

static func recovery(p: int) -> int:
	var k: int = 64 - (STATS[p][2] - 3) * STEP_64THS
	return (K.PLAYER_RECOVERY_FRAMES * k + 32) >> 6

static func swing_limit(p: int) -> int:
	var k: int = 64 + (STATS[p][2] - 3) * STEP_64THS
	return (K.PLAYER_SWING_MAX_SPEED_FP * k + 32) >> 6
