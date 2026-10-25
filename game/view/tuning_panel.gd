## The tuning panel (port ADR-074): a flyout from the right during a match,
## opened with F2 or the pause menu's TUNE. The match waits while it's open.
## BALL SPEED, BALL SIZE and CPU ERRORS change the match live and are saved
## as the settings; every modifier and rule can be switched for this match,
## and APPLY restarts it with them. SMART PLAY (port ADR-094) tunes how the
## CPUs play, live and saved: the opponents' KITCHEN, TOGETHER and AIM at
## this match's difficulty, and a CPU partner's (MATE). Not online, not in the demo.
class_name TuningPanel
extends CanvasLayer

const AREA := Rect2(612, 14, 336, 0)
const SLIDE_FRAMES := 8

var view: MatchView
var open := false
var pages := {}
var page: MenuPage
var mods := 0                    ## the modifiers APPLY restarts with
var _slide := 0.0                ## 0 off the right edge .. 1 in
var _shade: ColorRect


func setup(v: MatchView) -> TuningPanel:
	view = v
	layer = 20                       # over the HUD and its pause menu
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.35)
	_shade.size = Vector2(960, 540)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_add("tune", "TUNING", [
		SettingRows.slider("ball_speed", _retune),
		SettingRows.slider("ball_size", func(): view.actors.apply_ball_size()),
		SettingRows.slider("cpu_errors", _retune),
		{"id": "modifiers", "label": "MODIFIERS", "value": _count.bind("modifiers"),
			"press": func(): _show("modifiers")},
		{"id": "rules", "label": "RULES", "value": _count.bind("rules"), "press": func(): _show("rules")},
		{"id": "smarts", "label": "SMART PLAY", "value": func(): return Settings.smart_name(view.sim.config.difficulty).to_upper(),
			"press": func(): _show("smarts")},
		{"id": "apply", "label": "APPLY", "value": func():
			if not pending():
				return ""
			return "RESTART" if can_apply() else "NEXT MATCH",
			"press": apply},
		{"id": "defaults", "label": "DEFAULTS", "press": defaults},
		{"id": "close", "label": "CLOSE", "press": close},
	])
	for group in ["modifiers", "rules"]:
		var rows := []
		for m in Settings.MOD_ROWS:
			if m[3] != group:
				continue
			var bit: int = m[2]
			rows.append({"id": m[0], "label": m[1], "value": func(): return "ON" if mods & bit else "OFF",
				"change": func(_d): mods ^= bit})
		rows.append({"id": "back", "label": "BACK", "press": func(): _show("tune")})
		_add(group, "MODIFIERS" if group == "modifiers" else "RULES", rows)
	var smart_rows := []
	for who in [["them", "THEIR"], ["partner", "MATE"]]:
		for knob in [[K.SMART_KITCHEN, "KITCHEN"], [K.SMART_TOGETHER, "TOGETHER"], [K.SMART_AIM, "AIM"]]:
			var profile := String(who[0])
			var k: int = knob[0]
			smart_rows.append({"id": "%s_%s" % [profile, String(knob[1]).to_lower()],
				"label": "%s %s" % [who[1], knob[1]],
				"value": func(): return "%d%%" % int(Settings.smart_profile(_profile(profile))[k]),
				"change": func(d):
					Settings.nudge_smart(_profile(profile), k, d)
					_retune_smarts()})
	smart_rows.append({"id": "smart_defaults", "label": "DEFAULTS", "press": func():
		Settings.smarts = Settings.smart_defaults()
		_retune_smarts()})
	smart_rows.append({"id": "back", "label": "BACK", "press": func(): _show("tune")})
	_add("smarts", "SMART PLAY", smart_rows)
	visible = false
	return self


## The profile a SMART PLAY row tunes: the partner's, or this match's
## difficulty's for "them".
func _profile(who: String) -> String:
	return "partner" if who == "partner" else Settings.smart_name(view.sim.config.difficulty)


