## Online by room (port ADR-105, design/RELAY.md): a NetLink through the
## relay, a WebSocket server both players dial out to, so nobody forwards a
## port and the Web build can play. The host opens a room and the relay
## names it (four consonants, "BXKM"); the guest joins it by that name.
## The messages are ENetLink's (var_to_bytes Arrays) in binary frames: the
## host's carry the relay's one-byte guest number, the guest's are bare.
## The relay's own words are JSON text frames (room, welcome, joined, left,
## error). The link measures its round trip itself (PING / PONG between the
## two games, kept out of receive()), so Lockstep.for_rtt and
## Rollback.for_rtt see the relay's line as they see ENet's.
class_name RelayLink
extends NetLink

const URL := "wss://pb94-relay.wonderfulground-3bc64e4e.eastus.azurecontainerapps.io"
const GAME := "pb94-port"
## The relay's room names: no I or O to misread, no vowels, so no words.
const ALPHABET := "BCDFGHJKLMNPQRSTVWXZ"
const ROOM_LEN := 4
const TIMEOUT_MS := 45000        ## a relay asleep took 18.6 s to wake (2026-10-29)
const PING_MS := 2000
const KEEP_MS := 60000           ## a host waiting tells the relay it's still there
const PING := "~PING"
const PONG := "~PONG"
## The relay's reasons, as the screen says them; others pass as they are.
const REASONS := {"HOST LEFT": "THE OTHER PLAYER LEFT", "IDLE": "THE ROOM CLOSED: IDLE",
	"TIME UP": "THE ROOM CLOSED: TIME UP", "NO SUCH ROOM": "NO SUCH ROOM",
	"ROOM FULL": "THAT ROOM IS FULL", "SERVER FULL": "THE SERVER IS FULL"}

var ws := WebSocketPeer.new()
var room := ""                   ## the room's name, once the relay gives it
var _hosting := false
var _guest := -1                 ## the host's: the relay's number for the guest who's in
var _welcomed := false           ## the guest's: in the room
var _inbox: Array = []
var _started_ms := 0
var _ping_ms := 0
var _keep_ms := 0
var _rtt := 0


## The relay's address: URL, or `relay=ws://...` on the command line (a
## local relay, for testing).
static func address() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("relay="):
			return a.trim_prefix("relay=")
	return URL


## A room's name as typed, cleaned: capitals from ALPHABET, at most ROOM_LEN.
static func clean_room(s: String) -> String:
	var out := ""
	for c in s.to_upper():
		if c in ALPHABET and out.length() < ROOM_LEN:
			out += c
	return out


func host(url := address()) -> bool:
	_hosting = true
	return _dial("%s/v1/host?game=%s&ver=%s" % [url, GAME, BuildInfo.version().uri_encode()])


func join(code: String, url := address()) -> bool:
	room = clean_room(code)
	if room.length() != ROOM_LEN:
		error = "A ROOM IS %d LETTERS" % ROOM_LEN
		return false
	return _dial("%s/v1/join?game=%s&code=%s&ver=%s" % [url, GAME, room, BuildInfo.version().uri_encode()])


func _dial(url: String) -> bool:
	if ws.connect_to_url(url) != OK:
		error = "CAN'T REACH THE SERVER"
		return false
	_started_ms = Time.get_ticks_msec()
	return true


func status() -> int:
	if error != "":
		return CLOSED
	if _started_ms == 0:
		return OPEN                      # not dialled (the screenshot tool's)
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return CLOSED
	if _hosting:
		return CONNECTED if _guest >= 0 else OPEN
	return CONNECTED if _welcomed else OPEN


func rtt_ms() -> int:
	return _rtt


func send(msg: Array) -> void:
	if status() != CONNECTED:
		return
	_send(msg)


func _send(msg: Array) -> void:
	var out := PackedByteArray([_guest]) if _hosting else PackedByteArray()
	out.append_array(var_to_bytes(msg))
	ws.send(out)


func poll() -> void:
	if error != "" or _started_ms == 0:
		return
	ws.poll()
	var now := Time.get_ticks_msec()
	while ws.get_available_packet_count() > 0:
		var bytes := ws.get_packet()
		if ws.was_string_packet():
			_control(JSON.parse_string(bytes.get_string_from_utf8()))
		elif _hosting:
			if bytes.size() > 1 and bytes[0] == _guest:
				_message(bytes_to_var(bytes.slice(1)), now)
		else:
			_message(bytes_to_var(bytes), now)
		if error != "":
			return
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		# A refusal's words come as the close's reason too (Godot can drop
		# the text frame right before a close).
		var r := ws.get_close_reason()
		if error == "" and r != "":
			error = String(REASONS.get(r, r))
		elif error == "":
			error = "CONNECTION LOST" if _guest >= 0 or _welcomed else "CAN'T REACH THE SERVER"
		return
	if st != WebSocketPeer.STATE_OPEN:
		if now - _started_ms > TIMEOUT_MS:
			error = "NO ANSWER FROM THE SERVER"
			close()
		return
	if status() == OPEN and room == "" and now - _started_ms > TIMEOUT_MS:
		error = "NO ANSWER FROM THE SERVER"
		close()
	elif status() == CONNECTED and now - _ping_ms >= PING_MS:
		_ping_ms = now
		_send([PING, now])
	elif _hosting and status() == OPEN and room != "" and now - _keep_ms >= KEEP_MS:
		_keep_ms = now
		ws.send_text(JSON.stringify({"op": "keep"}))


## The relay's words: the room, the guest coming and going, a refusal.
func _control(msg: Variant) -> void:
	if not msg is Dictionary:
		return
	match String(msg.get("op", "")):
		"room":
			room = String(msg.get("code", ""))
			_keep_ms = Time.get_ticks_msec()
		"welcome":
			_welcomed = true
		"joined":
			if _guest < 0:
				_guest = int(msg.get("guest", 0))
		"left":
			if int(msg.get("guest", -1)) == _guest:
				error = "THE OTHER PLAYER LEFT"
		"error":
			var r := String(msg.get("reason", ""))
			error = String(REASONS.get(r, r)) if r != "" else "CONNECTION LOST"


## A game message, or the line's own PING / PONG.
func _message(v: Variant, now: int) -> void:
	if not v is Array or (v as Array).is_empty():
		return
	var m: Array = v
	if m[0] == PING:
		_send([PONG, m[1]])
	elif m[0] == PONG:
		var took := now - int(m[1])
		_rtt = took if _rtt == 0 else (_rtt * 3 + took) / 4
	else:
		_inbox.append(m)


func receive() -> Array:
	var out := _inbox
	_inbox = []
	return out


## Closes after a last flush, so a QUIT just sent goes out.
func close() -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return
	ws.poll()
	ws.close()
	for i in 3:
		ws.poll()
