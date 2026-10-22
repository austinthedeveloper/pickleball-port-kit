## SPECIALS' meters (port ADR-080): a small bar under each
## player's feet, following them round the court, filling in their colour
## and flashing gold when full, with a prompt for the button under the
## side's score panel while a human's is. Reads the sim, never writes it.
class_name SpecialMeters
extends Node2D

const BAR_W := 40
const BAR_H := 4
const BELOW_FEET := 14           ## px from the feet to the bar's top, clear of the marker
const FULL_A := Color("fbe46a")
const FULL_B := Color.WHITE
const FRAME := Color("0b0f1e")

var view: MatchView
var panels: Array = []           ## [left, right] score panel rects
var prompts: Array = []          ## [left, right] PromptBars
var _frame := 0


func setup(v: MatchView, left: Rect2, right: Rect2) -> SpecialMeters:
	view = v
	panels = [left, right]
	for team in 2:
		var pb := PromptBar.new().setup([["rt" if v.multiplayer() else "special", "PICKLE SMASH"]],
			Vector2(panels[team].get_center().x, panels[team].end.y + 14))
		pb.visible = false
		add_child(pb)
		prompts.append(pb)
	return self


## A slot's bar on screen: centred under the feet as the view draws them
## (the camera's shift and a reach's lean included).
func bar(slot: int) -> Rect2:
	var root: Node2D = view._players[slot]["root"]
	var feet := root.position + view._actors.position
	return Rect2(feet.x - BAR_W / 2, feet.y + BELOW_FEET, BAR_W, BAR_H)


## Whether a slot's bar is up: an active player, before the result card.
func shown(slot: int) -> bool:
	return view.sim.players[slot].active != 0 and view.sim.phase != K.PHASE_MATCH_RESULT


func refresh() -> void:
	_frame += 1
	var s := view.sim
	for team in 2:
		var show := false
		for i in K.MAX_PLAYERS:
			var p: SimTypes.Player = s.players[i]
			if p.active and p.team == team and s.config.human[i] and s.special_ready(i):
				show = true
		prompts[team].visible = show and not view.demo and s.phase == K.PHASE_LIVE
	queue_redraw()


func _draw() -> void:
	var s := view.sim
	for slot in K.MAX_PLAYERS:
		if not shown(slot):
			continue
		var r := bar(slot)
		draw_rect(r.grow(1), FRAME)
		var f := float(s.meter[slot]) / K.SPECIAL_METER_MAX
		var c: Color = MatchView.TEAM_TINTS[s.config.palette[slot]]
		if s.special_ready(slot):
			c = FULL_A if (_frame / 8) % 2 == 0 else FULL_B
		draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * f), r.size.y)), c)
