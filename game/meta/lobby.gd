## The multiplayer lobby (PORT-16), pure: up to four controllers join,
## each with a card. A pad presses A to join and gets the first free
## player number (P1..P4). On its card: SIDE (LEFT or RIGHT; a side holds
## one player in singles, two in doubles), SHIRT (unique), BODY, PADDLE;
## A readies (and B un-readies, or leaves an unready card). LB / RB switch
## SINGLES and DOUBLES. In doubles the players on a side are partners and
## an empty place on a side goes to a CPU. Menu starts once everyone is
## ready and the teams work: two or more players, someone on the left (the
## sim's slot 0 is always a human), and in singles one on each side.
class_name Lobby
extends RefCounted

const LEFT := 0
const RIGHT := 1
const ROW_SIDE := 0
const ROW_SHIRT := 1
const ROW_BODY := 2
const ROW_PADDLE := 3
const ROWS := 4
const MAX := 4

## Back: B on an Xbox pad (the menus' convention), or X.
const BACK := GameControls.PAD_A | Practice.PAD_Y

const STAY := 0
const START := 1
const LEAVE := 2                 ## nobody joined and B: back to the title

var mode := K.MODE_DOUBLES
## One card per player number (index 0..3 = P1..P4), or null:
## {device, side, palette, variant, paddle, row, ready}
var cards: Array = [null, null, null, null]


func joined() -> Array:
	return cards.filter(func(c): return c != null)


func card_of(device: int) -> int:
	for i in MAX:
		if cards[i] != null and cards[i]["device"] == device:
			return i
	return -1


func per_side() -> int:
	return 1 if mode == K.MODE_SINGLES else 2


func side_count(side: int, except := -1) -> int:
	var n := 0
	for i in MAX:
		if i != except and cards[i] != null and cards[i]["side"] == side:
			n += 1
	return n


func _colour_taken(palette: int, except: int) -> bool:
	for i in MAX:
		if i != except and cards[i] != null and cards[i]["palette"] == palette:
			return true
	return false


func _free_colour(from: int, step: int, except: int) -> int:
	var c := from
	for t in PlayerSelect.PAL_COUNT:
		if not _colour_taken(c, except):
			return c
		c = (c + PlayerSelect.PAL_COUNT + step) % PlayerSelect.PAL_COUNT
	return from


## A pad joins: the first free number, the side with room (left first),
## a free shirt (starting from its number's colour). -1 if full.
func join(device: int) -> int:
	if card_of(device) >= 0:
		return card_of(device)
	var i := cards.find(null)
	if i < 0:
		return -1
	var side := LEFT if side_count(LEFT) < per_side() else RIGHT
	cards[i] = {"device": device, "side": side, "palette": _free_colour(i, 1, i),
		"variant": K.VARIANT_MALE, "paddle": Paddles.STANDARD, "row": ROW_SIDE, "ready": false}
	return i


func leave(i: int) -> void:
	cards[i] = null


## Switches singles and doubles. A side over the new limit sends its
## extra players across if there's room; otherwise the lobby waits
## (blocker) until someone leaves or changes side.
func set_mode(m: int) -> void:
	mode = m
	for side in [LEFT, RIGHT]:
		for i in range(MAX - 1, -1, -1):
			if side_count(side) <= per_side():
				break
			if cards[i] != null and cards[i]["side"] == side and side_count(1 - side) < per_side():
				cards[i]["side"] = 1 - side
				cards[i]["ready"] = false


func _change(i: int, dir: int) -> void:
	var c: Dictionary = cards[i]
	match c["row"]:
		ROW_SIDE:
			var to := 1 - int(c["side"])
			if side_count(to, i) < per_side():
				c["side"] = to
		ROW_SHIRT:
			c["palette"] = _free_colour((c["palette"] + dir + PlayerSelect.PAL_COUNT) % PlayerSelect.PAL_COUNT, dir, i)
		ROW_BODY:
			c["variant"] = K.VARIANT_FEMALE if c["variant"] == K.VARIANT_MALE else K.VARIANT_MALE
		ROW_PADDLE:
			c["paddle"] = (c["paddle"] + dir + Paddles.NAMES.size()) % Paddles.NAMES.size()


