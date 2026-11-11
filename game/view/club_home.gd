## CLUB's home (port ADR-106): the club between days. On the left the
## club at a glance (the day and its forecast, the cash, the members, the
## courts, the coach, the trophy shelf), on the right a MenuPage: OPEN THE
## PARK (the day, with you on court 1), END THE DAY (the rest of it runs
## without you), WEEKEND CUP (Saturdays), UPGRADES, STAFF (the coach and
## today's drill), MEMBERS (a card for each), LEDGER (last night's), NEW
## CLUB and BACK. After a day, the night's ledger shows first; a club the
## bank has called shows its last ledger and a new club starts.
class_name ClubHome
extends Control

signal open_day(club: Club)              ## OPEN THE PARK
signal drill(club: Club, lesson: int)    ## STAFF > TODAY'S DRILL
signal cup(club: Club)                   ## WEEKEND CUP
signal day_over(club: Club)              ## END THE DAY: the night
signal leave

const LOCK := MenuPage.TRANSITION
const GOLD := Color("fbe46a")
const DIM := Color(0.75, 0.78, 0.86)
const GOOD := Color("7be07b")
const BAD := Color("ff8a70")
const MEMBERS_PER_PAGE := 10
const STATUS := Rect2(24, 24, 420, 330)
const RIGHT := Rect2(470, 24, 466, 0)

var save: SaveGame
var club: Club
var page: MenuPage
var sub: MenuPage                 ## the open subpage (upgrades, staff, members), or null
var view := "home"                ## "home", "upgrades", "staff", "members", "ledger"
var report: Dictionary = {}       ## the night just ended, shown first
var member_page := 0
var new_armed := false
var end_armed := false
var fire_armed := false
var message := ""                 ## the help line under the panel, for tests
static var seed_override := 0      ## a new club's seed in the tests (0: the clock's)
var _lock := LOCK
var _status: Control
var _status_lines: Array = []
var _help: BitmapText
var _ledger: Control
var _rain: Node2D
var _sfx: Sfx
var _anim := 0


func setup(game_save: SaveGame, night: Dictionary = {}) -> ClubHome:
	save = game_save
	report = night
	club = Club.current(save)
	if club == null:
		club = Club.begin(save, seed_override if seed_override else Time.get_ticks_usec())
	return self


func music_track() -> String:
	return "park"


func _ready() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/park/ground.png")
	bg.centered = false
	bg.region_enabled = true
	bg.region_rect = Rect2(140, 150, 960, 540)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.55)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_rain = ClubWeather.new()
	_rain.home = self
	add_child(_rain)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	_build_status()
	_build_home()
	_help = UiKit.text("small", "", Vector2(480, 500), 0.5, GOLD, self)
	if not report.is_empty():
		_show_ledger(report)
	refresh()
	GameControls.clear_latch()


# --- The club at a glance -------------------------------------------------------------

func _build_status() -> void:
	_status = Control.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	UiKit.panel(STATUS, _status)
	UiKit.text("big_gold", "CLUB", Vector2(STATUS.position.x + 24, STATUS.position.y + 16), 0.0,
		Color.WHITE, _status)
	for k in 9:
		_status_lines.append(UiKit.text("small", "", Vector2(STATUS.position.x + 24,
			STATUS.position.y + 70 + k * 27), 0.0, Color.WHITE, _status))


## The club's lines, or, on MEMBERS, the selected member's card.
func status_lines() -> Array:
	if view == "members" and sub != null:
		var i := member_page * MEMBERS_PER_PAGE + sub.cursor
		if i < club.members.size():
			return member_card(club.members[i])
	var w := club.weather()
	var lines := [
		club.day_label() + "  " + Club.clock_label(club.minute),
		"FORECAST: " + Club.weather_name(w) + ("  INDOORS" if club.indoors() else ""),
		"CASH %d" % club.cash + ("  RED FOR %d DAYS" % club.red_days if club.red_days else ""),
		"MEMBERS %d/%d" % [club.members.size(), Club.MAX_MEMBERS],
		"COURTS %d   UPKEEP %d A DAY" % [club.courts(), club.upkeep()],
		"COACH: " + ("HIRED, %d A DAY" % club.coach_wage() if club.coach else "NONE"),
		"TROPHIES %d" % club.trophies.size(),
		"LAST NIGHT %+d" % int(club.ledger["net"]) if not club.ledger.is_empty() else "LAST NIGHT: NOTHING YET",
		"WAIT AT A COURT %d MIN" % int(club.ledger["wait"]) if not club.ledger.is_empty() else "",
	]
	return lines


