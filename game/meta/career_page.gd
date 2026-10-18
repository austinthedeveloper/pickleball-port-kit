## The CAREER page's logic (ADR-047, career_page.c in its order): the
## title's RECORDS entry. Pure input logic, like the practice editor; the
## screen (view/career_screen.gd) draws it as MenuPages and the title
## writes the save on SAVE.
##
##   SLOTS   the three players, NO PLAYER, and RECORDS. B opens a player
##           (making them active), creates one in an empty slot, or on NO
##           PLAYER makes nobody active; Y leaves.
##   CARD    the player's stats and unlocks. B edits; delete_player()
##           deletes (the screen's DELETE row, pressed twice, for the
##           SNES's L+R+X); Y back.
##   EDIT    name and look. Up/Down rows, Left/Right values (locked hair and
##           hats are skipped); B on NAME types it, B elsewhere keeps, Y
##           puts the look back (and drops a player just created).
##           Typing is an arcade keyboard: the D-pad picks a key, B types
##           it, DEL or Y erases the last letter, END or Start is done; Y
##           with nothing to erase backs out (a new player is dropped, an
##           old one keeps their name).
##   RECORDS the old records table (the title's records page).
class_name CareerPage
extends RefCounted

const VIEW_SLOTS := 0
const VIEW_CARD := 1
const VIEW_EDIT := 2
const VIEW_RECORDS := 3

## SLOTS rows: a row per slot, NO PLAYER (nobody active: matches as
## before, no stats), then RECORDS.
const ROW_NOBODY := Career.SLOTS
const ROW_RECORDS := Career.SLOTS + 1
const SLOT_ROWS := Career.SLOTS + 2

## EDIT rows.
const EDIT_NAME := 0
const EDIT_BODY := 1
const EDIT_SKIN := 2
const EDIT_HAIR := 3
const EDIT_SHIRT := 4
const EDIT_HAT := 5
const EDIT_PADDLE := 6
const EDIT_ROWS := 7

## input() results.
const STAY := 0
const CLOSE := 1                 ## back to the title menu
const SAVE := 2                  ## stay; write the save

## The name keyboard: rows of KEY_COLS letters ("A".."Z", space, "-"),
## then DEL and END on a row of their own.
const KEY_CHARS := 28
const KEY_COLS := 10
const KEY_ROWS := 4              ## three of letters, one of DEL and END
const KEY_DEL := 28
const KEY_END := 29
const KEYS := 30
const KEY_LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ -"

const PAD_B := Practice.PAD_B
const PAD_Y := Practice.PAD_Y
const PAD_START := Practice.PAD_START
const PAD_UP := Practice.PAD_UP
const PAD_DOWN := Practice.PAD_DOWN
const PAD_LEFT := Practice.PAD_LEFT
const PAD_RIGHT := Practice.PAD_RIGHT
const PAD_A := GameControls.PAD_A

var career: Career
var view := VIEW_SLOTS
var row := 0
var slot := 0                    ## the player on the CARD and EDIT views
var naming := false              ## typing the name
var cursor := 0                  ## letters typed (the next goes here)
var creating := false            ## a new player: Y drops them
var key_row := 0                 ## the keyboard key picked
var key_col := 0
var look_changed := false        ## the look changed: the screen re-previews
var original: Career.Player      ## the player when EDIT opened


func _player() -> Career.Player:
	return career.players[slot]


## A look row's value on the player (EDIT rows BODY to PADDLE).
static func look_value(player: Career.Player, look_row: int) -> int:
	match look_row:
		EDIT_BODY:
			return player.variant
		EDIT_SKIN:
			return player.skin
		EDIT_HAIR:
			return player.hair
		EDIT_SHIRT:
			return player.shirt
		EDIT_HAT:
			return player.hat
		EDIT_PADDLE:
			return player.paddle
	return 0


