## ONLINE (PORT-31, ADR-056): 1v1 with a friend over the internet or the
## same Wi-Fi. CONNECT BY picks the way (port ADR-105):
## - ROOM CODE (the default): through the relay (RelayLink). One of you
##   HOSTS and gets a room ("BXKM"); the other types the ROOM and JOINS.
##   Works anywhere with the internet, the Web build included.
## - ADDRESS: straight to the host (ENetLink). The host's screen shows its
##   addresses; the other types one and JOINS. Same Wi-Fi, or a VPN.
## Once you've both said hello, the host starts: singles on the host's
## COURT, POINTS and MODIFIERS, each of you in your Player Select look.
## The room is typed on a keyboard, pasted, or picked on a letter grid
## with a pad (PORT-116); the address is typed. The address and the way
## are kept in the save.
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
const BY_ROOM := "room"
const BY_ADDRESS := "address"

var save: SaveGame
var session: OnlineSession
var page: MenuPage
var address := ""
var room := ""                   ## the room typed, to join
var way := BY_ROOM
var port := ENetLink.PORT        ## tests use another
var relay_url := ""              ## tests' local relay ("": RelayLink.address())
var editing := false
var last_reason := ""
## PLAY (port ADR-111): the room you host or join. SINGLES, DOUBLES (four
## homes, empty seats a CPU's) or DOUBLES with two of you on this couch.
const PLAY_NAMES := ["SINGLES", "DOUBLES", "DOUBLES, 2 HERE"]
var play_i := 0
var _subtitle: BitmapText
var _lock := LOCK
var _sfx: Sfx
var _ui: CanvasLayer
var _lines: Array = []           ## the info panel's three lines
var _frame := 0
## The letter grid (PORT-116): a room code with the D-pad, the stick or the
## touch pad. Rows of the code's alphabet, then DELETE and JOIN; up/down
## picks the row, left/right the letter, HIT types it. Keys still type.
var grid: MenuPage
var grid_cols: Array = []        ## each grid row's letter under the cursor
var _grid_box: Node2D
var _key_typed := false          ## a key typed this frame: HIT doesn't type too
const GRID_W := 5                ## letters a row
const GRID_GAP := "   "


func setup(game_save: SaveGame) -> OnlineScreen:
	save = game_save
	if save:
		address = String(save.data["settings"].get("net_address", ""))
		way = String(save.data["settings"].get("net_way", BY_ROOM))
		play_i = clampi(int(save.data["settings"].get("net_play", 0)), 0, PLAY_NAMES.size() - 1)
	if not available(BY_ADDRESS):
		way = BY_ROOM
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
	_subtitle = UiKit.text("small", "", Vector2(480, 76), 0.5, DIM, _ui)
	page = MenuPage.new().setup("online", "", [
		{"id": "way", "label": "CONNECT BY", "value": func(): return "ROOM CODE" if way == BY_ROOM else "ADDRESS",
			"change": _change_way},
		{"id": "play", "label": "PLAY", "value": func(): return PLAY_NAMES[play_i], "change": _change_play},
		{"id": "host", "label": func(): return _host_label(), "value": func(): return _host_value(),
			"press": _press_host},
		{"id": "address", "label": func(): return "ROOM" if way == BY_ROOM else "ADDRESS",
			"value": func(): return _address_value(), "press": _press_address},
		{"id": "join", "label": "JOIN", "value": func(): return _join_value(), "press": _press_join},
		{"id": "watch", "label": "JOIN TO WATCH", "value": func(): return _watch_value(), "press": _press_watch},
		{"id": "chat", "label": "QUICK CHAT", "value": func(): return "MUTED" if Settings.mute_chat else "ON",
			"change": func(_d): Settings.mute_chat = not Settings.mute_chat; Settings.store_to(save)},
		{"id": "back", "label": "BACK", "press": func(): _leave()},
	], Rect2(110, 96, 740, 18 + 8 * MenuPage.ROW_H + 46), [["hit", "SELECT"], ["back", "BACK"]])
	page.pressed.connect(func(_id): page.refresh())
	page.back_requested.connect(_leave)
	_ui.add_child(page)
	_build_grid()
	UiKit.panel(Rect2(60, 394, 840, 120), _ui)
	for i in 3:
		_lines.append(UiKit.text("small", "", Vector2(480, 412 + i * 30), 0.5, Color.WHITE, _ui))
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
		var r := _room()
		if session.link is RelayLink:
			return "ROOM " + r if r != "" else "OPENING..."
		return "WAITING..."
	return ""


