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
var _trophy: Node2D                     ## over CHAMPION! (SNES ADR-064)
var _card: Control
var _practice_menu: Control
var _initials: Control           ## the initials card (ADR-040), built when needed
var _ini_letters: Array = []
var _ini_line: BitmapText
var _ini_under: ColorRect
var _result_prompts: PromptBar   ## B / Start on the result screen
var _stats_card: Control         ## the post-match stats (PORT-13), built when shown
var _unlock: Control             ## the UNLOCKED! card (ADR-047), built when needed
var _unlock_line: BitmapText
# PORT-14: scores pop when they change, a ball marks the serving side (and
# a marker the server in doubles), a rally counter on long rallies, and
# MATCH POINT pulses.
const POP_FRAMES := 14
const RALLY_SHOW := 5            ## shots before the rally counter shows
var _prev_scores := [0, 0]
var _score_pop := [0, 0]
var _score_y := 0.0
var _serve_icons: Array = []     ## [left, right] ball icons
var _server_mark: Node2D
var _rally: Control
var _rally_text: BitmapText
var _rally_pop := 0
var _last_rally := 0
var _frame := 0
## Multiplayer (PORT-16): a P1..P4 tag over each human, in their colour.
var _tags: Array = []            ## [slot, Node2D]
var _banner_y := 250.0
var _result_y := 316.0


