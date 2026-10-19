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
		return address + ("/" if (_frame / 20) % 2 == 0 else " ")   # the cursor (the font has no _)
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

## This machine's addresses worth telling a friend, labelled by the
## adapter they're on: [[label, address]], at most two. Home-network
## addresses (192.168 first, then 10 and 172.16) before a Tailscale one;
## virtual adapters (WSL, Hyper-V, VirtualBox, VMware, Docker, bridges)
## are left out: nobody else can reach them. A computer can have more than
## one home-network address (Wi-Fi and Ethernet, or a VPN's): all are
## shown, since only the friend's side can tell which one answers.
static func my_addresses() -> Array:
	return pick_addresses(IP.get_local_interfaces())


## The same from a list of interfaces ({name, friendly, addresses}), for
## tests.
static func pick_addresses(interfaces: Array) -> Array:
	var lan := []
	var vpn := []
	for i in interfaces:
		var name := (String(i.get("friendly", "")) + " " + String(i.get("name", ""))).to_lower()
		for a in i.get("addresses", []):
			var kind := address_kind(String(a), name)
			if kind == "TAILSCALE":
				vpn.append(["TAILSCALE", a])
			elif kind != "":
				lan.append([adapter_label(String(i.get("friendly", "")), String(i.get("name", ""))), a])
	# the home router's range first; on one range, a wired adapter before
	# Wi-Fi (a Wi-Fi network Windows calls Public can block a friend's
	# call; 0.12.0's tester found the Ethernet address answered)
	lan.sort_custom(func(x, y): return _rank(x[1]) * 2 + _wifi(x[0]) < _rank(y[1]) * 2 + _wifi(y[0]))
	var out: Array = lan.slice(0, 2 if vpn.is_empty() else 1) + vpn.slice(0, 1)
	return out


static func _wifi(label: String) -> int:
	return 1 if "WI-FI" in label or "WIFI" in label or "WLAN" in label or "WIRELESS" in label else 0


static func _rank(a: String) -> int:
	if a.begins_with("192.168."):
		return 0
	if a.begins_with("10."):
		return 1
	return 2


## An adapter's name as the font can draw it ("WI-FI", "ETHERNET 2",
## "EN0"), or "HOME NETWORK".
static func adapter_label(friendly: String, name: String) -> String:
	var n := friendly if friendly != "" and not friendly.begins_with("{") else name
	# an id, not a name: en0, eth0, wlan0, enp3s0 (Windows' "Ethernet" is a name)
	if RegEx.create_from_string("^(en|eth|wlan|wlp|enp|eno)[0-9][0-9a-z]*$").search(n.to_lower()):
		return "NETWORK"                  # macOS and Linux name adapters en0, eth0...
	var out := ""
	for c in n.to_upper():
		if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- ":
			out += c
	out = out.strip_edges().left(14)
	return out if out != "" else "HOME NETWORK"


const VIRTUAL := ["vethernet", "wsl", "hyper-v", "virtualbox", "vbox", "vmware", "vmnet",
	"docker", "veth", "br-", "bridge", "npcap", "loopback", "utun", "awdl", "llw"]
const PHYSICAL := ["wi-fi", "wifi", "wlan", "ethernet", "eth", "en0", "en1", "wlp", "enp", "eno"]


## How a friend would reach an address on an interface (`name`, lowercase):
## "SAME WI-FI", "TAILSCALE", or "" (don't offer it).
static func address_kind(a: String, name: String) -> String:
	if ":" in a or a.begins_with("127.") or a.begins_with("169.254.") or a.begins_with("0."):
		return ""
	var o := a.split(".")
	if o.size() != 4:
		return ""
	var b0 := int(o[0])
	var b1 := int(o[1])
	if b0 == 100 and b1 >= 64 and b1 < 128 or "tailscale" in name:
		return "TAILSCALE"
	for v in VIRTUAL:
		if v in name:
			return ""
	if b0 == 192 and b1 == 168 and int(o[2]) == 56:
		return ""                        # VirtualBox's host-only network
	if b0 == 172 and b1 >= 16 and b1 < 32:
		# WSL and Docker live here; a real network can too
		for ph in PHYSICAL:
			if ph in name:
				return "SAME WI-FI"
		return ""
	if b0 == 10 or (b0 == 192 and b1 == 168):
		return "SAME WI-FI"
	return ""


var _mine: Array = []
var _mine_for: OnlineSession


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
			# the adapters, read once per hosting (info() runs every frame)
			if _mine_for != session:
				_mine_for = session
				_mine = my_addresses()
			var mine := _mine
			var lines := ["WAITING. YOUR FRIEND JOINS ONE OF THESE:", "", ""]
			for k in mine.size():
				lines[k + 1] = "%s: %s" % mine[k]
			if mine.is_empty():
				lines[1] = "NO NETWORK FOUND: IS WI-FI ON?"
			return lines
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
	var nav := page.drive(false)
	if nav & MenuPage.NAV_MOVED:
		_sfx.play("blip")
	if nav & MenuPage.NAV_BACK:
		_leave()
	elif nav & MenuPage.NAV_PRESSED:
		_sfx.play("blip")
