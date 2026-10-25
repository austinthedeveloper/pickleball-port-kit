## ROAD TRIP (PORT-82, port ADR-087, design/ROAD_TRIP.md): the remaster's
## roguelike mode. A trip is one drive to the SUMMER OPEN: three legs of
## road, each three columns of stops in three lanes and then its big match
## (the last leg's is the final). The map, every offer and every detour
## come from the trip's seed, so a trip is the same wherever it's played,
## and coming back to a pick shows the same cards. Pure: ints, strings and
## Dictionaries, no Nodes; the save keeps the trip in progress and what
## lasts between trips (save.data["trip"], RoadTrip.meta()).
class_name RoadTrip
extends RefCounted

const PATH := "res://data/trip.json"
const LEGS := 3
const COLS := 3                  ## columns of stops in a leg, before its big match
const LANES := 3
const START := -1                ## `at`'s column before a leg's first stop
const GATE := COLS               ## `at`'s column on a leg's big match (or the final)
const STAT_MIN := 1
const STAT_MAX := 20
const STATS := ["power", "control", "speed", "feet"]
const STAT_NAMES := ["POWER", "CONTROL", "SPEED", "FEET"]
const HEARTS := 3
const HEARTS_MAX := 9
const HEAT_MAX := 5
const PARTNER_STAT := 6          ## a partner's stats at the start of a trip
## A partner's late swing (port ADR-091): every PARTNER_LATE-th ball at the
## start of a trip (a ladder partner's Pepper is every 7th, which let too
## many go by), PARTNER_LATE_STEP more balls apart per CONTROL point over
## PARTNER_STAT. A partner who is never late stays so.
const PARTNER_LATE := 12
const PARTNER_LATE_STEP := 2
## Leg 1's CPU ERRORS, % of the rest of the trip's (port ADR-091): its
## teams are late every 2nd or 3rd ball, so its rallies were 3 to 5 shots.
const LEG_1_ERRORS := 60
const PEPPER := -1               ## `partner`: Pepper, not a ladder captain

## Stop types. The ones that give gear (or a chance to buy it): no road
## has two stops without one in a row.
const MATCHES := ["pickup", "grudge", "big", "final"]
const PICKS := ["grudge", "yard", "shop", "detour"]
const WEIGHTS := {"pickup": 40, "grudge": 14, "yard": 12, "shop": 12, "motel": 10, "detour": 16}
const RARITY_WEIGHTS := {"common": 60, "uncommon": 30, "rare": 10}
const PRICES := {"common": 30, "uncommon": 45, "rare": 65}
const SODA := 25                 ## the PRO SHOP's heart
const FIX := 15                  ## the PRO SHOP's hazard lifted
const SKIP_CASH := 5

static var _data: Dictionary = {}

var seed := 1
var gen := 1                     ## the generator's version (a saved map is kept as made)
var heat := 0
var partner := PEPPER
var map: Array = []              ## per leg {"cols": [[node x LANES] x COLS], "gate": node}
var at: Array = [0, START, 1]    ## leg, column, lane
var hearts := HEARTS
var max_hearts := HEARTS
var cash := 0
var base: Array = [STAT_MIN, STAT_MIN, STAT_MIN, STAT_MIN]
var partner_stats: Array = [PARTNER_STAT, PARTNER_STAT, PARTNER_STAT, PARTNER_STAT]
var paddle := "plain_paddle"
var hat := "plain_cap"
var bag: Array = []              ## gear ids, in the order picked
var hazards: Array = []          ## hazard ids waiting for the next match
var used: Array = []             ## once-only items spent (rain check, umbrella)
var pending: Dictionary = {}     ## an offer not yet taken: {"kind": "pick", "items": [...]}
var beaten: Array = []           ## ladder teams beaten on this trip
var route: Array = []            ## the stops driven to, [leg, col, lane] each
var stops := 0                   ## stops reached
var wins := 0
var losses := 0
var miles := 0                   ## this trip's
var state := "on"                ## "on", "won", "over"


# --- Data ------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func gear(id: String) -> Dictionary:
	for g in data()["gear"]:
		if String(g["id"]) == id:
			return g
	return {}


static func hazard(id: String) -> Dictionary:
	for h in data()["hazards"]:
		if String(h["id"]) == id:
			return h
	return {}


static func detour(id: String) -> Dictionary:
	for d in data()["detours"]:
		if String(d["id"]) == id:
			return d
	return {}


static func leg_info(leg: int) -> Dictionary:
	return data()["legs"][clampi(leg, 0, LEGS - 1)]


static var _k_consts: Dictionary = {}

## A MOD_* name's bit (trip.json names modifiers as K does).
static func mod_bits(name: String) -> int:
	if not name.begins_with("MOD_"):
		return 0
	if _k_consts.is_empty():
		_k_consts = (load("res://sim/k.gd") as GDScript).get_script_constant_map()
	return int(_k_consts.get(name, 0))


