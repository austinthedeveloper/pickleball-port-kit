## Career players (ADR-047), career.c in its order: three save slots, each
## a named player with a look, lifetime stats, and unlocked hats and hair.
## The active player is 1P; stats record from finished points and matches
## against the CPU, outside the attract demo and practice. Pure: ints and
## strings, no Nodes. The save (meta/save.gd) keeps one Career and writes
## it; the match hooks (MatchView) and the CAREER page change it.
##
## The data (skins, hair colours, hats, unlocks, gear) is data/career.json,
## the SNES asset build's source; career_data.h's tables are read from it.
class_name Career
extends RefCounted

const PATH := "res://data/career.json"

const SLOTS := 3
const NAME := 8                  ## letters, space-padded
const TEAMS := 8                 ## ladder teams (Opponents.count(), checked)
const NONE := -1                 ## no active player (CAREER_NONE)
const FREE := -1                 ## an item no unlock gates (CAREER_FREE)
const COUNTER_MAX := 9999        ## SAVE_COUNTER_MAX: four digits on screen
## Player.park (SNES ADR-070), save.h's byte: the highest court reached in
## the top two bits, the rating less PARK_BASE tenths below (0: unrated).
const PARK_BASE := 19            ## 2.0 is stored as 1
const PARK_RATING := 0x3f
const PARK_COURT_SHIFT := 6

const RULE_WINS := 0
const RULE_RALLY := 1
const RULE_ACES := 2
const RULE_SHUTOUTS := 3
const RULE_STREAK := 4
const RULE_BEAT := 5
const RULE_CLEARS := 6
const RULE_OPEN := 7
const RULE_NAMES := ["WINS", "RALLY", "ACES", "SHUTOUTS", "STREAK", "BEAT", "CLEARS", "OPEN"]

## career.json, as career_data.h has it.
static var _loaded := false
static var skin_names: Array = []        ## opponents.json's skins, in order
static var hair_names: Array = []
static var hair_rgb5: Array = []         ## [r, g, b] 5-bit per hair colour
static var hair_unlock: Array = []       ## unlock bit, or FREE
static var hat_names: Array = []         ## HAT id order (0 the cap)
static var hat_unlock: Array = []
static var unlock_names: Array = []
static var unlock_rule: Array = []
static var unlock_value: Array = []      ## BEAT: the ladder team's index
static var unlock_how: Array = []        ## the card's hint (NEXT: ...)
## Per hat: [power, control, speed] shifts (stage 4's gear).
static var hat_gear: Array = []


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var names := []
	for u in d["unlocks"]:
		names.append(String(u["name"]))
	for s in d["skins"]:
		skin_names.append(String(s))
	for h in d["hair"]:
		hair_names.append(String(h[0]))
		hair_rgb5.append([int(h[1][0]), int(h[1][1]), int(h[1][2])])
		hair_unlock.append(names.find(String(h[2])) if h.size() > 2 else FREE)
	for h in d["hats"]:
		hat_names.append(String(h[0]))
		hat_unlock.append(names.find(String(h[1])) if h.size() > 1 else FREE)
		var g: Dictionary = d["gear"].get(String(h[0]), {})
		hat_gear.append([int(g.get("power", 0)), int(g.get("control", 0)), int(g.get("speed", 0))])
	for u in d["unlocks"]:
		unlock_names.append(String(u["name"]))
		var rule := RULE_NAMES.find(String(u["rule"]))
		unlock_rule.append(rule)
		if rule == RULE_BEAT:
			var team := -1
			for i in Opponents.count():
				if String(Opponents.team(i)["team"]) == String(u["value"]):
					team = i
			unlock_value.append(team)
		else:
			unlock_value.append(int(u["value"]))
		unlock_how.append(String(u["how"]))


static func skins() -> int:
	_load()
	return skin_names.size()


static func hairs() -> int:
	_load()
	return hair_names.size()


static func hats() -> int:
	_load()
	return hat_names.size()


## The bare head's id (CAREER_HAT_NONE): after the first six, with the
## hats SNES ADR-060 added after it.
static func hat_none() -> int:
	_load()
	return hat_names.find("NONE")


static func unlocks() -> int:
	_load()
	return unlock_names.size()


