## CLUB (port ADR-106, PORT-142..150): the Pickleball '95 club manager.
## You own the park behind open play: a day at a time, you play on its
## courts while the members play around you, and at night the ledger says
## what the club made. Between days you spend it: upgrades that change the
## park (LIGHTS, a SNACK BAR, the BALL MACHINE, ANNEX courts, INDOOR
## courts), a COACH who runs drills, a WEEKEND CUP on Saturdays.
##
## Members are people with a skill, a patience and a mood: they come when
## the weather lets them, wait for a court, and leave when the waits are
## too long too often. Your wins on court bring new ones (word gets round).
## The weather comes from the club's seed and the day, so the forecast is
## known before the day and the same on a replay.
##
## Meta, not sim: none of this is in a match. A club match is an open play
## match (records, achievements and the career count it like one); WIND on
## a breezy day is the existing modifier. Ints only and seeded (its own
## xorshift32), so a club replays the same from the same days: the tests
## and tools/club_stats.gd play years of it headless.
##
## Saved in save.data["club"] ({"now": the club, or {}, and the records
## kept across clubs}); a missing key fills in (a harmless default, so the
## save layout stays v6).
class_name Club
extends RefCounted

# --- The numbers (the balance pass in ADR-106) ---------------------------------------

const START_CASH := 600
const START_MEMBERS := 16
const MAX_MEMBERS := 80
const DUES := 3                     ## a member, a day
const FEE := 1                      ## a player's game
const SNACK := 1                    ## a visitor's snack (2 on a HOT day)
const UPKEEP_BASE := 30
const UPKEEP_COURT := 8             ## each court open
const BASE_COURTS := 3
const GAMES_PER_COURT_HOUR := 1
const GAMES_WANTED := 3             ## games a visitor wants in a day
const COACH_FEE := 250              ## to hire
const COACH_WAGE := 2               ## a member, a day (classes)
const COACH_WAGE_MIN := 20          ## a day, however few
const CUP_PURSE := 100              ## the WEEKEND CUP's prize (back to you if you win it)
const CUP_ENTRY := 30               ## each visiting team's entry
const CUP_GATE := 2                 ## each member watching
const CUP_REP := 12                 ## a cup won
const BUST_DAYS := 14               ## days in a row in the red before the bank calls
const RICH := 20000                 ## the balance pass's ceiling at day 60
const MOOD_MAX := 3
const MOOD_LEAVE := -3              ## a member this unhappy leaves
const SKILL_MAX := 95
const WALKIN_REP := 8               ## a walk-in for each this much reputation
const JOIN_REP := 15                ## a new member for each this much
const JOINS_MAX := 2                ## a day
const PATIENCE_MAX := 90            ## minutes: a coached member's most
const WAIT_NO_JOIN := 45            ## minutes: past this, nobody joins
const WAIT_PER_TEAM := 15           ## minutes a team waiting in a stack costs
const WAIT_DEFAULT := 10            ## the park's wait when it wasn't sampled

## The clock, in minutes from midnight. A park frame is CLOCK_FRAMES of
## a minute; a match takes MATCH_MINUTES, a drill DRILL_MINUTES.
const OPEN := 9 * 60
const CLOSE := 18 * 60
const CLOSE_LIGHTS := 21 * 60
const DUSK_AT := 17 * 60
const NIGHT_AT := 18 * 60 + 30
const CLOCK_FRAMES := 8
const MATCH_MINUTES := 40
const DRILL_MINUTES := 30

const WEEKDAYS := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const SATURDAY := 5

## The weather, from the seed and the day: [name, chance in 100, attendance %].
const SUNNY := 0
const CLOUDY := 1
const HOT := 2
const WINDY := 3
const SHOWERS := 4
const RAIN := 5
const WEATHER := [["SUNNY", 35, 60], ["CLOUDY", 20, 55], ["HOT", 12, 40], ["WINDY", 12, 45],
	["SHOWERS", 11, 35], ["RAIN", 10, 0]]
const INDOOR_ATTENDANCE := 50        ## on a RAIN day, with INDOOR COURTS

