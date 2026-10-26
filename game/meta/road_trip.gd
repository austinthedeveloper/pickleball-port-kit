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
const GEN := 3                   ## the generator's version: 2 adds the diner, the rival and story stops; 3 never keeps a leg that breaks the rules
const DRAWS_MAX := 20000         ## draws of a leg, at most (a valid one comes long before)
const RIVAL_LEG := 1             ## the ROAD HOGS turn up on the long drive (port ADR-092)
const ISLANDS := 3               ## the secret fourth leg's index, past the SUMMER OPEN (port ADR-093)
## A partner's bond (port ADR-093): points a trip together earns, and the
## points each level needs: 1, +1 to their stats; 2, their own item; 3, +2.
const BOND_LEVELS := [4, 12, 24]
const BOND_TITLE := 3            ## bond points for a SUMMER OPEN won together
## Postcards it takes for each map pen after the red one (the gold is the
## islands' ending's).
const PEN_POSTCARDS := [8, 16, 24]

## Stop types. The ones that give gear (or a chance to buy it): no road
## has two stops without one in a row.
const MATCHES := ["pickup", "grudge", "rival", "big", "final", "encore"]
const PICKS := ["grudge", "rival", "yard", "shop", "detour"]
const WEIGHTS := {"pickup": 40, "grudge": 14, "yard": 12, "shop": 12, "motel": 10, "detour": 16, "diner": 8}
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
var locker: Array = []           ## paddles and hats put away in the van (port ADR-092)
var boost: Array = [0, 0, 0, 0]  ## stats won on the road for the rest of the trip (detours)
var meal := ""                   ## the diner's dish: stats for the next match only
var rival_won := false           ## the ROAD HOGS beaten on this trip
var daily := 0                   ## TRIP OF THE DAY: its date (YYYYMMDD), 0 for any other trip
var title := false               ## the SUMMER OPEN won, with the islands still to go
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
var garage_since := -1           ## the GARAGE's steps before this trip began (not saved; -1 unknown)


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


static func dish(id: String) -> Dictionary:
	for d in data()["diner"]:
		if String(d["id"]) == id:
			return d
	return {}


static func beat(id: String) -> Dictionary:
	for b in data()["beats"]:
		if String(b["id"]) == id:
			return b
	return {}


static func leg_info(leg: int) -> Dictionary:
	return data()["legs"][clampi(leg, 0, data()["legs"].size() - 1)]


## Legs on this trip's map: three, four with the islands.
func legs() -> int:
	return map.size()


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
	t.gen = GEN
	t.map = generate(t.seed, t.heat, story_extras(meta_dict, who))
	var g := garage(meta_dict)
	var bond := bond_level(meta_dict, who)
	for i in 4:
		t.partner_stats[i] = PARTNER_STAT + (1 if bond >= 1 else 0) + (1 if bond >= 3 else 0)
	if bond >= 2:
		t.bag.append(bond_item(who))
		t._apply_hearts(bond_item(who))
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
## draws the same map. `extras` (story_extras) puts the story's stops on
## it: the ROAD HOGS, a story detour, the stranger.
static func generate(s: int, heat_level: int, extras: Dictionary = {}) -> Array:
	var out := []
	var used_detours := []
	for leg in LEGS + (1 if extras.get("islands", false) else 0):
		var info := leg_info(leg)
		var bigs: Array = info["big"]
		var big_team := int(bigs[roll(s, leg, 1, bigs.size())])
		var leg_map := {}
		# draws until one keeps the rules (1 leg in 7,000 needs more than 400;
		# generator 2 kept the 400th, rules or not)
		for attempt in DRAWS_MAX:
			leg_map = _draw_leg(s, leg, attempt, big_team, heat_level, used_detours)
			_place_story(leg_map, s, leg, attempt, extras)
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
				var ds: Array = data()["detours"].filter(func(d): return not used_detours.has(d["id"]) \
					and not d.has("beat"))
				if ds.is_empty():
					ds = data()["detours"].filter(func(d): return not d.has("beat"))
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
	var gate := {"type": "final" if leg == LEGS - 1 else ("encore" if leg == ISLANDS else "big"),
		"team": big_team, "edges": [], "local": -1, "mod": "", "detour": "", "done": false}
	if leg == LEGS - 1:
		gate["venue"] = "sunset"
		gate["time"] = CourtStyle.NIGHT
	elif leg == ISLANDS:
		gate["venue"] = String(info.get("encore_venue", "pirate"))
		gate["time"] = CourtStyle.NIGHT
	else:
		var home := Settings.home_venue(big_team)
		gate["venue"] = home if venues.has(home) else String(venues[roll(s, salt, 17, venues.size())])
		gate["time"] = _time_of(s, salt + 99)
	return {"cols": cols, "gate": gate}


