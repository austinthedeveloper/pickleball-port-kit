## HOW TO PLAY (PORT-30): six short lessons, each a real sim with one goal,
## watched through its events. Display-free and pure like the rest of
## meta/: MatchView feeds it each frame's events (observe) and draws its
## card and banner (view/tutorial_view.gd).
##
##   RALLY        the ball machine feeds at you: return 3
##   SHOTS        land one DRIVE and one SOFT return
##   SMASH        the machine lobs: smash 1 back in
##   SERVE        against a KID CPU: 2 serves in
##   TWO BOUNCES  2 rallies past the two-bounce rule
##   THE KITCHEN  2 volleys from behind the kitchen line (ADR-055)
##
## Lesson text never names a button (CLAUDE.md): each lesson's prompts are
## [action, label] pairs for a PromptBar.
class_name Tutorial
extends RefCounted

const LESSONS := [
	{"id": "rally", "title": "RALLY", "goal": 3, "count": "RETURNS",
		"lines": ["THE MACHINE FEEDS THE BALL AT YOU.", "MOVE TO IT AND SWING: GET IT BACK",
			"OVER THE NET AND IN, THREE TIMES."],
		"prompts": [["dpad", "MOVE"], ["hit", "HIT"]],
		"drill": [Practice.SHOT_DRIVE, Practice.TARGET_AT_YOU, Practice.RATE_SLOW]},
	{"id": "shots", "title": "SHOTS", "goal": 2, "count": "SHOTS",
		"lines": ["DRIVE IS FAST AND FLAT. SOFT LOBS IT,", "OR DINKS IT SHORT IF YOU HOLD AWAY",
			"FROM THE NET. LAND ONE OF EACH."],
		"prompts": [["drive", "DRIVE"], ["soft", "SOFT"]],
		"drill": [Practice.SHOT_DRIVE, Practice.TARGET_AT_YOU, Practice.RATE_SLOW]},
	{"id": "smash", "title": "SMASH", "goal": 1, "count": "SMASH",
		"lines": ["A HIGH BALL ON ITS WAY DOWN IS YOURS.", "STAND A STEP IN FRONT OF THE LOB AND",
			"SWING EARLY, AS IT DROPS. SMASH ONE IN."],
		"prompts": [["dpad", "MOVE"], ["hit", "HIT"], ["drive", "DRIVE"]],
		"drill": [Practice.SHOT_LOB, Practice.TARGET_AT_YOU, Practice.RATE_SLOW]},
	{"id": "serve", "title": "SERVE", "goal": 2, "count": "SERVES IN",
		"lines": ["SERVE CORNER TO CORNER, PAST THE", "KITCHEN. TAP TO SERVE, OR HOLD AND",
			"LET GO ON THE WAY UP FOR PACE."],
		"prompts": [["hit", "SERVE"], ["dpad", "AIM"]], "match": true},
	{"id": "bounces", "title": "TWO BOUNCES", "goal": 2, "count": "RALLIES",
		"lines": ["THE SERVE MUST BOUNCE, AND SO MUST", "THE RETURN. AFTER THAT YOU MAY",
			"VOLLEY. PLAY TWO RALLIES PAST IT."],
		"prompts": [["dpad", "MOVE"], ["hit", "HIT"]], "match": true},
	{"id": "kitchen", "title": "THE KITCHEN", "goal": 2, "count": "VOLLEYS",
		"lines": ["STAND IN THE KITCHEN IF YOU LIKE, BUT", "NEVER VOLLEY FROM IT. COME UP TO THE",
			"LINE AND VOLLEY TWO FROM BEHIND IT."],
		"prompts": [["dpad", "MOVE"], ["hit", "HIT"]], "match": true},
]
const MESSAGE_FRAMES := 150

