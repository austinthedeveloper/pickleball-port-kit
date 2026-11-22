## The on-screen pad for touch screens (PORT-81, port ADR-086): the D-pad
## on the left; on the right the face buttons weighted as a GameCube pad's
## (port ADR-119): a big B (HIT, the shot most played) with the others
## round it, X (SLICE) and A (DRIVE) as kidneys over and right of it, Y
## (SOFT) small below left; R (SPECIAL, a shot) over the cluster; L
## (SHORT) over the D-pad, a toggle here (a tap turns it on, lit, a tap
## off: holding it would take the thumb off the D-pad); START top left.
## The letters and colours stay the SNES pad's, as the prompts name them.
## A finger presses the input-map action under it, sent through Input as
## an InputEventAction, so the latch, the menus and the sim read it like
## a key; the pad never touches the sim. A finger that starts on the D-pad
## steers until it lifts; one on a button can slide to the next. Shown
## (TOUCH PAD) on AUTO with a touch screen (or a touch seen), no pad
## connected and touch the last device used, or always (ON), or never.
## A part with a panel under it (a menu's, a card's) steps aside, so the
## pad never covers a screen's text: menus work by tap (a tap on a value
## cycles it), and the parts left still drive them.
##
## Upright (PORT-152): the picture keeps its width at the top of the
## screen (Settings.apply_window) and the pad moves into the space under
## it, bigger, the shoulders over the D-pad and the buttons. TOUCH BUTTONS
## WORDS (PORT-151) labels them HIT, DRIVE, SOFT, SLICE, SHORT, SPECIAL
## instead of the SNES pad's letters, on four equal round buttons in a
## diamond (a word doesn't fit a kidney). The constants are the landscape
## layout's; `layout_for()` gives the one in use.
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

const DPAD := Vector2(108, 438)
const DPAD_ARM := 56.0            ## the cross's half length
const DPAD_W := 38.0              ## an arm's width
const DPAD_DISC := 68.0           ## the faint disc it sits on
const DPAD_REACH := 90.0          ## a touch this near the centre starts on the D-pad
const DEAD := 12.0                ## this near the centre, no direction
const FACE := Vector2(846, 424)   ## HIT's centre, the cluster's heart
const RING := 70.0                ## a kidney's arc, round HIT's centre
const KIDNEY_W := 17.0            ## a kidney's half thickness
const FACE_REACH := 12.0          ## a touch this far outside a button still presses it
## The face buttons: round ones by centre (from FACE) and radius, kidneys
## by their arc's ends, in degrees round FACE (0 right, -90 up).
const FACES := {"hit": {"at": Vector2.ZERO, "r": 40.0},
	"soft": {"at": Vector2(-56, 48), "r": 24.0},
	"drive": {"arc": [-60.0, 10.0]},
	"slice": {"arc": [-165.0, -105.0]}}
## The cluster's reach from HIT's centre, left and right.
const CLUSTER_HALF := 87.0
## WORDS: four equal round buttons in a SNES diamond (B south, A east, Y
## west, X north), big enough for a word.
const DIAMOND := {"hit": Vector2(0, 1), "drive": Vector2(1, 0), "soft": Vector2(-1, 0),
	"slice": Vector2(0, -1)}
const DIAMOND_AT := Vector2(830, 410)
const DIAMOND_GAP := 75.0
const DIAMOND_R := 39.0
## START top left (the title's version line is in the top right), L and
## R within a thumb's reach over the D-pad and the faces.
const PILLS := {"start": Rect2(14, 12, 104, 36), "short": Rect2(14, 318, 104, 36),
	"special": Rect2(842, 288, 104, 36)}
const PILL_REACH := 10.0          ## px around a pill that still press it
const ALPHA := 0.72

var _art := Node2D.new()
var _letters := {}                ## action -> BitmapText
var _fingers := {}                ## touch index -> [target ("dpad" or an action), position]
var _down := {}                   ## actions this pad holds pressed
var _away := {}                   ## parts ("dpad", "faces", a pill's action) stepped aside
var _short_on := false            ## L's toggle
## The layout in use (layout_for()): where the D-pad and the buttons are,
## the pills' boxes, and `k`, the size against the landscape pad's.
var dpad_at := DPAD
var face_at := FACE
var pills := PILLS.duplicate()
var k := 1.0
var words := false                ## the WORDS diamond, not the weighted cluster
var face_gap := DIAMOND_GAP       ## WORDS: the diamond's centre to each button's
var face_r := DIAMOND_R           ## WORDS: a button's radius
var _layout_key := ""