## The story's stops on a leg: the ROAD HOGS on the long drive's middle
## column (port ADR-092), a story detour on its first, the stranger on the
## coast. Each takes a lane the seed picks.
static func _place_story(leg_map: Dictionary, s: int, leg: int, attempt: int, extras: Dictionary) -> void:
	var salt := leg * 1000 + attempt * 37
	if leg == RIVAL_LEG and extras.get("rival", false):
		var n: Dictionary = leg_map["cols"][1][roll(s, salt, 61, LANES)]
		n["type"] = "rival"
		n["team"] = -1
		n["local"] = -1
		n["detour"] = ""
		n["mod"] = ""
		n["level"] = int(extras.get("hogs", 0))
	var story: Array = extras.get("detours", [])
	if leg == 1 and not story.is_empty():
		var d: Dictionary = leg_map["cols"][0][roll(s, salt, 63, LANES)]
		d["type"] = "detour"
		d["team"] = -1
		d["local"] = -1
		d["mod"] = ""
		d["detour"] = String(story[0])
	if leg == 2 and extras.get("dawson", false):
		var g: Dictionary = leg_map["cols"][1][roll(s, salt, 65, LANES)]
		g["type"] = "grudge"
		g["team"] = Opponents.DAWSON
		g["local"] = -1
		g["detour"] = ""
		if String(g["mod"]) == "":
			g["mod"] = String(data()["grudge_mods"][roll(s, salt, 67, data()["grudge_mods"].size())])


## What the story puts on a new trip's map, from what lasts between trips:
## the ROAD HOGS from the second trip on, a story detour whose beat is
## due, and the stranger once the old court has been found.
static func story_extras(meta_dict: Dictionary, who: int) -> Dictionary:
	if meta_dict.is_empty():
		return {}
	var ctx := {"heat": 0, "partner": who, "trip": int(meta_dict.get("trips", 0)) + 1}
	var out := {"rival": int(ctx["trip"]) >= 2, "hogs": int(meta_dict.get("hogs", 0)), "detours": []}
	for d in data()["detours"]:
		if d.has("beat") and beat_due(meta_dict, beat(String(d["beat"])), ctx):
			out["detours"].append(String(d["id"]))
	ctx["team"] = Opponents.DAWSON
	out["dawson"] = beat_due(meta_dict, beat("van_4"), ctx)
	out["islands"] = islands_open(meta_dict)
	return out


## The islands are open once an arc of the story is finished (THE VAN,
## THE ROAD HOGS or THE CHAMPS) or a trip is won at HEAT 5.
static func islands_open(meta_dict: Dictionary) -> bool:
	var seen: Array = meta_dict.get("beats", [])
	return seen.has("van_6") or seen.has("hogs_6") or seen.has("champs_4") \
		or int(meta_dict.get("best_heat", -1)) >= HEAT_MAX



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
	var rivals := 0
	for col in leg_map["cols"]:
		rivals += col.filter(func(n): return n["type"] == "rival").size()
	if rivals > 1:
		return false
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
	cash += _sum("tip")
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


## The stops this leg's roads still reach from `target` ([col, lane]),
## itself included, as [col, lane] pairs: the map's preview of where a
## choice leads (port ADR-098). Empty for the big match.
func ahead(target: Array) -> Array:
	var col := int(target[0])
	if col < 0 or col >= COLS:
		return []
	var out := [[col, int(target[1])]]
	var lanes := [int(target[1])]
	for c in range(col, COLS - 1):
		var next := []
		for lane in lanes:
			for e in node_at(leg(), c, int(lane))["edges"]:
				if not next.has(int(e)):
					next.append(int(e))
		next.sort()
		for lane in next:
			out.append([c + 1, int(lane)])
		lanes = next
	return out


## Shirts the locals wear (5-bit base colours; each a dark, mid and light
## ramp), and their hats ("hair": bareheaded).
const LOCAL_SHIRTS := [[24, 6, 6], [6, 14, 26], [6, 20, 10], [26, 20, 4], [18, 8, 22], [4, 20, 20],
	[26, 12, 4], [20, 20, 22]]
const LOCAL_HATS := ["cap", "visor", "headband", "bandana", "beanie", "backcap", "bucket", "hair"]


## The two locals' looks at a stop (opponents.json's member shape), the
## same every time: a shirt colour for the pair, each their own skin,
## hair, hat and body. Display only.
func local_members(n: Dictionary) -> Array:
	if String(n.get("type", "")) == "rival":
		return rival_members()
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
		var at_line := "%s, FIRST TO %d" % [where, points_for(n)]
		var bits := modifiers_for(n)
		var names := []
		for row in Settings.MOD_ROWS:
			if bits & int(row[2]):
				names.append(String(row[1]))
		var prize := "PRIZE: CASH"
		if type in ["grudge", "big", "rival"]:
			prize = "PRIZE: A GEAR PICK, CASH"
		elif type == "final":
			prize = "THE SUMMER OPEN TITLE"
		elif type == "encore":
			prize = "THE ISLAND ENCORE"
		# the prize beside the venue, so the day's modifiers have a line
		out.append(at_line + "   " + prize)
		if not names.is_empty():
			out.append("TODAY: " + ", ".join(names))
	else:
		match type:
			"yard":
				out.append("A FREE PICK FROM THE BOXES.")
			"shop":
				out.append("GEAR, A SODA FOR A HEART, A FIX FOR A HAZARD.")
			"motel":
				out.append("A HEART BACK, OR YOUR PARTNER PRACTISES.")
			"diner":
				out.append("A HOT MEAL: STATS FOR THE NEXT MATCH.")
			"detour":
				if _sum("atlas") > 0:
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
## start and what the road gave (boost), your paddle and hat, the bag's
## items, the sets you've made, and in a match (`for_match`) the diner's
## dish.
func stats(for_match := false) -> Array:
	var parts := stat_parts()
	var s := []
	for i in 4:
		var v := 0
		for k in ["base", "gear", "sets"]:
			v += int(parts[k][i])
		if for_match:
			v += int(parts["meal"][i])
		s.append(clampi(v, STAT_MIN, STAT_MAX))
	return s


