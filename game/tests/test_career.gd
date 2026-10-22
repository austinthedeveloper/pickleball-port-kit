## ADR-047: career players, their stats, and unlocks (test_career.c), the
## CAREER page's input (test_career_page.c), the v4 -> v5 save, and the
## career player in matches.
extends TestSuite

const DIR := "user://test_career/"


func _fresh_save() -> SaveGame:
	var s := fresh_save(DIR)
	return s


func _unlock_bit(name: String) -> int:
	var i := Career.unlock_names.find(name)
	check(i >= 0, "an unlock named " + name)
	return i


func _team(name: String) -> int:
	for i in Opponents.count():
		if Opponents.team(i)["team"] == name:
			return i
	return -1


# --- test_career.c --------------------------------------------------------------

func test_data_matches_the_ladder() -> void:
	Career._load()
	check(Opponents.count() <= Career.TEAMS, "beaten[] holds one count per ladder team")
	check(Career.unlocks() <= 16, "the unlocked mask is a u16")
	eq(Career.skins(), 4, "opponents.json's four skins")
	eq(Career.hair_unlock[0], Career.FREE, "the first hair colour is free")
	eq(Career.hat_unlock[0], Career.FREE, "the cap is free")
	eq(Career.unlock_value[_unlock_bit("TRICORN")], _team("PIRATES"), "BEAT names a ladder team")
	eq(_team("PIRATES"), 3, "the C tests' team 3 is the PIRATES")


func test_slots() -> void:
	var s := _fresh_save()
	var c := s.career
	check(c.active == Career.NONE and c.active_player() == null, "nobody at first")
	check(c.create(1, "ACE"), "a new player")
	check(c.active == 1 and c.active_player() == c.players[1], "made active")
	eq(c.players[1].name, "ACE     ", "space-padded")
	check(not c.create(1, "BOB"), "taken")
	check(c.create(0, "BOBBYJOEX"), "a long name")
	eq(c.players[0].name, "BOBBYJOE", "cut to 8")
	c.select(2)                                  # empty
	check(c.active_player() == null, "an empty slot can't be active")
	c.select(1)
	c.delete(1)
	check(c.active_player() == null and c.players[1].used == 0, "deleted, nobody active")
	check(not c.create(3, "X"), "no slot 3")
	# Players survive a save round trip.
	c.select(0)
	s.save_game()
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	check(t.career.active_player() != null and t.career.active == 0, "the active player comes back")
	eq(t.career.players[0].name, "BOBBYJOE", "with their name")


func test_points_and_matches() -> void:
	var c := Career.new()
	# No player: nothing records.
	c.record_point(1, true, true)
	c.record_match(K.MODE_SINGLES, true, 0, 0, 0)
	eq(c.new_unlocks, 0, "no player, no unlocks")
	c.create(0, "ACE")
	var p := c.active_player()
	c.record_point(1, true, true)                # an ace
	c.record_point(1, true, false)               # their serve went out
	c.record_point(7, false, true)
	check(p.points_won == 2 and p.points_lost == 1, "points")
	check(p.aces == 1 and p.longest_rally == 7, "aces and the rally")
	c.record_match(K.MODE_DOUBLES, true, 0, 3, 0)        # PIRATES, 5-0
	check(p.wins[K.MODE_DOUBLES] == 1 and p.shutouts == 1, "a doubles shutout")
	check(p.streak == 1 and p.best_streak == 1 and p.beaten[3] == 1, "the streak and the team")
	c.record_match(K.MODE_SINGLES, false, 5, -1, 1)
	check(p.losses[K.MODE_SINGLES] == 1 and p.streak == 0, "a loss ends the streak")
	check(p.best_streak == 1 and p.open_play == 1, "the best stays; a park game counts")
	# Beating the last ladder team clears the ladder; at the park, not.
	c.record_match(K.MODE_SINGLES, true, 2, Opponents.count() - 1, 1)
	eq(p.ladder_clears, 0, "not at the park")
	c.record_match(K.MODE_SINGLES, true, 2, Opponents.count() - 1, 0)
	eq(p.ladder_clears, 1, "on the ladder")


func test_counters_saturate() -> void:
	var c := Career.new()
	c.create(0, "MAX")
	var p := c.active_player()
	p.points_won = Career.COUNTER_MAX
	p.beaten[0] = 255
	c.record_point(3, true, false)
	c.record_match(K.MODE_SINGLES, true, 3, 0, 0)
	eq(p.points_won, Career.COUNTER_MAX, "counters stop at 9999")
	eq(p.beaten[0], 255, "beaten[] stops at 255")