# --- Randomness: the trip's seed, mixed with what's being decided ---------------

## A number 0..n-1 from the seed and two salts (where on the map, what
## for); the same inputs always give the same number.
static func roll(s: int, a: int, b: int, n: int) -> int:
	var h := (s * 1103515245 + a * 40503 + b * 2654435 + 12345) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return h % maxi(1, n)


## A weighted pick: `table` maps a name to its weight.
static func pick_weighted(table: Dictionary, s: int, a: int, b: int) -> String:
	var total := 0
	for k in table:
		total += int(table[k])
	var r := roll(s, a, b, total)
	for k in table:
		r -= int(table[k])
		if r < 0:
			return String(k)
	return String(table.keys()[0])


# --- A new trip ---------------------------------------------------------------------

## A trip from `trip_seed` at HEAT `heat_level`, with `who` as your partner
## (PEPPER, or a ladder captain you've unlocked) and the GARAGE's lasting
## rewards from `meta_dict` (RoadTrip.meta()).
static func create(trip_seed: int, heat_level: int, who: int, meta_dict: Dictionary = {}) -> RoadTrip:
	var t := RoadTrip.new()
	t.seed = trip_seed & 0x7fffffff
	if t.seed == 0:
		t.seed = 1
	t.heat = clampi(heat_level, 0, HEAT_MAX)
	t.partner = who
	t.map = generate(t.seed, t.heat)
	var g := garage(meta_dict)
	for i in 4:
		t.base[i] = clampi(STAT_MIN + int(g["stats"][i]), STAT_MIN, STAT_MAX)
	t.max_hearts = (2 if t.heat >= 2 else HEARTS) + int(g["hearts"])
	t.hearts = t.max_hearts
	t.cash = int(g["cash"])
	if String(g["paddle"]) != "":
		t.paddle = String(g["paddle"])
	if String(g["item"]) != "" and not gear(String(g["item"])).is_empty():
		t.bag.append(String(g["item"]))
		t._apply_hearts(String(g["item"]))
	if t.heat >= 3:
		var all: Array = data()["hazards"]
		t.hazards.append(String(all[roll(t.seed, 77, 0, all.size())]["id"]))
	return t


## The map: per leg, COLS columns of LANES stops and the big match. Each
## leg is drawn until it keeps the rules (valid_leg); the same seed always
## draws the same map.
static func generate(s: int, heat_level: int) -> Array:
	var out := []
	var used_detours := []
	for leg in LEGS:
		var info := leg_info(leg)
		var bigs: Array = info["big"]
		var big_team := int(bigs[roll(s, leg, 1, bigs.size())])
		var leg_map := {}
		for attempt in 400:
			leg_map = _draw_leg(s, leg, attempt, big_team, heat_level, used_detours)
			if valid_leg(leg_map, leg, heat_level):
				break
		for col in leg_map["cols"]:
			for n in col:
				if n["type"] == "detour":
					used_detours.append(n["detour"])
		out.append(leg_map)
	return out


static func _draw_leg(s: int, leg: int, attempt: int, big_team: int, heat_level: int,
		used_detours: Array) -> Dictionary:
	var info := leg_info(leg)
	var venues: Array = info["venues"]
	var weights := WEIGHTS.duplicate()
	if leg == 0 or heat_level >= 5:
		weights.erase("motel")
	var salt := leg * 1000 + attempt * 37
	var cols := []
	for c in COLS:
		var col := []
		for lane in LANES:
			var k := salt + c * 10 + lane
			var type := pick_weighted(weights, s, k, 3)
			var node := {"type": type, "venue": String(venues[roll(s, k, 5, venues.size())]),
				"time": _time_of(s, k), "edges": [], "team": -1, "local": -1, "mod": "", "detour": "",
				"done": false}
			if type == "grudge":
				_grudge(node, s, k, leg, big_team)
			elif type == "pickup":
				node["local"] = roll(s, k, 9, data()["locals"].size())
			elif type == "detour":
				var ds: Array = data()["detours"].filter(func(d): return not used_detours.has(d["id"]))
				if ds.is_empty():
					ds = data()["detours"]
				node["detour"] = String(ds[roll(s, k, 11, ds.size())]["id"])
			col.append(node)
		cols.append(col)
	# roads: each stop to its own lane in the next column, sometimes one
	# lane over as well, never two roads crossing
	for c in COLS - 1:
		for lane in LANES:
			cols[c][lane]["edges"] = [lane]
		for lane in LANES - 1:
			var r := roll(s, salt + c * 10 + lane, 13, 4)
			if r == 1:
				cols[c][lane]["edges"].append(lane + 1)
			elif r == 2:
				cols[c][lane + 1]["edges"].append(lane)
		for lane in LANES:
			cols[c][lane]["edges"].sort()
	var gate := {"type": "final" if leg == LEGS - 1 else "big", "team": big_team, "edges": [],
		"local": -1, "mod": "", "detour": "", "done": false}
	if leg == LEGS - 1:
		gate["venue"] = "sunset"
		gate["time"] = CourtStyle.NIGHT
	else:
		var home := Settings.home_venue(big_team)
		gate["venue"] = home if venues.has(home) else String(venues[roll(s, salt, 17, venues.size())])
		gate["time"] = _time_of(s, salt + 99)
	return {"cols": cols, "gate": gate}


