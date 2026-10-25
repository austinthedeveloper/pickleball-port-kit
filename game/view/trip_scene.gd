## A ROAD TRIP scene (port ADR-087): a backdrop (one of the trip's own, or
## a venue at its time of day), you and your partner on the left, a team
## on the right, the words typed in a panel under the speaker's name, as
## STORY's scenes do. A scene can open on a card (a stop's name, the
## opponents, the venue and twist) and end on choices (a detour's, the
## motel's): a MenuPage whose rows are the choices by id. HIT turns the
## page (the first press finishes the typing), START skips to the choices
## or the end. Display only: what a choice does is the trip's.
class_name TripScene
extends Control

signal done(choice: int)         ## the choice's index, or -1 (no choices)

const TYPE_SPEED := 2
const LOCK_FRAMES := 14
const SCALE := 2.0
const FEET_Y := 392.0
const GOLD := Color("fbe46a")
const DIM := Color(0.42, 0.44, 0.52)

var trip: RoadTrip
var pages: Array = []
var page := 0
var shown := 0
var lock := LOCK_FRAMES
var manifest: Dictionary
var cast := {}
var team := -1
var members: Array = []          ## the right side's cast when it isn't a ladder team (the ROAD HOGS)
var choices: Array = []          ## [{"label", "enabled", "value"}]
var choice_page: MenuPage
var _frame := 0
var _bg: Node2D
var _panel: NinePatchRect
var _tag: NinePatchRect
var _tag_text: BitmapText
var _lines: Array = []
var _prompts: PromptBar
var _card: Control
var _card_info: Dictionary = {}
var _sfx: Sfx
var _me_name := "YOU"


## `scene`: pages [{who, lines}] (who: partner, you, captain, mate,
## narrator). `opts`: "art" (a trip backdrop: roadside, motel, yard_sale,
## pro_shop, summer_open, garage, diner, old_court; one still being made
## shows its "venue" instead, or its stand-in) or "venue" and "time";
## "team" (the right side's cast) or "members" (opponents.json members, a
## "who" each: the ROAD HOGS); "card" ({title, lines}: a card first);
## "choices".
func setup(t: RoadTrip, scene: Array, me: PlayerLook, me_name: String, opts: Dictionary = {}) -> TripScene:
	trip = t
	manifest = MatchView.levels_manifest()
	team = int(opts.get("team", -1))
	members = opts.get("members", [])
	_me_name = me_name
	choices = opts.get("choices", [])
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	var art := String(opts.get("art", ""))
	var art_name := "garage" if art == "garage" else "scene_" + art
	if art != "" and (TripArt.has_backdrop(art_name) or not opts.has("venue")):
		_build_art(art_name)
	else:
		_build_venue(String(opts.get("venue", "park")), int(opts.get("time", CourtStyle.DAY)))
	_build_cast(me)
	_build_panel()
	pages = []
	if opts.has("card"):
		_card_info = opts["card"]
		pages.append({"card": true})
	pages.append_array(scene)
	if pages.is_empty():
		pages = [{"who": "narrator", "lines": [""]}]
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_show_page()
	return self


func music_track() -> String:
	return "title"


# --- Building -------------------------------------------------------------------------

func _build_art(art: String) -> void:
	_bg = Node2D.new()
	add_child(_bg)
	var s := Sprite2D.new()
	s.texture = TripArt.backdrop(art)
	s.centered = false
	s.scale = Vector2(1.04, 1.04)
	s.position = Vector2(-20, -10)
	_bg.add_child(s)
	_shade(0.18)


func _build_venue(venue: String, time: int) -> void:
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
	_shade(0.35)


func _shade(a: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, a)
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
	return {"node": node, "sprites": sprites, "x": x}


## Your partner's look and name: Pepper, or the captain partnering you.
static func partner_member(t: RoadTrip) -> Dictionary:
	if t != null and t.partner >= 0 and Opponents.exists(t.partner):
		return Opponents.team(t.partner)["players"][0]
	return StoryMode.partner()


func _build_cast(me: PlayerLook) -> void:
	cast["partner"] = _person(PlayerLook.from_member(partner_member(trip), manifest), 150, false)
	cast["you"] = _person(me, 290, false)
	var right: Array = members
	if team >= 0 and Opponents.exists(team):
		right = Opponents.team(team)["players"]
	if not right.is_empty():
		cast["captain"] = _person(PlayerLook.from_member(right[0], manifest), 690 if right.size() > 1 else 760, true)
		if right.size() > 1:
			cast["mate"] = _person(PlayerLook.from_member(right[1], manifest), 820, true)
	for k in cast:
		var c: Dictionary = cast[k]
		c["node"].position.x += -320.0 if c["x"] < 480 else 320.0    # they walk on


func _build_panel() -> void:
	_panel = UiKit.panel(Rect2(48, 400, 864, 132), self)
	_tag = UiKit.panel(Rect2(70, 366, 200, 36), self, "sub")
	_tag_text = UiKit.text("small", "", Vector2(170, 376), 0.5, Color.WHITE, self)
	for k in 3:
		_lines.append(UiKit.text("small", "", Vector2(84, 420 + k * 26), 0.0, Color.WHITE, self))
	_prompts = PromptBar.new().setup([["hit", "NEXT"], ["start", "SKIP"]], Vector2(740, 508))
	add_child(_prompts)


# --- Pages ----------------------------------------------------------------------------