func member_card(m: Dictionary) -> Array:
	var mood := int(m["m"])
	var feel := "HAPPY" if mood >= 2 else ("FINE" if mood >= 0 else ("GRUMPY" if mood > Club.MOOD_LEAVE + 1 else "ABOUT TO QUIT"))
	return [Club.member_name(m),
		"SKILL %d" % int(m["s"]),
		"PATIENCE %d MIN" % int(m["p"]),
		"MOOD: " + feel,
		"MEMBER SINCE DAY %d" % int(m["d"]),
		"COACHED %d DAYS" % int(m["c"]),
		"", "", ""]


func _refresh_status() -> void:
	var lines := status_lines()
	for k in _status_lines.size():
		var t: BitmapText = _status_lines[k]
		t.text = String(lines[k]) if k < lines.size() else ""
		t.tint = GOLD if k == 0 else (BAD if t.text.contains("RED FOR") or t.text.ends_with("QUIT") else Color.WHITE)


# --- Home -----------------------------------------------------------------------------

func _build_home() -> void:
	if page:
		_drop(page)
	var rows := []
	rows.append({"id": "open", "label": "OPEN THE PARK", "value": func(): return _open_value(),
		"press": func(): _open()})
	rows.append({"id": "end", "label": "END THE DAY", "value": func(): return "PRESS AGAIN" if end_armed else "",
		"press": func(): _end()})
	rows.append({"id": "cup", "label": "WEEKEND CUP", "value": func(): return _cup_value(),
		"press": func(): _cup()})
	rows.append({"id": "upgrades", "label": "UPGRADES", "value": func(): return "%d/%d" % [
		club.upgrades.size(), Club.UPGRADES.size()], "press": func(): _open_sub("upgrades")})
	rows.append({"id": "staff", "label": "STAFF", "value": func(): return "COACH" if club.coach else "",
		"press": func(): _open_sub("staff")})
	rows.append({"id": "members", "label": "MEMBERS", "value": func(): return str(club.members.size()),
		"press": func(): _open_sub("members")})
	rows.append({"id": "ledger", "label": "LEDGER", "value": func(): return "DAY %d" % int(club.ledger["day"]) if not club.ledger.is_empty() else "",
		"press": func(): _show_ledger(club.ledger)})
	rows.append({"id": "new", "label": "NEW CLUB", "value": func(): return "PRESS AGAIN" if new_armed else "",
		"press": func(): _new()})
	rows.append({"id": "back", "label": "BACK", "press": func(): _leave()})
	page = MenuPage.new().setup("club", "", rows,
		Rect2(RIGHT.position, Vector2(RIGHT.size.x, 18 + rows.size() * MenuPage.ROW_H + 50)),
		[["hit", "SELECT"], ["back", "BACK"]])
	add_child(page)
	page.pressed.connect(func(_id): refresh())
	page.back_requested.connect(_on_back)


func _open_value() -> String:
	if club.park_closed():
		return "CLOSED: RAIN"
	if club.closed_for_today():
		return "CLOSED FOR TODAY"
	if club.minute > Club.OPEN:
		return "TILL " + Club.clock_label(club.closing())
	return Club.weather_name(club.weather()) + (" AT THE GYM" if club.indoors() else "")


