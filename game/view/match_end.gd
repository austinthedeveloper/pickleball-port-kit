## A match's end (split from MatchView in PORT-27): the records, the
## ladder, the tournament's bracket and the career written at the result;
## the initials card (ADR-040) and the UNLOCKED! card (ADR-047) after it.
class_name MatchEnd
extends RefCounted

var v: MatchView


func _init(view: MatchView) -> void:
	v = view
var cup_finish := ""            ## set when this match ended your tournament


## The initials card (ADR-040): the match waits under it like the intro card.
var initials := Initials.new()


func update_initials() -> void:
	var bits := GameControls.pad_bits()
	if not initials.update(bits[0], bits[1]):
		v.save.save_game()
		v.input_lock = MatchView.INPUT_LOCK_FRAMES      # the closing press doesn't rematch
		GameControls.clear_latch()
		v._sfx.play("confirm")
	elif bits[0]:
		v._sfx.play("blip")


## The UNLOCKED! card (ADR-047, story.c's STORY_CARD_UNLOCK): after the
## initials card, the career unlocks the match just earned; B, A or Start
## closes it after UNLOCK_MIN_FRAMES, or it goes by itself.
const UNLOCK_MIN_FRAMES := 30
const UNLOCK_FRAMES := 300
var unlock_frames := -1


func unlock_open() -> bool:
	return unlock_frames >= 0 and not initials.open


func update_unlock() -> void:
	unlock_frames += 1
	var pressed: int = GameControls.pad_bits()[0]
	if unlock_frames >= UNLOCK_FRAMES or (unlock_frames >= UNLOCK_MIN_FRAMES
			and pressed & (Practice.PAD_B | GameControls.PAD_A | Practice.PAD_START)):
		unlock_frames = -1
		if v.save:
			v.save.career.new_unlocks = 0
		v.input_lock = MatchView.INPUT_LOCK_FRAMES      # the closing press doesn't rematch
		GameControls.clear_latch()
		v._sfx.play("confirm")


## A career match (ADR-047): 1P's points and the result count for the
## active career player against the CPU, outside the demo, practice and
## multiplayer (as the records).
func career_counts() -> bool:
	return v.save != null and not v.demo and not v.multiplayer() and not v.sim.config.human[2] \
		and not v.sim.config.practice


## Records at the match's end (a safe point to write, playbook §6), and the
## ladder (ADR-023): a win moves to the next rung; beating the last clears.
## A record beaten (the rally, in 2P too) asks for initials (ADR-040).
func on_match_over() -> void:
	if v.demo or v.save == null:
		return
	var won := v.sim.match_winner == 0
	if v.multiplayer():
		if v.tournament:
			record_tournament(won)         # PORT-29: the couch cup's bracket
		v.save.drop_new_records()          # friends' matches don't touch the records
		v.save.save_game()
		return
	if not v.sim.config.human[2]:
		# ADR-047: before record_match, whose write keeps both.
		if career_counts():
			v.save.career.record_match(v.sim.config.mode, won, v.sim.team_score[1],
				v.sim.config.opponent, v.sim.config.open_play != 0)
		v.save.record_match(v.sim.config.mode == K.MODE_DOUBLES, won, v.sim.config.opponent,
			v.sim.team_score[1] if won else -1)
		if v.ladder and won:
			v.cleared = v.save.advance_ladder(Opponents.count())
		if v.tournament:
			record_tournament(won)
		v.save.record_stats(v.stats)
	v.save.save_game()
	initials.begin(v.save)
	# then what the career player unlocked (after the initials, if any)
	if v.save.career.new_unlocks:
		unlock_frames = 0


## PORT-25: the bracket takes this result (and decides the round's other
## matches); a tournament over for you goes in the records.
func record_tournament(won: bool) -> void:
	var t := v.save.tournament(v.cup_key)
	if t == null or t.next_match().is_empty():
		return
	t.record_left(won, v.sim.team_score[0], v.sim.team_score[1])
	v.save.store_tournament(t, v.cup_key)
	if t.couch():
		return                             # friends' cups don't go in the records
	cup_finish = t.finish()
	v.save.record_cup(cup_finish)