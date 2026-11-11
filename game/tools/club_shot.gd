## Renders a CLUB screen (port ADR-106) and saves it (needs a display):
##   godot --path game --resolution 960x540 -s res://tools/club_shot.gd -- <screen> <frames> <out.png>
## Screens: home (a club some weeks in), fresh (day 1), ledger (last
## night's), upgrades, staff, members (a member's card), park (the
## morning), park_full (every upgrade, the evening under the LIGHTS),
## park_rain (SHOWERS), park_hot, park_gym (RAIN, INDOOR COURTS), house
## (the trophy shelf in the clubhouse), closing (closing time), cup (the
## WEEKEND CUP's bracket). A scratch save, nothing written.
extends SceneTree

var _frames := 0
var _target := 60
var _out := "user://club_shot.png"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var screen: String = a[0] if a.size() > 0 else "home"
	_target = int(a[1]) if a.size() > 1 else 60
	_out = a[2] if a.size() > 2 else _out
	var controls = load("res://game_ui/controls.gd").new()
	root.add_child(controls)
	var sv := SaveGame.new()
	sv.dir = "user://club_shot_save/"
	sv.data = SaveGame.defaults()
	sv.career = Career.new()
	var c := Club.begin(sv, 4242)
	if screen != "fresh":
		var bot := [99]
		for d in 33:
			c.bot_day("BUILDER", bot)
		c.trophies = [6, 13, 27]
		c.coach = true
	var view: Node
	match screen:
		"home", "fresh", "ledger", "upgrades", "staff", "members":
			c.store(sv)
			var h := ClubHome.new().setup(sv, c.ledger if screen == "ledger" else {})
			root.add_child(h)
			if screen in ["upgrades", "staff", "members"]:
				_sub = screen              # opened once the screen is up
			view = h
		"cup":
			var t := Tournament.create(c.seed, false, K.DIFFICULTY_MEDIUM, 11)
			t.record(true, 11, 6)
			sv.store_tournament(t, "club")
			var b := BracketScreen.new().setup(sv, false, false, true)
			root.add_child(b)
			view = b
		_:
			var w: int = {"park_rain": Club.SHOWERS, "park_hot": Club.HOT, "park_gym": Club.RAIN}.get(screen, Club.SUNNY)
			for d in range(c.day, c.day + 400):
				if c.weather(d) == w:
					c.day = d
					break
			c.minute = Club.OPEN + 75
			if screen in ["park_full", "house", "park_gym"]:
				c.upgrades = {"lights": 1, "snack": 1, "machine": 1, "annex1": 1, "annex2": 1, "indoor": 1}
			if screen == "park_full":
				c.minute = 19 * 60 + 20
			var op := OpenPlay.new()
			op.begin(1234, false)
			if screen == "house":
				op.x_fp = K.to_fp(OpenPlay.BOARD_X + 30)
				op.y_fp = K.to_fp(OpenPlay.BOARD_Y + 40)
			elif screen == "park_full":
				op.x_fp = K.to_fp(250)
				op.y_fp = K.to_fp(196)
			var v := ParkView.new()
			root.add_child(v)
			v.setup(op, sv, false, c)
			if screen == "closing":
				v.closing_timer = ParkView.CLOSING_FRAMES
			view = v
	_view = view


var _view: Node
var _sub := ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and _sub != "":
		var h := _view as ClubHome
		h._open_sub(_sub)
		if _sub == "members":
			h.sub.select("m3")
		h.refresh()
	if _view is ParkView:
		var v := _view as ParkView
		# hold the clock where the shot set it (the frames would move it on)
		var m := v.club.minute
		v.step_frame(SimTypes.Intent.new())
		v.club.minute = m
		v.refresh()
	if _frames >= _target:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