var index := 0
var progress := 0
var done := false
var message := ""                 ## feedback after a miss, shown a while
var message_frames := 0
var _streak := 0                  ## the machine's streak last frame
var _last_shot := -1              ## P1's last swing's shot (practice lessons)
var _shots_landed := {}           ## SHOTS: the shot types landed
var _serving := false             ## SERVE: P1's serve in the air
var _rally_counted := false       ## TWO BOUNCES: this rally already counted


func _init(lesson := 0) -> void:
	index = clampi(lesson, 0, LESSONS.size() - 1)


func lesson() -> Dictionary:
	return LESSONS[index]


func is_match() -> bool:
	return lesson().get("match", false)


## The lesson's sim: the ball machine with its drill, or singles against a
## KID CPU to 21 (it restarts if it ends first). You play in your last
## Player Select choice.
func config(p1: Dictionary) -> SimTypes.MatchConfig:
	if is_match():
		var cfg := Settings.config_for(false, -1, K.DIFFICULTY_KID, 21, p1)
		return cfg
	var d: Array = lesson()["drill"]
	var cfg2 := SimTypes.MatchConfig.practice_session([d[0], d[1], d[2], Practice.ZONE_ANY], 0)
	if not p1.is_empty():
		cfg2.palette[0] = p1["palette"]
		cfg2.variant[0] = p1["variant"]
		cfg2.paddle[0] = p1["paddle"]
	return cfg2


## "RETURNS 2/3".
func progress_text() -> String:
	return "%s %d/%d" % [lesson()["count"], mini(progress, lesson()["goal"]), lesson()["goal"]]


func _say(text: String) -> void:
	message = text
	message_frames = MESSAGE_FRAMES


func _gain() -> void:
	progress += 1
	if progress >= int(lesson()["goal"]):
		done = true


## One frame: the sim after its step, and the events it gave.
func observe(sim: Sim, events: Array) -> void:
	if message_frames > 0:
		message_frames -= 1
		if message_frames == 0:
			message = ""
	if done:
		return
	var id: String = lesson()["id"]
	for e in events:
		var slot: int = e[3] & 15
		match e[0]:
			K.EVENT_HIT:
				if slot != 0:
					continue
				_last_shot = e[3] >> 4
				if id == "kitchen" and sim.contact_volley and sim.phase == K.PHASE_LIVE:
					var p: SimTypes.Player = sim.players[0]
					if not Sim.in_kitchen(p.x_fp, p.y_fp, 0):
						_gain()
			K.EVENT_SERVE:
				_serving = slot == 0
				_rally_counted = false
			K.EVENT_BOUNCE:
				if id == "serve" and _serving and sim.phase == K.PHASE_LIVE:
					_serving = false
					_gain()
			K.EVENT_FAULT:
				_serving = false
				match int(e[3]):
					K.FAULT_EARLY_VOLLEY:
						_say("LET THE SERVE AND RETURN BOUNCE FIRST.")
					K.FAULT_KITCHEN:
						_say("NO VOLLEYS FROM THE KITCHEN: STEP BACK.")
					K.FAULT_WRONG_BOX:
						if id == "serve":
							_say("SERVE CORNER TO CORNER, PAST THE KITCHEN.")
					K.FAULT_NET:
						if id == "serve":
							_say("INTO THE NET: AIM A LITTLE DEEPER.")
	if id == "bounces" and sim.phase == K.PHASE_LIVE and not _rally_counted \
			and sim.required_bounce == K.REQUIRED_BOUNCE_NONE:
		_rally_counted = true
		_gain()
	if not is_match() and sim.practice:
		var s: int = sim.practice.streak
		if s > _streak:
			match id:
				"rally":
					_gain()
				"shots":
					if _last_shot in [K.SHOT_DRIVE, K.SHOT_SOFT] and not _shots_landed.has(_last_shot):
						_shots_landed[_last_shot] = true
						_gain()
				"smash":
					if _last_shot == K.SHOT_OVERHEAD:
						_gain()
		elif s < _streak and id == "smash" and _last_shot != K.SHOT_OVERHEAD:
			_say("A STEP IN FRONT OF IT, AND SWING EARLY.")
		_streak = s
