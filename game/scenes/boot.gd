## The first scene (PORT-32, ADR-057): starts the game, from a downloaded
## update if there's a newer one.
##
## An update is a newer release's .pck in user://updates/ (the updater
## writes current.json beside it). If it's newer than this build, for this
## engine, and its last start reached the title, its pack is loaded over
## this one; then the game starts: the input map's node and the updater
## (once autoloads), and the title. Everything they load comes from the
## update, so an update can change anything but this file. Keep it small,
## and never load a game script here before the pack.
##
## A start on an update is marked `booting` until the title clears it, so a
## broken update is skipped the next time.
extends Node

const CURRENT := "user://updates/current.json"


func _ready() -> void:
	var c := _read()
	var pack := choose(c, String(ProjectSettings.get_setting("application/config/version", "0")),
		_engine())
	if pack != "" and FileAccess.file_exists(pack):
		c["booting"] = true
		_write(c)
		if ProjectSettings.load_resource_pack(pack, true):
			# the version this game now is (BuildInfo reads it)
			ProjectSettings.set_setting("application/config/version", String(c["version"]))
	_start.call_deferred()


func _start() -> void:
	var tree := get_tree()
	for pair in [["Controls", "res://game_ui/controls.gd"], ["Updates", "res://meta/updater.gd"]]:
		if tree.root.has_node(pair[0]):
			continue
		var n: Node = load(pair[1]).new()
		n.name = pair[0]
		tree.root.add_child(n)
	tree.change_scene_to_file("res://scenes/main.tscn")


## The pack to load, or "": the update's, if it's newer than `built_in`,
## for engine `eng`, and its last start reached the title.
static func choose(c: Dictionary, built_in: String, eng: String) -> String:
	if c.is_empty() or String(c.get("engine", "")) != eng or bool(c.get("booting", false)):
		return ""
	if _compare(String(c.get("version", "0")), built_in) <= 0:
		return ""
	return String(c.get("file", ""))


## -1, 0, 1 as `a` is older, the same, newer than `b` (Updater.compare's twin:
## this file can't load the game's scripts).
static func _compare(a: String, b: String) -> int:
	var x := a.trim_prefix("v").split(".")
	var y := b.trim_prefix("v").split(".")
	for i in maxi(x.size(), y.size()):
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return 1 if p > q else -1
	return 0


static func _engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


static func _read() -> Dictionary:
	if not FileAccess.file_exists(CURRENT):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(CURRENT))
	return v if v is Dictionary else {}


static func _write(d: Dictionary) -> void:
	var f := FileAccess.open(CURRENT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
