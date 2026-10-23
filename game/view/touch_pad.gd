## The on-screen pad for touch screens (PORT-81, port ADR-086), drawn as
## a SNES pad: the D-pad on the left, B A Y X on the right (B hit, A
## drive, Y soft, X slice), START, L (SHORT, held) and R (SPECIAL) in the
## top corners, where a SNES pad's shoulders are. A finger presses the input-map action under it, sent
## through Input as an InputEventAction, so the latch, the menus and the
## sim read it like a key; the pad never touches the sim. A finger that
## starts on the D-pad steers until it lifts; one on a button can slide to
## the next. Shown (TOUCH PAD) on AUTO with a touch screen, no pad
## connected and touch the last device used, or always (ON), or never.
## A part with a panel under it (a menu's, a card's) steps aside, so the
## pad never covers a screen's text: menus work by tap (a tap on a value
## cycles it), and the parts left still drive them.
##
## Taps: Godot makes the first finger a mouse too (emulate_mouse_from_touch),
## which is how the menus work by tap. On a button that mouse is swallowed
## here, before the GUI, so a tap on B doesn't also click the row under it.
class_name TouchPad
extends CanvasLayer

const AUTO := 0
const ON := 1
const OFF := 2
const MODES := ["AUTO", "ON", "OFF"]

const DPAD := Vector2(108, 448)
const DPAD_ARM := 56.0            ## the cross's half length
const DPAD_W := 38.0              ## an arm's width
const DPAD_DISC := 68.0           ## the faint disc it sits on
const DPAD_REACH := 90.0          ## a touch this near the centre starts on the D-pad
const DEAD := 12.0                ## this near the centre, no direction
const FACE := Vector2(870, 450)
const FACE_GAP := 44.0            ## the diamond's centre to each button's
const FACE_R := 23.0
const FACE_REACH := 32.0          ## a touch this near a button presses it
## The face buttons by position, as on a SNES pad: B south, A east, Y west,
## X north.
const FACES := {"hit": Vector2(0, 1), "drive": Vector2(1, 0), "soft": Vector2(-1, 0),
	"slice": Vector2(0, -1)}
## START top left, the shoulders under the top corners (the title's
## version line is in the top right).
const PILLS := {"start": Rect2(16, 14, 96, 30), "short": Rect2(16, 54, 96, 30),
	"special": Rect2(848, 54, 96, 30)}
const PILL_REACH := 10.0          ## px around a pill that still press it
const ALPHA := 0.72

var _art := Node2D.new()
var _letters := {}                ## action -> BitmapText
var _fingers := {}                ## touch index -> [target ("dpad" or an action), position]
var _down := {}                   ## actions this pad holds pressed
var _away := {}                   ## parts ("dpad", "faces", a pill's action) stepped aside


## Shown now: TOUCH PAD's setting, the screen and the device in hand.
static func wanted() -> bool:
	match Settings.touch_pad:
		ON:
			return true
		OFF:
			return false
	return DisplayServer.is_touchscreen_available() and GameControls.connected_pads().is_empty() \
		and GameControls.last_device == GameControls.TOUCH


func _ready() -> void:
	layer = 90                        # over the screens and their fades
	_art.modulate.a = ALPHA
	_art.draw.connect(_draw_pad)
	add_child(_art)
	for a in FACES:
		_letters[a] = _letter("big", face_centre(a))
	for a in PILLS:
		var r: Rect2 = PILLS[a]
		_letters[a] = _letter("small", r.get_center())
	for a in _letters:                # the letters the touch prompts show
		_letters[a].text = Prompts.touch_glyph(a)["text"]
	visible = wanted()


func _letter(font: String, at: Vector2) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.align = 0.5
	t.position = Vector2(at.x, at.y - BitmapText.load_font(font)["line_height"] / 2.0)
	_art.add_child(t)
	return t


static func face_centre(action: String) -> Vector2:
	return FACE + FACES[action] * FACE_GAP


## Each part's box on the screen: the D-pad, the faces, each pill.
static func part_rects() -> Dictionary:
	var out := {"dpad": Rect2(DPAD - Vector2.ONE * DPAD_DISC, Vector2.ONE * DPAD_DISC * 2),
		"faces": Rect2(FACE - Vector2.ONE * (FACE_GAP + FACE_R + 2), Vector2.ONE * (FACE_GAP + FACE_R + 2) * 2)}
	for a in PILLS:
		out[a] = PILLS[a]
	return out


## The screen boxes of the shown panels among `nodes`.
static func panel_boxes(nodes: Array) -> Array:
	var out := []
	for n in nodes:
		if n.is_visible_in_tree():
			var xf: Transform2D = n.get_global_transform()
			out.append(Rect2(xf.origin, n.size * xf.get_scale()))
	return out


## Steps the parts with a panel (`boxes`, on the screen) under them aside,
## and brings the rest back.
func avoid(boxes: Array) -> void:
	var away := {}
	var parts := part_rects()
	for k in parts:
		for b in boxes:
			if parts[k].intersects(b):
				away[k] = true
				break
	if away == _away:
		return
	_away = away
	for i in _fingers.keys():           # a finger on a part that left lets go
		if _part_of(_fingers[i][0]) in _away:
			_fingers.erase(i)
	_apply()
	for a in _letters:
		_letters[a].visible = not _part_of(a) in _away


static func _part_of(target: String) -> String:
	return "faces" if FACES.has(target) else target


