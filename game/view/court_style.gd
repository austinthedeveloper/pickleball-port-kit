## Court colours (ADR-022, kitchen ADR-027): presets per part from
## data/court_colors.json, applied to a venue's ground layer by the court
## mask's roles (view/court_style.gdshader). A choice is [surface, kitchen,
## surround, lines] preset indices; 0 is DEFAULT (the venue's paint; for
## the kitchen, SAME as the surface). All DEFAULT draws the painted ground
## untouched. TIME (ADR-045) is DAY, DUSK or NIGHT: the backdrop and the
## surround take the time's dark scales, the court under the floodlights
## its lit scales; players, ball and HUD keep their colours. Display only.
class_name CourtStyle
extends RefCounted

const SHADER := preload("res://view/court_style.gdshader")
const PARTS := ["surface", "kitchen", "surround", "lines"]
const PART_NAMES := ["SURFACE", "KITCHEN", "SURROUND", "LINES"]
const DEFAULTS := [0, 0, 0, 0]
## Mask roles (manifest court_mask_roles) -> part.
const ROLE_PART := {1: "surround", 2: "surround", 3: "surface", 4: "surface",
	5: "kitchen", 6: "kitchen", 7: "lines", 8: "lines"}

static var _data: Dictionary


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/court_colors.json"))
	return _data


## The part's preset names in index order (DEFAULT first; the kitchen's
## list already starts with SAME).
static func names(part: String) -> Array:
	var out := [] if part == "kitchen" else ["DEFAULT"]
	for p in data()["parts"][part]["presets"]:
		out.append(p[0])
	return out


static func count(part: String) -> int:
	return names(part).size()


## A preset's base colour, or null for DEFAULT / SAME (and out of range).
static func preset(part: String, index: int) -> Variant:
	var list: Array = data()["parts"][part]["presets"]
	var i := index if part == "kitchen" else index - 1
	if i < 0 or i >= list.size() or list[i][1] == null:
		return null
	return _rgb8(list[i][1])


## The venue's painted base for a part: the mean of its painted ramp.
static func venue_base(venue: String, part: String, manifest: Dictionary) -> Color:
	var ramp: Array = manifest["venues"][venue]["court_colors"][part]
	var sum := Vector3.ZERO
	for c in ramp:
		sum += Vector3(c[0], c[1], c[2])
	sum /= ramp.size() * 255.0
	return Color(sum.x, sum.y, sum.z)


## part -> target Color, or null where the paint stays.
static func resolve(choice: Array) -> Dictionary:
	var out := {}
	for i in PARTS.size():
		out[PARTS[i]] = preset(PARTS[i], choice[i] if i < choice.size() else 0)
	if out["kitchen"] == null:
		out["kitchen"] = out["surface"]          # SAME
	return out


## The colour a part shows (its target, or the venue's paint).
static func shown(choice: Array, part: String, venue: String, manifest: Dictionary) -> Color:
	var t: Variant = resolve(choice)[part]
	return t if t != null else venue_base(venue, part, manifest)