## A career player (save.h's CareerPlayer): counters, then the look.
## Counters saturate at COUNTER_MAX, beaten[] at 255.
class Player:
	var wins := [0, 0]           ## by K.MODE_*, against the CPU
	var losses := [0, 0]
	var points_won := 0
	var points_lost := 0
	var aces := 0                ## your serves that were not returned
	var shutouts := 0
	var streak := 0
	var best_streak := 0
	var longest_rally := 0
	var ladder_clears := 0
	var open_play := 0           ## open play games finished
	var unlocked := 0            ## bit n: career.json's unlock n
	var used := 0                ## 0: an empty slot
	var name := "        "       ## NAME letters, space-padded
	var variant := K.VARIANT_MALE
	var skin := 0
	var hair := 0
	var shirt := 0               ## a PlayerSelect.PAL_* team colour
	var hat := 0                 ## HAT id, 0 the cap
	var paddle := Paddles.STANDARD
	var beaten := [0, 0, 0, 0, 0, 0, 0, 0]   ## wins over each ladder team
	var park := 0                ## the park rating and court (PARK_*), 0 a new player

	func _init() -> void:
		Career._load()           # the tables, before anything reads them

	const KEYS := ["wins", "losses", "points_won", "points_lost", "aces", "shutouts",
		"streak", "best_streak", "longest_rally", "ladder_clears", "open_play", "unlocked",
		"used", "name", "variant", "skin", "hair", "shirt", "hat", "paddle", "beaten", "park"]

	func copy() -> Player:
		var p := Player.new()
		p.assign(self)
		return p

	func assign(o: Player) -> void:
		for k in KEYS:
			var v = o.get(k)
			set(k, v.duplicate() if v is Array else v)

	func to_dict() -> Dictionary:
		var d := {}
		for k in KEYS:
			var v = get(k)
			d[k] = v.duplicate() if v is Array else v
		return d

	## A saved player, each value made valid (a hand-edited save can't
	## crash a screen).
	static func from_dict(d: Dictionary) -> Player:
		var p := Player.new()
		if d.is_empty():
			return p
		for k in ["points_won", "points_lost", "aces", "shutouts", "streak", "best_streak",
				"longest_rally", "ladder_clears", "open_play"]:
			p.set(k, clampi(int(d.get(k, 0)), 0, COUNTER_MAX))
		for k in ["wins", "losses"]:
			var a: Array = d.get(k, [0, 0])
			for i in mini(a.size(), 2):
				p.get(k)[i] = clampi(int(a[i]), 0, COUNTER_MAX)
		var b: Array = d.get("beaten", [])
		for i in mini(b.size(), TEAMS):
			p.beaten[i] = clampi(int(b[i]), 0, 255)
		p.unlocked = int(d.get("unlocked", 0)) & 0xffff
		p.park = int(d.get("park", 0)) & 0xff
		p.used = 1 if int(d.get("used", 0)) else 0
		p.name = (String(d.get("name", "")) + "        ").substr(0, NAME)
		p.variant = clampi(int(d.get("variant", 0)), 0, 1)
		p.skin = clampi(int(d.get("skin", 0)), 0, Career.skins() - 1)
		p.hair = clampi(int(d.get("hair", 0)), 0, Career.hairs() - 1)
		p.shirt = clampi(int(d.get("shirt", 0)), 0, PlayerSelect.PAL_COUNT - 1)
		p.hat = clampi(int(d.get("hat", 0)), 0, Career.hats() - 1)
		p.paddle = clampi(int(d.get("paddle", Paddles.STANDARD)), 0, Paddles.NAMES.size() - 1)
		return p

	## The name without its padding.
	func shown_name() -> String:
		return name.strip_edges(false, true)


var players: Array = []          ## SLOTS Players
var active := NONE               ## slot, or NONE
## The unlocks newly earned by the last finished match (bit n: unlock n);
## never saved, for the result screen (g_career_new_unlocks).
var new_unlocks := 0
## The park rating before and after the last finished park game, in tenths
## (OpenPlay.RATING_NONE before: not rated), and a court it opened (or
## OpenPlay.NONE); never saved, for the result (g_career_park_*).
var park_before := OpenPlay.RATING_NONE
var park_after := OpenPlay.RATING_NONE
var park_opened := OpenPlay.NONE