func _cup_value() -> String:
	if String(club.today["cup"]) != "":
		return String(club.today["cup"])
	if not club.saturday():
		return "SATURDAYS"
	return "NO: RAIN" if club.park_closed() else "TODAY"


func _open() -> void:
	if club.park_closed() or club.closed_for_today():
		_beep("back")
		return
	_beep("confirm")
	club.store(save)
	open_day.emit(club)


func _end() -> void:
	if not end_armed:
		end_armed = true
		_beep("blip")
		return
	_beep("confirm")
	end_armed = false
	day_over.emit(club)


func _cup() -> void:
	if not club.cup_ready():
		_beep("back")
		return
	_beep("confirm")
	club.store(save)
	cup.emit(club)


func _new() -> void:
	if not new_armed:
		new_armed = true
		_beep("blip")
		return
	_beep("confirm")
	new_armed = false
	club = Club.begin(save, seed_override if seed_override else Time.get_ticks_usec())
	save.save_game()
	refresh()


func _leave() -> void:
	_beep("back")
	club.store(save)
	leave.emit()


func _on_back() -> void:
	match view:
		"ledger":
			_close_ledger()
		"home":
			_leave()
		_:
			_close_sub()


# --- UPGRADES, STAFF, MEMBERS -----------------------------------------------------------

func _open_sub(which: String) -> void:
	_beep("confirm")
	view = which
	page.visible = false
	fire_armed = false
	var rows := []
	var title := which.to_upper()
	match which:
		"upgrades":
			for u: Dictionary in Club.UPGRADES:
				var id := String(u["id"])
				rows.append({"id": id, "label": String(u["name"]),
					"value": func(): return _upgrade_value(id),
					"press": func(): _buy(id)})
		"staff":
			rows.append({"id": "coach", "label": "COACH", "value": func(): return _coach_value(),
				"press": func(): _coach()})
			rows.append({"id": "drill", "label": "TODAY'S DRILL", "value": func(): return _drill_value(),
				"press": func(): _drill()})
		"members":
			for k in MEMBERS_PER_PAGE:
				rows.append({"id": "m%d" % k, "label": func(): return _member_label(k),
					"value": func(): return _member_value(k)})
			rows.append({"id": "page", "label": "PAGE", "value": func(): return "%d/%d" % [
				member_page + 1, member_pages()], "change": func(d): _turn(d)})
	rows.append({"id": "back", "label": "BACK", "press": func(): _close_sub()})
	sub = MenuPage.new().setup(which, title, rows,
		Rect2(RIGHT.position, Vector2(RIGHT.size.x, 64 + rows.size() * MenuPage.ROW_H + 50)),
		[["hit", "SELECT"], ["back", "BACK"]] if which != "members" else [["dpad", "PAGE"], ["back", "BACK"]])
	add_child(sub)
	sub.back_requested.connect(_close_sub)
	sub.pressed.connect(func(_id): refresh())
	_lock = LOCK
	refresh()


func _close_sub() -> void:
	_beep("back")
	view = "home"
	if sub:
		_drop(sub)
		sub = null
	page.visible = true
	_lock = LOCK
	refresh()


func _upgrade_value(id: String) -> String:
	var why := club.why_not(id)
	if why == "OWNED" or why.begins_with("NEEDS "):
		return why
	return "%d" % int(Club.upgrade(id)["price"])


func _buy(id: String) -> void:
	if club.buy(id):
		_beep("confirm")
		club.store(save)
		save.save_game()
	else:
		_beep("back")


func _coach_value() -> String:
	if club.coach:
		return "PRESS AGAIN TO LET GO" if fire_armed else "HIRED, %d A DAY" % club.coach_wage()
	return "HIRE: %d" % Club.COACH_FEE


func _coach() -> void:
	if club.coach:
		if not fire_armed:
			fire_armed = true
			_beep("blip")
			return
		fire_armed = false
		club.let_coach_go()
		_beep("back")
	elif club.hire_coach():
		_beep("confirm")
	else:
		_beep("back")
	club.store(save)
	save.save_game()


