## A sim's whole state (port ADR-100): saved mid-match and loaded, into the
## same sim later (a rollback) or a new one (a rejoin), it steps on exactly
## as the sim that never stopped, in every mode and modifier.
extends TestSuite

const AT := [0, 1, 37, 400, 1500]    ## frames a state is saved at
const ON := 300                       ## frames compared after it


## A scripted human on slot 2: deterministic moves and swings.
static func _press(f: int) -> SimTypes.Intent:
	var it := SimTypes.Intent.new()
	var r := (f * 1103515245 + 12345) & 0x7fffffff
	it.move_x = ((r >> 8) % 3) - 1
	it.move_y = ((r >> 12) % 3) - 1
	it.aim_x = it.move_x
	it.aim_y = it.move_y
	it.hit_pressed = 1 if (r >> 16) % 9 == 0 else 0
	it.hit_held = 1 if (r >> 18) % 3 == 0 else it.hit_pressed
	it.shot = (r >> 20) % 3 if it.hit_pressed else 0
	it.short_held = 1 if (r >> 22) % 7 == 0 else 0
	return it


static func _human(f: int) -> Array:
	return [null, null, _press(f), null]


## The matches tried: name -> config. P1 is a bot; 2P ones script slot 2.
static func _configs() -> Dictionary:
	var out := {}
	out["singles"] = SimTypes.MatchConfig.singles()
	out["doubles"] = SimTypes.MatchConfig.doubles()
	var two := SimTypes.MatchConfig.singles()
	two.human = [1, 0, 1, 0]
	out["2p"] = two
	var kid := SimTypes.MatchConfig.doubles()
	kid.difficulty = K.DIFFICULTY_KID
	out["kid"] = kid
	var easy := SimTypes.MatchConfig.singles()
	easy.difficulty = K.DIFFICULTY_EASY
	out["easy (paced ball)"] = easy
	for mod in [K.MOD_BIG_BALL, K.MOD_FAST_BALL, K.MOD_WIN_BY_2, K.MOD_LAVA, K.MOD_GHOST_BALL,
			K.MOD_POPCORN, K.MOD_ICE, K.MOD_GLOW, K.MOD_INVERSE, K.MOD_SIDE_OUT, K.MOD_MOMENTUM,
			K.MOD_MOON, K.MOD_BOUNCY, K.MOD_WIND, K.MOD_DINK_OR_DIE, K.MOD_SUDDEN_DEATH,
			K.MOD_MULTI_BALL, K.MOD_SPECIALS]:
		var c := SimTypes.MatchConfig.doubles()
		c.modifiers = mod
		out["modifier %d" % mod] = c
	var all := SimTypes.MatchConfig.doubles()
	all.modifiers = K.MOD_POPCORN | K.MOD_WIND | K.MOD_SPECIALS | K.MOD_MOMENTUM | K.MOD_SIDE_OUT
	out["several modifiers"] = all
	var trip := SimTypes.MatchConfig.singles()
	trip.trip = 1
	trip.perks = K.PERK_HEAD_START | K.PERK_LONG_ARMS | K.PERK_SECOND_WIND | K.PERK_KITCHEN_PASS \
		| K.PERK_SECOND_SERVE | K.PERK_LUCKY_LINE | K.PERK_HOT_HAND
	trip.trip_stats = [[14, 12, 16, 15], [], [], []]
	trip.modifiers = K.MOD_SPECIALS
	out["road trip perks"] = trip
	var smart := SimTypes.MatchConfig.doubles()
	smart.smarts = [80, 60, 70, 80, 60, 70, 80, 60, 70, 80, 60, 70]
	out["smart play"] = smart
	out["practice"] = SimTypes.MatchConfig.practice_session(Practice.DEFAULTS.duplicate(), 3)
	return out


static func _sim(cfg: SimTypes.MatchConfig) -> Sim:
	var s := Sim.new(cfg)
	s.p1_bot = true
	return s


## Runs `s` from frame `from` for `n` frames: the traced state after each,
## and the whole state every 60th frame and the last (it takes longer).
static func _run(s: Sim, from: int, n: int) -> Array:
	var out := []
	for f in range(from, from + n):
		s.step(_human(f))
		s.drain_events()
		out.append(s.save_state() if (f - from) % 60 == 59 or f == from + n - 1 else s.snapshot())
	return out


func _first_difference(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())


func test_a_loaded_state_steps_on_as_the_sim_that_never_stopped() -> void:
	var cfgs := _configs()
	for name: String in cfgs:
		var s := _sim(cfgs[name])
		var f := 0
		for at: int in AT:
			_run(s, f, at - f)
			f = at
			var saved := s.save_state()
			var ahead := _run(s, f, ON)          # the sim that never stopped
			# a rollback: the same sim, ON frames later, back to the save
			eq(s.load_state(saved), true, "%s: load" % name)
			eq(s.save_state(), saved, "%s @%d: the state loaded is the state saved" % [name, at])
			var again := _run(s, f, ON)
			eq(_first_difference(again, ahead), -1, "%s @%d: rolled back, then the frame that differs" % [name, at])
			# a rejoin: a new sim of another match, sent the state as bytes
			var other := Sim.new(SimTypes.MatchConfig.singles())
			eq(other.load_state(bytes_to_var(var_to_bytes(saved))), true, "%s: load into a new sim" % name)
			var joined := _run(other, f, ON)
			eq(_first_difference(joined, ahead), -1, "%s @%d: a new sim, then the frame that differs" % [name, at])
			other.dispose()
			f += ON
		s.dispose()


## Loading keeps the sim's own objects (whatever holds them still does) and
## MULTI BALL's ball is still one of its entries' balls, not a copy.
func test_load_keeps_identity() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.modifiers = K.MOD_MULTI_BALL
	var s := _sim(cfg)
	var f := run_until(s, func(): return s.multi.size() > 1, 3000)
	check(f > 0, "MULTI BALL has balls in play")
	var saved := s.save_state()
	_run(s, f, 200)
	var ai := s.ai
	var p0: SimTypes.Player = s.players[0]
	s.load_state(saved)
	check(s.ai == ai and s.ai.sim == s and s.mb.sim == s and s.practice.sim == s, "the sim's parts stay its own")
	check(s.players[0] == p0, "a player is the same object")
	var shared := s.ball == s.mb.idle
	for m: MultiBallPlay.Entry in s.multi:
		shared = shared or m.ball == s.ball
	check(shared, "sim.ball is one of MULTI BALL's balls")
	s.dispose()


## The state is plain data (it goes over a line as bytes) and has every
## part of the sim, the untraced ones too.
func test_the_state_is_plain_data_and_whole() -> void:
	var s := _sim(SimTypes.MatchConfig.singles())
	_run(s, 0, 200)
	var saved := s.save_state()
	eq(bytes_to_var(var_to_bytes(saved)), saved, "through bytes and back")
	var before := s.state_hash()
	s.hot_streak += 1                         # not in snapshot()
	check(s.state_hash() != before, "an untraced field changes the hash")
	s.hot_streak -= 1
	eq(s.state_hash(), before, "and back")
	s.ai.last_think[1] += 1                   # deep in the AI
	check(s.state_hash() != before, "the AI's caches are in it")
	eq(s.load_state([0, {}]), false, "another format isn't loaded")
	s.dispose()
