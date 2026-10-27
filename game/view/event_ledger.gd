## A match's sim events on their way to the view, by the step that made
## them (port ADR-101). Rollback runs steps again: a guess of the other
## side's input is taken back (Sim.load_state) and the steps re-run with
## the real one. Their events come again, the same ones or others, so the
## view takes them in two ways:
##
## - **Played** (sound, sparks, dust, the crowd, quips): at once, and once.
##   A step run again plays only the events it didn't make the first time.
##   A sound already played for a guess that's then taken back stays played
##   (it can't be unplayed); that's the price of playing it on time.
## - **Counted** (stats, rally records, career points): only when the step
##   is confirmed (both sides' inputs known), with the events of its last
##   run and the view's context recorded with them, so a taken-back guess
##   is never counted.
##
## Offline and in lockstep every step is confirmed as it's run, so both
## come on the same frame, as before. Display only: nothing here writes to
## the sim. A step taken back must be run again before it's confirmed
## (rollback always re-runs up to the present).
class_name EventLedger
extends RefCounted

var confirmed := 0               ## steps up to this one are counted
var _steps := {}                 ## step -> [events, context, played], not confirmed yet


func _init(through := 0) -> void:
	confirmed = through


## A step's events as just run (for the first time, or again), with the
## view's context for counting them. Returns those to play: the ones not
## played for that step yet (an event a step makes twice plays twice).
func run(step: int, events: Array, context: Variant = null) -> Array:
	if step <= confirmed:
		push_error("EventLedger: step %d is confirmed already" % step)
		return []
	var played: Array = _steps[step][2] if _steps.has(step) else []
	var left := played.duplicate()
	var fresh := []
	for e in events:
		var i := left.find(e)
		if i >= 0:
			left.remove_at(i)
		else:
			fresh.append(e)
	played.append_array(fresh)
	if events.is_empty() and played.is_empty():
		_steps.erase(step)
	else:
		_steps[step] = [events, context, played]
	return fresh


## Steps up to `step` are final. Returns their events to count, oldest
## first, each as [event, context].
func confirm(step: int) -> Array:
	var out := []
	for s in range(confirmed + 1, step + 1):
		if _steps.has(s):
			var rec: Array = _steps[s]
			for e in rec[0]:
				out.append([e, rec[1]])
			_steps.erase(s)
	confirmed = maxi(confirmed, step)
	return out