func _panel(name: String, rect: Rect2) -> NinePatchRect:
	return UiKit.panel(rect, self, name)


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
	if view.multiplayer() and not doubles:
		left_name = _player_name(0)
		right_name = _player_name(2)
	# ADR-047: 1P's side reads the career player's name (the SNES panel
	# fits its first four letters; this one fits all eight).
	if cfg.career_p1 and cfg.career and not view.demo and not cfg.practice:
		left_name = cfg.career.shown_name()
	var left_tint: Color = MatchView.TEAM_TINTS[cfg.palette[0]]
	var right_tint: Color = MatchView.TEAM_TINTS[cfg.palette[2]]
	if cfg.opponent >= 0 and not cfg.human[2] and not view.demo:
		right_tint = Story.team_color(cfg.opponent)
	# Practice (ADR-028): P1 <streak>, the zone (PRACTICE on ANY), BEST <best>.
	var practice: bool = cfg.practice != 0
	if practice:
		right_name = "BEST"
		right_tint = Color("fbe46a")
	# a score panel: the name, then a box wide enough for two digits (and
	# their pop) so a score of 10+ never reaches the name
	var dig := BitmapText.measure("big", "00") + 8
	var lw := 12 + BitmapText.measure("big", left_name) + 14 + dig + 10
	var rw := 12 + BitmapText.measure("big", right_name) + 14 + dig + 10
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
	_left_score = _text("big", "0", Vector2(480 - tw / 2 - 18 - 10 - dig / 2.0, y + 8), 0.5)
	_panel(pan_r, Rect2(480 + tw / 2 + 18, y, rw, h))
	_right_label = _text("big", right_name, Vector2(480 + tw / 2 + 18 + 12, y + 8), 0, right_tint)
	_right_score = _text("big", "0", Vector2(480 + tw / 2 + 18 + rw - 10 - dig / 2.0, y + 8), 0.5)
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
	_score_y = y + 8
	var icon_tex: Texture2D = load(UI + "icon_ball.png")
	for x in [480 - tw / 2 - 18 - lw - 22, 480 + tw / 2 + 18 + rw + 7]:
		var ic := Sprite2D.new()
		ic.texture = icon_tex
		ic.centered = false
		ic.position = Vector2(x, y + 13)
		ic.visible = false
		add_child(ic)
		_serve_icons.append(ic)
	_server_mark = Node2D.new()
	_server_mark.draw.connect(_draw_server_mark)
	_server_mark.visible = false
	add_child(_server_mark)
	_rally = Control.new()
	_rally.visible = false
	add_child(_rally)
	var rp := _panel("sub", Rect2(410, 492, 140, 30))
	rp.reparent(_rally)
	_rally_text = _text("small", "", Vector2(480, 500), 0.5, Color("fbe46a"), _rally)
	if view.multiplayer():
		for slot in K.MAX_PLAYERS:
			if _player_of(slot) >= 0:
				var tag := Node2D.new()
				tag.draw.connect(_draw_tag.bind(tag, _player_of(slot)))
				add_child(tag)
				_tags.append([slot, tag])
	_subtitle = Control.new()
	add_child(_subtitle)
	var sw := 30 + BitmapText.measure("small", "MATCH POINT")
	var sp := _panel("sub", Rect2(480 - sw / 2, y + h - 2, sw, 29))
	sp.reparent(_subtitle)
	_text("small", "MATCH POINT", Vector2(480, y + h + 4), 0.5, Color.WHITE, _subtitle)
	_prompt = Control.new()
	add_child(_prompt)
	var pp := _panel("title", Rect2(282, 488, 396, 38))
	pp.reparent(_prompt)
	# multiplayer is controllers only: the pad's A, whatever was touched last
	_prompt.add_child(PromptBar.new().setup([["pad_a" if view.multiplayer() else "hit",
		"SERVE  HOLD FOR POWER"]], Vector2(480, 507)))
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
	_trophy = Node2D.new()
	_trophy.position = Vector2(480, 214)
	_trophy.draw.connect(_draw_trophy)
	_trophy.visible = false
	add_child(_trophy)
	_banner = _text("big_gold", "", Vector2(480, 250), 0.5)
	_banner_sub = _text("small", "", Vector2(480, 288), 0.5)
	_quip = Control.new()
	add_child(_quip)
	_quip_text = _text("small", "", Vector2(480, 320), 0.5, Color.WHITE, _quip)
	_result_line = _text("small", "", Vector2(480, 316), 0.5)
	if Settings.hud_large:
		# HUD TEXT LARGE (PORT-12): the banners, quips and lines grow
		for t in [_banner, _banner_sub, _quip_text, _result_line]:
			t.scale = Vector2(1.5, 1.5)
		_banner_sub.position.y += 12
		_quip_text.position.y += 22
		_result_line.position.y += 22
	_result_prompts = PromptBar.new().setup([["hit", "REMATCH"], ["start", "MENU"]], Vector2(480, 296))
	_result_prompts.visible = false
	add_child(_result_prompts)
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
	ph += 30
	pause_menu = MenuPage.new().setup("pause", "PAUSED", rows, Rect2(270, 270 - ph / 2, 420, ph),
		[["hit", "SELECT"], ["start", "RESUME"]])
	_paused.add_child(pause_menu)
	if practice:
		_practice_menu = Control.new()
		add_child(_practice_menu)
		var mp := _panel("title", Rect2(380, 488, 200, 38))
		mp.reparent(_practice_menu)
		_practice_menu.add_child(PromptBar.new().setup([["start", "PAUSE"]], Vector2(480, 507)))
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
	_card.add_child(PromptBar.new().setup([["hit", "PLAY"]], Vector2(480, 338)))


func _refresh_initials() -> void:
	var ini: Initials = view.initials
	if not ini.open:
		if _initials:
			_initials.visible = false
		return
	if _initials == null:
		_initials = Control.new()
		add_child(_initials)
		var shade := ColorRect.new()
		shade.color = Color(0, 0.02, 0.08, 0.55)
		shade.size = Vector2(960, 540)
		_initials.add_child(shade)
		var p := _panel("title", Rect2(220, 140, 520, 250))
		p.reparent(_initials)
		var title := _text("big_gold", "NEW RECORD!", Vector2(480, 160), 0.5, Color.WHITE, _initials)
		title.scale = Vector2(1.5, 1.5)
		title.position.x = 480
		_ini_line = _text("small", "", Vector2(480, 214), 0.5, Color("fbe46a"), _initials)
		for i in 3:
			var l := _text("big", "", Vector2(420 + i * 60, 252), 0.5, Color.WHITE, _initials)
			l.scale = Vector2(2, 2)
			l.position.x = 420 + i * 60
			_ini_letters.append(l)
		_ini_under = ColorRect.new()
		_ini_under.size = Vector2(36, 5)
		_ini_under.color = Color("fbe46a")
		_initials.add_child(_ini_under)
		_initials.add_child(PromptBar.new().setup([["dpad", "LETTER"], ["hit", "NEXT"], ["start", "OK"]],
			Vector2(480, 352)))
	_initials.visible = true
	_ini_line.text = ini.records_line()
	var t := ini.text()
	for i in 3:
		_ini_letters[i].text = t[i]
		_ini_letters[i].tint = Color.WHITE if i == ini.cursor else Color(0.7, 0.74, 0.85)
	_ini_under.position = Vector2(402 + ini.cursor * 60, 310)


