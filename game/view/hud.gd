## The match HUD (layout from the art manifest's hud_layout): score panels,
## the mode banner, MATCH POINT, the serve prompt and meter, the point and
## match banners, and the pause menu. Reads the sim only.
class_name Hud
extends CanvasLayer

const UI := "res://assets/levels/ui/"

var view: MatchView
var _left_label: BitmapText
var _left_score: BitmapText
var _right_label: BitmapText
var _right_score: BitmapText
var _subtitle: Control
var _prompt: Control
var _banner: BitmapText
var _banner_sub: BitmapText
var _paused: Control
var pause_menu: MenuPage
var _meter: Control
var _meter_fill: ColorRect
var _point_banner_frames := 0
var _quip: Control
var _quip_text: BitmapText
var _quip_frames := 0
var _result_line: BitmapText
var _card: Control
var _practice_menu: Control


func _panel(name: String, rect: Rect2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(UI + "panel_" + name + ".png")
	n.patch_margin_left = 12
	n.patch_margin_top = 12
	n.patch_margin_right = 12
	n.patch_margin_bottom = 12
	n.position = rect.position
	n.size = rect.size
	add_child(n)
	return n


func _text(font: String, s: String, pos: Vector2, align := 0.0, tint := Color.WHITE,
		parent: Node = null) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.text = s
	t.align = align
	t.tint = tint
	t.position = pos
	(parent if parent else self).add_child(t)
	return t


func setup(v: MatchView) -> void:
	view = v
	layer = 10
	var cfg := view.sim.config
	var doubles := cfg.mode == K.MODE_DOUBLES
	var left_name := "P1"
	var right_name := "2P" if cfg.human[2] else "CPU"
	if doubles:
		left_name = MatchView.TEAM_NAMES[cfg.palette[0]]
		right_name = MatchView.TEAM_NAMES[cfg.palette[2]]
	if view.demo:
		left_name = "CPU" if not doubles else left_name
	if cfg.opponent >= 0 and not cfg.human[2] and not view.demo:
		right_name = Story.card_name(cfg.opponent, doubles)
	var left_tint: Color = MatchView.TEAM_TINTS[cfg.palette[0]]
	var right_tint: Color = MatchView.TEAM_TINTS[cfg.palette[2]]
	if cfg.opponent >= 0 and not cfg.human[2] and not view.demo:
		right_tint = Story.team_color(cfg.opponent)
	# Practice (ADR-028): P1 <streak>, the zone (PRACTICE on ANY), BEST <best>.
	var practice: bool = cfg.practice != 0
	if practice:
		right_name = "BEST"
		right_tint = Color("fbe46a")
	var lw := 74 + BitmapText.measure("big", left_name)
	var rw := 74 + BitmapText.measure("big", right_name)
	var title := "DOUBLES" if doubles else "ARCADE RULES"
	if practice:
		var zone: int = Practice.practice_zone(int(cfg.practice_settings[Practice.ROW_ZONE]))
		title = "PRACTICE" if zone == Practice.ZONE_ANY else Practice.zone_name(zone)
	var tw := 40 + BitmapText.measure("big_gold", title)
	var y := 14
	var h := 40
	var pan_l: String = ["blue", "red", "green", "gold"][cfg.palette[0]]
	var pan_r: String = "gold" if practice else ["blue", "red", "green", "gold"][cfg.palette[2]]
	_panel(pan_l, Rect2(480 - tw / 2 - 18 - lw, y, lw, h))
	_left_label = _text("big", left_name, Vector2(480 - tw / 2 - 18 - lw + 12, y + 8), 0, left_tint)
	_left_score = _text("big", "0", Vector2(480 - tw / 2 - 18 - 14, y + 8), 1.0)
	_panel(pan_r, Rect2(480 + tw / 2 + 18, y, rw, h))
	_right_label = _text("big", right_name, Vector2(480 + tw / 2 + 18 + 12, y + 8), 0, right_tint)
	_right_score = _text("big", "0", Vector2(480 + tw / 2 + 18 + rw - 14, y + 8), 1.0)
	_panel("doubles" if doubles else "title", Rect2(480 - tw / 2, y, tw, h))
	_text("big_gold", title, Vector2(480, y + 8), 0.5)
	if doubles:
		var icon := load(UI + "icon_ball.png")
		for x in [480 - tw / 2 + 8, 480 + tw / 2 - 23]:
			var s := Sprite2D.new()
			s.texture = icon
			s.centered = false
			s.position = Vector2(x, y + 13)
			add_child(s)
	_subtitle = Control.new()
	add_child(_subtitle)
	var sw := 30 + BitmapText.measure("small", "MATCH POINT")
	var sp := _panel("sub", Rect2(480 - sw / 2, y + h - 2, sw, 26))
	sp.reparent(_subtitle)
	_text("small", "MATCH POINT", Vector2(480, y + h + 4), 0.5, Color.WHITE, _subtitle)
	_prompt = Control.new()
	add_child(_prompt)
	var pw := 64 + BitmapText.measure("small", "PRESS    TO SERVE")
	var pp := _panel("title", Rect2(480 - pw / 2, 490, pw, 34))
	pp.reparent(_prompt)
	_text("small", "PRESS    TO SERVE", Vector2(480, 498), 0.5, Color.WHITE, _prompt)
	var btn := Sprite2D.new()
	btn.texture = load(UI + "button_B_red.png")
	btn.position = Vector2(480 - BitmapText.measure("small", "PRESS    TO SERVE") / 2.0
		+ BitmapText.measure("small", "PRESS ") + 14, 506)
	_prompt.add_child(btn)
	_meter = Control.new()
	add_child(_meter)
	var frame := ColorRect.new()
	frame.color = Color("0b0f1e")
	frame.size = Vector2(54, 9)
	_meter.add_child(frame)
	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(2, 2)
	_meter_fill.size = Vector2(0, 5)
	_meter.add_child(_meter_fill)
	_banner = _text("big_gold", "", Vector2(480, 250), 0.5)
	_banner_sub = _text("small", "", Vector2(480, 288), 0.5)
	_quip = Control.new()
	add_child(_quip)
	_quip_text = _text("small", "", Vector2(480, 320), 0.5, Color.WHITE, _quip)
	_result_line = _text("small", "", Vector2(480, 316), 0.5)
	if view.card_frames >= 0:
		_build_card(cfg)
	_paused = Control.new()
	add_child(_paused)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.08, 0.45)
	shade.size = Vector2(960, 540)
	_paused.add_child(shade)
	var rows := view.pause_rows()
	var ph := 46 + 46 + rows.size() * MenuPage.ROW_H - 10
	pause_menu = MenuPage.new().setup("pause", "PAUSED", rows, Rect2(330, 270 - ph / 2, 300, ph))
	_paused.add_child(pause_menu)
	if practice:
		_practice_menu = Control.new()
		add_child(_practice_menu)
		var mw := 40 + BitmapText.measure("small", "START: PAUSE")
		var mp := _panel("title", Rect2(480 - mw / 2, 490, mw, 34))
		mp.reparent(_practice_menu)
		_text("small", "START: PAUSE", Vector2(480, 498), 0.5, Color.WHITE, _practice_menu)
	refresh()


