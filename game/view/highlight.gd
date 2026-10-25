## PLAY OF THE MATCH (port ADR-075): when a match ends, its longest rally
## again, as television would show it. The sim is exact, so this records
## the match's inputs (and the view's two calls into it: a restart, the
## tuning panel's retune) and plays the rally back by running a second sim
## through them, checked against the live one. Display only: the live sim
## is never stepped or written here.
##
## Saved replays (PORT-69, ADR-081) are the same recording cut after one
## rally: the pause menu's SAVE LAST RALLY writes `export(last)` through
## SavedReplays, as SAVE does here while PLAY OF THE MATCH plays (PORT-70),
## and `from_saved` plays one back, from REPLAYS on the title or quietly
## in its demo.
class_name Highlight
extends RefCounted

const MIN_SHOTS := 6             ## a rally worth showing, serve included
const SEEK_PER_FRAME := 600      ## replay frames run a drawn frame, catching up
const TITLE_FRAMES := 50         ## the card shows at least this long
const SLOW_FRAMES := 40          ## the end of the rally, at half speed
const AFTER_FRAMES := 50         ## the point's result, after it
const LEAD_FRAMES := 45          ## shown before the serve is struck (PORT-71)
const SKIP_LOCK := 15

var view: MatchView
var _cfg: Dictionary             ## the match's config at the start (a copy)
var _career: Career.Player
var _bot := false
var _inputs := PackedInt32Array()   ## 8 a frame: per slot, [moves and aims, buttons]
var _ops := {}                   ## frame -> [["new_match"], ["retune", speed, errors] or ["smarts", [...]]]
var _serve_at := 0               ## the frame the current point's serve began
var _serve_snap: Array = []
var _serve_hit := -1             ## the frame the serve was struck (PORT-71)
var best := {}                   ## the longest rally of this match so far
var last := {}                   ## the rally that ended last (SAVE LAST RALLY)
var saved_last := false          ## that one is saved already
var saved_best := false          ## PLAY OF THE MATCH's rally is saved (its SAVE)
var saved := false               ## a saved replay, not this match's (from_saved)
var quiet := false               ## in the title's demo: no card, no skip, no score

# playback
var replay: Sim
var _live: Sim
var _live_glide: BallGlide
var _frame := 0                  ## the replay's next recorded frame
var _state := ""                 ## "", "seek", "play"
var _shown := 0                  ## frames the overlay has been up
var _done: Callable
var overlay: CanvasLayer
var _caption: Array = []


func _init(v: MatchView) -> void:
	view = v
	_cfg = OnlineSession.config_to_dict(v.sim.config)
	_career = v.sim.config.career
	_bot = v.sim.p1_bot


## Whether this match gets one: not the demo, online, a lesson, practice or
## MULTI BALL (no single rally).
func wanted() -> bool:
	return wanted_for(view)


## The same, before the view has made its Highlight (the pause menu's
## SAVE LAST RALLY row is built first).
static func wanted_for(v: MatchView) -> bool:
	return not v.demo and v.net == null and v.lesson == null \
		and not v.sim.config.practice and not v.sim.multi_on


func frames() -> int:
	return _inputs.size() / 8


# --- Recording -------------------------------------------------------------------------

## The frame's human intents, just before the live sim steps on them.
func record(human: Array) -> void:
	_bot = view.sim.p1_bot
	for i in K.MAX_PLAYERS:
		var it: SimTypes.Intent = human[i] if i < human.size() else null
		if it == null:
			_inputs.append(0)
			_inputs.append(0)
			continue
		_inputs.append(((it.move_x + 128) & 0xff) | (((it.move_y + 128) & 0xff) << 8)
			| (((it.aim_x + 128) & 0xff) << 16) | (((it.aim_y + 128) & 0xff) << 24))
		_inputs.append(1 | (it.hit_pressed << 1) | ((it.shot & 0xff) << 2) | (it.pause_pressed << 10)
			| (it.hit_held << 11))