func who_name(who: String) -> String:
	match who:
		"partner":
			return String(partner_member(trip)["name"])
		"you":
			return _me_name
		"captain":
			if team < 0:
				return String(members[0].get("who", "")) if not members.is_empty() else ""
			return String(Opponents.team(team)["players"][0]["name"])
		"mate":
			if team < 0:
				return String(members[mini(1, members.size() - 1)].get("who", "")) if not members.is_empty() else ""
			var m: Array = Opponents.team(team)["players"]
			return String(m[mini(1, m.size() - 1)]["name"])
	return ""


func _who_tint(who: String) -> Color:
	match who:
		"partner":
			return Color("9be05a")
		"you":
			return Color("6aa0ff")
		"captain", "mate":
			if team < 0 and not members.is_empty():
				return Color("e0605a")       # the ROAD HOGS' maroon, lightened to read
			return Story.team_color(team) if team >= 0 and team < Opponents.count() else Color("ff9a5a")

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
	var who := String(p.get("who", ""))
	var talk: bool = not p.get("card", false)
	_panel.visible = talk
	for l in _lines:
		l.visible = talk
		l.text = ""
	var name := who_name(who)
	_tag.visible = talk and name != ""
	_tag_text.visible = _tag.visible
	_tag_text.text = name
	_tag_text.tint = _who_tint(who)
	if _tag.visible:
		var w := BitmapText.measure("small", name) + 40
		_tag.size.x = w
		_tag_text.position.x = _tag.position.x + w / 2.0
	if p.get("card", false):
		_card = _make_card()
	_prompts.position.y = 508.0 if talk else 500.0


## The stop's card: its name large, then its lines (the opponents, the
## venue and time, the twist, the prize).
func _make_card() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.55)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	if String(_card_info.get("over", "")) != "":
		UiKit.text("small", String(_card_info["over"]), Vector2(480, 140), 0.5, GOLD, c)
	var title := UiKit.text("big_gold", String(_card_info.get("title", "")), Vector2(480, 176), 0.5, Color.WHITE, c)
	title.scale = Vector2(2, 2)
	title.position.x = 480
	var lines: Array = _card_info.get("lines", [])
	for i in lines.size():
		var tint := Color.WHITE if i == 0 else Color(0.85, 0.88, 0.95)
		if String(lines[i]).begins_with("TODAY:") or String(lines[i]).begins_with("HAZARD"):
			tint = Color("ff9a5a")
		UiKit.text("small", String(lines[i]), Vector2(480, 252 + i * 30), 0.5, tint, c)
	return c


func _process(_delta: float) -> void:
	_frame += 1
	var p := _page()
	var text := _text_of(p)
	shown = mini(shown + TYPE_SPEED, text.length())
	var parts := text.substr(0, shown).split("\n")
	for k in _lines.size():
		_lines[k].text = parts[k] if k < parts.size() else ""
	_animate(String(p.get("who", "")))
	if choice_page:
		var nav := choice_page.drive(false, false)
		if nav & MenuPage.NAV_MOVED:
			_beep("blip")
		return
	if lock > 0:
		lock -= 1
		return
	if Input.is_action_just_pressed("start"):
		_finish()
	elif Input.is_action_just_pressed("hit"):
		advance()


## A press: finish the typing, or turn the page; past the last, the
## choices (or the end).
func advance() -> void:
	if choice_page:
		return
	var text := _text_of(_page())
	if shown < text.length():
		shown = text.length()
		return
	if page + 1 >= pages.size():
		_finish()
		return
	page += 1
	_show_page()


func _finish() -> void:
	if choices.is_empty():
		done.emit(-1)
		return
	_open_choices()


func _open_choices() -> void:
	if choice_page:
		return
	page = pages.size() - 1
	shown = _text_of(_page()).length()
	_prompts.visible = false
	var rows := []
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var idx := i
		rows.append({"id": "choice_%d" % i, "label": String(ch["label"]),
			"value": func(): return String(ch.get("value", "")),
			"press": func(): _choose(idx)})
	var h := 24 + rows.size() * MenuPage.ROW_H + 52
	choice_page = MenuPage.new().setup("choices", "", rows, Rect2(150, 36, 660, h),
		[["hit", "CHOOSE"]])
	add_child(choice_page)
	choice_page.pressed.connect(func(_id): pass)


func _choose(i: int) -> void:
	if not choices[i].get("enabled", true):
		_beep("back")
		return
	_beep("confirm")
	done.emit(i)


## Picks a choice by id, as a test does (the row's press).
func choose(id: String) -> void:
	_open_choices()
	choice_page.select(id)
	choice_page.press()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and lock == 0 and choice_page == null:
		advance()


func _animate(who: String) -> void:
	_bg.position.x = sin(_frame / 240.0) * 10.0 - 10.0
	for k in cast:
		var c: Dictionary = cast[k]
		var n: Node2D = c["node"]
		n.visible = not _page().get("card", false)
		if n.visible:
			n.position.x = lerpf(n.position.x, c["x"], 0.12)
		var speaking: bool = k == who
		if who in ["partner", "you", "captain", "mate"]:
			n.modulate = Color.WHITE if speaking else DIM
		else:
			n.modulate = Color(0.82, 0.83, 0.88)
		n.position.y = FEET_Y - (absf(sin(_frame * 0.25)) * 6.0 if speaking else 0.0)
		var idle := (_frame / 22) % 2
		for s: Sprite2D in c["sprites"]:
			s.region_rect = Rect2(idle * MatchView.FRAME, 0, MatchView.FRAME, MatchView.FRAME)


## A sound, once the screen is up (a screen opened by a test or tool may not be).
func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)
