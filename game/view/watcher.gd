## The partner sitting out (ADR-042): in a singles ladder match the
## captain's partner watches from the venue's watcher spot, in their own
## look at crowd size (the top half when sitting: the bench hides the
## legs), facing the court, hopping and cheering when their teammate wins
## a point or the match. Display only.
class_name Watcher
extends Node2D

const SCALE := 0.5               ## about the crowd sprites' size
const HIP := 72                  ## frame row of the hips: a sitting watcher shows the top

var sprites: Array = []          ## [body, hat]
var spot := Vector2.ZERO
var sitting := true
var cheer_frames := 0


## Wanted in singles against a ladder team (not the demo, practice, or
## 2P; doubles has nobody out) at a venue with a watcher spot.
static func wanted(cfg: SimTypes.MatchConfig, demo: bool, manifest: Dictionary, venue: String) -> bool:
	return not demo and cfg.mode == K.MODE_SINGLES and cfg.opponent >= 0 and not cfg.human[2] \
		and not cfg.practice and Opponents.team(cfg.opponent)["players"].size() > 1 \
		and manifest["venues"][venue].has("watcher")


func setup(cfg: SimTypes.MatchConfig, manifest: Dictionary, venue: String, tint: Color) -> Watcher:
	var s: Dictionary = manifest["venues"][venue]["watcher"]
	spot = Vector2(s["x"], s["y"])
	sitting = s["pose"] == "sit"
	var look := PlayerLook.from_member(Opponents.team(cfg.opponent)["players"][1], manifest)
	var mat := look.material()
	for tex in [look.body_texture(manifest), look.hat_texture(manifest)]:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.material = mat
		spr.centered = false
		spr.region_enabled = true
		spr.scale = Vector2(SCALE, SCALE)
		spr.flip_h = spot.x > CourtView.CENTER_X      # facing the court
		spr.modulate = tint
		add_child(spr)
		sprites.append(spr)
	return self


func cheer(frames: int) -> void:
	cheer_frames = maxi(cheer_frames, frames)


func update(sim: Sim) -> void:
	if cheer_frames > 0:
		cheer_frames -= 1
	var winning := sim.phase == K.PHASE_MATCH_RESULT and sim.match_winner == 1
	var up := cheer_frames > 0 or winning
	var frame: int = MatchView.SLOTS.find("cheer") if up else (sim.frame_count / 40) % 2
	var hop := -absf(sin(sim.frame_count * 0.25)) * 7.0 if up else 0.0
	var h: int = HIP if sitting else MatchView.FRAME
	var anchor_y: float = HIP if sitting else MatchView.ANCHOR.y
	for spr in sprites:
		spr.region_rect = Rect2(frame * MatchView.FRAME, 0, MatchView.FRAME, h)
		var ax: float = (MatchView.FRAME - 1 - MatchView.ANCHOR.x) if spr.flip_h else MatchView.ANCHOR.x
		spr.position = (spot - Vector2(ax, anchor_y) * SCALE + Vector2(0, hop)).round()