func _build_card(cfg: SimTypes.MatchConfig) -> void:
	var opp := cfg.opponent
	var doubles := cfg.mode == K.MODE_DOUBLES
	_card = Control.new()
	add_child(_card)
	var shade := ColorRect.new()
	shade.color = Color(0, 0.02, 0.08, 0.5)
	shade.size = Vector2(960, 540)
	_card.add_child(shade)
	var name := Story.card_name(opp, doubles)
	_text("big_gold", "", Vector2.ZERO, 0, Color.WHITE, _card)
	var title := _text("big", name, Vector2(480, 170), 0.5, Story.team_color(opp), _card)
	title.scale = Vector2(2, 2)
	title.position.x = 480
	var line := Story.intro_line(opp)
	var w := 40 + BitmapText.measure("small", line)
	var p := _panel("title", Rect2(480 - w / 2, 236, w, 36))
	p.reparent(_card)
	_text("small", line, Vector2(480, 246), 0.5, Color.WHITE, _card)
	_text("small", Story.rung_line(opp), Vector2(480, 296), 0.5, Color("fbe46a"), _card)
	_text("small", "B: PLAY", Vector2(480, 330), 0.5, Color.WHITE, _card)


func close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null


func team_tint(team: int) -> Color:
	var cfg := view.sim.config
	if team == 1 and cfg.opponent >= 0 and not cfg.human[2]:
		return Story.team_color(cfg.opponent)
	return MatchView.TEAM_TINTS[cfg.palette[team * 2]]


