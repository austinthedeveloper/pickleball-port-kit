## ONLINE (PORT-31, ADR-056): 1v1 with a friend over the internet or the
## same Wi-Fi, by address. One of you HOSTS (the screen shows your
## addresses and waits); the other types the host's ADDRESS and JOINS.
## Once you've both said hello, the host starts: singles on the host's
## COURT, POINTS and MODIFIERS, each of you in your Player Select look.
## The address is typed on a keyboard (or pasted); it's kept in the save.
class_name OnlineScreen
extends Node2D

signal play(session: OnlineSession)
signal leave

const LOCK := MenuPage.TRANSITION
const DIM := Color(0.7, 0.75, 0.9)
const GOLD := Color("fbe46a")
const RED := Color("ff7060")
const ALLOWED := "0123456789.:-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const MAX_ADDRESS := 32

var save: SaveGame
var session: OnlineSession
var page: MenuPage
var address := ""
var port := ENetLink.PORT        ## tests use another
var editing := false
var last_reason := ""
var _lock := LOCK
var _sfx: Sfx
var _ui: CanvasLayer
var _lines: Array = []           ## the info panel's three lines
var _frame := 0


func setup(game_save: SaveGame) -> OnlineScreen:
	save = game_save
	if save:
		address = String(save.data["settings"].get("net_address", ""))
	return self


func music_track() -> String:
	return "title"


func _ready() -> void:
	if page:
		return                           # built already (tests and tools call it early)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.06, 0.14, 1.0)
	back.size = Vector2(960, 540)
	add_child(back)
	_ui = CanvasLayer.new()
	add_child(_ui)
	UiKit.panel(Rect2(300, 10, 360, 58), _ui)
	UiKit.text("big_gold", "ONLINE", Vector2(480, 22), 0.5, Color.WHITE, _ui)
	UiKit.text("small", "1 VS 1, SINGLES", Vector2(480, 76), 0.5, DIM, _ui)
	page = MenuPage.new().setup("online", "", [
		{"id": "host", "label": func(): return _host_label(), "value": func(): return _host_value(),
			"press": _press_host},
		{"id": "address", "label": "ADDRESS", "value": func(): return _address_value(),
			"press": _press_address},
		{"id": "join", "label": "JOIN", "value": func(): return _join_value(), "press": _press_join},
		{"id": "back", "label": "BACK", "press": func(): _leave()},
	], Rect2(110, 104, 740, 190), [["hit", "SELECT"], ["back", "BACK"]])
	page.pressed.connect(func(_id): page.refresh())
	page.back_requested.connect(_leave)
	_ui.add_child(page)
	UiKit.panel(Rect2(60, 312, 840, 120), _ui)
	for i in 3:
		_lines.append(UiKit.text("small", "", Vector2(480, 330 + i * 30), 0.5, Color.WHITE, _ui))
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup("", false)
	refresh()
	GameControls.clear_latch()


# --- The rows -------------------------------------------------------------------

func _state() -> int:
	return session.state if session else OnlineSession.IDLE


func _host_label() -> String:
	if session and session.host and _state() == OnlineSession.CONNECTED:
		return "START MATCH"
	return "HOST A MATCH"


func _host_value() -> String:
	if session and session.host and _state() == OnlineSession.WAITING:
		return "WAITING..."
	return ""


func _address_value() -> String:
	if editing:
		return address + ("_" if (_frame / 20) % 2 == 0 else " ")
	return address if address != "" else "TYPE IT"


func _join_value() -> String:
	if session and not session.host and _state() == OnlineSession.WAITING:
		return "CALLING..."
	return ""


## The Web build has no UDP (ENet): online needs the desktop game.
static func available() -> bool:
	return not OS.has_feature("web")


func _press_host() -> void:
	if not available():
		last_reason = "ONLINE NEEDS THE DESKTOP GAME"
		return
	if session and session.host and _state() == OnlineSession.CONNECTED:
		_start_match()
		return
	_close_session()
	var link := ENetLink.new()
	if not link.host(port):
		last_reason = link.error
		_sfx.play("back")
		return
	_open(link, true)


func _press_address() -> void:
	editing = not editing
	if not editing:
		_store_address()


func _press_join() -> void:
	if not available():
		last_reason = "ONLINE NEEDS THE DESKTOP GAME"
		return
	if address.strip_edges() == "":
		page.select("address")
		editing = true
		return
	_close_session()
	_store_address()
	var link := ENetLink.new()
	if not link.join(address.to_lower(), port):
		last_reason = link.error
		_sfx.play("back")
		return
	_open(link, false)


func _open(link: NetLink, is_host: bool) -> void:
	last_reason = ""
	session = OnlineSession.new(link, is_host)
	session.my_hello = OnlineSession.hello(Settings.p1_choice, _my_name())
	_sfx.play("confirm")


func _my_name() -> String:
	var me: Career.Player = save.career.active_player() if save else null
	return me.shown_name() if me else ""


