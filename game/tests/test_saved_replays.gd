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
	var t := TitleScreen.new()
	t.save = fresh_save("user://test_saved_replays/")
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	return t


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
