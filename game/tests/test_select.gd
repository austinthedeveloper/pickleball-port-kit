## PORT-04: Player Select (ADR-020). test_select.c ported, plus the config
## it builds (unique colours, CPU defaults, the paddle reaching the sim
## and changing play) and the look that shows the paddle.
extends TestSuite

const B := PlayerSelect.PAD_B
const Y := PlayerSelect.PAD_Y
const START := PlayerSelect.PAD_START
const UP := PlayerSelect.PAD_UP
const DOWN := PlayerSelect.PAD_DOWN
const LEFT := PlayerSelect.PAD_LEFT
const RIGHT := PlayerSelect.PAD_RIGHT


func test_select_c() -> void:
	var s := PlayerSelect.new()
	s.begin(K.MODE_SINGLES, 1)
	eq(s.row, PlayerSelect.ROW_VARIANT)
	eq(s.choice[0]["palette"], PlayerSelect.PAL_BLUE)
	# B steps down the rows; Y steps back up
	eq(s.input(B), PlayerSelect.STAY)
	eq(s.row, PlayerSelect.ROW_COLOUR)
	eq(s.input(B), PlayerSelect.STAY)
	eq(s.row, PlayerSelect.ROW_PADDLE)
	eq(s.input(Y), PlayerSelect.STAY)
	eq(s.row, PlayerSelect.ROW_COLOUR)
	eq(s.choice[0]["paddle"], Paddles.STANDARD)
	# colour wraps both ways
	s.input(LEFT)
	eq(s.choice[0]["palette"], PlayerSelect.PAL_GOLD)
	s.input(RIGHT)
	s.input(RIGHT)
	eq(s.choice[0]["palette"], PlayerSelect.PAL_RED)
	# rows clamp; the variant row toggles with Left/Right
	s.input(UP)
	s.input(UP)
	eq(s.row, PlayerSelect.ROW_VARIANT)
	s.input(RIGHT)
	eq(s.choice[0]["variant"], K.VARIANT_FEMALE)
	s.input(RIGHT)
	eq(s.choice[0]["variant"], K.VARIANT_FEMALE)
	s.input(LEFT)
	eq(s.choice[0]["variant"], K.VARIANT_MALE)
	s.input(RIGHT)
	# paddles wrap
	s.input(DOWN)
	s.input(DOWN)
	s.input(DOWN)
	eq(s.row, PlayerSelect.ROW_PADDLE)
	s.input(RIGHT)
	eq(s.choice[0]["paddle"], Paddles.RED)
	s.input(RIGHT)
	s.input(RIGHT)
	eq(s.choice[0]["paddle"], Paddles.WOOD)
	# no buttons: nothing changes
	s.changed = false
	check(s.input(0) == PlayerSelect.STAY and not s.changed, "no press, no change")
	# one human: B on the paddle row confirms; the config follows
	eq(s.input(B), PlayerSelect.DONE)
	var cfg := PlayerSelect.config_select(s.mode, s.choice[0])
	eq(cfg.palette[0], PlayerSelect.PAL_RED)
	eq(cfg.variant[0], K.VARIANT_FEMALE)
	eq(cfg.paddle[0], Paddles.WOOD)
	eq(cfg.palette[2], PlayerSelect.PAL_BLUE, "the CPU takes the first free colour")
	eq(cfg.human[2], 0)
	# Y on 1P's top row backs out; Start confirms anywhere
	s.begin(K.MODE_SINGLES, 1)
	eq(s.input(Y), PlayerSelect.BACK)
	s.begin(K.MODE_SINGLES, 1)
	eq(s.input(START), PlayerSelect.DONE)


