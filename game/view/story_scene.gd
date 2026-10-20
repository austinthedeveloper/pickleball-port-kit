## A story scene (port ADR-069): the chapter's venue behind, the cast large
## (you and Pepper on the left, the chapter's team on the right; the one
## speaking lit and bobbing, the rest dimmed), and the words typed out in a
## panel under their name. Grimsby is only ever text (bible 5.2): his lines
## come over the park's loudspeaker, his letters on Grimsby Parking Co.
## letterhead. A chapter opens on its title card; a win can show the
## petition filling up. HIT (or a click) turns the page (the first press
## finishes the typing), Start skips the rest. Display only.
class_name StoryScene
extends Control

signal done(skipped: bool)

const TYPE_SPEED := 2            ## characters a frame
const LOCK_FRAMES := 14          ## input ignored as a scene or page opens
const SCALE := 2.0               ## the cast, over the match's size
const FEET_Y := 392.0
const GOLD := Color("fbe46a")
const PAPER := Color("efe6cc")
const INK := Color("2a2230")
const LETTERHEAD := Color("8c2a2a")
const DIM := Color(0.42, 0.44, 0.52)

var save: SaveGame
var chapter := 0
var pages: Array = []            ## [{who, lines, petition?}] or {"card": ...}
var page := 0
var shown := 0                   ## characters typed on this page
var lock := LOCK_FRAMES
var manifest: Dictionary
var cast := {}                   ## who -> {"node", "sprites", "x", "flip"}
var _frame := 0
var _bg: Node2D
var _panel: NinePatchRect
var _tag: NinePatchRect
var _tag_text: BitmapText
var _lines: Array = []
var _prompts: PromptBar
var _card: Control               ## the chapter card, THE END, or the petition
var _note: Control               ## a Grimsby Parking Co. letter
var _speaker: Node2D             ## the loudspeaker over Grimsby's lines
var _team: Dictionary


## `kind`: "intro" (the chapter's card and scene), "win", "lose", "ending"
## (the ending, THE END and the epilogue). `me`: your look.
func setup(s: SaveGame, ch: int, kind: String, me: PlayerLook) -> StoryScene:
	save = s
	chapter = ch
	manifest = MatchView.levels_manifest()
	_team = Opponents.team(int(StoryMode.chapter(ch)["team"]))
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build_backdrop(StoryMode.venue(ch) if kind != "ending" else "park",
		StoryMode.time(ch) if kind != "ending" else CourtStyle.DAY)
	_build_cast(me, kind)
	_build_panel()
	pages = _pages(kind)
	_show_page()
	return self


func _pages(kind: String) -> Array:
	var c := StoryMode.chapter(chapter)
	match kind:
		"intro":
			return [{"card": "chapter"}] + c["scene"]
		"win":
			return c["win"]
		"lose":
			return [c["lose"]]
		"ending":
			return StoryMode.data()["ending"] + [{"card": "end"}] + StoryMode.data()["epilogue"]
	return []


# --- Building -------------------------------------------------------------------------

## The venue's layers as a still, tinted for the time of day, under a
## shade that darkens toward the panel.
func _build_backdrop(venue: String, time: int) -> void:
	_bg = Node2D.new()
	add_child(_bg)
	var scales := CourtStyle.time_scales(time)
	for layer in manifest["venues"][venue]["layers"]:
		if layer["name"] in ["front", "net"]:
			continue
		var s := Sprite2D.new()
		s.texture = load(MatchView.LEVELS + String(layer["file"]))
		s.centered = false
		s.position = Vector2(layer["origin"][0], layer["origin"][1])
		s.modulate = scales[1] if layer["name"] == "ground" else scales[0]
		_bg.add_child(s)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.35)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _person(look: PlayerLook, x: float, flip: bool) -> Dictionary:
	var node := Node2D.new()
	node.position = Vector2(x, FEET_Y)
	add_child(node)
	var sprites := []
	var mat := look.material()
	for sheet in [look.body_sheet(manifest), look.hat_sheet(manifest)]:
		var s := Sprite2D.new()
		s.texture = load(MatchView.LEVELS + sheet) if sheet != "" else null
		s.material = mat
		s.centered = false
		s.region_enabled = true
		s.scale = Vector2(SCALE, SCALE)
		s.flip_h = flip
		s.offset = -Vector2((MatchView.FRAME - 1 - MatchView.ANCHOR.x) if flip else MatchView.ANCHOR.x,
			MatchView.ANCHOR.y)
		node.add_child(s)
		sprites.append(s)
	return {"node": node, "sprites": sprites, "x": x, "flip": flip}


