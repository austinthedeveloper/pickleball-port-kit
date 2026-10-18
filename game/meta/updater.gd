## The in-game updater (PORT-32, ADR-057): a node scenes/boot.gd adds ("Updates").
##
## A release's game is its .pck; the app around it (Godot's engine) only
## changes with Godot's version. So an update is the new .pck: the updater
## asks GitHub for the latest release, and if it's newer and needs this
## engine, OPTIONS > UPDATES downloads its .pck into user://updates/,
## checks its SHA-256 against the release's manifest, and restarts the game
## (scenes/boot.gd loads it over the built-in one at every start, until a
## full download is newer). Release builds of Godot refuse `--main-pack`,
## so the pack is loaded in-game, by the boot scene.
##
## If a start on an update never reaches the title (a broken pack), the
## next start skips it: boot marks it `booting`, the title clears it
## (`mark_good`).
##
## Only exported desktop builds update; the Web build and a checkout
## (`godot --path game`) say so and never touch the network.
class_name Updater
extends Node

const DIR := "user://updates/"
const CURRENT := DIR + "current.json"   ## {version, engine, file, booting}
const API := "https://api.github.com/repos/%s/releases/latest"
const PAGE := "https://github.com/%s/releases/latest"

## The state OPTIONS > UPDATES shows.
const OFF := 0               ## not an exported desktop build
const IDLE := 1
const CHECKING := 2
const LATEST := 3            ## up to date
const AVAILABLE := 4         ## a newer pack for this engine
const FULL := 5              ## a newer release, but it needs a full download
const DOWNLOADING := 6
const READY := 7             ## downloaded and checked: restart for it
const FAILED := 8

static var instance: Updater             ## the node, for the title (null in tests)

var state := OFF
var latest := ""                        ## the newest release's version
var error := ""
var manifest := {}                      ## the newest release's manifest
var _http: HTTPRequest
var _pck_url := ""
var _job := ""                          ## "release", "manifest", "pck"


# --- Pure: versions, the release, the launch decision -----------------------------

## -1, 0, 1 as `a` is older, the same, newer than `b` ("0.10.0" > "0.9.3").
static func compare(a: String, b: String) -> int:
	var x := a.trim_prefix("v").split(".")
	var y := b.trim_prefix("v").split(".")
	for i in maxi(x.size(), y.size()):
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return 1 if p > q else -1
	return 0


## This engine's MAJOR.MINOR.PATCH (a pack needs the same).
static func engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


## From GitHub's latest-release JSON: {version, manifest_url, pck_url}, or
## {} if it has no updater files (a release from before 0.9.0).
static func parse_release(r: Dictionary) -> Dictionary:
	var v := String(r.get("tag_name", "")).trim_prefix("v")
	var out := {"version": v, "manifest_url": "", "pck_url": ""}
	for a in r.get("assets", []):
		var n := String(a.get("name", ""))
		if n == "Pickleball94-%s.json" % v:
			out["manifest_url"] = a.get("browser_download_url", "")
		elif n == "Pickleball94-%s.pck" % v:
			out["pck_url"] = a.get("browser_download_url", "")
	if v == "" or out["manifest_url"] == "" or out["pck_url"] == "":
		return {}
	return out


# --- The node (scenes/boot.gd adds it as "Updates") -------------------------------

func _ready() -> void:
	instance = self
	if not supported():
		state = OFF
		return
	state = IDLE
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_done)
	add_child(_http)
	check.call_deferred()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Exported desktop builds only.
static func supported() -> bool:
	return OS.has_feature("template") and not OS.has_feature("web")


static func repo() -> String:
	return String(ProjectSettings.get_setting("application/config/update_repo",
		"austinthedeveloper/pickleball-port-kit"))


static func read_current() -> Dictionary:
	if not FileAccess.file_exists(CURRENT):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(CURRENT))
	return v if v is Dictionary else {}