## SMART PLAY's knobs on the live match (and its replay).
func _retune_smarts() -> void:
	var smarts := Settings.smarts_for(view.sim.config)
	if view.highlight:
		view.highlight.op(["smarts", smarts])
	view.sim.retune_smarts(smarts)



func _add(id: String, title: String, rows: Array) -> void:
	var area := AREA
	area.size.y = 18 + 44 + rows.size() * MenuPage.ROW_H + 52
	var p := MenuPage.new().setup(id, title, rows, area, [["hit", "SELECT"], ["back", "BACK"]])
	p.back_requested.connect(back)
	p.visible = false
	add_child(p)
	pages[id] = p


func _count(group: String) -> String:
	var n := Settings.MOD_ROWS.filter(func(m): return m[3] == group and mods & int(m[2])).size()
	return "NONE" if n == 0 else "%d ON" % n


## The modifiers differ from the running match's: APPLY would restart it.
func pending() -> bool:
	return mods != view.sim.config.modifiers


## Whether a match can be tuned here: not online, not the demo.
func available() -> bool:
	return not view.demo and view.net == null


## APPLY restarts: not in practice or a lesson (their sessions own the config).
func can_apply() -> bool:
	return not view.sim.config.practice and view.lesson == null


func toggle() -> void:
	if open:
		close()
	elif available():
		open_panel()


func open_panel() -> void:
	open = true
	visible = true
	mods = view.sim.config.modifiers
	view._hud.visible = false            # the scoreboard under the flyout: the match waits
	_show("tune")
	view._sfx.play("confirm")


func close() -> void:
	open = false
	view._hud.visible = true
	view._sfx.play("back")
	# the closing press never reaches the match (rule 9)
	view.input_lock = MatchView.INPUT_LOCK_FRAMES
	GameControls.clear_latch()
	if view.save:
		Settings.store_to(view.save)
		view.save.save_game()


func back() -> void:
	if page and page.page_id != "tune":
		_show("tune")
	else:
		close()


func _show(id: String) -> void:
	for k in pages:
		pages[k].visible = k == id
	page = pages[id]
	page.refresh()
	page.appear()
	GameControls.clear_latch()


func _retune() -> void:
	if view.highlight:
		view.highlight.op(["retune", Settings.ball_speed, Settings.cpu_errors])   # replayed too
	view.sim.retune(Settings.ball_speed, Settings.cpu_errors)


## The match again, from 0-0, with the modifiers set here (and the
## sliders); they're kept for the next match too (a story chapter's twist
## isn't). In practice and lessons, only for the next match.
func apply() -> void:
	if not view.story_mode and not view.trip:
		Settings.mod_bits = mods & Settings.MOD_SAVED
	if not can_apply():
		close()
		return
	var cfg: SimTypes.MatchConfig = view.sim.config
	cfg.modifiers = mods
	cfg.ball_speed = Settings.ball_speed
	cfg.cpu_errors = Settings.cpu_errors
	view.rebuild(cfg)
	view._hud.visible = false
	_show("tune")


## The sliders back to their defaults, live.
func defaults() -> void:
	Settings.ball_speed = Settings.BALL_SPEED_DEFAULT
	Settings.ball_size = Settings.BALL_SIZE_DEFAULT
	Settings.cpu_errors = Settings.CPU_ERRORS_DEFAULT
	_retune()
	view.actors.apply_ball_size()
	page.refresh()


## One frame while open (the match waits): the keys and pads on the page.
func update() -> void:
	if not page:
		return
	var nav := page.drive()
	if nav & MenuPage.NAV_MOVED:
		view._sfx.play("blip")
	if nav & MenuPage.NAV_CHANGED:
		view._sfx.play("blip")
	if nav & MenuPage.NAV_BACK:
		back()
	page.refresh()


func _process(_delta: float) -> void:
	_slide = clampf(_slide + (1.0 if open else -1.0) / SLIDE_FRAMES, 0.0, 1.0)
	var x := (1.0 - _slide) * (960.0 - AREA.position.x)
	for k in pages:
		pages[k].position.x = x
	_shade.modulate.a = _slide
	if not open and _slide <= 0.0:
		visible = false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()
