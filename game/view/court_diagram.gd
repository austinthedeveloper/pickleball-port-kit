## PICKLEBALL 101's court diagram (ADR-070): a real court from above, 20 by
## 44 feet, your side on the left. A page (data/pickleball101.json) says
## what it shows, all in feet (x along the court, 0 your baseline to 44
## theirs; y across, 0 the top sideline to 20):
##   show / bad   zones to light, gold or red (ZONES, or "net")
##   players      [x, y, "you"|"partner"|"them", label]
##   arrows       [x1, y1, x2, y2]: someone moving
##   path         [x, y, flag]: the ball, looping; at each point "h" a hit,
##                "b" a bounce, "v" a volley, "n" off the net, "x" a fault
##   marks        [x, y, "x"|"ok"]
##   labels       [x, y, TEXT]
##   call         a score to call, big over the court ("4 - 2 - 1")
## The node's origin is the court's top-left corner; `ppf` px a foot.
class_name CourtDiagram
extends Node2D

const LENGTH := 44.0
const WIDTH := 20.0
const KITCHEN := 7.0
const SURROUND := 2.5            ## feet of ground drawn past the lines
const BALL_SPEED := 30.0         ## feet a second
const HOLD := 50                 ## frames the finished path stays up

const GROUND := Color("2f6b45")
const COURT := Color("2c5f9e")
const KITCHEN_TINT := Color("3a73b4")
const LINE := Color("f4f1e6")
const GOLD := Color(1.0, 0.86, 0.3)
const RED := Color(1.0, 0.32, 0.26)
const BALL := Color("d8f23e")
const TEAM := {"you": Color("3b82f6"), "partner": Color("7fb2ff"), "them": Color("e5484d")}

const ZONES := {
	"kitchen_near": Rect2(15, 0, 7, 20), "kitchen_far": Rect2(22, 0, 7, 20),
	"service_near_right": Rect2(0, 10, 15, 10), "service_near_left": Rect2(0, 0, 15, 10),
	"service_far_right": Rect2(29, 0, 15, 10), "service_far_left": Rect2(29, 10, 15, 10),
	"deep_far_right": Rect2(37, 0, 7, 10), "box_near_right": Rect2(-2.5, 10, 2.5, 10),
	"half_near": Rect2(0, 0, 22, 20),
}

var ppf := 10.0
var page: Dictionary = {}
var show_labels := true
var frame := 0
var _texts: Array = []


func setup(pixels_per_foot: float, labels := true) -> CourtDiagram:
	ppf = pixels_per_foot
	show_labels = labels
	return self


## Shows a page (or {} for the bare court) and starts its ball over.
func show_page(p: Dictionary) -> void:
	page = p
	frame = 0
	for t in _texts:
		t.free()
	_texts.clear()
	if show_labels:
		for l in p.get("labels", []):
			_text("small", String(l[2]), _at(l[0], l[1]) - Vector2(0, 10), Color(0.92, 0.95, 1.0))
		for pl in p.get("players", []):
			if String(pl[3]) != "":
				_text("small", String(pl[3]), _at(pl[0], pl[1]) + Vector2(0, ppf * 0.9 + 3), Color.WHITE)
	if p.has("call"):
		_text("big_gold", String(p["call"]), _at(22, 10) - Vector2(0, 15), Color.WHITE)
	queue_redraw()


func _text(font: String, s: String, at: Vector2, tint: Color) -> void:
	_texts.append(UiKit.text(font, s, at, 0.5, tint, self))


## Feet to this node's pixels.
func _at(x: float, y: float) -> Vector2:
	return Vector2(x, y) * ppf


func _process(_delta: float) -> void:
	step()


func step() -> void:
	frame += 1
	queue_redraw()


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(frame * 0.12)
	draw_rect(Rect2(_at(-SURROUND, -SURROUND), _at(LENGTH + SURROUND * 2, WIDTH + SURROUND * 2)), GROUND)
	draw_rect(Rect2(_at(0, 0), _at(LENGTH, WIDTH)), COURT)
	draw_rect(Rect2(_at(22 - KITCHEN, 0), _at(KITCHEN * 2, WIDTH)), KITCHEN_TINT)
	for z in page.get("show", []):
		if ZONES.has(z):
			_zone(ZONES[z], GOLD, 0.5 + 0.15 * pulse)
	for z in page.get("bad", []):
		if ZONES.has(z):
			_zone(ZONES[z], RED, 0.5 + 0.15 * pulse)
	_lines()
	var net_hi: bool = "net" in page.get("show", [])
	_net(GOLD.lerp(Color.WHITE, 0.3 * pulse) if net_hi else Color(0.85, 0.87, 0.9), 3.0 if net_hi else 2.0)
	for a in page.get("arrows", []):
		_arrow(_at(a[0], a[1]), _at(a[2], a[3]))
	for pl in page.get("players", []):
		_player(_at(pl[0], pl[1]), String(pl[2]))
	for m in page.get("marks", []):
		_mark(_at(m[0], m[1]), String(m[2]))
	_ball()
	if page.has("call"):
		var c := _at(22, 10)
		draw_rect(Rect2(c - Vector2(110, 26), Vector2(220, 52)), Color(0.04, 0.06, 0.14, 0.86))
		draw_rect(Rect2(c - Vector2(110, 26), Vector2(220, 52)), GOLD, false, 2.0)


