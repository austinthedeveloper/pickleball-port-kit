## The version and build on the title (playbook §9, design/VERSIONING.md):
## the version from project.godot, and the build: `git describe --tags
## --always --dirty` of the commit an export was made from, written to
## res://build_id.txt by tools/export.sh (which refuses a dirty tree for a
## release). Run from the editor or a checkout, it asks git directly and
## says DEV.
class_name BuildInfo
extends RefCounted

const FILE := "res://build_id.txt"


static func id() -> String:
	var git := from_git()
	if git != "":
		return "DEV " + git          # a checkout: a leftover build_id.txt would be stale
	if FileAccess.file_exists(FILE):
		return FileAccess.get_file_as_string(FILE).strip_edges()
	return "DEV"


## The checkout's describe string, or "" without git (an export).
static func from_git() -> String:
	if OS.has_feature("template"):
		return ""
	var out := []
	var root := ProjectSettings.globalize_path("res://").path_join("..")
	if OS.execute("git", ["-C", root, "describe", "--tags", "--always", "--dirty"], out) != 0 or out.is_empty():
		return ""
	return String(out[0]).strip_edges()


static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## The title's line, upper case for the bitmap font (it has no lower
## case): "V0.1.0" for a release build exported at its tag, otherwise the
## version and the build ("V0.1.0  DEV V0.1.0-3-GABC1234").
static func label() -> String:
	var v := "V" + version()
	var b := id()
	if b == "v" + version():
		return v
	return (v + "  " + b).to_upper()
