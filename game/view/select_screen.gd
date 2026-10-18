## Player Select (ADR-020), after the select concept: the big portrait of
## your player and the four colour thumbnails on the left, the paddles and
## their POWER / CONTROL / SPEED bars on the right. Reads a PlayerSelect;
## the title feeds it presses (1P's pad, or 2P's while 2P chooses).
class_name SelectScreen
extends Control

const DIM := Color(0.7, 0.74, 0.85)
const GOLD := Color("fbe46a")
const LEFT := Rect2(40, 92, 540, 372)
const RIGHT := Rect2(596, 92, 324, 372)
const THUMB_W := 126
const PADDLE_W := 72
const SEG := 5                   ## bar segments (ADR-020: stats 0..5)

var sel: PlayerSelect
var manifest: Dictionary
var _pals: Dictionary
var _portrait: Array = []        # [body, cap]
var _thumbs: Array = []          # per colour: [body, cap, label, box]
var _variant: BitmapText
var _variant_label: BitmapText
var _colour_label: BitmapText
var _paddle_label: BitmapText
var _paddle_name: BitmapText
var _who: BitmapText
var _bars: Array = []            # per stat: [label, segs...]
var _arrow: Sprite2D
var _frame := 0
var _overlay: Control           ## the paddles and the cursor brackets, over the panels
## ADR-047: the active career player (null: none). 1P's portrait and
## thumbnails take their skin, hair and hat, and 1P's bars their hat's gear.
var career: Career.Player


func setup(s: PlayerSelect) -> SelectScreen:
	sel = s
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MatchView.LEVELS + "manifest.json"))
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	_pals = JSON.parse_string(FileAccess.get_file_as_string(MatchView.LEVELS + String(roles["palettes"])))
	var back := ColorRect.new()
	back.color = Color(0.04, 0.16, 0.18, 0.88)
	back.size = Vector2(960, 540)
	add_child(back)
	_panel(Rect2(250, 14, 460, 62))
	var title := _text("big_gold", "PLAYER SELECT", Vector2(480, 30), 0.5, Color.WHITE)
	title.scale = Vector2(1.25, 1.25)
	title.position.x = 480
	_panel(LEFT)
	var court := ColorRect.new()
	court.color = Color(0.08, 0.27, 0.29)
	court.position = LEFT.position + Vector2(12, 12)
	court.size = Vector2(LEFT.size.x - 24, 222)
	add_child(court)
	_who = _text("small", "", LEFT.position + Vector2(24, 22), 0.0, GOLD)
	_variant_label = _text("small", "BODY", LEFT.position + Vector2(LEFT.size.x - 210, 22), 0.0, DIM)
	_variant = _text("small", "", LEFT.position + Vector2(LEFT.size.x - 24, 22), 1.0, GOLD)
	for k in 2:
		var spr := _sprite()
		spr.scale = Vector2(2, 2)
		spr.position = Vector2(LEFT.get_center().x - 56 * 2, LEFT.position.y + 236 - 116 * 2)
		_portrait.append(spr)
	_colour_label = _text("small", "SHIRT", LEFT.position + Vector2(24, 244), 0.0, DIM)
	for c in PlayerSelect.PAL_COUNT:
		var x := LEFT.position.x + 18 + c * (THUMB_W + 4)
		var box := _panel(Rect2(x, LEFT.position.y + 264, THUMB_W, 96))
		var body := _sprite()
		var cap := _sprite()
		for spr in [body, cap]:
			spr.scale = Vector2(0.62, 0.62)
			spr.position = Vector2(x + THUMB_W / 2.0 - 56 * 0.62, LEFT.position.y + 330 - 116 * 0.62)
			_set_sheet(spr, c, K.VARIANT_MALE, spr == cap)
		var label := _text("small", PlayerSelect.COLOUR_NAMES[c], Vector2(x + THUMB_W / 2.0, LEFT.position.y + 338), 0.5, Color.WHITE)
		_thumbs.append([body, cap, label, box])
	_panel(RIGHT)
	_panel(Rect2(RIGHT.position.x + 14, RIGHT.position.y + 14, RIGHT.size.x - 28, 50))
	_paddle_label = _text("big", "PADDLE", Vector2(RIGHT.get_center().x, RIGHT.position.y + 26), 0.5, Color.WHITE)
	_paddle_name = _text("small", "", Vector2(RIGHT.get_center().x, RIGHT.position.y + 200), 0.5, GOLD)
	var stats := ["POWER", "CONTROL", "SPEED"]
	for i in stats.size():
		var y := RIGHT.position.y + 236 + i * 40
		_panel(Rect2(RIGHT.position.x + 14, y - 8, RIGHT.size.x - 28, 34))
		var row := [_text("small", stats[i], Vector2(RIGHT.position.x + 30, y), 0.0, Color.WHITE)]
		for k in SEG:
			var seg := ColorRect.new()
			seg.position = Vector2(RIGHT.position.x + 150 + k * 28, y + 1)
			seg.size = Vector2(24, 14)
			add_child(seg)
			row.append(seg)
		_bars.append(row)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_panel(Rect2(40, 476, 880, 50))
	add_child(PromptBar.new().setup([["dpad", "CHOOSE"], ["hit", "CONFIRM"], ["start", "PLAY"],
		["back", "BACK"]], Vector2(480, 501)))
	_arrow = Sprite2D.new()
	_arrow.texture = load("res://assets/levels/ui/icon_ball.png")
	_arrow.centered = false
	add_child(_arrow)
	refresh()
	return self


