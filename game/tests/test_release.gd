## PORT-09: release prep. The build ID matches `git describe`, the title
## shows it, the icon is set, and the export presets cover the four
## platforms without the tests and tools. (tools/export.sh does the
## exports, refuses a dirty tree, and boots the exported .pck.)
extends TestSuite


func test_build_id_matches_git_describe() -> void:
	var out := []
	var root := ProjectSettings.globalize_path("res://").path_join("..")
	var code := OS.execute("git", ["-C", root, "describe", "--always", "--dirty"], out)
	if code != 0:
		check(true, "no git here: nothing to compare")
		return
	eq(BuildInfo.from_git(), String(out[0]).strip_edges(), "the checkout's describe string")
	eq(BuildInfo.id(), "DEV " + BuildInfo.from_git(),
		"a checkout says DEV and asks git (even with an export's build_id.txt left over)")
	var label := BuildInfo.label()
	eq(label, label.to_upper(), "upper case for the bitmap font")
	check(label.begins_with("BUILD "), label)


func test_title_shows_the_build() -> void:
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	eq(t.build_label.text, BuildInfo.label())
	t.free()


func test_icon_and_presets() -> void:
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	eq(icon, "res://icon.png")
	var img := (load(icon) as Texture2D).get_image()
	eq(img.get_size(), Vector2i(256, 256), "a 256 px icon")
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	var platforms := []
	for sec in cfg.get_sections():
		if sec.ends_with(".options") or not sec.begins_with("preset."):
			continue
		platforms.append(cfg.get_value(sec, "platform"))
		var ex: String = cfg.get_value(sec, "exclude_filter")
		check("tests/*" in ex and "tools/*" in ex, "%s leaves out tests and tools" % sec)
		check("build_id.txt" in String(cfg.get_value(sec, "include_filter")), "%s carries the build ID" % sec)
		check(String(cfg.get_value(sec, "export_path")).begins_with("../build/"), "%s exports into build/" % sec)
	platforms.sort()
	eq(platforms, ["Linux", "Web", "Windows Desktop", "macOS"])
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility",
		"the Compatibility renderer (Web needs it)")
