## The build ID on the title (playbook §9): `git describe --always
## --dirty` of the commit an export was made from, written to
## res://build_id.txt by tools/export.sh (which refuses a dirty tree for a
## release). Run from the editor or a checkout, it asks git directly and
## says DEV.
class_name BuildInfo
extends RefCounted

const FILE := "res://build_id.txt"


static func id() -> String:
	if FileAccess.file_exists(FILE):
		return FileAccess.get_file_as_string(FILE).strip_edges()
	var git := from_git()
	return "DEV " + git if git != "" else "DEV"


## The checkout's describe string, or "" without git (an export).
static func from_git() -> String:
	if OS.has_feature("template"):
		return ""
	var out := []
	var root := ProjectSettings.globalize_path("res://").path_join("..")
	if OS.execute("git", ["-C", root, "describe", "--always", "--dirty"], out) != 0 or out.is_empty():
		return ""
	return String(out[0]).strip_edges()


## The title's line: upper case for the bitmap font (it has no lower case).
static func label() -> String:
	return "BUILD " + id().to_upper()
