## Score boards through the relay (port ADR-109, PORT-158/159): TODAY'S
## TRIP's board for each day and the WEEKLY CHALLENGE's for each week
## (the relay's /v1/board, boards.js in pickleball-relay). Three letters
## and a score; nothing else leaves the game, and OPTIONS > SCORE BOARDS
## OFF sends nothing. The relay can't replay a trip or a match, so a
## board is for friends, not prizes.
##
## A request is a Node with an HTTPRequest (fetch(), post()); its `done`
## gives the board ([{initials, score, detail}]) or an error word for the
## screen: OFFLINE, NO BOARD YET (the relay has no boards: an older one).
class_name Boards
extends Node

signal done(board: Array, error: String)

const BASE := "https://pb94-relay.wonderfulground-3bc64e4e.eastus.azurecontainerapps.io"
const GAME := "pb94-port"
const SHOWN := 10
static var base := BASE              ## the tests point it at a local relay

var _http: HTTPRequest


static func trip_board(date: int) -> String:
	return "trip-%08d" % date


static func week_board(week: Array) -> String:
	return "week-%04d%02d" % [int(week[0]), int(week[1])]


static func url(board: String) -> String:
	return "%s/v1/board?game=%s&board=%s" % [base, GAME, board]


## The ISO week of a date (YYYYMMDD): [year, week], as the relay counts it.
static func iso_week(date: int) -> Array:
	var y := date / 10000
	var m := (date / 100) % 100
	var d := date % 100
	var days := _days(y, m, d)
	var wd := (days + 3) % 7                  # 0 Monday (1970-01-01 was a Thursday)
	var thursday := days - wd + 3
	var ty := _year_of(thursday)
	var jan4 := _days(ty, 1, 4)
	var first_thursday := jan4 - (jan4 + 3) % 7 + 3
	return [ty, 1 + (thursday - first_thursday) / 7]


## Days since 1970-01-01 (proleptic Gregorian).
static func _days(y: int, m: int, d: int) -> int:
	var yy := y - (1 if m <= 2 else 0)
	var era := (yy if yy >= 0 else yy - 399) / 400
	var yoe := yy - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func _year_of(days: int) -> int:
	var y := 1970 + days / 366
	while _days(y + 1, 1, 1) <= days:
		y += 1
	while _days(y, 1, 1) > days:
		y -= 1
	return y


## Three letters for a board: the active career player's name, else the
## last record's initials, else PLR.
static func initials(save: SaveGame) -> String:
	var me: Career.Player = save.career.active_player() if save and save.career else null
	var from := me.shown_name() if me else ""
	if from == "" and save:
		for v in save.data["initials"].values():
			if String(v) != "":
				from = String(v)
	var out := ""
	for ch in from.to_upper():
		if ch >= "A" and ch <= "Z":
			out += ch
	return (out + "XXX").substr(0, 3) if out != "" else "PLR"


## TODAY'S TRIP's score: a won trip above any unwon, then how far, the
## matches won, the losses.
static func trip_score(won: bool, leg: int, wins: int, losses: int) -> int:
	return (10000 if won else 0) + leg * 1000 + wins * 10 - mini(losses, 9)


static func trip_detail(won: bool, leg: int, wins: int, losses: int) -> String:
	return ("WON %d-%d" % [wins, losses]) if won else ("LEG %d  %d-%d" % [leg, wins, losses])


func fetch(board: String) -> void:
	_start(board, HTTPClient.METHOD_GET, "")


## Posts a score (if SCORE BOARDS is on), then the board comes back.
func post(board: String, who: String, score: int, detail: String) -> void:
	if not Settings.board_post:
		fetch(board)
		return
	_start(board, HTTPClient.METHOD_POST, JSON.stringify({"initials": who, "score": score, "detail": detail}))


func _start(board: String, method: int, body: String) -> void:
	_http = HTTPRequest.new()
	_http.timeout = 45.0                       # the relay may be waking (KNOWN_ISSUES #94)
	add_child(_http)
	_http.request_completed.connect(_on_done)
	if _http.request(url(board), ["Content-Type: application/json"], method, body) != OK:
		done.emit([], "OFFLINE")


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		done.emit([], "OFFLINE")
		return
	var d: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code == 404 or not d is Dictionary:
		done.emit([], "NO BOARD YET")
		return
	if d.has("error"):
		done.emit(d.get("board", []), String(d["error"]))
		return
	done.emit(d.get("board", []), "")


## A board's rows as the screens show them: "1  ACE  1240  WON 9-2".
static func lines(board: Array) -> Array:
	var out := []
	for i in mini(board.size(), SHOWN):
		var e: Dictionary = board[i]
		out.append("%2d  %s  %6d  %s" % [i + 1, String(e.get("initials", "???")).substr(0, 3),
			mini(int(e.get("score", 0)), 999999), String(e.get("detail", "")).substr(0, 12)])
	return out


## A request waited on (the tests and tools; the screens use fetch() and
## post()): [HTTP code, the body parsed], or [0, {}] if it couldn't.
static func request_blocking(full_url: String, method := HTTPClient.METHOD_GET, body := "") -> Array:
	var u := full_url
	var tls := u.begins_with("https://")
	u = u.trim_prefix("https://").trim_prefix("http://")
	var slash := u.find("/")
	var hostport := u.substr(0, slash)
	var path := u.substr(slash)
	var host := hostport
	var port := 443 if tls else 80
	if hostport.contains(":"):
		host = hostport.split(":")[0]
		port = int(hostport.split(":")[1])
	var c := HTTPClient.new()
	if c.connect_to_host(host, port, TLSOptions.client() if tls else null) != OK:
		return [0, {}]
	for i in 500:
		c.poll()
		if c.get_status() == HTTPClient.STATUS_CONNECTED:
			break
		OS.delay_msec(5)
	if c.get_status() != HTTPClient.STATUS_CONNECTED:
		return [0, {}]
	c.request(method, path, ["Content-Type: application/json"], body)
	for i in 500:
		c.poll()
		if c.get_status() != HTTPClient.STATUS_REQUESTING:
			break
		OS.delay_msec(5)
	if not c.has_response():
		return [0, {}]
	var code := c.get_response_code()
	var bytes := PackedByteArray()
	for i in 500:
		c.poll()
		if c.get_status() != HTTPClient.STATUS_BODY:
			break
		bytes.append_array(c.read_response_body_chunk())
		OS.delay_msec(2)
	var d: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return [code, d if d is Dictionary else {}]