## The upgrades, in the order UPGRADES lists them.
const UPGRADES := [
	{"id": "lights", "name": "LIGHTS", "price": 900, "upkeep": 6, "rep": 2,
		"what": "THE PARK STAYS OPEN TILL 9 PM"},
	{"id": "snack", "name": "SNACK BAR", "price": 600, "upkeep": 8, "rep": 2,
		"what": "VISITORS BUY A SNACK, TWO ON A HOT DAY"},
	{"id": "machine", "name": "BALL MACHINE", "price": 400, "upkeep": 2, "rep": 1,
		"what": "PRACTICE IN THE CLUBHOUSE"},
	{"id": "annex1", "name": "ANNEX COURT", "price": 1500, "upkeep": 0, "rep": 2, "courts": 1,
		"what": "ONE MORE COURT FOR THE MEMBERS"},
	{"id": "annex2", "name": "SECOND ANNEX", "price": 2200, "upkeep": 0, "rep": 2, "courts": 1,
		"needs": "annex1", "what": "ANOTHER COURT FOR THE MEMBERS"},
	{"id": "indoor", "name": "INDOOR COURTS", "price": 2800, "upkeep": 15, "rep": 3,
		"what": "OPEN IN THE RAIN, AT THE GYM"},
]

const FIRST := ["AL", "BEA", "CAL", "DOT", "ED", "FAY", "GUS", "HAL", "IDA", "JOE", "KAY", "LOU",
	"MAE", "NED", "OLA", "PAT", "RAY", "SAL", "TED", "VAL", "WES", "ZOE", "BUD", "CY", "DEB", "ELI",
	"FLO", "GIL", "HOPE", "IKE", "JUNE", "KIT"]
const LAST := "ABCDEFGHJKLMNOPRSTVW"

# --- The club ----------------------------------------------------------------------

var seed := 1
var rng := 1
var day := 1
var cash := START_CASH
var rep := 0                     ## reputation: walk-ins and new members
var members: Array = []          ## {"n": name, "s": skill, "p": patience (min), "m": mood, "d": joined, "c": coached days}
var upgrades: Dictionary = {}    ## id -> 1
var coach := false
var trophies: Array = []         ## the days a WEEKEND CUP was won
var red_days := 0                ## days in a row the cash has been below zero
var state := "on"                ## "on", or "bust" (the bank called)
var minute := OPEN               ## today's clock
var today: Dictionary = {}       ## today so far (fresh_today())
var ledger: Dictionary = {}      ## last night's (end_day())
var history: Array = []          ## the last 30 nights' nets
var joined_total := 0
var left_total := 0
var _next_name := 0


static func fresh_today() -> Dictionary:
	return {"wins": 0, "losses": 0, "win_rep": 0, "stack_sum": 0, "samples": 0, "drill": false,
		"cup": "", "cup_won": false, "played": false}


## A new club. Its members are drawn from the seed.
static func create(club_seed: int) -> Club:
	var c := Club.new()
	c.seed = club_seed & 0x7fffffff
	c.rng = c.seed if c.seed else 0x1234
	c.today = fresh_today()
	for i in START_MEMBERS:
		c.members.append(c._new_member())
	return c


func _random() -> int:
	var x := rng
	x ^= (x << 13) & 0xffffffff
	x ^= x >> 17
	x ^= (x << 5) & 0xffffffff
	rng = x & 0xffffffff
	if rng == 0:
		rng = 0x1234
	return rng


func _roll(n: int) -> int:
	return (_random() >> 8) % n


func _new_member() -> Dictionary:
	var m := {"n": _next_name, "s": 30 + _roll(31), "p": 20 + _roll(41), "m": 0, "d": day, "c": 0}
	_next_name += 1
	return m


static func member_name(m: Dictionary) -> String:
	var n := int(m["n"])
	return "%s %s." % [FIRST[n % FIRST.size()], LAST[(n / FIRST.size() + n * 7) % LAST.length()]]


# --- The calendar and the weather ----------------------------------------------------

func weekday(d := -1) -> int:
	return ((day if d < 0 else d) - 1) % 7


func day_label(d := -1) -> String:
	return "DAY %d  %s" % [day if d < 0 else d, WEEKDAYS[weekday(d)]]


func saturday() -> bool:
	return weekday() == SATURDAY


## The weather on day `d` (today by default): fixed by the seed and the day.
func weather(d := -1) -> int:
	var x := (seed ^ ((day if d < 0 else d) * 0x9e3779b1)) & 0xffffffff
	x ^= (x << 13) & 0xffffffff
	x ^= x >> 17
	x ^= (x << 5) & 0xffffffff
	var roll := (x & 0xffffffff) % 100
	for w in WEATHER.size():
		roll -= int(WEATHER[w][1])
		if roll < 0:
			return w
	return SUNNY


static func weather_name(w: int) -> String:
	return String(WEATHER[w][0])


