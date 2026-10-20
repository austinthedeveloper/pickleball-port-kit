## The sprite wish list in play (SNES ADR-064), ported from the SNES
## repo's test_flair.c: point reactions over bot play (dives on time),
## celebrations by team, quip emotes by fault and how long they last, the
## dink note, the net's shiver, and the Z's for a human server only. Then
## the view: a match plays the same with flair as a bare sim.
extends TestSuite


func _flair(cfg: SimTypes.MatchConfig = null) -> Flair:
	var s := Sim.new(cfg if cfg else SimTypes.MatchConfig.singles())
	var f := Flair.new().setup(s, false)
	return f


func _done(f: Flair) -> void:
	f.sim.dispose()
	f.free()


## Bot play for 20 minutes: in a rally nobody reacts; at a point, the
## winners cheer (the default CPU) and the losers slump, or the nearest
## runner dives, scrambles and slumps on time.
func test_point_reactions() -> void:
	var f := _flair()
	var s := f.sim
	s.p1_bot = true
	var points := 0
	var dives := 0
	var stages := [0, 0, 0]
	var ok := true
	var m := 0
	for frame in 60 * 60 * 20:
		s.set_bot_skill(4, m)
		var it := SimTypes.Intent.new()
		it.hit_pressed = 1 if (s.phase == K.PHASE_SERVE_SETUP and s.server_index == 0 and (frame & 31) == 0) else 0
		if s.phase == K.PHASE_MATCH_RESULT:
			m += 1
			s.new_match()
			f.begin()
		s.step([it, null, null, null])
		for e in s.drain_events():
			f.on_event(e)
		f.tick()
		if s.phase == K.PHASE_LIVE:
			for slot in K.MAX_PLAYERS:
				ok = ok and f.body_frame(slot) == ""
			continue
		if s.phase != K.PHASE_POINT_RESULT:
			continue
		if f.result_frames == 1:
			points += 1
		for slot in [0, 2]:
			var b := f.body_frame(slot)
			if s.players[slot].team == s.point_winner:
				ok = ok and b == "cheer"
				continue
			if f.react[slot] != Flair.REACT_DIVE:
				ok = ok and b == "slump"
				continue
			ok = ok and s.last_fault == K.FAULT_SECOND_BOUNCE
			if f.result_frames == 1:
				dives += 1
			if b == "dive":
				ok = ok and f.result_frames < Flair.DIVE_FRAMES
				stages[0] += 1
			elif b == "scramble":
				ok = ok and f.result_frames >= Flair.DIVE_FRAMES
				stages[1] += 1
			else:
				ok = ok and b == "slump" and f.result_frames >= Flair.SCRAMBLE_END
				stages[2] += 1
	print("    flair: %d points, %d dives (dive %d, scramble %d, slump %d frames)" % [
		points, dives, stages[0], stages[1], stages[2]])
	check(ok, "every reaction as the rules say")
	check(points > 50 and dives > 0 and dives < points, "points and dives")
	check(stages[0] and stages[1] and stages[2], "each dive stage shows")
	_done(f)


## Ladder players celebrate their own way; humans and the others cheer.
func test_celebrations() -> void:
	var expect := ["thumbs_up", "cheer", "flex", "en_garde"]
	for opponent in 4:
		var cfg := SimTypes.MatchConfig.doubles()
		cfg.opponent = opponent
		var f := _flair(cfg)
		eq(f.celebrate[0], "cheer", "a human")
		eq([f.celebrate[2], f.celebrate[3]], [expect[opponent], expect[opponent]],
			Opponents.team(opponent)["team"])
		_done(f)
	var f := _flair()
	eq(f.celebrate[2], "cheer", "the default CPU")
	_done(f)


## A quip's emote says how the point was lost; it lasts the result.
func test_quip_emotes() -> void:
	var faults := [K.FAULT_NET, K.FAULT_OUT, K.FAULT_SECOND_BOUNCE, K.FAULT_KITCHEN,
		K.FAULT_EARLY_VOLLEY]
	var emotes := [Flair.EMOTE_EXCLAIM, Flair.EMOTE_QUESTION, Flair.EMOTE_SWEAT,
		Flair.EMOTE_ANGER, Flair.EMOTE_ANGER]
	var f := _flair()
	var s := f.sim
	for i in faults.size():
		s.phase = K.PHASE_POINT_RESULT
		f.tick()
		s.last_fault = faults[i]
		f.quip(1)
		eq(f.emote[2], emotes[i], "fault %d" % faults[i])
		eq(f.emote[0], Flair.EMOTE_NONE, "not the winner")
		for t in 100:
			f.tick()
		eq(f.emote[2], emotes[i], "held")
		s.phase = K.PHASE_SERVE_SETUP
		s.phase_timer = 0
		f.tick()
		eq(f.emote[2], Flair.EMOTE_NONE, "gone with the next serve")
		f.quip(1)
		eq(f.emote[2], Flair.EMOTE_NONE, "a quip picked late: none")
	_done(f)


