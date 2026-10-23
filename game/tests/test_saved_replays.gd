## Saved replays (PORT-69, ADR-081): the pause menu's SAVE LAST RALLY keeps
## the rally that ended last as a file (the match's inputs up to it), and
## REPLAYS on the title plays it back, exactly, or the title's demo does,
## quietly. Saving never touches the live match.
extends TestSuite


func _view(points := 5) -> MatchView:
	return match_view(Settings.config_for(false, 2, K.DIFFICULTY_MEDIUM, points))


## Plays until a rally has ended and the next serve is being set up.
func _to_a_rally(v: MatchView) -> bool:
	for f in 60 * 60 * 3:
		v._physics_process(1.0 / 60.0)
		if not v.highlight.last.is_empty() and v.sim.phase == K.PHASE_SERVE_SETUP:
			return true
	return false


func _title() -> TitleScreen:
	return title_screen(fresh_save("user://test_saved_replays/"))


## A saved replay played on a view of its own, as the title does; the
## replay's snapshot where the rally ended, and whether it finished.
func _play_saved(data: Dictionary) -> Array:
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(OnlineSession.config_from_dict(data["cfg"]), str(data["venue"]), true)
	var h := Highlight.from_saved(d, data)
	d.highlight = h
	var done := []
	check(h.start(func(): done.append(1)), "it starts")
	var at_end: Array = []
	for f in 20000:
		if not h.playing():
			break
		if h.replay and h._frame == int(h.best["to"]) + 1 and at_end.is_empty():
			at_end = h.replay.snapshot()
		d._physics_process(1.0 / 60.0)
	d.free()
	return [at_end, not done.is_empty()]


func test_save_and_watch() -> void:
	wipe_replays()
	var v := _view()
	check(v._hud.pause_menu.index_of("save_rally") >= 0, "the pause row")
	eq(v.save_rally_state(), "NONE YET", "before a rally")
	check(not v.save_rally(), "nothing to save")
	check(_to_a_rally(v), "a rally ends")
	var shots := int(v.highlight.last["shots"])
	eq(v.save_rally_state(), "%d SHOTS" % shots)
	var live := v.sim.snapshot()
	check(v.save_rally(), "saved")
	eq(v.sim.snapshot(), live, "the live match never moved")
	eq(v.save_rally_state(), "SAVED")
	check(not v.save_rally(), "once")
	var list := SavedReplays.list()
	eq(list.size(), 1, "one replay")
	check(list[0]["playable"], "playable here")
	eq(list[0]["shots"], shots)
	var data := SavedReplays.load_replay(list[0]["name"])
	var rally: Dictionary = data["rally"]
	v.free()
	var r := _play_saved(data)
	eq(r[0], rally["snap_to"], "the replay is the rally, exactly")
	check(r[1], "and it ends")


## Six at most; the pause row says FULL; REPLAYS lists the newest first;
## a replay from another sim is OLD and doesn't play.
func test_full_old_and_order() -> void:
	wipe_replays()
	var v := _view()
	check(_to_a_rally(v))
	var data := v.highlight.export(v.highlight.last)
	for i in SavedReplays.MAX:
		data["saved"] = 1000 + i
		check(SavedReplays.save(data) != "", "slot %d" % i)
	eq(v.save_rally_state(), "FULL")
	check(not v.save_rally(), "no seventh")
	var list := SavedReplays.list()
	eq(list[0]["saved"], 1000 + SavedReplays.MAX - 1, "newest first")
	SavedReplays.remove(list[0]["name"])
	eq(SavedReplays.list().size(), SavedReplays.MAX - 1, "removed")
	var old := data.duplicate()
	old["tuning"] = K.TUNING_VERSION + 1
	old["saved"] = 5000
	SavedReplays.save(old)
	var top: Dictionary = SavedReplays.list()[0]
	check(not top["playable"], "another sim's replay")
	eq(SavedReplays.row_value(top), "OLD VERSION")
	v.free()
	wipe_replays()


## Not where there's no PLAY OF THE MATCH: the demo, practice.
func test_where_it_is() -> void:
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(SimTypes.MatchConfig.doubles(), "park", true)
	check(d._hud.pause_menu.index_of("save_rally") < 0, "not the demo")
	d.free()
	var p := MatchView.new()
	runner.root.add_child(p)
	p.setup(SimTypes.MatchConfig.practice_session(Practice.DEFAULTS, 0), "park", false)
	check(p._hud.pause_menu.index_of("save_rally") < 0, "not practice")
	p.free()