static func _time_of(s: int, k: int) -> int:
	var r := roll(s, k, 7, 10)
	return CourtStyle.DAY if r < 6 else (CourtStyle.DUSK if r < 9 else CourtStyle.NIGHT)


## A grudge match: one of the leg's ladder teams (not its big match's),
## Dale Dawson now and then on the long roads, or locals with a twist.
static func _grudge(node: Dictionary, s: int, k: int, leg: int, big_team: int) -> void:
	var teams: Array = leg_info(leg)["grudge"].filter(func(t): return int(t) != big_team)
	var r := roll(s, k, 19, 10)
	if leg > 0 and r == 0:
		node["team"] = Opponents.DAWSON
	elif r < 6 and not teams.is_empty():
		node["team"] = int(teams[roll(s, k, 23, teams.size())])
	else:
		node["local"] = roll(s, k, 9, data()["locals"].size())
	var mods: Array = data()["grudge_mods"]
	node["mod"] = String(mods[roll(s, k, 29, mods.size())])


## Every road from the leg's start to its big match, as lists of lanes.
static func roads(leg_map: Dictionary) -> Array:
	var out := []
	for lane in LANES:
		_walk(leg_map, 0, lane, [lane], out)
	return out


static func _walk(leg_map: Dictionary, col: int, lane: int, so_far: Array, out: Array) -> void:
	if col == COLS - 1:
		out.append(so_far.duplicate())
		return
	for e in leg_map["cols"][col][lane]["edges"]:
		var next := so_far.duplicate()
		next.append(int(e))
		_walk(leg_map, col + 1, int(e), next, out)


## The rules a leg keeps: at most one grudge match, shop and yard sale a
## column; no motel on the first leg (or at HEAT 5); along every road no
## two stops in a row without gear on offer, never the same kind twice in
## a row, and at least one match.
static func valid_leg(leg_map: Dictionary, leg: int, heat_level: int) -> bool:
	for col in leg_map["cols"]:
		for type in ["grudge", "shop", "yard"]:
			if col.filter(func(n): return n["type"] == type).size() > 1:
				return false
		for n in col:
			if n["type"] == "motel" and (leg == 0 or heat_level >= 5):
				return false
	for road in roads(leg_map):
		var dry := 0
		var prev := ""
		var matches := 0
		for c in road.size():
			var t := String(leg_map["cols"][c][road[c]]["type"])
			if t == prev:
				return false
			prev = t
			dry = 0 if PICKS.has(t) else dry + 1
			if dry >= 2:
				return false
			if MATCHES.has(t):
				matches += 1
		if matches == 0:
			return false
	return true


# --- Where you are -------------------------------------------------------------------

func leg() -> int:
	return int(at[0])


func col() -> int:
	return int(at[1])


func lane() -> int:
	return int(at[2])


func node_at(l: int, c: int, ln: int) -> Dictionary:
	if c == GATE:
		return map[l]["gate"]
	return map[l]["cols"][c][ln]


func here() -> Dictionary:
	if col() == START:
		return {}
	return node_at(leg(), col(), lane())


## The stops you can drive to next: [[col, lane], ...].
func reachable() -> Array:
	if state != "on":
		return []
	var c := col()
	if c == START:
		var out := []
		for ln in LANES:
			out.append([0, ln])
		return out
	if c == GATE:
		return []                    # the big match: win it to go on
	if not here()["done"]:
		return []
	if c == COLS - 1:
		return [[GATE, 0]]
	var out2 := []
	for e in here()["edges"]:
		out2.append([c + 1, int(e)])
	return out2


## Drives to a stop (one of reachable()); its node.
func go(c: int, ln: int) -> Dictionary:
	at = [leg(), c, ln]
	route.append(at.duplicate())
	stops += 1
	miles += 10 * (leg() + 1)
	return here()


## A stop that isn't a match is done once you've had it (a detour's
## choice, the shop, the motel, the yard sale's pick taken or skipped).
func finish_stop() -> void:
	if col() != START:
		here()["done"] = true


func is_match(n: Dictionary) -> bool:
	return MATCHES.has(String(n.get("type", "")))


## Where the map lets you go: the stops reachable, or (a big match lost)
## the big match again.
func targets() -> Array:
	var r := reachable()
	if r.is_empty() and state == "on" and is_gate() and not here()["done"]:
		return [[GATE, 0]]
	return r


