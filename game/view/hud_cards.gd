## The HUD's cards over a match (PORT-42 split them out of hud.gd): the
## ladder intro card, the record initials card (ADR-040), UNLOCKED!
## (ADR-047) and the post-match stats (PORT-13). Built when first needed,
## on the Hud (`h`).
class_name HudCards
extends RefCounted

var h: Hud
var card: Control
var initials: Control
var ini_letters: Array = []
var ini_line: BitmapText
var ini_under: ColorRect
var stats_card: Control
var unlock: Control
var unlock_line: BitmapText


func _init(hud: Hud) -> void:
	h = hud


func build_card(cfg: SimTypes.MatchConfig) -> void:
	var opp := cfg.opponent
	var doubles := cfg.mode == K.MODE_DOUBLES
	card = Control.new()
	h.add_child(card)
	var shade := ColorRect.new()
	shade.color = Color(0, 0.02, 0.08, 0.5)
	shade.size = Vector2(960, 540)
	card.add_child(shade)
	var name := Story.card_name(opp, doubles)
	h._text("big_gold", "", Vector2.ZERO, 0, Color.WHITE, card)
	var title := h._text("big", name, Vector2(480, 170), 0.5, Story.team_color(opp), card)
	title.scale = Vector2(2, 2)
	title.position.x = 480
	var line := Story.intro_line(opp)
	var w := 40 + BitmapText.measure("small", line)
	var p := h._panel("title", Rect2(480 - w / 2, 236, w, 36))
	p.reparent(card)
	h._text("small", line, Vector2(480, 246), 0.5, Color.WHITE, card)
	h._text("small", Story.rung_line(opp), Vector2(480, 296), 0.5, Color("fbe46a"), card)
	card.add_child(PromptBar.new().setup([["hit", "PLAY"]], Vector2(480, 338)))


func refresh_initials() -> void:
	var ini: Initials = h.view.initials
	if not ini.open:
		if initials:
			initials.visible = false
		return
	if initials == null:
		initials = Control.new()
		h.add_child(initials)
		var shade := ColorRect.new()
		shade.color = Color(0, 0.02, 0.08, 0.55)
		shade.size = Vector2(960, 540)
		initials.add_child(shade)
		var p := h._panel("title", Rect2(220, 140, 520, 250))
		p.reparent(initials)
		var title := h._text("big_gold", "NEW RECORD!", Vector2(480, 160), 0.5, Color.WHITE, initials)
		title.scale = Vector2(1.5, 1.5)
		title.position.x = 480
		ini_line = h._text("small", "", Vector2(480, 214), 0.5, Color("fbe46a"), initials)
		for i in 3:
			var l := h._text("big", "", Vector2(420 + i * 60, 252), 0.5, Color.WHITE, initials)
			l.scale = Vector2(2, 2)
			l.position.x = 420 + i * 60
			ini_letters.append(l)
		ini_under = ColorRect.new()
		ini_under.size = Vector2(36, 5)
		ini_under.color = Color("fbe46a")
		initials.add_child(ini_under)
		initials.add_child(PromptBar.new().setup([["dpad", "LETTER"], ["hit", "NEXT"], ["start", "OK"]],
			Vector2(480, 352)))
	initials.visible = true
	ini_line.text = ini.records_line()
	var t := ini.text()
	for i in 3:
		ini_letters[i].text = t[i]
		ini_letters[i].tint = Color.WHITE if i == ini.cursor else Color(0.7, 0.74, 0.85)
	ini_under.position = Vector2(402 + ini.cursor * 60, 310)


func close_card() -> void:
	if card:
		card.visible = false             # gone this frame, freed after it
		card.queue_free()
		card = null


## The UNLOCKED! card (ADR-047): what the career player just earned
## ("VISOR, PINK HAIR"), over the result like the initials card.
func refresh_unlock() -> void:
	var open := h.view.unlock_open()
	if not open:
		if unlock:
			unlock.visible = false
		return
	if unlock == null:
		unlock = Control.new()
		h.add_child(unlock)
		var shade := ColorRect.new()
		shade.color = Color(0, 0.02, 0.08, 0.55)
		shade.size = Vector2(960, 540)
		unlock.add_child(shade)
		var p := h._panel("title", Rect2(180, 150, 600, 220))
		p.reparent(unlock)
		var title := h._text("big_gold", "UNLOCKED!", Vector2(480, 172), 0.5, Color.WHITE, unlock)
		title.scale = Vector2(1.5, 1.5)
		title.position.x = 480
		unlock_line = h._text("small", "", Vector2(480, 236), 0.5, Color("fbe46a"), unlock)
		unlock_line.scale = Vector2(1.25, 1.25)
		unlock_line.position.x = 480
		var player: Career.Player = h.view.sim.config.career
		h._text("small", "NEW LOOKS FOR %s: CAREER, EDIT" % (player.shown_name() if player else "YOU"),
			Vector2(480, 282), 0.5, Color(0.8, 0.84, 0.95), unlock)
		unlock.add_child(PromptBar.new().setup([["hit", "OK"]], Vector2(480, 336)))
	unlock.visible = true
	# the SNES panel fits 24 letters; this one 30 (past that, "+n")
	unlock_line.text = Career.unlock_text(h.view.save.career.new_unlocks if h.view.save else 0, 30)


func refresh_stats() -> void:
	var show := h.stats_shown()
	if show and stats_card == null:
		build_stats()
	if stats_card:
		stats_card.visible = show
	h._banner.position.y = 96.0 if show else h._banner_y
	h._result_line.position.y = 142.0 if show else h._result_y
	h._result_prompts.position.y = 486.0 if show else 296.0


func build_stats() -> void:
	var st: MatchStats = h.view.stats
	stats_card = Control.new()
	h.add_child(stats_card)
	h.move_child(stats_card, 0)       # under the banner and the prompts
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.45)
	shade.size = Vector2(960, 540)
	stats_card.add_child(shade)
	var p := h._panel("title", Rect2(210, 170, 540, 290))
	p.reparent(stats_card)
	var cols := [545.0, 665.0]
	for t in 2:
		h._text("small", h._team_label(t), Vector2(cols[t], 188), 0.5, h.team_tint(t), stats_card)
	var rows := st.rows()
	for i in rows.size():
		var y := 222.0 + i * 26.0
		h._text("small", rows[i][0], Vector2(258, y), 0.0, Color(0.8, 0.84, 0.95), stats_card)
		for t in 2:
			var won: bool = rows[i][0] == "POINTS" and h.view.sim.match_winner == t
			h._text("small", rows[i][t + 1], Vector2(cols[t], y), 0.5,
				Color("fbe46a") if won else Color.WHITE, stats_card)
	h._text("small", st.rally_line(), Vector2(480, 222.0 + rows.size() * 26.0 + 6), 0.5,
		Color("fbe46a"), stats_card)


func on_rematch() -> void:
	if stats_card:
		stats_card.queue_free()
		stats_card = null
