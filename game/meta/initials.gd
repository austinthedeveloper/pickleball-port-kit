## The initials card (ADR-040), story.c's story_update_initials: three
## letters for every record a finished match beat. Up/Down change the
## letter (A-Z around; held, they repeat after 16 frames, then every 4);
## B, A or Right moves on and past the third saves; Y or Left goes back;
## Start saves at once. Nothing but Up/Down counts for the first 30
## frames (mashing B out of the last point can't enter AAA); after 30
## seconds the letters shown are saved. Pure: pad bits in.
class_name Initials
extends RefCounted

const MIN_FRAMES := 30
const FRAMES := 1800
const REPEAT_DELAY := 16
const REPEAT_FRAMES := 4

const PAD_B := Practice.PAD_B
const PAD_Y := Practice.PAD_Y
const PAD_START := Practice.PAD_START
const PAD_UP := Practice.PAD_UP
const PAD_DOWN := Practice.PAD_DOWN
const PAD_LEFT := Practice.PAD_LEFT
const PAD_RIGHT := Practice.PAD_RIGHT
const PAD_A := 0x0080            ## the SNES pad bit (the practice editor has no A)

## The initials entered last this session: the next card starts there.
static var last := "AAA"

var save: SaveGame
var letters: Array = []          ## three ints, "A".."Z" as 0..25
var cursor := 0
var timer := 0
var held_frames := 0
var open := false
var beaten := 0                  ## SaveGame.NEW_* bits this card names


## Opens the card if the match beat a record (never in the demo: the
## caller doesn't ask there). False if there's nothing to name.
func begin(s: SaveGame) -> bool:
	save = s
	if s == null or s.new_records == 0:
		return false
	beaten = s.new_records
	open = true
	timer = 0
	cursor = 0
	held_frames = 0
	letters = []
	for ch in last:
		letters.append(ch.unicode_at(0) - 65)
	return true


func text() -> String:
	var out := ""
	for l in letters:
		out += String.chr(65 + l)
	return out


func _letter(step: int) -> void:
	letters[cursor] = (letters[cursor] + step + 26) % 26


func _save() -> void:
	last = text()
	save.set_initials(last)
	open = false


## One frame: newly pressed and held pad bits. True while the card stays.
func update(pressed: int, held: int) -> bool:
	if not open:
		return false
	var vertical := held & (PAD_UP | PAD_DOWN)
	timer += 1
	if timer >= FRAMES:
		_save()
		return false
	if pressed & (PAD_UP | PAD_DOWN):
		_letter(1 if pressed & PAD_UP else -1)
		held_frames = 0
	elif vertical:
		held_frames += 1
		if held_frames >= REPEAT_DELAY:
			held_frames -= REPEAT_FRAMES
			_letter(1 if vertical & PAD_UP else -1)
	else:
		held_frames = 0
	if timer < MIN_FRAMES:
		return true
	if pressed & PAD_START:
		_save()
		return false
	if pressed & (PAD_B | PAD_A | PAD_RIGHT):
		if cursor == 2:
			_save()
			return false
		cursor += 1
	elif (pressed & (PAD_Y | PAD_LEFT)) and cursor > 0:
		cursor -= 1
	return true


## The records beaten, as the card's line (story.c).
func records_line() -> String:
	var r: Dictionary = save.data["records"]
	if beaten == SaveGame.NEW_STREAK | SaveGame.NEW_RALLY:
		return "STREAK %d  RALLY %d" % [int(r["best_streak"]), int(r["longest_rally"])]
	if beaten & SaveGame.NEW_STREAK:
		return "BEST STREAK %d" % int(r["best_streak"])
	return "LONGEST RALLY %d" % int(r["longest_rally"])
