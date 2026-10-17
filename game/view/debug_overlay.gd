## Diagnostics (docs/05_TEST_PLAN.md "Debug instrumentation"), toggled
## with F3: game state and timer, positions and states, ball position and
## velocity, bounces and last hitter, predicted landing markers, hit
## volumes, court bounds, P1 input, and the last fault. Reads only.
class_name DebugOverlay
extends Node2D

var view: MatchView
var _label: Label


func _ready() -> void:
	z_index = 100
	_label = Label.new()
	_label.position = Vector2(8, 64)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)
	visible = false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F3:
		visible = not visible


func refresh() -> void:
	if not visible:
		return
	var s := view.sim
	var b := s.ball
	var phases := ["SERVE_SETUP", "SERVE_TOSS", "LIVE", "SERVE_FAULT", "POINT_RESULT", "MATCH_RESULT"]
	var lines := PackedStringArray()
	lines.append("frame %d  phase %s t=%d  score %d-%d  serve team %d (slot %d)" % [s.frame_count,
		phases[s.phase], s.phase_timer, s.team_score[0], s.team_score[1], s.serving_team, s.server_index])
	lines.append("required bounce %d  last fault %s  shot #%d  paced %s" % [s.required_bounce,
		K.fault_word(s.last_fault), s.shot_serial, s.ball_paced])
	lines.append("ball (%.1f, %.1f, z %.1f) v (%d, %d, %d)  bounces %d  last hitter %d  %s" % [
		b.x_fp / 16.0, b.y_fp / 16.0, b.z_fp / 16.0, b.vx_fp, b.vy_fp, b.vz_fp, b.bounce_count,
		b.last_hitter, "LIVE" if b.rally_state else "dead"])
	var states := ["IDLE", "MOVE", "WINDUP", "ACTIVE", "RECOVERY"]
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = s.players[i]
		if not p.active:
			continue
		var a: SimTypes.AiState = s.ai.slots[i]
		lines.append("P%d %s (%.1f, %.1f) v (%d, %d) %s%s  ai target %s land (%d, %d) in %d" % [i,
			["HUMAN", "", "CPU"][s.owners[i]] if s.owners[i] != 0 else "-", p.x_fp / 16.0,
			p.y_fp / 16.0, p.vx_fp, p.vy_fp, states[p.state], " frozen" if p.frozen else "",
			"yes" if a.has_target else "no", a.predicted_land_x, a.predicted_land_y, a.predicted_frames])
	var it: SimTypes.Intent = s.intents[0]
	lines.append("P1 input move (%d, %d) hit %d shot %d held %d" % [it.move_x, it.move_y,
		it.hit_pressed, it.shot, it.hit_held])
	_label.text = "\n".join(lines)
	queue_redraw()


func _draw() -> void:
	var s := view.sim
	var bounds := [CourtView.ground(K.to_fp(K.COURT_BASELINE_LEFT), K.to_fp(K.COURT_SIDELINE_TOP)),
		CourtView.ground(K.to_fp(K.COURT_BASELINE_RIGHT), K.to_fp(K.COURT_SIDELINE_TOP)),
		CourtView.ground(K.to_fp(K.COURT_BASELINE_RIGHT), K.to_fp(K.COURT_SIDELINE_BOTTOM)),
		CourtView.ground(K.to_fp(K.COURT_BASELINE_LEFT), K.to_fp(K.COURT_SIDELINE_BOTTOM))]
	for i in 4:
		draw_line(bounds[i], bounds[(i + 1) % 4], Color(1, 0, 1, 0.8), 1.0)
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = s.players[i]
		if not p.active:
			continue
		var c := Color(1, 1, 0, 0.9) if p.state == K.STATE_ACTIVE else Color(0, 1, 1, 0.6)
		var corners := []
		for d in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			corners.append(CourtView.ground(p.x_fp + d[0] * K.to_fp(K.HIT_REACH_X),
				p.y_fp + d[1] * K.to_fp(K.HIT_REACH_Y)))
		for k in 4:
			draw_line(corners[k], corners[(k + 1) % 4], c, 1.0)
		var a: SimTypes.AiState = s.ai.slots[i]
		if s.owners[i] == K.OWNER_CPU and a.has_target:
			var m := CourtView.ground(K.to_fp(a.predicted_land_x), K.to_fp(a.predicted_land_y))
			draw_line(m - Vector2(5, 5), m + Vector2(5, 5), Color.RED, 2.0)
			draw_line(m - Vector2(5, -5), m + Vector2(5, -5), Color.RED, 2.0)
