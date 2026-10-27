## The career player beside the CAREER page's card and editor (ADR-047's
## preview): a big idle portrait in their look (skin, hair, shirt, hat,
## paddle), their name, and their unlocks. The SNES stood the title
## demo's P1 at the baseline in the look; here the portrait has its own
## panel so the menu never hides it. Display only.
class_name CareerPreview
extends Control

const AREA := Rect2(70, 96, 290, 352)
const SCALE := 2.0

var manifest: Dictionary
var player: Career.Player
var _sprites: Array = []         # [body, hat]
var _name: BitmapText
var _line: BitmapText
var _frame := 0


func setup() -> CareerPreview:
	manifest = MatchView.levels_manifest()
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UiKit.panel(AREA, self)
	var court := ColorRect.new()
	court.color = Color(0.08, 0.27, 0.29)
	court.position = AREA.position + Vector2(12, 52)
	court.size = Vector2(AREA.size.x - 24, 238)
	court.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(court)
	_name = _text("big_gold", AREA.position + Vector2(AREA.size.x / 2, 16))
	for k in 2:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, MatchView.FRAME, MatchView.FRAME)
		s.scale = Vector2(SCALE, SCALE)
		s.position = Vector2(AREA.get_center().x - MatchView.ANCHOR.x * SCALE,
			AREA.position.y + 280 - MatchView.ANCHOR.y * SCALE)
		add_child(s)
		_sprites.append(s)
	_line = _text("small", AREA.position + Vector2(AREA.size.x / 2, 306))
	_line.tint = Color("fbe46a")
	return self


func _text(font: String, at: Vector2) -> BitmapText:
	return UiKit.text(font, "", at, 0.5, Color.WHITE, self)


## Shows a player (null hides the portrait).
func show_player(p: Career.Player) -> void:
	player = p
	for s in _sprites:
		s.visible = p != null
	if p == null:
		_name.text = ""
		_line.text = ""
		return
	_name.text = p.shown_name() if p.shown_name() != "" else "NEW PLAYER"
	_line.text = "UNLOCKS %d/%d" % [Career.unlock_count(p), Career.unlocks()]
	var look := PlayerLook.for_career(p, p.shirt, p.variant, p.paddle, manifest)
	_sprites[0].texture = look.body_texture(manifest)
	_sprites[1].texture = look.hat_texture(manifest)
	var mat := look.material()
	for s in _sprites:
		s.material = mat


func _process(_delta: float) -> void:
	_frame += 1
	var idle := (_frame / 18) % 2
	for s in _sprites:
		s.region_rect = Rect2(idle * MatchView.FRAME, 0, MatchView.FRAME, MatchView.FRAME)
