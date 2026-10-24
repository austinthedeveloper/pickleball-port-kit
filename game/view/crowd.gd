## The venue's crowd (art manifest seats): people on the stands who cheer
## on long rallies and points, in turns so the stands ripple. Dimmed with
## the backdrop at night. Display only. A painted venue (ADR-088) has its
## own locals: its manifest entry's "crowd" sheet, in place of the shared one.
class_name Crowd
extends Node2D

var people: Array = []           ## [Sprite2D, person row, seat]
var cheer_frames := 0
var _fw := 0
var _fh := 0


func setup(manifest: Dictionary, venue: String, tint: Color) -> Crowd:
	var meta: Dictionary = manifest["venues"][venue].get("crowd", manifest["sprites"]["crowd"])
	var tex: Texture2D = load(MatchView.LEVELS + meta["file"])
	_fw = meta["frame_size"][0]
	_fh = meta["frame_size"][1]
	for seat in manifest["venues"][venue]["seats"]:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		var row: int = seat["person"]
		s.region_rect = Rect2(0, row * _fh, _fw, _fh)
		var anchor: Array = meta["sit_anchor"] if seat["pose"] == "sit" else meta["stand_anchor"]
		s.position = Vector2(seat["x"] - anchor[0], seat["y"] - anchor[1])
		s.modulate = tint
		add_child(s)
		people.append([s, row, Vector2(seat["x"], seat["y"])])
	return self


func cheer(frames: int) -> void:
	cheer_frames = maxi(cheer_frames, frames)


## Hides whoever sits within `radius` of a spot (the watcher takes it).
func vacate(spot: Vector2, radius := 16.0) -> void:
	for p in people:
		if p[2].distance_to(spot) <= radius:
			p[0].visible = false


func update() -> void:
	if cheer_frames > 0:
		cheer_frames -= 1
	for p in people:
		var up: bool = cheer_frames > 0 and ((cheer_frames / 8 + p[1]) % 2 == 0)
		p[0].region_rect = Rect2(_fw if up else 0, p[1] * _fh, _fw, _fh)
