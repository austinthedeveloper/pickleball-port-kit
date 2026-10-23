## DINOSAUR's background dinosaurs (ADR-084): display only, deterministic,
## wandering, and always behind the fence.
extends TestSuite


func _view() -> MatchView:
	var view := MatchView.new()
	runner.root.add_child(view)
	view.setup(SimTypes.MatchConfig.doubles(), "dinosaur", true)
	return view


## Every dinosaur's look this frame: name, place, cell, facing, strip.
func _looks(view: MatchView) -> Array:
	var out := []
	for d in view.dinos.dinos:
		var s: Sprite2D = d[0]
		out.append([d[1]["name"], s.position, s.region_rect, s.flip_h, s.texture.resource_path, s.visible])
	return out


func test_dinos_only_on_the_dinosaur_venue() -> void:
	var sim := Sim.new(SimTypes.MatchConfig.doubles())
	for venue in Settings.VENUES:
		var w := DinoWalkers.for_venue(venue, sim, {"sky": [0, 0.2], "trees": [2, 0.6], "stands": [4, 1.0]},
			Color.WHITE)
		check((w != null) == (venue == "dinosaur"), venue)
		if w:
			w.free()
	sim.dispose()


func test_dinos_leave_the_sim_alone() -> void:
	var view := _view()
	check(view.dinos != null, "the dinosaur venue has its dinosaurs")
	var bare := Sim.new(SimTypes.MatchConfig.doubles())
	bare.start_attract()
	for f in 1500:
		view._physics_process(1.0 / 60.0)
		bare.step()
		bare.drain_events()
		if view.sim.snapshot() != bare.snapshot():
			runner.fail("view's sim diverged from a bare sim at frame %d" % f)
			break
	check(true)
	bare.dispose()
	view.queue_free()


func test_dinos_repeat() -> void:
	var a := _view()
	var b := _view()
	for f in 900:
		a._physics_process(1.0 / 60.0)
		b._physics_process(1.0 / 60.0)
		if f % 150 == 0:
			eq(_looks(a), _looks(b), "frame %d" % f)
	a.queue_free()
	b.queue_free()


func test_carnotaurus_wanders() -> void:
	var c: Dictionary = DinoWalkers.CAST[0]
	eq(c["name"], "carnotaurus")
	var legs := DinoWalkers.plan(c)
	var period: int = legs[-1][0] + legs[-1][1]
	var xs := []
	var facings := {}
	var strips := {}
	var frames := {}
	var prev: Array = DinoWalkers.pose_at(c, legs, period - 1)
	for f in period * 2:
		var p := DinoWalkers.pose_at(c, legs, f)
		xs.append(p[2].x)
		facings[p[3]] = true
		strips[p[0]] = true
		frames[str(p[0], p[1])] = true
		check(absf(p[2].x - prev[2].x) <= 1.0, "no jumps at frame %d" % f)    # the loop too
		prev = p
	check(xs.min() <= 200.0 and xs.max() >= 1000.0, "crosses the venue and walks off it")
	eq(facings.size(), 2, "turns both ways")
	eq(strips.size(), 2, "walks and stands")
	eq(frames.size(), 6, "every frame of the walk and the idle")
	eq(DinoWalkers.pose_at(c, legs, 123), DinoWalkers.pose_at(c, legs, 123 + period), "loops")


func test_dinos_stay_behind_the_fence() -> void:
	var view := _view()
	var fence_z := -1
	for n in view.get_children():
		if n is Sprite2D and n.texture and n.texture.resource_path.ends_with("/fence.png"):
			fence_z = n.z_index
	check(fence_z > 0, "found the fence")
	for f in 2400:
		view._physics_process(1.0 / 60.0)
		if f % 40:
			continue
		for d in view.dinos.dinos:
			var s: Sprite2D = d[0]
			check(s.z_index < fence_z, "%s under the fence" % d[1]["name"])
			var feet := s.position.y                       # offset puts the feet here
			check(feet <= 170.0, "%s's feet behind the fence (y %d)" % [d[1]["name"], feet])
	view.queue_free()