func _init() -> void:
	_load()
	for i in SLOTS:
		players.append(Player.new())


func to_dict() -> Dictionary:
	var out := []
	for p in players:
		out.append(p.to_dict())
	return {"active": active, "players": out}


static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	var saved: Array = d.get("players", [])
	for i in mini(saved.size(), SLOTS):
		if typeof(saved[i]) == TYPE_DICTIONARY:
			c.players[i] = Player.from_dict(saved[i])
	c.active = int(d.get("active", NONE))
	if c.active < 0 or c.active >= SLOTS:
		c.active = NONE
	return c


## The active player, or null when none is chosen.
func active_player() -> Player:
	var slot := active
	if slot < 0 or slot >= SLOTS:
		return null
	if players[slot].used == 0:
		return null
	return players[slot]


## A new player in an empty slot with a name (NAME letters or fewer, cut
## to fit), the default look, and no stats; made active. False if the
## slot is taken.
func create(slot: int, player_name: String) -> bool:
	if slot < 0 or slot >= SLOTS:
		return false
	var player: Player = players[slot]
	if player.used:
		return false
	player.assign(Player.new())
	player.used = 1
	player.name = (player_name.substr(0, NAME) + "        ").substr(0, NAME)
	player.variant = K.VARIANT_MALE
	player.shirt = PlayerSelect.PAL_BLUE
	player.paddle = Paddles.STANDARD
	active = slot
	return true


## Empties a slot; if it was active, no player is active.
func delete(slot: int) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	players[slot].assign(Player.new())
	if active == slot:
		active = NONE


## Makes a used slot active (NONE: no player).
func select(slot: int) -> void:
	if slot >= 0 and slot < SLOTS and players[slot].used:
		active = slot
	else:
		active = NONE


static func _unlock_held(player: Player, unlock: int) -> bool:
	if unlock == FREE:
		return true
	return (player.unlocked >> unlock) & 1 != 0


static func hair_unlocked(player: Player, hair: int) -> bool:
	if hair < 0 or hair >= hairs():
		return false
	return _unlock_held(player, hair_unlock[hair])


static func hat_unlocked(player: Player, hat: int) -> bool:
	if hat < 0 or hat >= hats():
		return false
	return _unlock_held(player, hat_unlock[hat])


static func _bump(v: int) -> int:
	return v + 1 if v < COUNTER_MAX else v


## A finished point in a career match: its shots, whether 1P's team won
## it, and whether 1P served it.
func record_point(shots: int, won: bool, served: bool) -> void:
	var player := active_player()
	if player == null:
		return
	if won:
		player.points_won = _bump(player.points_won)
		# An ace: your serve, and nobody touched it after.
		if served and shots == 1:
			player.aces = _bump(player.aces)
	else:
		player.points_lost = _bump(player.points_lost)
	if shots > player.longest_rally:
		player.longest_rally = shots


# --- The park rating (SNES ADR-070) -------------------------------------------

## A player's park rating in tenths (3.0 until their first game).
static func park_rating(player: Player) -> int:
	var stored := player.park & PARK_RATING
	return stored + PARK_BASE if stored else OpenPlay.RATING_START


## The highest court a player has reached.
static func park_court(player: Player) -> int:
	var court := player.park >> PARK_COURT_SHIFT
	return court if court < OpenPlay.COURTS else OpenPlay.COURTS - 1


## A park game on a court: the rating moves (OpenPlay.rating_after) and a
## court it reaches opens; sets park_*.
func rate_park(player: Player, court: int, won: bool) -> void:
	var before := park_rating(player)
	var after := OpenPlay.rating_after(before, court, won)
	var best := park_court(player)
	var reached := OpenPlay.rating_court(after)
	park_before = before
	park_after = after
	park_opened = OpenPlay.NONE
	if reached > best:
		best = reached
		park_opened = reached
	player.park = (best << PARK_COURT_SHIFT) | (after - PARK_BASE)