func show_quip(line: String, tint: Color) -> void:
	_quip_text.text = line
	_quip_text.tint = tint
	_quip_frames = 80


func on_point(winner: int) -> void:
	_point_banner_frames = 80


func on_new_match() -> void:
	_point_banner_frames = 0


func refresh() -> void:
	var s := view.sim
	_left_score.text = str(s.team_score[0])
	_right_score.text = str(s.team_score[1])
	var mp := s.phase <= K.PHASE_LIVE and (s.match_point(0) or s.match_point(1)) \
		and not s.config.practice
	_subtitle.visible = mp and not view.demo
	var human_serving: bool = not view.demo and s.owners[s.server_index] == K.OWNER_HUMAN
	_prompt.visible = human_serving and s.phase == K.PHASE_SERVE_SETUP \
		and s.phase_timer >= K.SERVE_READY_FRAMES and not s.charge_charging
	_meter.visible = human_serving and s.phase == K.PHASE_SERVE_SETUP and s.charge_charging
	if _meter.visible:
		var server: SimTypes.Player = s.players[s.server_index]
		var head := CourtView.ground(server.x_fp, server.y_fp) - Vector2(27, 112)
		_meter.position = head.round()
		var f := float(s.charge_level) / K.SERVE_CHARGE_MAX
		_meter_fill.size.x = 50.0 * f
		_meter_fill.color = Color("e04040") if s.charge_level < K.SERVE_CHARGE_DUD \
			else Color("f4c430").lerp(Color("60e060"), f)
	if s.paused != 0 and not _paused.visible:
		pause_menu.cursor = 0          # every pause opens on RESUME
		pause_menu.refresh()
	_paused.visible = s.paused != 0
	if _practice_menu:
		_practice_menu.visible = s.paused == 0
	if _point_banner_frames > 0:
		_point_banner_frames -= 1
	if _quip_frames > 0:
		_quip_frames -= 1
	_quip.visible = _quip_frames > 0 and s.phase == K.PHASE_POINT_RESULT and view.close_call == null
	_result_line.text = ""
	if s.phase == K.PHASE_MATCH_RESULT:
		var you := s.match_winner == 0
		if view.demo:
			_banner.text = "%s WINS" % _team_label(s.match_winner)
			_banner_sub.text = ""
		else:
			var cfg := s.config
			var vs_ladder: bool = cfg.opponent >= 0 and not cfg.human[2]
			_banner.text = "YOU WIN!" if you else "%s WINS" % _team_label(s.match_winner)
			if view.cleared:
				_banner.text = "CHAMPION!"
			var ready := s.phase_timer >= K.POINT_RESULT_MIN_FRAMES
			var next := "B: NEXT OPPONENT" if (view.ladder and you) else "B: REMATCH"
			_banner_sub.text = (next + "   START: MENU") if ready else ""
			if vs_ladder:
				_result_line.text = Story.result_line(cfg.opponent, you)
				_result_line.tint = Story.team_color(cfg.opponent)
				if view.cleared:
					_result_line.text = "LADDER CLEARED!"
					_result_line.tint = Color("fbe46a")
				elif view.ladder and you and view.save:
					_result_line.text += "  NEXT UP: " + String(Opponents.team(
						int(view.save.data["records"]["ladder_rung"]))["team"])
	elif s.phase == K.PHASE_POINT_RESULT and _point_banner_frames > 0:
		_banner.text = K.fault_word(s.last_fault)
		_banner_sub.text = "%s SCORES" % _team_label(s.point_winner)
	else:
		_banner.text = ""
		_banner_sub.text = ""


func _team_label(team: int) -> String:
	var cfg := view.sim.config
	if team == 1 and cfg.opponent >= 0 and not cfg.human[2]:
		return Story.card_name(cfg.opponent, cfg.mode == K.MODE_DOUBLES)
	if cfg.mode == K.MODE_DOUBLES:
		return MatchView.TEAM_NAMES[cfg.palette[team * 2]]
	if team == 0:
		return "CPU" if view.demo else "P1"
	return "2P" if cfg.human[2] else "CPU"
