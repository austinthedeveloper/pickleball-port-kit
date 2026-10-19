## STY/quips for the port (ADR-023/026/048): lines fit the font, quips come
## from the right side, a third of the time, never repeated.
extends TestSuite

const FONT_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,:-'/%+ "


func _fits(s: String) -> bool:
	if s.length() < 1 or s.length() > 28:
		return false
	for ch in s:
		if FONT_CHARS.find(ch) < 0:
			return false
	return true


func test_every_line_fits_the_hud_font() -> void:
	for i in Opponents.count():
		var t := Opponents.team(i)
		for key in ["intro", "taunt", "concede"]:
			check(_fits(t[key]), "%s %s: '%s'" % [t["team"], key, t[key]])
		eq(t["quips"].size(), 16, "%s has sixteen quips (SNES ADR-063)" % t["team"])
		for q in t["quips"]:
			check(_fits(q), "%s quip '%s'" % [t["team"], q])
	for side in ["player", "cpu"]:
		for q in Story.generic()[side]:
			check(_fits(q), "%s quip '%s'" % [side, q])


func test_quips_come_from_the_losing_side() -> void:
	var st := Story.new()
	var cfg := SimTypes.MatchConfig.singles()
	cfg.opponent = 3
	var team_lines: Array = Opponents.team(3)["quips"]
	var said := 0
	for frame in 300:
		var q := st.quip(cfg, 1, frame)
		if q != "":
			said += 1
			check(q in team_lines, "a ladder team speaks its own lines: '%s'" % q)
	eq(said, 100, "a third of lost points")
	var mine := st.quip(cfg, 0, 3)
	check(mine in Story.generic()["player"], "P1 speaks the player's lines")
	cfg.opponent = -1
	check(st.quip(cfg, 1, 6) in Story.generic()["cpu"], "the default CPU's lines")


func test_quips_never_repeat_in_a_row() -> void:
	var st := Story.new()
	var cfg := SimTypes.MatchConfig.singles()
	var last := ""
	for frame in range(0, 600, 3):
		var q := st.quip(cfg, 1, frame)
		if q == "":
			continue
		check(q != last, "no repeat")
		last = q


## SNES ADR-063: a shuffled deck per side: every line once before any again.
func test_quips_go_through_the_deck() -> void:
	var st := Story.new()
	var cfg := SimTypes.MatchConfig.singles()
	cfg.opponent = 5
	var heard := {}
	var frame := 0
	while heard.size() < 16 and frame < 3000:
		var q := st.quip(cfg, 1, frame)
		if q != "":
			check(not heard.has(q), "no line twice in a pass: '%s'" % q)
			heard[q] = true
		frame += 3
	eq(heard.size(), 16, "all sixteen in one pass")


func test_cards_and_results() -> void:
	eq(Story.card_name(0, false), Opponents.team(0)["players"][0]["name"], "singles names the captain")
	eq(Story.card_name(0, true), Opponents.team(0)["team"], "doubles names the team")
	eq(Story.rung_line(0), "LADDER 1 OF %d" % Opponents.count())
	eq(Story.result_line(0, true), Opponents.team(0)["concede"])
	eq(Story.result_line(0, false), Opponents.team(0)["taunt"])
