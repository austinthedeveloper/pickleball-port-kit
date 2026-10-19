## Open play (ADR-034): a park with three courts. Each court has a game
## going and a paddle stack: paddles in line for the next game. Entries are
## ladder teams (ADR-023, a pair each) or you. When a game ends all four
## come off and the top two entries go on; the players coming off join the
## back of a stack. You walk the park, put your paddle in a court's stack,
## and play when your turn comes. A port of reference/snes-src/src/
## open_play.c, in its order.
##
## The courts are skill levels (ADR-034, amended): <3.5, 3.5-4.5, and 4.5+.
## Each ladder team calls one home (the ladder's order is its difficulty),
## and your game there is EASY, MEDIUM, or HARD.
##
## Pure like the rest of the sim: ints only, positions in 12.4, no Nodes,
## no time; its randomness is its own xorshift16 on a seed passed in.
## park_view.gd draws it and main.gd runs the match.
class_name OpenPlay
extends RefCounted

const COURTS := 3
const STACK_MAX := 4            ## entries waiting at one court
const YOU := 0x80               ## an entry: you (and a partner)
const NONE := 0xff
const TEAMS := 8                ## the ladder (opponents.json; a test checks)
const GAME_POINTS := 7          ## the park's own games: first to 7
## A point every 1 to 3 s, so a game lasts about half a minute.
const POINT_MIN_FRAMES := 60
const POINT_SPAN_FRAMES := 128  ## a power of two (a mask)
const CHANGEOVER_FRAMES := 120  ## players walk off, then a pause
const WALK_FRAMES := 64         ## walking off, or on before a game
const CALL_FRAMES := 150        ## "YOUR GAME!" before the match

## Park layout in park pixels: two screens wide (PARK_W x 224), the view
## scrolling with you. The courts are on the first screen; they run top to
## bottom, and the path along the bottom has a paddle rack at each court's
## gate.
const PARK_W := 512
const PARK_H := 224
const COURT_W := 56
const COURT_H := 112
const COURT_TOP := 48
const COURT_LEFT0 := 20
const COURT_PITCH := 80         ## court n's left edge: 20 + 80 n
const RACK_Y := COURT_TOP + COURT_H + 10
const RACK_DX := COURT_W / 2    ## the rack at the court's gate
const RACK_REACH := 14          ## B works within this of a rack
const PEEK_REACH := 28          ## the panel names a court this close

## You: a ground point (feet), in 12.4.
const START_X := 128
const START_Y := 196
const WALK_FP := 20             ## 1.25 px per frame
const WALK_TOP := 30
const WALK_BOTTOM := 210
const WALK_LEFT := 8
const WALK_RIGHT := 504
const FENCE_MARGIN := 4         ## feet stay this far off a fence

## The clubhouse, on the second screen: a room seen from above, its walls
## solid, a door in the bottom wall onto the path.
const HOUSE_LEFT := 296
const HOUSE_RIGHT := 488
const HOUSE_TOP := 40
const HOUSE_BOTTOM := 168
const HOUSE_WALL := 6
const HOUSE_DOOR_X := 392       ## the door's middle
const HOUSE_DOOR_W := 28
## Inside: B within SPOT_REACH of the records board (on the top wall) or
## the ball machine; the waiting teams sit on the bench (its left end),
## four people 12 px apart.
const BOARD_X := 336
const BOARD_Y := 64
const MACHINE_X := 452
const MACHINE_Y := 84
const BENCH_X := 344
const BENCH_Y := 132
const SPOT_REACH := 16
const BOARD_PAGES := 4          ## records shown, one per B

## OpenCourt.state
const COURT_PLAYING := 0
const COURT_CHANGEOVER := 1     ## between games
const COURT_YOURS := 2          ## your game: the match is on

## update() results.
const EVENT_NONE := 0
const EVENT_STACKED := 1        ## your paddle went into a stack
const EVENT_UNSTACKED := 2      ## you took it back
const EVENT_FULL := 3           ## that stack has no room
const EVENT_CALLED := 4         ## your game is up: the call banner
const EVENT_PLAY := 5           ## the banner is done: start the match
const EVENT_BOARD := 6          ## B at the records board: the next page
const EVENT_PRACTICE := 7       ## B at the ball machine: start practice

