## PICKLEBALL 101 (port ADR-070): the real game's rules and habits, for
## a real court. The lessons are data/pickleball101.json (pages of text,
## each with a court diagram, then quizzes); this reads them, adds each
## lesson's closing page, and keeps the progress, saved. The screen is
## view/course_screen.gd.
class_name Course
extends RefCounted

const PATH := "res://data/pickleball101.json"
const LINES_MAX := 3
const LINE_MAX := 60             ## small-font characters a line, at most
const NOT_DONE := 0
const DONE := 1
const PERFECT := 2               ## done, every quiz right the first time

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func count() -> int:
	return data()["lessons"].size()


static func lesson(i: int) -> Dictionary:
	return data()["lessons"][clampi(i, 0, count() - 1)]


## A lesson's pages, its closing page last ({"end": true}).
static func pages(i: int) -> Array:
	return lesson(i)["pages"] + [{"end": true}]


static func is_quiz(p: Dictionary) -> bool:
	return p.has("quiz")


static func quizzes(i: int) -> int:
	return lesson(i)["pages"].filter(is_quiz).size()


## The HOW TO PLAY lesson (meta/tutorial.gd) that drills this one in the
## game, or -1.
static func try_lesson(i: int) -> int:
	var id := String(lesson(i).get("try", ""))
	for k in Tutorial.LESSONS.size():
		if Tutorial.LESSONS[k]["id"] == id:
			return k
	return -1


# --- Progress (save.data["course"]) --------------------------------------------------

static func _done(save: SaveGame) -> Array:
	if not save.data.has("course") or typeof(save.data["course"]) != TYPE_DICTIONARY:
		save.data["course"] = {"done": []}
	var d: Array = save.data["course"].get("done", [])
	while d.size() < count():
		d.append(NOT_DONE)
	save.data["course"]["done"] = d
	return d


## NOT_DONE, DONE or PERFECT.
static func status(save: SaveGame, i: int) -> int:
	if save == null:
		return NOT_DONE
	return int(_done(save)[i])


## A lesson finished; a perfect run is kept once it's had.
static func finish(save: SaveGame, i: int, perfect: bool) -> void:
	if save == null:
		return
	var d := _done(save)
	d[i] = maxi(int(d[i]), PERFECT if perfect else DONE)


static func done_count(save: SaveGame) -> int:
	var n := 0
	for i in count():
		n += 1 if status(save, i) != NOT_DONE else 0
	return n


## The lesson to start on: the first not done (the first, when all are).
static func next(save: SaveGame) -> int:
	for i in count():
		if status(save, i) == NOT_DONE:
			return i
	return 0


## The PRACTICE page's value: "3/8".
static func label(save: SaveGame) -> String:
	return "%d/%d" % [done_count(save), count()]
