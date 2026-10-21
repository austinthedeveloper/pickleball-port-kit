## The multiplayer lobby (PORT-16): four player cards across the screen,
## one per controller. An empty card says PRESS A TO JOIN; a joined card
## shows the player number in their colour, their player as picked, and
## SIDE, SHIRT, BODY, PADDLE with the card's cursor; READY over it when
## set. Above: the mode (LB / RB). Below: who plays on which side (CPUs
## fill doubles) and what the match still waits for. Reads a Lobby.
class_name LobbyScreen
extends Control

const PLAYER_TINTS := [Color("4aa0ff"), Color("ff5a50"), Color("6ad860"), Color("ffd040")]
const CARD_W := 214
const CARD_H := 318
const CARD_Y := 104
const ROW_NAMES := ["SIDE", "SHIRT", "BODY", "PADDLE"]
const DIM := Color(0.7, 0.74, 0.85)
const GOLD := Color("fbe46a")

var lobby: Lobby
var manifest: Dictionary
var _cards: Array = []           ## per card: {root, empty, full, number, body, cap, labels, values, ready, bar}
var _tabs: Array = []            ## the modes, as tabs (PORT-58)
const TAB_GAP := 26
var _teams: BitmapText
var _status: BitmapText
var _frame := 0


func setup(l: Lobby) -> LobbyScreen:
	lobby = l
	manifest = MatchView.levels_manifest()
	var back := ColorRect.new()
	back.color = Color(0.03, 0.06, 0.14, 0.9)
	back.size = Vector2(960, 540)
	add_child(back)
	_panel(Rect2(250, 12, 460, 58))
	var title := _text("big_gold", "MULTIPLAYER", Vector2(480, 22), 0.5, Color.WHITE)
	title.scale = Vector2(1.2, 1.2)
	title.position.x = 480
	# the four modes as tabs, the one on lit; LB / RB step round them
	var x := 480.0 - _tabs_width() / 2.0
	for k in Lobby.MODE_NAMES.size():
		var w := BitmapText.measure("small", Lobby.MODE_NAMES[k])
		_tabs.append(_text("small", Lobby.MODE_NAMES[k], Vector2(x + w / 2.0, 80), 0.5, DIM))
		x += w + TAB_GAP
	add_child(PromptBar.new().setup([["lb", ""]], Vector2(480 - _tabs_width() / 2.0 - 40, 87)))
	add_child(PromptBar.new().setup([["rb", ""]], Vector2(480 + _tabs_width() / 2.0 + 40, 87)))
	for i in Lobby.MAX:
		_cards.append(_build_card(i))
	_panel(Rect2(40, 430, 880, 42))
	_teams = _text("small", "", Vector2(480, 443), 0.5, Color.WHITE)
	_status = _text("small", "", Vector2(480, 482), 0.5, GOLD)
	add_child(PromptBar.new().setup([["pad_a", "JOIN / READY"], ["pad_b", "BACK"], ["pad_menu", "START"]],
		Vector2(480, 516)))
	refresh()
	return self


func _tabs_width() -> float:
	var w := 0.0
	for m in Lobby.MODE_NAMES:
		w += BitmapText.measure("small", m)
	return w + TAB_GAP * (Lobby.MODE_NAMES.size() - 1)


func _panel(r: Rect2) -> NinePatchRect:
	var n := UiKit.panel(r, self)
	return n


func _text(font: String, s: String, at: Vector2, align: float, tint: Color, parent: Node = null) -> BitmapText:
	return UiKit.text(font, s, at, align, tint, parent if parent else self)


func card_x(i: int) -> float:
	return 480.0 - (CARD_W * 4 + 12 * 3) / 2.0 + i * (CARD_W + 12)


func _build_card(i: int) -> Dictionary:
	var x := card_x(i)
	var root := Control.new()
	add_child(root)
	var p := _panel(Rect2(x, CARD_Y, CARD_W, CARD_H))
	p.reparent(root)
	var c := {"root": root}
	var cx := x + CARD_W / 2.0
	c["number"] = _text("big", "P%d" % (i + 1), Vector2(cx, CARD_Y + 12), 0.5, PLAYER_TINTS[i], root)
	var empty := Control.new()
	root.add_child(empty)
	_text("small", "PRESS", Vector2(cx, CARD_Y + 130), 0.5, DIM, empty)
	empty.add_child(PromptBar.new().setup([["pad_a", "TO JOIN"]], Vector2(cx, CARD_Y + 166)))
	c["empty"] = empty
	var full := Control.new()
	root.add_child(full)
	c["full"] = full
	var bar := ColorRect.new()
	bar.color = Color(0.98, 0.86, 0.36, 0.22)
	bar.size = Vector2(CARD_W - 20, 24)
	full.add_child(bar)
	c["bar"] = bar
	for k in 2:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, MatchView.FRAME, MatchView.FRAME)
		s.position = Vector2(cx - MatchView.ANCHOR.x, CARD_Y + 160 - MatchView.ANCHOR.y)
		full.add_child(s)
		c["cap" if k else "body"] = s
	var labels := []
	var values := []
	for r in Lobby.ROWS:
		var y := CARD_Y + 176 + r * 28
		labels.append(_text("small", ROW_NAMES[r], Vector2(x + 16, y), 0.0, DIM, full))
		values.append(_text("small", "", Vector2(x + CARD_W - 16, y), 1.0, GOLD, full))
	c["labels"] = labels
	c["values"] = values
	var band := ColorRect.new()
	band.color = Color(0.02, 0.03, 0.08, 0.7)
	band.position = Vector2(x + 8, CARD_Y + 168)
	band.size = Vector2(CARD_W - 16, Lobby.ROWS * 28 + 8)
	full.add_child(band)
	var ready := _text("big_gold", "READY", Vector2(cx, CARD_Y + 214), 0.5, Color.WHITE, full)
	ready.scale = Vector2(1.4, 1.4)
	ready.position.x = cx
	c["band"] = band
	c["ready"] = ready
	return c