## Where each stat comes from (THE VAN's bars): "base" (the GARAGE and the
## road), "gear", "sets" and "meal", four ints each.
func stat_parts() -> Dictionary:
	var out := {"base": [], "gear": [0, 0, 0, 0], "sets": [0, 0, 0, 0], "meal": [0, 0, 0, 0]}
	for i in 4:
		out["base"].append(int(base[i]) + int(boost[i]))
	for id in [paddle, hat] + bag:
		var g := gear(String(id))
		for i in 4:
			out["gear"][i] += int(g.get(STATS[i], 0))
	for st in active_sets():
		for i in 4:
			out["sets"][i] += int(st.get(STATS[i], 0))
	var d := dish(meal)
	for i in 4:
		out["meal"][i] = int(d.get(STATS[i], 0))
	return out


## The sets you've made: every item of a set held (the paddle and hat in
## hand, not in the locker; the bag's).
func active_sets() -> Array:
	return data()["sets"].filter(func(st): return st["items"].all(func(id): return has_item(String(id))))


## The sets an item belongs to.
static func sets_of(id: String) -> Array:
	return data()["sets"].filter(func(st): return st["items"].has(id))


## A set's bonus (or a dish's) as a line: "+2 POWER, +1 FEET".
static func bonus_label(st: Dictionary) -> String:
	var v := int(st.get("power", 0))
	if v != 0 and STATS.all(func(k): return int(st.get(k, 0)) == v):
		return "%+d EVERY STAT" % v
	var parts := []
	for k in 4:
		if int(st.get(STATS[k], 0)) != 0:
			parts.append("%+d %s" % [int(st[STATS[k]]), STAT_NAMES[k]])
	return ", ".join(parts)


## The sum of a number the bag's items carry (tip, gas, lucky...).
func _sum(key: String) -> int:
	var n := 0
	for id in bag:
		n += int(gear(String(id)).get(key, 0))
	return n


## Your partner's stats: their own (the MOTEL's practice) and partner gear.
func partner_now() -> Array:
	var add := _sum("partner_all")
	var out := []
	for i in 4:
		out.append(clampi(int(partner_stats[i]) + add, STAT_MIN, STAT_MAX))
	return out


## Whether the trip ends a winner: the SUMMER OPEN won (on the islands or
## not).
func won_title() -> bool:
	return title or state == "won"


## Whether the island encore was won (the islands' gate done).
func encore_won() -> bool:
	return legs() > LEGS and bool(map[ISLANDS]["gate"]["done"])


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
	if String(n.get("type", "")) == "rival":
		return String(data()["rival"]["name"])
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
		"rival":
			return "RIVALS!"
		"big":
			return "BIG MATCH"
		"final":
			return "THE SUMMER OPEN"
		"encore":
			return "THE ENCORE"
		"yard":
			return "YARD SALE"
		"shop":
			return "PRO SHOP"
		"motel":
			return "MOTEL"
		"detour":
			return "DETOUR"
		"diner":
			return "DINER"
	return ""


## A match's points: pickup games are short, the final long.
func points_for(n: Dictionary) -> int:
	match String(n["type"]):
		"pickup":
			return 3
		"final", "encore":
			return 7
		"big":
			return 7 if heat >= 4 else 5
	return 5


func difficulty_for(n: Dictionary) -> int:
	if String(n["type"]) in ["final", "encore"]:
		return K.DIFFICULTY_HARD
	if String(n["type"]) == "rival":
		# the ROAD HOGS get serious after two losses to you, friendly after five
		var lv := int(n.get("level", 0))
		return K.DIFFICULTY_HARD if lv >= 2 and lv < 5 else K.DIFFICULTY_MEDIUM
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
		s.late_period = maxi(s.late_period, partner_late(int(partner_now()[1])))
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
	cfg.trip_stats = [stats(true), partner_now(), [], []]

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
	meal = ""
	if won:
		wins += 1
		miles += 5 + _sum("win_miles")
		var pay := 12 + 4 * leg()
		match String(n["type"]):
			"grudge", "rival":
				pay = 20 + 5 * leg()
			"big":
				pay = 30
			"final", "encore":
				pay = 0
		if has_item("piggy_bank"):
			pay += pay / 2
		cash += pay
		var team := int(n.get("team", -1))
		if team >= 0 and not beaten.has(team):
			beaten.append(team)
		if String(n["type"]) == "rival":
			rival_won = true
		n["done"] = true
		if String(n["type"]) in ["grudge", "rival"]:
			offer_pick("grudge", 1)
		elif String(n["type"]) == "big":
			offer_pick("big", 1)
			heal(_sum("big_heal"))
		if String(n["type"]) == "final" and legs() > LEGS:
			title = true                 # the SUMMER OPEN won; the islands next
			at = [ISLANDS, START, 1]
			heal(_sum("leg_heal"))
			cash += _sum("leg_cash")
		elif String(n["type"]) in ["final", "encore"]:
			state = "won"
		elif col() == GATE:
			at = [leg() + 1, START, 1]
			heal(_sum("leg_heal"))
			cash += _sum("leg_cash")
		return
	losses += 1
	if has_item("rain_check") and not used.has("rain_check"):
		used.append("rain_check")
	else:
		hearts -= 1
	if hearts <= 0:
		state = "won" if title else "over"   # lost on the islands, but the title's yours
		return
	if not is_gate():
		n["done"] = true            # a lost stop: no prize, drive on


