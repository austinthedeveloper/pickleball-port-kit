## A ladder opponent's look (M4-OPP-04): their colours from opponents.json
## as a palette for the indexed role sheets, and their hat. Also a human's
## team colours with a non-standard paddle (ADR-020: the paddle you pick
## shows in your hands). Display only.
class_name PlayerLook
extends RefCounted

const SHADER := preload("res://view/palette_swap.gdshader")
const ROLE_COUNT := 32
const TEAMS := ["blue", "red", "green", "gold"]

var variant := "male"
var hat := "cap"                 ## "cap", a manifest roles hat, or "hair" (none)
var pattern := ""                ## a manifest roles pattern (ADR-095), "" plain
var head := ""                   ## a manifest roles head (ADR-099), "" the classic
var palette := PackedColorArray()


## The look of a slot, or null for the team-colour sheets: ladder
## opponents on slots 2-3 (the same members config_for picks), and an
## open play partner's captain on slot 1 (ADR-034).
static func for_slot(cfg: SimTypes.MatchConfig, slot: int, manifest: Dictionary) -> PlayerLook:
	if slot == 0 and cfg.career_p1 and cfg.career and cfg.palette[0] >= 0:
		return for_career(cfg.career, cfg.palette[0], cfg.variant[0], cfg.paddle[0], manifest)
	if cfg.human[slot] and cfg.palette[slot] >= 0 \
			and not sheet_has_paddle(cfg.palette[slot], cfg.paddle[slot]):
		return for_team(cfg.palette[slot], cfg.variant[slot], cfg.paddle[slot], manifest)
	if slot == 1 and not cfg.human[1] and Opponents.exists(cfg.partner):
		return from_member(Opponents.team(cfg.partner)["players"][0], manifest)
	if not Opponents.exists(cfg.opponent) or cfg.human[2] or slot < 2:
		return null
	var members: Array = Opponents.team(cfg.opponent)["players"]
	var m: Dictionary = members[mini(slot - 2, members.size() - 1)]
	return from_member(m, manifest)


## The team-colour sheets hold the paddle in the shirt's colour (CPUs
## keep them, KNOWN_ISSUES #37); a human's chosen paddle is drawn.
static func sheet_has_paddle(team: int, paddle: int) -> bool:
	return Paddles.NAMES[paddle] == TEAMS[team]


## The team-colour sheets' look (light skin, brown hair, the cap) with any
## paddle: base + team + paddle + skin + hair, shoe accent from the team.
## A team-colour sheet's path under MatchView.LEVELS: `variant` "male" or
## "female", `team` a TEAMS name; the cap overlay or the body.
static func team_sheet(variant: String, team: String, cap: bool) -> String:
	return "sprites/players/player_%s_%s%s.png" % [variant, team, "_cap" if cap else ""]


static func variant_name(body_variant: int) -> String:
	return "female" if body_variant == K.VARIANT_FEMALE else "male"


## palettes.json, read once (every look reads it; it doesn't change).
static var _palettes := {}

static func palettes(roles: Dictionary) -> Dictionary:
	if _palettes.is_empty():
		_palettes = JSON.parse_string(FileAccess.get_file_as_string(
			MatchView.LEVELS + String(roles["palettes"])))
	return _palettes


static func for_team(team: int, body_variant: int, paddle: int, manifest: Dictionary) -> PlayerLook:
	var look := PlayerLook.new()
	look.variant = variant_name(body_variant)
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	var pals := palettes(roles)
	var t: Dictionary = pals["teams"][TEAMS[team]]
	var c := {".": Color.TRANSPARENT}
	for src in [pals["base"], t, pals["paddles"][Paddles.NAMES[paddle]], pals["skins"]["light"],
			pals["hairs"]["brown"]]:
		for k in src:
			c[k] = _rgb8(src[k])
	c["k"] = _rgb8(t["M"])
	c["K"] = _rgb8(t["d"])
	c["y"] = c["d"]              # no pattern: the design ramp is the shirt's
	c["Y"] = c["M"]
	var order := String(roles["order"])
	look.palette.resize(ROLE_COUNT)
	for i in order.length():
		look.palette[i] = c.get(order[i], Color.MAGENTA)
	return look