func node_for(target: Array) -> Dictionary:
	return node_at(leg(), int(target[0]), int(target[1]))


## Shirts the locals wear (5-bit base colours; each a dark, mid and light
## ramp), and their hats ("hair": bareheaded).
const LOCAL_SHIRTS := [[24, 6, 6], [6, 14, 26], [6, 20, 10], [26, 20, 4], [18, 8, 22], [4, 20, 20],
	[26, 12, 4], [20, 20, 22]]
const LOCAL_HATS := ["cap", "visor", "headband", "bandana", "beanie", "backcap", "bucket", "hair"]


## The two locals' looks at a stop (opponents.json's member shape), the
## same every time: a shirt colour for the pair, each their own skin,
## hair, hat and body. Display only.
func local_members(n: Dictionary) -> Array:
	var k := int(n.get("local", 0)) * 131 + leg() * 7
	var base: Array = LOCAL_SHIRTS[roll(seed, k, 51, LOCAL_SHIRTS.size())]
	var shirt := [[int(base[0]) * 3 / 5, int(base[1]) * 3 / 5, int(base[2]) * 3 / 5], base,
		[mini(31, int(base[0]) + 5), mini(31, int(base[1]) + 5), mini(31, int(base[2]) + 5)]]
	var skins: Array = ["light", "tan", "deep", "pale"]
	var out := []
	for i in 2:
		var hair: Array = Career.hair_rgb5[roll(seed, k + i, 53, mini(5, Career.hair_rgb5.size()))]
		out.append({"name": String(data()["locals"][int(n.get("local", 0))]),
			"variant": "female" if roll(seed, k + i, 55, 2) == 0 else "male",
			"paddle": ["wood", "blue", "red", "gold"][roll(seed, k + i, 57, 4)],
			"hat": String(LOCAL_HATS[roll(seed, k + i, 59, LOCAL_HATS.size())]),
			"skin": String(skins[roll(seed, k + i, 61, skins.size())]),
			"hair": hair.duplicate(), "shirt": shirt.duplicate(true),
			"shorts": [[3, 3, 5], [7, 7, 9]] if i == 0 else [[20, 20, 22], [26, 26, 28]],
			"shoe": [26, 26, 26]})
	return out


## A stop's lines for the map's panel and its card: what it is, where,
## and what's at stake.
func info(n: Dictionary) -> Array:
	var type := String(n.get("type", ""))
	var out := []
	var head := stop_name(n)
	if MATCHES.has(type):
		head += "  VS " + opponent_name(n)
	out.append(head)
	if MATCHES.has(type):
		var where := String(Settings.VENUE_NAMES[maxi(0, Settings.VENUES.find(String(n["venue"])))])
		if int(n.get("time", 0)) != CourtStyle.DAY:
			where += " " + String(CourtStyle.time_names()[int(n["time"])])
		out.append("%s, FIRST TO %d" % [where, points_for(n)])
		var bits := modifiers_for(n)
		var names := []
		for row in Settings.MOD_ROWS:
			if bits & int(row[2]):
				names.append(String(row[1]))
		var prize := "PRIZE: CASH"
		if type in ["grudge", "big"]:
			prize = "PRIZE: A GEAR PICK, CASH"
		elif type == "final":
			prize = "THE SUMMER OPEN TITLE"
		out.append(("TODAY: " + ", ".join(names) + "   " if not names.is_empty() else "") + prize)
	else:
		match type:
			"yard":
				out.append("A FREE PICK FROM THE BOXES.")
			"shop":
				out.append("GEAR, A SODA FOR A HEART, A FIX FOR A HAZARD.")
			"motel":
				out.append("A HEART BACK, OR YOUR PARTNER PRACTISES.")
			"detour":
				if has_item("road_atlas"):
					out.append(String(detour(String(n["detour"]))["lines"][0]))
				else:
					out.append("WHO KNOWS WHAT'S DOWN THIS ROAD?")
	return out


## Your look in a trip's match: the active career player (or MATCH SETUP's
## 1P), wearing the trip's hat. A copy; the career isn't touched.
func driver(career: Career.Player, p1: Dictionary) -> Career.Player:
	var d: Career.Player
	if career != null:
		d = career.copy()
	else:
		d = Career.Player.new()
		d.used = 1
		d.name = "YOU     "
		d.shirt = int(p1.get("palette", 0))
		d.variant = int(p1.get("variant", K.VARIANT_MALE))
	d.hat = maxi(0, Career.hat_names.find(String(gear(hat).get("hat", "CAP"))))
	d.paddle = int(gear(paddle).get("look", Paddles.WOOD))
	return d


# --- Stats ----------------------------------------------------------------------------

## Your four stats (POWER, CONTROL, SPEED, FEET), 1 to 20: the GARAGE's
## start, your paddle and hat, and the bag's items.
func stats() -> Array:
	var s: Array = base.duplicate()
	for id in [paddle, hat] + bag:
		var g := gear(String(id))
		for i in 4:
			s[i] = int(s[i]) + int(g.get(STATS[i], 0))
	for i in 4:
		s[i] = clampi(int(s[i]), STAT_MIN, STAT_MAX)
	return s


