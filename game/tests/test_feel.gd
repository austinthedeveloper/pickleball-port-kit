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
