## PICKLEBALL 101 (ADR-070): the lessons list, with a preview of each, and
## a lesson: a court diagram over a page of text, then quizzes, then its
## closing page (the next lesson, the HOW TO PLAY drill that goes with it,
## or the list). The pages are meta/course.gd's; nothing here plays a match.
class_name CourseScreen
extends Control

signal leave                     ## back to the title
signal try_lesson(index: int)    ## a HOW TO PLAY lesson (meta/tutorial.gd)

const LOCK := MenuPage.TRANSITION
const DIM := Color(0.72, 0.77, 0.9)
const GOOD := Color("4ade80")
const BAD := Color("ff6b6b")
const GOLD := Color("fbe46a")
const TEXT_PANEL := Rect2(48, 360, 864, 112)

var save: SaveGame
var lesson := -1                 ## -1: the list
var page := 0
var pages: Array = []
var answers := {}                ## page -> the choice picked first
var lock := LOCK
var list: MenuPage
var choices: MenuPage            ## a quiz's choices, or the closing page's menu
var diagram: CourtDiagram
var _preview: CourtDiagram
var _list_ui: Control
var _lesson_ui: Control
var _title: BitmapText
var _sub: BitmapText
var _blurb: Array = []
var _lines: Array = []
var _prompts: PromptBar
var _sfx: Sfx


func setup(game_save: SaveGame, start := -1) -> CourseScreen:
	save = game_save
	lesson = start
	return self


func music_track() -> String:
	return "title"


func _ready() -> void:
	if list:
		return                           # built already (tests and tools call it early)
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.06, 0.14)
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	UiKit.panel(Rect2(230, 8, 500, 58), self)
	_title = UiKit.text("big_gold", "", Vector2(480, 22), 0.5, Color.WHITE, self)
	_sub = UiKit.text("small", "", Vector2(480, 72), 0.5, DIM, self)
	_build_list()
	_build_lesson()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	if lesson >= 0:
		open_lesson(lesson)
	else:
		show_list()
	GameControls.clear_latch()


func _build_list() -> void:
	_list_ui = Control.new()
	_list_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list_ui)
	var rows := []
	for i in Course.count():
		rows.append({"id": Course.lesson(i)["id"], "label": "%d %s" % [i + 1, Course.lesson(i)["title"]],
			"value": _status_label.bind(i), "press": open_lesson.bind(i)})
	rows.append({"id": "back", "label": "BACK", "press": func(): leave.emit()})
	var h := 18 + rows.size() * MenuPage.ROW_H + 52
	list = MenuPage.new().setup("course", "", rows, Rect2(40, 96, 420, h), [["hit", "START"], ["back", "BACK"]])
	list.hovered.connect(func(_id): _show_preview())
	list.back_requested.connect(func(): leave.emit())
	list.cursor = Course.next(save)
	_list_ui.add_child(list)
	UiKit.panel(Rect2(490, 96, 430, h), _list_ui)
	_preview = CourtDiagram.new().setup(8.0, false)
	_preview.position = Vector2(705 - 176, 136)
	_list_ui.add_child(_preview)
	for k in 3:
		_blurb.append(UiKit.text("small", "", Vector2(705, 334 + k * 26), 0.5,
			GOLD if k == 2 else Color.WHITE, _list_ui))
	for k in 2:
		_blurb.append(UiKit.text("small", "", Vector2(480, 440 + k * 26), 0.5, DIM, _list_ui))


func _build_lesson() -> void:
	_lesson_ui = Control.new()
	_lesson_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lesson_ui)
	diagram = CourtDiagram.new().setup(10.0)
	diagram.position = Vector2(480 - 220, 122)
	_lesson_ui.add_child(diagram)
	UiKit.panel(TEXT_PANEL, _lesson_ui)
	for k in Course.LINES_MAX:
		_lines.append(UiKit.text("small", "", Vector2(80, 376 + k * 28), 0.0, Color.WHITE, _lesson_ui))
	_prompts = PromptBar.new().setup([], Vector2(480, 510))
	_lesson_ui.add_child(_prompts)