## REPLAYS: a press watches (the menu gives the screen up, then has it
## back); ON PRESS DELETE deletes.
func test_title_watch_and_delete() -> void:
	wipe_replays()
	var v := _view()
	check(_to_a_rally(v))
	check(v.save_rally())
	v.free()
	var t := _title()
	t.open_page("player")
	t.pages["player"].settle()
	eq(t.pages["player"].value_of("replays"), "1 SAVED")
	t.open_page("replays")
	var page: MenuPage = t.pages["replays"]
	page.settle()
	check(t.replay_label(0).ends_with(" SHOTS"), "the row: " + t.replay_label(0))
	eq(t.replay_label(1), "EMPTY")
	t.replay_press(0)
	check(t.watching and not t._ui.visible, "watching")
	check(t._demo.highlight.saved and not t._demo.highlight.quiet, "the saved rally, with its card")
	for f in 20000:
		if not t.watching:
			break
		t._demo._physics_process(1.0 / 60.0)
	check(not t.watching and t._ui.visible, "back to REPLAYS")
	eq(t.page, "replays")
	page.select("on_press")
	page.change(1)
	check(t.replay_delete, "DELETE")
	t.replay_press(0)
	eq(SavedReplays.list().size(), 0, "deleted")
	eq(t.replay_label(0), "EMPTY")
	t.free()


## The title's demo: with IN THE DEMO on, every other one is a saved
## replay, quietly; off, never. The setting is saved.
func test_demo_takes_turns() -> void:
	wipe_replays()
	var kept := Settings.replays_in_demo
	var v := _view()
	check(_to_a_rally(v))
	check(v.save_rally())
	v.free()
	var t := _title()
	Settings.replays_in_demo = true
	var kinds := []
	for i in 4:
		t._start_demo(true)
		var h := t._demo.highlight
		kinds.append(h != null and h.saved and h.quiet)
	eq(kinds.count(true), 2, "every other demo: %s" % str(kinds))
	Settings.replays_in_demo = false
	for i in 4:
		t._start_demo(true)
		check(t._demo.highlight == null, "off: the live demo")
	var sv := fresh_save("user://test_saved_replays/")
	Settings.store_to(sv)
	Settings.replays_in_demo = true
	Settings.load_from(sv)
	check(not Settings.replays_in_demo, "saved off")
	Settings.replays_in_demo = kept
	t.free()
	wipe_replays()


## PORT-70: SAVE while PLAY OF THE MATCH plays keeps its rally (once; the
## card says so), FULL says why not, and a saved replay's card has none.
func test_save_play_of_the_match() -> void:
	wipe_replays()
	var v := _view()
	var over := false
	for f in 60 * 60 * 10:
		v._physics_process(1.0 / 60.0)
		if v.highlight.playing():
			over = true
			break
	check(over, "PLAY OF THE MATCH (%d shots)" % int(v.highlight.best.get("shots", 0)))
	var h := v.highlight
	eq(h.best_state(), "SAVE")
	eq(h._prompts.items.size(), 2, "SKIP and SAVE")
	var live: Array = h._live.snapshot() if h._live else v.sim.snapshot()
	h.on_save()
	eq(h.best_state(), "SAVED")
	check(h._caption[1].text.ends_with(", SAVED"), h._caption[1].text)
	eq(h._prompts.items.size(), 1, "SAVE goes")
	h.on_save()
	eq(SavedReplays.list().size(), 1, "saved once")
	var data := SavedReplays.load_replay(SavedReplays.list()[0]["name"])
	var rally: Dictionary = h.best.duplicate(true)
	h._finish()
	eq(v.sim.snapshot(), live, "the live match never moved")
	v.free()
	var r := _play_saved(data)
	eq(r[0], rally["snap_to"], "the saved rally, exactly")
	wipe_replays()
	var w := _view()
	w.highlight.best = {"shots": 9, "from": 0, "to": 0, "winner": 0, "fault": K.FAULT_OUT,
		"snap_from": [], "snap_to": []}
	for i in SavedReplays.MAX:
		SavedReplays.save({"format": SavedReplays.FORMAT, "tuning": K.TUNING_VERSION,
			"saved": i, "cfg": {}, "inputs": PackedInt32Array(), "ops": {}, "rally": {"shots": 1}})
	eq(w.highlight.best_state(), "FULL")
	check(not w.highlight.save_best(), "no seventh")
	w.free()
	wipe_replays()
	var s := _view()
	s.highlight.saved = true
	s.highlight.best = {"shots": 9}
	eq(s.highlight.best_state(), "", "a saved replay's card has no SAVE")
	s.free()


