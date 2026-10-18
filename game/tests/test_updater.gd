## The in-game updater (PORT-32, ADR-057): versions, GitHub's release, the
## launch decision (and its safety: a pack that never reached the title is
## skipped), what OPTIONS and the title say in each state, and the
## manifest CI publishes.
extends TestSuite


func test_versions_compare() -> void:
	eq(Updater.compare("0.9.0", "0.8.1"), 1)
	eq(Updater.compare("0.10.0", "0.9.3"), 1, "numbers, not text")
	eq(Updater.compare("v0.8.1", "0.8.1"), 0, "a tag's v")
	eq(Updater.compare("0.8", "0.8.0"), 0)
	eq(Updater.compare("1.0.0", "1.0.1"), -1)
	check(Updater.engine().count(".") == 2, "the engine as MAJOR.MINOR.PATCH: " + Updater.engine())


func _release(tag: String, files: Array) -> Dictionary:
	return {"tag_name": tag, "assets": files.map(func(n): return {"name": n,
		"browser_download_url": "https://example.test/" + n})}


func test_the_release() -> void:
	var r := Updater.parse_release(_release("v0.9.0", ["Pickleball94-0.9.0-macos.zip",
		"Pickleball94-0.9.0.pck", "Pickleball94-0.9.0.json"]))
	eq(r, {"version": "0.9.0", "manifest_url": "https://example.test/Pickleball94-0.9.0.json",
		"pck_url": "https://example.test/Pickleball94-0.9.0.pck"})
	eq(Updater.parse_release(_release("v0.8.1", ["Pickleball94-0.8.1-macos.zip"])), {},
		"a release from before the updater")
	eq(Updater.parse_release({}), {})


## scenes/boot.gd's choice at start-up (it can't use the game's scripts,
## so it has its own copy of the comparison).
func test_the_launch_decision() -> void:
	var boot = load("res://scenes/boot.gd")
	var eng := Updater.engine()
	var cur := {"version": "0.9.0", "engine": eng, "file": "user://updates/Pickleball94-0.9.0.pck", "booting": false}
	eq(boot.choose(cur, "0.8.1", eng), cur["file"], "a newer pack: load it")
	eq(boot.choose(cur, "0.9.0", eng), "", "the same as this build: no")
	eq(boot.choose(cur, "0.9.2", eng), "", "a newer full download wins")
	eq(boot.choose(cur, "0.10.0", eng), "", "0.10 is newer than 0.9")
	eq(boot.choose(cur, "0.8.1", "9.9.9"), "", "another engine: no")
	var bad := cur.duplicate()
	bad["booting"] = true
	eq(boot.choose(bad, "0.8.1", eng), "", "its last start never reached the title: skip it")
	eq(boot.choose({}, "0.8.1", eng), "", "nothing downloaded")
	for pair in [["0.9.0", "0.8.1"], ["0.10.0", "0.9.3"], ["1.0.0", "1.0.1"], ["0.8", "0.8.0"]]:
		eq(boot._compare(pair[0], pair[1]), Updater.compare(pair[0], pair[1]), "the twins agree: %s" % str(pair))


## Each state's words, short on OPTIONS and whole on the title.
func test_what_it_says() -> void:
	var u := Updater.new()
	u.latest = "0.9.0"
	var cases := [[Updater.LATEST, "UP TO DATE", ""],
		[Updater.AVAILABLE, "GET 0.9.0", "0.9.0 IS OUT: GET IT IN OPTIONS, UPDATES"],
		[Updater.FULL, "0.9.0 IS OUT", "0.9.0 IS OUT: GET IT FROM THE RELEASES PAGE"],
		[Updater.READY, "RESTART", "0.9.0 IS READY: RESTART IN OPTIONS, UPDATES"],
		[Updater.OFF, "DEV BUILD", ""]]
	for c in cases:
		u.state = c[0]
		eq([u.label(), u.notice()], [c[1], c[2]], "state %d" % c[0])
	u.state = Updater.FAILED
	u.error = "OFFLINE"
	eq([u.label(), u.notice()], ["TRY AGAIN", ""], "offline: quiet on the title")
	u.free()
	check(not Updater.supported(), "a checkout never updates (the tests run in one)")


## The title's line under the logo shows the news while there is some.
func test_the_title_says_so() -> void:
	var u := Updater.new()
	Updater.instance = u
	u.state = Updater.AVAILABLE
	u.latest = "0.9.0"
	var t := TitleScreen.new()
	runner.root.add_child(t)
	if not t.is_node_ready():
		t._ready()
	t._refresh_record()
	eq(t._record.text, "0.9.0 IS OUT: GET IT IN OPTIONS, UPDATES")
	t.open_page("options")
	check(t.pages["options"].select("updates"), "UPDATES on OPTIONS")
	eq(t.pages["options"].value_of("updates"), "GET 0.9.0")
	u.state = Updater.LATEST
	t._refresh_record()
	check(t._record.text.begins_with("RECORD") or t._record.text == "", "no news: the record again")
	t.free()
	Updater.instance = null
	u.free()


## CI's manifest: the version, this engine, the pack's size and SHA-256.
func test_the_manifest() -> void:
	var kit := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var pck := ProjectSettings.globalize_path("user://test_manifest.pck")
	var f := FileAccess.open(pck, FileAccess.WRITE)
	f.store_string("pickleball")
	f.close()
	var out := []
	OS.execute("python3", [kit.path_join("game/tools/update_manifest.py"), "9.9.9", pck], out, true)
	var m = JSON.parse_string(out[0])
	check(m is Dictionary, "JSON out")
	if m is Dictionary:
		eq([m["version"], m["engine"], int(m["size"])], ["9.9.9", Updater.engine(), 10])
		eq(m["sha256"], FileAccess.get_sha256(pck), "the same SHA-256 the game checks")
