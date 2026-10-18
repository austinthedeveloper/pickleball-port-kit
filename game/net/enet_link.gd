## The real connection (PORT-31): ENet over UDP, one peer each side, every
## message on the reliable, ordered channel (lockstep needs every input).
## The host listens on PORT; the guest connects to the host's address.
## Messages are Arrays of plain values (var_to_bytes, no objects).
class_name ENetLink
extends NetLink

const PORT := 24994
const TIMEOUT_MS := 8000         ## a guest gives up connecting after this

var peer := ENetMultiplayerPeer.new()
var _inbox: Array = []
var _was_connected := false
var _started_ms := 0
var _hosting := false


func host(port := PORT) -> bool:
	_hosting = true
	var err := peer.create_server(port, 1)
	if err != OK:
		error = "CAN'T OPEN PORT %d" % port
		return false
	_started_ms = Time.get_ticks_msec()
	return true


func join(address: String, port := PORT) -> bool:
	var err := peer.create_client(address, port)
	if err != OK:
		error = "CAN'T REACH " + address.to_upper()
		return false
	_started_ms = Time.get_ticks_msec()
	return true


func status() -> int:
	if error != "":
		return CLOSED
	var s := peer.get_connection_status()
	if s == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return CLOSED
	if _hosting:
		return CONNECTED if _was_connected else OPEN
	return CONNECTED if s == MultiplayerPeer.CONNECTION_CONNECTED else OPEN


func send(msg: Array) -> void:
	if status() != CONNECTED:
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	peer.put_packet(var_to_bytes(msg))


func poll() -> void:
	if error != "":
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var v = bytes_to_var(peer.get_packet())
		if v is Array:
			_inbox.append(v)
	if _hosting:
		var n := 0
		for id in _peers():
			n += 1
		if n > 0:
			_was_connected = true
		elif _was_connected:
			error = "THE OTHER PLAYER LEFT"
	elif status() == OPEN and Time.get_ticks_msec() - _started_ms > TIMEOUT_MS:
		error = "NO ANSWER"
		close()
	elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_was_connected = true
	elif _was_connected:
		error = "CONNECTION LOST"


## The connected peers' ids (the host has at most one).
func _peers() -> Array:
	var out := []
	# ENetMultiplayerPeer has no list; ask ENet's host for its peers
	var h := peer.host
	if h:
		for p in h.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				out.append(p)
	return out


func rtt_ms() -> int:
	var ps := _peers()
	return int(ps[0].get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if not ps.is_empty() else 0


func receive() -> Array:
	var out := _inbox
	_inbox = []
	return out


## Closes after a last flush, so a QUIT just sent goes out.
func close() -> void:
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	for i in 3:
		peer.poll()
	peer.close()