## A career player (ADR-047, career_compose_with): their skin ramp and
## hair, in a team colour's shirt and shorts (one match's Player Select
## choice, or their saved one) with a paddle, and their hat. Hair and
## skin are 5-bit (career.json, opponents.json's skins), widened as
## palette_for widens a ladder member's.
static func for_career(player: Career.Player, shirt: int, body_variant: int, paddle: int,
		manifest: Dictionary) -> PlayerLook:
	var look := for_team(shirt, body_variant, paddle, manifest)
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	var order := String(roles["order"])
	var c := {}
	var skin: Array = Opponents.skin(String(Career.skin_names[player.skin]).to_lower())
	c["2"] = rgb5(skin[0])
	c["3"] = rgb5(skin[1])
	c["4"] = rgb5(skin[2])
	c["1"] = c["2"].darkened(0.3)
	c["H"] = rgb5(Career.hair_rgb5[player.hair])
	c["h"] = c["H"].darkened(0.4)
	c["i"] = c["H"].lerp(Color.WHITE, 0.3)
	for k in c:
		var i := order.find(k)
		if i >= 0:
			look.palette[i] = c[k]
	var hat: String = String(Career.hat_names[player.hat]).to_lower()
	look.hat = "hair" if hat == "none" else hat
	look.set_pattern(String(Career.pattern_sheets[player.pattern % Career.patterns()]), [], manifest)
	look.set_head(Career.head_sheet(player), manifest)
	return look


static func from_member(m: Dictionary, manifest: Dictionary) -> PlayerLook:
	var look := PlayerLook.new()
	look.variant = String(m.get("variant", "male"))
	look.hat = String(m.get("hat", "cap"))
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	var pals := palettes(roles)
	look.palette = palette_for(m, String(roles["order"]), pals)
	look.set_pattern(String(m.get("pattern", "")), m.get("pattern_color", []), manifest)
	look.set_head(String(m.get("head", "")), manifest)
	return look


## A generated head (ADR-099) for this body, or "" (the classic head) when
## the manifest has none by that name.
func set_head(name: String, manifest: Dictionary) -> void:
	var files: Dictionary = manifest["sprites"]["players"]["roles"]["files"][variant]
	head = name if name != "" and files.has("head_" + name) else ""


## A shirt pattern (ADR-095) and its design ramp (y shadow, Y base): 5-bit
## [shadow, base] from opponents.json, else palettes.json's default.
func set_pattern(name: String, rgb5s: Array, manifest: Dictionary) -> void:
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	if name == "" or not roles["patterns"].has(name):
		pattern = ""
		return
	pattern = name
	var order := String(roles["order"])
	var c := {}
	if rgb5s.size() == 2:
		c["y"] = rgb5(rgb5s[0])
		c["Y"] = rgb5(rgb5s[1])
	else:
		var d: Dictionary = palettes(roles)["patterns"][name]
		c["y"] = _rgb8(d["y"])
		c["Y"] = _rgb8(d["Y"])
	for k in c:
		palette[order.find(k)] = c[k]


## Roles a pre-coloured sheet takes from palettes.json (base, the paddle)
## and the rest from the member's 5-bit colours. The SNES roles have fewer
## steps than the 960x540 ones, so the deep shirt (D), deep skin (1), hair
## shadow and shine (h, i), bright shorts (W) and shoe shadow (K) are
## derived from their neighbours.
static func palette_for(m: Dictionary, order: String, pals: Dictionary) -> PackedColorArray:
	var c := {".": Color.TRANSPARENT}
	for src in [pals["base"], pals["paddles"].get(String(m.get("paddle", "blue")), pals["paddles"]["blue"])]:
		for k in src:
			c[k] = _rgb8(src[k])
	var skin: Array = Opponents.skin(String(m.get("skin", "light")))
	c["2"] = rgb5(skin[0])
	c["3"] = rgb5(skin[1])
	c["4"] = rgb5(skin[2])
	c["1"] = c["2"].darkened(0.3)
	var shirt: Array = m["shirt"]
	c["d"] = rgb5(shirt[0])
	c["M"] = rgb5(shirt[1])
	c["L"] = rgb5(shirt[2])
	c["D"] = c["d"].darkened(0.38)
	var shorts: Array = m["shorts"]
	c["q"] = rgb5(shorts[0])
	c["w"] = rgb5(shorts[1])
	c["W"] = c["w"].lerp(Color.WHITE, 0.5)
	c["H"] = rgb5(m["hair"])
	c["h"] = c["H"].darkened(0.4)
	c["i"] = c["H"].lerp(Color.WHITE, 0.3)
	c["k"] = rgb5(m["shoe"])
	c["K"] = c["k"].darkened(0.28)
	var out := PackedColorArray()
	out.resize(ROLE_COUNT)
	for i in order.length():
		out[i] = c.get(order[i], Color.MAGENTA)
	return out