func test_unlocks() -> void:
	var c := Career.new()
	var visor := 1 << _unlock_bit("VISOR")
	var tricorn := 1 << _unlock_bit("TRICORN")
	var pink := 1 << _unlock_bit("PINK HAIR")
	var gold := 1 << _unlock_bit("GOLD HAIR")
	var beanie := 1 << _unlock_bit("BEANIE")
	c.create(2, "MAX")
	var p := c.active_player()
	# Free from the start: the cap, bare hair, the first hair colours.
	check(Career.hat_unlocked(p, 0) and Career.hat_unlocked(p, Career.hat_none()), "cap and NONE")
	check(Career.hair_unlocked(p, 0), "the first hair")
	for i in Career.hats():
		eq(Career.hat_unlocked(p, i), Career.hat_unlock[i] == Career.FREE, "hat %d" % i)
	# A first win (the default CPU, 5-3): the visor, nothing else.
	c.record_match(K.MODE_SINGLES, true, 3, -1, 0)
	check(c.new_unlocks == visor and (p.unlocked & visor) != 0, "the visor")
	check(Career.hat_unlocked(p, 1), "worn now")
	# Earned once: the next win earns nothing new.
	c.record_match(K.MODE_SINGLES, true, 3, -1, 0)
	eq(c.new_unlocks, 0, "earned once")
	# A shutout of the PIRATES, the third win: their hat, the pink hair,
	# and the beanie together (SNES ADR-060).
	c.record_match(K.MODE_SINGLES, true, 0, 3, 0)
	eq(c.new_unlocks, tricorn | pink | beanie, "three at once")
	# A ladder clear: the gold hair; a loss earns nothing.
	c.record_match(K.MODE_SINGLES, false, 5, 1, 0)
	eq(c.new_unlocks, 0, "a loss earns nothing")
	c.record_match(K.MODE_SINGLES, true, 4, Opponents.count() - 1, 0)
	check(c.new_unlocks & gold != 0, "a clear: gold hair")
	check(Career.hair_unlocked(p, Career.hairs() - 1), "GOLD")
	check(not Career.hair_unlocked(p, Career.hairs()), "past the end")
	eq(Career.unlock_text(tricorn | pink), "TRICORN, PINK HAIR", "the card's line")
	eq(Career.unlock_text(0x1ff), "VISOR, HEADBAND, BANDANA +6", "more than fits")


## A v0.5.0 save (layout v4) carries over with no career players (as the
## SNES's test_migrate_v11).
func test_migrate_v4() -> void:
	var s := _fresh_save()
	var old := SaveGame.defaults()
	old.erase("career")
	old["records"]["singles_wins"] = 17
	old["settings"]["time"] = 2
	old["settings"]["court"] = [1, 3, 0, 2]
	old["initials"]["best_streak"] = "JOE"
	var payload := JSON.stringify(old, "", true)
	var f := FileAccess.open(DIR + "save_a.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"magic": SaveGame.MAGIC, "version": 4, "seq": 2,
		"checksum": SaveGame.checksum(payload), "payload": payload}))
	f.close()
	s = SaveGame.new()
	s.dir = DIR
	s.load_game()
	eq(int(s.data["records"]["singles_wins"]), 17, "records kept")
	eq(int(s.data["settings"]["time"]), 2, "settings kept")
	eq(s.data["settings"]["court"], [1, 3, 0, 2], "court kept")
	eq(s.data["initials"]["best_streak"], "JOE", "initials kept")
	eq(s.career.active, Career.NONE, "nobody active")
	check(s.career.players[0].used == 0 and s.career.players[2].used == 0, "no players")
	# both copies are now v5
	var t := SaveGame.new()
	t.dir = DIR
	eq(int(t._read("save_a.json")["version"]), SaveGame.VERSION, "rewritten as v5")
	eq(int(t._read("save_b.json")["version"]), SaveGame.VERSION, "both copies")