func has_item(id: String) -> bool:
	return bag.has(id) or paddle == id or hat == id


func has_perk(p: String) -> bool:
	for id in bag:
		if String(gear(String(id)).get("perk", "")) == p:
			return true
	return false


## The perk bits a match takes (MatchConfig.perks, K.PERK_*).
func perk_bits() -> int:
	var bits := 0
	for pair in [["head_start", K.PERK_HEAD_START], ["long_arms", K.PERK_LONG_ARMS],
			["second_wind", K.PERK_SECOND_WIND], ["kitchen_pass", K.PERK_KITCHEN_PASS],
			["second_serve", K.PERK_SECOND_SERVE], ["lucky_line", K.PERK_LUCKY_LINE],
			["hot_hand", K.PERK_HOT_HAND]]:
		if has_perk(String(pair[0])):
			bits |= int(pair[1])
	return bits


# --- A stop's match -------------------------------------------------------------------

## The opponents' name, for the map and the cards.
static func opponent_name(n: Dictionary) -> String:
	if int(n.get("team", -1)) >= 0:
		return String(Opponents.team(int(n["team"]))["team"])
	if int(n.get("local", -1)) >= 0:
		return String(data()["locals"][int(n["local"])])
	return "LOCALS"


static func stop_name(n: Dictionary) -> String:
	match String(n.get("type", "")):
		"pickup":
			return "PICKUP GAME"
		"grudge":
			return "GRUDGE MATCH"
		"big":
			return "BIG MATCH"
		"final":
			return "THE SUMMER OPEN"
		"yard":
			return "YARD SALE"
		"shop":
			return "PRO SHOP"
		"motel":
			return "MOTEL"
		"detour":
			return "DETOUR"
	return ""


## A match's points: pickup games are short, the final long.
func points_for(n: Dictionary) -> int:
	match String(n["type"]):
		"pickup":
			return 3
		"final":
			return 7
		"big":
			return 7 if heat >= 4 else 5
	return 5


func difficulty_for(n: Dictionary) -> int:
	if String(n["type"]) == "final":
		return K.DIFFICULTY_HARD
	# leg 1's pickups are EASY; its grudge and big matches MEDIUM (port ADR-091)
	return K.DIFFICULTY_EASY if leg() == 0 and String(n["type"]) == "pickup" else K.DIFFICULTY_MEDIUM


## The modifiers a match is played with: the stop's twist (lifted by an
## UMBRELLA), the hazards waiting, SPECIALS with a PICKLE JAR.
func modifiers_for(n: Dictionary, spend := false) -> int:
	var bits := mod_bits(String(n.get("mod", "")))
	if bits and has_item("umbrella") and not used.has("umbrella"):
		bits = 0
		if spend:
			used.append("umbrella")
	for h in hazards:
		bits |= mod_bits(String(hazard(String(h)).get("mod", "")))
	if has_item("pickle_jar") or has_perk("hot_hand"):
		bits |= K.MOD_SPECIALS
	return bits


## The partner's play: their own style (Pepper's, or the captain's), with
## the partner gear's changes.
func partner_style() -> SimTypes.AiStyle:
	var s: SimTypes.AiStyle
	if partner >= 0 and Opponents.exists(partner):
		s = Opponents.team(partner)["players"][0]["style_obj"].copy()
	else:
		s = Opponents.partner_style()
	if s.late_period > 0:
		s.late_period = maxi(s.late_period, partner_late(int(partner_stats[1])))
	for id in bag:
		var g := gear(String(id))
		if g.has("style"):
			for k in g["style"]:
				s.set(String(k), int(g["style"][k]))
		if g.has("style_add"):
			for k in g["style_add"]:
				var v := int(s.get(String(k))) + int(g["style_add"][k])
				if String(k) == "speed":
					v = mini(v, K.PLAYER_MAX_SPEED_FP)
				s.set(String(k), v)
	return s


## CPU ERRORS for this leg's matches: fewer from HEAT 1, fewer in leg 1.
func errors_for() -> int:
	var errors := 75 if heat >= 1 else 100
	return errors * LEG_1_ERRORS / 100 if leg() == 0 else errors


## How many balls apart the partner's late swings are, at `control`.
static func partner_late(control: int) -> int:
	return PARTNER_LATE + PARTNER_LATE_STEP * maxi(0, control - PARTNER_STAT)


