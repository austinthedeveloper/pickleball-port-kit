## The update screen (PORT-34, ADR-057 amended): the first thing an
## exported desktop game shows. It checks for a newer version; if there is
## one it downloads it at once (no skipping: friends need the same version
## to play online), with a progress bar, then says INSTALLED and restarts
## on it. Up to date, it goes straight on to the title.
##
## The only ways past it are the cases where updating in-game can't work:
## no answer (offline, after CHECK_TIMEOUT), a failed download (RETRY or
## PLAY THIS VERSION), or a release that needs a full download (GET IT, or
## PLAY THIS VERSION). Without them a dropped line would lock you out.
class_name UpdateScreen
extends Node2D

signal done                      ## on to the title

const CHECK_TIMEOUT := 8.0       ## seconds of no answer before going on
const RESTART_FRAMES := 75       ## INSTALLED shows this long, then the restart
const GOLD := Color("fbe46a")
const DIM := Color(0.7, 0.75, 0.9)

var updater: Updater
var page: MenuPage               ## RETRY / GET IT / PLAY THIS VERSION, when there's a choice
var _page_ids: Array = []
var _ui: CanvasLayer
var _lines: Array = []
var _bar_back: ColorRect
var _bar: ColorRect
var _waited := 0.0
var _ready_frames := 0
var _sfx: Sfx
var _finished := false
var _shown_state := -1


## Wanted only where updating works (an exported desktop game).
static func wanted() -> bool:
	return Updater.instance != null and Updater.instance.state != Updater.OFF


func setup(u: Updater) -> UpdateScreen:
	updater = u
	return self


func music_track() -> String:
	return "title"


func _ready() -> void:
	if _ui:
		return
	var back := ColorRect.new()
	back.color = Color(0.03, 0.06, 0.14, 1.0)
	back.size = Vector2(960, 540)
	add_child(back)
	_ui = CanvasLayer.new()
	add_child(_ui)
	UiKit.panel(Rect2(300, 60, 360, 58), _ui)
	UiKit.text("big_gold", "UPDATE", Vector2(480, 72), 0.5, Color.WHITE, _ui)
	UiKit.panel(Rect2(140, 150, 680, 190), _ui)
	for i in 3:
		_lines.append(UiKit.text("small", "", Vector2(480, 172 + i * 30), 0.5, Color.WHITE, _ui))
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.08, 0.1, 0.2)
	_bar_back.position = Vector2(190, 278)
	_bar_back.size = Vector2(580, 22)
	_ui.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = GOLD
	_bar.position = _bar_back.position + Vector2(3, 3)
	_bar.size = Vector2(0, 16)
	_ui.add_child(_bar)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	refresh()


func _retry() -> void:
	_waited = 0.0
	if updater.state == Updater.FAILED and updater.manifest.is_empty():
		updater.check()
	else:
		updater.state = Updater.AVAILABLE
		updater.download()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit()


## What the screen says, and which choices it offers, for the updater's state.
func lines() -> Array:
	var u := updater
	var mb := func(b: float) -> String: return "%.1f" % (b / 1048576.0)
	match u.state:
		Updater.IDLE, Updater.CHECKING:
			return ["CHECKING FOR A NEW VERSION...", "", ""]
		Updater.AVAILABLE, Updater.DOWNLOADING:
			var total := float(u.manifest.get("size", 0))
			return ["VERSION %s IS OUT." % u.latest, "DOWNLOADING IT NOW.",
				"%s OF %s MB" % [mb.call(total * u.progress()), mb.call(total)]]
		Updater.READY:
			if _ready_frames > RESTART_FRAMES + 30:   # the restart didn't start
				return ["VERSION %s IS INSTALLED." % u.latest, "CLOSE THE GAME AND OPEN IT AGAIN.", ""]
			return ["VERSION %s IS INSTALLED." % u.latest, "RESTARTING...", ""]
		Updater.FULL:
			return ["VERSION %s IS OUT." % u.latest, "IT NEEDS A FULL DOWNLOAD FROM", "THE RELEASES PAGE."]
		Updater.FAILED:
			if u.manifest.is_empty():
				return ["COULDN'T CHECK FOR UPDATES.", u.error, ""]
			return ["THE DOWNLOAD DIDN'T FINISH.", u.error, ""]
	return ["", "", ""]


## The choices: none while checking, downloading or restarting.
func choices() -> Array:
	match updater.state:
		Updater.FULL:
			return ["get", "play"]
		Updater.FAILED:
			return ["retry", "play"]
	return []


func refresh() -> void:
	var ls := lines()
	for i in 3:
		_lines[i].text = ls[i]
		_lines[i].tint = GOLD if i == 0 else (DIM if i == 2 else Color.WHITE)
	var downloading := updater.state in [Updater.AVAILABLE, Updater.DOWNLOADING, Updater.READY]
	_bar_back.visible = downloading
	_bar.visible = downloading
	var p := 1.0 if updater.state == Updater.READY else updater.progress()
	_bar.size.x = (_bar_back.size.x - 6) * p
	_build_page(choices())


const ROWS := {"retry": "RETRY", "get": "GET THE FULL DOWNLOAD", "play": "PLAY THIS VERSION"}


## The choices as a page, rebuilt when they change (none: no page).
func _build_page(ids: Array) -> void:
	if ids == _page_ids:
		return
	_page_ids = ids
	if page:
		page.queue_free()
		page = null
	if ids.is_empty():
		return
	var rows := []
	for id in ids:
		var press: Callable = {"retry": _retry, "get": func(): updater.open_page(), "play": _finish}[id]
		rows.append({"id": id, "label": ROWS[id], "press": press})
	page = MenuPage.new().setup("update", "", rows, Rect2(260, 356, 440, 18 + ids.size() * 28 + 52),
		[["hit", "SELECT"]])
	page.pressed.connect(func(_id): _sfx.play("confirm"))
	_ui.add_child(page)


func _process(delta: float) -> void:
	if _finished:
		return
	var st := updater.state
	if st != _shown_state:
		_shown_state = st
		if st == Updater.READY:
			_sfx.play("confirm")
	match st:
		Updater.LATEST, Updater.OFF:
			_finish()
			return
		Updater.IDLE, Updater.CHECKING:
			_waited += delta
			if _waited >= CHECK_TIMEOUT:
				_finish()                    # no answer: play what we have
				return
		Updater.AVAILABLE:
			updater.download()               # at once: no skipping
		Updater.FAILED:
			if updater.error == "OFFLINE" and updater.manifest.is_empty():
				_finish()                    # no network at all: play what we have
				return
		Updater.READY:
			_ready_frames += 1
			if _ready_frames == RESTART_FRAMES:
				updater.restart()
	refresh()
	if page == null:
		return
	if GameControls.menu_pressed("move_up"):
		page.move(-1)
		_sfx.play("blip")
	elif GameControls.menu_pressed("move_down"):
		page.move(1)
		_sfx.play("blip")
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		_sfx.play("confirm")
		page.press()