const EVENT_LOCKED := 8          ## that court is above your park rating (SNES ADR-070)
const STAY_MAX := 2               ## winners stay on for this many wins (SNES ADR-071)
## ROOKIE, CLUB, CHAMP (SNES ADR-070: period-true; DUPR-style ratings
## didn't exist in 1994).
const LEVEL_NAMES := ["ROOKIE", "CLUB", "CHAMP"]

## The park rating (SNES ADR-070), in tenths. A win at your level (the
## court whose range holds your rating) or above it moves you up more than
## a loss moves you down, so winning a third of your games there holds
## your place; below your level a win counts for nothing.
const RATING_NONE := 0            ## unrated: every court open
const RATING_START := 30          ## a new player: 10 points
const RATING_MIN := 20            ## 0 points
const RATING_MAX := 60
const RATING_WIN := 2             ## a win at your level
const RATING_WIN_UP := 3          ## a win on a court above it
const RATING_LOSS := 1            ## a loss anywhere
const COURT_FLOOR := [0, 35, 45]  ## each court's floor: 15 and 25 points


class OpenCourt:
	var state := COURT_PLAYING
	var playing := [NONE, NONE]     ## the two entries on court (top, bottom)
	var score := [0, 0]
	var stack := [0, 0, 0, 0]       ## next first
	var stack_count := 0
	var timer := 0                  ## frames to the next point or game
	var rally := 0                  ## animation: frames into the rally (u8)
	var age := 0                    ## frames since this game began (to 255)
	var stay := NONE                ## the side on a winning streak (it stays on), or NONE
	var streak := 0                 ## games in a row that side has won


var court: Array = []           ## [OpenCourt] x COURTS
var x_fp := 0                   ## you
var y_fp := 0
var facing_left := 0
var walking := 0
var step := 0                   ## walk animation frame counter (u8)
var your_court := NONE          ## the court your paddle waits at, or none
var called := NONE              ## the court calling you, or NONE
var call_timer := 0
var opponent := NONE            ## your opponents' team, when called
var partner := NONE             ## the team next in line: its captain
                                ## partners you; NONE: the regular
var seed := 0
var lineup := 0                 ## changes when anyone comes on or off (u8)
var stacks := 0                 ## changes when any stack changes (u8)
var two_players := 0            ## 2P is with you: your partner
var last_won := NONE            ## your last game: 1 won, 0 lost, none
var last_score := [0, 0]        ## yours, theirs
var board_page := NONE          ## the records board's page, or NONE
var rating := RATING_NONE       ## yours (SNES ADR-070), or RATING_NONE
var best_court := COURTS - 1    ## the highest court open to you
var stay_court := NONE          ## you won and stay on this court, or NONE (SNES ADR-071)
var last_streak := 0            ## your last game: wins in a row there
## Pick your partner (SNES ADR-072): the team whose captain partners you in
## a fresh game, or NONE (next in line); bit n of pickable: team n may be
## picked (the ladder teams the career player has beaten).
var pick := NONE
var pickable := 0


func _init() -> void:
	for c in COURTS:
		court.append(OpenCourt.new())


## xorshift16 (the C avoids a multiply).
func _random() -> int:
	var x := seed
	x = (x ^ (x << 7)) & 0xffff
	x ^= x >> 9
	x = (x ^ (x << 8)) & 0xffff
	seed = x
	return x


## Skill levels: the ladder's first three teams, the next three, the last
## two (the ladder is ordered by difficulty, ADR-023).
const _TEAM_COURT := [0, 0, 0, 1, 1, 1, 2, 2]

static func team_court(team: int) -> int:
	return _TEAM_COURT[team] if team >= 0 and team < TEAMS else 0


static func court_level_name(c: int) -> String:
	return LEVEL_NAMES[c if c >= 0 and c < COURTS else 0]