func is_gate() -> bool:
	return col() == GATE


func heal(n: int) -> void:
	hearts = mini(max_hearts, hearts + maxi(0, n))


# --- Gear picks ---------------------------------------------------------------------

## The pool of gear a trip draws from: the starting pool and what the
## GARAGE has added.
static func pool(meta_dict: Dictionary) -> Array:
	var out: Array = data()["start_pool"].duplicate()
	for id in garage(meta_dict)["pool"] + meta_dict.get("story_pool", []):
		if not out.has(id):
			out.append(id)
	return out


## Whether picking `id` would change anything: a non-stacking item you
## have, or the paddle or hat you hold, wouldn't.
func can_take(id: String) -> bool:
	var g := gear(id)
	if g.is_empty() or String(g["rarity"]) in ["start", "bond"]:
		return false
	if g.get("stacks", false):
		return true
	return not has_item(id) and not locker.has(id)


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
	# a set you've started: one card in two is a piece it's missing (port ADR-093)
	var pieces := set_pieces(meta_dict).filter(func(id): return not out.has(id))
	if not out.is_empty() and not pieces.is_empty() and roll(seed, salt, 71, 2) == 0:
		out[out.size() - 1] = String(pieces[roll(seed, salt, 73, pieces.size())])
	return out


## The pieces missing from the sets you've started (one item held, in hand,
## in the bag or the locker), that can turn up on the road.
func set_pieces(meta_dict: Dictionary) -> Array:
	var in_pool := pool(meta_dict)
	var out := []
	for st in data()["sets"]:
		if not st["items"].any(func(id): return has_item(String(id)) or locker.has(String(id))):
			continue
		for id in st["items"]:
			if in_pool.has(id) and can_take(String(id)) and not out.has(id):
				out.append(String(id))
	return out



func _stop_salt() -> int:
	return leg() * 10000 + (col() + 1) * 100 + lane() * 10 + stops


## Puts a pick on offer (it waits in `pending` until taken or skipped).
var _meta_for_draw: Dictionary = {}

func offer_pick(source: String, extra_salt: int) -> void:
	var count := 3 + (1 if has_item("lucky_penny") else 0)
	pending = {"kind": "pick", "source": source,
		"items": draw(source, count, _stop_salt() * 3 + extra_salt, _meta_for_draw)}


## Takes an item: a paddle or hat goes in your hand and the one you held
## into the locker (port ADR-092), the rest into the bag.
func take(id: String) -> void:
	var g := gear(id)
	match String(g.get("kind", "")):
		"paddle":
			locker.append(paddle)
			paddle = id
		"hat":
			locker.append(hat)
			hat = id
		_:
			bag.append(id)
			_apply_hearts(id)
	pending = {}


## The paddles (or hats) you can switch between: the one in hand first,
## then the locker's.
func choices_of(kind: String) -> Array:
	var out := [paddle if kind == "paddle" else hat]
	for id in locker:
		if String(gear(String(id)).get("kind", "")) == kind:
			out.append(String(id))
	return out


## Swaps the paddle or hat in hand for one from the locker.
func equip(id: String) -> bool:
	var kind := String(gear(id).get("kind", ""))
	if not locker.has(id) or not kind in ["paddle", "hat"]:
		return false
	locker.erase(id)
	if kind == "paddle":
		locker.append(paddle)
		paddle = id
	else:
		locker.append(hat)
		hat = id
	return true


## What the PRO SHOP pays for an item: half its price. The PLAIN ones are
## worth nothing to anyone.
func sell_price(id: String) -> int:
	var g := gear(id)
	if g.is_empty() or String(g["rarity"]) in ["start", "bond"]:
		return 0
	return int(PRICES.get(String(g["rarity"]), 30)) / 2


## The items the PRO SHOP takes: the locker's, then the bag's (one of each).
func sellable() -> Array:
	var out := []
	for id in locker + bag:
		if sell_price(String(id)) > 0 and not out.has(id):
			out.append(String(id))
	return out


func sell(id: String) -> bool:
	if not sellable().has(id):
		return false
	if locker.has(id):
		locker.erase(id)
	else:
		bag.erase(id)
		var h := int(gear(id).get("hearts", 0))
		if h > 0:
			max_hearts = maxi(1, max_hearts - h)
			hearts = clampi(hearts, 1, max_hearts)
	cash += sell_price(id)
	return true


## A CB RADIO's redraw: once a leg, the pick on offer drawn again.
func can_redraw() -> bool:
	return _sum("redraw") > 0 and not used.has("redraw_%d" % leg()) \
		and String(pending.get("kind", "")) == "pick"


func redraw() -> bool:
	if not can_redraw():
		return false
	used.append("redraw_%d" % leg())
	var count: int = pending["items"].size()
	pending["items"] = draw(String(pending.get("source", "")), count, _stop_salt() * 3 + 911, _meta_for_draw)
	return true


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


func soda_price() -> int:
	return SODA / 2 if _sum("loyalty") > 0 else SODA