func close_card() -> void:
	if _card:
		_card.visible = false             # gone this frame, freed after it
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
	_frame += 1
	_refresh_live()
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
	_result_prompts.visible = false
	_refresh_initials()
	_refresh_unlock()
	_refresh_stats()
	if view.initials.open or view.unlock_open():
		_banner.text = ""
		_banner_sub.text = ""
	elif s.phase == K.PHASE_MATCH_RESULT:
		var you: bool = s.match_winner == view.my_team()
		if view.demo:
			_banner.text = "%s WINS" % _team_label(s.match_winner)
			_banner_sub.text = ""
		else:
			var cfg := s.config
			var vs_ladder: bool = cfg.opponent >= 0 and not cfg.human[2]
			_banner.text = "YOU WIN!" if you else "%s WINS" % _team_label(s.match_winner)
			if view.cleared or (view.tournament and view.cup_finish.begins_with("CHAMPION")):
				_banner.text = "CHAMPION!" if not view.cup_finish.begins_with("CHAMPIONS") else "CHAMPIONS!"
			var ready := s.phase_timer >= K.POINT_RESULT_MIN_FRAMES
			var next := "PARK" if view.park else ("NEXT OPPONENT" if (view.ladder and you) else (
				"BRACKET" if view.tournament else "REMATCH"))
			_banner_sub.text = ""
			_result_prompts.visible = ready
			var items := [["hit", next], ["start", "MENU"]]
			if view.net:                     # PORT-31: the host picks; either can leave
				items = [["hit", "REMATCH"], ["start", "LEAVE"]] if view.net.host \
					else [["start", "LEAVE, OR WAIT FOR A REMATCH"]]
			if ready and _result_prompts.items != items:
				_result_prompts.set_items(items)
			if vs_ladder:
				_result_line.text = Story.result_line(cfg.opponent, you)
				_result_line.tint = Story.team_color(cfg.opponent)
				if view.cleared:
					_result_line.text = "LADDER CLEARED!"
					_result_line.tint = Color("fbe46a")
				elif view.tournament and view.cup_finish != "":
					_result_line.text = view.cup_finish + "!" if view.cup_finish.begins_with("CHAMPION") \
						else "OUT AS " + view.cup_finish
					_result_line.tint = Color("fbe46a")
				elif view.ladder and you and view.save:
					_result_line.text += "  NEXT UP: " + String(Opponents.team(
						view.save.ladder(cfg.mode == K.MODE_DOUBLES))["team"])
				elif view.park and view.save and park_line(view.save.career) != "":
					# off the ladder: the park rating's move where NEXT UP goes
					_result_line.text += "  " + park_line(view.save.career)
	elif s.phase == K.PHASE_POINT_RESULT and _point_banner_frames > 0:
		_banner.text = K.fault_word(s.last_fault)
		_banner_sub.text = point_line(s, _team_label(s.point_winner))
	else:
		_banner.text = ""
		_banner_sub.text = ""
	_trophy.visible = _banner.text.begins_with("CHAMPION")