## Opens on SLOTS, the cursor on the active player (else NO PLAYER).
func begin(c: Career) -> void:
	career = c
	view = VIEW_SLOTS
	row = career.active if career.active >= 0 and career.active < Career.SLOTS else ROW_NOBODY
	slot = 0
	naming = false
	cursor = 0
	creating = false
	_key_pick(0, 0)
	look_changed = false


## Up/Down through count rows, wrapping.
static func _page_row(r: int, count: int, pressed: int) -> int:
	if pressed & PAD_UP:
		return r - 1 if r else count - 1
	if pressed & PAD_DOWN:
		return 0 if r + 1 >= count else r + 1
	return r


## Left/Right through count values, wrapping.
static func _page_step(value: int, count: int, pressed: int) -> int:
	if pressed & PAD_LEFT:
		return value - 1 if value else count - 1
	return 0 if value + 1 >= count else value + 1


func _open_edit(is_new: bool) -> void:
	view = VIEW_EDIT
	row = EDIT_NAME
	creating = is_new
	naming = false
	original = _player().copy()
	if is_new:
		_start_naming(_player())
	look_changed = true


func _slots(pressed: int) -> int:
	if pressed & PAD_Y:
		return CLOSE
	if pressed & (PAD_B | PAD_START):
		if row == ROW_RECORDS:
			view = VIEW_RECORDS
			return STAY
		if row == ROW_NOBODY:
			career.select(Career.NONE)
			return SAVE
		slot = row
		if career.players[row].used:
			career.select(row)
			view = VIEW_CARD
			return SAVE
		# A new player: named first, from a blank name.
		career.create(row, "")
		_open_edit(true)
		return STAY
	row = _page_row(row, SLOT_ROWS, pressed)
	return STAY


func _card(pressed: int) -> int:
	if pressed & PAD_Y:
		view = VIEW_SLOTS
		row = slot
		return STAY
	if pressed & (PAD_B | PAD_START):
		_open_edit(false)
	return STAY


## The card's delete (L+R+X on the SNES): the slot empties, back to SLOTS.
func delete_player() -> int:
	if view != VIEW_CARD:
		return STAY
	career.delete(slot)
	view = VIEW_SLOTS
	row = slot
	return SAVE


func _records(pressed: int) -> int:
	if pressed & (PAD_B | PAD_Y | PAD_START):
		view = VIEW_SLOTS
		row = ROW_RECORDS
	return STAY


## Keys on a keyboard row.
static func _key_row_count(r: int) -> int:
	if r == KEY_ROWS - 1:
		return 2
	if r == 2:
		return KEY_CHARS - 2 * KEY_COLS
	return KEY_COLS


## The keyboard key picked: 0..KEY_CHARS-1 a letter, else DEL or END.
func key() -> int:
	if key_row == KEY_ROWS - 1:
		return KEY_DEL + key_col
	return key_row * KEY_COLS + key_col


func _key_pick(r: int, c: int) -> void:
	key_row = r
	key_col = c


## The D-pad on the keyboard: rows and columns wrap; DEL sits under the
## left half, END under the right.
func _key_move(pressed: int) -> void:
	var r := key_row
	var c := key_col
	if pressed & (PAD_LEFT | PAD_RIGHT):
		key_col = _page_step(c, _key_row_count(r), pressed)
		return
	if not (pressed & (PAD_UP | PAD_DOWN)):
		return
	if r == KEY_ROWS - 1:
		c = 7 if c else 2
	r = _page_row(r, KEY_ROWS, pressed)
	if r == KEY_ROWS - 1:
		c = 0 if c < KEY_COLS / 2 else 1
	else:
		var count := _key_row_count(r)
		if c >= count:
			c = count - 1
	_key_pick(r, c)


## Picks a key directly (the mouse on the keyboard).
func pick_key(k: int) -> void:
	if k >= KEY_DEL:
		_key_pick(KEY_ROWS - 1, k - KEY_DEL)
	else:
		_key_pick(k / KEY_COLS, k % KEY_COLS)