## A 5-bit SNES colour, expanded the way the PPU's DAC reads it (v << 3 | v >> 2).
static func rgb5(v: Array) -> Color:
	var r: int = v[0]
	var g: int = v[1]
	var b: int = v[2]
	return Color8((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2))


static func _rgb8(v: Array) -> Color:
	return Color8(int(v[0]), int(v[1]), int(v[2]))


## ROAD TRIP's PLAIN PADDLE (port ADR-087): unpainted plywood and a black
## taped handle, on the rig's paddle roles (art/roadtrip-v3's palette).
const PLAIN_PADDLE := {"p": Color8(188, 163, 112), "P": Color8(188, 163, 112), "f": Color8(232, 211, 164),
	"e": Color8(24, 20, 36), "E": Color8(232, 211, 164), "G": Color8(24, 20, 36)}


func plain_paddle(manifest: Dictionary) -> void:
	var order := String(manifest["sprites"]["players"]["roles"]["order"])
	for k in PLAIN_PADDLE:
		var i := order.find(k)
		if i >= 0:
			palette[i] = PLAIN_PADDLE[k]


## GLOW (SNES ADR-054): neon outlines, a purple, pink and cyan paddle, and
## outfits (shirt, cap, the shoe accent) more saturated and a little
## brighter, keeping their ramps' order.
const NEON := Color(0.13, 1.0, 0.26)
const GLOW_PADDLE := {"G": Color8(40, 16, 70), "p": Color8(90, 20, 160), "P": Color8(150, 40, 220),
	"f": Color8(230, 40, 170), "e": Color8(255, 70, 200), "E": Color8(80, 240, 255)}


static func neon(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.5 + 0.1), minf(1.0, c.v * 1.15), c.a)


func glow(manifest: Dictionary) -> void:
	var order := String(manifest["sprites"]["players"]["roles"]["order"])
	palette[order.find("o")] = NEON
	for k in GLOW_PADDLE:
		palette[order.find(k)] = GLOW_PADDLE[k]
	for k in "DdMLkKyY":
		var i := order.find(k)
		palette[i] = neon(palette[i])


## The role sheets (hat "" for bareheaded) and one material for both.
## body_sheet is the classic head's; draw body_texture, which is a new
## head's when the look has one.
func body_sheet(manifest: Dictionary) -> String:
	return manifest["sprites"]["players"]["roles"]["files"][variant]["body_" + pattern if pattern else "body"]


func hat_sheet(manifest: Dictionary) -> String:
	var files: Dictionary = manifest["sprites"]["players"]["roles"]["files"][variant]
	return files.get(hat, "")


## Composed bodies (ADR-099), by headless sheet and head: a session's few.
static var _composed := {}


## The body to draw: the body sheet, or for a generated head the headless
## body (plain or patterned) with the head laid on it.
func body_texture(manifest: Dictionary) -> Texture2D:
	if head == "":
		return load(MatchView.LEVELS + body_sheet(manifest))
	var files: Dictionary = manifest["sprites"]["players"]["roles"]["files"][variant]
	var base: String = files["nohead_" + pattern if pattern else "nohead"]
	var key := base + "+" + head
	if not _composed.has(key):
		var img := (load(MatchView.LEVELS + base) as Texture2D).get_image()
		var top := (load(MatchView.LEVELS + String(files["head_" + head])) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		top.convert(Image.FORMAT_RGBA8)
		img.blit_rect_mask(top, top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
		_composed[key] = ImageTexture.create_from_image(img)
	return _composed[key]


## The hat to draw over body_texture, or null for bareheaded.
func hat_texture(manifest: Dictionary) -> Texture2D:
	var file := hat_sheet(manifest)
	return load(MatchView.LEVELS + file) if file != "" else null


func material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("palette", palette)
	return mat