## Under the fault word: who scored, or with SIDE-OUT (port ADR-063) a
## rally the receivers won: SECOND SERVER (doubles, the first server's
## rally) or SIDE OUT.
static func point_line(s: Sim, winner_label: String) -> String:
	if s.point_scored:
		return "%s SCORES" % winner_label
	if s.side_out_doubles() and s.server_number == 1:
		return "SECOND SERVER"
	return "SIDE OUT"


## After a rated park game (SNES ADR-070, hud_scene.c hud_result_rating):
## "PARK POINTS 14 TO 16", or a court it opened, "CLUB COURT OPEN! 16 PTS".
static func park_line(c: Career) -> String:
	if c.park_before == OpenPlay.RATING_NONE:
		return ""
	if c.park_opened != OpenPlay.NONE:
		return "%s COURT OPEN! %d PTS" % [OpenPlay.court_level_name(c.park_opened),
			OpenPlay.rating_points(c.park_after)]
	return "PARK POINTS %d TO %d" % [OpenPlay.rating_points(c.park_before),
		OpenPlay.rating_points(c.park_after)]


## The trophy: a gold cup with handles on a brown base.
func _draw_trophy() -> void:
	var ink := Color(0.07, 0.06, 0.12)
	var gold := Color("f4c430")
	var light := Color("fbe46a")
	var cup := PackedVector2Array([Vector2(-16, -26), Vector2(16, -26), Vector2(13, -10),
		Vector2(6, -3), Vector2(-6, -3), Vector2(-13, -10)])
	for side in [-1.0, 1.0]:
		var from := -PI / 2 if side > 0 else PI / 2
		_trophy.draw_arc(Vector2(side * 15, -18), 7.0, from, from + PI, 10, ink, 5.0)
		_trophy.draw_arc(Vector2(side * 15, -18), 7.0, from, from + PI, 10, gold, 2.5)
	var rim := PackedVector2Array()
	for q in cup:
		rim.append(q * 1.12 + Vector2(0, -1))
	_trophy.draw_colored_polygon(rim, ink)
	_trophy.draw_colored_polygon(cup, gold)
	_trophy.draw_colored_polygon(PackedVector2Array([Vector2(-11, -23), Vector2(-5, -23),
		Vector2(-5, -8), Vector2(-9, -11)]), light)
	_trophy.draw_rect(Rect2(-4, -4, 8, 8), ink)
	_trophy.draw_rect(Rect2(-2.5, -4, 5, 7), gold)
	_trophy.draw_rect(Rect2(-14, 3, 28, 9), ink)
	_trophy.draw_rect(Rect2(-12.5, 4.5, 25, 6), Color("8a5a2c"))


func _player_of(slot: int) -> int:
	return view.slot_players[slot] if slot < view.slot_players.size() else -1


func _player_name(slot: int) -> String:
	var n := _player_of(slot)
	return "P%d" % (n + 1) if n >= 0 else "CPU"


func _draw_tag(n: Node2D, player: int) -> void:
	var col: Color = LobbyScreen.PLAYER_TINTS[player]
	var r := Rect2(-17, -12, 34, 20)
	n.draw_rect(r.grow(2), Color(0.05, 0.06, 0.12))
	n.draw_rect(r, col.darkened(0.35))
	n.draw_colored_polygon(PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, 16)]),
		Color(0.05, 0.06, 0.12))
	var f := BitmapText.load_font("small")
	var text := "P%d" % (player + 1)
	var x := -BitmapText.measure("small", text) / 2.0
	for ch in text:
		var g: Dictionary = f["glyphs"].get(ch, f["glyphs"][" "])
		n.draw_texture_rect_region(f["texture"], Rect2(x, -9, g["w"], g["h"]),
			Rect2(g["x"], g["y"], g["w"], g["h"]))
		x += int(g["advance"]) - 1