## Rain closes the outdoor courts; INDOOR COURTS moves the day to the gym.
func indoors() -> bool:
	return weather() == RAIN and owns("indoor")


func park_closed() -> bool:
	return weather() == RAIN and not owns("indoor")


## The modifiers a club match adds to yours: WIND on a WINDY day.
func match_mods() -> int:
	return K.MOD_WIND if weather() == WINDY and not indoors() else 0


## OPEN PLAY's location today: THE PARK, or THE GYM in the rain (Settings.PARKS).
func park_index() -> int:
	return 2 if indoors() else 0


# --- The clock --------------------------------------------------------------------------

func closing() -> int:
	return CLOSE_LIGHTS if owns("lights") else CLOSE


func advance(minutes: int) -> void:
	minute = mini(minute + minutes, closing())


func closed_for_today() -> bool:
	return minute >= closing()


static func clock_label(m: int) -> String:
	var h := m / 60
	var am := h < 12
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if am else "PM"]


## The court's light: DAY, DUSK, NIGHT (CourtStyle's) at minute `m`.
static func time_of_day(m: int) -> int:
	if m >= NIGHT_AT:
		return CourtStyle.NIGHT
	if m >= DUSK_AT:
		return CourtStyle.DUSK
	return CourtStyle.DAY


# --- Upgrades and the coach ---------------------------------------------------------

func owns(id: String) -> bool:
	return int(upgrades.get(id, 0)) > 0


static func upgrade(id: String) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## "" when it can be bought now; else why not.
func why_not(id: String) -> String:
	var u := upgrade(id)
	if u.is_empty():
		return "NO SUCH THING"
	if owns(id):
		return "OWNED"
	if u.has("needs") and not owns(String(u["needs"])):
		return "NEEDS " + String(upgrade(String(u["needs"]))["name"])
	if cash < int(u["price"]):
		return "NEEDS %d" % int(u["price"])
	return ""


func buy(id: String) -> bool:
	if why_not(id) != "":
		return false
	cash -= int(upgrade(id)["price"])
	upgrades[id] = 1
	return true


func courts() -> int:
	var n := BASE_COURTS
	for u: Dictionary in UPGRADES:
		if owns(String(u["id"])):
			n += int(u.get("courts", 0))
	return n


## The courts open today: none in the rain without INDOOR COURTS; the
## gym's three (the annexes are outdoors) with them.
func courts_today() -> int:
	if park_closed():
		return 0
	return BASE_COURTS if indoors() else courts()


func hire_coach() -> bool:
	if coach or cash < COACH_FEE:
		return false
	cash -= COACH_FEE
	coach = true
	return true


func let_coach_go() -> void:
	coach = false


## Today's drill: a HOW TO PLAY lesson, a new one each day.
func drill_lesson() -> int:
	return (day - 1) % Tutorial.LESSONS.size()


func drill_ready() -> bool:
	return coach and not bool(today["drill"]) and not park_closed()


func finish_drill() -> void:
	today["drill"] = true
	advance(DRILL_MINUTES)


func upkeep() -> int:
	var n := UPKEEP_BASE + UPKEEP_COURT * courts()
	for u: Dictionary in UPGRADES:
		if owns(String(u["id"])):
			n += int(u["upkeep"])
	return n + coach_wage()


func coach_wage() -> int:
	return maxi(COACH_WAGE_MIN, COACH_WAGE * members.size()) if coach else 0


# --- Today ----------------------------------------------------------------------------

## Your match on a court of the park (OpenPlay's 0..2): a win brings word
## of the club, more from a higher court.
func add_match(won: bool, court_level: int) -> void:
	today["played"] = true
	if won:
		today["wins"] = int(today["wins"]) + 1
		today["win_rep"] = int(today["win_rep"]) + 3 + clampi(court_level, 0, 2)
	else:
		today["losses"] = int(today["losses"]) + 1
	advance(MATCH_MINUTES)


## The park's stacks, sampled while you walk it: teams waiting in all.
func sample_wait(teams_waiting: int) -> void:
	today["stack_sum"] = int(today["stack_sum"]) + teams_waiting
	today["samples"] = int(today["samples"]) + 1


## The WEEKEND CUP's end for you: how far, and whether you won it.
func cup_result(finish: String, won: bool) -> void:
	today["cup"] = finish if finish != "" else "OUT"
	today["cup_won"] = won


func cup_ready() -> bool:
	return saturday() and String(today["cup"]) == "" and not park_closed()


