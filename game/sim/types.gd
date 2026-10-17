## Plain simulation records (the C structs). Every field is an int so the
## state is exactly reproducible; `copy()` gives value semantics where the
## C code copies a struct.
class_name SimTypes
extends RefCounted


class Ball:
	var active := 0
	var x_fp := 0
	var y_fp := 0
	var z_fp := 0
	var vx_fp := 0
	var vy_fp := 0
	var vz_fp := 0
	var last_hitter := K.BALL_NO_HITTER
	var bounce_count := 0
	var rally_state := K.BALL_RALLY_INACTIVE

	func copy() -> Ball:
		var b := Ball.new()
		b.active = active
		b.x_fp = x_fp
		b.y_fp = y_fp
		b.z_fp = z_fp
		b.vx_fp = vx_fp
		b.vy_fp = vy_fp
		b.vz_fp = vz_fp
		b.last_hitter = last_hitter
		b.bounce_count = bounce_count
		b.rally_state = rally_state
		return b

	func to_array() -> Array:
		return [active, x_fp, y_fp, z_fp, vx_fp, vy_fp, vz_fp, last_hitter,
			bounce_count, rally_state]


class Player:
	var active := 0
	var team := 0
	var logical_input_slot := 0
	var cpu_controlled := 0
	var x_fp := 0
	var y_fp := 0
	var vx_fp := 0
	var vy_fp := 0
	var max_speed_fp := K.PLAYER_MAX_SPEED_FP
	var facing_left := 0
	var animation_frame := 0
	var animation_timer := 0
	var state := K.STATE_IDLE
	var state_frames_remaining := 0
	var contact_consumed := 1
	var frozen := 0
	var pose := K.POSE_NONE
	var flash_timer := 0
	var shot_type := K.SHOT_STANDARD
	var variant := K.VARIANT_MALE
	var paddle := Paddles.STANDARD

	func to_array() -> Array:
		return [active, team, logical_input_slot, cpu_controlled, x_fp, y_fp,
			vx_fp, vy_fp, max_speed_fp, facing_left, animation_frame,
			animation_timer, state, state_frames_remaining, contact_consumed,
			frozen, pose, flash_timer, shot_type, variant, paddle]


class Intent:
	var move_x := 0
	var move_y := 0
	var aim_x := 0
	var aim_y := 0
	var hit_pressed := 0
	var shot := K.SHOT_STANDARD
	var pause_pressed := 0
	var hit_held := 0

	func clear() -> void:
		move_x = 0
		move_y = 0
		aim_x = 0
		aim_y = 0
		hit_pressed = 0
		shot = K.SHOT_STANDARD
		pause_pressed = 0
		hit_held = 0

	func copy_from(o: Intent) -> void:
		move_x = o.move_x
		move_y = o.move_y
		aim_x = o.aim_x
		aim_y = o.aim_y
		hit_pressed = o.hit_pressed
		shot = o.shot
		pause_pressed = o.pause_pressed
		hit_held = o.hit_held


## CPU play style (ADR-023); the defaults are data/opponents.json
## default_style, which equals the C constants.
class AiStyle:
	var late_period := 7
	var reaction := 0
	var dink_period := 4
	var lob_distance := 44
	var putaway_z := 14
	var putaway_distance := 48
	var aim := K.AIM_AWAY
	var depth := K.DEPTH_ALTERNATE
	var recover := 80
	var speed := 19
	var volley := 0
	var net := 0
	var team := 0
	var tactics := 0
	var footwork := 0

	func copy() -> AiStyle:
		var s := AiStyle.new()
		for f in ["late_period", "reaction", "dink_period", "lob_distance",
				"putaway_z", "putaway_distance", "aim", "depth", "recover",
				"speed", "volley", "net", "team", "tactics", "footwork"]:
			s.set(f, get(f))
		return s

	static func from_dict(d: Dictionary) -> AiStyle:
		var s := AiStyle.new()
		for f in ["late_period", "reaction", "dink_period", "lob_distance",
				"putaway_z", "putaway_distance", "recover", "speed",
				"volley", "net", "team", "tactics", "footwork"]:
			if d.has(f):
				s.set(f, int(d[f]))
		s.aim = {"away": K.AIM_AWAY, "body": K.AIM_BODY,
			"mix": K.AIM_MIX}.get(d.get("aim", "away"), K.AIM_AWAY)
		s.depth = K.DEPTH_DEEP if d.get("depth", "alternate") == "deep" \
			else K.DEPTH_ALTERNATE
		return s


class AiState:
	var has_target := 0
	var target_x := 0
	var target_y := 0
	var predicted_land_x := 0
	var predicted_land_y := 0
	var predicted_frames := 0
	var plan_age := 0
	var shot_counter := 0
	var plan_key := 0xff
	var reaction_frames := 0
	var incoming_frames := 0
	var late_period := 0
	var returns := 0
	var late_this_ball := 0
	var seen_shot := 0
	var planned_shot := K.SHOT_STANDARD
	var planned_depth := 0

	func to_array() -> Array:
		return [has_target, target_x, target_y, predicted_land_x,
			predicted_land_y, predicted_frames, plan_age, shot_counter,
			plan_key, reaction_frames, incoming_frames, late_period, returns,
			late_this_ball, seen_shot, planned_shot, planned_depth]


## Per-match choices (match.h MatchConfig). Colour/identity never follows
## the slot (ADR-010); a slot plays when it has a palette.
class MatchConfig:
	var mode := K.MODE_SINGLES
	var palette := [0, -1, 1, -1]      # team colour index per slot, -1 = off
	var paddle := [Paddles.STANDARD, Paddles.STANDARD, Paddles.STANDARD,
		Paddles.STANDARD]
	var variant := [K.VARIANT_MALE, K.VARIANT_FEMALE, K.VARIANT_MALE,
		K.VARIANT_FEMALE]
	var human := [1, 0, 0, 0]
	var opponent := -1                 # index into opponents.json, -1 = default CPU
	var points_to_win := K.POINTS_TO_WIN
	var difficulty := K.DIFFICULTY_MEDIUM
	var win_by_2 := 0

	static func singles() -> MatchConfig:
		return MatchConfig.new()

	static func doubles() -> MatchConfig:
		var c := MatchConfig.new()
		c.mode = K.MODE_DOUBLES
		c.palette = [0, 3, 1, 2]       # blue + gold vs red + green (mock)
		return c

	func slot_active(slot: int) -> bool:
		return palette[slot] >= 0