## PORT-14's live elements, once a frame.
func _refresh_live() -> void:
	var s := view.sim
	for t in _tags:
		var p: SimTypes.Player = s.players[t[0]]
		var node: Node2D = t[1]
		node.visible = p.active != 0 and s.phase != K.PHASE_MATCH_RESULT
		node.position = (CourtView.ground(p.x_fp, p.y_fp) - Vector2(0, 138) - view.camera.offset).round()
	# MATCH POINT pulses
	var pulse := 0.5 + 0.5 * sin(_frame * 0.18)
	_subtitle.modulate = Color(1, 1, 1, 0.7 + 0.3 * pulse)
	# scores pop on a change
	for t in 2:
		if s.team_score[t] != _prev_scores[t]:
			if s.team_score[t] > _prev_scores[t]:
				_score_pop[t] = POP_FRAMES
			_prev_scores[t] = s.team_score[t]
		var label: BitmapText = _left_score if t == 0 else _right_score
		if _score_pop[t] > 0:
			_score_pop[t] -= 1
		var k := float(_score_pop[t]) / POP_FRAMES
		var sc := 1.0 + 0.2 * k          # stays inside its panel
		label.scale = Vector2(sc, sc)
		label.position.y = _score_y - (sc - 1.0) * 29.0   # bottom fixed: grows up
		label.tint = Color.WHITE.lerp(Color("fbe46a"), k)
	# the serving side, and the server in doubles while they set up
	var serving := s.phase <= K.PHASE_LIVE and not s.config.practice and not s.multi_on
	for t in 2:
		_serve_icons[t].visible = serving and s.serving_team == t
	var mark := not view.demo and s.config.mode == K.MODE_DOUBLES \
		and (s.phase == K.PHASE_SERVE_SETUP or s.phase == K.PHASE_SERVE_TOSS)
	_server_mark.visible = mark
	if mark:
		var p: SimTypes.Player = s.players[s.server_index]
		var head := CourtView.ground(p.x_fp, p.y_fp) - Vector2(0, 116) - view.camera.offset
		_server_mark.position = (head + Vector2(0, -absf(sin(_frame * 0.15)) * 5.0)).round()
		_server_mark.queue_redraw()
	# the rally counter on a long rally, popping on each shot
	var rally: int = (s.shot_serial - s.rally_start) & 0xff
	var live := s.phase == K.PHASE_LIVE and rally >= RALLY_SHOW and not s.config.practice
	_rally.visible = live and not view.demo
	if rally != _last_rally:
		_last_rally = rally
		_rally_pop = 10 if live else 0
	if _rally.visible:
		_rally_text.text = "RALLY %d" % rally
		if _rally_pop > 0:
			_rally_pop -= 1
		var rs := 1.0 + 0.35 * float(_rally_pop) / 10.0
		_rally_text.scale = Vector2(rs, rs)
		_rally_text.position.y = 500.0 - (rs - 1.0) * 8.0


func _draw_server_mark() -> void:
	var s := view.sim
	var col := team_tint(MatchStats.team_of(s.server_index))
	var pts := PackedVector2Array([Vector2(-13, -16), Vector2(13, -16), Vector2(0, 0)])
	_server_mark.draw_colored_polygon(pts, Color(0.05, 0.06, 0.12))
	var inner := PackedVector2Array([Vector2(-9, -13), Vector2(9, -13), Vector2(0, -3)])
	_server_mark.draw_colored_polygon(inner, col)


## The stats card shows on a finished human match's result screen (not
## the demo, practice, or under the initials card); the banner and the
## result line move up over it, the prompts below it.
func stats_shown() -> bool:
	var s := view.sim
	return s.phase == K.PHASE_MATCH_RESULT and not view.demo and not s.config.practice \
		and not view.initials.open and not view.unlock_open()