## The PRO SHOP's stock at this stop: four items (five with a LOYALTY
## CARD), always the same ones.
func shop_stock(meta_dict: Dictionary) -> Array:
	return draw("shop", 4 + mini(1, _sum("loyalty")), _stop_salt() * 5, meta_dict)


func buy(id: String) -> bool:
	var p := price(id)
	if cash < p or not can_take(id):
		return false
	cash -= p
	take(id)
	return true


func buy_soda() -> bool:
	if cash < soda_price() or hearts >= max_hearts:
		return false
	cash -= soda_price()
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


## A hazard for the next match, unless SUNSCREEN takes it (once a trip).
func add_hazard(id: String) -> void:
	if used.count("sunscreen") < _sum("sunscreen"):
		used.append("sunscreen")
		return
	hazards.append(id)


## What a detour's choice asks of your cash: nothing with a GAS CARD,
## except a bet.
func cash_needed(ch: Dictionary) -> int:
	if _sum("gas") > 0 and not ch["do"].has("gamble"):
		return 0
	return int(ch.get("needs_cash", 0))


## A coin flip at this stop (a bet, a contest): LUCKY DICE always win.
func _flip(salt: int) -> bool:
	return _sum("lucky") > 0 or roll(seed, _stop_salt(), salt, 2) == 0


## A detour's choices as a scene shows them: each with whether you can
## afford it, and DRIVE ON after them when you can afford none.
func detour_choices(d: Dictionary) -> Array:
	var out := []
	var any := false
	for ch in d["choices"]:
		var need := cash_needed(ch)
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
	if cash < cash_needed(ch):
		return false
	var e: Dictionary = ch["do"]
	var spend := int(e.get("cash", 0))
	if spend < 0 and cash_needed(ch) == 0 and int(ch.get("needs_cash", 0)) > 0:
		spend = 0                    # on the GAS CARD
	cash = maxi(0, cash + spend)
	if e.has("heart"):
		heal(int(e["heart"]))
	if e.has("hazard"):
		add_hazard(String(e["hazard"]))
	if e.has("gamble"):
		var bet := int(e["gamble"])
		cash += bet if _flip(43) else -bet
		cash = maxi(0, cash)
	if e.has("flip_cash") and _flip(45):
		cash += int(e["flip_cash"])
	if e.has("flip_pick") and _flip(47):
		offer_pick(String(e["flip_pick"]), 3)
	if e.has("boost"):
		for k in e["boost"]:
			var i := STATS.find(String(k))
			if i >= 0:
				boost[i] = int(boost[i]) + int(e["boost"][k])
	if e.has("boost_all"):
		for i in 4:
			boost[i] = int(boost[i]) + int(e["boost_all"])
	if e.has("miles"):
		miles += int(e["miles"])
	if e.has("partner"):
		rest(false)
	if e.has("pick"):
		offer_pick(String(e["pick"]), 2)
	return true


## The diner's menu at this stop: three of the four dishes (the same each
## time) and THE WORKS for cash.
func diner_menu() -> Array:
	var dishes: Array = data()["diner"].slice(0, 4)
	var skip := roll(seed, _stop_salt(), 49, dishes.size())
	var out := []
	for i in dishes.size():
		if i != skip:
			out.append(String(dishes[i]["id"]))
	out.append(String(data()["diner"][4]["id"]))
	return out


## The menu as a scene's choices.
func diner_choices() -> Array:
	var out := []
	for id in diner_menu():
		var d := dish(String(id))
		var need := int(d.get("cash", 0))
		out.append({"label": String(d["label"]), "enabled": cash >= need,
			"value": "" if cash >= need else "NEED %d" % need})
	return out


## Orders the menu's `i`th dish: its stats for the next match.
func order(i: int) -> bool:
	var menu := diner_menu()
	if i < 0 or i >= menu.size():
		return false
	var d := dish(String(menu[i]))
	if cash < int(d.get("cash", 0)):
		return false
	cash -= int(d.get("cash", 0))
	meal = String(d["id"])
	return true


# --- The save -------------------------------------------------------------------------

const KEYS := ["seed", "gen", "heat", "partner", "map", "at", "hearts", "max_hearts", "cash",
	"base", "partner_stats", "paddle", "hat", "bag", "hazards", "used", "pending", "beaten",
	"route", "stops", "wins", "losses", "miles", "state", "locker", "boost", "meal", "rival_won",
	"daily", "title"]


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
		"partners": [], "seen": 0, "looks": {"van": 0, "ornament": 0, "tape": 0, "pen": 0}, "last_item": "",
		"now": {},
		"hogs": 0, "beats": [], "story_pool": [], "tapes": [], "bonds": {}, "bond_seen": [],
		"daily": {}, "daily_won": 0, "postcards": [], "pens": [], "garage_steps": -1}
	if save == null:
		return def
	if not save.data.has("trip") or typeof(save.data["trip"]) != TYPE_DICTIONARY:
		save.data["trip"] = def
	var m: Dictionary = save.data["trip"]
	for k in def:
		if not m.has(k):
			m[k] = def[k]
	for k in def["looks"]:
		if not m["looks"].has(k):
			m["looks"][k] = def["looks"][k]
	return m


