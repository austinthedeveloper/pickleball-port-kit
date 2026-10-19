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
	if slot == 1 and not cfg.human[1] and cfg.partner >= 0 and cfg.partner < Opponents.count():
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
static func for_team(team: int, body_variant: int, paddle: int, manifest: Dictionary) -> PlayerLook:
	var look := PlayerLook.new()
	look.variant = "female" if body_variant == K.VARIANT_FEMALE else "male"
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	var pals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/levels/" + String(roles["palettes"])))
	var t: Dictionary = pals["teams"][TEAMS[team]]
	var c := {".": Color.TRANSPARENT}
	for src in [pals["base"], t, pals["paddles"][Paddles.NAMES[paddle]], pals["skins"]["light"],
			pals["hairs"]["brown"]]:
		for k in src:
			c[k] = _rgb8(src[k])
	c["k"] = _rgb8(t["M"])
	c["K"] = _rgb8(t["d"])
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
	return look


static func from_member(m: Dictionary, manifest: Dictionary) -> PlayerLook:
	var look := PlayerLook.new()
	look.variant = String(m.get("variant", "male"))
	look.hat = String(m.get("hat", "cap"))
	var roles: Dictionary = manifest["sprites"]["players"]["roles"]
	var pals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/levels/" + String(roles["palettes"])))
	look.palette = palette_for(m, String(roles["order"]), pals)
	return look


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
	for k in "DdMLkK":
		var i := order.find(k)
		palette[i] = neon(palette[i])


## The role sheets (hat "" for bareheaded) and one material for both.
func body_sheet(manifest: Dictionary) -> String:
	return manifest["sprites"]["players"]["roles"]["files"][variant]["body"]


func hat_sheet(manifest: Dictionary) -> String:
	var files: Dictionary = manifest["sprites"]["players"]["roles"]["files"][variant]
	return files.get(hat, "")


func material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("palette", palette)
	return mat