func _intent(f: int, i: int) -> SimTypes.Intent:
	var b := _inputs[f * 8 + i * 2 + 1]
	if b & 1 == 0:
		return null
	var a := _inputs[f * 8 + i * 2]
	var it := SimTypes.Intent.new()
	it.move_x = (a & 0xff) - 128
	it.move_y = ((a >> 8) & 0xff) - 128
	it.aim_x = ((a >> 16) & 0xff) - 128
	it.aim_y = ((a >> 24) & 0xff) - 128
	it.hit_pressed = (b >> 1) & 1
	it.shot = (b >> 2) & 0xff
	it.pause_pressed = (b >> 10) & 1
	it.hit_held = (b >> 11) & 1
	return it


## A call the view made into the sim before the next step.
func op(o: Array) -> void:
	if not _ops.has(frames()):
		_ops[frames()] = []
	_ops[frames()].append(o)
	if o[0] == "new_match":
		best = {}
		saved_best = false


## After the live step: a serve's start, a point's end (the longest rally
## of the match is the one to show; a tie goes to the later). Every rally
## that was served is the last one, for SAVE LAST RALLY.
func after_step(events: Array) -> void:
	var s := view.sim
	if s.phase == K.PHASE_SERVE_SETUP and _serve_at != frames() - 1 and _serve_snap.is_empty():
		_serve_at = frames() - 1
		_serve_snap = s.snapshot()
		_serve_hit = -1
	for e in events:
		if e[0] == K.EVENT_SERVE and _serve_hit < _serve_at:
			_serve_hit = frames() - 1
		if e[0] != K.EVENT_POINT:
			continue
		var shots: int = (s.shot_serial - s.rally_start) & 0xff
		var rally := {"shots": shots, "from": _serve_at, "to": frames() - 1, "winner": e[3],
			"fault": s.last_fault, "snap_from": _serve_snap, "snap_to": s.snapshot(),
			"serve": maxi(_serve_hit, _serve_at)}
		if shots >= 1 and not _serve_snap.is_empty():
			last = rally
			saved_last = false
		if shots >= MIN_SHOTS and shots >= int(best.get("shots", 0)):
			best = rally
			saved_best = false
		_serve_snap = []


# --- Saving (PORT-69) -------------------------------------------------------------------

## A rally as a saved replay: the match's start and its inputs up to the
## rally's result, the rally's place in them and its snapshots (playback
## checks them), and what REPLAYS lists. Plain values only (SavedReplays
## stores it with store_var, which keeps the ints ints).
func export(rally: Dictionary) -> Dictionary:
	var end := mini(frames(), int(rally["to"]) + AFTER_FRAMES)
	var ops := {}
	for f in _ops:
		if int(f) < end:
			ops[int(f)] = _ops[f].duplicate(true)
	return {"format": SavedReplays.FORMAT, "tuning": K.TUNING_VERSION,
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved": int(Time.get_unix_time_from_system()),
		"venue": view.venue, "time": view._base_time, "court": view._base_court.duplicate(),
		"teams": [view._hud._team_label(0), view._hud._team_label(1)],
		"doubles": view.sim.config.mode == K.MODE_DOUBLES,
		"cfg": _cfg.duplicate(true), "career": _career.to_dict() if _career else {},
		"bot": _bot, "ops": ops, "inputs": _inputs.slice(0, end * 8),
		"rally": rally.duplicate(true)}


## SAVE LAST RALLY (PORT-69): the rally that ended last, once. False
## when there's none, it's saved already, or REPLAYS is full.
func save_last() -> bool:
	if last.is_empty() or saved_last or SavedReplays.full():
		return false
	saved_last = SavedReplays.save(export(last)) != ""
	return saved_last


## SAVE LAST RALLY's value: NONE YET, SAVED, FULL, or the rally's shots.
func last_state() -> String:
	if last.is_empty():
		return "NONE YET"
	if saved_last:
		return "SAVED"
	return "FULL" if SavedReplays.full() else "%d SHOTS" % int(last["shots"])


## PLAY OF THE MATCH's SAVE (PORT-70): its rally to SavedReplays, once
## (it's the same rally as SAVE LAST RALLY's when the match ended on it).
func save_best() -> bool:
	if best_state() != "SAVE":
		return false
	saved_best = SavedReplays.save(export(best)) != ""
	if saved_best and int(last.get("from", -1)) == int(best["from"]):
		saved_last = true
	return saved_best


