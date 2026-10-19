## The HAT MUSEUM (SNES ADR-061, museum.c in its order): a career
## player's hats in display cases, the player wearing each one. Locked
## hats show as a dark silhouette named "???", with how to earn them under
## the cursor. Opened from the player's card on the CAREER page. Pure
## input logic; view/hat_museum.gd draws it and the title writes the save.
##
##   D-pad  moves through the cases (rows of COLS, wrapping)
##   B      wears an unlocked hat
##   Y      back to the card (Start too); the save is written then if a
##          hat was put on
##
## The cases hold every hat but the bare head (Career.hat_none()), in hat
## id order: the cap first.
class_name Museum
extends RefCounted

const COLS := 4

## input() results.
const STAY := 0
const CLOSE := 1                 ## back to the CAREER page's card
const CLOSE_SAVE := 2            ## the same; a hat was put on: write

var career: Career
var slot := 0                    ## the career player shown
var cursor := 0                  ## the case picked, 0..hats()-1
var changed := false             ## the cursor or the worn hat moved
var worn := false                ## a hat was put on since opening


static func hats() -> int:
	return Career.hats() - 1


static func rows() -> int:
	return (hats() + COLS - 1) / COLS


## The bare head has no case: the cases skip its id.
static func hat(index: int) -> int:
	return index if index < Career.hat_none() else index + 1


func player() -> Career.Player:
	return career.players[slot]


func unlocked(index: int) -> bool:
	return Career.hat_unlocked(player(), hat(index))


func unlocked_count() -> int:
	var count := 0
	for i in hats():
		count += 1 if unlocked(i) else 0
	return count


## Opens on a slot's player, the cursor on the hat they wear (the cap when
## bareheaded).
func begin(c: Career, s: int) -> void:
	career = c
	slot = s
	var h := player().hat
	var none := Career.hat_none()
	if h == none or h >= Career.hats():
		cursor = 0
	else:
		cursor = h if h < none else h - 1
	changed = true
	worn = false


## The D-pad over the grid: Left/Right along a row, Up/Down along a
## column, both wrapping; a short last row is skipped going down into it
## past its end, and entered at its end going up.
static func _move(at: int, pressed: int) -> int:
	var row := at / COLS
	var col := at % COLS
	var last := hats() - 1
	if pressed & Practice.PAD_LEFT:
		return at - 1 if at > 0 else last
	if pressed & Practice.PAD_RIGHT:
		return at + 1 if at < last else 0
	if pressed & Practice.PAD_UP:
		if row:
			return at - COLS
		at = (rows() - 1) * COLS + col
		return at - COLS if at > last else at
	if pressed & Practice.PAD_DOWN:
		at += COLS
		return col if at > last else at
	return at


## One frame of input: newly pressed buttons (Practice.PAD_*).
func input(pressed: int) -> int:
	if pressed & (Practice.PAD_Y | Practice.PAD_START):
		return CLOSE_SAVE if worn else CLOSE
	if pressed & Practice.PAD_B:
		if unlocked(cursor) and player().hat != hat(cursor):
			player().hat = hat(cursor)
			changed = true
			worn = true
		return STAY
	var moved := _move(cursor, pressed)
	if moved != cursor:
		cursor = moved
		changed = true
	return STAY