## What a touch at `p` lands on: "dpad", an action, or "" (nothing, or a
## part stepped aside: it's the mouse's, for the screen under the pad).
func target_at(p: Vector2) -> String:
	if not "dpad" in _away and p.distance_to(DPAD) <= DPAD_REACH:
		return "dpad"
	var best := ""
	var near := FACE_REACH
	for a in FACES if not "faces" in _away else []:
		var d := p.distance_to(face_centre(a))
		if d <= near:
			best = a
			near = d
	if best != "":
		return best
	for a in PILLS:
		if not a in _away and PILLS[a].grow(PILL_REACH).has_point(p):
			return a
	return ""


## The D-pad's directions for a finger `v` from its centre: eight ways,
## 45 degrees each, nothing in the dead centre.
static func dpad_actions(v: Vector2) -> Array:
	var out := []
	if v.length() < DEAD:
		return out
	var lean := tan(PI / 8.0)         # a diagonal within 22.5 degrees of an axis is that axis
	if absf(v.x) > absf(v.y) * lean:
		out.append("move_right" if v.x > 0 else "move_left")
	if absf(v.y) > absf(v.x) * lean:
		out.append("move_down" if v.y > 0 else "move_up")
	return out


func _process(_delta: float) -> void:
	var show := wanted()
	if show != visible:
		visible = show
		if not show:
			release_all()
	if show:
		avoid(panel_boxes(get_tree().get_nodes_in_group(UiKit.PANELS)))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if take_touch(event):
			GameControls.note_device(event)   # handled here, so the input node won't see it
			get_viewport().set_input_as_handled()
	elif swallows(event):
		get_viewport().set_input_as_handled()


## The first finger's mouse (Godot's emulation) on a button, or while that
## finger holds one: not the menus'.
func swallows(event: InputEvent) -> bool:
	if not (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION):
		return false
	return _fingers.has(0) or (event is InputEventMouseButton and target_at(event.position) != "")


## A finger down, moved or up: true if it's the pad's.
func take_touch(event: InputEvent) -> bool:
	var i: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed:
			var t := target_at(event.position)
			if t == "":
				return false
			_fingers[i] = [t, event.position]
		elif not _fingers.erase(i):
			return false
	else:
		if not _fingers.has(i):
			return false
		var f: Array = _fingers[i]
		f[1] = event.position
		if f[0] != "dpad":
			var t := target_at(event.position)
			if t != "" and t != "dpad":
				f[0] = t                 # slid onto the next button
	_apply()
	return true


## Lifts every finger (the pad hid, or a screen changed under it).
func release_all() -> void:
	_fingers.clear()
	_apply()


## Presses what the fingers are on and releases what they left.
func _apply() -> void:
	var want := {}
	for f in _fingers.values():
		if f[0] == "dpad":
			for a in dpad_actions(f[1] - DPAD):
				want[a] = true
		else:
			want[f[0]] = true
	for a in _down:
		if not want.has(a):
			_send(a, false)
	for a in want:
		if not _down.has(a):
			_send(a, true)
	_down = want
	_art.queue_redraw()


## Where the presses go: Input, or a test's stand-in (the test runner has
## no frames, and a press through Input stays "just pressed" for the rest
## of its one frame).
static var sink := Callable()

static func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	if sink.is_valid():
		sink.call(e)
	else:
		Input.parse_input_event(e)


## The actions held down now (tests).
func held() -> Array:
	var out := _down.keys()
	out.sort()
	return out


func _draw_pad() -> void:
	var dark := Color(0.08, 0.09, 0.16)
	var face := Color(0.62, 0.65, 0.76)
	if not "dpad" in _away:
		_draw_dpad(dark, face)
	# B A Y X, each in its SNES colour
	for act in FACES if not "faces" in _away else []:
		var c := face_centre(act)
		var col: Color = Prompts.touch_glyph(act).get("color", face)
		var down := _down.has(act)
		_art.draw_circle(c, FACE_R + 2.0, dark)
		_art.draw_circle(c, FACE_R, col if down else col.darkened(0.45))
		_art.draw_arc(c, FACE_R - 1.0, 0, TAU, 28, col.lightened(0.3) if down else col, 3.0)
	# START, L and R: pills
	for act in PILLS:
		if act in _away:
			continue
		var r: Rect2 = PILLS[act]
		_art.draw_rect(r, Color(0.92, 0.93, 0.98))
		_art.draw_rect(r.grow(-2), Color(0.42, 0.45, 0.6) if _down.has(act) else Color(0.16, 0.18, 0.3))


## The cross on a faint disc, a held arm lit.
func _draw_dpad(dark: Color, face: Color) -> void:
	_art.draw_circle(DPAD, DPAD_DISC, Color(dark, 0.45))
	var a := DPAD_ARM
	var w := DPAD_W / 2.0
	var cross := [Rect2(DPAD.x - w, DPAD.y - a, w * 2, a * 2), Rect2(DPAD.x - a, DPAD.y - w, a * 2, w * 2)]
	for r in cross:
		_art.draw_rect(r.grow(3), dark)
	for r in cross:
		_art.draw_rect(r, face)
	var arms := {"move_up": Vector2(0, -1), "move_down": Vector2(0, 1), "move_left": Vector2(-1, 0),
		"move_right": Vector2(1, 0)}
	for m in arms:
		var c: Vector2 = DPAD + arms[m] * (a - w)
		_art.draw_rect(Rect2(c - Vector2(w, w), Vector2(w, w) * 2).grow(-3),
			Color("fbe46a") if _down.has(m) else face.darkened(0.12))
	_art.draw_circle(DPAD, 9.0, face.darkened(0.3))