## The wait at a court today, in minutes: the park's own stacks, and the
## games wanted past what the courts can hold.
func wait_minutes(demand: int, capacity: int, open_courts: int) -> int:
	var samples := int(today["samples"])
	var park := WAIT_DEFAULT if samples == 0 else \
		int(today["stack_sum"]) * WAIT_PER_TEAM / (samples * OpenPlay.COURTS)
	var over := maxi(0, demand - capacity)
	return park + over * 60 / maxi(1, open_courts)


## The night: the day's games (the members play all day, with you or
## not), the ledger, members coming and going, the next day. Returns the
## ledger.
func end_day() -> Dictionary:
	var w := weather()
	var open_courts := courts_today()
	var hours := (closing() - OPEN) / 60
	var capacity := open_courts * hours * GAMES_PER_COURT_HOUR
	var attendance := int(WEATHER[w][2])
	if indoors():
		attendance = INDOOR_ATTENDANCE
	if open_courts == 0:
		attendance = 0
	var attending: Array = []
	for i in members.size():
		if _roll(100) < attendance:
			attending.append(i)
	var walkins := rep / WALKIN_REP if open_courts else 0
	var players := attending.size() + walkins
	var demand := players * GAMES_WANTED / 4
	var played := mini(demand, capacity)
	var wait := wait_minutes(demand, capacity, open_courts) if open_courts else 0
	var lines: Array = []
	lines.append(["DUES", members.size() * DUES])
	lines.append(["COURT FEES", played * 4 * FEE])
	if owns("snack") and players:
		lines.append(["SNACK BAR", players * (2 if w == HOT else 1) * SNACK])
	var cup := String(today["cup"])
	if cup != "":
		lines.append(["CUP ENTRIES", 7 * CUP_ENTRY + attending.size() * CUP_GATE])
		lines.append(["CUP PURSE", 0 if bool(today["cup_won"]) else -CUP_PURSE])
	lines.append(["UPKEEP", -(upkeep() - coach_wage())])
	if coach:
		lines.append(["COACH", -coach_wage()])
	var net := 0
	for l: Array in lines:
		net += int(l[1])
	# the members' day: a long wait sours them, a good day cheers them;
	# the coach's drills raise their skill and their patience
	var drill := bool(today["drill"])
	for i: int in attending:
		var m: Dictionary = members[i]
		var mood := int(m["m"])
		mood += -1 if wait > int(m["p"]) else 1
		if coach:
			# coached, they improve, and learn to wait their turn
			m["s"] = mini(SKILL_MAX, int(m["s"]) + (2 if drill else 1))
			m["p"] = mini(PATIENCE_MAX, int(m["p"]) + 1)
			m["c"] = int(m["c"]) + 1
		m["m"] = clampi(mood, MOOD_LEAVE, MOOD_MAX)
	var left: Array = []
	var kept: Array = []
	for m: Dictionary in members:
		if int(m["m"]) <= MOOD_LEAVE:
			left.append(member_name(m))
		else:
			kept.append(m)
	members = kept
	# word of the club: your wins, its upgrades, a strong membership, a cup
	var strong := 0
	for m: Dictionary in members:
		if int(m["s"]) >= 70:
			strong += 1
	var appeal := 0
	for u: Dictionary in UPGRADES:
		if owns(String(u["id"])):
			appeal += int(u["rep"])
	rep = rep * 9 / 10 + appeal + int(today["win_rep"]) + strong / 5 \
		+ (CUP_REP if bool(today["cup_won"]) else 0)
	var joins := 0
	if wait <= WAIT_NO_JOIN and open_courts:
		joins = mini(JOINS_MAX, rep / JOIN_REP)
	joins = mini(joins, MAX_MEMBERS - members.size())
	for j in joins:
		members.append(_new_member())
	joined_total += joins
	left_total += left.size()
	if bool(today["cup_won"]):
		trophies.append(day)
	cash += net
	red_days = red_days + 1 if cash < 0 else 0
	history.append(net)
	if history.size() > 30:
		history.pop_front()
	ledger = {"day": day, "weekday": weekday(), "weather": w, "lines": lines, "net": net,
		"cash": cash, "members": members.size(), "joined": joins, "left": left, "wait": wait,
		"played": played, "capacity": capacity, "players": players, "wins": int(today["wins"]),
		"losses": int(today["losses"]), "cup": cup, "cup_won": bool(today["cup_won"]),
		"bust": red_days >= BUST_DAYS, "red_days": red_days}
	if red_days >= BUST_DAYS:
		state = "bust"
	day += 1
	minute = OPEN
	today = fresh_today()
	return ledger