func test_saved_player_is_made_valid() -> void:
	var c := Career.from_dict({"active": 7, "players": [{"used": 1, "name": "A", "hat": 99,
		"wins": [3, 99999], "skin": -2}]})
	eq(c.active, Career.NONE, "a bad slot: nobody")
	var p: Career.Player = c.players[0]
	eq(p.name, "A       ", "padded")
	eq(p.hat, Career.hats() - 1, "hat clamped")
	eq(p.wins, [3, Career.COUNTER_MAX], "counters clamped")
	eq(p.skin, 0, "skin clamped")


## Stage 4: hats shift paddle stats. Every pairing keeps the budget; a
## stat a paddle maxes leaves that hat with nothing to do on it; the
## career player's match uses the pairing, everyone else the paddle.
func test_gear() -> void:
	var rows := Paddles.profiles()
	eq(rows.size(), Career.hats() * Paddles.COUNT, "every paddle with every hat")
	for r in rows:
		eq(int(r[0]) + int(r[1]) + int(r[2]), 9, "on budget")
		check(int(r[0]) <= Paddles.STAT_MAX and int(r[1]) <= Paddles.STAT_MAX
			and int(r[2]) <= Paddles.STAT_MAX, "in range")
	# The cap and bare hair are the plain paddles.
	for paddle in Paddles.COUNT:
		eq(Paddles.stats(Paddles.profile(paddle, 0)), Paddles.STATS[paddle], "cap")
		eq(Paddles.stats(Paddles.profile(paddle, Career.hat_none())), Paddles.STATS[paddle], "none")
	# VISOR on BLUE: control up, power down; on WOOD (control 5): none.
	var hat := 1
	eq(Paddles.stats(Paddles.profile(Paddles.BLUE, hat)), [2, 4, 3], "visor on blue")
	eq(Paddles.stats(Paddles.profile(Paddles.WOOD, hat)), Paddles.STATS[Paddles.WOOD], "visor on wood")
	# In a match: the career player's pairing on slot 0 only.
	var c := Career.new()
	c.create(0, "ACE")
	c.active_player().hat = hat
	var cfg := SimTypes.MatchConfig.singles()
	cfg.set_career(c.active_player())
	cfg.paddle[0] = Paddles.BLUE
	var sim := Sim.new(cfg)
	eq(sim.players[0].paddle, Paddles.profile(Paddles.BLUE, hat), "slot 0's pairing")
	eq(sim.players[2].paddle, Paddles.STANDARD, "the CPU's plain paddle")
	# Without a career player: the plain paddle.
	cfg.set_career(null)
	sim = Sim.new(cfg)
	eq(sim.players[0].paddle, Paddles.BLUE, "plain without a player")


func test_open_play_wears_the_saved_look() -> void:
	var c := Career.new()
	c.create(0, "ACE")
	var p := c.active_player()
	p.shirt = PlayerSelect.PAL_RED
	p.variant = K.VARIANT_FEMALE
	p.paddle = Paddles.GOLD
	var cfg := SimTypes.MatchConfig.doubles()       # blue, gold, red, green
	cfg.set_career_p1(p)
	eq(cfg.palette, [1, 3, 0, 2], "1P in red; red's slot takes blue (ADR-010)")
	check(PlayerSelect.palettes_unique(cfg), "colours unique")
	check(cfg.career_p1 == 1 and cfg.variant[0] == K.VARIANT_FEMALE and cfg.paddle[0] == Paddles.GOLD,
		"body and paddle")
	var none := SimTypes.MatchConfig.doubles()
	none.set_career_p1(null)
	eq(none.career_p1, 0, "no player: as before")


# --- test_career_page.c ---------------------------------------------------------------

var page: CareerPage


func _press(bits: int) -> int:
	return page.input(bits)


## A blank career, the page open; nobody is active, so it opens on NO
## PLAYER: the tests start from slot 1 (row 0).
func _fresh_page() -> Career:
	var c := Career.new()
	page = CareerPage.new()
	page.begin(c)
	eq(page.row, CareerPage.ROW_NOBODY, "opens on NO PLAYER")
	page.row = 0
	return c


## Types a letter on the keyboard: the D-pad to its key, then B.
func _type_key(k: int) -> void:
	for guard in 40:
		if page.key() == k:
			break
		if k >= CareerPage.KEY_DEL:
			if page.key_row != CareerPage.KEY_ROWS - 1:
				_press(CareerPage.PAD_UP)          # wraps to DEL/END
			else:
				_press(CareerPage.PAD_RIGHT)
		elif page.key_row != k / CareerPage.KEY_COLS:
			_press(CareerPage.PAD_DOWN)
		else:
			_press(CareerPage.PAD_RIGHT)
	_press(CareerPage.PAD_B)