static func brightness(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## Per role: [target or null, the part's painted base brightness].
static func role_targets(choice: Array, venue: String, manifest: Dictionary) -> Array:
	var r := resolve(choice)
	var out := []
	for role in 9:
		if not ROLE_PART.has(role):
			out.append([null, 1.0])
			continue
		var part: String = ROLE_PART[role]
		out.append([r[part], brightness(venue_base(venue, part, manifest))])
	return out


## The shader's formula on the CPU.
static func recolor(c: Color, role: int, targets: Array) -> Color:
	var t: Variant = targets[role][0]
	if t == null:
		return c
	var k: float = brightness(c) / maxf(targets[role][1], 0.001)
	return Color(clampf(t.r * k, 0, 1), clampf(t.g * k, 0, 1), clampf(t.b * k, 0, 1), c.a)


## The ground layer's material, or null when every part is DEFAULT by day.
static func material(choice: Array, venue: String, manifest: Dictionary, time := 0) -> ShaderMaterial:
	var targets := role_targets(choice, venue, manifest)
	if time == 0 and targets.all(func(t): return t[0] == null):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mask", load("res://assets/levels/" + String(manifest["venues"][venue]["court_mask"])))
	var tv := PackedVector4Array()
	var lums := PackedFloat32Array()
	for t in targets:
		var c: Variant = t[0]
		tv.append(Vector4(c.r, c.g, c.b, 1.0) if c != null else Vector4.ZERO)
		lums.append(t[1])
	mat.set_shader_parameter("target", tv)
	mat.set_shader_parameter("base_lum", lums)
	var sc := time_scales(time)
	mat.set_shader_parameter("dark", Vector3(sc[0].r, sc[0].g, sc[0].b))
	mat.set_shader_parameter("lit", Vector3(sc[1].r, sc[1].g, sc[1].b))
	return mat


# --- Time of day (ADR-045) ---------------------------------------------------------

const DAY := 0
const DUSK := 1
const NIGHT := 2
## Roles at or above this are the court under the lights.
const LIT_ROLE := 3


static func time_names() -> Array:
	return data()["times"]["list"].map(func(t): return t["name"])


## [dark, lit] channel scales as Colors (DAY and out of range: white).
static func time_scales(time: int) -> Array:
	var list: Array = data()["times"]["list"]
	if time <= 0 or time >= list.size():
		return [Color.WHITE, Color.WHITE]
	var t: Dictionary = list[time]
	return [Color(t["dark"][0], t["dark"][1], t["dark"][2]), Color(t["lit"][0], t["lit"][1], t["lit"][2])]


## The venue whose ambience loop plays at this time ("" = the venue's own):
## NIGHT names crickets, SUNSET's loop.
static func time_ambience(time: int) -> String:
	var list: Array = data()["times"]["list"]
	if time <= 0 or time >= list.size() or not list[time].has("ambience"):
		return ""
	var venues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/venues.json"))
	for v in venues["venues"]:
		if v.get("ambience", "") == list[time]["ambience"]:
			return String(v["name"]).to_lower()
	return ""


## A ground part's colour as shown at a time (lit for the court parts).
static func shown_at(choice: Array, part: String, venue: String, manifest: Dictionary, time: int) -> Color:
	var c := shown(choice, part, venue, manifest)
	var sc: Color = time_scales(time)[0 if part == "surround" else 1]
	if part == "lines":
		sc = lines_scale(time)
	return Color(c.r * sc.r, c.g * sc.g, c.b * sc.b)


## The lines catch the floodlights: half the lit dimming. The SNES's 5-bit
## tables round YELLOW on a LIME kitchen at NIGHT to 2.61; the port's float
## scales would leave it at 2.45, under ADR-022's 2.5.
static func lines_scale(time: int) -> Color:
	var lit: Color = time_scales(time)[1]
	return Color((lit.r + 1.0) * 0.5, (lit.g + 1.0) * 0.5, (lit.b + 1.0) * 0.5)


## Shadows over the court (the sprites' colour and alpha).
const SHADOW := Color8(10, 14, 24, 110)
const SHADOW_GREY := Color8(150, 160, 175, 110)
## KNOWN_ISSUES #26's lesson: on a court this dark (BLACK) a dark shadow
## vanishes, so shadows draw grey.
const DARK_COURT_LUM := 0.02

static func grey_shadows(choice: Array, venue: String, manifest: Dictionary, time: int) -> bool:
	return luminance(shown_at(choice, "surface", venue, manifest, time)) < DARK_COURT_LUM


## A shadow's colour over a ground colour (alpha blended).
static func over(ground: Color, shadow: Color) -> Color:
	return ground.lerp(Color(shadow.r, shadow.g, shadow.b), shadow.a)


## WCAG 2 relative luminance and contrast ratio (playbook §4.7).
static func luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _rgb8(v: Array) -> Color:
	return Color8(int(v[0]), int(v[1]), int(v[2]))
