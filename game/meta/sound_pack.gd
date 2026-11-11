## The Web build's sound pack (PORT-154): the music and the ambience
## (about 8 MB of the pack's 13) leave the first download, so the title
## comes up sooner. The page fetches `sound.pck` from beside index.html
## once the game is running, loads it over the game's pack, and the music
## starts; until then the menus are quiet but for their effects. A desktop
## build has them in its own pack, so this does nothing there.
##
## The pack is made by tools/sound_pack.gd from the Web project's imported
## files (export.sh); the Web preset's exclude_filter leaves them out.
class_name SoundPack
extends Node

signal loaded

const FILE := "sound.pck"
const SAVED := "user://sound.pck"
## A file only the sound pack has, in the Web build.
const PROBE := "res://assets/audio/music_title.ogg"

static var state := "none"           ## "none", "loading", "loaded", "failed"
var _http: HTTPRequest


## The build's own pack lacks the music: the Web build's.
static func needed() -> bool:
	return not ResourceLoader.exists(PROBE)


func _ready() -> void:
	if not needed():
		state = "loaded"
		return
	var url := FILE
	if OS.has_feature("web"):
		var href: Variant = JavaScriptBridge.eval("new URL('%s', window.location.href).href" % FILE)
		if href is String and href != "":
			url = href
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)
	state = "loading" if _http.request(url) == OK else "failed"


## The body, written out and loaded over the game's pack. (Written here,
## not through HTTPRequest.download_file: in a browser that file wouldn't
## load as a pack.)
func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0
	if ok:
		var f := FileAccess.open(SAVED, FileAccess.WRITE)
		ok = f != null
		if ok:
			f.store_buffer(body)
			f.close()
	if not ok or not ProjectSettings.load_resource_pack(SAVED, true):
		state = "failed"
		push_warning("sound pack: not loaded (result %d, HTTP %d, %d bytes)" % [result, code, body.size()])
		return
	state = "loaded"
	print("sound pack: loaded")
	loaded.emit()