func _drill_value() -> String:
	if not club.coach:
		return "NO COACH"
	if bool(club.today["drill"]):
		return "DONE TODAY"
	return String(Tutorial.LESSONS[club.drill_lesson()]["title"])


func _drill() -> void:
	if not club.drill_ready():
		_beep("back")
		return
	_beep("confirm")
	club.store(save)
	drill.emit(club, club.drill_lesson())


func member_pages() -> int:
	return maxi(1, (club.members.size() + MEMBERS_PER_PAGE - 1) / MEMBERS_PER_PAGE)


func _turn(d: int) -> void:
	member_page = (member_page + d + member_pages()) % member_pages()
	refresh()


func _member_label(k: int) -> String:
	var i := member_page * MEMBERS_PER_PAGE + k
	return Club.member_name(club.members[i]) if i < club.members.size() else ""


func _member_value(k: int) -> String:
	var i := member_page * MEMBERS_PER_PAGE + k
	return "SKILL %d" % int(club.members[i]["s"]) if i < club.members.size() else ""


# --- The ledger -------------------------------------------------------------------------

## A night's ledger as lines: [text, amount or null, tint].
static func ledger_lines(l: Dictionary) -> Array:
	var out := []
	for line: Array in l["lines"]:
		var n := int(line[1])
		out.append([String(line[0]), "%+d" % n, GOOD if n > 0 else (BAD if n < 0 else DIM)])
	var net := int(l["net"])
	out.append(["THE NIGHT", "%+d" % net, GOOD if net >= 0 else BAD])
	out.append(["CASH", str(int(l["cash"])), GOLD])
	var left: Array = l["left"]
	out.append(["MEMBERS %d" % int(l["members"]), "+%d  -%d" % [int(l["joined"]), left.size()], DIM])
	out.append(["GAMES %d OF %d" % [int(l["played"]), int(l["capacity"])],
		"WAIT %d MIN" % int(l["wait"]), DIM])
	out.append(["YOU WON %d, LOST %d" % [int(l["wins"]), int(l["losses"])], "", DIM])
	if String(l["cup"]) != "":
		out.append(["WEEKEND CUP", String(l["cup"]), GOLD if bool(l["cup_won"]) else DIM])
	return out


func _show_ledger(l: Dictionary) -> void:
	if l.is_empty():
		_beep("back")
		return
	_beep("confirm")
	view = "ledger"
	page.visible = false
	_ledger = Control.new()
	_ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ledger)
	var lines := ledger_lines(l)
	var h := 96 + lines.size() * 26 + 40
	UiKit.panel(Rect2(RIGHT.position, Vector2(RIGHT.size.x, h)), _ledger)
	var title := "LEDGER, DAY %d" % int(l["day"])
	UiKit.text("big_gold", title, Vector2(RIGHT.get_center().x, RIGHT.position.y + 16), 0.5,
		Color.WHITE, _ledger)
	UiKit.text("small", "%s, %s" % [Club.WEEKDAYS[int(l["weekday"])], Club.weather_name(int(l["weather"]))],
		Vector2(RIGHT.get_center().x, RIGHT.position.y + 60), 0.5, DIM, _ledger)
	for k in lines.size():
		var y := RIGHT.position.y + 96 + k * 26
		var line: Array = lines[k]
		UiKit.text("small", String(line[0]), Vector2(RIGHT.position.x + 28, y), 0.0, Color.WHITE, _ledger)
		UiKit.text("small", String(line[1]), Vector2(RIGHT.end.x - 28, y), 1.0, line[2], _ledger)
	var why := ""
	if bool(l.get("bust", false)):
		why = "THE BANK CALLED: THE CLUB IS CLOSED"
	elif not (l["left"] as Array).is_empty():
		why = "LEFT: " + ", ".join((l["left"] as Array).slice(0, 3)) + \
			(" AND MORE" if (l["left"] as Array).size() > 3 else "")
	var p := PromptBar.new().setup([["hit", "OK"]], Vector2(RIGHT.get_center().x, RIGHT.position.y + h - 22))
	_ledger.add_child(p)
	message = why
	_lock = LOCK