## The match at stop `n`: doubles, you and your partner, your trip stats,
## the stop's opponents, venue and twist. `p1`: your look (a Player Select
## choice). Records nothing (MatchView.trip).
func config_for(n: Dictionary, p1: Dictionary, spend := false,
		career: Career.Player = null) -> SimTypes.MatchConfig:
	var team := int(n.get("team", -1))
	var cfg := Settings.config_for(true, team, difficulty_for(n), points_for(n), p1)
	cfg.ball_speed = 100
	cfg.cpu_errors = errors_for()
	cfg.set_partner(partner if partner >= 0 else Opponents.PEPPER)
	cfg.modifiers = modifiers_for(n, spend)
	cfg.paddle[0] = int(gear(paddle).get("look", Paddles.WOOD))
	cfg.set_career(driver(career, p1))
	cfg.trip = 1
	cfg.trip_stats = [stats(), partner_stats.duplicate(), [], []]
	cfg.styles = [null, partner_style(), null, null]
	cfg.perks = perk_bits()
	return cfg


## A match's result. A win pays cash (and a gear pick after a grudge or
## big match), and beating a ladder team unlocks its captain; a loss costs
## a heart (a RAIN CHECK takes the first), and a lost big match is played
## again. The hazards are spent either way.
func record_match(won: bool) -> void:
	var n := here()
	if n.is_empty():
		return
	hazards.clear()
	if won:
		wins += 1
		miles += 5
		var pay := 12 + 4 * leg()
		match String(n["type"]):
			"grudge":
				pay = 20 + 5 * leg()
			"big":
				pay = 30
			"final":
				pay = 0
		if has_item("piggy_bank"):
			pay += pay / 2
		cash += pay
		var team := int(n.get("team", -1))
		if team >= 0 and not beaten.has(team):
			beaten.append(team)
		n["done"] = true
		if String(n["type"]) == "grudge":
			offer_pick("grudge", 1)
		elif String(n["type"]) == "big":
			offer_pick("big", 1)
		if String(n["type"]) == "final":
			state = "won"
		elif col() == GATE:
			at = [leg() + 1, START, 1]
		return
	losses += 1
	if has_item("rain_check") and not used.has("rain_check"):
		used.append("rain_check")
	else:
		hearts -= 1
	if hearts <= 0:
		state = "over"
		return
	if not is_gate():
		n["done"] = true            # a lost stop: no prize, drive on


func is_gate() -> bool:
	return col() == GATE


# --- Gear picks ---------------------------------------------------------------------

## The pool of gear a trip draws from: the starting pool and what the
## GARAGE has added.
static func pool(meta_dict: Dictionary) -> Array:
	var out: Array = data()["start_pool"].duplicate()
	for id in garage(meta_dict)["pool"]:
		if not out.has(id):
			out.append(id)
	return out


## Whether picking `id` would change anything: a non-stacking item you
## have, or the paddle or hat you hold, wouldn't.
func can_take(id: String) -> bool:
	var g := gear(id)
	if g.is_empty() or String(g["rarity"]) == "start":
		return false
	if g.get("stacks", false):
		return true
	return not has_item(id)


## Draws `count` different items for a pick (`source`: "grudge" leans
## rare, "rare" offers only rares if there are any). The same stop and
## source always draw the same cards.
func draw(source: String, count: int, salt: int, meta_dict: Dictionary) -> Array:
	var table := RARITY_WEIGHTS.duplicate()
	if source in ["grudge", "big"]:
		table = {"common": 35, "uncommon": 45, "rare": 20}
	elif source in ["uncommon", "rare"]:
		table = {source: 1}
	var candidates: Array = pool(meta_dict).filter(func(id): return can_take(String(id)))
	var out := []
	for i in count * 8:
		if out.size() >= count or candidates.is_empty():
			break
		var rarity := pick_weighted(table, seed, salt + i * 7, 31)
		var of_rarity: Array = candidates.filter(func(id): return String(gear(String(id))["rarity"]) == rarity)
		if of_rarity.is_empty():
			continue
		var id := String(of_rarity[roll(seed, salt + i * 7, 37, of_rarity.size())])
		out.append(id)
		candidates.erase(id)
	while out.size() < count and not candidates.is_empty():
		var id2 := String(candidates[roll(seed, salt + out.size(), 41, candidates.size())])
		out.append(id2)
		candidates.erase(id2)
	return out


func _stop_salt() -> int:
	return leg() * 10000 + (col() + 1) * 100 + lane() * 10 + stops


## Puts a pick on offer (it waits in `pending` until taken or skipped).
var _meta_for_draw: Dictionary = {}

func offer_pick(source: String, extra_salt: int) -> void:
	var count := 3 + (1 if has_item("lucky_penny") else 0)
	pending = {"kind": "pick", "source": source,
		"items": draw(source, count, _stop_salt() * 3 + extra_salt, _meta_for_draw)}


func take(id: String) -> void:
	var g := gear(id)
	match String(g.get("kind", "")):
		"paddle":
			paddle = id
		"hat":
			hat = id
		_:
			bag.append(id)
			_apply_hearts(id)
	pending = {}


func skip_pick() -> void:
	cash += SKIP_CASH
	pending = {}