func test_page_create_and_name() -> void:
	var c := _fresh_page()
	# Slot 2: a new player, on the keyboard at once, the name blank.
	_press(CareerPage.PAD_DOWN)
	_press(CareerPage.PAD_DOWN)
	eq(_press(CareerPage.PAD_B), CareerPage.STAY, "creating doesn't save yet")
	check(page.view == CareerPage.VIEW_EDIT and page.naming, "typing at once")
	check(page.creating and c.active == 2, "slot 2, active")
	var p: Career.Player = c.players[2]
	eq(p.name, "        ", "blank")
	check(page.key() == 0 and page.cursor == 0, "on A")
	# END with no letters: still typing.
	_press(CareerPage.PAD_START)
	check(page.naming, "a name needs a letter")
	# "ACE": A is picked (B), then C, E.
	_press(CareerPage.PAD_B)
	_type_key(2)
	_type_key(4)
	eq(p.name, "ACE     ", "typed")
	# Y (or DEL) erases the last letter.
	_press(CareerPage.PAD_Y)
	eq(p.name, "AC      ", "Y erases")
	_type_key(CareerPage.KEY_DEL)
	_type_key(4)
	eq(p.name, "AE      ", "DEL erases")
	# Space and dash.
	_type_key(26)
	_type_key(27)
	eq(p.name, "AE -    ", "space and dash")
	# END: done typing, and a new player goes on to their look.
	_type_key(CareerPage.KEY_END)
	check(not page.naming and page.row == CareerPage.EDIT_BODY, "on to BODY")
	# B keeps: the card, and a save.
	eq(_press(CareerPage.PAD_B), CareerPage.SAVE, "kept")
	check(page.view == CareerPage.VIEW_CARD and not page.creating, "the card")


func test_page_name_full_and_edit() -> void:
	var c := _fresh_page()
	_press(CareerPage.PAD_B)                     # slot 0: new
	var p: Career.Player = c.players[0]
	for i in Career.NAME:
		_press(CareerPage.PAD_B)                 # AAAAAAAA
	eq(p.name, "AAAAAAAA", "full")
	eq(page.key(), CareerPage.KEY_END, "full: on END")
	_press(CareerPage.PAD_B)                     # an extra B: END
	check(not page.naming, "done")
	# Editing the name again picks up after the last letter.
	_press(CareerPage.PAD_UP)                    # NAME
	_press(CareerPage.PAD_B)
	check(page.naming and page.cursor == Career.NAME, "after the last letter")
	_press(CareerPage.PAD_Y)
	_press(CareerPage.PAD_Y)
	eq(p.name, "AAAAAA  ", "two erased")
	_press(CareerPage.PAD_START)
	check(not page.naming, "Start finishes")


func test_page_cancel_new_player() -> void:
	var c := _fresh_page()
	_press(CareerPage.PAD_B)                     # slot 0: new
	_press(CareerPage.PAD_B)                     # A
	_press(CareerPage.PAD_START)                 # done typing
	_press(CareerPage.PAD_Y)                     # never mind
	eq(page.view, CareerPage.VIEW_SLOTS, "back to the slots")
	check(c.players[0].used == 0 and c.active_player() == null, "dropped")
	# Keeping a nameless player isn't possible: B goes back to typing.
	_press(CareerPage.PAD_B)
	page.naming = false                          # (as if left without END)
	page.row = CareerPage.EDIT_BODY
	eq(_press(CareerPage.PAD_B), CareerPage.STAY, "not kept")
	check(page.naming and page.row == CareerPage.EDIT_NAME, "typing again")


