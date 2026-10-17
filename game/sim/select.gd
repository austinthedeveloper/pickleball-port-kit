## Player Select logic (ADR-020), select.c in its order. Pure: the screen
## is view/select_screen.gd. Three rows: MALE/FEMALE, colour, paddle.
## Up/Down rows, Left/Right values; B steps to the next row and confirms
## on the paddle row; Start confirms at once; Y steps back (to 1P from
## 2P's top row, out to the title from 1P's).
class_name PlayerSelect
extends RefCounted

const ROW_VARIANT := 0
const ROW_COLOUR := 1
const ROW_PADDLE := 2
const ROWS := 3

const STAY := 0
const DONE := 1                  ## every human confirmed: start the match
const BACK := 2                  ## 1P backed out: return to the title

const PAL_BLUE := 0
const PAL_RED := 1
const PAL_GREEN := 2
const PAL_GOLD := 3
const PAL_COUNT := 4
const COLOUR_NAMES := ["BLUE", "RED", "GREEN", "GOLD"]
const PADDLE_NAMES := ["WOOD", "BLUE", "RED", "GOLD"]

## Pad bits, as the practice editor's (SNES order).
const PAD_B := Practice.PAD_B
const PAD_Y := Practice.PAD_Y
const PAD_START := Practice.PAD_START
const PAD_UP := Practice.PAD_UP
const PAD_DOWN := Practice.PAD_DOWN
const PAD_LEFT := Practice.PAD_LEFT
const PAD_RIGHT := Practice.PAD_RIGHT

var mode := K.MODE_SINGLES
var humans := 1
var current := 0                 ## 0 while 1P chooses, 1 for 2P
var row := ROW_VARIANT
var changed := false
## Per human: {palette, variant, paddle}.
var choice: Array = []


static func new_choice(palette: int, variant: int, paddle: int) -> Dictionary:
	return {"palette": palette, "variant": variant, "paddle": paddle}


## Opens the screen for 1P (blue, male, standard paddle, or `p1` if given:
## the last choice); 2P starts red, moved off 1P's colour when it begins.
func begin(match_mode: int, human_count: int, p1: Dictionary = {}) -> void:
	mode = match_mode
	humans = 2 if human_count == 2 else 1
	current = 0
	row = ROW_VARIANT
	choice = [new_choice(PAL_BLUE, K.VARIANT_MALE, Paddles.STANDARD),
		new_choice(PAL_RED, K.VARIANT_MALE, Paddles.STANDARD)]
	if not p1.is_empty():
		choice[0] = p1.duplicate()
	changed = true


func current_choice() -> Dictionary:
	return choice[current]


## True when the colour belongs to 1P while 2P is choosing.
func colour_taken(palette: int) -> bool:
	return current == 1 and choice[0]["palette"] == palette


## Next colour in direction step (+1/-1, wrapping) that isn't taken.
func _step_colour(from: int, step: int) -> int:
	var colour := from
	for tries in PAL_COUNT:
		colour = (colour + PAL_COUNT + step) % PAL_COUNT
		if not colour_taken(colour):
			return colour
	return from


func _change_value(step: int) -> void:
	var c: Dictionary = current_choice()
	if row == ROW_VARIANT:
		c["variant"] = K.VARIANT_FEMALE if step > 0 else K.VARIANT_MALE
	elif row == ROW_COLOUR:
		c["palette"] = _step_colour(c["palette"], step)
	else:
		c["paddle"] = (c["paddle"] + Paddles.NAMES.size() + step) % Paddles.NAMES.size()


## One frame of the current human's newly pressed buttons (PAD_* bits).
func input(pressed: int) -> int:
	if pressed == 0:
		return STAY
	changed = true
	if (pressed & PAD_B) and row < ROWS - 1:
		row += 1
		return STAY
	if pressed & (PAD_B | PAD_START):
		if current == 0 and humans == 2:
			current = 1
			row = ROW_VARIANT
			if colour_taken(choice[1]["palette"]):
				choice[1]["palette"] = _step_colour(choice[1]["palette"], 1)
			return STAY
		return DONE
	if pressed & PAD_Y:
		if row > 0:
			row -= 1
			return STAY
		if current == 1:
			current = 0
			row = ROW_PADDLE
			return STAY
		return BACK
	if (pressed & PAD_UP) and row > 0:
		row -= 1
	elif (pressed & PAD_DOWN) and row < ROWS - 1:
		row += 1
	elif pressed & PAD_LEFT:
		_change_value(-1)
	elif pressed & PAD_RIGHT:
		_change_value(1)
	return STAY


## The confirmed choices as a match config (match_config_select): 1P on
## slot 0, 2P on slot 2; CPUs take the unused colours in order, the
## standard paddle, and the fixed variants (slots 1 and 3 female).
static func config_select(match_mode: int, p1: Dictionary, p2: Dictionary = {}) -> SimTypes.MatchConfig:
	var cfg := SimTypes.MatchConfig.doubles() if match_mode == K.MODE_DOUBLES \
		else SimTypes.MatchConfig.singles()
	cfg.palette = [-1, -1, -1, -1]
	cfg.human = [0, 0, 0, 0]
	_apply(cfg, 0, p1)
	if not p2.is_empty():
		_apply(cfg, 2, p2)
	var colour := 0
	for slot in range(1, K.MAX_PLAYERS):
		if cfg.human[slot]:
			continue
		if match_mode == K.MODE_SINGLES and slot != 2:
			continue
		while colour in cfg.palette:
			colour += 1
		cfg.palette[slot] = colour
	return cfg


static func _apply(cfg: SimTypes.MatchConfig, slot: int, c: Dictionary) -> void:
	cfg.palette[slot] = c["palette"]
	cfg.variant[slot] = c["variant"]
	cfg.paddle[slot] = c["paddle"]
	cfg.human[slot] = 1


## ADR-010: no two active slots share a colour.
static func palettes_unique(cfg: SimTypes.MatchConfig) -> bool:
	var seen := []
	for p in cfg.palette:
		if p < 0:
			continue
		if p in seen:
			return false
		seen.append(p)
	return true