# --- Saving ----------------------------------------------------------------------------

const KEYS := ["seed", "rng", "day", "cash", "rep", "members", "upgrades", "coach", "trophies",
	"red_days", "state", "minute", "today", "ledger", "history", "joined_total", "left_total",
	"_next_name"]


func to_dict() -> Dictionary:
	var d := {}
	for k: String in KEYS:
		var v: Variant = get(k)
		d[k] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return d


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	for k: String in KEYS:
		if d.has(k):
			var v: Variant = d[k]
			c.set(k, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	var t := fresh_today()
	for k in t:
		if not c.today.has(k):
			c.today[k] = t[k]
	return c


## What lasts between clubs (save.data["club"]), filled in if missing.
static func meta(save: SaveGame) -> Dictionary:
	var def := {"now": {}, "clubs": 0, "best_day": 0, "best_cash": 0, "cups": 0}
	if save == null:
		return def
	if not save.data.has("club") or typeof(save.data["club"]) != TYPE_DICTIONARY:
		save.data["club"] = def
	var m: Dictionary = save.data["club"]
	for k in def:
		if not m.has(k):
			m[k] = def[k]
	return m


static func current(save: SaveGame) -> Club:
	var now: Dictionary = meta(save)["now"]
	return null if now.is_empty() else from_dict(now)


func store(save: SaveGame) -> void:
	var m := meta(save)
	m["now"] = to_dict() if state == "on" else {}
	m["best_day"] = maxi(int(m["best_day"]), day - 1)
	m["best_cash"] = maxi(int(m["best_cash"]), cash)
	m["cups"] = maxi(int(m["cups"]), trophies.size())


## A new club, stored (it replaces the one before).
static func begin(save: SaveGame, club_seed: int) -> Club:
	var c := create(club_seed)
	var m := meta(save)
	m["clubs"] = int(m["clubs"]) + 1
	c.store(save)
	return c


## PLAY > CLUB's value: the club's day, or nothing yet.
static func title_label(save: SaveGame) -> String:
	if save == null:
		return ""
	var c := current(save)
	return "" if c == null else "DAY %d" % c.day


# --- The balance pass (tools/club_stats.gd, test_club) --------------------------------

const STRATEGIES := ["SAVER", "BUILDER", "PLAYER", "SPENDER"]

## A day played by a strategy, headless: what it buys, how many matches
## it plays and wins, the cup on Saturdays. SAVER buys nothing and never
## plays; BUILDER buys an upgrade with a cushion left and plays a little;
## PLAYER plays a lot and well and hires the coach; SPENDER buys anything
## it can, the moment it can.
func bot_day(strategy: String, bot: Array) -> Dictionary:
	var plays := 0
	var win_pct := 50
	match strategy:
		"BUILDER":
			plays = 2
			for u: Dictionary in UPGRADES:
				if why_not(String(u["id"])) == "" and cash >= int(u["price"]) + 400:
					buy(String(u["id"]))
					break
		"PLAYER":
			plays = 3
			win_pct = 70
			if not coach and cash >= COACH_FEE + 300:
				hire_coach()
			for u: Dictionary in UPGRADES:
				if why_not(String(u["id"])) == "" and cash >= int(u["price"]) + 600:
					buy(String(u["id"]))
					break
		"SPENDER":
			plays = 1
			if not coach:
				hire_coach()
			for u: Dictionary in UPGRADES:
				buy(String(u["id"]))
	if park_closed():
		plays = 0
	for p in plays:
		bot[0] = (int(bot[0]) * 1103515245 + 12345) & 0x7fffffff
		add_match((int(bot[0]) >> 16) % 100 < win_pct, p % 3)
	if drill_ready():
		finish_drill()
	if strategy != "SAVER" and cup_ready():
		bot[0] = (int(bot[0]) * 1103515245 + 12345) & 0x7fffffff
		var won := (int(bot[0]) >> 16) % 100 < win_pct / 3
		cup_result("CHAMPION" if won else "SEMIFINALIST", won)
	return end_day()


## A club played `days` days by a strategy: every night's ledger.
static func simulate(club_seed: int, strategy: String, days: int) -> Array:
	var c := create(club_seed)
	var bot := [club_seed ^ 0x5eed]
	var out: Array = []
	for d in days:
		if c.state != "on":
			break
		out.append(c.bot_day(strategy, bot))
	return out