func test_page_edit_look() -> void:
	var c := _fresh_page()
	c.create(1, "MAX")
	page.begin(c)
	eq(page.row, 1, "on the active player")
	eq(_press(CareerPage.PAD_B), CareerPage.SAVE, "the card")
	_press(CareerPage.PAD_B)                     # edit
	check(page.view == CareerPage.VIEW_EDIT and not page.naming, "editing")
	var p: Career.Player = c.players[1]
	page.look_changed = false
	_press(CareerPage.PAD_DOWN)                  # BODY
	_press(CareerPage.PAD_RIGHT)
	check(p.variant == K.VARIANT_FEMALE and page.look_changed, "body")
	_press(CareerPage.PAD_DOWN)                  # SKIN
	_press(CareerPage.PAD_LEFT)
	eq(p.skin, Career.skins() - 1, "skin wraps")
	_press(CareerPage.PAD_DOWN)                  # HAIR: the locked skipped
	_press(CareerPage.PAD_LEFT)
	check(Career.hair_unlocked(p, p.hair) and p.hair != 0, "a free hair")
	_press(CareerPage.PAD_DOWN)                  # SHIRT
	_press(CareerPage.PAD_RIGHT)
	eq(p.shirt, PlayerSelect.PAL_RED, "shirt")
	_press(CareerPage.PAD_DOWN)                  # HAT: nothing won yet
	_press(CareerPage.PAD_RIGHT)
	eq(p.hat, Career.hat_none(), "past the locked: NONE")
	_press(CareerPage.PAD_RIGHT)
	eq(p.hat, 0, "and round to the cap")
	# Y puts it all back.
	_press(CareerPage.PAD_Y)
	eq(page.view, CareerPage.VIEW_CARD, "the card")
	check(p.variant == K.VARIANT_MALE and p.skin == 0 and p.hair == 0, "the look back")
	eq(p.shirt, PlayerSelect.PAL_BLUE, "the shirt back")
	# An unlocked hat can be worn.
	p.unlocked = 1                               # VISOR
	_press(CareerPage.PAD_B)
	while page.row != CareerPage.EDIT_HAT:
		_press(CareerPage.PAD_DOWN)
	_press(CareerPage.PAD_RIGHT)
	eq(p.hat, 1, "the visor")
	check(_press(CareerPage.PAD_B) == CareerPage.SAVE and p.hat == 1, "kept")


func test_page_delete_and_records() -> void:
	var c := _fresh_page()
	c.create(0, "ACE")
	page.begin(c)
	_press(CareerPage.PAD_B)                     # the card
	eq(page.delete_player(), CareerPage.SAVE, "deleted")
	check(c.players[0].used == 0 and c.active_player() == null, "gone")
	eq(page.view, CareerPage.VIEW_SLOTS, "back to the slots")
	# RECORDS and back.
	_press(CareerPage.PAD_UP)                    # wraps to RECORDS
	eq(page.row, CareerPage.ROW_RECORDS, "RECORDS")
	_press(CareerPage.PAD_B)
	eq(page.view, CareerPage.VIEW_RECORDS, "the records")
	_press(CareerPage.PAD_Y)
	eq(page.view, CareerPage.VIEW_SLOTS, "back")
	eq(_press(CareerPage.PAD_Y), CareerPage.CLOSE, "Y leaves")


## Y with nothing left to erase backs out of typing.
func test_page_back_out_of_name() -> void:
	# A new player: dropped, back to the slots.
	var c := _fresh_page()
	_press(CareerPage.PAD_B)
	check(page.naming and page.cursor == 0, "typing")
	_press(CareerPage.PAD_Y)
	check(not page.naming and page.view == CareerPage.VIEW_SLOTS, "backed out")
	eq(c.players[0].used, 0, "dropped")
	# Typed, erased, then back out: still dropped.
	_press(CareerPage.PAD_B)
	_press(CareerPage.PAD_B)                     # A
	_press(CareerPage.PAD_Y)                     # erased
	check(page.naming, "still typing")
	_press(CareerPage.PAD_Y)
	eq(c.players[0].used, 0, "dropped")
	# An old player: erasing then backing out keeps the old name.
	c = _fresh_page()
	c.create(0, "MAX")
	page.begin(c)
	_press(CareerPage.PAD_B)                     # card
	_press(CareerPage.PAD_B)                     # edit, on NAME
	_press(CareerPage.PAD_B)                     # typing, after "MAX"
	var p: Career.Player = c.players[0]
	check(page.naming and page.cursor == 3, "after MAX")
	for i in 3:
		_press(CareerPage.PAD_Y)
	eq(p.name, "        ", "erased")
	_press(CareerPage.PAD_Y)                     # back out
	check(not page.naming and page.view == CareerPage.VIEW_EDIT, "still editing")
	check(p.name == "MAX     " and p.used == 1, "the old name")