## The title's ROAD TRIP value: the leg of a trip in progress, or the
## trips won.
static func title_label(save: SaveGame) -> String:
	if save == null:
		return ""
	var t := current(save)
	if t != null:
		return "LEG %d/%d" % [t.leg() + 1, t.legs()]
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
	t.garage_since = int(m["garage_steps"])
	m["garage_steps"] = steps_reached(m)
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
	var key := str(partner)
	m["bonds"][key] = int(m["bonds"].get(key, 0)) + wins + (BOND_TITLE if won_title() else 0)
	if daily > 0:
		var best: Dictionary = m["daily"] if int(m["daily"].get("date", 0)) == daily else {"date": daily}
		if won_title() and not best.get("won", false):
			m["daily_won"] = int(m["daily_won"]) + 1
		best["won"] = best.get("won", false) or won_title()
		best["leg"] = maxi(int(best.get("leg", 0)), leg() + 1)
		best["tries"] = int(best.get("tries", 0)) + 1
		m["daily"] = best
	var partners: Array = m["partners"]
	for team in beaten:
		if team != Opponents.DAWSON and team != 7 and not partners.has(team):
			partners.append(team)
	if rival_won:
		m["hogs"] = int(m["hogs"]) + 1
	if won_title():
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
		"pool": [], "vans": [0], "ornaments": [0], "tapes": [0]}
	for t in meta_dict.get("tapes", []):
		out["tapes"].append(int(t))

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
## The card before a new trip's first scene (port ADR-097): the stats you
## start with, what the GARAGE adds to them, and what's new since the last
## trip began. {} when the GARAGE adds nothing yet, and on the day's trip.
func garage_card(meta_dict: Dictionary) -> Dictionary:
	if daily > 0:
		return {}
	var g := garage(meta_dict)
	var adds := _stat_gains(g["stats"])
	var more := []
	if int(g["hearts"]) > 0:
		more.append("%d MORE HEART%s" % [int(g["hearts"]), "S" if int(g["hearts"]) > 1 else ""])
	if int(g["cash"]) > 0:
		more.append("%d CASH" % int(g["cash"]))
	if String(g["paddle"]) != "":
		more.append("A " + String(gear(String(g["paddle"]))["name"]))
	if adds == "" and more.is_empty():
		return {}
	var now := stats()
	var parts := []
	for i in 4:
		parts.append("%s %d" % [STAT_NAMES[i], int(now[i])])
	var lines := ["   ".join(parts)]
	if adds != "":
		lines.append("THE GARAGE: " + adds)
	if not more.is_empty():
		lines.append(("AND " if adds != "" else "THE GARAGE: ") + ", ".join(more))
	if garage_since >= 0:
		var fresh := [0, 0, 0, 0]
		var ladder: Array = data()["ladder"]
		for i in range(garage_since, mini(steps_reached(meta_dict), ladder.size())):
			for k in 4:
				fresh[k] += int(ladder[i].get(STATS[k], 0))
		if _stat_gains(fresh) != "":
			lines.append("NEW: " + _stat_gains(fresh))
	return {"over": "YOUR STATS TO START", "title": "FROM THE GARAGE", "lines": lines}


## "+1 POWER, +2 FEET", or "+2 TO EVERY STAT", or "" for none.
static func _stat_gains(add: Array) -> String:
	if int(add[0]) > 0 and add.all(func(v): return int(v) == int(add[0])):
		return "+%d TO EVERY STAT" % int(add[0])
	var parts := []
	for k in 4:
		if int(add[k]) > 0:
			parts.append("+%d %s" % [int(add[k]), STAT_NAMES[k]])
	return ", ".join(parts)


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
		var nth := 0
		for j in i + 1:
			nth += int(data()["ladder"][j].get("heart", 0))
		parts.append("A %s HEART" % ["FOURTH", "FIFTH", "SIXTH"][clampi(nth - 1, 0, 2)])

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


# --- The story across trips (port ADR-092) ------------------------------------------

## A story beat is a scene that plays once, at its slot (start, motel, leg,
## team, rival, beaten, won, over, detour), when its "when" holds: trip
## (this is at least the nth trip), won (trips won before), heat (this
## trip's), hogs (ROAD HOGS beaten before), needs (beats seen), pepper
## (Pepper is your partner), and the slot's own team or leg. `ctx` holds
## this trip's heat, partner, trip number, and the slot's team, leg or
## rival.
static func beat_due(meta_dict: Dictionary, b: Dictionary, ctx: Dictionary) -> bool:
	if b.is_empty() or meta_dict.get("beats", []).has(String(b["id"])):
		return false
	var w: Dictionary = b.get("when", {})
	if int(ctx.get("trip", int(meta_dict.get("trips", 0)))) < int(w.get("trip", 0)):
		return false
	if int(meta_dict.get("won", 0)) < int(w.get("won", 0)):
		return false
	if int(ctx.get("heat", 0)) < int(w.get("heat", 0)):
		return false
	if int(meta_dict.get("hogs", 0)) < int(w.get("hogs", 0)):
		return false
	if w.get("pepper", false) and int(ctx.get("partner", PEPPER)) != PEPPER:
		return false
	for id in w.get("needs", []):
		if not meta_dict.get("beats", []).has(String(id)):
			return false
	if b.has("team") and String(b["slot"]) in ["team", "beaten"] and int(ctx.get("team", -99)) != int(b["team"]):
		return false
	if b.get("rival", false) and not ctx.get("rival", false):
		return false
	if b.has("leg") and int(ctx.get("leg", -1)) != int(b["leg"]):
		return false
	if b.get("encore", false) and not ctx.get("encore", false):
		return false
	return true