## Your game's difficulty there (ADR-025); KID (the saved difficulty) stays
## KID, for its swing assist.
static func court_difficulty(c: int, saved_difficulty: int) -> int:
	const LEVELS := [K.DIFFICULTY_EASY, K.DIFFICULTY_MEDIUM, K.DIFFICULTY_HARD]
	if saved_difficulty == K.DIFFICULTY_KID:
		return K.DIFFICULTY_KID
	return LEVELS[c if c >= 0 and c < COURTS else 0]


# --- The park rating (SNES ADR-070) -------------------------------------------

static func court_floor(c: int) -> int:
	return COURT_FLOOR[c if c < COURTS else 0]


## The court whose range holds a rating.
static func rating_court(r: int) -> int:
	var c := COURTS - 1
	while c and r < COURT_FLOOR[c]:
		c -= 1
	return c


## A rating after a game on a court, won or lost.
static func rating_after(r: int, c: int, won: bool) -> int:
	var level := rating_court(r)
	if not won:
		return r - RATING_LOSS if r >= RATING_MIN + RATING_LOSS else RATING_MIN
	if c < level:
		return r
	var gain := RATING_WIN_UP if c > level else RATING_WIN
	return mini(r + gain, RATING_MAX)


## A rating as the park points shown (0 to 40): no decimals.
static func rating_points(r: int) -> int:
	return r - RATING_MIN if r > RATING_MIN else 0


## Your rating and the highest court open to you (from the career player
## when the park opens and after each game); RATING_NONE opens every court.
func rate(r: int, best: int) -> void:
	rating = r
	best_court = COURTS - 1 if r == RATING_NONE or best >= COURTS else best


func court_open(c: int) -> bool:
	return c <= best_court


static func court_left(c: int) -> int:
	return COURT_LEFT0 + COURT_PITCH * (c if c >= 0 and c < COURTS else 0)


static func rack_x(c: int) -> int:
	return court_left(c) + RACK_DX


## The rack within reach of you, or NONE.
func rack_near() -> int:
	var x := K.from_fp(x_fp)
	var y := K.from_fp(y_fp)
	for c in COURTS:
		if absi(x - rack_x(c)) <= RACK_REACH and absi(y - RACK_Y) <= RACK_REACH:
			return c
	return NONE


## The court you are next to (for the panel's peek), or NONE.
func court_near() -> int:
	var x := K.from_fp(x_fp)
	var y := K.from_fp(y_fp)
	for c in COURTS:
		var left := court_left(c)
		if x >= left - PEEK_REACH / 2 and x <= left + COURT_W + PEEK_REACH / 2 \
				and y >= COURT_TOP - PEEK_REACH and y <= COURT_TOP + COURT_H + PEEK_REACH:
			return c
	return NONE


## The clubhouse walls, with the margin.
static func _house_wall(x: int, y: int) -> bool:
	const M := FENCE_MARGIN
	if x <= HOUSE_LEFT - M or x >= HOUSE_RIGHT + M or y <= HOUSE_TOP - M \
			or y >= HOUSE_BOTTOM + M:
		return false                # outside it
	if x >= HOUSE_LEFT + HOUSE_WALL + M and x <= HOUSE_RIGHT - HOUSE_WALL - M \
			and y >= HOUSE_TOP + HOUSE_WALL + M and y <= HOUSE_BOTTOM - HOUSE_WALL - M:
		return false                # the room
	# The door: through the bottom wall only.
	if y > HOUSE_BOTTOM - HOUSE_WALL - M and x >= HOUSE_DOOR_X - HOUSE_DOOR_W / 2 + M \
			and x <= HOUSE_DOOR_X + HOUSE_DOOR_W / 2 - M:
		return false
	return true


func in_house() -> bool:
	var x := K.from_fp(x_fp)
	var y := K.from_fp(y_fp)
	return x > HOUSE_LEFT and x < HOUSE_RIGHT and y > HOUSE_TOP \
		and y < HOUSE_BOTTOM - HOUSE_WALL