## The UNLOCKED! card (ADR-047): what the career player just earned
## ("VISOR, PINK HAIR"), over the result like the initials card.
func _refresh_unlock() -> void:
	var open := view.unlock_open()
	if not open:
		if _unlock:
			_unlock.visible = false
		return
	if _unlock == null:
		_unlock = Control.new()
		add_child(_unlock)
		var shade := ColorRect.new()
		shade.color = Color(0, 0.02, 0.08, 0.55)
		shade.size = Vector2(960, 540)
		_unlock.add_child(shade)
		var p := _panel("title", Rect2(180, 150, 600, 220))
		p.reparent(_unlock)
		var title := _text("big_gold", "UNLOCKED!", Vector2(480, 172), 0.5, Color.WHITE, _unlock)
		title.scale = Vector2(1.5, 1.5)
		title.position.x = 480
		_unlock_line = _text("small", "", Vector2(480, 236), 0.5, Color("fbe46a"), _unlock)
		_unlock_line.scale = Vector2(1.25, 1.25)
		_unlock_line.position.x = 480
		var player: Career.Player = view.sim.config.career
		_text("small", "NEW LOOKS FOR %s: CAREER, EDIT" % (player.shown_name() if player else "YOU"),
			Vector2(480, 282), 0.5, Color(0.8, 0.84, 0.95), _unlock)
		_unlock.add_child(PromptBar.new().setup([["hit", "OK"]], Vector2(480, 336)))
	_unlock.visible = true
	# the SNES panel fits 24 letters; this one 30 (past that, "+n")
	_unlock_line.text = Career.unlock_text(view.save.career.new_unlocks if view.save else 0, 30)


func _refresh_stats() -> void:
	var show := stats_shown()
	if show and _stats_card == null:
		_build_stats()
	if _stats_card:
		_stats_card.visible = show
	_banner.position.y = 96.0 if show else _banner_y
	_result_line.position.y = 142.0 if show else _result_y
	_result_prompts.position.y = 486.0 if show else 296.0


func _build_stats() -> void:
	var st: MatchStats = view.stats
	_stats_card = Control.new()
	add_child(_stats_card)
	move_child(_stats_card, 0)       # under the banner and the prompts
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.45)
	shade.size = Vector2(960, 540)
	_stats_card.add_child(shade)
	var p := _panel("title", Rect2(210, 170, 540, 290))
	p.reparent(_stats_card)
	var cols := [545.0, 665.0]
	for t in 2:
		_text("small", _team_label(t), Vector2(cols[t], 188), 0.5, team_tint(t), _stats_card)
	var rows := st.rows()
	for i in rows.size():
		var y := 222.0 + i * 26.0
		_text("small", rows[i][0], Vector2(258, y), 0.0, Color(0.8, 0.84, 0.95), _stats_card)
		for t in 2:
			var won: bool = rows[i][0] == "POINTS" and view.sim.match_winner == t
			_text("small", rows[i][t + 1], Vector2(cols[t], y), 0.5,
				Color("fbe46a") if won else Color.WHITE, _stats_card)
	_text("small", st.rally_line(), Vector2(480, 222.0 + rows.size() * 26.0 + 6), 0.5,
		Color("fbe46a"), _stats_card)


func on_rematch() -> void:
	if _stats_card:
		_stats_card.queue_free()
		_stats_card = null


func _team_label(team: int) -> String:
	var cfg := view.sim.config
	if team == 1 and cfg.opponent >= 0 and not cfg.human[2]:
		return Story.card_name(cfg.opponent, cfg.mode == K.MODE_DOUBLES)
	if view.net:
		# PORT-31: YOU, and the friend by their name
		if team == view.my_team():
			return "YOU"
		var n := String(view.net.peer_hello.get("name", ""))
		return n if n != "" else "FRIEND"
	if view.multiplayer():
		# PORT-29: a side by its players ("P3", "P1 + P4"); a CPU side by colour
		var names := []
		for s in [team * 2, team * 2 + 1]:
			if s < view.slot_players.size() and int(view.slot_players[s]) >= 0:
				names.append("P%d" % (int(view.slot_players[s]) + 1))
		if not names.is_empty():
			return " + ".join(names)
	if cfg.mode == K.MODE_DOUBLES:
		return MatchView.TEAM_NAMES[cfg.palette[team * 2]]
	if team == 0:
		return "CPU" if view.demo else "P1"
	return "2P" if cfg.human[2] else "CPU"
