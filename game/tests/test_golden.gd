## The sim matches its golden traces frame for frame (tests/golden.gd).
extends TestSuite


func _check(scenario: String) -> void:
	var path := Golden.DIR + scenario + ".txt"
	if not check(FileAccess.file_exists(path), "golden trace %s exists" % scenario):
		return
	var want := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var got := Golden.run(scenario)
	eq(got.size(), want.size(), scenario + " length")
	for i in mini(got.size(), want.size()):
		if got[i] != want[i]:
			runner.fail("%s diverges at line %d:\n      want %s\n      got  %s" % [scenario, i,
				want[i].left(160), got[i].left(160)])
			return
	check(true)


func test_singles_demo_matches_golden() -> void:
	_check("singles_demo")


func test_doubles_demo_matches_golden() -> void:
	_check("doubles_demo")


func test_bot_vs_cpu_matches_golden() -> void:
	_check("bot_vs_cpu")


func test_runs_are_reproducible() -> void:
	eq(Golden.run("doubles_demo", 1200), Golden.run("doubles_demo", 1200), "same input, same trace")