func _panel(r: Rect2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load("res://assets/levels/ui/panel_title.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		n.set(m, 12)
	n.position = r.position
	n.size = r.size
	add_child(n)
	return n


func _text(font: String, s: String, at: Vector2, align: float, tint: Color) -> BitmapText:
	var t := BitmapText.new()
	t.font = font
	t.text = s
	t.align = align
	t.position = at
	t.tint = tint
	add_child(t)
	return t


func _sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, MatchView.FRAME, MatchView.FRAME)
	add_child(s)
	return s


## A team-colour sheet, or the role sheet in the team's colours with the
## chosen paddle (PlayerLook.for_team), so the paddle shows in hand.
func _set_sheet(spr: Sprite2D, team: int, variant: int, cap: bool, paddle := -1) -> void:
	var v := "female" if variant == K.VARIANT_FEMALE else "male"
	if paddle < 0 or PlayerLook.sheet_has_paddle(team, paddle):
		spr.material = null
		spr.texture = load(MatchView.LEVELS + "sprites/players/player_%s_%s%s.png" % [
			v, PlayerLook.TEAMS[team], "_cap" if cap else ""])
		return
	var look := PlayerLook.for_team(team, variant, paddle, manifest)
	spr.texture = load(MatchView.LEVELS + (look.hat_sheet(manifest) if cap else look.body_sheet(manifest)))
	spr.material = look.material()


## The career player's look in a colour and paddle on a sprite (the body
## sheet, or the hat's; bareheaded, the hat sprite is empty).
func _set_career(spr: Sprite2D, team: int, variant: int, cap: bool, paddle: int) -> void:
	var look := PlayerLook.for_career(career, team, variant, paddle, manifest)
	var file := look.hat_sheet(manifest) if cap else look.body_sheet(manifest)
	spr.texture = load(MatchView.LEVELS + file) if file != "" else null
	spr.material = look.material()


func _career_shown() -> bool:
	return career != null and sel.current == 0


func _process(_delta: float) -> void:
	_frame += 1
	var idle := (_frame / 18) % 2
	for s in _portrait:
		s.region_rect = Rect2(idle * MatchView.FRAME, 0, MatchView.FRAME, MatchView.FRAME)
	if sel and sel.changed:
		refresh()
	_overlay.queue_redraw()


func refresh() -> void:
	if sel == null or sel.choice.is_empty():
		return
	sel.changed = false
	var c: Dictionary = sel.current_choice()
	_who.text = "%dP SELECT" % (sel.current + 1)
	if _career_shown():
		_who.text = "1P  " + career.shown_name()
	_variant.text = "MALE" if c["variant"] == K.VARIANT_MALE else "FEMALE"
	if _career_shown():
		_set_career(_portrait[0], c["palette"], c["variant"], false, c["paddle"])
		_set_career(_portrait[1], c["palette"], c["variant"], true, c["paddle"])
	else:
		_set_sheet(_portrait[0], c["palette"], c["variant"], false, c["paddle"])
		_set_sheet(_portrait[1], c["palette"], c["variant"], true, c["paddle"])
	for i in _thumbs.size():
		var t: Array = _thumbs[i]
		var taken := sel.colour_taken(i)
		if _career_shown():
			_set_career(t[0], i, c["variant"], false, c["paddle"])
			_set_career(t[1], i, c["variant"], true, c["paddle"])
		else:
			_set_sheet(t[0], i, c["variant"], false)
			_set_sheet(t[1], i, c["variant"], true)
		t[2].text = "1P" if taken else PlayerSelect.COLOUR_NAMES[i]
		var picked: bool = c["palette"] == i
		t[2].tint = GOLD if picked else (DIM if taken else Color.WHITE)
		for spr in [t[0], t[1]]:
			spr.modulate = Color(1, 1, 1, 0.35) if taken else Color.WHITE
	# ADR-047 stage 4: 1P's bars with their career hat's gear.
	var stats: Array = Paddles.stats(Paddles.profile(c["paddle"], career.hat)) \
		if _career_shown() else Paddles.STATS[c["paddle"]]
	for i in _bars.size():
		for k in SEG:
			_bars[i][k + 1].color = GOLD if k < stats[i] else Color(0.12, 0.14, 0.28)
	_paddle_name.text = PlayerSelect.PADDLE_NAMES[c["paddle"]]
	_variant_label.tint = Color.WHITE if sel.row == PlayerSelect.ROW_VARIANT else DIM
	_colour_label.tint = Color.WHITE if sel.row == PlayerSelect.ROW_COLOUR else DIM
	_paddle_label.tint = Color.WHITE if sel.row == PlayerSelect.ROW_PADDLE else DIM
	var arrow_at := [_variant_label.position, _colour_label.position,
		Vector2(RIGHT.position.x + 24, RIGHT.position.y + 26)]
	_arrow.position = arrow_at[sel.row] - Vector2(18, 0)


func _paddle_rect(i: int) -> Rect2:
	return Rect2(RIGHT.position.x + 18 + i * (PADDLE_W + 4), RIGHT.position.y + 76, PADDLE_W, 112)


## The paddles, drawn in their palettes.json colours (the art has no
## paddle icons): a rounded face with an edge guard, and a wrapped grip.
func _draw_overlay() -> void:
	if sel == null or sel.choice.is_empty():
		return
	var c: Dictionary = sel.current_choice()
	for i in Paddles.NAMES.size():
		var r := _paddle_rect(i)
		var pal: Dictionary = _pals["paddles"][Paddles.NAMES[i]]
		_overlay.draw_rect(r, Color(0.07, 0.2, 0.24))
		var face := Rect2(r.position.x + 14, r.position.y + 10, r.size.x - 28, 62)
		var edge := Color8(pal["e"][0], pal["e"][1], pal["e"][2])
		var fill := Color8(pal["P"][0], pal["P"][1], pal["P"][2])
		var shine := Color8(pal["f"][0], pal["f"][1], pal["f"][2])
		_overlay.draw_rect(face.grow(3), edge)
		_overlay.draw_rect(face, fill)
		_overlay.draw_rect(Rect2(face.position + Vector2(5, 5), Vector2(6, face.size.y - 18)), shine)
		var grip := Rect2(r.get_center().x - 5, face.end.y + 3, 10, 30)
		_overlay.draw_rect(grip, Color8(pal["G"][0], pal["G"][1], pal["G"][2]))
		for k in 3:
			_overlay.draw_rect(Rect2(grip.position + Vector2(0, 6 + k * 8), Vector2(10, 2)), edge)
		if i == c["paddle"]:
			_brackets(r, GOLD if sel.row == PlayerSelect.ROW_PADDLE else DIM)
	var t: Array = _thumbs[c["palette"]]
	var box: NinePatchRect = t[3]
	_brackets(Rect2(box.position, box.size), GOLD if sel.row == PlayerSelect.ROW_COLOUR else DIM)


func _brackets(r: Rect2, col: Color) -> void:
	var l := 14.0
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		_overlay.draw_line(p, p + Vector2(l * d.x, 0), col, 4)
		_overlay.draw_line(p, p + Vector2(0, l * d.y), col, 4)