## What SAVE would do: SAVE, SAVED (already), FULL, or "" (nothing to,
## or a saved replay playing).
func best_state() -> String:
	if saved or best.is_empty():
		return ""
	if saved_best or (saved_last and int(last.get("from", -1)) == int(best["from"])):
		return "SAVED"
	return "FULL" if SavedReplays.full() else "SAVE"


## A saved replay (`export`'s dictionary), ready to `start` on a view set
## up with its config.
static func from_saved(v: MatchView, data: Dictionary) -> Highlight:
	var h := Highlight.new(v)
	h.saved = true
	h._cfg = data["cfg"]
	var c: Dictionary = data.get("career", {})
	h._career = null if c.is_empty() else Career.Player.from_dict(c)
	h._bot = bool(data.get("bot", false))
	h._inputs = data["inputs"]
	h._ops = data["ops"]
	h.best = data["rally"]
	return h


# --- Playback --------------------------------------------------------------------------

func playing() -> bool:
	return _state != ""


## The match is over: play the best rally, then `done`. False (and nothing
## shown) when there's none.
func start(done: Callable) -> bool:
	if best.is_empty() or not (saved or wanted()):
		return false
	_done = done
	var cfg := OnlineSession.config_from_dict(_cfg)
	cfg.career = _career
	replay = Sim.new(cfg)
	replay.p1_bot = _bot
	_frame = 0
	_state = "seek"
	_shown = 0
	if not quiet:
		_build_overlay()
	view._hud.visible = false            # not the result yet: the title card

	return true


func _step_replay() -> Array:
	for o in _ops.get(_frame, []):
		if o[0] == "new_match":
			replay.new_match()
		elif o[0] == "retune":
			replay.retune(int(o[1]), int(o[2]))
		elif o[0] == "smarts":
			replay.retune_smarts(o[1].map(func(v): return int(v)))
	var human := []
	for i in K.MAX_PLAYERS:
		human.append(_intent(_frame, i))
	replay.step(human)
	_frame += 1
	return replay.drain_events()


## One drawn frame of the highlight.
func update() -> void:
	_shown += 1
	if _bug:
		_bug.queue_redraw()                # the REPLAY dot blinks
	var skip := not quiet and _shown > SKIP_LOCK and (Input.is_action_just_pressed("hit")
		or Input.is_action_just_pressed("start"))
	if not quiet and _shown > SKIP_LOCK and Input.is_action_just_pressed("soft"):
		on_save()
	if _state == "seek":
		# catch up unseen to just before the serve, checking the sim at the
		# serve's setup on the way
		var n := 0
		var start := start_frame()
		while _frame < start and n < SEEK_PER_FRAME:
			_step_replay()
			n += 1
			if _frame == int(best["from"]) + 1 and replay.snapshot() != best["snap_from"]:
				push_warning("PLAY OF THE MATCH: the replay differs; not shown")
				_finish()
				return
		if _frame >= start:
			_skip_paused()
			if _shown >= TITLE_FRAMES or quiet:
				_swap_in()
		if skip:
			_finish()
		return
	# play: the rally, its last stretch at half speed, then its result
	var to: int = best["to"]
	var slow := _frame > to - SLOW_FRAMES and _frame <= to
	if not slow or _shown % 2 == 0:
		if _frame < end_frame():
			for e in _step_replay():
				_replay_event(e)
			_skip_paused()
		else:
			_finish()
			return
	if not _caption.is_empty():
		_caption[2].visible = _frame > to      # the result line, once it's won
	view._update_visuals()
	if skip:
		_finish()


## The first frame shown (PORT-71): a moment before the serve is struck,
## not the wait at the serve's setup. A replay saved before PORT-71 has no
## "serve", and starts at the setup.
func start_frame() -> int:
	var from := int(best["from"]) + 1
	return maxi(from, int(best["serve"]) - LEAD_FRAMES) if best.has("serve") else from


func end_frame() -> int:
	return mini(int(best["to"]) + AFTER_FRAMES, frames())