func test_two_players_skip_taken_colours() -> void:
	var s := PlayerSelect.new()
	s.begin(K.MODE_DOUBLES, 2)
	s.input(DOWN)
	s.input(RIGHT)                       # 1P red
	eq(s.input(START), PlayerSelect.STAY)
	eq(s.current, 1)
	eq(s.row, PlayerSelect.ROW_VARIANT)
	s.input(DOWN)
	check(s.colour_taken(PlayerSelect.PAL_RED), "red is 1P's")
	eq(s.choice[1]["palette"], PlayerSelect.PAL_GREEN, "2P moved off 1P's colour")
	s.input(LEFT)
	eq(s.choice[1]["palette"], PlayerSelect.PAL_BLUE, "skips red")
	# Y climbs 2P's rows, then returns to 1P without leaving the screen
	check(s.input(Y) == PlayerSelect.STAY and s.current == 1, "2P's top row")
	check(s.input(Y) == PlayerSelect.STAY and s.current == 0, "back to 1P")
	eq(s.row, PlayerSelect.ROW_PADDLE)
	check(not s.colour_taken(PlayerSelect.PAL_RED), "nothing is taken for 1P")
	s.input(B)
	eq(s.current, 1, "1P done: 2P from the top")
	s.input(B)
	s.input(B)
	eq(s.input(B), PlayerSelect.DONE)
	var cfg := PlayerSelect.config_select(s.mode, s.choice[0], s.choice[1])
	eq(cfg.mode, K.MODE_DOUBLES)
	eq(cfg.palette, [PlayerSelect.PAL_RED, PlayerSelect.PAL_GREEN, PlayerSelect.PAL_BLUE,
		PlayerSelect.PAL_GOLD])
	eq(cfg.human, [1, 0, 1, 0])
	check(PlayerSelect.palettes_unique(cfg), "unique")


## ADR-010 over every choice: any 1P colour, any 2P colour 2P can pick,
## singles and doubles, CPUs on the standard paddle and fixed bodies.
func test_colours_unique_and_cpu_defaults() -> void:
	for mode in [K.MODE_SINGLES, K.MODE_DOUBLES]:
		for c1 in 4:
			var p1 := PlayerSelect.new_choice(c1, K.VARIANT_FEMALE, Paddles.GOLD)
			var cfg := PlayerSelect.config_select(mode, p1)
			check(PlayerSelect.palettes_unique(cfg), "1P %d unique" % c1)
			eq(cfg.palette[2] >= 0, true)
			eq(cfg.paddle[2], Paddles.STANDARD, "the CPU's paddle is standard")
			eq(cfg.variant[2], K.VARIANT_MALE)
			if mode == K.MODE_DOUBLES:
				eq(cfg.variant[1], K.VARIANT_FEMALE, "slot 1 female")
				eq(cfg.variant[3], K.VARIANT_FEMALE, "slot 3 female")
			else:
				eq([cfg.palette[1], cfg.palette[3]], [-1, -1], "singles: slots 1 and 3 off")
			for c2 in 4:
				if c2 == c1:
					continue
				var both := PlayerSelect.config_select(mode, p1,
					PlayerSelect.new_choice(c2, K.VARIANT_MALE, Paddles.RED))
				check(PlayerSelect.palettes_unique(both), "1P %d 2P %d unique" % [c1, c2])


func test_choice_reaches_the_sim_and_ladder() -> void:
	var p1 := PlayerSelect.new_choice(PlayerSelect.PAL_GOLD, K.VARIANT_FEMALE, Paddles.RED)
	var cfg := Settings.config_for(false, 0, K.DIFFICULTY_MEDIUM, 5, p1)
	var sim := Sim.new(cfg)
	eq(sim.players[0].paddle, Paddles.RED, "the paddle reaches the sim")
	eq(sim.players[0].variant, K.VARIANT_FEMALE)
	eq(cfg.opponent, 0, "still the ladder team")
	var members: Array = Opponents.team(0)["players"]
	eq(cfg.paddle[2], Paddles.NAMES.find(members[0]["paddle"]), "their captain's paddle")
	var pv := Settings.config_for(true, 3, K.DIFFICULTY_MEDIUM, 5, p1,
		PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, Paddles.WOOD))
	eq(pv.opponent, -1, "2P versus has no ladder team")
	eq(pv.human[2], 1)
	eq(pv.paddle[2], Paddles.WOOD)


## The stats harness check: in bot play, the red (power) paddle's rally
## shots fly sooner than the standard one's: frames from P1's hit to the
## next bounce, over the same 6,000 frames.
func test_red_paddle_flies_sooner_in_play() -> void:
	var std := _flight(Paddles.STANDARD)
	var red := _flight(Paddles.RED)
	check(std[1] > 20 and red[1] > 20, "enough P1 shots (%d, %d)" % [std[1], red[1]])
	check(red[0] < std[0], "red %.2f frames < standard %.2f" % [red[0], std[0]])


func _flight(paddle: int) -> Array:
	var cfg := Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 21,
		PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, paddle))
	var sim := Sim.new(cfg)
	sim.p1_bot = true
	var total := 0
	var shots := 0
	var since := -1
	for f in 6000:
		if sim.phase == K.PHASE_SERVE_SETUP and sim.server_index == 0:
			sim.serve_requested = 1
		sim.step()
		for e in sim.drain_events():
			if e[0] == K.EVENT_HIT:
				since = 0 if (e[3] & 15) == 0 else -1
			elif e[0] == K.EVENT_BOUNCE and since >= 0:
				total += since
				shots += 1
				since = -1
		if since >= 0:
			since += 1
	return [float(total) / maxi(shots, 1), shots]