func _spot_near(spot_x: int, spot_y: int) -> bool:
	return absi(K.from_fp(x_fp) - spot_x) <= SPOT_REACH \
		and absi(K.from_fp(y_fp) - spot_y) <= SPOT_REACH


func board_near() -> bool:
	return _spot_near(BOARD_X, BOARD_Y)


func machine_near() -> bool:
	return _spot_near(MACHINE_X, MACHINE_Y)


func bench_near() -> bool:
	return _spot_near(BENCH_X + 24, BENCH_Y + 8)


## The nth team waiting in a stack (stack order, court by court), or NONE:
## the bench shows the first two.
func waiting_team(n: int) -> int:
	for c in COURTS:
		var ct: OpenCourt = court[c]
		for i in ct.stack_count:
			if ct.stack[i] < TEAMS:
				if n == 0:
					return ct.stack[i]
				n -= 1
	return NONE


## True when a ground point is walkable (not inside a fenced court or a
## clubhouse wall).
static func walkable(px_fp: int, py_fp: int) -> bool:
	var x := K.from_fp(px_fp)
	var y := K.from_fp(py_fp)
	if x < WALK_LEFT or x > WALK_RIGHT or y < WALK_TOP or y > WALK_BOTTOM:
		return false
	if _house_wall(x, y):
		return false
	for c in COURTS:
		var left := court_left(c)
		if x > left - FENCE_MARGIN and x < left + COURT_W + FENCE_MARGIN \
				and y > COURT_TOP - FENCE_MARGIN and y < COURT_TOP + COURT_H + FENCE_MARGIN:
			return false
	return true


## Your place in your stack: 0 = next game, 1 = the one after; NONE when
## not stacked. Two entries per game.
func your_wait() -> int:
	if your_court == NONE:
		return NONE
	var ct: OpenCourt = court[your_court]
	for i in ct.stack_count:
		if ct.stack[i] == YOU:
			return i >> 1
	return NONE


## The first entry in a stack that is not skip, taken out (NONE skips
## nothing: the front).
func _stack_take(ct: OpenCourt, skip: int) -> int:
	for i in ct.stack_count:
		var entry: int = ct.stack[i]
		if entry != skip:
			_stack_remove(ct, entry)
			return entry
	return NONE


## A team waits in some stack.
func _team_waiting(team: int) -> bool:
	for ct: OpenCourt in court:
		for i in ct.stack_count:
			if ct.stack[i] == team:
				return true
	return false


func _stack_remove(ct: OpenCourt, entry: int) -> bool:
	for i in ct.stack_count:
		if ct.stack[i] != entry:
			continue
		for j in range(i + 1, ct.stack_count):
			ct.stack[j - 1] = ct.stack[j]
		ct.stack_count -= 1
		stacks = (stacks + 1) & 0xff
		return true
	return false


## A team coming off joins its own court's stack (its skill level); if that
## is full, the shortest stack (ties: from a random court).
func _stack_join(entry: int) -> void:
	var start := _random() & 3
	if entry == NONE or entry == YOU:
		return
	var ct: OpenCourt = court[team_court(entry)]
	if ct.stack_count < STACK_MAX:
		ct.stack[ct.stack_count] = entry
		ct.stack_count += 1
		stacks = (stacks + 1) & 0xff
		return
	var at := start if start < COURTS else 0
	var best: OpenCourt = null
	for n in COURTS:
		var o: OpenCourt = court[at]
		if o.stack_count < STACK_MAX and (best == null or o.stack_count < best.stack_count):
			best = o
		at = (at + 1) % COURTS
	if best:
		best.stack[best.stack_count] = entry
		best.stack_count += 1
		stacks = (stacks + 1) & 0xff


## The next entry for a court: its own stack, else the front team of the
## longest other stack (never your paddle: it waits where you put it).
## Never skip: your partner's team, when you stay on (SNES ADR-071).
func _next_entry(c: int, skip: int) -> int:
	var ct: OpenCourt = court[c]
	if ct.stack_count:
		var entry := _stack_take(ct, skip)
		if entry != NONE:
			return entry
	var best: OpenCourt = null
	for o in COURTS:
		var other: OpenCourt = court[o]
		if other == ct or other.stack_count == 0 or other.stack[0] == YOU or other.stack[0] == skip:
			continue
		if best == null or other.stack_count > best.stack_count:
			best = other
	return _stack_take(best, NONE) if best else NONE