## NO PLAYER: nobody active; the page opens there.
func test_page_no_player() -> void:
	var c := _fresh_page()
	c.create(1, "MAX")
	page.begin(c)
	check(page.row == 1 and c.active_player() != null, "on MAX")
	_press(CareerPage.PAD_DOWN)
	_press(CareerPage.PAD_DOWN)
	eq(page.row, CareerPage.ROW_NOBODY, "NO PLAYER")
	eq(_press(CareerPage.PAD_B), CareerPage.SAVE, "saved")
	check(c.active_player() == null and page.view == CareerPage.VIEW_SLOTS, "nobody")
	eq(c.players[1].used, 1, "still there")


func test_page_card_helpers() -> void:
	var p := Career.Player.new()
	check(Career.next_unlock(p) == 0 and Career.unlock_count(p) == 0, "none")
	p.unlocked = 0x0b                            # 0, 1, 3
	check(Career.next_unlock(p) == 2 and Career.unlock_count(p) == 3, "some")
	p.unlocked = (1 << Career.unlocks()) - 1
	eq(Career.next_unlock(p), Career.unlocks(), "all")
	eq(Career.paddle_name(0), "WOOD", "paddle name")
	eq(Career.body_name(1), "FEMALE", "body name")


# --- In the game (stage 3) -------------------------------------------------------------

func _finish(view: MatchView, winner: int) -> void:
	var sim := view.sim
	sim.team_score[winner] = sim.config.points_to_win - 1
	sim.phase = K.PHASE_LIVE
	sim.ball.rally_state = K.BALL_RALLY_LIVE
	sim.resolve_point(1 - winner, K.FAULT_OUT)     # the faulting team
	for f in K.POINT_RESULT_FRAMES + 5:
		view._physics_process(1.0 / 60.0)


func _career_view(s: SaveGame, cfg: SimTypes.MatchConfig, demo := false) -> MatchView:
	var v := MatchView.new()
	v.save = s
	runner.root.add_child(v)
	v.setup(cfg, "park", demo)
	return v


## A shutout of the PIRATES as a career player: the stats, the unlocks,
## the name on the HUD, and the UNLOCKED! card after the initials card.
func test_match_records_and_unlock_card() -> void:
	var s := _fresh_save()
	s.career.create(0, "ACE")
	var cfg := Settings.config_for(false, _team("PIRATES"), K.DIFFICULTY_MEDIUM, 5)
	cfg.set_career(s.career.active_player())
	var v := _career_view(s, cfg)
	eq(v._hud._left_label.text, "ACE", "the name on 1P's panel")
	check(v._players[0]["look"] != null and v._players[0]["look"].hat == "cap", "slot 0 in the career look")
	_finish(v, 0)
	var p := s.career.active_player()
	eq(p.wins[K.MODE_SINGLES], 1, "a career win")
	check(p.shutouts == 1 and p.beaten[_team("PIRATES")] == 1, "a shutout of the PIRATES")
	eq(p.points_won, 1, "the last point counted")
	var earned := (1 << _unlock_bit("VISOR")) | (1 << _unlock_bit("TRICORN")) | (1 << _unlock_bit("PINK HAIR"))
	eq(s.career.new_unlocks, earned, "three unlocks")
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	eq(t.career.active_player().wins[K.MODE_SINGLES], 1, "written with the match")
	# the initials card first (a first best streak), then the unlocks
	check(v.initials.open and not v.unlock_open(), "initials first")
	v.initials._save()
	v._physics_process(1.0 / 60.0)
	check(v.unlock_open(), "then UNLOCKED!")
	v._hud.refresh()
	check(v._hud.cards.unlock.visible and v._hud._banner.text == "", "the card, not the result")
	eq(v._hud.cards.unlock_line.text, "VISOR, TRICORN, PINK HAIR", "what was earned")
	var frame := v.sim.frame_count
	for f in MatchEnd.UNLOCK_FRAMES - 2:
		v._physics_process(1.0 / 60.0)
	eq(v.sim.frame_count, frame, "the match waits under it")
	check(v.unlock_open(), "for five seconds")
	v._physics_process(1.0 / 60.0)
	check(not v.unlock_open() and s.career.new_unlocks == 0, "then it goes by itself")
	v.free()