## The role sheet in the team's palette with the team-coloured paddle is
## the team-colour sheet, so a chosen paddle changes only the paddle.
func test_team_look_matches_the_colour_sheet() -> void:
	var manifest: Dictionary = MatchView.levels_manifest()
	for pair in [[K.VARIANT_MALE, PlayerSelect.PAL_RED, Paddles.RED],
			[K.VARIANT_FEMALE, PlayerSelect.PAL_GOLD, Paddles.GOLD]]:
		var v: int = pair[0]
		var look := PlayerLook.for_team(pair[1], v, pair[2], manifest)
		var role := (load(MatchView.LEVELS + look.body_sheet(manifest)) as Texture2D).get_image()
		var name := "female" if v == K.VARIANT_FEMALE else "male"
		var sheet := (load(MatchView.LEVELS + "sprites/players/player_%s_%s.png" % [name,
			PlayerLook.TEAMS[pair[1]]]) as Texture2D).get_image()
		eq(role.get_size(), sheet.get_size(), "%s sizes" % name)
		var bad := 0
		for y in range(0, role.get_height(), 2):
			for x in range(0, role.get_width(), 2):
				var r := role.get_pixel(x, y)
				if r.a == 0.0:
					continue
				var want: Color = look.palette[clampi(roundi(r.r * 255.0 / 8.0), 0, 31)]
				var got := sheet.get_pixel(x, y)
				if absf(want.r - got.r) + absf(want.g - got.g) + absf(want.b - got.b) > 0.02:
					bad += 1
		eq(bad, 0, "%s: role sheet + palette == colour sheet" % name)
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES,
		PlayerSelect.new_choice(PlayerSelect.PAL_BLUE, K.VARIANT_MALE, Paddles.GOLD))
	check(PlayerLook.for_slot(cfg, 0, manifest) != null, "a non-standard paddle draws through a look")
	cfg.paddle[0] = Paddles.BLUE
	check(PlayerLook.for_slot(cfg, 0, manifest) == null, "blue on blue keeps the colour sheet")
	check(PlayerLook.for_slot(cfg, 2, manifest) == null, "CPUs keep the colour sheets")


func test_title_select_flow() -> void:
	var kept := [Settings.p1_choice.duplicate(), Settings.two_players, Settings.opponent_i]
	Settings.two_players = false
	Settings.opponent_i = -1
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	var started := []
	t.start_match.connect(func(cfg, _v, _l, _p, _n): started.append(cfg))
	Settings.quick_doubles = true
	t.reveal("start").press()
	eq(t.page, "select", "MATCH SETUP's START opens Player Select")
	eq(t.select.mode, K.MODE_DOUBLES, "for DOUBLES")
	Settings.quick_doubles = false
	check(t.select_screen.visible and not t._header[0].visible, "the select screen replaces the logo")
	t.select_input(Y)
	eq(t.page, "setup", "Y on the top row goes back to MATCH SETUP")
	t.open_select(true)
	t.select_input(DOWN)
	t.select_input(LEFT)                 # GOLD
	t.select_input(DOWN)
	t.select_input(RIGHT)                # RED paddle
	t.select_input(B)
	eq(started.size(), 1, "B on the paddle row starts")
	var cfg: SimTypes.MatchConfig = started[0]
	eq(cfg.mode, K.MODE_DOUBLES)
	eq([cfg.palette[0], cfg.paddle[0]], [PlayerSelect.PAL_GOLD, Paddles.RED])
	check(PlayerSelect.palettes_unique(cfg), "unique colours")
	eq(Settings.p1_choice["palette"], PlayerSelect.PAL_GOLD, "remembered for next time")
	t.open_select(false)
	eq(t.select.choice[0]["paddle"], Paddles.RED, "the screen opens on the last choice")
	var pc := t.practice_config()
	eq([pc.palette[0], pc.paddle[0], pc.practice], [PlayerSelect.PAL_GOLD, Paddles.RED, 1],
		"practice plays in the last choice")
	t.free()
	Settings.p1_choice = kept[0]
	Settings.two_players = kept[1]
	Settings.opponent_i = kept[2]
