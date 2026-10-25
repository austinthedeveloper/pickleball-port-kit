## The pause menu's OPTIONS (port ADR-090): the title's OPTIONS pages
## (view/options_pages.gd) over a paused match, the same rows, the same
## sub-pages. The match waits while it's open, as under TUNE (ADR-074).
## Closing saves the settings and applies the ones a match set up with
## (CAMERA, HUD TEXT); the rest already apply as they change.
class_name OptionsPanel
extends CanvasLayer

var view: MatchView
var open := false
var pages := {}                  ## id -> MenuPage
var page := ""                   ## the open page ("padmap": MAP BUTTONS)
var listening := ""              ## CONTROLS: the action waiting for a key
var pad_mapper := PadMapper.new()
var pad_map_screen: PadMapScreen
var _sfx: Sfx:                    ## the match's (rebuilt with it)
	get: return view._sfx
var _parents := {}               ## page -> [the page it was opened from, its row]
var _lock := 0
var _shade: ColorRect


func setup(v: MatchView) -> OptionsPanel:
	view = v
	layer = 20                       # over the HUD and its pause menu
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.6)
	_shade.size = Vector2(960, 540)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	OptionsPages.build(self)
	pad_map_screen = PadMapScreen.new().setup(pad_mapper)
	pad_map_screen.visible = false
	add_child(pad_map_screen)
	visible = false
	return self


## A page, as the title's _add_page builds it: a BACK row, the lite
## build's rows left out, tall enough for its rows.
func _add_page(id: String, title: String, rows: Array, help: Array,
		at := Rect2(300, 172, 360, 0)) -> void:
	if Settings.lite:
		rows = rows.filter(func(r): return not String(r["id"]) in TitleScreen.LITE_HIDDEN)
	rows.append({"id": "back", "label": "BACK", "press": back})
	var h := 18 + rows.size() * MenuPage.ROW_H + (52 if not help.is_empty() else 12) + 46
	at.size.y = h if id == "pad" else maxi(h, 300)
	var p := MenuPage.new().setup(id, title, rows, at, help)
	p.pressed.connect(func(row): if row != "back": _sfx.play("confirm"))
	p.changed.connect(func(_row): _sfx.play("blip"))
	p.hovered.connect(func(_row): _sfx.play("blip"))
	p.back_requested.connect(back)
	p.visible = false
	add_child(p)
	pages[id] = p


func open_panel() -> void:
	open = true
	visible = true
	_parents.clear()
	view._hud.visible = false
	_show("options")
	pages["options"].cursor = 0
	pages["options"].appear(1)
	_sfx.play("confirm")
	swallow()


func close() -> void:
	open = false
	visible = false
	listening = ""
	view._hud.visible = true
	_sfx.play("back")
	view.camera.percent = Settings.CAMERAS[Settings.camera_i]
	view._hud.apply_text_size()
	_save_settings()
	# the closing press never reaches the pause menu (rule 9)
	view.input_lock = MatchView.INPUT_LOCK_FRAMES
	GameControls.clear_latch()


func _show(id: String) -> void:
	page = id
	for k in pages:
		pages[k].visible = k == id
	pad_map_screen.visible = id == "padmap"
	if pages.has(id):
		pages[id].refresh()


func open_page(id: String) -> void:
	if not pages.has(id):
		return
	if pages.has(page) and page != id:
		_parents[id] = [page, pages[page].current_id()]
	_show(id)
	pages[id].appear(1)
	swallow()


## BACK, or Y: the page it was opened from; OPTIONS' closes the panel.
func back() -> void:
	if page == "options":
		close()
		return
	var to: Array = _parents.get(page, ["options", page])
	back_to(to[0], to[1])
	_sfx.play("back")


func back_to(to: String, row := "", _sound := false) -> void:
	_show(to)
	if row != "":
		pages[to].select(row)
	pages[to].appear(-1)
	swallow()


func listen(action: String) -> void:
	listening = action
	pages["controls"].refresh()


func open_pad_map() -> void:
	OptionsPages.open_pad_map(self)


func swallow() -> void:
	_lock = TitleScreen.SWITCH_LOCK
	GameControls.clear_latch()


func _store_settings() -> void:
	if view.save:
		Settings.store_to(view.save)


func _save_settings() -> void:
	if view.save:
		Settings.store_to(view.save)
		view.save.save_game()


## One frame while open (the match waits): the keys and pads on the page.
func update() -> void:
	if _lock > 0:
		_lock -= 1
		return
	if listening != "" or page == "padmap" or not pages.has(page):
		return
	var p: MenuPage = pages[page]
	var nav := p.drive()
	if nav & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
		_sfx.play("blip")
	if nav & MenuPage.NAV_BACK:
		back()
	elif nav & MenuPage.NAV_PRESSED and p.pressed_id != "back":
		_sfx.play("confirm")
	if open and pages.has(page):
		pages[page].refresh()


func _input(event: InputEvent) -> void:
	if open and OptionsPages.input(self, event):
		get_viewport().set_input_as_handled()
