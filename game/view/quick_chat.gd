## Online quick chat (port ADR-111, PORT-122): eight friendly lines
## (OnlineSession.CHAT), no keyboard or microphone needed. Between points
## (a fault, a point's or the match's result), SHORT held opens the picker:
## up and down pick a line, HIT says it, letting go closes it. The pads
## don't reach the match while it's open (MatchInput.net_intents). A line
## shows in a bubble over its player for BUBBLE_FRAMES; CHAT MUTED (on
## ONLINE) hides everyone's but yours. One line in 3 s (the session's).
## Display only: chat travels beside the inputs, never in them.
class_name QuickChat
extends Node2D

const BUBBLE_FRAMES := 150
const ABOVE := Vector2(0, -150)  ## a bubble over the feet
const PICKER := Rect2(290, 100, 380, 18 + 8 * MenuPage.ROW_H + 50)

var view: MatchView
var page: MenuPage
var bubbles := {}                ## slot -> [frames left, panel, text]
var said := []                   ## lines shown: [slot, line], for tests


func setup(v: MatchView) -> QuickChat:
	view = v
	var rows := []
	for i in OnlineSession.CHAT.size():
		rows.append({"id": "c%d" % i, "label": OnlineSession.CHAT[i], "press": _say.bind(i)})
	page = MenuPage.new().setup("chat", "", rows, PICKER, [["hit", "SAY IT"], ["short", "LET GO"]])
	page.visible = false
	add_child(page)
	return self


## Between points: the only time a line can go.
static func between_points(s: Sim) -> bool:
	return s.phase == K.PHASE_POINT_RESULT or s.phase == K.PHASE_SERVE_FAULT \
		or s.phase == K.PHASE_MATCH_RESULT


func picking() -> bool:
	return page.visible


func can_pick() -> bool:
	return view.net != null and not view.net.watcher and not view.net.my_slots.is_empty() \
		and between_points(view.sim) and view.net.state == OnlineSession.PLAYING


## A frame: the picker (SHORT held), then the lines heard.
func update() -> void:
	var want := can_pick() and Input.is_action_pressed("short")
	if want and not page.visible:
		page.select("c0")
		page.appear()
		GameControls.clear_latch()
	page.visible = want
	if page.visible:
		page.drive(false, false, true)
	for c in view.net.take_chats():
		show_line(int(c[0]), int(c[1]))
	for slot in bubbles.keys():
		var b: Array = bubbles[slot]
		b[0] = int(b[0]) - 1
		if int(b[0]) <= 0:
			(b[1] as Node).queue_free()
			(b[2] as Node).queue_free()
			bubbles.erase(slot)
		else:
			_place(int(slot), b)


func _say(line: int) -> void:
	if view.net.say(line):
		page.visible = false
		GameControls.clear_latch()


## A line over its player (yours always; others' unless CHAT MUTED).
func show_line(slot: int, line: int) -> void:
	var mine: bool = slot in view.net.my_slots
	if Settings.mute_chat and not mine:
		return
	if line < 0 or line >= OnlineSession.CHAT.size() or slot < 0 or slot >= K.MAX_PLAYERS:
		return
	if bubbles.has(slot):
		(bubbles[slot][1] as Node).queue_free()
		(bubbles[slot][2] as Node).queue_free()
	var words := String(OnlineSession.CHAT[line])
	var w := BitmapText.measure("small", words) + 28
	var panel := UiKit.panel(Rect2(0, 0, w, 34), self)
	var text := UiKit.text("small", words, Vector2.ZERO, 0.5, Color.WHITE, self)
	var b := [BUBBLE_FRAMES, panel, text]
	bubbles[slot] = b
	said.append([slot, line])
	_place(slot, b)


## A bubble over its player's head, kept on the screen.
func _place(slot: int, b: Array) -> void:
	var root: Node2D = view._players[slot]["root"]
	var at := root.position + view._actors.position + ABOVE
	var panel: Control = b[1]
	var x := clampf(at.x - panel.size.x / 2, 8, 952 - panel.size.x)
	var y := clampf(at.y, 60, 440)
	panel.position = Vector2(x, y).round()
	(b[2] as Node2D).position = Vector2(x + panel.size.x / 2, y + 9).round()