## Why the match can't start yet ("" when it can).
func blocker() -> String:
	var players := joined()
	if players.size() < 2:
		return "WAITING FOR PLAYERS"
	if mode == K.MODE_SINGLES and players.size() > 2:
		return "SINGLES IS TWO PLAYERS"
	if players.any(func(c): return not c["ready"]):
		return "WAITING FOR READY"
	if side_count(LEFT) == 0:
		return "SOMEONE TAKE THE LEFT SIDE"
	if mode == K.MODE_SINGLES and (side_count(LEFT) != 1 or side_count(RIGHT) != 1):
		return "SINGLES IS ONE ON EACH SIDE"
	if side_count(RIGHT) == 0:
		return "SOMEONE TAKE THE RIGHT SIDE"
	return ""


## One pad's presses this frame (SNES bits plus GameControls.PAD_L/R).
func input(device: int, pressed: int) -> int:
	if pressed == 0:
		return STAY
	var i := card_of(device)
	if i < 0:
		if pressed & Practice.PAD_B:
			join(device)
		elif pressed & BACK and joined().is_empty():
			return LEAVE
		return STAY
	var c: Dictionary = cards[i]
	if pressed & Practice.PAD_START and c["ready"]:
		return START if blocker() == "" else STAY
	if pressed & GameControls.PAD_L:
		set_mode(K.MODE_SINGLES)
		return STAY
	if pressed & GameControls.PAD_R:
		set_mode(K.MODE_DOUBLES)
		return STAY
	if pressed & BACK:
		if c["ready"]:
			c["ready"] = false
		else:
			leave(i)
		return STAY
	if c["ready"]:
		return STAY
	if pressed & (Practice.PAD_B | Practice.PAD_START):
		c["ready"] = true
		return STAY
	if pressed & Practice.PAD_UP:
		c["row"] = (c["row"] + ROWS - 1) % ROWS
	elif pressed & Practice.PAD_DOWN:
		c["row"] = (c["row"] + 1) % ROWS
	elif pressed & Practice.PAD_LEFT:
		_change(i, -1)
	elif pressed & Practice.PAD_RIGHT:
		_change(i, 1)
	return STAY


## The sim slots: the left side on 0 and 1, the right on 2 and 3, each in
## player-number order (singles: 0 and 2). [player index per slot or -1].
func slot_players() -> Array:
	var slots := [-1, -1, -1, -1]
	for side in [LEFT, RIGHT]:
		var base := 0 if side == LEFT else 2
		var n := 0
		for i in MAX:
			if cards[i] != null and cards[i]["side"] == side:
				slots[base + n] = i
				n += 1
	return slots


## The match: humans on their slots with their picks; in doubles CPUs fill
## the empty places (free colours, the standard paddle, the default
## bodies); singles leaves slots 1 and 3 off. No ladder team.
func match_config(difficulty: int, points: int, modifiers: int) -> SimTypes.MatchConfig:
	var cfg := SimTypes.MatchConfig.doubles() if mode == K.MODE_DOUBLES else SimTypes.MatchConfig.singles()
	var slots := slot_players()
	cfg.human = [0, 0, 0, 0]
	cfg.palette = [-1, -1, -1, -1]
	for s in K.MAX_PLAYERS:
		var i: int = slots[s]
		if i >= 0:
			cfg.human[s] = 1
			cfg.palette[s] = cards[i]["palette"]
			cfg.variant[s] = cards[i]["variant"]
			cfg.paddle[s] = cards[i]["paddle"]
	var colour := 0
	for s in K.MAX_PLAYERS:
		if cfg.human[s] or (mode == K.MODE_SINGLES and (s == 1 or s == 3)):
			continue
		while colour in cfg.palette:
			colour += 1
		cfg.palette[s] = colour
	cfg.difficulty = difficulty
	cfg.points_to_win = points
	cfg.modifiers = modifiers
	cfg.opponent = -1
	return cfg


## Each slot's pad (-1 for a CPU or an empty slot).
func slot_pads() -> Array:
	return slot_players().map(func(i): return cards[i]["device"] if i >= 0 else -1)
