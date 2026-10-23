## DINOSAUR's background dinosaurs (ADR-084), drawn with the SNES dinosaur
## game's own sprites (art/sprites/dinos): the Carnotaurus, with Nathan up,
## walks the stands behind the fence, stops to look about and turns back; a
## baby dinosaur patrols the jungle's edge, where a Spinosaurus breathes;
## a pterodactyl crosses the sky behind the volcano. Each sits just in front
## of its backdrop layer (under the next one) and moves with its parallax.
## Display only; deterministic (the sim's frame count), so screenshots and
## replays repeat. The Carnotaurus roars (roar()) when a long rally ends or
## a match is won: his route waits for it. OPEN PLAY's DINO PARK has its own
## cast (PARK_CAST), which ParkView places in its world.
class_name DinoWalkers
extends Node2D

const DIR := "res://assets/dinos/"
const ROAR_RALLY := 10           ## a point after this many shots, or a match won, makes him roar

## Who's in it. `cell` is a frame's size in the strip, `feet` the anchor in a
## cell (feet, or the body's middle for a flyer), `right` whether the art
## faces right. `walk`/`idle` are strips and frames per pose (the sources'
## timings at 60 Hz); a `route` is [x to walk to, frames to stand there],
## looping, at `speed` px a frame along the `y` of the `layer`. One with a
## `roar` strip can be made to roar.
const CAST := [
	{"name": "carnotaurus", "layer": "stands", "y": 162, "speed": 0.5,
		"walk": ["carno_mount_walk.png", [9, 9, 9, 9]], "idle": ["carno_mount_idle.png", [84, 10]],
		"roar": ["carno_mount_roar.png", [12, 11, 10, 30]],
		"cell": Vector2i(144, 96), "feet": Vector2i(70, 90), "right": true,
		"route": [[450, 300], [175, 260], [1090, 420]]},
	{"name": "baby", "layer": "trees", "y": 152, "speed": 0.5, "scale": 2,
		"walk": ["baby_dino_walk.png", [8, 8]], "idle": ["baby_dino_walk.png", [400]],
		"cell": Vector2i(32, 32), "feet": Vector2i(16, 31), "right": true,
		"route": [[300, 150], [210, 220]]},
	{"name": "spinosaurus", "layer": "trees", "y": 152, "speed": 0.0,
		"idle": ["spinosaurus_idle.png", [50, 50]],
		"cell": Vector2i(96, 64), "feet": Vector2i(48, 63), "right": false,
		"route": [[548, 600]]},
	{"name": "pterodactyl", "layer": "sky", "y": 66, "speed": -1.0,
		"walk": ["pterodactyl_flap.png", [10, 10]],
		"cell": Vector2i(32, 32), "feet": Vector2i(16, 16), "right": false,
		"fly": [1080, -60, 1800]},          # from x, to x, every n frames
]

## DINO PARK (ADR-078), in its world's px: the Carnotaurus strolls the
## path's lower edge among the people, the baby patrols the grass below the
## T. rex statue, and the pterodactyl flies over the courts.
const PARK_CAST := [
	{"name": "carnotaurus", "layer": "ground", "y": 744, "speed": 0.5,
		"walk": ["carno_mount_walk.png", [9, 9, 9, 9]], "idle": ["carno_mount_idle.png", [84, 10]],
		"roar": ["carno_mount_roar.png", [12, 11, 10, 30]],
		"cell": Vector2i(144, 96), "feet": Vector2i(70, 90), "right": true,
		"route": [[300, 240], [1700, 300], [2120, 200], [820, 300]]},
	{"name": "baby", "layer": "ground", "y": 560, "speed": 0.5, "scale": 2,
		"walk": ["baby_dino_walk.png", [8, 8]], "idle": ["baby_dino_walk.png", [400]],
		"cell": Vector2i(32, 32), "feet": Vector2i(16, 31), "right": true,
		"route": [[1240, 150], [1100, 220]]},
	{"name": "pterodactyl", "layer": "air", "y": 430, "speed": -1.5, "scale": 2,
		"walk": ["pterodactyl_flap.png", [10, 10]],
		"cell": Vector2i(32, 32), "feet": Vector2i(16, 16), "right": false,
		"fly": [2340, -100, 1800]},
]

## One of the cast: its sprite, its entry, its route's legs, and a roar
## (the frame it began, and the frames the route has waited for roars).
class Dino:
	var spr: Sprite2D
	var c: Dictionary
	var legs: Array
	var parallax := 1.0
	var roar_at := -1
	var held := 0                ## route frames lost to roars before roar_at

	func _init(cast: Dictionary, p := 1.0) -> void:
		c = cast
		spr = DinoWalkers.sprite(c)
		legs = DinoWalkers.plan(c)
		parallax = p

	## Roars from frame `f` (not again until the last one is done).
	func roar(f: int) -> void:
		if not c.has("roar") or roaring(f):
			return
		if roar_at >= 0 and f >= roar_at:
			held += DinoWalkers.total(c["roar"][1])
		roar_at = f

	func roaring(f: int) -> bool:
		return roar_at >= 0 and f >= roar_at and f < roar_at + DinoWalkers.total(c["roar"][1])

	## Poses the sprite at frame `f`; returns where its feet go.
	func dress(f: int) -> Vector2:
		if roaring(f):
			var at := DinoWalkers.dress(spr, c, legs, roar_at - held)
			var cell: Vector2i = c["cell"]
			spr.texture = load(DinoWalkers.DIR + c["roar"][0])
			spr.region_rect = Rect2(DinoWalkers.cycle(c["roar"][1], f - roar_at) * cell.x, 0, cell.x, cell.y)
			return at
		var done := DinoWalkers.total(c["roar"][1]) if roar_at >= 0 and f >= roar_at else 0
		return DinoWalkers.dress(spr, c, legs, f - held - done)