## You and Pepper on the left, the chapter's team on the right (the
## ending: the whole park's two heroes, cheering).
func _build_cast(me: PlayerLook, kind: String) -> void:
	var members: Array = _team["players"]
	cast["partner"] = _person(PlayerLook.from_member(StoryMode.partner(), manifest), 150, false)
	cast["you"] = _person(me, 290, false)
	if kind != "ending":
		cast["captain"] = _person(PlayerLook.from_member(members[0], manifest), 690, true)
		cast["mate"] = _person(PlayerLook.from_member(members[mini(1, members.size() - 1)], manifest), 820, true)
	for k in cast:
		var c: Dictionary = cast[k]
		c["node"].position.x += -320.0 if c["x"] < 480 else 320.0    # they walk on
	_speaker = Node2D.new()
	_speaker.position = Vector2(500, 96)
	_speaker.draw.connect(_draw_speaker)
	_speaker.visible = false
	add_child(_speaker)


func _build_panel() -> void:
	_panel = UiKit.panel(Rect2(48, 400, 864, 132), self)
	_tag = UiKit.panel(Rect2(70, 366, 200, 36), self, "sub")
	_tag_text = UiKit.text("small", "", Vector2(170, 376), 0.5, Color.WHITE, self)
	for k in StoryMode.LINES_MAX:
		_lines.append(UiKit.text("small", "", Vector2(84, 420 + k * 26), 0.0, Color.WHITE, self))
	_prompts = PromptBar.new().setup([["hit", "NEXT"], ["start", "SKIP"]], Vector2(740, 508))
	add_child(_prompts)


# --- Pages ----------------------------------------------------------------------------

func _who_name(who: String) -> String:
	match who:
		"partner":
			return String(StoryMode.partner()["name"])
		"captain":
			return String(_team["players"][0]["name"])
		"mate":
			var m: Array = _team["players"]
			return String(m[mini(1, m.size() - 1)]["name"])
		"villain":
			return StoryMode.villain()
	return ""


func _who_tint(who: String) -> Color:
	match who:
		"partner":
			return Color("9be05a")
		"captain", "mate":
			return Story.team_color(int(StoryMode.chapter(chapter)["team"]))
		"villain":
			return Color("ff6a5a")
	return Color.WHITE


func _page() -> Dictionary:
	return pages[page]


func _text_of(p: Dictionary) -> String:
	return "\n".join(p.get("lines", []))


func _show_page() -> void:
	lock = LOCK_FRAMES
	shown = 0
	var p := _page()
	if _card:
		_card.free()
		_card = null
	if _note:
		_note.free()
		_note = null
	var who := String(p.get("who", ""))
	var card := String(p.get("card", ""))
	var talk := card == "" and who != "note"
	_panel.visible = talk
	for l in _lines:
		l.visible = talk
		l.text = ""
	var name := _who_name(who)
	_tag.visible = talk and name != ""
	_tag_text.visible = _tag.visible
	_tag_text.text = name
	_tag_text.tint = _who_tint(who)
	if _tag.visible:
		var w := BitmapText.measure("small", name) + 40
		_tag.size.x = w
		_tag_text.position.x = _tag.position.x + w / 2.0
	_speaker.visible = who == "villain"
	if card == "chapter":
		_card = _chapter_card()
	elif card == "end":
		_card = _end_card()
	elif who == "note":
		_note = _letter(p)
	elif p.get("petition", false):
		_card = _petition()
	_prompts.position.y = 508.0 if talk else 500.0


## CHAPTER 3 / MUSCLE FOR HIRE / the venue and its twist / the petition.
func _chapter_card() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.55)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	UiKit.text("small", "CHAPTER %d OF %d" % [chapter + 1, StoryMode.CHAPTERS], Vector2(480, 150), 0.5, GOLD, c)
	var title := UiKit.text("big_gold", String(StoryMode.chapter(chapter)["title"]), Vector2(480, 186), 0.5,
		Color.WHITE, c)
	title.scale = Vector2(2, 2)
	title.position.x = 480
	var where: String = Settings.VENUE_NAMES[Settings.VENUES.find(StoryMode.venue(chapter))]
	if StoryMode.time(chapter) != CourtStyle.DAY:
		where += "  " + CourtStyle.time_names()[StoryMode.time(chapter)]
	UiKit.text("small", where + "  VS " + String(_team["team"]), Vector2(480, 262), 0.5, Color.WHITE, c)
	var twist := StoryMode.twist_label(chapter)
	if twist != "":
		UiKit.text("small", twist, Vector2(480, 290), 0.5, Color("ff9a5a"), c)
	UiKit.text("small", "PETITION %d/%d" % [chapter, StoryMode.CHAPTERS], Vector2(480, 330), 0.5, DIM, c)
	return c


func _end_card() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.6)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	var t := UiKit.text("big_gold", "THE END", Vector2(480, 200), 0.5, Color.WHITE, c)
	t.scale = Vector2(2.5, 2.5)
	t.position.x = 480
	UiKit.text("small", "THE PARK IS SAVED. PARKS SAVED: %d" % StoryMode.cleared(save), Vector2(480, 300), 0.5,
		GOLD, c)
	return c