## The first beat due at `slot`, or {}.
static func beat_for(meta_dict: Dictionary, slot: String, ctx: Dictionary) -> Dictionary:
	for b in data()["beats"]:
		if String(b["slot"]) == slot and beat_due(meta_dict, b, ctx):
			return b
	return {}


## A beat seen: kept, and its reward handed over (new gear on the road, a
## tape for the deck).
static func see_beat(meta_dict: Dictionary, b: Dictionary) -> void:
	if b.is_empty() or meta_dict["beats"].has(String(b["id"])):
		return
	meta_dict["beats"].append(String(b["id"]))
	var r: Dictionary = b.get("reward", {})
	for id in r.get("pool", []):
		if not meta_dict["story_pool"].has(String(id)):
			meta_dict["story_pool"].append(String(id))
	if r.has("tape") and not meta_dict["tapes"].has(int(r["tape"])):
		meta_dict["tapes"].append(int(r["tape"]))
	if r.has("pen") and meta_dict.has("pens") and not meta_dict["pens"].has(int(r["pen"])):
		meta_dict["pens"].append(int(r["pen"]))



## This trip as a beat's context (`more`: the slot's team, leg or rival).
func ctx(meta_dict: Dictionary, more: Dictionary = {}) -> Dictionary:
	var out := {"heat": heat, "partner": partner, "trip": int(meta_dict.get("trips", 1)), "leg": leg()}
	out.merge(more, true)
	return out


## A trip's opening scene: a beat due, the captain partner's own, the
## first trip's, or the one for every trip after.
func start_pages(meta_dict: Dictionary) -> Array:
	var scenes: Dictionary = data()["scenes"]
	if daily > 0:
		return scenes["daily"]
	var pages: Array = []
	var b := beat_for(meta_dict, "start", ctx(meta_dict))
	if not b.is_empty():
		see_beat(meta_dict, b)
		pages = b["pages"]
	elif partner >= 0 and partner < scenes["partner_start"].size():
		pages = scenes["partner_start"][partner]
	else:
		pages = scenes["start"] if int(meta_dict.get("trips", 1)) <= 1 else scenes["start_again"]
	# a partner's bond at level 2 the first time: their own scene, and their item
	var key := str(partner)
	if bond_level(meta_dict, partner) >= 2 and not meta_dict.get("bond_seen", []).has(key):
		meta_dict["bond_seen"].append(key)
		pages = pages + data()["bonds"][key]["pages"]
	return pages



## The ROAD HOGS' looks (opponents.json's member shape), for the match and
## their scenes.
static func rival_members() -> Array:
	return data()["rival"]["members"].duplicate(true)


## The ROAD HOGS' scene before their match: a beat due, or a taunt (a
## friendly word once the arc is done).
func rival_pages(meta_dict: Dictionary) -> Array:
	var b := beat_for(meta_dict, "rival", ctx(meta_dict, {"rival": true}))
	if not b.is_empty():
		see_beat(meta_dict, b)
		return b["pages"]
	var done: bool = meta_dict.get("beats", []).has("hogs_5")
	return data()["scenes"]["rival_friendly" if done else "rival_again"]


## An arc's beats in order, and how many of them are seen.
static func arc_beats(arc: String) -> Array:
	return data()["beats"].filter(func(b): return String(b["arc"]) == arc)


static func arc_seen(meta_dict: Dictionary, arc: String) -> Array:
	return arc_beats(arc).filter(func(b): return meta_dict.get("beats", []).has(String(b["id"])))


## The SCRAPBOOK's line for what comes next in an arc ("" when it's done).
static func arc_hint(meta_dict: Dictionary, arc: String) -> String:
	for b in arc_beats(arc):
		if not meta_dict.get("beats", []).has(String(b["id"])):
			return String(b.get("hint", ""))
	return ""


## A beat's scene as the SCRAPBOOK replays it: its pages (a story
## detour's own) and where it's set.
static func beat_scene(b: Dictionary) -> Dictionary:
	var pages: Array = b.get("pages", [])
	var opts := {}
	match String(b["slot"]):
		"start":
			opts = {"art": "garage"}
		"motel":
			opts = {"art": "motel"}
		"won":
			opts = {"art": "summer_open"}
		"rival":
			opts = {"art": "roadside", "members": rival_members()}
		"detour":
			for d in data()["detours"]:
				if String(d.get("beat", "")) == String(b["id"]):
					var sc := detour_scene(d)
					pages = sc["pages"]
					opts = sc["opts"]

		"beaten":
			opts = {"art": "roadside", "members": rival_members()} if b.get("rival", false) else {}
		_:
			opts = {"art": "roadside"}
	if b.has("team"):
		opts = {"venue": Settings.home_venue(int(b["team"])), "team": int(b["team"])}
		if String(b["slot"]) == "won":
			opts["art"] = "summer_open"
	return {"pages": pages, "opts": opts}


## A detour's scene: its pages (a narrator reading its lines, or its own)
## and where it's set (a trip backdrop, or a venue at a time of day).
static func detour_scene(d: Dictionary) -> Dictionary:
	var opts := {}
	if d.has("art"):
		opts["art"] = String(d["art"])
	if d.has("venue"):
		opts["venue"] = String(d["venue"])
		opts["time"] = int(d.get("time", 0))
	return {"pages": d.get("pages", [{"who": "narrator", "lines": d["lines"]}]), "opts": opts}