## A game won by a side (SNES ADR-071): its streak goes on, or starts.
func _court_won(ct: OpenCourt, side: int) -> void:
	if ct.stay != side:
		ct.streak = 0
	ct.streak += 1
	ct.stay = side


## You give up your place as a winner (B at a rack while you wait to be
## called again): you come off, and the court's next game is a fresh one.
func _leave_stay() -> void:
	if stay_court >= COURTS:
		return
	var ct: OpenCourt = court[stay_court]
	if ct.playing[0] == YOU:
		ct.playing[0] = NONE
	if ct.playing[1] == YOU:
		ct.playing[1] = NONE
	ct.stay = NONE
	ct.streak = 0
	stay_court = NONE
	lineup = (lineup + 1) & 0xff


func _court_next_point(ct: OpenCourt) -> void:
	ct.timer = POINT_MIN_FRAMES + (_random() & (POINT_SPAN_FRAMES - 1))
	ct.rally = 0


## Changeover over. Winners stay (SNES ADR-071): the losers join a stack
## and the next entry comes on against the winners, at the other side. A
## fresh game (no winners staying, or they have won STAY_MAX in a row): the
## two off join stacks, then the next two come on.
func _court_start_game(c: int) -> int:
	var ct: OpenCourt = court[c]
	var off0: int = ct.playing[0]
	var off1: int = ct.playing[1]
	var stay: int = ct.stay
	var skip := NONE
	# Your picked partner (SNES ADR-072); with 2P there is none.
	var pk: int = NONE if two_players else pick
	if stay >= 2 or ct.streak >= STAY_MAX or ct.playing[stay] == NONE:
		stay = NONE
	# You would challenge winners who are your picked partner's team: a
	# fresh game instead, so they are never your opponents.
	if stay != NONE and pk != NONE and ct.playing[stay] == pk and ct.stack_count \
			and ct.stack[0] == YOU:
		stay = NONE
	# Those off go to the back of their stacks first, so a court whose
	# stack is short keeps its own level playing (the CHAMP court has two
	# teams); anyone waiting is ahead of them.
	lineup = (lineup + 1) & 0xff
	if stay != NONE:
		ct.playing[stay ^ 1] = NONE
		_stack_join(off0 if stay else off1)
		# You stay on with the same partner: their team waits on.
		if ct.playing[stay] == YOU and two_players == 0:
			skip = partner
		ct.playing[stay ^ 1] = _next_entry(c, skip)
	else:
		ct.stay = NONE
		ct.streak = 0
		ct.playing[0] = NONE
		ct.playing[1] = NONE
		_stack_join(off0)
		_stack_join(off1)
		# You come on (first or second in line) with a picked partner:
		# their team is passed over.
		if pk != NONE and ct.stack_count and (ct.stack[0] == YOU
				or (ct.stack_count > 1 and ct.stack[1] == YOU)):
			skip = pk
		ct.playing[0] = _next_entry(c, skip)
		ct.playing[1] = _next_entry(c, skip)
	ct.score[0] = 0
	ct.score[1] = 0
	if ct.playing[0] == NONE or ct.playing[1] == NONE:
		# Not enough players yet (winners staying come off too): wait for
		# the next changeover.
		_stack_join(ct.playing[0])
		_stack_join(ct.playing[1])
		ct.playing[0] = NONE
		ct.playing[1] = NONE
		ct.stay = NONE
		ct.streak = 0
		if stay_court == c:
			stay_court = NONE
		ct.state = COURT_CHANGEOVER
		ct.timer = CHANGEOVER_FRAMES
		return EVENT_NONE
	for side in 2:
		if ct.playing[side] != YOU:
			continue
		ct.state = COURT_YOURS
		your_court = NONE
		called = c
		call_timer = 0
		opponent = ct.playing[side ^ 1]
		if side == stay:
			# Called again as a winner: the same partner, while their team
			# still waits (another court may have taken it).
			stay_court = c
			if partner == NONE or _team_waiting(partner):
				return EVENT_CALLED
		else:
			stay_court = NONE
		# Your partner: the captain you picked, else the captain of the
		# team waiting next at this court (they stay in line); none
		# waiting, the regular.
		if pk != NONE:
			partner = pk
		else:
			partner = ct.stack[0] if ct.stack_count and ct.stack[0] != YOU else NONE
		return EVENT_CALLED
	ct.state = COURT_PLAYING
	_court_next_point(ct)
	# The new four walk on from the gate before the first serve.
	ct.age = 0
	ct.timer += WALK_FRAMES
	return EVENT_NONE


