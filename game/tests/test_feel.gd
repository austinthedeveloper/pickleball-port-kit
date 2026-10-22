## PORT-01: contact punch is display only, fires on the right events, and
## settles back to rest.
extends TestSuite


func _view() -> MatchView:
	var v := MatchView.new()
	runner.root.add_child(v)
	v.setup(SimTypes.MatchConfig.singles(), "park", true)
	return v


func test_drive_shakes_and_settles() -> void:
	var v := _view()
	v.feel.on_event([K.EVENT_HIT, 100, 130, 0 | (K.SHOT_DRIVE << 4)])
	check(v.feel.shake_frames > 0, "a drive shakes the picture")
	var moved := false
	for f in 30:
		v.feel.update()
		if v.position != Vector2.ZERO:
			moved = true
	check(moved, "the picture moved")
	eq(v.position, Vector2.ZERO, "and came back to rest")
	v.feel.on_event([K.EVENT_HIT, 100, 130, 0 | (K.SHOT_STANDARD << 4)])
	eq(v.feel.shake_frames, 0, "a standard shot at a low ball doesn't shake")
	v.queue_free()


func test_bounce_squashes_the_ball() -> void:
	var v := _view()
	var base := v._ball_sprite.scale
	v.feel.on_event([K.EVENT_BOUNCE, 100, 130, 1])
	v.feel.update()
	check(v._ball_sprite.scale.x > base.x and v._ball_sprite.scale.y < base.y, "squashed wide")
	for f in Feel.SQUASH_FRAMES + 1:
		v.feel.update()
	eq(v._ball_sprite.scale, base, "back to round")
	v.queue_free()


func test_trail_follows_fast_balls_only() -> void:
	var v := _view()
	var b := v.sim.ball
	b.rally_state = K.BALL_RALLY_LIVE
	b.z_fp = K.to_fp(10)
	b.vx_fp = 60
	b.vy_fp = 0
	v._ball_root.visible = true
	for f in 10:
		v.feel.update()
	eq(v.feel.trail.size(), Feel.TRAIL_LEN, "a fast ball leaves a trail")
	b.vx_fp = 20
	for f in 10:
		v.feel.update()
	eq(v.feel.trail.size(), 0, "a slow one doesn't")
	v.queue_free()


func test_whoosh_on_contact_frames() -> void:
	var v := _view()
	var p: SimTypes.Player = v.sim.players[0]
	p.state = K.STATE_WINDUP
	v.feel.update()
	p.state = K.STATE_ACTIVE
	v.feel.update()
	eq(v.feel.whooshes.size(), 1, "the first active frame draws a whoosh")
	for f in Feel.WHOOSH_FRAMES:
		v.feel.update()
	eq(v.feel.whooshes.size(), 0, "and it fades")
	v.queue_free()


func test_feel_leaves_the_sim_alone() -> void:
	var v := _view()
	var bare := Sim.new()
	bare.start_attract()
	for f in 1200:
		v._physics_process(1.0 / 60.0)
		bare.step()
		bare.drain_events()
	eq(v.sim.snapshot(), bare.snapshot(), "1200 frames with every effect on")
	v.queue_free()


## PORT-66: a scuff where the ball lands, fading, a dozen at most.
func test_bounce_marks() -> void:
	var v := _view()
	var m := v.effects.marks
	v.effects.on_event([K.EVENT_BOUNCE, 60, 120, 1])
	eq(m.list.size(), 1, "a bounce leaves a mark")
	for i in 20:
		v.effects.on_event([K.EVENT_BOUNCE, 60 + i, 120, 1])
	eq(m.list.size(), CourtEffects.MARK_MAX, "the oldest go")
	for f in CourtEffects.MARK_FRAMES:
		v.effects.update()
	eq(m.list.size(), 0, "and they fade away")
	v.queue_free()


## PORT-66: camera flashes at the big moments, none with FLASHES off or in
## the demo.
func test_camera_flashes() -> void:
	var kept := Settings.flashes
	var cfg := SimTypes.MatchConfig.singles()
	var v := match_view(cfg)
	v.highlight = null
	Settings.flashes = true
	v.effects.on_event([K.EVENT_HIT, 100, 120, 0 | (K.SHOT_SPECIAL << 4)])
	check(v.effects.flashes.left > 0, "PICKLE SMASH: the cameras flash")
	var seen := 0
	for f in CourtEffects.FLASH_BURST:
		v.effects.update()
		seen = maxi(seen, v.effects.flashes.lit.size())
	check(seen > 0, "glints in the stands")
	v.effects.flashes.left = 0
	v.sim.rally_start = (v.sim.shot_serial - 15) & 0xff
	v.effects.on_event([K.EVENT_HIT, 100, 120, 0])
	check(v.effects.flashes.left > 0, "a 15-shot rally")
	v.effects.flashes.left = 0
	Settings.flashes = false
	v.effects.flash(CourtEffects.FLASH_BIG)
	eq(v.effects.flashes.left, 0, "FLASHES off: none")
	Settings.flashes = kept
	v.queue_free()
	var demo := _view()
	demo.effects.flash(CourtEffects.FLASH_BIG)
	eq(demo.effects.flashes.left, 0, "none in the demo")
	demo.queue_free()


## PORT-66: a ball that clips the tape and goes over shakes the net; one
## well over doesn't; one into the net does.
func test_net_cord() -> void:
	var v := _view()
	var b := v.sim.ball
	b.active = 1
	b.rally_state = K.BALL_RALLY_LIVE
	for clear in [1, 10]:
		v.effects.shake = 0
		b.x_fp = K.to_fp(K.COURT_NET_X - 2)
		b.z_fp = K.to_fp(K.COURT_NET_HEIGHT + clear)
		v.effects.update()
		b.x_fp = K.to_fp(K.COURT_NET_X + 2)
		v.effects.update()
		if clear == 1:
			check(v.effects.shake > 0, "a net cord shakes the net")
			check(v.effects.net_offset() != Vector2.ZERO or v.effects.shake < CourtEffects.SHAKE_FRAMES,
				"the net moves")
		else:
			eq(v.effects.shake, 0, "well over: still")
	v.effects.on_event([K.EVENT_FAULT, 128, 120, K.FAULT_NET])
	eq(v.effects.shake, CourtEffects.SHAKE_FRAMES, "into the net: it shakes")
	for f in CourtEffects.SHAKE_FRAMES:
		v.effects.update()
	eq(v.effects.net_offset(), Vector2.ZERO, "and settles")
	v.queue_free()