func _process(_delta: float) -> void:
	if not visible:
		return                          # the title builds it hidden
	_frame += 1
	refresh()


func refresh() -> void:
	if lobby == null:
		return
	for k in _tabs.size():
		_tabs[k].tint = GOLD if k == lobby.mode_index() else DIM
	for i in Lobby.MAX:
		var c: Dictionary = _cards[i]
		var card: Variant = lobby.cards[i]
		c["empty"].visible = card == null
		c["full"].visible = card != null
		c["number"].modulate.a = 1.0 if card != null else 0.45
		if card == null:
			continue
		var values: Array = c["values"]
		values[0].text = "LEFT" if card["side"] == Lobby.LEFT else "RIGHT"
		values[1].text = PlayerSelect.COLOUR_NAMES[card["palette"]]
		values[2].text = "MALE" if card["variant"] == K.VARIANT_MALE else "FEMALE"
		values[3].text = PlayerSelect.PADDLE_NAMES[card["paddle"]]
		for r in Lobby.ROWS:
			c["labels"][r].tint = Color.WHITE if r == card["row"] and not card["ready"] else DIM
			# a ready card shows READY in place of its rows
			c["labels"][r].visible = not card["ready"]
			c["values"][r].visible = not card["ready"]
		c["bar"].visible = not card["ready"]
		c["bar"].position = Vector2(card_x(i) + 10, CARD_Y + 171 + card["row"] * 28)
		c["ready"].visible = card["ready"]
		c["band"].visible = card["ready"]
		c["ready"].modulate.a = 0.75 + 0.25 * sin(_frame * 0.12)
		_dress(c, card)
	_teams.text = _teams_line()
	var why := lobby.blocker()
	_status.text = "READY TO START" if why == "" else why   # the prompt bar shows the button
	_status.tint = Color("60e060") if why == "" else GOLD


func _dress(c: Dictionary, card: Dictionary) -> void:
	var idle := (_frame / 20) % 2
	# the sheets and material only when the look changes; the frame each time
	var key := [card["palette"], card["variant"], card["paddle"]]
	var fresh: bool = c.get("dressed") != key
	c["dressed"] = key
	for k in ["body", "cap"]:
		var s: Sprite2D = c[k]
		var cap: bool = k == "cap"
		if not fresh:
			pass
		elif PlayerLook.sheet_has_paddle(card["palette"], card["paddle"]):
			s.material = null
			s.texture = load(MatchView.LEVELS + PlayerLook.team_sheet(
				PlayerLook.variant_name(card["variant"]), PlayerLook.TEAMS[card["palette"]], cap))
		else:
			var look := PlayerLook.for_team(card["palette"], card["variant"], card["paddle"], manifest)
			s.texture = load(MatchView.LEVELS + (look.hat_sheet(manifest) if cap else look.body_sheet(manifest)))
			s.material = look.material()
		s.region_rect = Rect2(idle * MatchView.FRAME, 0, MatchView.FRAME, MatchView.FRAME)
		s.flip_h = card["side"] == Lobby.RIGHT


## "P1 + P3  VS  P2 + CPU" (PORT-58: who plays with whom, plainly)
func _teams_line() -> String:
	var slots := lobby.slot_players()
	var name := func(s: int) -> String:
		if slots[s] >= 0:
			return "P%d" % (slots[s] + 1)
		return "CPU" if lobby.mode == K.MODE_DOUBLES else ""
	if lobby.joined().is_empty():
		return "UP TO FOUR PLAYERS, ONE CONTROLLER EACH"
	if lobby.cup:                        # PORT-29: the cup's entries
		var names: Array = lobby.entries().map(func(e): return e["name"])
		return ("ENTRIES  " if lobby.mode == K.MODE_SINGLES else "TEAMS  ") + "   ".join(names) \
			+ "  + CPU TEAMS"
	if lobby.mode == K.MODE_SINGLES:
		return "%s   VS   %s" % [name.call(0) if slots[0] >= 0 else "-", name.call(2) if slots[2] >= 0 else "-"]
	return "%s + %s   VS   %s + %s" % [name.call(0), name.call(1), name.call(2), name.call(3)]