func _court_update(c: int) -> int:
	var ct: OpenCourt = court[c]
	if ct.state == COURT_YOURS:
		return EVENT_NONE
	if ct.timer:
		ct.timer -= 1
	if ct.state == COURT_CHANGEOVER:
		return EVENT_NONE if ct.timer else _court_start_game(c)
	if ct.age != 255:
		ct.age += 1
	ct.rally = (ct.rally + 1) & 0xff
	if ct.timer:
		return EVENT_NONE
	var side := _random() & 1
	ct.score[side] += 1
	if ct.score[side] >= GAME_POINTS:
		_court_won(ct, side)
		ct.state = COURT_CHANGEOVER
		ct.timer = CHANGEOVER_FRAMES
		return EVENT_NONE
	_court_next_point(ct)
	return EVENT_NONE


## A fresh park: six teams playing, two waiting, you at the gate; with
## two_players, 2P comes along as your partner.
func begin(start_seed: int, with_2p: bool) -> void:
	seed = start_seed & 0xffff if start_seed & 0xffff else 0xace1
	lineup = (lineup + 1) & 0xff
	for c in COURTS:
		var ct: OpenCourt = court[c]
		ct.state = COURT_PLAYING
		ct.playing[0] = NONE
		ct.playing[1] = NONE
		ct.score[0] = _random() & 3
		ct.score[1] = _random() & 3
		ct.stack_count = 0
		ct.stay = NONE
		ct.streak = 0
		_court_next_point(ct)
		ct.age = 255                # these games are already going
	# Each team at its level's court: the first two play, the rest wait.
	for entry in TEAMS:
		var ct: OpenCourt = court[team_court(entry)]
		if ct.playing[0] == NONE:
			ct.playing[0] = entry
		elif ct.playing[1] == NONE:
			ct.playing[1] = entry
		else:
			ct.stack[ct.stack_count] = entry
			ct.stack_count += 1
	x_fp = K.to_fp(START_X)
	y_fp = K.to_fp(START_Y)
	facing_left = 0
	walking = 0
	step = 0
	your_court = NONE
	called = NONE
	call_timer = 0
	opponent = NONE
	partner = NONE
	two_players = 1 if with_2p else 0
	last_won = NONE
	last_score = [0, 0]
	board_page = NONE
	stay_court = NONE
	last_streak = 0
	pick = NONE
	pickable = 0
	rate(RATING_NONE, 0)


## Pick your partner (SNES ADR-072): the teams you may pick (bit n: ladder
## team n); a pick no longer among them goes back to next in line.
func partners(teams: int) -> void:
	pickable = teams
	if pick >= TEAMS or (teams & (1 << pick)) == 0:
		pick = NONE


## Y picks: you stand at the rack holding your paddle, with teams to pick
## and no 2P.
func pick_ready() -> bool:
	return called == NONE and two_players == 0 and pickable != 0 \
		and your_court != NONE and rack_near() == your_court


## Y: next in line, then each team you may pick in ladder order, then next
## in line again. True when the pick changed.
func pick_next() -> bool:
	if not pick_ready():
		return false
	var team := 0 if pick >= TEAMS else pick + 1
	while team < TEAMS and (pickable & (1 << team)) == 0:
		team += 1
	pick = team if team < TEAMS else NONE
	return true