## A finished career match against the CPU; opponent is the ladder team
## (-1 for the default CPU), open_play a park game: its court + 1 (0 not
## one), rated unless the match is on KID (`kid`). Updates the stats, the
## unlocks (new_unlocks) and the park rating (park_*); the caller writes
## the save. (The C rates the park on the next frame, career_park_flush,
## for the SNES's frame budget; here it is at once.)
func record_match(mode: int, won: bool, points_against: int, opponent: int,
		open_play: int, kid := false) -> void:
	var player := active_player()
	new_unlocks = 0
	park_before = OpenPlay.RATING_NONE
	park_opened = OpenPlay.NONE
	if player == null:
		return
	if mode > K.MODE_DOUBLES:
		mode = K.MODE_DOUBLES
	if open_play:
		player.open_play = _bump(player.open_play)
		# KID's games are all KID (ADR-034): not rated.
		if not kid:
			rate_park(player, open_play - 1, won)
	if won:
		player.wins[mode] = _bump(player.wins[mode])
		player.streak = _bump(player.streak)
		if player.streak > player.best_streak:
			player.best_streak = player.streak
		if points_against == 0:
			player.shutouts = _bump(player.shutouts)
		if opponent >= 0 and opponent < Opponents.count():
			if player.beaten[opponent] < 255:
				player.beaten[opponent] += 1
			# The ladder's last team, on the ladder (not at the park).
			if opponent == Opponents.count() - 1 and not open_play:
				player.ladder_clears = _bump(player.ladder_clears)
	else:
		player.losses[mode] = _bump(player.losses[mode])
		player.streak = 0
	new_unlocks = check_unlocks(player)


## The player's count for a rule (BEAT: wins over that team).
static func rule_count(player: Player, rule: int, value: int) -> int:
	match rule:
		RULE_WINS:
			return player.wins[0] + player.wins[1]
		RULE_RALLY:
			return player.longest_rally
		RULE_ACES:
			return player.aces
		RULE_SHUTOUTS:
			return player.shutouts
		RULE_STREAK:
			return player.best_streak
		RULE_BEAT:
			return player.beaten[value] if value >= 0 and value < TEAMS else 0
		RULE_CLEARS:
			return player.ladder_clears
		RULE_OPEN:
			return player.open_play
	return 0


## (career_compose_with / career_compose_palette are the view's:
## PlayerLook.for_career.)


## Unlocks whose rules the player now meets and did not have; marks them.
## Returns the new ones.
static func check_unlocks(player: Player) -> int:
	var earned := 0
	var bit := 1
	for i in unlocks():
		if player.unlocked & bit == 0:
			# BEAT's value names the team: one win is enough.
			var need: int = 1 if unlock_rule[i] == RULE_BEAT else unlock_value[i]
			if rule_count(player, unlock_rule[i], unlock_value[i]) >= need:
				earned |= bit
		bit <<= 1
	player.unlocked |= earned
	return earned


# --- The CAREER page's helpers (career_page.c) --------------------------------

const BODY_NAMES := ["MALE", "FEMALE"]


static func body_name(v: int) -> String:
	return BODY_NAMES[v & 1]


static func shirt_name(shirt: int) -> String:
	return PlayerSelect.COLOUR_NAMES[shirt % PlayerSelect.PAL_COUNT]


static func paddle_name(paddle: int) -> String:
	return PlayerSelect.PADDLE_NAMES[paddle % Paddles.NAMES.size()]


## The next unlock the player has not earned, or unlocks().
static func next_unlock(player: Player) -> int:
	for i in unlocks():
		if (player.unlocked >> i) & 1 == 0:
			return i
	return unlocks()


## How many of the museum's hats the player holds (career_hats_held):
## every hat but the bare head.
static func hats_held(player: Player) -> int:
	var count := 0
	for i in hats():
		if i != hat_none() and hat_unlocked(player, i):
			count += 1
	return count


## How many unlocks the player holds.
static func unlock_count(player: Player) -> int:
	var count := 0
	for i in unlocks():
		count += (player.unlocked >> i) & 1
	return count


## The unlocks in a mask, for the UNLOCKED! card (hud_unlock_text):
## "VISOR, PINK HAIR", and " +n" for any past `fit` letters.
static func unlock_text(mask: int, fit := 24) -> String:
	var text := ""
	var more := 0
	for i in unlocks():
		if mask & (1 << i) == 0:
			continue
		var n: String = unlock_names[i]
		if text.length() + (2 if text != "" else 0) + n.length() > fit:
			more += 1
			continue
		text += (", " if text != "" else "") + n
	if more:
		text += " +%d" % more
	return text
