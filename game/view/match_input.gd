## A match's input (split from MatchView in PORT-27): each human slot's
## intent (the keyboard and P1's pad, 2P's pad, or every pad in
## multiplayer), the input lock after a modal, SERVE ASSIST, a dropped pad
## pausing, and the pause menu.
class_name MatchInput
extends RefCounted

var v: MatchView


func _init(view: MatchView) -> void:
	v = view


## This frame's human intents for Sim.step (P1 on the input map, 2P on
## its pad, or every pad in multiplayer), or null when the pause menu took
## the frame. The demo has none.
func read() -> Variant:
	var human := []
	if not v.demo and v.multiplayer():
		human = multiplayer_intents()
		if human.is_empty():
			return null
	elif not v.demo:
		var it := GameControls.read_intent()
		var it2: SimTypes.Intent = GameControls.read_pad_intent(GameControls.p2_pad) if v.sim.config.human[2] else null
		# 2P partnering you in the park (ADR-034): slot 1, on their pad
		var it1: SimTypes.Intent = GameControls.read_pad_intent(GameControls.p2_pad) \
			if v.sim.config.human[1] and not v.sim.config.human[2] else null
		if v.input_lock > 0:
			v.input_lock -= 1
			it = SimTypes.Intent.new()
			it1 = null
			it2 = null
			GameControls.clear_latch()
		serve_assist(it)
		if pause_on_lost_pad():
			it.pause_pressed = 1
		human = [it, it1, it2, null]
		if v.sim.paused and pause_input(it):
			return null
	return human


## Every human slot's intent from its own pad. Any player's Menu pauses
## (the sim reads the pause on slot 0), and while paused any pad drives
## the pause menu. Empty when the pause menu took the frame.
func multiplayer_intents() -> Array:
	var human := [null, null, null, null]
	var menu := SimTypes.Intent.new()        # the pause menu: anyone's presses
	for s in K.MAX_PLAYERS:
		var dev: int = v.slot_pads[s] if s < v.slot_pads.size() else -1
		if dev < 0 or not v.sim.config.human[s]:
			continue
		var it := GameControls.read_pad_intent(dev)
		menu.hit_pressed |= it.hit_pressed
		menu.pause_pressed |= it.pause_pressed
		human[s] = it
	if v.input_lock > 0:
		v.input_lock -= 1
		for s in K.MAX_PLAYERS:
			if human[s] != null:
				human[s] = SimTypes.Intent.new()
		menu = SimTypes.Intent.new()
	if human[0] == null:
		human[0] = SimTypes.Intent.new()
	if pause_on_lost_pad():
		menu.pause_pressed = 1
	human[0].pause_pressed = menu.pause_pressed
	if v.sim.paused:
		menu.pause_pressed = human[0].pause_pressed
		if pause_input(menu):
			return []
		human[0].pause_pressed = menu.pause_pressed
	return human


## A controller dropping out mid-match pauses it (the pause menu waits
## for the player to come back), as most games do.
var _lost_seen := GameControls.lost_serial


func pause_on_lost_pad() -> bool:
	if GameControls.lost_serial == _lost_seen:
		return false
	_lost_seen = GameControls.lost_serial
	return not v.sim.paused and v.sim.phase != K.PHASE_MATCH_RESULT and not v.end.initials.open


## SERVE ASSIST (PORT-12, an input aid, not a rule change): while P1
## holds B on the charged serve, the press lets go by itself on the way up
## at a strong charge, so holding is enough for a good serve.
const SERVE_ASSIST_LEVEL := 24


func serve_assist(it: SimTypes.Intent) -> void:
	if not Settings.serve_assist or not it.hit_held or not v.sim.charge_charging:
		return
	var server: SimTypes.Player = v.sim.players[v.sim.server_index]
	if server.logical_input_slot == 0 and v.sim.charge_rising \
			and v.sim.charge_level >= SERVE_ASSIST_LEVEL:
		it.hit_held = 0


## The pause menu (ADR-030): RESUME, RESTART (not in practice), MAIN MENU.
func pause_rows() -> Array:
	var rows := [{"id": "resume", "label": "RESUME", "press": func(): pause_choice = "resume"}]
	if not v.sim.config.practice:
		rows.append({"id": "restart", "label": "RESTART", "press": func(): pause_choice = "restart"})
	rows.append({"id": "menu", "label": "PARK" if v.park and v.sim.config.practice else "MAIN MENU",
		"press": func(): pause_choice = "menu"})
	return rows


var pause_choice := ""


## One paused frame: Up/Down move, B picks (Start still resumes, in the
## sim). True when the frame is done (the sim doesn't step).
func pause_input(it: SimTypes.Intent) -> bool:
	var menu: MenuPage = v._hud.pause_menu
	if GameControls.menu_pressed("move_up"):
		menu.move(-1)
		v._sfx.play("blip")
	elif GameControls.menu_pressed("move_down"):
		menu.move(1)
		v._sfx.play("blip")
	if it.hit_pressed and not it.pause_pressed:
		menu.press()
	it.hit_pressed = 0              # a menu press is never a swing
	var choice := pause_choice      # set by a press: keys above, or a click
	pause_choice = ""
	match choice:
		"resume":
			v._sfx.play("back")
			it.pause_pressed = 1         # the sim unpauses on its own Start
		"restart":
			v._sfx.play("confirm")
			if v.save:
				v.save.drop_new_records()          # only a finished match asks
				v.save.career.new_unlocks = 0
			v.sim.new_match()
			v._prev_phase = -1
			v.input_lock = MatchView.INPUT_LOCK_FRAMES   # the closing press doesn't serve
			v.stats = MatchStats.new()
			v._hud.on_rematch()
			v._hud.on_new_match()
			v._update_visuals()
			return true
		"menu":
			v._sfx.play("back")
			if v.save:
				v.save.drop_new_records()
			if v.sim.config.practice:
				v.leave_practice()
			else:
				v.finished.emit(true)
			return true
	if it.pause_pressed and choice == "":
		v._sfx.play("back")
	return false