func _press_rack(rack: int) -> int:
	var ct: OpenCourt = court[rack]
	# Waiting to be called again as a winner, you give that up.
	_leave_stay()
	if your_court == rack:
		_stack_remove(ct, YOU)
		your_court = NONE
		return EVENT_UNSTACKED
	if not court_open(rack):
		return EVENT_LOCKED
	if ct.stack_count >= STACK_MAX:
		return EVENT_FULL
	if your_court != NONE:
		_stack_remove(court[your_court], YOU)
	ct.stack[ct.stack_count] = YOU
	ct.stack_count += 1
	stacks = (stacks + 1) & 0xff
	your_court = rack
	return EVENT_STACKED


func _walk(move_x: int, move_y: int) -> void:
	var x := x_fp + move_x * WALK_FP
	var y := y_fp + move_y * WALK_FP
	# Each axis on its own, so you slide along a fence.
	if move_x and walkable(x, y_fp):
		x_fp = x
	if move_y and walkable(x_fp, y):
		y_fp = y
	if move_x:
		facing_left = 1 if move_x < 0 else 0
	walking = 1 if move_x or move_y else 0
	if walking:
		step = (step + 1) & 0xff


## One park frame: walking (the D-pad), B at a rack, the courts' games.
## Returns EVENT_*. While called, input is ignored.
func update(move_x: int, move_y: int, b_pressed: bool) -> int:
	var event := EVENT_NONE
	for c in COURTS:
		var result := _court_update(c)
		if result != EVENT_NONE:
			event = result
	if called != NONE:
		walking = 0
		if event == EVENT_CALLED:
			return event
		call_timer += 1
		if call_timer >= CALL_FRAMES:
			call_timer = CALL_FRAMES
			return EVENT_PLAY
		return EVENT_NONE
	_walk(move_x, move_y)
	# The board's page shows while you stand there.
	if not board_near():
		board_page = NONE
	if b_pressed:
		var rack := rack_near()
		if rack != NONE:
			event = _press_rack(rack)
		elif board_near():
			board_page = 0 if board_page >= BOARD_PAGES - 1 else board_page + 1
			event = EVENT_BOARD
		elif machine_near():
			event = EVENT_PRACTICE
	return event


## Back from your match: you won or lost by this score; your court's game
## ends and the next one starts.
func return_from_match(won: bool, points_for: int, points_against: int) -> void:
	var c := called
	last_won = 1 if won else 0
	last_score = [points_for, points_against]
	last_streak = 0
	called = NONE
	stay_court = NONE
	if c >= COURTS:
		return
	var ct: OpenCourt = court[c]
	# Winners stay (SNES ADR-071): won, below the cap, you stay on and the
	# changeover calls you again; otherwise you leave. The court's next
	# game starts after a changeover.
	var side := 0 if ct.playing[0] == YOU else (1 if ct.playing[1] == YOU else NONE)
	if side != NONE:
		_court_won(ct, side if won else side ^ 1)
		if won:
			last_streak = ct.streak
		if won and ct.streak < STAY_MAX:
			stay_court = c
		else:
			ct.playing[side] = NONE
	ct.state = COURT_CHANGEOVER
	ct.timer = CHANGEOVER_FRAMES
	lineup = (lineup + 1) & 0xff
	x_fp = K.to_fp(rack_x(c))
	y_fp = K.to_fp(RACK_Y + 8)


## Everything, for tests that compare a park with another.
func snapshot() -> Array:
	var s := [x_fp, y_fp, facing_left, walking, step, your_court, called, call_timer,
		opponent, partner, seed, lineup, stacks, two_players, last_won, last_score.duplicate(),
		board_page, rating, best_court, stay_court, last_streak, pick, pickable]
	for ct: OpenCourt in court:
		s.append([ct.state, ct.playing.duplicate(), ct.score.duplicate(), ct.stack.duplicate(),
			ct.stack_count, ct.timer, ct.rally, ct.age, ct.stay, ct.streak])
	return s