## The room the relay gave this host ("" until it has, or by address).
func _room() -> String:
	return (session.link as RelayLink).room if session and session.link is RelayLink else ""


## The row being typed in: the room or the address.
func _typed() -> String:
	return room if way == BY_ROOM else address


func _address_value() -> String:
	if editing:
		return _typed() + ("/" if (_frame / 20) % 2 == 0 else " ")   # the cursor (the font has no _)
	return _typed() if _typed() != "" else "TYPE IT"


## ROOM CODE or ADDRESS; the Web build has only the room (no UDP). A
## session open the other way closes.
func _change_way(_dir: int) -> void:
	if not available(BY_ADDRESS):
		last_reason = "BY ADDRESS NEEDS THE DESKTOP GAME"
		return
	way = BY_ADDRESS if way == BY_ROOM else BY_ROOM
	editing = false
	last_reason = ""
	_close_session()
	if save:
		save.data["settings"]["net_way"] = way
		save.save_game()


func _join_value() -> String:
	if session and not session.host and _state() == OnlineSession.WAITING:
		return "CALLING..."
	return ""


func _watch_value() -> String:
	if session and session.watcher and _state() != OnlineSession.IDLE:
		return "WATCHING" if _state() == OnlineSession.CONNECTED else "CALLING..."
	return "BY ROOM" if way == BY_ROOM else ""


## The room's mode and the players here, from PLAY.
func play_mode() -> int:
	return K.MODE_SINGLES if play_i == 0 else K.MODE_DOUBLES


func players_here() -> int:
	return 2 if play_i == 2 else 1


## PLAY: SINGLES, DOUBLES, DOUBLES WITH 2 HERE. By ADDRESS is singles only
## (ENet's line is one guest); a hosted room changes with it if it can.
func _change_play(d: int) -> void:
	if way == BY_ADDRESS:
		last_reason = "DOUBLES IS BY ROOM CODE"
		play_i = 0
		return
	var was := play_i
	play_i = (play_i + d + PLAY_NAMES.size()) % PLAY_NAMES.size()
	if session and session.host and session.state != OnlineSession.PLAYING:
		session.players_here = players_here()
		if not session.set_mode(play_mode()):
			play_i = was
			last_reason = "THE ROOM HAS TOO MANY FOR SINGLES"
			return
		session.my_hello["players"] = players_here()
	elif session and not session.host and _state() != OnlineSession.IDLE:
		_close_session()                 # a guest's ask changes: join again
	last_reason = ""
	if save:
		save.data["settings"]["net_play"] = play_i
		save.save_game()


## The Web build has no UDP (ENet): only the room, through the relay.
static func available(by := BY_ROOM) -> bool:
	return by == BY_ROOM or not OS.has_feature("web")


func _relay() -> String:
	return relay_url if relay_url != "" else RelayLink.address()


func _press_host() -> void:
	if session and session.host and _state() == OnlineSession.CONNECTED:
		_start_match()
		return
	_close_session()
	editing = false
	var link: NetLink
	var ok := false
	if way == BY_ROOM:
		link = RelayLink.new()
		ok = (link as RelayLink).host(_relay(), OnlineSession.room_guests(K.MODE_DOUBLES))
	else:
		link = ENetLink.new()
		ok = (link as ENetLink).host(port)
	if not ok:
		last_reason = link.error
		_sfx.play("back")
		return
	_open(link, true)


func _press_address() -> void:
	editing = not editing
	if not editing:
		_store_address()
	_show_grid(editing and way == BY_ROOM)


func _press_watch() -> void:
	if way != BY_ROOM:
		last_reason = "WATCHING IS BY ROOM CODE"
		return
	_press_join(true)


func _press_join(watch := false) -> void:
	var need := RelayLink.ROOM_LEN if way == BY_ROOM else 1
	if _typed().strip_edges().length() < need:
		page.select("address")
		editing = true
		return
	_close_session()
	editing = false
	var link: NetLink
	var ok := false
	if way == BY_ROOM:
		link = RelayLink.new()
		ok = (link as RelayLink).join(room, _relay())
	else:
		_store_address()
		link = ENetLink.new()
		ok = (link as ENetLink).join(address.to_lower(), port)
	if not ok:
		last_reason = link.error
		_sfx.play("back")
		return
	_open(link, false, watch)


