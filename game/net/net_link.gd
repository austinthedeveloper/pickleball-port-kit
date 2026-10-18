## A connection to the other player (PORT-31): messages (small Arrays) out
## and in, in order, nothing lost. Two kinds: ENetLink (the real thing, UDP
## with ENet's reliable channel) and LoopbackLink (two ends in one process,
## with a delay, for tests).
class_name NetLink
extends RefCounted

const OPEN := 0                  ## waiting for the other end
const CONNECTED := 1
const CLOSED := 2

var error := ""                  ## why it closed ("" when it hasn't, or for no reason)


func status() -> int:
	return CLOSED


## The line's round trip in milliseconds, as far as it's known (0: unknown).
func rtt_ms() -> int:
	return 0


func send(_msg: Array) -> void:
	pass


## Pumps the connection; call once a frame.
func poll() -> void:
	pass


## The messages that arrived since the last call, oldest first.
func receive() -> Array:
	return []


func close() -> void:
	pass