static func write_current(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(CURRENT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


## The title reached: a start on an update (BuildInfo's version is the
## update's) works, so it isn't skipped next time (scenes/boot.gd).
static func mark_good() -> void:
	var c := read_current()
	if bool(c.get("booting", false)) and String(c.get("version", "")) == BuildInfo.version():
		c["booting"] = false
		write_current(c)


## Starts the game again (scenes/boot.gd loads the update) and quits this
## one. False if the new process didn't start.
func relaunch() -> bool:
	var pid := OS.create_process(OS.get_executable_path(), [])
	if pid <= 0:
		return false
	get_tree().quit()
	return true


## Asks GitHub for the latest release.
func check() -> void:
	if state in [OFF, CHECKING, DOWNLOADING]:
		return
	error = ""
	state = CHECKING
	_job = "release"
	_http.download_file = ""
	var err := _http.request(API % repo(), ["User-Agent: Pickleball94", "Accept: application/vnd.github+json"])
	if err != OK:
		_fail("CAN'T CHECK")


## Downloads the newest pack (when AVAILABLE).
func download() -> void:
	if state != AVAILABLE:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	state = DOWNLOADING
	_job = "pck"
	_http.download_file = DIR + "download.part"
	if _http.request(_pck_url, ["User-Agent: Pickleball94"]) != OK:
		_fail("CAN'T DOWNLOAD")


## 0..1 while DOWNLOADING.
func progress() -> float:
	if state != DOWNLOADING or _http == null:
		return 0.0
	var total := maxi(_http.get_body_size(), int(manifest.get("size", 0)))
	return clampf(float(_http.get_downloaded_bytes()) / maxf(total, 1.0), 0.0, 1.0)


## READY: start again on the new pack.
func restart() -> void:
	if state == READY:
		if not relaunch():
			_fail("QUIT AND OPEN THE GAME AGAIN")


## FULL: the release page, for the full download.
func open_page() -> void:
	OS.shell_open(PAGE % repo())


func _fail(why: String) -> void:
	error = why
	state = FAILED


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("OFFLINE" if result != HTTPRequest.RESULT_SUCCESS else "GITHUB SAID %d" % code)
		return
	match _job:
		"release":
			var r = JSON.parse_string(body.get_string_from_utf8())
			var rel := parse_release(r if r is Dictionary else {})
			if rel.is_empty():
				latest = String((r if r is Dictionary else {}).get("tag_name", "")).trim_prefix("v")
				state = LATEST if compare(latest, BuildInfo.version()) <= 0 else FULL
				return
			latest = rel["version"]
			if compare(latest, BuildInfo.version()) <= 0:
				state = LATEST
				return
			_pck_url = rel["pck_url"]
			_job = "manifest"
			if _http.request(rel["manifest_url"], ["User-Agent: Pickleball94"]) != OK:
				_fail("CAN'T CHECK")
		"manifest":
			var m = JSON.parse_string(body.get_string_from_utf8())
			manifest = m if m is Dictionary else {}
			if String(manifest.get("engine", "")) != engine():
				state = FULL
				return
			state = AVAILABLE
		"pck":
			var part := DIR + "download.part"
			var sum := FileAccess.get_sha256(part)
			if sum != String(manifest.get("sha256", "")):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
				_fail("THE DOWNLOAD WAS DAMAGED: TRY AGAIN")
				return
			var file := DIR + "Pickleball94-%s.pck" % latest
			DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(file))
			_prune(file)
			write_current({"version": latest, "engine": engine(), "file": file, "booting": false})
			state = READY


## Keeps only the newest pack.
func _prune(keep: String) -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".pck") and DIR + f != keep:
			d.remove(f)


## OPTIONS > UPDATES's value (short: the column is narrow).
func label() -> String:
	match state:
		OFF:
			return "WEB" if OS.has_feature("web") else "DEV BUILD"
		IDLE, CHECKING:
			return "CHECKING"
		LATEST:
			return "UP TO DATE"
		AVAILABLE:
			return "GET " + latest
		FULL:
			return latest + " IS OUT"
		DOWNLOADING:
			return "%d%%" % int(progress() * 100)
		READY:
			return "RESTART"
		FAILED:
			return "TRY AGAIN"
	return ""


## The title's notice, or "": what's new and what to do.
func notice() -> String:
	match state:
		AVAILABLE:
			return "%s IS OUT: GET IT IN OPTIONS, UPDATES" % latest
		FULL:
			return "%s IS OUT: GET IT FROM THE RELEASES PAGE" % latest
		DOWNLOADING:
			return "DOWNLOADING %s: %d%%" % [latest, int(progress() * 100)]
		READY:
			return "%s IS READY: RESTART IN OPTIONS, UPDATES" % latest
		FAILED:
			return "UPDATE: " + error if error != "OFFLINE" else ""
	return ""


## OPTIONS > UPDATES pressed.
func press() -> void:
	match state:
		AVAILABLE:
			download()
		READY:
			restart()
		FULL:
			open_page()
		LATEST, FAILED:
			check()