## One frame as MatchView plays it (recorded, then stepped), P1 a human
## who serves when it's theirs after standing four seconds (then a press
## every half second) and otherwise stands, with Start pressed when
## `pause` (a pause or an unpause).
func _frame(v: MatchView, pause := false) -> void:
	var it := SimTypes.Intent.new()
	it.pause_pressed = 1 if pause else 0
	if v.sim.phase == K.PHASE_SERVE_SETUP and v.sim.server_index == 0 and not v.sim.paused \
			and v.sim.phase_timer >= 240 and v.highlight.frames() % 30 == 0:
		it.hit_pressed = 1
	var human := [it, null, null, null]
	v.highlight.record(human)
	v.sim.step(human)
	v.highlight.after_step(v.sim.drain_events())


## PORT-71: a replay starts a moment before the serve is struck and ends
## soon after the ball is dead; a pause in the rally (and the wait in the
## menu) is never shown. The rally is still exact.
func test_trimmed_to_the_rally() -> void:
	wipe_replays()
	var v := _view()
	v.sim.p1_bot = false                 # a bot's intent drops the pause bit (sim.gd)
	var paused_at := -1
	for f in 60 * 60 * 3:
		var live := v.sim.phase == K.PHASE_LIVE
		if paused_at < 0 and live and (v.sim.shot_serial - v.sim.rally_start) & 0xff >= 1:
			paused_at = v.highlight.frames()
			_frame(v, true)
			check(v.sim.paused != 0, "paused mid-rally")
			for w in 600:                       # ten seconds on the pause menu
				_frame(v)
			_frame(v, true)
			check(v.sim.paused == 0, "and back")
			continue
		_frame(v)
		if paused_at >= 0 and not v.highlight.last.is_empty() \
				and int(v.highlight.last["from"]) < paused_at:
			break
	var rally: Dictionary = v.highlight.last
	check(paused_at >= 0 and not rally.is_empty(), "a rally with a pause in it")
	check(int(rally["serve"]) - int(rally["from"]) >= 240, "a long wait before the serve")
	check(v.save_rally(), "saved")
	var data := SavedReplays.load_replay(SavedReplays.list()[0]["name"])
	v.free()
	var d := MatchView.new()
	runner.root.add_child(d)
	d.setup(OnlineSession.config_from_dict(data["cfg"]), "park", true)
	var h := Highlight.from_saved(d, data)
	d.highlight = h
	check(h.start(func(): pass))
	var first := -1
	var drawn := 0
	var paused_drawn := 0
	var at_end: Array = []
	for f in 20000:
		if not h.playing():
			break
		d._physics_process(1.0 / 60.0)
		if d.replaying():
			if first < 0:
				first = h._frame
			drawn += 1
			if h.replay.paused != 0:
				paused_drawn += 1
			if h._frame == int(rally["to"]) + 1 and at_end.is_empty():
				at_end = h.replay.snapshot()
	eq(first, int(rally["serve"]) - Highlight.LEAD_FRAMES, "it opens just before the serve, not the wait")
	eq(paused_drawn, 0, "the pause is never shown")
	check(drawn < int(rally["to"]) - int(rally["from"]) - 600 + Highlight.AFTER_FRAMES + Highlight.SLOW_FRAMES,
		"nor its ten seconds (%d frames drawn)" % drawn)
	eq(at_end, rally["snap_to"], "still the rally, exactly")
	d.free()
	wipe_replays()