func _open(link: NetLink, is_host: bool, watch := false) -> void:
	last_reason = ""
	session = OnlineSession.new(link, is_host)
	session.mode = play_mode()
	session.players_here = players_here()
	var me: Career.Player = save.career.active_player() if save else null
	session.my_hello = OnlineSession.hello(Settings.p1_choice, _my_name(), me, players_here(), watch)
	if not is_host:
		session.redial = _redial         # a dropped line dials the room again (PORT-120)
	_sfx.play("confirm")


## A guest's line back to the room it was in (a rejoin).
func _redial() -> Variant:
	var link: NetLink
	var ok := false
	if way == BY_ROOM:
		link = RelayLink.new()
		ok = (link as RelayLink).join(room, _relay())
	else:
		link = ENetLink.new()
		ok = (link as ENetLink).join(address.to_lower(), port)
	return link if ok else null


func _my_name() -> String:
	var me: Career.Player = save.career.active_player() if save else null
	return me.shown_name() if me else ""


## The host's match: the room's seats on the COURT, POINTS and MODIFIERS
## settings; each player in their look, in another shirt if theirs is
## taken (ADR-010: no two share a colour); an empty seat a CPU's.
func _start_match() -> void:
	var cfg := room_config(session)
	cfg.points_to_win = Settings.POINTS[Settings.points_i]
	cfg.modifiers = Settings.mod_bits
	cfg.ball_speed = Settings.ball_speed       # the host's: the guests play the config they're sent
	session.begin({"cfg": OnlineSession.config_to_dict(cfg), "venue": Settings.venue(),
		"time": Settings.time_i, "court": Settings.court.duplicate()})
	_sfx.play("confirm")
	play.emit(session)


## The room's config: each seat's look from HELLO (the host's from its
## own), a couch partner in the next team colour, a CPU in any empty seat.
static func room_config(s: OnlineSession) -> SimTypes.MatchConfig:
	var doubles := s.mode == K.MODE_DOUBLES
	var cfg := SimTypes.MatchConfig.doubles() if doubles else SimTypes.MatchConfig.singles()
	cfg.palette = [-1, -1, -1, -1]
	cfg.human = [0, 0, 0, 0]
	var looks := {}
	var mine: Dictionary = Dictionary(s.my_hello.get("look", Settings.p1_choice)).duplicate()
	looks[0] = mine if not mine.is_empty() else Settings.p1_choice
	var taken := s.seats()
	for slot in taken:
		if taken[slot] == null and slot != 0:
			looks[slot] = {}                 # the host's couch partner
		elif taken[slot] != null:
			var p: OnlineSession.Peer = taken[slot]
			looks[slot] = Dictionary(p.hello.get("look", {})).duplicate() if slot == p.slots[0] else {}
	var used := []
	for slot in K.MAX_PLAYERS:
		if not doubles and slot % 2 == 1:
			continue
		var l: Dictionary = looks.get(slot, {})
		var pal := int(l.get("palette", -1))
		if pal < 0 or pal in used:
			pal = 0
			while pal in used:
				pal += 1
		used.append(pal)
		cfg.palette[slot] = pal
		cfg.variant[slot] = int(l.get("variant", K.VARIANT_MALE))
		cfg.paddle[slot] = int(l.get("paddle", Paddles.STANDARD))
		cfg.human[slot] = 1 if taken.has(slot) else 0
	return cfg


func _store_address() -> void:
	if save and way == BY_ADDRESS:
		save.data["settings"]["net_address"] = address
		save.save_game()


func _close_session() -> void:
	if session:
		session.quit()
	session = null


func _leave() -> void:
	if grid and grid.visible:
		_close_grid()
		return
	if editing:
		editing = false
		_store_address()
		return
	_close_session()
	if _sfx:
		_sfx.play("back")
	leave.emit()


# --- The letter grid (PORT-116) -------------------------------------------------

## A grid row's items: letters, or DELETE and JOIN.
static func grid_items(row: int) -> Array:
	var letters := RelayLink.ALPHABET.length()
	var rows := (letters + GRID_W - 1) / GRID_W
	if row == rows:
		return ["DELETE", "JOIN"]
	var out := []
	for i in range(row * GRID_W, mini(letters, (row + 1) * GRID_W)):
		out.append(RelayLink.ALPHABET[i])
	return out


static func grid_rows() -> int:
	return (RelayLink.ALPHABET.length() + GRID_W - 1) / GRID_W + 1


