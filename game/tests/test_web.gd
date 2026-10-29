## Port ADR-106: the Web build on a phone. SCALE starts on FILL there
## (under its own saved key), FULLSCREEN is the page's, a touch brings up
## the touch pad on AUTO even where the browser said it had no touch
## screen, and the page's additions (tools/web_head.html) are in the Web
## preset.
extends TestSuite

const DIR := "user://test_web/"


func _web(on: bool) -> bool:
	var kept := Settings.web
	Settings.web = on
	return kept


## FILL by default in a browser, PIXEL on the desktop, each saved apart.
func test_the_scale() -> void:
	var kept := _web(true)
	var keep_scale := Settings.integer_scale
	var sv := fresh_save(DIR)
	Settings.load_from(sv)
	check(not Settings.integer_scale, "the Web build starts on FILL")
	# a save the Web build made before: its "integer_scale" was the default
	sv.data["settings"]["integer_scale"] = 1
	Settings.load_from(sv)
	check(not Settings.integer_scale, "the old key doesn't count in a browser")
	Settings.integer_scale = true
	Settings.store_to(sv)
	eq(int(sv.data["settings"]["integer_scale_web"]), 1, "PIXEL chosen in a browser is kept")
	Settings.load_from(sv)
	check(Settings.integer_scale, "and comes back")
	_web(false)
	var desk := fresh_save(DIR)
	Settings.load_from(desk)
	check(Settings.integer_scale, "the desktop starts on PIXEL")
	Settings.integer_scale = false
	Settings.store_to(desk)
	eq(int(desk.data["settings"]["integer_scale_web"]), 0, "the desktop's choice leaves the Web key")
	Settings.integer_scale = keep_scale
	wipe_saves(DIR)
	_web(kept)


## In a browser with no full-screen API (headless stands in for an
## iPhone's Safari) OPTIONS has no FULLSCREEN row; on the desktop it does.
func test_the_fullscreen_row() -> void:
	var kept := _web(true)
	check(not Settings.web_full_offered(), "no full screen to offer headless")
	var t := title_screen(fresh_save(DIR))
	var options: MenuPage = t.pages["options"]
	check(options.index_of("fullscreen") < 0, "no FULLSCREEN row")
	check(options.index_of("scale") >= 0, "SCALE stays")
	t.free()
	_web(false)
	t = title_screen(fresh_save(DIR))
	check(t.pages["options"].index_of("fullscreen") >= 0, "the desktop's FULLSCREEN row")
	t.free()
	wipe_saves(DIR)
	_web(kept)


## A real touch shows the pad on AUTO with no touch screen reported.
func test_a_touch_brings_the_pad() -> void:
	var keep_mode := Settings.touch_pad
	var keep_dev := GameControls.last_device
	Settings.touch_pad = TouchPad.AUTO
	GameControls.touch_seen = false
	check(not TouchPad.wanted(), "headless, no touch yet: no pad")
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = Vector2(480, 270)
	GameControls.note_device(e)
	check(GameControls.touch_seen, "the touch is seen")
	check(TouchPad.wanted(), "and the pad shows")
	GameControls.fake_pads = {0: {}}
	check(not TouchPad.wanted(), "a controller still hides it")
	GameControls.fake_pads = {}
	var k := InputEventKey.new()
	k.pressed = true
	k.physical_keycode = KEY_SPACE
	GameControls.note_device(k)
	check(not TouchPad.wanted(), "a key press hides it until the next touch")
	GameControls.touch_seen = false
	GameControls.last_device = keep_dev
	Settings.touch_pad = keep_mode


## The Web preset carries tools/web_head.html (tools/web_head.py copies
## it) and installs as a landscape, full-screen app.
func test_the_page() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "the presets")
	var opts := ""
	for s in cfg.get_sections():
		if s.count(".") == 1 and String(cfg.get_value(s, "name", "")) == "Web":
			opts = s + ".options"
	check(opts != "", "a Web preset")
	var head := FileAccess.get_file_as_string("res://tools/web_head.html")
	check(head.contains("viewport-fit=cover"), "the page uses the notch's margins")
	check(head.contains("TURN YOUR PHONE SIDEWAYS"), "the upright card")
	eq(String(cfg.get_value(opts, "html/head_include", "")), head,
		"the preset has web_head.html as it is (run tools/web_head.py)")
	check(cfg.get_value(opts, "progressive_web_app/enabled", false), "an installable app")
	eq(int(cfg.get_value(opts, "progressive_web_app/display", -1)), 0, "full screen")
	eq(int(cfg.get_value(opts, "progressive_web_app/orientation", -1)), 1, "landscape")