## Nothing counts with nobody active, in a 2P match, or in the demo.
func test_only_career_matches_count() -> void:
	var s := _fresh_save()
	s.career.create(0, "ACE")
	s.career.select(Career.NONE)
	var v := _career_view(s, Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5))
	_finish(v, 0)
	eq(s.career.players[0].wins, [0, 0], "nobody active")
	v.free()
	s.career.select(0)
	var versus := Settings.config_for(false, -1, K.DIFFICULTY_MEDIUM, 5, Settings.p1_choice,
		PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD))
	versus.set_career(s.career.active_player())
	v = _career_view(s, versus)
	_finish(v, 0)
	eq(s.career.players[0].wins, [0, 0], "2P on the other team")
	v.free()
	v = _career_view(s, SimTypes.MatchConfig.singles(), true)
	for f in 3000:
		v._physics_process(1.0 / 60.0)
	eq(s.career.players[0].points_won + s.career.players[0].points_lost, 0, "not the demo")
	v.free()


## Display only (CLAUDE.md): a career match in the view runs exactly like a
## bare sim with the same config (the hat's gear is in both).
func test_display_only() -> void:
	var c := Career.new()
	c.create(0, "ACE")
	c.active_player().hat = 1
	c.active_player().hair = 3
	var cfg := Settings.config_for(false, 1, K.DIFFICULTY_MEDIUM, 5)
	cfg.set_career(c.active_player())
	var v := _career_view(null, cfg)
	v.sim.p1_bot = true
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	for f in 1500:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % f)
			break
	eq(v.sim.snapshot(), bare.snapshot(), "1500 frames match a bare sim")
	v.free()


func _title(s: SaveGame) -> TitleScreen:
	var t := TitleScreen.new()
	t.save = s
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	return t


## The title's CAREER entry by row ids: a new player named on the keyboard,
## dressed, kept (a save), then Player Select and the match as them.
func test_title_career_flow() -> void:
	var kept: Dictionary = Settings.p1_choice.duplicate()
	var s := _fresh_save()
	var t := _title(s)
	eq(t.pages["main"].value_of("player"), "NO PLAYER", "nobody yet")
	t.reveal("career").press()
	eq(t.page, "career", "the slots")
	eq(t.pages["career"].current_id(), "nobody", "opens on NO PLAYER")
	t.pages["career"].select("slot1")
	t.pages["career"].press()
	eq(t.page, "career_name", "a new player types a name first")
	check(t.career_keyboard.visible and t.career_preview.visible, "the keyboard and the portrait")
	for k in [CareerPage.PAD_B, CareerPage.PAD_RIGHT, CareerPage.PAD_RIGHT, CareerPage.PAD_B]:
		t._career_input(k)                      # A, then C
	t._career_input(CareerPage.PAD_START)
	eq(t.page, "career_edit", "on to the look")
	eq(t.pages["career_edit"].current_id(), "body", "on BODY")
	t.pages["career_edit"].select("shirt")
	t.pages["career_edit"].change(1)
	eq(t.pages["career_edit"].value_of("shirt"), "RED", "the shirt")
	eq(t.pages["career_edit"].value_of("gear"), "PWR 3  CTL 3  SPD 3", "the plain paddle")
	t.pages["career_edit"].select("hat")
	t.pages["career_edit"].change(1)
	eq(t.pages["career_edit"].value_of("hat"), "NONE", "the locked hats skipped")
	t.pages["career_edit"].select("keep")
	t.pages["career_edit"].press()
	eq(t.page, "career_card", "kept: the card")
	eq(t.pages["career_card"].value_of("next"), "VISOR", "the next unlock")
	var disk := SaveGame.new()
	disk.dir = DIR
	disk.load_game()
	eq(disk.career.players[1].name, "AC      ", "saved")
	eq(disk.career.players[1].shirt, PlayerSelect.PAL_RED, "with the look")
	eq(disk.career.active, 1, "and active")
	t.back()
	eq(t.page, "career", "Y: the slots")
	eq(t.pages["career"].current_id(), "slot1", "on the player")
	t.back()
	eq(t.page, "player", "Y again: PLAYER")
	eq(t.pages["main"].value_of("player"), "AC", "MAIN shows the player")
	t.open_select(false)
	eq(t.select.choice[0]["palette"], PlayerSelect.PAL_RED, "Player Select starts on them")
	check(t.select_screen.career != null, "in their look")
	var cfg := t.config(false)
	check(cfg.career_p1 == 1 and cfg.career.name == "AC      ", "the match is theirs")
	eq(Settings.p1_choice, kept, "the saved choice is left alone")
	t.free()