## Shown now: TOUCH PAD's setting, the screen and the device in hand.
static func wanted() -> bool:
	match Settings.touch_pad:
		ON:
			return true
		OFF:
			return false
	return (DisplayServer.is_touchscreen_available() or GameControls.touch_seen) \
		and GameControls.connected_pads().is_empty() \
		and GameControls.last_device == GameControls.TOUCH


func _ready() -> void:
	layer = 90                        # over the screens and their fades
	_art.modulate.a = ALPHA
	_art.draw.connect(_draw_pad)
	add_child(_art)
	relayout(Vector2(960, 540))
	visible = wanted()


## The pad's layout for a view of `view` px (the picture's width is
## always 960): landscape, the constants; with room under the picture (an
## upright phone), the pad in that space, scaled up to fill it.
static func layout_for(view: Vector2, use_words := false) -> Dictionary:
	var out := {"dpad": DPAD, "face": DIAMOND_AT if use_words else FACE, "pills": PILLS.duplicate(),
		"k": 1.0, "gap": DIAMOND_GAP, "r": DIAMOND_R}
	if use_words:                       # R clear of the diamond's top
		out["pills"]["special"] = Rect2(842, 244, 104, 36)
	var band := view.y - 540.0
	if band < 260.0:
		return out
	var half := DIAMOND_GAP + DIAMOND_R + 4.0 if use_words else CLUSTER_HALF + 4.0
	var k := clampf(band / 420.0, 1.0, 2.4)
	# the D-pad and the buttons side by side, a gap between them, in 880 px
	k = minf(k, 840.0 / (2.0 * DPAD_DISC + 2.0 * half))
	var cy := 540.0 + band * 0.58
	out["k"] = k
	out["dpad"] = Vector2(40.0 + DPAD_DISC * k, cy)
	out["face"] = Vector2(920.0 - half * k, cy)
	out["gap"] = DIAMOND_GAP * k
	out["r"] = DIAMOND_R * k
	var pw := 96.0 * k
	var ph := 30.0 * k
	var top := 540.0 + band * 0.12
	out["pills"] = {"start": Rect2(480.0 - pw / 2.0, top, pw, ph),
		"short": Rect2(40.0, top, pw, ph), "special": Rect2(920.0 - pw, top, pw, ph)}
	return out


## Lays the pad out for a view of `view` px (again only if it changed).
func relayout(view: Vector2) -> void:
	var key := "%s|%s" % [view, Settings.touch_words]
	if key == _layout_key:
		return
	_layout_key = key
	words = Settings.touch_words
	var l := layout_for(view, words)
	dpad_at = l["dpad"]
	face_at = l["face"]
	pills = l["pills"]
	k = l["k"]
	face_gap = l["gap"]
	face_r = l["r"]
	for a in _letters:
		_letters[a].queue_free()
	_letters.clear()
	for a in FACES:
		_letters[a] = _letter("small" if words else "big", centre_of(a))
	for a in pills:
		var r: Rect2 = pills[a]
		_letters[a] = _letter("small", r.get_center())
	var s := 2.0 if k >= 1.6 else 1.0   # the bitmap fonts at whole sizes only
	for a in _letters:                # the letters the touch prompts show
		var letter: BitmapText = _letters[a]
		letter.text = Prompts.touch_glyph(a)["text"]
		letter.scale = Vector2(s, s)
		var at: Vector2 = centre_of(a) if FACES.has(a) else (pills[a] as Rect2).get_center()
		letter.position = Vector2(at.x, at.y - BitmapText.load_font(letter.font)["line_height"] * s / 2.0)
		letter.visible = not _part_of(a) in _away
	_fingers.clear()
	_apply()


func _letter(font: String, at: Vector2) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.align = 0.5
	t.position = Vector2(at.x, at.y - BitmapText.load_font(font)["line_height"] / 2.0)
	_art.add_child(t)
	return t