func _status_label(i: int) -> String:
	match Course.status(save, i):
		Course.PERFECT:
			return "PERFECT"
		Course.DONE:
			return "DONE"
	return ""


# --- The list -------------------------------------------------------------------------

func show_list() -> void:
	lesson = -1
	_free_choices()
	_list_ui.visible = true
	_lesson_ui.visible = false
	_title.text = String(Course.data()["title"])
	_sub.text = String(Course.data()["subtitle"])
	list.refresh()
	list.appear()
	_show_preview()
	var all := Course.done_count(save) == Course.count()
	var fin: Array = Course.data()["finale"]
	_blurb[3].text = String(fin[0]) if all else "LESSONS DONE %s" % Course.label(save)
	_blurb[4].text = String(fin[1]) if all else ""
	lock = LOCK


func _show_preview() -> void:
	var i := list.cursor
	if i >= Course.count():
		_preview.show_page({})
		for k in 3:
			_blurb[k].text = ""
		return
	var first: Dictionary = Course.lesson(i)["pages"][0]
	_preview.show_page(first)
	var b: Array = Course.lesson(i)["blurb"]
	_blurb[0].text = String(b[0])
	_blurb[1].text = String(b[1]) if b.size() > 1 else ""
	var n: int = Course.lesson(i)["pages"].size() - Course.quizzes(i)
	_blurb[2].text = {Course.PERFECT: "PERFECT: EVERY QUIZ RIGHT", Course.DONE: "DONE"}.get(
		Course.status(save, i), "%d PAGES, %d %s" % [n, Course.quizzes(i), "QUIZ" if Course.quizzes(i) == 1 else "QUIZZES"])


# --- A lesson -------------------------------------------------------------------------

func open_lesson(i: int) -> void:
	lesson = i
	pages = Course.pages(i)
	answers = {}
	page = 0
	_list_ui.visible = false
	_lesson_ui.visible = true
	_title.text = String(Course.lesson(i)["title"])
	_sfx.play("confirm")
	_show_page()


func _page() -> Dictionary:
	return pages[page]


func _show_page() -> void:
	lock = LOCK
	_free_choices()
	var p := _page()
	_sub.text = "LESSON %d OF %d   PAGE %d/%d" % [lesson + 1, Course.count(), page + 1, pages.size()]
	diagram.visible = not Course.is_quiz(p) and not p.has("end")
	diagram.show_page(p)
	if Course.is_quiz(p):
		var rows := []
		var quiz := page
		for k in p["choices"].size():
			rows.append({"id": "c%d" % k, "label": String(p["choices"][k]),
				"value": _choice_mark.bind(quiz, k), "press": answer.bind(k)})
		_choices(rows, "QUIZ")
	elif p.has("end"):
		_end_page()
	_text()


func _choices(rows: Array, title: String) -> void:
	var h := 18 + rows.size() * MenuPage.ROW_H + (54 if title != "" else 18)
	choices = MenuPage.new().setup("choices", title, rows, Rect2(200, 214 - h / 2.0, 560, h))
	_lesson_ui.add_child(choices)
	choices.appear()


func _free_choices() -> void:
	if choices:
		# out now, freed later: its own press may be what's closing it
		choices.get_parent().remove_child(choices)
		choices.queue_free()
		choices = null