func _apply_hearts(id: String) -> void:
	var h := int(gear(id).get("hearts", 0))
	if h > 0:
		max_hearts = mini(HEARTS_MAX, max_hearts + h)
		hearts = mini(max_hearts, hearts + h)


# --- The PRO SHOP, the MOTEL, the YARD SALE, DETOURS ---------------------------------

func price(id: String) -> int:
	var p := int(PRICES.get(String(gear(id).get("rarity", "common")), 30))
	if has_item("coupon_book"):
		p -= p / 4
	return p


## The PRO SHOP's stock at this stop: four items (always the same ones).
func shop_stock(meta_dict: Dictionary) -> Array:
	return draw("shop", 4, _stop_salt() * 5, meta_dict)


func buy(id: String) -> bool:
	var p := price(id)
	if cash < p or not can_take(id):
		return false
	cash -= p
	take(id)
	return true


func buy_soda() -> bool:
	if cash < SODA or hearts >= max_hearts:
		return false
	cash -= SODA
	hearts += 1
	return true


func buy_fix() -> bool:
	if cash < FIX or hazards.is_empty():
		return false
	cash -= FIX
	hazards.clear()
	return true


## The MOTEL: a heart back, or your partner practises (+1 to each of
## their stats).
func rest(heal: bool) -> void:
	if heal:
		hearts = mini(max_hearts, hearts + 1)
	else:
		for i in 4:
			partner_stats[i] = mini(STAT_MAX, int(partner_stats[i]) + 1)


## A detour's choices as a scene shows them: each with whether you can
## afford it, and DRIVE ON after them when you can afford none.
func detour_choices(d: Dictionary) -> Array:
	var out := []
	var any := false
	for ch in d["choices"]:
		var need := int(ch.get("needs_cash", 0))
		out.append({"label": String(ch["label"]), "enabled": cash >= need,
			"value": "" if cash >= need else "NEED %d" % need})
		any = any or cash >= need
	if not any:
		out.append({"label": "DRIVE ON", "enabled": true})
	return out


## A detour's choice: its effects (cash, a heart, a hazard, a gear pick,
## a double-or-nothing bet decided by the seed). False if you can't
## afford it.
func choose(d: Dictionary, choice: int) -> bool:
	if choice < 0 or choice >= d["choices"].size():
		return true                  # DRIVE ON: nothing happens
	var ch: Dictionary = d["choices"][choice]
	if cash < int(ch.get("needs_cash", 0)):
		return false
	var e: Dictionary = ch["do"]
	cash = maxi(0, cash + int(e.get("cash", 0)))
	if e.has("heart"):
		hearts = mini(max_hearts, hearts + int(e["heart"]))
	if e.has("hazard"):
		hazards.append(String(e["hazard"]))
	if e.has("gamble"):
		var bet := int(e["gamble"])
		cash += bet if roll(seed, _stop_salt(), 43, 2) == 0 else -bet
		cash = maxi(0, cash)
	if e.has("pick"):
		offer_pick(String(e["pick"]), 2)
	return true


# --- The save -------------------------------------------------------------------------

const KEYS := ["seed", "gen", "heat", "partner", "map", "at", "hearts", "max_hearts", "cash",
	"base", "partner_stats", "paddle", "hat", "bag", "hazards", "used", "pending", "beaten",
	"route", "stops", "wins", "losses", "miles", "state"]


func to_dict() -> Dictionary:
	var d := {}
	for k in KEYS:
		var v = get(k)
		d[k] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return d