## A letter on Grimsby Parking Co. letterhead.
func _letter(p: Dictionary) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.position = Vector2(180, 120)
	paper.size = Vector2(600, 260)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(paper)
	var band := ColorRect.new()
	band.color = LETTERHEAD
	band.position = paper.position
	band.size = Vector2(600, 46)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(band)
	UiKit.text("big", StoryMode.company(), Vector2(480, 130), 0.5, Color(1, 0.92, 0.86), c)
	var lines: Array = p["lines"]
	for k in lines.size():
		var l := UiKit.text("small", "", Vector2(480, 210 + k * 30), 0.5, INK, c)
		_lines[k].visible = false
		c.set_meta("line%d" % k, l)
	c.set_meta("count", lines.size())
	return c


## The petition: every team's name, the ones signed so far ticked (this
## win's included).
func _petition() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.position = Vector2(330, 34)
	paper.size = Vector2(300, 330)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(paper)
	UiKit.text("small", "SAVE THE PARK", Vector2(480, 46), 0.5, LETTERHEAD, c)
	for t in StoryMode.CHAPTERS:
		var signed := t <= chapter
		var team := String(Opponents.team(int(StoryMode.chapter(t)["team"]))["team"])
		UiKit.text("small", ("+ " if signed else "  ") + team, Vector2(360, 82 + t * 34), 0.0,
			INK if signed else Color(0.55, 0.52, 0.48), c)
	return c


# --- Frames ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	var p := _page()
	var who := String(p.get("who", ""))
	var text := _text_of(p)
	shown = mini(shown + TYPE_SPEED, text.length())
	_type(p, text.substr(0, shown))
	_animate(who)
	if lock > 0:
		lock -= 1
		return
	if Input.is_action_just_pressed("start"):
		done.emit(true)
	elif Input.is_action_just_pressed("hit"):
		advance()


## A press: finish the typing, or turn the page; the last page ends it.
func advance() -> void:
	var text := _text_of(_page())
	if shown < text.length():
		shown = text.length()
		return
	if page + 1 >= pages.size():
		done.emit(false)
		return
	page += 1
	_show_page()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and lock == 0:
		advance()


func _type(p: Dictionary, typed: String) -> void:
	var parts := typed.split("\n")
	if _note:
		for k in int(_note.get_meta("count")):
			var l: BitmapText = _note.get_meta("line%d" % k)
			l.text = parts[k] if k < parts.size() else ""
		return
	for k in _lines.size():
		_lines[k].text = parts[k] if k < parts.size() else ""


## The cast walks on, then stands; the speaker is lit and bobs, the rest
## dimmed; the backdrop drifts.
func _animate(who: String) -> void:
	_bg.position.x = sin(_frame / 240.0) * 10.0 - 10.0
	for k in cast:
		var c: Dictionary = cast[k]
		var n: Node2D = c["node"]
		# the chapter card stands alone; the cast walks on after it
		n.visible = String(_page().get("card", "")) != "chapter"
		if n.visible:
			n.position.x = lerpf(n.position.x, c["x"], 0.12)
		var speaking: bool = k == who
		# a character's line lights them and dims the rest; narration,
		# Grimsby and the cards leave everyone a little in shadow
		if who in ["partner", "captain", "mate"]:
			n.modulate = Color.WHITE if speaking else DIM
		else:
			n.modulate = Color(0.82, 0.83, 0.88)
		n.position.y = FEET_Y - (absf(sin(_frame * 0.25)) * 6.0 if speaking else 0.0)
		var idle := (_frame / 22) % 2
		for s: Sprite2D in c["sprites"]:
			s.region_rect = Rect2(idle * MatchView.FRAME, 0, MatchView.FRAME, MatchView.FRAME)
	if _speaker.visible:
		_speaker.queue_redraw()


## The park's loudspeaker on its pole, its sound waves pulsing: Grimsby.
func _draw_speaker() -> void:
	var ink := Color(0.07, 0.06, 0.12)
	_speaker.draw_rect(Rect2(-3, -100, 6, 92), ink)
	var horn := PackedVector2Array([Vector2(-8, -10), Vector2(-8, 10), Vector2(-40, 26), Vector2(-40, -26)])
	var rim := PackedVector2Array()
	for q in horn:
		rim.append(q * 1.12)
	_speaker.draw_colored_polygon(rim, ink)
	_speaker.draw_colored_polygon(horn, Color(0.75, 0.76, 0.8))
	_speaker.draw_rect(Rect2(-10, -12, 14, 24), Color(0.5, 0.52, 0.58))
	for k in 3:
		var a := 0.3 + 0.7 * fposmod(_frame / 30.0 - k * 0.33, 1.0)
		_speaker.draw_arc(Vector2(-44, 0), 10.0 + k * 9.0, PI * 0.7, PI * 1.3, 8, Color(1, 0.4, 0.35, 1.0 - a), 3.0)