## A face button's middle in the landscape cluster: a round one's centre,
## a kidney's arc's middle.
static func face_centre(action: String) -> Vector2:
	return FACE + _offset(action)


static func _offset(action: String) -> Vector2:
	var f: Dictionary = FACES[action]
	if f.has("arc"):
		return Vector2.from_angle(deg_to_rad((f["arc"][0] + f["arc"][1]) / 2.0)) * RING
	return f["at"]


## How far `p` is outside a face button's edge in the landscape cluster
## (negative inside).
static func face_edge(action: String, p: Vector2) -> float:
	return _edge(action, p, FACE, 1.0)


## A face button's edge for a cluster at `at`, `s` times the constants.
static func _edge(action: String, p: Vector2, at: Vector2, s: float) -> float:
	var f: Dictionary = FACES[action]
	if not f.has("arc"):
		return p.distance_to(at + f["at"] * s) - f["r"] * s
	var ang := clampf(rad_to_deg((p - at).angle()), f["arc"][0], f["arc"][1])
	return p.distance_to(at + Vector2.from_angle(deg_to_rad(ang)) * RING * s) - KIDNEY_W * s


## A face button's centre in the layout in use.
func centre_of(action: String) -> Vector2:
	if words:
		return face_at + DIAMOND[action] * face_gap
	return face_at + _offset(action) * k


## How far `p` is outside a face button's edge in the layout in use.
func edge_of(action: String, p: Vector2) -> float:
	if words:
		return p.distance_to(centre_of(action)) - face_r
	return _edge(action, p, face_at, k)


## The cluster's box for a cluster at `at`, `s` times the constants.
static func _faces_box(at: Vector2, s: float) -> Rect2:
	var faces := Rect2(at, Vector2.ZERO)
	for a in FACES:
		var f: Dictionary = FACES[a]
		if f.has("arc"):
			for i in 9:                   # the arc's ends and the points between
				var deg: float = lerpf(f["arc"][0], f["arc"][1], i / 8.0)
				var c := at + Vector2.from_angle(deg_to_rad(deg)) * RING * s
				faces = faces.merge(Rect2(c, Vector2.ZERO).grow(KIDNEY_W * s))
		else:
			faces = faces.merge(Rect2(at + f["at"] * s, Vector2.ZERO).grow(f["r"] * s))
	return faces.grow(2)


## Each part's box on the screen, in the layout in use.
func parts() -> Dictionary:
	var faces := _faces_box(face_at, k)
	if words:
		faces = Rect2(face_at - Vector2.ONE * (face_gap + face_r + 2), Vector2.ONE * (face_gap + face_r + 2) * 2)
	var out := {"dpad": Rect2(dpad_at - Vector2.ONE * DPAD_DISC * k, Vector2.ONE * DPAD_DISC * k * 2),
		"faces": faces}
	for a in pills:
		out[a] = pills[a]
	return out


## Each part's box on the screen: the D-pad, the faces, each pill (landscape).
static func part_rects() -> Dictionary:
	var out := {"dpad": Rect2(DPAD - Vector2.ONE * DPAD_DISC, Vector2.ONE * DPAD_DISC * 2),
		"faces": _faces_box(FACE, 1.0)}
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
	var all := parts()
	for part in all:
		for b in boxes:
			if all[part].intersects(b):
				away[part] = true
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
## `reach`: how far outside a part still counts (a test asks for none:
## what the part covers, and no menu prompts).
func target_at(p: Vector2, reach := -1.0) -> String:
	var exact := reach >= 0.0
	if not "dpad" in _away and p.distance_to(dpad_at) <= (DPAD_DISC * k + reach if exact else DPAD_REACH * k):
		return "dpad"
	var best := ""
	var near := reach if exact else FACE_REACH * k   # the nearest edge wins: no dead gaps
	for a in FACES if not "faces" in _away else []:
		var d := edge_of(a, p)
		if d <= near:
			best = a
			near = d
	if best != "":
		return best
	for a in pills:
		if not a in _away and pills[a].grow(reach if exact else PILL_REACH * k).has_point(p):
			return a
	return "" if exact else prompt_at(p)