## The page's text: the lines; a quiz's question, then whether you had it
## and why; the closing page's word.
func _text() -> void:
	var p := _page()
	var out: Array = []
	var tints := [Color.WHITE, Color.WHITE, Color.WHITE]
	if Course.is_quiz(p):
		if answers.has(page):
			var right: bool = answers[page] == int(p["answer"])
			out = ["RIGHT!" if right else "NOT QUITE: IT'S %s." % p["choices"][int(p["answer"])]]
			tints[0] = GOOD if right else BAD
			out.append_array(p["why"])
		else:
			out = p["quiz"]
	elif p.has("end"):
		var perfect := _perfect()
		out = ["LESSON DONE!", "PERFECT: EVERY QUIZ RIGHT THE FIRST TIME." if perfect
			else "QUIZZES RIGHT THE FIRST TIME: %d/%d" % [_right(), Course.quizzes(lesson)]]
		tints[0] = GOLD
		if lesson == Course.count() - 1:
			out.append(String(Course.data()["finale"][0]))
	else:
		out = p["lines"]
	for k in _lines.size():
		_lines[k].text = String(out[k]) if k < out.size() else ""
		_lines[k].tint = tints[k]
	var waiting := Course.is_quiz(p) and not answers.has(page)
	if waiting or p.has("end"):
		_prompts.set_items([["hit", "SELECT"], ["back", "LESSONS"]])
	else:
		_prompts.set_items([["hit", "NEXT"], ["back", "LESSONS"]])


func _choice_mark(quiz: int, k: int) -> String:
	if not answers.has(quiz):
		return ""
	if k == int(pages[quiz]["answer"]):
		return "RIGHT"
	return "NO" if k == int(answers[quiz]) else ""


## A quiz answered: the first pick is the one that counts.
func answer(k: int) -> void:
	if answers.has(page):
		return
	answers[page] = k
	_sfx.play("confirm" if k == int(_page()["answer"]) else "back")
	choices.refresh()
	_text()
	lock = LOCK


func _right() -> int:
	var n := 0
	for q in answers:
		n += 1 if int(answers[q]) == int(pages[q]["answer"]) else 0
	return n


func _perfect() -> bool:
	return _right() == Course.quizzes(lesson)


## The closing page: saved as done; on to the next, the drill, or the list.
func _end_page() -> void:
	Course.finish(save, lesson, _perfect())
	if Course.done_count(save) == Course.count():
		Achievements.unlock(save, "scholar")        # ADR-077
	if save:
		save.save_game()
	var rows := []
	if lesson < Course.count() - 1:
		rows.append({"id": "next", "label": "NEXT: " + String(Course.lesson(lesson + 1)["title"]),
			"press": open_lesson.bind(lesson + 1)})
	var drill := Course.try_lesson(lesson)
	if drill >= 0:
		rows.append({"id": "try", "label": "TRY IT IN THE GAME", "press": func(): try_lesson.emit(drill)})
	rows.append({"id": "list", "label": "ALL LESSONS", "press": show_list})
	_choices(rows, "")


func next_page() -> void:
	var p := _page()
	if Course.is_quiz(p) and not answers.has(page):
		return
	if page + 1 < pages.size():
		page += 1
		_sfx.play("blip")
		_show_page()


func prev_page() -> void:
	if page > 0:
		page -= 1
		_sfx.play("blip")
		_show_page()


# --- Input ----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if lock > 0:
		lock -= 1
		return
	if lesson < 0:
		var nav := list.drive(false)
		if nav & MenuPage.NAV_MOVED:
			_sfx.play("blip")
			_show_preview()
		if nav & MenuPage.NAV_BACK:
			_sfx.play("back")
			leave.emit()
		return
	var p := _page()
	var menu := choices != null and (p.has("end") or not answers.has(page))
	if menu:
		var nav := choices.drive(false)
		if nav & MenuPage.NAV_MOVED:
			_sfx.play("blip")
		if nav & MenuPage.NAV_BACK:
			_back_to_list()
		elif not p.has("end") and GameControls.menu_pressed("move_left"):
			prev_page()
		return
	if Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
		_back_to_list()
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start") \
			or GameControls.menu_pressed("move_right"):
		next_page()
	elif GameControls.menu_pressed("move_left"):
		prev_page()


func _back_to_list() -> void:
	_sfx.play("back")
	var at := lesson
	show_list()
	list.cursor = maxi(at, 0)
	list.refresh()
	_show_preview()


func _on_gui_input(event: InputEvent) -> void:
	if lesson < 0 or lock > 0 or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_back_to_list()
	elif event.button_index == MOUSE_BUTTON_LEFT and (choices == null or answers.has(page)):
		next_page()
