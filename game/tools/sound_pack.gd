## Makes the Web build's sound pack (PORT-154, meta/sound_pack.gd): the
## music and ambience Oggs as imported (each one's .import and its
## .godot/imported file), from a project that has imported them (export.sh
## runs it in build/web-src).
##   godot --headless --path <project> -s res://tools/sound_pack.gd -- <out.pck>
extends SceneTree

const DIR := "res://assets/audio/"


## The Web preset's exclude_filter, but for the music and ambience it
## leaves to this pack: what the Web build has none of (the painted
## venues' tracks) stays out of the pack too.
static func web_excluded() -> Array:
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		return []
	for s in presets.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options") \
				and presets.get_value(s, "name", "") == "Web":
			var out := []
			for pat in String(presets.get_value(s, "exclude_filter", "")).split(","):
				pat = pat.strip_edges()
				if pat != "" and not pat in ["assets/audio/music_*.ogg", "assets/audio/ambience_*.ogg"]:
					out.append(pat)
			return out
	return []


## The files the pack holds: [path in the pack, source] pairs.
static func entries() -> Array:
	var out := []
	var skip := web_excluded()
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".ogg.import"):
			continue
		if not (f.begins_with("music_") or f.begins_with("ambience_")):
			continue
		var src := "assets/audio/" + f.trim_suffix(".import")
		if skip.any(func(pat: String) -> bool: return src.match(pat)):
			continue                       # not in the Web build at all
		var imp := DIR + f
		out.append([imp, imp])
		var cfg := ConfigFile.new()
		if cfg.load(imp) != OK:
			continue
		var path := String(cfg.get_value("remap", "path", ""))
		if path != "":
			out.append([path, path])
	return out


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://sound.pck"
	var pck := PCKPacker.new()
	if pck.pck_start(out) != OK:
		printerr("sound pack: can't write ", out)
		quit(1)
		return
	var n := 0
	for e: Array in entries():
		if pck.add_file(String(e[0]), String(e[1])) != OK:
			printerr("sound pack: can't add ", e[1])
			quit(1)
			return
		n += 1
	pck.flush()
	print("sound pack: %d files in %s" % [n, out])
	quit(0)
