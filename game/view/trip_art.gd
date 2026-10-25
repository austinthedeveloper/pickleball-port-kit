## ROAD TRIP's art, by name (port ADR-087, ADR-092): the gear and hazard
## icons (two sheets each: the accepted set, then the second round's), the
## pins, and the backdrops. Art still being made has a stand-in: a
## backdrop that isn't in the game yet falls back to one that is
## (FALLBACK), and the second round's sheets ship as placeholders until
## the art replaces them (art/roadtrip-r5/PROMPTS.md).
class_name TripArt
extends RefCounted

const DIR := "res://assets/trip/"
const ICON := 64
const ICONS_1 := 40              ## cells on trip_gear_icons.png
const ICONS_2 := 64              ## then _2's, then _3's (the partners' bond items)
const HAZARDS_1 := 5             ## cells on trip_hazard_icons.png
const PIN := Vector2(32, 40)
const PINS_1 := 9                ## columns on trip_pins.png; the rest are on _2
## Backdrops still to come, and what stands in for them meanwhile.
const FALLBACK := {"scene_diner": "scene_roadside", "scene_old_court": "scene_roadside",
	"van_interior": "garage", "scrapbook": "garage"}


## A backdrop's texture ("scene_motel", "garage", "van_interior"...), or
## its stand-in while the art is being made.
static func backdrop(name: String) -> Texture2D:
	var path := DIR + "trip_%s.webp" % name
	if not ResourceLoader.exists(path) and FALLBACK.has(name):
		path = DIR + "trip_%s.webp" % String(FALLBACK[name])
	return load(path)


## Whether a backdrop's own art is in (not a stand-in).
static func has_backdrop(name: String) -> bool:
	return ResourceLoader.exists(DIR + "trip_%s.webp" % name)


static func _cell(tex: Texture2D, i: int, cols: int, size: Vector2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2((i % cols) * size.x, (i / cols) * size.y, size.x, size.y)
	return a


## A gear item's 64 x 64 icon (the PLAIN PADDLE has its own picture).
static func gear_icon(id: String) -> Texture2D:
	var icon := int(RoadTrip.gear(id).get("icon", 0))
	if icon < 0:
		return load(DIR + "trip_paddle_plain.png")
	if icon < ICONS_1:
		return _cell(load(DIR + "trip_gear_icons.png"), icon, 8, Vector2(ICON, ICON))
	if icon < ICONS_2:
		return _cell(load(DIR + "trip_gear_icons_2.png"), icon - ICONS_1, 8, Vector2(ICON, ICON))
	return _cell(load(DIR + "trip_gear_icons_3.png"), icon - ICONS_2, 8, Vector2(ICON, ICON))


## A hazard's 64 x 64 icon.
static func hazard_icon(id: String) -> Texture2D:
	var icon := int(RoadTrip.hazard(id).get("icon", 0))
	if icon < HAZARDS_1:
		return _cell(load(DIR + "trip_hazard_icons.png"), icon, HAZARDS_1, Vector2(ICON, ICON))
	return _cell(load(DIR + "trip_hazard_icons_2.png"), icon - HAZARDS_1, 4, Vector2(ICON, ICON))


## A map pin: `index` a column of the pin sheets, `done` the greyed row.
static func pin(index: int, done: bool) -> AtlasTexture:
	var a := AtlasTexture.new()
	var col := index
	if index < PINS_1:
		a.atlas = load(DIR + "trip_pins.png")
	else:
		a.atlas = load(DIR + "trip_pins_2.png")
		col = index - PINS_1
	a.region = Rect2(col * PIN.x, PIN.y if done else 0.0, PIN.x, PIN.y)
	return a


## A Sprite2D of a texture at `scale`, its top left at `at`.
static func sprite(tex: Texture2D, at: Vector2, scale: float, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(scale, scale)
	s.position = at
	parent.add_child(s)
	return s


## A postcard's picture in `rect`: the venue at dusk, or the detour's scene
## (its backdrop, or its venue), scaled down and clipped.
static func postcard_picture(key: String, rect: Rect2) -> Control:
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var world := Node2D.new()
	var k := rect.size.x / 960.0
	world.scale = Vector2(k, k)
	world.position.y = (rect.size.y - 540.0 * k) / 2.0
	clip.add_child(world)
	var venue := ""
	var time := CourtStyle.DUSK
	if key.begins_with("v:"):
		venue = key.substr(2)
	else:
		var d := RoadTrip.detour(key.substr(2))
		var art := String(d.get("art", ""))
		var name := "garage" if art == "garage" else "scene_" + art
		if art != "" and (has_backdrop(name) or not d.has("venue")):
			var s := Sprite2D.new()
			s.texture = backdrop(name)
			s.centered = false
			world.add_child(s)
			return clip
		venue = String(d.get("venue", "park"))
		time = int(d.get("time", CourtStyle.DAY))
	var manifest := MatchView.levels_manifest()
	if not manifest["venues"].has(venue):
		venue = "park"
	var scales := CourtStyle.time_scales(time)
	for layer in manifest["venues"][venue]["layers"]:
		if layer["name"] in ["net"]:
			continue
		var s2 := Sprite2D.new()
		s2.texture = load(MatchView.LEVELS + String(layer["file"]))
		s2.centered = false
		s2.position = Vector2(layer["origin"][0], layer["origin"][1])
		s2.modulate = scales[1] if layer["name"] == "ground" else scales[0]
		world.add_child(s2)
	return clip


## The islands' part of the paper map (600 x 330 at the paper's scale):
## its own art, or the coast's third of the paper tinted to the sea.
static func islands_paper() -> Texture2D:
	var path := DIR + "trip_map_islands.webp"
	if ResourceLoader.exists(path):
		return load(path)
	var a := AtlasTexture.new()
	a.atlas = load(DIR + "trip_map_paper.webp")
	a.region = Rect2(1200, 0, 600, 330)
	return a


static func islands_placeholder() -> bool:
	return not ResourceLoader.exists(DIR + "trip_map_islands.webp")