## SAVE LAST RALLY and PLAY OF THE MATCH's SAVE on the same rally write it
## once, whichever comes first; a new match forgets the best.
func test_one_rally_saved_once() -> void:
	wipe_replays()
	var v := _view()
	check(_to_a_rally(v))
	var h := v.highlight
	h.best = h.last.duplicate(true)          # the match's longest so far
	eq(h.best_state(), "SAVE")
	check(v.save_rally(), "SAVE LAST RALLY")
	eq(h.best_state(), "SAVED", "PLAY OF THE MATCH's is the same rally")
	check(not h.save_best(), "not again")
	eq(SavedReplays.list().size(), 1, "one file")
	v.free()
	wipe_replays()
	var w := _view()
	check(_to_a_rally(w))
	var g := w.highlight
	g.best = g.last.duplicate(true)
	check(g.save_best(), "PLAY OF THE MATCH's SAVE")
	eq(w.save_rally_state(), "SAVED", "SAVE LAST RALLY's is the same rally")
	check(not w.save_rally(), "not again")
	eq(SavedReplays.list().size(), 1, "one file")
	g.op(["new_match"])
	eq(g.best, {}, "a new match forgets the best")
	check(not g.saved_best, "...and that it was saved")
	eq(g.best_state(), "", "nothing to SAVE")
	w.free()
	wipe_replays()


## Files that aren't replays are skipped; another format doesn't play; two
## saved in the same second get their own names.
func test_bad_files() -> void:
	wipe_replays()
	var good := {"format": SavedReplays.FORMAT, "tuning": K.TUNING_VERSION, "saved": 77,
		"cfg": {}, "inputs": PackedInt32Array(), "ops": {}, "rally": {"shots": 3}}
	var plain := FileAccess.open(SavedReplays.dir + "plain" + SavedReplays.EXT, FileAccess.WRITE)
	plain.store_string("not a replay")
	plain.close()
	var bad := {"array": [1, 2], "missing": good.duplicate(), "inputs": good.duplicate(true)}
	bad["missing"].erase("rally")
	bad["inputs"]["inputs"] = [1, 2, 3]
	for n in bad:
		var f := FileAccess.open_compressed(SavedReplays.dir + n + SavedReplays.EXT, FileAccess.WRITE,
			FileAccess.COMPRESSION_GZIP)
		f.store_var(bad[n])
		f.close()
		eq(SavedReplays.load_replay(n + SavedReplays.EXT), {}, "%s isn't a replay" % n)
	eq(SavedReplays.load_replay("plain" + SavedReplays.EXT), {}, "a plain file isn't")
	eq(SavedReplays.load_replay("nowhere" + SavedReplays.EXT), {}, "nor a missing one")
	SavedReplays._cached = false
	eq(SavedReplays.list(), [], "REPLAYS skips them")
	eq(SavedReplays.save(good), "77" + SavedReplays.EXT)
	eq(SavedReplays.save(good), "77-2" + SavedReplays.EXT, "the same second: its own name")
	eq(SavedReplays.list().size(), 2)
	var other := good.duplicate()
	other["format"] = SavedReplays.FORMAT + 1
	check(not SavedReplays.playable(other), "another format doesn't play")
	check(SavedReplays.playable(good))
	wipe_replays()


## A replay shows the match's light effects: its bounces leave marks, and
## watched from REPLAYS the cameras flash (behind the title's menu, quiet,
## they don't, as in the demo).
func test_replays_show_the_effects() -> void:
	var kept := Settings.flashes
	Settings.flashes = true
	wipe_replays()
	var v := _view()
	check(_to_a_rally(v))
	var data := v.highlight.export(v.highlight.last)
	v.free()
	for quiet in [false, true]:
		var d := MatchView.new()
		runner.root.add_child(d)
		d.setup(OnlineSession.config_from_dict(data["cfg"]), str(data["venue"]), true)
		var h := Highlight.from_saved(d, data)
		h.quiet = quiet
		d.highlight = h
		check(h.start(func(): pass))
		var marked := false
		var flashed := false
		for f in 20000:
			if not h.playing():
				break
			d._physics_process(1.0 / 60.0)
			if d.replaying():
				d.effects.marks.list.clear()
				d._physics_process(1.0 / 60.0)
				marked = marked or not d.effects.marks.list.is_empty()
				d.effects.flashes.left = 0
				d.effects.flash(CourtEffects.FLASH_BURST)
				flashed = flashed or d.effects.flashes.left > 0
		if not quiet:
			check(marked, "the replay's bounces leave marks")
		eq(flashed, not quiet, "flashes when watched (quiet: %s)" % quiet)
		d.free()
	wipe_replays()
	Settings.flashes = kept