var sim: Sim
var dinos: Array = []            ## [Dino]


## The cast on the DINOSAUR venue, null elsewhere. `layers` maps a backdrop
## layer's name to [its z, its parallax].
static func for_venue(venue: String, s: Sim, layers: Dictionary, tint: Color) -> DinoWalkers:
	if venue != "dinosaur":
		return null
	var w := DinoWalkers.new()
	w.sim = s
	for c: Dictionary in CAST:
		var d := Dino.new(c, float(layers[c["layer"]][1]))
		d.spr.z_index = layers[c["layer"]][0]    # after the layer's own sprite
		d.spr.modulate = tint
		w.add_child(d.spr)
		w.dinos.append(d)
	return w


## The Carnotaurus roars (a long rally's end, a match won).
func roar() -> void:
	for d: Dino in dinos:
		d.roar(sim.frame_count)


## A route as legs [first frame, frames, from x, to x] (a stop has from ==
## to), starting from where the route ends so it loops.
static func plan(c: Dictionary) -> Array:
	var legs := []
	var route: Array = c["route"] if c.has("route") else []
	if route.is_empty():
		return legs
	var x: float = route[-1][0]
	var t := 0
	for stop: Array in route:
		var to := float(stop[0])
		if to != x:
			var n := int(ceil(absf(to - x) / c["speed"]))
			legs.append([t, n, x, to])
			t += n
		legs.append([t, int(stop[1]), to, to])
		t += int(stop[1])
		x = to
	return legs


## Each dinosaur's place and pose this frame; `cam` is the camera's offset.
func update(cam: Vector2) -> void:
	for d: Dino in dinos:
		var at := d.dress(sim.frame_count)
		d.spr.position = (at - cam * d.parallax).round()
		d.spr.visible = at.x > -100.0 and at.x < 1060.0


## A cast member's sprite (its strip and frame come from dress()).
static func sprite(c: Dictionary) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.region_enabled = true
	spr.scale = Vector2.ONE * c.get("scale", 1)
	return spr


## Puts `spr` in its pose at frame `f` (its strip, frame and facing, the
## feet at the origin) and returns where its feet go.
static func dress(spr: Sprite2D, c: Dictionary, legs: Array, f: int) -> Vector2:
	var pose := pose_at(c, legs, f)
	var strip: Array = c[pose[0]]
	var tex: Texture2D = load(DIR + strip[0])
	if spr.texture != tex:
		spr.texture = tex
	var cell: Vector2i = c["cell"]
	spr.region_rect = Rect2(pose[1] * cell.x, 0, cell.x, cell.y)
	var flip: bool = pose[3] != c["right"]
	spr.flip_h = flip
	var feet: Vector2i = c["feet"]
	spr.offset = -Vector2((cell.x - 1 - feet.x) if flip else feet.x, feet.y)
	return pose[2]


## [strip "walk" or "idle", its frame, the feet, facing right] at frame `f`.
static func pose_at(c: Dictionary, legs: Array, f: int) -> Array:
	if c.has("fly"):
		var fly: Array = c["fly"]
		var t := posmod(f, int(fly[2]))
		var x: float = fly[0] + t * float(c["speed"])
		var y: float = c["y"] + sin(t / 50.0) * 8.0
		return ["walk", cycle(c["walk"][1], t), Vector2(x, y), c["speed"] > 0.0]
	var last: Array = legs[-1]
	var t := posmod(f, int(last[0]) + int(last[1]))
	var right := true
	for leg: Array in legs:
		if leg[2] != leg[3]:
			right = leg[3] > leg[2]
		if t < leg[0] + leg[1]:
			var k: int = t - leg[0]
			var y: float = c["y"]
			if leg[2] == leg[3]:
				return ["idle", cycle(c["idle"][1], k), Vector2(leg[2], y), right if c["speed"] > 0.0 else c["right"]]
			var x: float = lerpf(leg[2], leg[3], float(k) / leg[1])
			return ["walk", cycle(c["walk"][1], k), Vector2(x, y), right]
	return ["idle", 0, Vector2(last[2], c["y"]), right]


## A strip's length in frames.
static func total(ticks: Array) -> int:
	var n := 0
	for k: int in ticks:
		n += k
	return n


## The frame of a strip with these durations, `t` frames in.
static func cycle(ticks: Array, t: int) -> int:
	t = posmod(t, total(ticks))
	for i in ticks.size():
		t -= int(ticks[i])
		if t < 0:
			return i
	return 0