## A menu's tappable prompt at `p` (port ADR-117): the action it presses.
func prompt_at(p: Vector2) -> String:
	return PromptBar.tapped_at(p)


## The D-pad's directions for a finger `v` from its centre: eight ways,
## 45 degrees each, nothing in the dead centre.
static func dpad_actions(v: Vector2, scale := 1.0) -> Array:
	var out := []
	if v.length() < DEAD * scale:
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
		relayout(get_viewport().get_visible_rect().size)
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
			if t == "short":
				_short_on = not _short_on
		elif not _fingers.erase(i):
			return false
	else:
		if not _fingers.has(i):
			return false
		var f: Array = _fingers[i]
		f[1] = event.position
		if f[0] != "dpad" and f[0] != "short":
			var t := target_at(event.position)
			if t != "" and t != "dpad" and t != "short":
				f[0] = t                 # slid onto the next button
	_apply()
	return true


## Lifts every finger and L's toggle (the pad hid, or a screen changed
## under it).
func release_all() -> void:
	_fingers.clear()
	_short_on = false
	_apply()


## Presses what the fingers are on and releases what they left.
func _apply() -> void:
	var want := {}
	if _short_on and not "short" in _away:
		want["short"] = true
	for f in _fingers.values():
		if f[0] == "short":
			continue                    # L is its toggle, not the finger
		if f[0] == "dpad":
			for a in dpad_actions(f[1] - dpad_at, k):
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
	# B Y A X, each in its SNES colour: a frame, a rim, the fill lit when held
	for act in FACES if not "faces" in _away else []:
		var col: Color = Prompts.button_glyph(Prompts.TOUCH.get(act, -1), Prompts.SNES).get("color", face)
		var down := _down.has(act)
		_draw_face(act, 2.0, dark)
		_draw_face(act, 0.0, col.lightened(0.3) if down else col)
		_draw_face(act, -3.0 * k, col if down else col.darkened(0.45))
	# START, L and R: pills
	for act in pills:
		if act in _away:
			continue
		var r: Rect2 = pills[act]
		var lit := Color("fbe46a").darkened(0.35) if act == "short" else Color(0.42, 0.45, 0.6)
		_art.draw_rect(r, Color(0.92, 0.93, 0.98))
		_art.draw_rect(r.grow(-2), lit if _down.has(act) else Color(0.16, 0.18, 0.3))


## A face button's shape in the layout in use, grown by `grow` px.
func _draw_face(action: String, grow: float, col: Color) -> void:
	if words:
		_art.draw_circle(centre_of(action), face_r + grow, col)
		return
	var f: Dictionary = FACES[action]
	if not f.has("arc"):
		_art.draw_circle(face_at + f["at"] * k, f["r"] * k + grow, col)
		return
	var w := KIDNEY_W * k + grow
	var ends: Array = f["arc"].map(func(d): return deg_to_rad(d))
	_art.draw_arc(face_at, RING * k, ends[0], ends[1], 24, col, w * 2.0)
	for e in ends:                      # round ends
		_art.draw_circle(face_at + Vector2.from_angle(e) * RING * k, w, col)


## The cross on a faint disc, a held arm lit.
func _draw_dpad(dark: Color, face: Color) -> void:
	_art.draw_circle(dpad_at, DPAD_DISC * k, Color(dark, 0.45))
	var a := DPAD_ARM * k
	var w := DPAD_W / 2.0 * k
	var cross := [Rect2(dpad_at.x - w, dpad_at.y - a, w * 2, a * 2), Rect2(dpad_at.x - a, dpad_at.y - w, a * 2, w * 2)]
	for r in cross:
		_art.draw_rect(r.grow(3), dark)
	for r in cross:
		_art.draw_rect(r, face)
	var arms := {"move_up": Vector2(0, -1), "move_down": Vector2(0, 1), "move_left": Vector2(-1, 0),
		"move_right": Vector2(1, 0)}
	for m in arms:
		var c: Vector2 = dpad_at + arms[m] * (a - w)
		_art.draw_rect(Rect2(c - Vector2(w, w), Vector2(w, w) * 2).grow(-3),
			Color("fbe46a") if _down.has(m) else face.darkened(0.12))
	_art.draw_circle(dpad_at, 9.0 * k, face.darkened(0.3))