## Paused frames were recorded (the sim steps while paused, to take the
## unpause): they run unseen, so a replay never shows the pause menu or
## the wait in it (PORT-71).
func _skip_paused() -> void:
	while replay.paused != 0 and _frame < end_frame():
		_step_replay()


func _swap_in() -> void:
	_state = "play"
	_live = view.sim
	_live_glide = view.glide
	view.sim = replay
	view.glide = BallGlide.new()
	view.flair.visible = false           # the live match's reactions and emotes wait
	view._hud.visible = not quiet        # the rally's own score, from the replay


func _finish() -> void:
	if _live:
		view.sim = _live
		view.glide = _live_glide
		view.flair.visible = true
		_live = null
	_state = ""
	view._hud.visible = not view.demo    # the title's demo never shows one
	if overlay:
		overlay.queue_free()
		overlay = null
	if replay:
		replay.dispose()
		replay = null
	view._update_visuals()
	_done.call()


## An event of PLAY OF THE MATCH's replay: the sounds and the show (the
## bounce marks and camera flashes too), never the stats, the score's
## animation, quips or records.
func _replay_event(e: Array) -> void:
	view.feel.on_event(e)
	view.effects.on_event(e)
	var sim := view.sim
	view._sfx.event(e, (sim.shot_serial - sim.rally_start) & 0xff, false)
	match int(e[0]):
		K.EVENT_HIT, K.EVENT_SERVE:
			view.contact_fx(e)
		K.EVENT_BOUNCE:
			view.actors.spawn_fx("dust", CourtView.ground(K.to_fp(e[1]), K.to_fp(e[2])), 0)
		K.EVENT_POINT:
			view.crowd.cheer(90)


# --- The overlay ------------------------------------------------------------------------

## What the caption says of how the rally ended.
func ending() -> String:
	var who: String = view._hud._team_label(int(best["winner"]))
	match int(best["fault"]):
		K.FAULT_OUT:
			return "POINT %s: THE LAST SHOT SAILED OUT" % who
		K.FAULT_SECOND_BOUNCE:
			return "POINT %s: NO ONE GOT TO IT" % who
		K.FAULT_NET:
			return "POINT %s: INTO THE NET" % who
	return "POINT %s: %s" % [who, K.fault_word(int(best["fault"]))]


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 15
	view.add_child(overlay)
	var bug := Node2D.new()
	overlay.add_child(bug)
	bug.draw.connect(func():
		if (_shown / 30) % 2 == 0:
			bug.draw_circle(Vector2(26, 31), 6, Color("e5484d")))
	UiKit.text("small", "REPLAY", Vector2(38, 22), 0.0, Color.WHITE, bug)
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(card)
	UiKit.panel(Rect2(200, 392, 560, 104), card)
	_caption = [UiKit.text("big_gold", "SAVED REPLAY" if saved else "PLAY OF THE MATCH",
			Vector2(480, 404), 0.5, Color.WHITE, card),
		UiKit.text("small", "", Vector2(480, 440), 0.5, Color(0.85, 0.88, 0.95), card),
		UiKit.text("small", ending(), Vector2(480, 466), 0.5, Color("fbe46a"), card)]
	_caption[2].visible = false
	_prompts = PromptBar.new().setup([], Vector2(480, 516))
	overlay.add_child(_prompts)
	_bug = bug
	_refresh_save()


var _bug: Node2D
var _prompts: PromptBar


## SAVE pressed (soft: X, or L): saved, or why not.
func on_save() -> void:
	var state := best_state()
	if state == "":
		return
	view._sfx.play("confirm" if save_best() else "back")
	_refresh_save()


## The card's rally line ("14-SHOT RALLY, SAVED") and its prompts: SAVE
## while it can be.
func _refresh_save() -> void:
	if overlay == null:
		return
	var state := best_state()
	_caption[1].text = "%d-SHOT RALLY" % int(best["shots"]) + {"SAVED": ", SAVED",
		"FULL": ", REPLAYS FULL"}.get(state, "")
	_prompts.set_items([["hit", "SKIP"], ["soft", "SAVE"]] if state == "SAVE" else [["hit", "SKIP"]])
