## SAV-01..05 for the port (playbook §6): blank formats, newer copy wins,
## torn copy falls back, sequence wraps, old layouts migrate.
extends TestSuite

const DIR := "user://test_save/"


func _fresh() -> SaveGame:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in SaveGame.FILES:
		if FileAccess.file_exists(DIR + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	var s := SaveGame.new()
	s.dir = DIR
	return s


func _write_raw(name: String, body: Dictionary) -> void:
	var f := FileAccess.open(DIR + name, FileAccess.WRITE)
	f.store_string(JSON.stringify(body))


func _image(version: int, seq: int, d: Dictionary) -> Dictionary:
	var payload := JSON.stringify(d, "", true)
	return {"magic": SaveGame.MAGIC, "version": version, "seq": seq,
		"checksum": SaveGame.checksum(payload), "payload": payload}


func test_blank_save_formats_defaults() -> void:
	var s := _fresh()
	s.load_game()
	eq(s.data, SaveGame.defaults(), "defaults on a blank save")


func test_round_trip_and_newer_copy_wins() -> void:
	var s := _fresh()
	s.load_game()
	s.data["settings"]["venue"] = 2
	s.save_game()
	s.data["settings"]["venue"] = 1
	s.save_game()
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	eq(t.data["settings"]["venue"], 1, "the newer of the two copies")
	check(FileAccess.file_exists(DIR + "save_a.json") and FileAccess.file_exists(DIR + "save_b.json"),
		"writes alternate between the two copies")


func test_torn_copy_falls_back() -> void:
	var s := _fresh()
	s.load_game()
	s.data["settings"]["points"] = 4
	s.save_game()
	s.data["settings"]["points"] = 6
	s.save_game()
	# tear the newer copy (seq 2 went to the second file)
	var newer := "save_b.json"
	var f := FileAccess.open(DIR + newer, FileAccess.WRITE)
	f.store_string("{\"magic\": \"PB94\", \"seq\": 2, \"chec")
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	eq(t.data["settings"]["points"], 4, "the intact older copy")
	var bad := _image(2, 9, {"settings": {"points": 9}})
	bad["checksum"] = 1
	_write_raw(newer, bad)
	t.load_game()
	eq(t.data["settings"]["points"], 4, "a checksum mismatch is ignored")


func test_sequence_wraps() -> void:
	check(SaveGame._newer(0, 0xffff), "0 is newer than 65535")
	check(not SaveGame._newer(0xffff, 0), "65535 is older than 0")
	var s := _fresh()
	var d := SaveGame.defaults()
	d["settings"]["venue"] = 2
	_write_raw("save_a.json", _image(2, 0xffff, SaveGame.defaults()))
	_write_raw("save_b.json", _image(2, 0, d))
	s.load_game()
	eq(s.data["settings"]["venue"], 2, "the wrapped copy wins")


func test_v1_save_migrates() -> void:
	var s := _fresh()
	var v1 := {"settings": {"venue": 1, "difficulty": K.DIFFICULTY_HARD, "points": 3, "players": 1}}
	_write_raw("save_a.json", _image(1, 7, v1))
	s.load_game()
	eq(s.data["settings"]["venue"], 1, "settings carry over")
	eq(s.data["settings"]["difficulty"], K.DIFFICULTY_HARD)
	eq(s.data["records"], SaveGame.defaults()["records"], "records arrive at zero")
	var t := SaveGame.new()
	t.dir = DIR
	t.load_game()
	eq(t.seq, 9, "migration rewrote both copies")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "save_a.json"))
	eq(int(raw["version"]), SaveGame.VERSION, "now the current layout")


func test_future_version_is_rejected() -> void:
	var s := _fresh()
	_write_raw("save_a.json", _image(SaveGame.VERSION + 1, 3, {"settings": {"venue": 2}}))
	s.load_game()
	eq(s.data, SaveGame.defaults(), "an unknown newer layout isn't trusted")


func test_records_and_ladder() -> void:
	var s := _fresh()
	s.load_game()
	s.record_match(false, true)
	s.record_match(true, false)
	eq(s.data["records"]["singles_wins"], 1)
	eq(s.data["records"]["doubles_losses"], 1)
	check(s.record_rally(12), "a longer rally is a record")
	check(not s.record_rally(5), "a shorter one isn't")
	for i in 7:
		check(not s.advance_ladder(8), "rung %d" % (i + 1))
	eq(s.data["records"]["ladder_rung"], 7)
	check(s.advance_ladder(8), "beating the last rung clears the ladder")
	eq(s.data["records"]["ladder_rung"], 0, "and it starts over")
	eq(s.data["records"]["ladder_clears"], 1)