# --- Round three (port ADR-093): the day's trip, bonds, postcards, pens ---------------

## TRIP OF THE DAY: today's date as YYYYMMDD (`date_override` in the tests).
static var date_override := 0

static func today() -> int:
	if date_override > 0:
		return date_override
	var d := Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## A date's seed: the same day, the same map, for everyone.
static func daily_seed(date: int) -> int:
	return roll(date, 2026, 94, 0x7ffffff) + 1


## The day's trip, stored: HEAT 0, Pepper, and nothing from the GARAGE or
## the story (everyone starts it the same); its end is kept by the date.
static func begin_daily(save: SaveGame, date: int) -> RoadTrip:
	var m := meta(save)
	var t := create(daily_seed(date), 0, PEPPER)
	t.daily = date
	t._meta_for_draw = m
	m["trips"] = int(m["trips"]) + 1
	t.store(save)
	return t


## ROAD TRIP's row for the day's trip: today's best ("WON", "LEG 2") or "".
static func daily_label(meta_dict: Dictionary) -> String:
	var d: Dictionary = meta_dict.get("daily", {})
	if int(d.get("date", 0)) != today():
		return ""
	return "WON" if d.get("won", false) else "LEG %d" % int(d.get("leg", 1))


## A date as the screens show it ("10/24").
static func date_label(date: int) -> String:
	return "%d/%d" % [(date / 100) % 100, date % 100]


## A partner's bond: its points and level (0 to 3) with `who`.
static func bond_points(meta_dict: Dictionary, who: int) -> int:
	return int(meta_dict.get("bonds", {}).get(str(who), 0))


static func bond_level(meta_dict: Dictionary, who: int) -> int:
	var p := bond_points(meta_dict, who)
	var lv := 0
	for need in BOND_LEVELS:
		if p >= int(need):
			lv += 1
	return lv


## The partner's own item, from bond level 2.
static func bond_item(who: int) -> String:
	return String(data()["bonds"][str(who)]["item"])


## The announcer's opening calls for a stop's match (MatchView.trip_calls;
## the first two recorded are said): the islands' arrival, the stop's
## kind, your last heart, a hazard, the meal, HEAD START, a strong bond.
func calls_for(n: Dictionary, meta_dict: Dictionary = {}) -> Array:
	var out := []
	var type := String(n.get("type", ""))
	if daily > 0 and wins + losses == 0:
		out.append("trip_daily")
	if leg() == ISLANDS and col() == 0:
		out.append("trip_islands")
	match type:
		"pickup":
			out.append("trip_pickup")
		"grudge":
			out.append("trip_stranger" if int(n.get("team", -1)) == Opponents.DAWSON else "trip_grudge")
		"rival":
			out.append("trip_rival" if int(n.get("level", 0)) == 0 else "trip_rival_again")
		"big", "final", "encore":
			out.append("trip_" + type)
	if hearts == 1:
		out.append("trip_last_heart")
	var hz := {"fog": "trip_hazard_fog", "heat_wave": "trip_hazard_heat", "full_moon": "trip_hazard_moon",
		"wrong_glasses": "trip_hazard_glasses", "flat_tire": "trip_hazard_flat"}
	for h in hazards:
		if hz.has(String(h)):
			out.append(String(hz[String(h)]))
	if meal != "":
		out.append("trip_meal")
	if has_perk("head_start"):
		out.append("trip_perk_head_start")
	if type in ["big", "final", "encore"] and bond_level(meta_dict, partner) >= 3:
		out.append("trip_bond")
	return out


## Every postcard there is: a card for each venue a trip can play and each
## detour ("v:park", "d:hitchhiker").
static func postcards_all() -> Array:
	var out := []
	for leg in data()["legs"]:
		for v in leg["venues"] + [String(leg.get("encore_venue", "sunset"))]:
			if not out.has("v:" + String(v)):
				out.append("v:" + String(v))
	for d in data()["detours"]:
		out.append("d:" + String(d["id"]))
	return out


## A postcard collected (a venue played on a trip, a detour taken); the
## map pens it earns.
static func postcard(meta_dict: Dictionary, key: String) -> void:
	if not meta_dict.has("postcards") or meta_dict["postcards"].has(key) or not postcards_all().has(key):
		return
	meta_dict["postcards"].append(key)
	for i in PEN_POSTCARDS.size():
		if meta_dict["postcards"].size() >= int(PEN_POSTCARDS[i]) and not meta_dict["pens"].has(i + 1):
			meta_dict["pens"].append(i + 1)


## A postcard's name: the venue's, or the detour's.
static func postcard_name(key: String) -> String:
	var id := key.substr(2)
	if key.begins_with("v:"):
		return String(Settings.VENUE_NAMES[maxi(0, Settings.VENUES.find(id))])
	return String(detour(id).get("name", id.to_upper()))


## The map pens you can pick in the GARAGE: the red, and those earned.
static func pens_open(meta_dict: Dictionary) -> Array:
	var out := [0]
	for p in meta_dict.get("pens", []):
		if not out.has(int(p)):
			out.append(int(p))
	out.sort()
	return out
