## The HAT MUSEUM (SNES ADR-061, render_museum.c): a dark gallery wall,
## a lit case per hat (four to a row), the career player standing in each
## in their saved look, wearing that case's hat. A locked hat is a black
## silhouette; the picked case idles, the others stand still. Under the
## cases, the picked hat's name (WEARING if worn) or "???" and how to earn
## it. Reads a Museum; the title feeds it presses, and the mouse picks a
## case (a click on the picked case wears it).
class_name HatMuseum
extends Control

signal pressed(bits: int)

const WALL := Color(0.09, 0.08, 0.12, 0.97)
const CASE := Color(0.40, 0.42, 0.48)
const PLINTH := Color(0.27, 0.28, 0.33)
const GOLD := Color("fbe46a")
const DIM := Color(0.7, 0.74, 0.85)
const CASE_SIZE := Vector2(190, 120)
const GAP := Vector2(16, 12)
const GRID_AT := Vector2(76, 82)
const SILHOUETTE := 0.06             ## the palette's brightness for a locked hat

var museum: Museum
var manifest: Dictionary
var _cases: Array = []               ## per case: [panel, body, hat]
var _cursor: Control
var _who: BitmapText
var _count: BitmapText
var _name: BitmapText
var _how: BitmapText
var _prompts: PromptBar
var _frame := 0


func setup(m: Museum) -> HatMuseum:
	museum = m
	manifest = MatchView.levels_manifest()
	size = Vector2(960, 540)
	var wall := ColorRect.new()
	wall.color = WALL
	wall.size = size
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	UiKit.panel(Rect2(300, 8, 360, 66), self)
	UiKit.text("big_gold", "HAT MUSEUM", Vector2(480, 18), 0.5, Color.WHITE, self)
	_who = UiKit.text("small", "", Vector2(320, 50), 0.0, GOLD, self)
	_count = UiKit.text("small", "", Vector2(640, 50), 1.0, DIM, self)
	for i in Museum.hats():
		var r := case_rect(i)
		var box := ColorRect.new()
		box.color = CASE
		box.position = r.position
		box.size = r.size
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.gui_input.connect(_on_case_input.bind(i))
		add_child(box)
		var plinth := ColorRect.new()
		plinth.color = PLINTH
		plinth.position = Vector2(0, r.size.y - 10)
		plinth.size = Vector2(r.size.x, 10)
		plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(plinth)
		var sprites := []
		for k in 2:
			var s := Sprite2D.new()
			s.centered = false
			s.region_enabled = true
			s.position = Vector2(r.size.x / 2 - MatchView.ANCHOR.x, 0)
			box.add_child(s)
			sprites.append(s)
		_cases.append([box, sprites[0], sprites[1]])
	_cursor = Control.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.size = CASE_SIZE + Vector2(8, 8)
	_cursor.draw.connect(func():
		var r := Rect2(Vector2.ZERO, _cursor.size)
		_cursor.draw_rect(r, GOLD, false, 3.0))
	add_child(_cursor)
	_name = UiKit.text("small", "", Vector2(480, 470), 0.5, GOLD, self)
	_how = UiKit.text("small", "", Vector2(480, 490), 0.5, DIM, self)
	_prompts = PromptBar.new().setup([], Vector2(480, 520))
	add_child(_prompts)
	return self


func case_rect(i: int) -> Rect2:
	var col := i % Museum.COLS
	var row := i / Museum.COLS
	return Rect2(GRID_AT + Vector2(col * (CASE_SIZE.x + GAP.x), row * (CASE_SIZE.y + GAP.y)), CASE_SIZE)


## Redraws every case for the player (their look may have changed).
func refresh() -> void:
	var p := museum.player()
	var look := PlayerLook.for_career(p, p.shirt, p.variant, p.paddle, manifest)
	var body := look.body_texture(manifest)
	var files: Dictionary = manifest["sprites"]["players"]["roles"]["files"][look.variant]
	var lit := look.material()
	var dark := look.material()
	dark.set_shader_parameter("brighten", SILHOUETTE)
	for i in Museum.hats():
		var name := String(Career.hat_names[Museum.hat(i)]).to_lower()
		var c: Array = _cases[i]
		c[1].texture = body
		c[2].texture = load(MatchView.LEVELS + String(files[name])) if files.has(name) else null
		for k in [1, 2]:
			c[k].material = lit if museum.unlocked(i) else dark
	_who.text = p.shown_name()
	_count.text = "%d OF %d" % [museum.unlocked_count(), Museum.hats()]
	_refresh_cursor()


func _refresh_cursor() -> void:
	var i := museum.cursor
	_cursor.position = case_rect(i).position - Vector2(4, 4)
	_cursor.queue_redraw()
	var h := Museum.hat(i)
	if museum.unlocked(i):
		_name.text = String(Career.hat_names[h]) + ("  WEARING" if museum.player().hat == h else "")
		_how.text = ""
		_prompts.set_items([["hit", "WEAR"], ["back", "BACK"]] if museum.player().hat != h
			else [["back", "BACK"]])
	else:
		_name.text = "???"
		_how.text = Career.unlock_how[Career.hat_unlock[h]]
		_prompts.set_items([["back", "BACK"]])
	museum.changed = false


func _process(_delta: float) -> void:
	if museum == null or not visible:
		return
	if museum.changed:
		refresh()
	_frame += 1
	# the picked case idles; the others stand still
	for i in _cases.size():
		var idle := (_frame / 18) % 2 if i == museum.cursor else 0
		for k in [1, 2]:
			_cases[i][k].region_rect = Rect2(idle * MatchView.FRAME, 4, MatchView.FRAME, 116)


## The mouse: a click picks a case; on the picked case, wears its hat.
func _on_case_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if i == museum.cursor:
			pressed.emit(Practice.PAD_B)
		else:
			museum.cursor = i
			museum.changed = true