func _zone(r: Rect2, c: Color, a: float) -> void:
	var px := Rect2(_at(r.position.x, r.position.y), _at(r.size.x, r.size.y))
	draw_rect(px, Color(c, a))
	draw_rect(px, Color(c, 0.9), false, 2.0)


func _lines() -> void:
	var w := 2.0
	draw_rect(Rect2(_at(0, 0), _at(LENGTH, WIDTH)), LINE, false, w)
	for x in [22 - KITCHEN, 22 + KITCHEN]:
		draw_line(_at(x, 0), _at(x, WIDTH), LINE, w)
	draw_line(_at(0, 10), _at(22 - KITCHEN, 10), LINE, w)
	draw_line(_at(22 + KITCHEN, 10), _at(LENGTH, 10), LINE, w)


func _net(c: Color, w: float) -> void:
	draw_line(_at(22, -1), _at(22, WIDTH + 1), Color(0, 0, 0, 0.35), w + 3)
	draw_line(_at(22, -1), _at(22, WIDTH + 1), c, w)
	for y in [-1.0, WIDTH + 1]:
		draw_circle(_at(22, y), 3.5, Color(0.2, 0.22, 0.26))


func _arrow(a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var c := Color(1, 1, 1, 0.85)
	var dash := 8.0
	var length := a.distance_to(b) - 8
	var s := 0.0
	while s < length:
		draw_line(a + d * s, a + d * minf(s + dash * 0.6, length), c, 2.0)
		s += dash
	draw_colored_polygon(PackedVector2Array([b, b - d * 10 + n * 6, b - d * 10 - n * 6]), c)


func _player(at: Vector2, who: String) -> void:
	var r := maxf(7.0, ppf * 0.8)
	draw_circle(at + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.35))
	draw_circle(at, r, TEAM.get(who, Color.GRAY))
	draw_arc(at, r, 0, TAU, 24, GOLD if who == "you" else Color.WHITE, 2.0 if who == "you" else 1.5)


func _mark(at: Vector2, kind: String) -> void:
	var s := maxf(6.0, ppf * 0.6)
	if kind == "x":
		draw_line(at + Vector2(-s, -s), at + Vector2(s, s), RED, 3.0)
		draw_line(at + Vector2(-s, s), at + Vector2(s, -s), RED, 3.0)
	else:
		draw_polyline(PackedVector2Array([at + Vector2(-s, 0), at + Vector2(-s * 0.3, s * 0.7),
			at + Vector2(s, -s * 0.8)]), Color("4ade80"), 3.0)


## The ball along its path at BALL_SPEED, in flight arcs, leaving a mark
## where each flagged point was reached; then a pause, and again.
func _ball() -> void:
	var path: Array = page.get("path", [])
	if path.size() < 2:
		return
	var lengths := []
	var total := 0.0
	for k in range(1, path.size()):
		var l := Vector2(path[k][0], path[k][1]).distance_to(Vector2(path[k - 1][0], path[k - 1][1]))
		lengths.append(l)
		total += l
	var run := int(ceil(total / BALL_SPEED * 60.0))
	var f := frame % (run + HOLD)
	var gone := minf(total, f / 60.0 * BALL_SPEED)
	# the trail, and the marks of the points passed
	var walked := 0.0
	var pos := _at(path[0][0], path[0][1])
	var height := 0.0
	_flag(pos, String(path[0][2]))
	for k in lengths.size():
		var a := _at(path[k][0], path[k][1])
		var b := _at(path[k + 1][0], path[k + 1][1])
		var l: float = lengths[k]
		var arc := minf(l * 0.1, 2.5) * ppf
		if String(path[k + 1][2]) == "x" and l < 4.0:
			arc = 0.0
		var upto := clampf((gone - walked) / l, 0.0, 1.0) if l > 0.0 else 1.0
		var dots := int(l / 1.2)
		for d in dots:
			var u := float(d) / maxf(dots, 1)
			if u > upto:
				break
			draw_circle(a.lerp(b, u) - Vector2(0, arc * sin(PI * u)), 1.5, Color(BALL, 0.45))
		if upto >= 1.0:
			_flag(b, String(path[k + 1][2]))
			pos = b
			height = 0.0
		elif upto > 0.0 or k == 0:
			pos = a.lerp(b, upto)
			height = arc * sin(PI * upto)
			walked += l
			break
		walked += l
	var r := maxf(4.0, ppf * 0.45)
	draw_circle(pos + Vector2(0, 2), r, Color(0, 0, 0, 0.35))
	draw_circle(pos - Vector2(0, height), r, BALL)
	draw_arc(pos - Vector2(0, height), r, 0, TAU, 16, Color(0.3, 0.35, 0.05), 1.0)


func _flag(at: Vector2, flag: String) -> void:
	match flag:
		"b":
			draw_arc(at, 7.0, 0, TAU, 20, Color(1, 1, 1, 0.9), 2.0)
		"x":
			_mark(at, "x")
		"v":
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8)
				draw_line(at + d * 6, at + d * 11, GOLD, 2.0)
		"n":
			draw_arc(at, 6.0, 0, TAU, 16, GOLD, 2.0)
		"h":
			draw_arc(at, 5.0, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.5)