## The host's match: singles on the COURT, POINTS and MODIFIERS settings;
## the guest in their look, in another shirt if both picked the same.
func _start_match() -> void:
	var mine: Dictionary = Settings.p1_choice
	var theirs: Dictionary = session.peer_hello.get("look", {})
	if theirs.is_empty():
		theirs = PlayerSelect.new_choice(PlayerSelect.PAL_RED, K.VARIANT_MALE, Paddles.STANDARD)
	theirs = theirs.duplicate()
	for k in theirs:
		theirs[k] = int(theirs[k])
	if theirs["palette"] == mine["palette"]:
		theirs["palette"] = (int(mine["palette"]) + 1) % PlayerSelect.PAL_COUNT
	var cfg := PlayerSelect.config_select(K.MODE_SINGLES, mine, theirs)
	cfg.points_to_win = Settings.POINTS[Settings.points_i]
	cfg.modifiers = Settings.mod_bits
	session.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": Settings.venue(),
		"time": Settings.time_i, "court": Settings.court.duplicate()})
	_sfx.play("confirm")
	play.emit(session)


func _store_address() -> void:
	if save:
		save.data["settings"]["net_address"] = address
		save.save_game()


func _close_session() -> void:
	if session:
		session.quit()
	session = null


func _leave() -> void:
	if editing:
		editing = false
		_store_address()
		return
	_close_session()
	if _sfx:
		_sfx.play("back")
	leave.emit()


# --- The info panel -----------------------------------------------------------

## This machine's addresses worth telling a friend: the LAN's and a VPN's
## (Tailscale's 100.64/10), IPv4, not loopback or link-local.
static func my_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if ":" in a or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		out.append(a)
	out.sort_custom(func(x, y): return (0 if x.begins_with("192.168.") else 1) < (0 if y.begins_with("192.168.") else 1))
	return out.slice(0, 2)


func info() -> Array:
	var st := _state()
	if session and session.closed():
		return [session.reason if session.reason != "" else "DISCONNECTED", "", ""]
	if st == OnlineSession.IDLE:
		if last_reason != "":
			return [last_reason, "", ""]
		return ["ONE OF YOU HOSTS. THE OTHER TYPES THE", "HOST'S ADDRESS AND JOINS.",
			"SAME WI-FI JUST WORKS. FAR AWAY: SEE THE README."]
	if st == OnlineSession.WAITING:
		if session.host:
			var mine := my_addresses()
			return ["WAITING FOR YOUR FRIEND, PORT %d." % ENetLink.PORT,
				"YOUR ADDRESS: " + ("   ".join(mine) if not mine.is_empty() else "?"), ""]
		return ["CALLING " + address + "...", "", ""]
	if st == OnlineSession.CONNECTED:
		var them := String(session.peer_hello.get("name", ""))
		var line := "CONNECTED TO " + (them if them != "" else "YOUR FRIEND") + "!"
		if session.host:
			return [line, "%s   %s   TO %d" % [Settings.VENUE_NAMES[Settings.venue_i],
				"SINGLES", Settings.POINTS[Settings.points_i]], "START MATCH WHEN YOU'RE READY."]
		return [line, "WAITING FOR THE HOST TO START.", ""]
	return ["", "", ""]


func refresh() -> void:
	var lines := info()
	for i in 3:
		_lines[i].text = lines[i]
		_lines[i].tint = RED if i == 0 and session and session.closed() or (i == 0 and last_reason != ""
			and _state() == OnlineSession.IDLE) else (GOLD if i == 0 else Color.WHITE)
	page.refresh()


# --- Frame ------------------------------------------------------------------------

## Typing the address: a key press is a character (or Backspace, or a
## paste); Enter or Esc ends it. The keys don't reach the menu.
func _input(event: InputEvent) -> void:
	if not editing or not (event is InputEventKey) or not event.pressed:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_BACKSPACE:
		address = address.left(maxi(0, address.length() - 1))
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		editing = false
		_store_address()
		_lock = LOCK
	elif k.keycode == KEY_V and (k.ctrl_pressed or k.meta_pressed):
		_type(DisplayServer.clipboard_get())
	elif k.unicode > 0:
		_type(char(k.unicode))
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	page.refresh()


func _type(s: String) -> void:
	for c in s.to_upper():
		if c in ALLOWED and address.length() < MAX_ADDRESS:
			address += c


func _process(_delta: float) -> void:
	_frame += 1
	if session:
		var was := session.state
		session.poll()
		if session.state == OnlineSession.CONNECTED and was == OnlineSession.WAITING:
			_sfx.play("confirm")
		if session.state == OnlineSession.PLAYING and not session.host:
			play.emit(session)               # the host started
			return
	refresh()
	if editing:
		return
	if _lock > 0:
		_lock -= 1
		return
	if GameControls.menu_pressed("move_up"):
		page.move(-1)
		_sfx.play("blip")
	elif GameControls.menu_pressed("move_down"):
		page.move(1)
		_sfx.play("blip")
	if Input.is_action_just_pressed("soft") or Input.is_action_just_pressed("drive"):
		_leave()
	elif Input.is_action_just_pressed("hit") or Input.is_action_just_pressed("start"):
		if page.press():
			_sfx.play("blip")
