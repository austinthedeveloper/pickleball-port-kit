## Both ends of a connection in one process (PORT-31's tests): a message
## arrives `delay` polls after it was sent (plus `jitter`'s pattern, never
## out of order), as over a real line. LoopbackLink.pair() makes two.
class_name LoopbackLink
extends NetLink

var other: LoopbackLink
var delay := 0
var jitter: Array = []           ## extra polls per message, cycling (deterministic)
var _inbox: Array = []           ## [[arrive_at, msg]]
var _clock := 0
var _sent := 0
var _closed := false
var _last_arrival := 0


static func pair(latency := 0, jitter_pattern: Array = []) -> Array:
	var a := LoopbackLink.new()
	var b := LoopbackLink.new()
	a.other = b
	b.other = a
	for l in [a, b]:
		l.delay = latency
		l.jitter = jitter_pattern
	return [a, b]


## Closed once either end closed and what was already sent has arrived.
func status() -> int:
	if _closed:
		return CLOSED
	if other == null or other._closed:
		return CONNECTED if not _inbox.is_empty() else CLOSED
	return CONNECTED


func send(msg: Array) -> void:
	if status() != CONNECTED or other == null or other._closed:
		return                           # the other end is gone: lost, as on a real line
	var extra: int = jitter[_sent % jitter.size()] if not jitter.is_empty() else 0
	_sent += 1
	# never before an earlier message (an ordered channel)
	var at := maxi(other._clock + delay + extra, other._last_arrival)
	other._last_arrival = at
	other._inbox.append([at, msg.duplicate(true)])


func poll() -> void:
	_clock += 1


func receive() -> Array:
	var out := []
	while not _inbox.is_empty() and _inbox[0][0] <= _clock:
		out.append(_inbox.pop_front()[1])
	return out


func close() -> void:
	_closed = true
	if other:
		other.other = null
	other = null
