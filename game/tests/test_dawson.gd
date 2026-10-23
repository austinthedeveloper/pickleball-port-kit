## Dale "Dink" Dawson (port ADR-066), the cover athlete the ROM never had:
## a bonus opponent after the ladder, unlocked by a ladder clear, who plays
## doubles alone, fast enough to cover the court.
extends TestSuite


func test_after_the_ladder() -> void:
	eq(Opponents.count(), 8, "the ladder is still eight")
	eq(Opponents.DAWSON, Opponents.count())
	check(Opponents.exists(Opponents.DAWSON) and Opponents.exists(Opponents.PEPPER)
		and not Opponents.exists(Opponents.PEPPER + 1), "Dawson, then the story's Pepper")
	check(Opponents.solo(Opponents.DAWSON) and not Opponents.solo(7))
	eq(Opponents.team(Opponents.DAWSON)["team"], "DALE DAWSON")
	eq(Story.rung_line(Opponents.DAWSON), "THE COVER MATCH")
	eq(Opponents.slot_celebrate(Settings.config_for(false, Opponents.DAWSON, K.DIFFICULTY_MEDIUM, 11), 2),
		"thumbs_up")


## Doubles against him is two against one; he runs faster than anyone.
func test_alone_and_fast() -> void:
	var cfg := Settings.config_for(true, Opponents.DAWSON, K.DIFFICULTY_MEDIUM, 11)
	check(cfg.slot_active(2) and not cfg.slot_active(3), "his partner's slot sits out")
	var s := Sim.new(cfg)
	eq([s.players[2].active, s.players[3].active], [1, 0])
	eq(s.players[2].max_speed_fp, 30, "faster than a human (%d)" % K.PLAYER_MAX_SPEED_FP)
	check(not s.ai.slots[2].has_partner if "has_partner" in s.ai.slots[2] else true, "covering alone")
	s.p1_bot = true
	var points := 0
	var finished := false
	for f in 60 * 60 * 6:
		var it := SimTypes.Intent.new()
		it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and (f & 31) == 0) else 0
		s.step([it, null, null, null])
		for e in s.drain_events():
			points += 1 if e[0] == K.EVENT_POINT else 0
		if s.phase == K.PHASE_MATCH_RESULT:
			finished = true
			break
	check(finished and points >= 11, "a doubles match against him finishes (%d points)" % points)
	s.dispose()
	var singles := Settings.config_for(false, Opponents.DAWSON, K.DIFFICULTY_MEDIUM, 11)
	check(singles.slot_active(2) and not singles.slot_active(3))


## VS offers him once a ladder has been cleared, and not before.
func test_unlocked_by_a_clear() -> void:
	var s := fresh_save("user://test_dawson/")
	var kept := Settings.opponent_i
	var t := title_screen(s)
	check(not t.dawson_unlocked())
	var seen := []
	Settings.opponent_i = -2
	for k in 12:
		t._change_opponent(1)
		seen.append(Settings.opponent_i)
	check(not Opponents.DAWSON in seen, "locked: not offered")
	s.data["records"]["ladder_clears"] = 1
	seen = []
	for k in 12:
		t._change_opponent(1)
		seen.append(Settings.opponent_i)
	check(Opponents.DAWSON in seen, "after a clear: offered")
	Settings.opponent_i = Opponents.DAWSON
	eq(t._opponent_label(), "DALE DAWSON")
	eq(t.config(true).palette[3], -1, "doubles: two against one")
	t.free()
	Settings.opponent_i = kept
