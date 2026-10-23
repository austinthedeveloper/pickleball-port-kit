## The HAT MUSEUM (SNES ADR-061): its input, ported from the SNES repo's
## test_museum.c, then the title's way in and out (the career card's HAT
## MUSEUM row, B wears, Y back with the save written) and the view.
extends TestSuite

const DIR := "user://test_museum/"


## The case holding a named hat.
func _case_of(name: String) -> int:
	for i in Museum.hats():
		if Career.hat_names[Museum.hat(i)] == name:
			return i
	runner.fail("no case for " + name)
	return 0


func _fresh() -> Career:
	var c := Career.new()
	c.create(0, "MAX")
	return c


func test_cases() -> void:
	var m := Museum.new()
	m.begin(_fresh(), 0)
	# Every hat but the bare head, in id order: the cap first.
	eq(Museum.hats(), Career.hats() - 1)
	eq(Museum.hats(), 12, "twelve cases (SNES ADR-060's hats)")
	eq(Museum.hat(0), 0)
	var ok := true
	for i in Museum.hats():
		ok = ok and Museum.hat(i) != Career.hat_none() and Museum.hat(i) < Career.hats()
	check(ok, "no case for the bare head")
	eq(Museum.hat(Museum.hats() - 1), Career.hats() - 1)
	# A new player holds the cap only.
	check(m.unlocked(0) and m.unlocked_count() == 1, "the cap only")
	check(not m.unlocked(_case_of("CROWN")))
	check(m.cursor == 0 and m.changed)


func test_moves() -> void:
	var m := Museum.new()
	m.begin(_fresh(), 0)
	var last := Museum.hats() - 1
	m.input(Practice.PAD_LEFT)
	eq(m.cursor, last, "left wraps to the last")
	m.input(Practice.PAD_RIGHT)
	eq(m.cursor, 0)
	m.input(Practice.PAD_DOWN)
	eq(m.cursor, Museum.COLS)
	m.input(Practice.PAD_UP)
	m.input(Practice.PAD_UP)
	eq(m.cursor, (Museum.rows() - 1) * Museum.COLS, "up wraps to the bottom row")
	m.input(Practice.PAD_DOWN)
	eq(m.cursor, 0, "and back to the top")
	var ok := true
	for at in last + 1:
		for k in [Practice.PAD_UP, Practice.PAD_DOWN, Practice.PAD_LEFT, Practice.PAD_RIGHT]:
			m.cursor = at
			m.input(k)
			ok = ok and m.cursor >= 0 and m.cursor <= last
	check(ok, "every move stays in the grid")


func test_wear() -> void:
	var c := _fresh()
	var p := c.active_player()
	var m := Museum.new()
	var crown := _case_of("CROWN")
	m.begin(c, 0)
	m.cursor = crown
	check(m.input(Practice.PAD_B) == Museum.STAY and p.hat == 0, "a locked hat can't be worn")
	p.unlocked |= 1 << Career.unlock_names.find("CROWN")
	check(m.unlocked(crown) and m.unlocked_count() == 2)
	m.changed = false
	eq(m.input(Practice.PAD_B), Museum.STAY)
	check(p.hat == Museum.hat(crown) and m.changed and m.worn, "unlocked, it can")
	eq(m.input(Practice.PAD_Y), Museum.CLOSE_SAVE, "the save is written on leaving")
	eq(m.input(Practice.PAD_B), Museum.STAY, "again: nothing to do")
	m.begin(c, 0)
	eq(m.cursor, crown, "it opens on the worn hat")
	p.hat = Career.hat_none()
	m.begin(c, 0)
	eq(m.cursor, 0, "bareheaded, on the cap")
	eq(m.input(Practice.PAD_Y), Museum.CLOSE)
	eq(m.input(Practice.PAD_START), Museum.CLOSE)


## The card's count (career_hats_held): the cap for a new player.
func test_hats_held() -> void:
	var c := _fresh()
	var p := c.active_player()
	eq(Career.hats_held(p), 1)
	p.unlocked = 0xffff
	eq(Career.hats_held(p), Museum.hats(), "all of them")


func _save() -> SaveGame:
	var s := fresh_save(DIR)
	return s


## From the card: HAT MUSEUM opens it on the worn hat; B wears the beanie
## (won), Y goes back to the card with the save written.
func test_title_museum() -> void:
	var s := _save()
	s.career.create(0, "MAX")
	s.career.active_player().unlocked = 1 << Career.unlock_names.find("BEANIE")
	var t := title_screen(s)
	t.career.open()
	t.pages["career"].select("slot0")
	t.pages["career"].press()
	eq(t.page, "career_card")
	eq(t.pages["career_card"].value_of("hats"), "2 OF 12", "the cap and the beanie")
	t.pages["career_card"].select("hats")
	t.pages["career_card"].press()
	eq(t.page, "museum")
	check(t.hat_museum.visible and not t.pages["career_card"].visible, "the museum alone")
	eq(t.museum.cursor, 0, "on the cap")
	var beanie := _case_of("BEANIE")
	while t.museum.cursor != beanie:
		t.museum_input(Practice.PAD_RIGHT)
	t.museum_input(Practice.PAD_B)
	eq(String(Career.hat_names[s.career.active_player().hat]), "BEANIE", "worn")
	t.hat_museum._process(0.0)
	eq(t.hat_museum._name.text, "BEANIE  WEARING")
	t.museum_input(Practice.PAD_Y)
	eq(t.page, "career_card", "Y: back to the card")
	var disk := SaveGame.new()
	disk.dir = DIR
	disk.load_game()
	eq(String(Career.hat_names[disk.career.players[0].hat]), "BEANIE", "saved")
	t.free()


## A locked case reads "???" and how to earn it; the view uses the new
## hats' sheets.
func test_view_locked() -> void:
	var c := _fresh()
	var m := Museum.new()
	m.begin(c, 0)
	var v := HatMuseum.new().setup(m)
	runner.root.add_child(v)
	m.cursor = _case_of("VIKING")
	m.changed = true
	v._process(0.0)
	eq(v._name.text, "???")
	eq(v._how.text, "BEAT THE GYM BROS")
	var ok := true
	for i in Museum.hats():
		ok = ok and v._cases[i][2].texture != null
	check(ok, "every case has its hat's sheet")
	v.free()
