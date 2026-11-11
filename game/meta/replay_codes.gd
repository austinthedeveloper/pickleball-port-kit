## Replay codes through the relay (port ADR-112, PORT-157): SHARE sends a
## saved replay's bytes (SavedReplays.to_bytes) and gets a six-letter code;
## WATCH A CODE fetches one. The relay keeps a replay 7 days under its code
## and nothing about who sent it (design/RELAY.md). A request is a Node with
## an HTTPRequest; `done` gives [code or bytes, error word for the screen].
class_name ReplayCodes
extends Node

signal shared(code: String, error: String)
signal fetched(bytes: PackedByteArray, error: String)

const LEN := 6

var _http: HTTPRequest


static func url(code := "") -> String:
	return "%s/v1/replay?game=%s%s" % [Boards.base, Boards.GAME, ("&code=" + code) if code != "" else ""]


## A code as typed: capitals from the rooms' alphabet, LEN at most.
static func clean(s: String) -> String:
	var out := ""
	for c in s.to_upper():
		if c in RelayLink.ALPHABET and out.length() < LEN:
			out += c
	return out


func share(bytes: PackedByteArray) -> void:
	_start(url(), HTTPClient.METHOD_POST, JSON.stringify({"data": Marshalls.raw_to_base64(bytes)}), true)


func fetch(code: String) -> void:
	_start(url(clean(code)), HTTPClient.METHOD_GET, "", false)


func _start(u: String, method: int, body: String, sharing: bool) -> void:
	_http = HTTPRequest.new()
	_http.timeout = 45.0                     # the relay may be waking (KNOWN_ISSUES #94)
	add_child(_http)
	_http.request_completed.connect(_on_done.bind(sharing))
	if _http.request(u, ["Content-Type: application/json"], method, body) != OK:
		_fail(sharing, "OFFLINE")


func _fail(sharing: bool, why: String) -> void:
	if sharing:
		shared.emit("", why)
	else:
		fetched.emit(PackedByteArray(), why)


func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, sharing: bool) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(sharing, "OFFLINE")
		return
	var d: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not d is Dictionary:
		_fail(sharing, "NO CODES HERE YET")   # an older relay
		return
	if (d as Dictionary).has("error"):
		_fail(sharing, words(String(d["error"])))
		return
	if sharing:
		shared.emit(String(d.get("code", "")), "" if d.has("code") else "NO CODE CAME BACK")
	else:
		fetched.emit(Marshalls.base64_to_raw(String(d.get("data", ""))), "")


## The relay's words as the screen says them.
static func words(e: String) -> String:
	return {"NO SUCH REPLAY": "NO SUCH CODE", "TOO BIG": "TOO LONG TO SHARE",
		"TOO MANY TRIES": "TRY IN AN HOUR", "FULL": "SERVER FULL",
		"BAD REPLAY": "NOT A REPLAY", "NO SUCH GAME": "NO CODES HERE YET"}.get(e, e)