## Three soft shots in a row: a note over the third's hitter, for a while;
## a ball into the net shivers it.
func test_dink_note() -> void:
	var f := _flair()
	f.sim.phase = K.PHASE_LIVE
	f.tick()
	f.on_event([K.EVENT_SERVE, 0, 0, 0])
	f.on_event([K.EVENT_HIT, 0, 0, 2 | (K.SHOT_SOFT << 4)])
	f.on_event([K.EVENT_HIT, 0, 0, 0 | (K.SHOT_SOFT << 4)])
	eq(f.emote[0], Flair.EMOTE_NONE)
	f.on_event([K.EVENT_HIT, 0, 0, 2 | (K.SHOT_STANDARD << 4)])
	f.on_event([K.EVENT_HIT, 0, 0, 0 | (K.SHOT_SOFT << 4)])
	f.on_event([K.EVENT_HIT, 0, 0, 2 | (K.SHOT_SOFT << 4)])
	eq(f.emote[2], Flair.EMOTE_NONE, "the run reset")
	f.on_event([K.EVENT_HIT, 0, 0, 0 | (K.SHOT_SOFT << 4)])
	eq(f.emote[0], Flair.EMOTE_NOTE)
	for t in range(1, Flair.NOTE_FRAMES):
		f.tick()
	eq(f.emote[0], Flair.EMOTE_NOTE, "for a while")
	f.tick()
	eq(f.emote[0], Flair.EMOTE_NONE)
	f.on_event([K.EVENT_FAULT, 128, 60, K.FAULT_NET])
	eq(f.cord_timer, Flair.CORD_FRAMES, "the net shivers")
	for t in Flair.CORD_FRAMES:
		f.tick()
	eq(f.cord_timer, 0)
	_done(f)


## A human server slow to serve: the receivers nod off, until the serve. A
## CPU (or the bot) takes its time without them.
func test_waiting_zzz() -> void:
	var f := _flair()
	var s := f.sim
	s.phase = K.PHASE_SERVE_SETUP
	s.server_index = 0
	s.phase_timer = Flair.ZZZ_WAIT - 1
	f.tick()
	eq(f.emote[2], Flair.EMOTE_NONE)
	s.phase_timer = Flair.ZZZ_WAIT
	f.tick()
	eq(f.emote[2], Flair.EMOTE_ZZZ, "the receiver")
	eq(f.emote[0], Flair.EMOTE_NONE, "not the server")
	s.phase = K.PHASE_SERVE_TOSS
	f.tick()
	eq(f.emote[2], Flair.EMOTE_NONE, "gone with the serve")
	s.p1_bot = true
	s.phase = K.PHASE_SERVE_SETUP
	s.phase_timer = Flair.ZZZ_WAIT * 2
	f.tick()
	eq(f.emote[2], Flair.EMOTE_NONE, "the bot serving: none")
	_done(f)


## Display only: a match with flair plays as a bare sim does.
func test_view_matches_a_bare_sim() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.opponent = 2
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, "park", false)
	v.sim.p1_bot = true
	v.highlight = null                   # the match ends in here: no replay over it
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	var reacted := false
	for frame in 3000:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		for slot in K.MAX_PLAYERS:
			reacted = reacted or v.flair.body_frame(slot) == "flex"
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % frame)
			break
	check(reacted, "the GYM BROS flexed")
	bare.dispose()
	v.free()


## GLOW and INVERSE (SNES ADR-054) are display only: a match with both plays
## as a bare sim does; GLOW sets NIGHT and the LIME lines, every player on
## neon role sheets; INVERSE puts the negative under the HUD.
func test_glow_and_inverse() -> void:
	var cfg := SimTypes.MatchConfig.doubles()
	cfg.modifiers = K.MOD_GLOW | K.MOD_INVERSE
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(cfg, "park", false)
	v.sim.p1_bot = true
	eq(v.time, MatchView.GLOW_TIME, "lights out")
	eq(v.court[3], MatchView.GLOW_LINES, "LIME lines")
	eq(CourtStyle.names("lines")[MatchView.GLOW_LINES], "LIME")
	var order := String(v.manifest["sprites"]["players"]["roles"]["order"])
	for slot in K.MAX_PLAYERS:
		var look: PlayerLook = v._players[slot]["look"]
		check(look != null and look.palette[order.find("o")] == PlayerLook.NEON, "slot %d glows" % slot)
	var negs := v.find_children("*", "CanvasLayer", false, false).filter(func(l): return l.layer == 9)
	eq(negs.size(), 1, "the negative under the HUD")
	var bare := Sim.new(cfg)
	bare.p1_bot = true
	for frame in 1200:
		v._physics_process(1.0 / 60.0)
		bare.step([SimTypes.Intent.new(), null, null, null])
		bare.drain_events()
		if v.sim.snapshot() != bare.snapshot():
			runner.fail("diverged at frame %d" % frame)
			break
	bare.dispose()
	v.free()
	check(K.MOD_INVERSE & Settings.MOD_SAVED and K.MOD_GLOW & Settings.MOD_SAVED, "both saved")


## The circles at the feet (SNES ADR-066's rings, filled): P1 in their
## colour, CPUs grey, each multiplayer slot its player's, none in the demo.
func test_markers() -> void:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.doubles(), "park", false)
	eq([v.marker_player(0), v.marker_player(1), v.marker_player(2)], [0, -1, -1], "P1 and the CPUs")
	eq(v.marker_color(0), Color(LobbyScreen.PLAYER_TINTS[0], MatchView.MARKER_ALPHA))
	v.slot_pads = [0, 1, 2, -1]
	v.slot_players = [0, 2, 1, -1]
	eq([v.marker_player(1), v.marker_player(2), v.marker_player(3)], [2, 1, -1], "multiplayer")
	v.free()
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(SimTypes.MatchConfig.doubles(), "park", true)
	eq(d.marker_player(0), -2, "none in the demo")
	eq(d.marker_color(0).a, 0.0)
	d.free()