func _start_naming(player: Career.Player) -> void:
	var length := 0
	for i in Career.NAME:
		if player.name[i] != " ":
			length = i + 1
	naming = true
	cursor = length
	if length == Career.NAME:
		_key_pick(KEY_ROWS - 1, 1)       # END
	else:
		_key_pick(0, 0)


static func _set_letter(player: Career.Player, at: int, ch: String) -> void:
	player.name = player.name.substr(0, at) + ch + player.name.substr(at + 1)


func _naming(player: Career.Player, pressed: int) -> int:
	var k := 0
	if pressed & PAD_Y:
		# Nothing left to erase: Y backs out. A new player is dropped; an
		# old one gets their name back.
		if cursor == 0:
			naming = false
			look_changed = true
			if creating:
				career.delete(slot)
				creating = false
				view = VIEW_SLOTS
				row = slot
				return STAY
			player.name = original.name
			return STAY
		k = KEY_DEL
	elif pressed & PAD_START:
		k = KEY_END
	elif pressed & (PAD_B | PAD_A):
		k = key()
	else:
		_key_move(pressed)
		return STAY
	look_changed = true
	if k == KEY_DEL:
		if cursor:
			cursor -= 1
			_set_letter(player, cursor, " ")
	elif k == KEY_END:
		# A name needs a letter.
		if cursor:
			naming = false
			if creating:
				row = EDIT_BODY
	elif cursor < Career.NAME:
		_set_letter(player, cursor, KEY_LETTERS[k])
		cursor += 1
		if cursor == Career.NAME:
			_key_pick(KEY_ROWS - 1, 1)   # full: END
	return STAY


## Left/Right on a look row; hair and hats skip what is locked.
func _change(player: Career.Player, look_row: int, pressed: int) -> void:
	match look_row:
		EDIT_BODY:
			player.variant = _page_step(player.variant, 2, pressed)
		EDIT_SKIN:
			player.skin = _page_step(player.skin, Career.skins(), pressed)
		EDIT_HAIR:
			var tries := Career.hairs()
			while true:
				player.hair = _page_step(player.hair, Career.hairs(), pressed)
				tries -= 1
				if Career.hair_unlocked(player, player.hair) or tries == 0:
					break
		EDIT_SHIRT:
			player.shirt = _page_step(player.shirt, PlayerSelect.PAL_COUNT, pressed)
		EDIT_HAT:
			var tries := Career.hats()
			while true:
				player.hat = _page_step(player.hat, Career.hats(), pressed)
				tries -= 1
				if Career.hat_unlocked(player, player.hat) or tries == 0:
					break
		EDIT_PADDLE:
			player.paddle = _page_step(player.paddle, Paddles.NAMES.size(), pressed)
		_:
			return
	look_changed = true


func _edit(pressed: int) -> int:
	var player := _player()
	var r := row
	if naming:
		return _naming(player, pressed)
	if pressed & PAD_Y:
		look_changed = true
		if creating:
			career.delete(slot)
			view = VIEW_SLOTS
			row = slot
			creating = false
			return STAY
		player.assign(original)
		view = VIEW_CARD
		return STAY
	if pressed & (PAD_B | PAD_START):
		if r == EDIT_NAME and (pressed & PAD_B):
			_start_naming(player)
			return STAY
		# No name yet: type one first.
		if player.name[0] == " ":
			row = EDIT_NAME
			_start_naming(player)
			return STAY
		creating = false
		view = VIEW_CARD
		return SAVE
	if pressed & (PAD_LEFT | PAD_RIGHT):
		_change(player, r, pressed)
		return STAY
	row = _page_row(r, EDIT_ROWS, pressed)
	return STAY


## One frame of input: newly pressed buttons (Practice.PAD_* bits).
func input(pressed: int) -> int:
	if pressed == 0:
		return STAY
	match view:
		VIEW_CARD:
			return _card(pressed)
		VIEW_EDIT:
			return _edit(pressed)
		VIEW_RECORDS:
			return _records(pressed)
	return _slots(pressed)
