## HOW TO PLAY's overlay (PORT-30) over a lesson's match: the lesson card
## first (the match waits under it, like the intro card), then a banner
## with the lesson and its progress and a strip for advice after a miss,
## then LESSON DONE! before the next. Reads the view's Tutorial; display
## only.
class_name TutorialView
extends Control

const CARD_MIN_FRAMES := 30
const DONE_FRAMES := 100
const GOLD := Color("fbe46a")

var view: MatchView
var t: Tutorial
var card_frames := 0                 ## -1 once the card is closed
var done_frames := -1                ## counting up once the lesson's done
var _card: Control
var _banner: Control
var _title: BitmapText
var _progress: BitmapText
var _advice: Control
var _advice_text: BitmapText
var _done: Control


func setup(v: MatchView) -> TutorialView:
	view = v
	t = v.lesson
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	_banner = Control.new()
	add_child(_banner)
	UiKit.panel(Rect2(14, 470, 340, 58), _banner)
	_title = UiKit.text("small", t.lesson()["title"], Vector2(30, 480), 0.0, GOLD, _banner)
	_progress = UiKit.text("small", "", Vector2(30, 502), 0.0, Color.WHITE, _banner)
	_advice = Control.new()
	add_child(_advice)
	UiKit.panel(Rect2(150, 420, 660, 40), _advice)
	_advice_text = UiKit.text("small", "", Vector2(480, 431), 0.5, GOLD, _advice)
	_done = Control.new()
	add_child(_done)
	UiKit.panel(Rect2(280, 196, 400, 96), _done, "gold")
	var last := t.index == Tutorial.LESSONS.size() - 1
	UiKit.text("big_gold", "ALL DONE!" if last else "LESSON DONE!", Vector2(480, 212), 0.5,
		Color.WHITE, _done)
	UiKit.text("small", "NOW GO WIN ONE." if last else "NEXT: " + String(
		Tutorial.LESSONS[t.index + 1]["title"]), Vector2(480, 258), 0.5, Color.WHITE, _done)
	refresh()
	return self


func _build_card() -> void:
	_card = Control.new()
	add_child(_card)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.5)
	shade.size = Vector2(960, 540)
	_card.add_child(shade)
	UiKit.panel(Rect2(170, 112, 620, 286), _card)
	var l: Dictionary = t.lesson()
	UiKit.text("small", "LESSON %d OF %d" % [t.index + 1, Tutorial.LESSONS.size()], Vector2(480, 128),
		0.5, Color(0.7, 0.75, 0.9), _card)
	UiKit.text("big_gold", l["title"], Vector2(480, 152), 0.5, Color.WHITE, _card)
	var y := 210.0
	for line in l["lines"]:
		UiKit.text("small", line, Vector2(480, y), 0.5, Color.WHITE, _card)
		y += 26
	var goal := UiKit.text("small", "GOAL: %d %s" % [l["goal"], l["count"]], Vector2(480, y + 8), 0.5,
		GOLD, _card)
	goal.name = "Goal"
	_card.add_child(PromptBar.new().setup(l["prompts"], Vector2(480, 330)))
	_card.add_child(PromptBar.new().setup([["hit", "START"]], Vector2(480, 370)))


## The card holds the match until it's closed (after CARD_MIN_FRAMES).
func blocking() -> bool:
	return card_frames >= 0


## One frame while blocking: a press closes the card, and the press
## doesn't swing (the view's input lock, rule 9).
func update_card(pressed: bool) -> void:
	card_frames += 1
	if card_frames >= CARD_MIN_FRAMES and pressed:
		card_frames = -1
		view.input_lock = MatchView.INPUT_LOCK_FRAMES
		GameControls.clear_latch()
	refresh()


## Counting LESSON DONE!: true when it's time for the next lesson.
func update_done() -> bool:
	if done_frames < 0:
		done_frames = 0
	done_frames += 1
	refresh()
	return done_frames >= DONE_FRAMES


func refresh() -> void:
	_card.visible = card_frames >= 0
	_banner.visible = card_frames < 0
	_progress.text = t.progress_text()
	_advice.visible = card_frames < 0 and t.message != "" and done_frames < 0
	_advice_text.text = t.message
	_done.visible = done_frames >= 0
