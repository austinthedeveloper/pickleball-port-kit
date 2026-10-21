## Menu rows for the settings shown in more than one place: the sliders on
## MODIFIERS and MATCH SETUP are the tuning panel's too (ADR-071 to 074).
## One definition each, so a range or a step changes once.
class_name SettingRows
extends RefCounted

const LABELS := {"ball_speed": "BALL SPEED", "ball_size": "BALL SIZE", "cpu_errors": "CPU ERRORS"}


## A slider's row ("78%"): Left/Right nudge it (Settings.SLIDERS); `after`
## runs once it has moved (the tuning panel's live changes).
static func slider(id: String, after: Callable = Callable()) -> Dictionary:
	return {"id": id, "label": LABELS[id], "value": func(): return "%d%%" % Settings.slider(id),
		"change": func(d):
			Settings.nudge(id, d)
			if after.is_valid():
				after.call()}