## Deleting from the card takes two presses, and an edit cancelled with Y
## puts the look back.
func test_title_delete_and_cancel() -> void:
	var s := _fresh_save()
	s.career.create(0, "MAX")
	var t := _title(s)
	t.open_career()
	t.pages["career"].press()                    # on MAX: the card
	eq(t.page, "career_card")
	t.pages["career_card"].select("edit")
	t.pages["career_card"].press()
	eq(t.page, "career_edit", "editing")
	t.pages["career_edit"].select("skin")
	t.pages["career_edit"].change(1)
	eq(s.career.players[0].skin, 1, "changed")
	t.back()
	eq(t.page, "career_card", "Y: back to the card")
	eq(s.career.players[0].skin, 0, "the look put back")
	t.pages["career_card"].select("delete")
	t.pages["career_card"].press()
	eq(s.career.players[0].used, 1, "one press only arms")
	eq(t.pages["career_card"].value_of("delete"), "B AGAIN")
	t.pages["career_card"].press()
	eq(s.career.players[0].used, 0, "the second deletes")
	eq(t.page, "career", "back to the slots")
	t.free()


func test_park_and_practice_wear_the_player() -> void:
	var s := _fresh_save()
	s.career.create(0, "ACE")
	s.career.active_player().shirt = PlayerSelect.PAL_GOLD
	var op := OpenPlay.new()
	op.begin(1234, false)
	var cfg := Settings.open_play_config(op, s.career.active_player())
	check(cfg.career_p1 == 1 and cfg.palette[0] == PlayerSelect.PAL_GOLD, "open play as the player")
	check(PlayerSelect.palettes_unique(cfg), "colours unique")
	var view := ParkView.new()
	runner.root.add_child(view)
	view.setup(op, s, false)
	check(view._you["body"].material != null, "the park sprite wears the player's palette")
	view.free()
	var page := PracticePage.new()
	page.save = s
	var pc := page.config()
	check(pc.career_p1 == 1 and pc.palette[0] == PlayerSelect.PAL_GOLD, "practice as the player")
	page.free()


## SNES ADR-070: the park rating, packed in Player.park (test_career.c's
## test_park_rating).
func test_park_rating() -> void:
	var c := Career.new()
	c.create(0, "ACE")
	var p := c.active_player()
	eq(p.park, 0)
	check(Career.park_rating(p) == 30 and Career.park_court(p) == 0, "a new player: 3.0, the first court")
	# Wins at the first court: 3.0, 3.2, 3.4, then 3.6 opens the next.
	c.rate_park(p, 0, true)
	c.rate_park(p, 0, true)
	check(Career.park_rating(p) == 34 and c.park_opened == OpenPlay.NONE)
	c.rate_park(p, 0, true)
	check(c.park_before == 34 and c.park_after == 36)
	check(c.park_opened == 1 and Career.park_court(p) == 1, "CLUB opens")
	# A loss drops the rating below the CLUB court's; it stays open.
	c.rate_park(p, 1, false)
	c.rate_park(p, 1, false)
	check(Career.park_rating(p) == 34 and Career.park_court(p) == 1)
	eq(c.park_opened, OpenPlay.NONE)
	# The floor holds in the byte...
	p.park = (1 << Career.PARK_COURT_SHIFT) | (OpenPlay.RATING_MIN - Career.PARK_BASE)
	c.rate_park(p, 0, false)
	eq(Career.park_rating(p), OpenPlay.RATING_MIN)
	eq(Career.park_court(p), 1)
	# ...and the cap, with the top court.
	p.park = OpenPlay.RATING_MAX - Career.PARK_BASE
	c.rate_park(p, 2, true)
	eq(Career.park_rating(p), OpenPlay.RATING_MAX)
	check(Career.park_court(p) == 2 and c.park_opened == 2)
	# Through a match: open_play is the court + 1; KID is not rated.
	p.park = 0
	c.record_match(K.MODE_DOUBLES, true, 4, 3, 2)
	check(Career.park_rating(p) == 33 and c.park_before == 30, "a CLUB win from 3.0")
	c.record_match(K.MODE_DOUBLES, true, 4, 3, 0)
	check(Career.park_rating(p) == 33 and c.park_before == OpenPlay.RATING_NONE, "the ladder isn't rated")
	c.record_match(K.MODE_DOUBLES, false, 4, 3, 1, true)
	check(Career.park_rating(p) == 33 and c.park_before == OpenPlay.RATING_NONE, "KID isn't")
	# It survives a save round trip.
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	eq(Career.park_rating(back.active_player()), 33)