static func from_dict(d: Dictionary) -> RoadTrip:
	var t := RoadTrip.new()
	for k in KEYS:
		if d.has(k):
			var v = d[k]
			t.set(k, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return t


## What lasts between trips (save.data["trip"]), filled in if missing.
static func meta(save: SaveGame) -> Dictionary:
	var def := {"miles": 0, "trips": 0, "won": 0, "best_heat": -1, "best_leg": 0, "heat": 0,
		"partners": [], "seen": 0, "looks": {"van": 0, "ornament": 0}, "last_item": "", "now": {}}
	if save == null:
		return def
	if not save.data.has("trip") or typeof(save.data["trip"]) != TYPE_DICTIONARY:
		save.data["trip"] = def
	var m: Dictionary = save.data["trip"]
	for k in def:
		if not m.has(k):
			m[k] = def[k]
	return m


## The title's ROAD TRIP value: the leg of a trip in progress, or the
## trips won.
static func title_label(save: SaveGame) -> String:
	if save == null:
		return ""
	var t := current(save)
	if t != null:
		return "LEG %d/%d" % [t.leg() + 1, LEGS]
	var won := int(meta(save)["won"])
	return "WON %d" % won if won > 0 else ""


## The trip in progress in the save, or null.
static func current(save: SaveGame) -> RoadTrip:
	var m := meta(save)
	var now: Dictionary = m["now"]
	if now.is_empty():
		return null
	var t := from_dict(now)
	t._meta_for_draw = m
	return t


func store(save: SaveGame) -> void:
	var m := meta(save)
	m["now"] = to_dict() if state == "on" else {}
	_meta_for_draw = m


## A new trip, stored (it replaces any in progress).
static func begin(save: SaveGame, trip_seed: int, heat_level: int, who: int) -> RoadTrip:
	var m := meta(save)
	var t := create(trip_seed, heat_level, who, m)
	t._meta_for_draw = m
	m["trips"] = int(m["trips"]) + 1
	t.store(save)
	return t


## The trip's end (won or over): its miles go to the GARAGE's ladder, the
## captains beaten become partners, the records update; nothing else in
## the game changes. Returns the ladder steps this reached.
func finish(save: SaveGame) -> Array:
	var m := meta(save)
	var before := steps_reached(m)
	m["miles"] = int(m["miles"]) + miles
	m["best_leg"] = maxi(int(m["best_leg"]), leg() + (1 if state == "won" else 0))
	var partners: Array = m["partners"]
	for team in beaten:
		if team != Opponents.DAWSON and team != 7 and not partners.has(team):
			partners.append(team)
	if state == "won":
		m["won"] = int(m["won"]) + 1
		m["best_heat"] = maxi(int(m["best_heat"]), heat)
		if heat >= int(m["heat"]):
			m["heat"] = mini(HEAT_MAX, heat + 1)
		if not partners.has(7):
			partners.append(7)               # the Champs' captain, only from a trip won
	for id in bag:
		if String(gear(String(id)).get("rarity", "")) == "common":
			m["last_item"] = String(id)
			break
	m["now"] = {}
	var after := steps_reached(m)
	var out := []
	for i in range(before, after):
		out.append(i)
	return out


# --- The GARAGE's ladder ------------------------------------------------------------

## Steps of the ladder the miles have reached (each step costs its miles,
## on top of the ones before).
static func steps_reached(meta_dict: Dictionary) -> int:
	var left := int(meta_dict.get("miles", 0))
	var n := 0
	for step in data()["ladder"]:
		left -= int(step["miles"])
		if left < 0:
			break
		n += 1
	return n


## Miles still to go to the next step (0 at the top).
static func miles_to_next(meta_dict: Dictionary) -> int:
	var left := int(meta_dict.get("miles", 0))
	for step in data()["ladder"]:
		left -= int(step["miles"])
		if left < 0:
			return -left
	return 0


## What the ladder's reached steps give every new trip.
static func garage(meta_dict: Dictionary) -> Dictionary:
	var out := {"stats": [0, 0, 0, 0], "hearts": 0, "cash": 0, "paddle": "", "item": "",
		"pool": [], "vans": [0], "ornaments": [0]}
	var ladder: Array = data()["ladder"]
	for i in steps_reached(meta_dict):
		var step: Dictionary = ladder[i]
		for k in 4:
			out["stats"][k] += int(step.get(STATS[k], 0))
		out["hearts"] += int(step.get("heart", 0))
		out["cash"] += int(step.get("cash", 0))
		if step.has("start_paddle"):
			out["paddle"] = String(step["start_paddle"])
		if step.has("start_item"):
			out["item"] = String(meta_dict.get("last_item", ""))
		for id in step.get("pool", []):
			out["pool"].append(String(id))
		if step.has("van"):
			out["vans"].append(int(step["van"]))
		if step.has("ornament"):
			out["ornaments"].append(int(step["ornament"]))
	return out


## A ladder step's reward as a line ("+1 FEET TO START").
static func step_label(i: int) -> String:
	var step: Dictionary = data()["ladder"][i]
	var parts := []
	var all4 := true
	for k in 4:
		if int(step.get(STATS[k], 0)) == 0:
			all4 = false
	if all4:
		parts.append("+%d TO EVERY STAT" % int(step["power"]))
	else:
		for k in 4:
			if int(step.get(STATS[k], 0)) != 0:
				parts.append("+%d %s" % [int(step[STATS[k]]), STAT_NAMES[k]])
	if step.has("heart"):
		parts.append("A FOURTH HEART")
	if step.has("cash"):
		parts.append("START WITH %d CASH" % int(step["cash"]))
	if step.has("start_paddle"):
		parts.append("START WITH A " + String(gear(String(step["start_paddle"]))["name"]))
	if step.has("start_item"):
		parts.append("START WITH LAST TRIP'S ITEM")
	if step.has("pool"):
		parts.append("%d NEW ITEMS ON THE ROAD" % step["pool"].size())
	if step.has("van"):
		parts.append("VAN PAINT: " + String(data()["vans"][int(step["van"])]))
	if step.has("ornament"):
		parts.append("ORNAMENT: " + String(data()["ornaments"][int(step["ornament"])]))
	return ", ".join(parts)