func _close_ledger() -> void:
	_beep("confirm")
	view = "home"
	if _ledger:
		_drop(_ledger)
		_ledger = null
	page.visible = true
	report = {}
	# the bank called: the club is gone, a new one opens
	if club.state != "on":
		club = Club.begin(save, seed_override if seed_override else Time.get_ticks_usec())
		save.save_game()
	_lock = LOCK
	refresh()


# --- Frame -------------------------------------------------------------------------------

func refresh() -> void:
	if page:
		page.refresh()
	if sub:
		sub.refresh()
	_refresh_status()
	if view == "upgrades" and sub:
		var id := sub.current_id()
		message = String(Club.upgrade(id).get("what", "")) if id != "back" else ""
	elif view == "staff" and sub:
		message = "THE COACH'S DRILLS RAISE THE MEMBERS' SKILL" if sub.current_id() == "coach" else \
			"A HOW TO PLAY DRILL WITH THE COACH, ONCE A DAY"
	elif view == "members":
		message = "A MEMBER KEPT WAITING TOO LONG, TOO OFTEN, LEAVES"
	elif view == "home":
		message = _home_help()
	if _help:
		_help.text = message


func _home_help() -> String:
	match page.current_id():
		"open":
			if club.park_closed():
				return "RAIN: THE OUTDOOR COURTS ARE SHUT. INDOOR COURTS FIX THAT."
			return "PLAY ON COURT 1 WHILE THE MEMBERS PLAY. CLOSES AT " + Club.clock_label(club.closing())
		"end":
			return "THE MEMBERS PLAY ON WITHOUT YOU, THEN THE LEDGER"
		"cup":
			return "SATURDAYS: EIGHT TEAMS, ENTRY FEES, A TROPHY FOR THE SHELF"
	return ""


func _process(_delta: float) -> void:
	_anim += 1
	_rain.queue_redraw()
	if _lock > 0:
		_lock -= 1
		return
	match view:
		"ledger":
			if Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start") \
					or Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
				_close_ledger()
		"home":
			var nav := page.drive()
			if nav & MenuPage.NAV_MOVED:
				new_armed = false
				end_armed = false
				_beep("blip")
				refresh()
			if nav & MenuPage.NAV_PRESSED:
				refresh()
			if nav & MenuPage.NAV_BACK:
				_leave()
		_:
			if sub == null:
				return
			var nav2 := sub.drive()
			if nav2 & (MenuPage.NAV_MOVED | MenuPage.NAV_CHANGED):
				fire_armed = false
				_beep("blip")
				refresh()
			if nav2 & MenuPage.NAV_PRESSED:
				refresh()
			if nav2 & MenuPage.NAV_BACK:
				_close_sub()


## Out of the screen at once (a page closing from its own signal can't be
## freed there), freed at the frame's end.
func _drop(n: Node) -> void:
	if n.get_parent() == self:
		remove_child(n)
	n.queue_free()


func _beep(name: String) -> void:
	if _sfx:
		_sfx.play(name)


## Rain falling over the home on a wet day (display only).
class ClubWeather:
	extends Node2D

	var home: ClubHome

	func _draw() -> void:
		if home == null or home.club == null:
			return
		var w := home.club.weather()
		if w == Club.RAIN or w == Club.SHOWERS:
			ClubWeather.draw_rain(self, home._anim, 90 if w == Club.RAIN else 40)


	## Streaks of rain over the screen, moving with `frame`.
	static func draw_rain(c: CanvasItem, frame: int, count: int) -> void:
		var col := Color(0.78, 0.85, 1.0, 0.6)
		for i in count:
			var x := float((i * 97 + frame * 3) % 1000) - 20.0
			var y := float((i * 61 + frame * 11) % 580) - 20.0
			c.draw_line(Vector2(x, y), Vector2(x - 4, y + 14), col, 1.5)
