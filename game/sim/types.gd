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
	## The match's ball physics (port ADR-065: MOON, BOUNCY, WIND), set
	## from the config; outside to_array (the traces' ball is unchanged).
	var gravity_fp := K.BALL_GRAVITY_FP
	var bounce_256 := K.BALL_BOUNCE_VERTICAL_256
	var flight := [1, 1]            ## a launch's frames, times flight[0] / flight[1]
	var wind := 0                   ## vy added every WIND_PERIOD frames aloft
	var wind_tick := 0

	## Another ball's physics (a probe flies as the match's ball does).
	func set_physics(o: Ball) -> void:
		gravity_fp = o.gravity_fp
		bounce_256 = o.bounce_256
		flight = o.flight
		wind = o.wind
		wind_tick = o.wind_tick

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
		b.set_physics(self)
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
	var slice := 0                   ## a slice every Nth rally shot, 0 never (SNES ADR-057)
	var serve_power := 4             ## the serve meter's level a CPU serves at (SNES ADR-058)
	var serve_dud := 0               ## about one serve in this many a dud, 0 never

	func copy() -> AiStyle:
		var s := AiStyle.new()
		for f in ["late_period", "reaction", "dink_period", "lob_distance",
				"putaway_z", "putaway_distance", "aim", "depth", "recover",
				"speed", "volley", "net", "team", "tactics", "footwork", "slice", "serve_power", "serve_dud"]:
			s.set(f, get(f))
		return s

	static func from_dict(d: Dictionary) -> AiStyle:
		var s := AiStyle.new()
		for f in ["late_period", "reaction", "dink_period", "lob_distance",
				"putaway_z", "putaway_distance", "recover", "speed",
				"volley", "net", "team", "tactics", "footwork", "slice", "serve_power", "serve_dud"]:
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
	var modifiers := 0                 # MOD_* bits (ADR-033)
	## The remaster's overhead smash (ADR-053; the ROM has none). Off, the
	## sim is the ROM's: the SNES conformance traces run with it off.
	var overhead := 1
	## Practice (ADR-028): the ball machine instead of an opponent, with the
	## saved settings (shot, target, rate, zone) and that zone's saved best.
	var practice := 0
	var practice_settings := [Practice.SHOT_MIX, Practice.TARGET_RANDOM,
		Practice.RATE_NORMAL, Practice.ZONE_ANY]
	var practice_best := 0
	## Open play (ADR-034): a game from the park's stack (no ladder change,
	## back to the park after), and `partner`, a ladder team whose captain
	## plays slot 1 (-1: the default CPU).
	var open_play := 0
	var partner := -1
	## ADR-047: slot 0 wears the active career player (their skin, hair, and
	## hat, and the hat's gear on their paddle). `career` is that player at
	## the match's start (a copy; the sim reads only its hat).
	var career_p1 := 0
	var career: Career.Player = null

	static func singles() -> MatchConfig:
		return MatchConfig.new()

	static func doubles() -> MatchConfig:
		var c := MatchConfig.new()
		c.mode = K.MODE_DOUBLES
		c.palette = [0, 3, 1, 2]       # blue + gold vs red + green (mock)
		return c

	## match_config_practice: singles with slot 2 inactive and no opponent.
	static func practice_session(settings: Array, best: int) -> MatchConfig:
		var c := MatchConfig.new()
		c.palette = [0, -1, -1, -1]
		c.practice = 1
		c.practice_settings = settings.duplicate()
		c.practice_best = best
		return c

	## match_config_partner: slot 1 is the team's captain (their body and
	## paddle; match_slot_style and the look follow `partner`). A human on
	## slot 1 keeps their own.
	func set_partner(team: int) -> void:
		partner = team if Opponents.exists(team) else -1   # a ladder captain, or PEPPER
		if partner < 0 or human[1]:
			return
		var m: Dictionary = Opponents.team(team)["players"][0]
		variant[1] = K.VARIANT_FEMALE if m.get("variant", "male") == "female" else K.VARIANT_MALE
		paddle[1] = maxi(0, Paddles.NAMES.find(m.get("paddle", "blue")))

	## match_config_career_p1: slot 0 in the career player's saved body,
	## shirt, and paddle (open play and the ball machine have no Player
	## Select); a slot that had that shirt colour takes slot 0's old one
	## (ADR-010). No player: nothing changes.
	func set_career_p1(player: Career.Player) -> void:
		if player == null:
			return
		var old: int = palette[0]
		career_p1 = 1
		career = player.copy()
		variant[0] = player.variant
		paddle[0] = player.paddle
		for slot in range(1, K.MAX_PLAYERS):
			if palette[slot] == player.shirt:
				palette[slot] = old
		palette[0] = player.shirt

	## select_apply's half (ADR-047): 1P plays as the career player (skin,
	## hair, hat) in this match's Player Select choice.
	func set_career(player: Career.Player) -> void:
		career_p1 = 1 if player != null else 0
		career = player.copy() if player != null else null

	func slot_active(slot: int) -> bool:
		return palette[slot] >= 0
