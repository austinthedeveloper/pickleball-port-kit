## PLAY OF THE MATCH (port ADR-075): when a match ends, its longest rally
## again, as television would show it. The sim is exact, so this records
## the match's inputs (and the view's two calls into it: a restart, the
## tuning panel's retune) and plays the rally back by running a second sim
## through them, checked against the live one. Display only: the live sim
## is never stepped or written here.
class_name Highlight
extends RefCounted

const MIN_SHOTS := 6             ## a rally worth showing, serve included
const SEEK_PER_FRAME := 600      ## replay frames run a drawn frame, catching up
const TITLE_FRAMES := 50         ## the card shows at least this long
const SLOW_FRAMES := 40          ## the end of the rally, at half speed
const AFTER_FRAMES := 80         ## the point's result, after it
const SKIP_LOCK := 15

var view: MatchView
var _cfg: Dictionary             ## the match's config at the start (a copy)
var _career: Career.Player
var _bot := false
var _inputs := PackedInt32Array()   ## 8 a frame: per slot, [moves and aims, buttons]
var _ops := {}                   ## frame -> [["new_match"] or ["retune", speed, errors]]
var _serve_at := 0               ## the frame the current point's serve began
var _serve_snap: Array = []
var best := {}                   ## the longest rally of this match so far

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
	return not view.demo and view.net == null and view.lesson == null \
		and not view.sim.config.practice and not view.sim.multi_on


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


## After the live step: a serve's start, a point's end (the longest rally
## of the match is the one to show; a tie goes to the later).
func after_step(events: Array) -> void:
	var s := view.sim
	if s.phase == K.PHASE_SERVE_SETUP and _serve_at != frames() - 1 and _serve_snap.is_empty():
		_serve_at = frames() - 1
		_serve_snap = s.snapshot()
	for e in events:
		if e[0] != K.EVENT_POINT:
			continue
		var shots: int = (s.shot_serial - s.rally_start) & 0xff
		if shots >= MIN_SHOTS and shots >= int(best.get("shots", 0)):
			best = {"shots": shots, "from": _serve_at, "to": frames() - 1, "winner": e[3],
				"fault": s.last_fault, "snap_from": _serve_snap, "snap_to": s.snapshot()}
		_serve_snap = []


# --- Playback --------------------------------------------------------------------------

func playing() -> bool:
	return _state != ""


## The match is over: play the best rally, then `done`. False (and nothing
## shown) when there's none.
func start(done: Callable) -> bool:
	if best.is_empty() or not wanted():
		return false
	_done = done
	var cfg := OnlineSession.config_from_dict(_cfg)
	cfg.career = _career
	replay = Sim.new(cfg)
	replay.p1_bot = _bot
	_frame = 0
	_state = "seek"
	_shown = 0
	_build_overlay()
	view._hud.visible = false            # not the result yet: the title card

	return true


func _step_replay() -> Array:
	for o in _ops.get(_frame, []):
		if o[0] == "new_match":
			replay.new_match()
		elif o[0] == "retune":
			replay.retune(int(o[1]), int(o[2]))
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
	var skip := _shown > SKIP_LOCK and (Input.is_action_just_pressed("hit")
		or Input.is_action_just_pressed("start"))
	if _state == "seek":
		var n := 0
		while _frame <= int(best["from"]) and n < SEEK_PER_FRAME:
			_step_replay()
			n += 1
		if _frame > int(best["from"]):
			if replay.snapshot() != best["snap_from"]:
				push_warning("PLAY OF THE MATCH: the replay differs; not shown")
				_finish()
				return
			if _shown >= TITLE_FRAMES:
				_swap_in()
		if skip:
			_finish()
		return
	# play: the rally, its last stretch at half speed, then its result
	var to: int = best["to"]
	var slow := _frame > to - SLOW_FRAMES and _frame <= to
	if not slow or _shown % 2 == 0:
		if _frame < mini(to + AFTER_FRAMES, frames()):
			for e in _step_replay():
				_replay_event(e)
		else:
			_finish()
			return
	_caption[2].visible = _frame > to          # the result line, once it's won
	view._update_visuals()
	if skip:
		_finish()


func _swap_in() -> void:
	_state = "play"
	_live = view.sim
	_live_glide = view.glide
	view.sim = replay
	view.glide = BallGlide.new()
	view.flair.visible = false           # the live match's reactions and emotes wait
	view._hud.visible = true             # the rally's own score, from the replay


func _finish() -> void:
	if _live:
		view.sim = _live
		view.glide = _live_glide
		view.flair.visible = true
		_live = null
	_state = ""
	view._hud.visible = true
	if overlay:
		overlay.queue_free()
		overlay = null
	if replay:
		replay.dispose()
		replay = null
	view._update_visuals()
	_done.call()


## An event of PLAY OF THE MATCH's replay: the sounds and the show, never
## the stats, the score's animation, quips or records.
func _replay_event(e: Array) -> void:
	view.feel.on_event(e)
	var sim := view.sim
	view._sfx.event(e, (sim.shot_serial - sim.rally_start) & 0xff, false)
	match int(e[0]):
		K.EVENT_HIT, K.EVENT_SERVE:
			var slot: int = e[3] & 15
			var lead := -14.0 if sim.players[slot].team else 14.0
			var shot: int = e[3] >> 4 if e[0] == K.EVENT_HIT else K.SHOT_STANDARD
			view.actors.spawn_fx("spark", CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp)
				+ Vector2(lead, 0), 1 if shot == K.SHOT_DRIVE or shot == K.SHOT_OVERHEAD else 0)
			if shot == K.SHOT_OVERHEAD:
				view._players[slot]["choice"] = "overhead"
				view.actors.smash_pop(CourtView.air(sim.ball.x_fp, sim.ball.y_fp, sim.ball.z_fp))
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
	_caption = [UiKit.text("big_gold", "PLAY OF THE MATCH", Vector2(480, 404), 0.5, Color.WHITE, card),
		UiKit.text("small", "%d-SHOT RALLY" % int(best["shots"]), Vector2(480, 440), 0.5,
			Color(0.85, 0.88, 0.95), card),
		UiKit.text("small", ending(), Vector2(480, 466), 0.5, Color("fbe46a"), card)]
	_caption[2].visible = false
	overlay.add_child(PromptBar.new().setup([["hit", "SKIP"]], Vector2(480, 516)))
	_bug = bug


var _bug: Node2D