func _build_grid() -> void:
	var rows := []
	for r in grid_rows():
		grid_cols.append(0)
		rows.append({"id": "g%d" % r, "label": GRID_GAP.join(grid_items(r)),
			"change": func(d): grid_cols[r] = (grid_cols[r] + d + grid_items(r).size()) % grid_items(r).size(); _grid_box.queue_redraw(),
			"press": func(): _grid_press(r)})
	grid = MenuPage.new().setup("room_grid", "", rows, Rect2(300, 96, 360, 18 + grid_rows() * MenuPage.ROW_H + 50),
		[["hit", "TYPE"], ["back", "DONE"]])
	grid.back_requested.connect(func(): _close_grid())
	grid.pressed.connect(func(_id): grid.refresh())
	_ui.add_child(grid)
	_grid_box = Node2D.new()
	_grid_box.draw.connect(_draw_grid_box)
	grid.add_child(_grid_box)
	grid.visible = false


## Where an item of a grid row starts and how wide it is, on screen.
func grid_item_rect(row: int, col: int) -> Rect2:
	var items := grid_items(row)
	var x := grid.area.position.x + 36
	for i in col:
		x += BitmapText.measure("small", String(items[i]) + GRID_GAP)
	var w := BitmapText.measure("small", String(items[col]))
	return Rect2(x - 5, grid._row_y(row) - 3, w + 10, MenuPage.ROW_H - 4)


func _draw_grid_box() -> void:
	if not grid.visible:
		return
	var r := grid_item_rect(grid.cursor, grid_cols[grid.cursor])
	_grid_box.draw_rect(r, MenuPage.BAR_EDGE, false, 2.0)


## HIT on a grid row: type its letter, or DELETE, or JOIN.
func _grid_press(row: int) -> void:
	var item := String(grid_items(row)[grid_cols[row]])
	if item == "DELETE":
		room = room.left(maxi(0, room.length() - 1))
	elif item == "JOIN":
		_close_grid()
		_press_join()
		return
	else:
		room = RelayLink.clean_room(room + item)
		if room.length() == RelayLink.ROOM_LEN:
			grid.select("g%d" % (grid_rows() - 1))      # full: the cursor on JOIN
			grid_cols[grid_rows() - 1] = 1
	_sfx.play("blip")
	_grid_box.queue_redraw()
	page.refresh()


## Types a whole code through the grid, letter by letter as a pad would
## (tests: rows selected by id).
func grid_type(code: String) -> void:
	for c in code:
		for r in grid_rows() - 1:
			var i := grid_items(r).find(c)
			if i >= 0:
				grid.select("g%d" % r)
				grid_cols[r] = i
				grid.press()


## The grid's help: on a keyboard, type and ENTER (its HIT and back keys
## are letters of the code); else the pad's or the touch pad's buttons.
func _grid_prompts() -> void:
	var want: Array = [["esc", "DONE"]] if GameControls.last_device == GameControls.KEYBOARD \
		else [["hit", "TYPE"], ["back", "DONE"]]
	if grid.prompts and str(grid.prompts.items) != str(want):
		grid.prompts.set_items(want)


func _show_grid(on: bool) -> void:
	grid.visible = on
	page.visible = not on
	if on:
		grid.select("g0")
		grid.appear()
		_lock = LOCK
		GameControls.clear_latch()
	_grid_box.queue_redraw()


