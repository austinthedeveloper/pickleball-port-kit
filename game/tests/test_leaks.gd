## Memory: a match built and freed leaves (almost) nothing behind. The sim
## and its AI (and practice machine) refer to each other, a cycle that
## reference counting can't free; MatchView disposes the sim as it goes
## (it used to leak ~26 objects a match, every title demo restart too).
extends TestSuite


func _objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func test_matches_free_their_sim() -> void:
	# warm the caches (textures, fonts, looks) first
	for k in 2:
		var w := MatchView.new()
		runner.root.add_child(w)
		w.setup(SimTypes.MatchConfig.doubles(), "park", true)
		w.free()
	var before := _objects()
	for k in 10:
		var v := MatchView.new()
		runner.root.add_child(v)
		v.setup(SimTypes.MatchConfig.doubles() if k % 2 else SimTypes.MatchConfig.singles(), "park", k % 3 == 0)
		v.free()
	var grown := _objects() - before
	check(grown <= 20, "10 matches built and freed left %d objects (a sim cycle leaks ~26 each)" % grown)


func test_dispose_breaks_the_cycle() -> void:
	var sim := Sim.new()
	var ref: WeakRef = weakref(sim)
	sim.dispose()
	sim = null
	check(ref.get_ref() == null, "a disposed sim is freed when let go")
	var kept := Sim.new()
	var kept_ref: WeakRef = weakref(kept)
	kept = null
	check(kept_ref.get_ref() != null, "an undisposed one lives on in its cycle (why dispose exists)")
