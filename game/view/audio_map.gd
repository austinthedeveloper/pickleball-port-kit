## Sim events to sounds (ADR-029's audio_events.c, ADR-031's ambience):
## pure, so tests can check the mapping. Volumes are SNESMOD's 0..15;
## pitch is a playback scale (SNESMOD pitch 4 = 1.0); pan -1 left .. 1 right.
class_name AudioMap
extends RefCounted

const SOUND_ALL := 0
const SOUND_NO_CROWD := 1
const SOUND_OFF := 2
const SOUND_NAMES := ["ALL", "NO CROWD", "OFF"]

## The HD set (audio/hd-sfx) has its own sample for each shot, where the
## SNES pitched one sample (SNESMOD pitch 5 / 3 against 4).
const HIT_EFFECTS := {K.SHOT_STANDARD: "hit", K.SHOT_DRIVE: "hit_drive", K.SHOT_SOFT: "hit_soft",
	K.SHOT_SLICE: "hit_slice", K.SHOT_OVERHEAD: "hit_smash"}


static func pan_for_x(x: int) -> float:
	return clampf(float(x - K.COURT_NET_X) / float(K.COURT_BASELINE_RIGHT - K.COURT_NET_X), -1.0, 1.0)


## Applause volume: 6 to 13 by shots in the rally, 15 for the match winner.
static func applause_volume(rally: int, match_won: bool) -> int:
	if match_won:
		return 15
	return clampi(6 + rally / 2, 6, 13)


## The sounds for one event: [[effect, pitch, volume, pan], ...].
## `rally` is the shots in the rally so far; `match_won` that this point
## won the match.
static func for_event(e: Array, setting: int, rally: int, match_won: bool) -> Array:
	if setting == SOUND_OFF:
		return []
	var pan := pan_for_x(e[1])
	var out := []
	match e[0]:
		K.EVENT_SERVE:
			out.append(["hit", 1.0, 12, pan])
		K.EVENT_HIT:
			var shot: int = e[3] >> 4
			out.append([HIT_EFFECTS.get(shot, "hit"), 1.0, {K.SHOT_DRIVE: 13, K.SHOT_OVERHEAD: 14, K.SHOT_SLICE: 10}.get(shot, 12), pan])
		K.EVENT_BOUNCE:
			var n: int = e[3]
			out.append(["bounce", 1.0, maxi(4, 11 - (n - 1) * 3), pan])
		K.EVENT_FAULT:
			out.append(["net", 1.0, 12, pan] if e[3] == K.FAULT_NET else ["whistle", 1.0, 11, 0.0])
		K.EVENT_POINT:
			if setting != SOUND_NO_CROWD:
				out.append(["applause", 1.0, applause_volume(rally, match_won), 0.0])
		K.EVENT_CROWD:
			if setting != SOUND_NO_CROWD:
				out.append(["applause", 1.0, applause_volume(e[3], false), 0.0])
	return out


## The ambience's level (0..1 of its full volume): it swells with a long
## live rally and hushes on match point; NO CROWD and OFF silence it.
static func ambience_level(setting: int, live: bool, rally: int, match_point: bool) -> float:
	if setting != SOUND_ALL:
		return 0.0
	var level := 0.55
	if live:
		level += minf(0.45, rally * 0.04)
		if match_point:
			level *= 0.5
	return level
