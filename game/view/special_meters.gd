## SPECIALS' meters on the HUD (port ADR-080): a bar for each player under
## their side's score panel, filling in their team's colour and flashing
## gold when full, with a prompt for the button while a human's is. Reads
## the sim, never writes it.
class_name SpecialMeters
extends Node2D

const BAR_H := 6
const GAP := 2
const INSET := 8
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
			Vector2(panels[team].get_center().x, _bars_bottom(team) + 14))
		pb.visible = false
		add_child(pb)
		prompts.append(pb)
	return self


## The team's active slots, in order.
func slots_of(team: int) -> Array:
	var out := []
	for i in K.MAX_PLAYERS:
		var p: SimTypes.Player = view.sim.players[i]
		if p.active and p.team == team:
			out.append(i)
	return out


func _bar(team: int, k: int) -> Rect2:
	var r: Rect2 = panels[team]
	return Rect2(r.position.x + INSET, r.end.y + 3 + k * (BAR_H + GAP), r.size.x - INSET * 2, BAR_H)


func _bars_bottom(team: int) -> float:
	return _bar(team, maxi(slots_of(team).size(), 1) - 1).end.y


func refresh() -> void:
	_frame += 1
	var s := view.sim
	for team in 2:
		var show := false
		for slot in slots_of(team):
			if s.config.human[slot] and s.special_ready(slot):
				show = true
		prompts[team].visible = show and not view.demo and s.phase == K.PHASE_LIVE
	queue_redraw()


func _draw() -> void:
	var s := view.sim
	for team in 2:
		var slots := slots_of(team)
		for k in slots.size():
			var slot: int = slots[k]
			var r := _bar(team, k)
			draw_rect(r.grow(1), FRAME)
			var f := float(s.meter[slot]) / K.SPECIAL_METER_MAX
			var c: Color = MatchView.TEAM_TINTS[s.config.palette[slot]]
			if s.special_ready(slot):
				c = FULL_A if (_frame / 8) % 2 == 0 else FULL_B
			draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * f), r.size.y)), c)