func _close_grid() -> void:
	if not grid.visible:
		return
	editing = false
	_show_grid(false)
	page.select("join" if room.length() == RelayLink.ROOM_LEN else "address")
	_lock = LOCK
	GameControls.clear_latch()


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
	if st == OnlineSession.IDLE and grid and grid.visible:
		var shown := room
		while shown.length() < RelayLink.ROOM_LEN:
			shown += "-"
		if GameControls.last_device == GameControls.KEYBOARD:
			return ["ROOM: " + shown, "TYPE THE LETTERS, OR PICK THEM", "WITH THE ARROWS AND SPACE."]
		return ["ROOM: " + shown, "PICK EACH LETTER, THEN JOIN.", "OR TYPE IT ON A KEYBOARD."]
	if st == OnlineSession.IDLE:
		if last_reason != "":
			return [last_reason, "", ""]
		if way == BY_ROOM:
			return ["ONE OF YOU HOSTS AND GETS A ROOM.", "THE OTHER TYPES THAT ROOM AND JOINS.",
				"WORKS ANYWHERE WITH THE INTERNET."]
		return ["ONE OF YOU HOSTS. THE OTHER TYPES THE", "HOST'S ADDRESS AND JOINS.",
			"SAME WI-FI JUST WORKS. FAR AWAY: SEE THE README."]
	if st == OnlineSession.WAITING:
		if session.link is RelayLink:
			var r := _room()
			var left := (session.link as RelayLink).seconds_left()
			if session.host and r == "":
				return ["OPENING A ROOM ON THE SERVER...", "IT CAN TAKE 20 SECONDS TO WAKE UP.",
					"GIVING UP IN %d" % left if left > 0 else ""]
			if session.host:
				return ["YOUR ROOM: " + r, "YOUR FRIEND PICKS ONLINE, TYPES " + r, "AND JOINS. WAITING FOR THEM..."]
			return ["JOINING ROOM " + r + "...", "THE SERVER MAY BE WAKING UP." if left > 0 else "",
				"GIVING UP IN %d" % left if left > 0 else ""]
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
	if st == OnlineSession.CONNECTED and (session.mode == K.MODE_DOUBLES or session.watcher):
		var line2 := "SEATS: " + seats_line()
		if session.watcher:
			return ["WATCHING. THE MATCH SHOWS WHEN IT STARTS.", line2, ""]
		if session.host:
			return ["YOUR ROOM: " + _room() if _room() != "" else "YOUR ROOM IS OPEN", line2,
				"START WHEN YOU'RE READY: EMPTY SEATS ARE CPUS."]
		return ["IN THE ROOM!", line2, "WAITING FOR THE HOST TO START."]
	if st == OnlineSession.CONNECTED:
		var them := String(session.peer_hello.get("name", ""))
		var line := "CONNECTED TO " + (them if them != "" else "YOUR FRIEND") + "!"
		if session.host:
			return [line, "%s   %s   TO %d" % [Settings.VENUE_NAMES[Settings.venue_i],
				"SINGLES", Settings.POINTS[Settings.points_i]], "START MATCH WHEN YOU'RE READY."]
		return [line, "WAITING FOR THE HOST TO START.", ""]
	return ["", "", ""]


## Who sits where, in the seat order: names, YOU, a dash for empty.
func seats_line() -> String:
	var out := []
	for slot in session.seat_order():
		if slot in session.my_slots or (session.host and slot in session.host_slots()):
			out.append("YOU")
		elif session.seated(slot):
			var n := session.seat_name(slot)
			out.append(n if n != "" else "P%d" % (int(slot) + 1))
		else:
			out.append("-")
	return ", ".join(out)


func refresh() -> void:
	if _subtitle:
		_subtitle.text = "1 VS 1, SINGLES" if play_i == 0 else ("DOUBLES, 2 OF YOU HERE" if play_i == 2
			else "DOUBLES: UP TO FOUR HOMES")
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
	if grid and grid.visible and event is InputEventMouse:
		_grid_mouse((event as InputEventMouse).position)
	if not editing or not (event is InputEventKey) or not event.pressed:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_BACKSPACE:
		if way == BY_ROOM:
			room = room.left(maxi(0, room.length() - 1))
		else:
			address = address.left(maxi(0, address.length() - 1))
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		editing = false
		_store_address()
		if grid.visible:
			_close_grid()
		_lock = LOCK
	elif k.keycode == KEY_V and (k.ctrl_pressed or k.meta_pressed):
		_type(DisplayServer.clipboard_get())
		_key_typed = true
	elif k.unicode > 0:
		var was := _typed()
		_type(char(k.unicode))
		_key_typed = _typed() != was     # a letter typed; SPACE (HIT) still picks on the grid
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	page.refresh()


## The mouse over the grid: the letter under it (MenuPage picks the row
## and presses it on a click).
func _grid_mouse(at: Vector2) -> void:
	var row := grid.row_at(at)
	if row < 0:
		return
	var best := 0
	for c in grid_items(row).size():
		if absf(grid_item_rect(row, c).get_center().x - at.x) < absf(grid_item_rect(row, best).get_center().x - at.x):
			best = c
	grid_cols[row] = best
	_grid_box.queue_redraw()


func _type(s: String) -> void:
	if way == BY_ROOM:
		room = RelayLink.clean_room(room + s)
		return
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
	if grid.visible:
		_grid_box.queue_redraw()
		var typed := _key_typed
		_key_typed = false
		if _lock > 0:
			_lock -= 1
			return
		# the keyboard's HIT and back keys (J, K, L) are letters too: a
		# letter typed is only a letter
		_grid_prompts()
		var gnav := grid.drive(true, not typed, not typed)
		if gnav & MenuPage.NAV_MOVED:
			_sfx.play("blip")
		if gnav & MenuPage.NAV_BACK:
			_sfx.play("back")
			_close_grid()
		return
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
