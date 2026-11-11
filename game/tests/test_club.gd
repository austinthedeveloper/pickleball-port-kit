## CLUB (port ADR-106, PORT-142..150): the club manager. The club's
## logic (the day, the ledger, upgrades, members, the coach, the cup, the
## weather, saving), the balance pass, the park in club mode, and main's
## flow from PLAY > CLUB through a day and back.
extends TestSuite

const DIR := "user://test_club/"


func _club(s := 4242) -> Club:
	return Club.create(s)


## A day with no weather in the way (the first non-RAIN day from today).
func _dry(c: Club) -> void:
	while c.weather() == Club.RAIN or c.weather() == Club.WINDY:
		c.end_day()


func test_new_club() -> void:
	var c := _club()
	eq(c.day, 1)
	eq(c.cash, Club.START_CASH)
	eq(c.members.size(), Club.START_MEMBERS)
	eq(c.minute, Club.OPEN, "the day starts at 9")
	eq(c.courts(), Club.BASE_COURTS)
	eq(c.day_label(), "DAY 1  MON")
	check(c.ledger.is_empty(), "no ledger yet")
	for m: Dictionary in c.members:
		check(int(m["s"]) >= 30 and int(m["s"]) <= 60, "a member's skill")
		check(int(m["p"]) >= 20 and int(m["p"]) <= 60, "a member's patience")
		check(Club.member_name(m).ends_with("."), "a name: " + Club.member_name(m))


## The same seed and the same days: the same club, night for night.
func test_deterministic() -> void:
	var a := Club.simulate(77, "BUILDER", 40)
	var b := Club.simulate(77, "BUILDER", 40)
	eq(a.size(), 40)
	eq(str(a), str(b), "two runs agree")
	check(str(Club.simulate(78, "BUILDER", 40)) != str(a), "another seed differs")


## The forecast is fixed by the seed and the day, and every kind comes up.
func test_weather() -> void:
	var c := _club(9)
	var seen := {}
	for d in range(1, 400):
		var w := c.weather(d)
		eq(c.weather(d), w, "the same day, the same weather")
		seen[w] = true
	eq(seen.size(), Club.WEATHER.size(), "every weather comes up in a year")
	var total := 0
	for w: Array in Club.WEATHER:
		total += int(w[1])
	eq(total, 100, "the chances add up")


## The ledger's lines add up to the night, and the cash moves by it.
func test_ledger_adds_up() -> void:
	var c := _club()
	for d in 20:
		var before := c.cash
		var l := c.end_day()
		var sum := 0
		for line: Array in l["lines"]:
			sum += int(line[1])
		eq(int(l["net"]), sum, "day %d's lines" % d)
		eq(c.cash, before + sum, "day %d's cash" % d)
		eq(int(l["cash"]), c.cash)
		check(int(l["played"]) <= int(l["capacity"]), "no more games than the courts hold")
	eq(c.day, 21, "twenty nights later")


func test_upgrades() -> void:
	var c := _club()
	c.cash = 10000
	var upkeep := c.upkeep()
	eq(c.why_not("annex2"), "NEEDS ANNEX COURT", "the second annex needs the first")
	check(not c.buy("annex2"))
	check(c.buy("annex1"), "the annex")
	eq(c.cash, 10000 - 1500)
	eq(c.courts(), Club.BASE_COURTS + 1, "one more court")
	check(c.upkeep() > upkeep, "a court costs upkeep")
	eq(c.why_not("annex1"), "OWNED")
	check(c.buy("annex2"))
	eq(c.courts(), Club.BASE_COURTS + 2)
	c.cash = 100
	eq(c.why_not("lights"), "NEEDS 900", "too dear")
	check(not c.buy("lights"))
	eq(c.cash, 100, "nothing spent")
	eq(c.closing(), Club.CLOSE)
	c.cash = 900
	check(c.buy("lights"))
	eq(c.closing(), Club.CLOSE_LIGHTS, "LIGHTS: open till 9")


## More courts hold more games: an annex lifts a busy club's capacity.
func test_annex_holds_more() -> void:
	var a := _club(5)
	var b := _club(5)
	b.cash += 3700
	b.buy("annex1")
	b.buy("annex2")
	b.cash = a.cash
	_dry(a)
	_dry(b)
	var la := a.end_day()
	var lb := b.end_day()
	eq(int(lb["capacity"]) - int(la["capacity"]), 2 * (Club.CLOSE - Club.OPEN) / 60 * Club.GAMES_PER_COURT_HOUR,
		"two courts, a game an hour each")


## Long waits lose members; enough courts keep them.
func test_members_leave_when_the_wait_is_long() -> void:
	var crowded := _club(11)
	var roomy := _club(11)
	for c: Club in [crowded, roomy]:
		while c.members.size() < Club.MAX_MEMBERS:
			c.members.append(c._new_member())
	roomy.upgrades = {"annex1": 1, "annex2": 1, "lights": 1}
	for d in 21:
		crowded.end_day()
		roomy.end_day()
	check(crowded.left_total > 0, "a crowded club loses members: %d left" % crowded.left_total)
	check(roomy.left_total < crowded.left_total, "more courts, fewer leave (%d against %d)" % [
		roomy.left_total, crowded.left_total])


## Your wins bring members: word of the club gets round.
func test_wins_bring_members() -> void:
	var quiet := _club(3)
	var winning := _club(3)
	for d in 14:
		for k in 3:
			winning.add_match(true, 2)
		quiet.end_day()
		winning.end_day()
	check(winning.members.size() > quiet.members.size(), "%d members against %d" % [
		winning.members.size(), quiet.members.size()])
	eq(int(winning.ledger["wins"]), 3, "the night counts your wins")


func test_coach() -> void:
	var c := _club(21)
	c.cash = 200
	check(not c.hire_coach(), "a coach costs %d to hire" % Club.COACH_FEE)
	c.cash = 1000
	check(c.hire_coach())
	eq(c.cash, 1000 - Club.COACH_FEE)
	eq(c.coach_wage(), maxi(Club.COACH_WAGE_MIN, Club.COACH_WAGE * c.members.size()))
	check(c.drill_ready() or c.park_closed(), "a drill a day")
	var skill_before := 0
	for m: Dictionary in c.members:
		skill_before += int(m["s"])
	for d in 10:
		if c.drill_ready():
			c.finish_drill()
			check(not c.drill_ready(), "one drill a day")
		c.end_day()
	var skill_after := 0
	var coached := 0
	for m: Dictionary in c.members:
		skill_after += int(m["s"])
		coached += int(m["c"])
	check(skill_after > skill_before, "coached members improve (%d to %d)" % [skill_before, skill_after])
	check(coached > 0, "coached days counted")
	var found := false
	for line: Array in c.ledger["lines"]:
		if line[0] == "COACH":
			found = true
			eq(int(line[1]), -c.coach_wage(), "the coach's wage in the ledger")
	check(found, "the coach is paid")
	c.let_coach_go()
	eq(c.coach_wage(), 0)
	eq(c.drill_lesson(), (c.day - 1) % Tutorial.LESSONS.size(), "today's drill")


func test_weekend_cup() -> void:
	var c := _club(31)
	while not c.saturday():
		check(not c.cup_ready(), "no cup on a " + Club.WEEKDAYS[c.weekday()])
		c.end_day()
	eq(c.day, 6, "day 6 is the first Saturday")
	while c.park_closed():          # a wet Saturday: next week's
		for k in 7:
			c.end_day()
	check(c.cup_ready(), "Saturday: the cup")
	c.cup_result("CHAMPION", true)
	check(not c.cup_ready(), "one cup a Saturday")
	var l := c.end_day()
	eq(c.trophies.size(), 1, "a trophy on the shelf")
	var entries := 0
	var purse := -1
	for line: Array in l["lines"]:
		if line[0] == "CUP ENTRIES":
			entries = int(line[1])
		if line[0] == "CUP PURSE":
			purse = int(line[1])
	check(entries >= 7 * Club.CUP_ENTRY, "the entries: %d" % entries)
	eq(purse, 0, "won: the purse comes back")
	while not c.saturday() or c.park_closed():
		c.end_day()
	c.cup_result("QUARTERFINALIST", false)
	for line: Array in c.end_day()["lines"]:
		if line[0] == "CUP PURSE":
			eq(int(line[1]), -Club.CUP_PURSE, "lost: the purse goes to the winners")
	eq(c.trophies.size(), 1)


## Rain shuts the park unless the club has INDOOR COURTS (then it's the
## gym); WIND on a windy day; the light by the clock.
func test_weather_days() -> void:
	var c := _club(13)
	var rain := -1
	var windy := -1
	for d in range(1, 200):
		if rain < 0 and c.weather(d) == Club.RAIN:
			rain = d
		if windy < 0 and c.weather(d) == Club.WINDY:
			windy = d
	check(rain > 0 and windy > 0, "a wet day and a windy one")
	while c.day < rain:
		c.end_day()
	check(c.park_closed(), "rain: the park is shut")
	eq(c.courts_today(), 0)
	check(not c.cup_ready() and not c.drill_ready(), "no cup or drill in the rain")
	var dues := c.members.size() * Club.DUES
	var l := c.end_day()
	eq(int(l["played"]), 0, "no games")
	eq(int(l["lines"][0][1]), dues, "the dues still come in")
	var d2 := _club(13)
	d2.upgrades = {"indoor": 1, "annex1": 1}
	while d2.day < rain:
		d2.end_day()
	check(d2.indoors() and not d2.park_closed(), "indoors")
	eq(d2.park_index(), 2, "at THE GYM")
	eq(String(Settings.PARKS[d2.park_index()][0]), "gym")
	eq(d2.courts_today(), Club.BASE_COURTS, "the gym's three; the annex is outdoors")
	check(int(d2.end_day()["played"]) > 0, "games in the rain")
	while c.day < windy:
		c.end_day()
	eq(c.match_mods(), K.MOD_WIND, "WIND on a windy day")
	c.end_day()
	eq(c.match_mods() & K.MOD_WIND, K.MOD_WIND if c.weather() == Club.WINDY else 0)
	eq(Club.time_of_day(10 * 60), CourtStyle.DAY)
	eq(Club.time_of_day(17 * 60 + 30), CourtStyle.DUSK)
	eq(Club.time_of_day(20 * 60), CourtStyle.NIGHT)
	eq(Club.clock_label(9 * 60), "9:00 AM")
	eq(Club.clock_label(12 * 60 + 5), "12:05 PM")
	eq(Club.clock_label(21 * 60), "9:00 PM")


func test_clock() -> void:
	var c := _club()
	c.add_match(true, 0)
	eq(c.minute, Club.OPEN + Club.MATCH_MINUTES, "a match takes %d minutes" % Club.MATCH_MINUTES)
	c.advance(10000)
	eq(c.minute, Club.CLOSE, "the clock stops at closing")
	check(c.closed_for_today())
	c.end_day()
	eq(c.minute, Club.OPEN, "the next morning")


## In the red for BUST_DAYS days in a row: the bank calls.
func test_bust() -> void:
	var c := _club()
	c.cash = -5000
	for d in Club.BUST_DAYS - 1:
		c.end_day()
		eq(c.state, "on", "day %d in the red" % d)
	var l := c.end_day()
	eq(c.state, "bust", "the bank called")
	check(bool(l["bust"]), "the ledger says so")
	var sv := fresh_save(DIR)
	c.store(sv)
	check(Club.current(sv) == null, "a bust club isn't kept")


## A hundred days of each strategy: members and money stay in range.
func test_soak() -> void:
	for strategy: String in Club.STRATEGIES:
		var nights := Club.simulate(1999, strategy, 100)
		eq(nights.size(), 100, strategy + " runs 100 days")
		for l: Dictionary in nights:
			var n := int(l["members"])
			check(n >= 0 and n <= Club.MAX_MEMBERS, "%s: %d members" % [strategy, n])
			check(abs(int(l["cash"])) < 1000000, "%s: cash %d" % [strategy, int(l["cash"])])
			check(int(l["wait"]) >= 0, "a wait")


## PORT-150: no strategy goes bust by day 30, none gets rich by day 60.
func test_balance() -> void:
	for strategy: String in Club.STRATEGIES:
		for s in 6:
			var nights := Club.simulate(1000 + s * 7919, strategy, 60)
			check(nights.size() >= 30 and not bool(nights[29]["bust"]),
				"%s seed %d: bust by day 30" % [strategy, s])
			for l: Dictionary in nights:
				check(int(l["cash"]) < Club.RICH, "%s seed %d: rich by day %d" % [strategy, s, int(l["day"])])


func test_save_round_trip() -> void:
	var sv := fresh_save(DIR)
	var c := Club.begin(sv, 555)
	c.cash = 1234
	c.buy("machine")
	c.add_match(true, 1)
	c.end_day()
	c.store(sv)
	sv.save_game()
	var again := SaveGame.new()
	again.dir = DIR
	again.load_game()
	var back := Club.current(again)
	check(back != null, "the club is saved")
	eq(JSON.stringify(back.to_dict(), "", true), JSON.stringify(c.to_dict(), "", true), "all of it")
	eq(Club.title_label(again), "DAY 2", "PLAY > CLUB's value")
	eq(int(Club.meta(again)["clubs"]), 1)


## A save from before CLUB (v6, no "club" key) loads; the club fills in.
func test_old_save_loads() -> void:
	var sv := fresh_save(DIR)
	sv.data.erase("club")
	sv.save_game()
	var again := SaveGame.new()
	again.dir = DIR
	again.load_game()
	eq(SaveGame.VERSION, 6, "the layout stays v6")
	check(not again.data.has("club"), "an old save has no club")
	check(Club.current(again) == null, "no club yet")
	eq(Club.title_label(again), "")
	eq(int(Club.meta(again)["clubs"]), 0, "the club's records fill in")


# --- The park in club mode ------------------------------------------------------------

func _park_view(c: Club) -> ParkView:
	var park := OpenPlay.new()
	park.begin(4321, false)
	var v := ParkView.new()
	runner.root.add_child(v)
	v.setup(park, fresh_save(DIR), false, c)
	v.input_lock = 0
	return v


func test_park_shows_the_upgrades() -> void:
	var c := _club()
	_dry(c)
	var bare := _park_view(c)
	check(not bare.machine_shown, "no ball machine before it's bought")
	check(bare.snack_props.is_empty(), "no snack cart")
	check(not bare.lamps.is_empty(), "the park's lamps")
	c.minute = Club.CLOSE - 10
	check(not bare.lamps_lit(), "no LIGHTS, unlit")
	# B at the machine's spot does nothing; the panel points at UPGRADES
	bare.op.x_fp = K.to_fp(OpenPlay.MACHINE_X)
	bare.op.y_fp = K.to_fp(OpenPlay.MACHINE_Y)
	var fired := [false]
	bare.practice.connect(func(_cfg): fired[0] = true)
	var b := SimTypes.Intent.new()
	b.hit_pressed = 1
	bare.step_frame(b)
	check(not fired[0], "no practice without a machine")
	eq(bare.message, "ROOM FOR A BALL MACHINE: SEE UPGRADES")
	bare.free()
	c.minute = Club.OPEN
	c.upgrades = {"machine": 1, "snack": 1, "lights": 1, "annex1": 1}
	var full := _park_view(c)
	check(full.machine_shown, "the ball machine")
	eq(full.snack_props.size(), 2, "the snack cart and cooler")
	c.minute = Club.CLOSE
	check(full.lamps_lit(), "LIGHTS: lit at dusk")
	full.refresh()
	check(full._night.color != Color.WHITE, "the evening's light")
	full.free()


func test_park_clock_and_closing() -> void:
	var c := _club()
	_dry(c)
	var v := _park_view(c)
	check(v._clock.text.begins_with("DAY %d " % c.day), "the clock: " + v._clock.text)
	for f in Club.CLOCK_FRAMES * 30:
		v.step_frame(SimTypes.Intent.new())
	eq(c.minute, Club.OPEN + 30, "half an hour of walking")
	check(int(c.today["samples"]) > 0, "the stacks sampled for the wait")
	c.minute = Club.CLOSE - 1
	var closed := [false]
	v.closed.connect(func(): closed[0] = true)
	for f in Club.CLOCK_FRAMES + 2:
		v.step_frame(SimTypes.Intent.new())
	check(v.closing_timer > 0, "closing time")
	eq(v.message, "CLOSING TIME: THE MEMBERS HEAD HOME")
	for f in ParkView.CLOSING_FRAMES + 2:
		if closed[0]:
			break
		v.step_frame(SimTypes.Intent.new())
	check(closed[0], "the park closes")
	v.free()


## The view only reads the park (OpenPlay): club mode changes nothing
## about how it plays, frame for frame.
func test_club_park_is_the_same_park() -> void:
	var c := _club()
	_dry(c)
	var v := _park_view(c)
	var bare := OpenPlay.new()
	bare.begin(4321, false)
	for f in 900:
		v.step_frame(SimTypes.Intent.new())
		bare.update(0, 0, false)
	eq(str(v.op.snapshot()), str(bare.snapshot()), "the same park")
	v.free()


# --- Main ------------------------------------------------------------------------------

func _main() -> Node:
	SaveGame.default_dir = DIR
	wipe_saves(DIR)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	runner.root.add_child(main)
	if not main.is_node_ready():
		main._ready()
	return main


## The fades run out; the new screen is ready (the runner's root isn't,
## during the suites, so a Control's _ready waits).
func _settle(main: Node) -> void:
	for f in main.FADE_OUT + main.FADE_IN + 1:
		main._physics_process(1.0 / 60.0)
	var s: Node = main._screen
	if s and not s.is_node_ready() and s.has_method("_ready"):
		s._ready()


## PLAY > CLUB opens the home; OPEN THE PARK, your game (a park match with
## the club's weather), back to the park, END THE DAY: the ledger.
func test_main_club_day() -> void:
	var kept := SaveGame.default_dir
	ClubHome.seed_override = 4242
	var main := _main()
	var title: TitleScreen = main._screen
	if not title.is_node_ready():
		title._ready()
	var p: MenuPage = title.reveal("club")
	check(p == title.pages["play"], "CLUB is on PLAY")
	p.press()
	_settle(main)
	var home: ClubHome = main._screen
	check(home is ClubHome, "the club's home")
	var c := home.club
	while c.park_closed() or c.weather() == Club.WINDY:
		c.end_day()
	home.page.select("open")
	home.page.press()
	_settle(main)
	var park: ParkView = main._screen
	check(park is ParkView and park.club != null, "the club's park")
	var o: OpenPlay = main.park
	o.x_fp = K.to_fp(OpenPlay.rack_x(2))
	o.y_fp = K.to_fp(OpenPlay.RACK_Y)
	park.input_lock = 0
	var b := SimTypes.Intent.new()
	b.hit_pressed = 1
	park.step_frame(b)
	eq(o.your_court, 2, "stacked at CHAMP")
	var frames := 0
	while o.called == OpenPlay.NONE and frames < 60 * 60 * 5:
		o.update(0, 0, false)
		frames += 1
	for f in OpenPlay.CALL_FRAMES + 1:
		if main._screen != park or main.fading():
			break
		park.step_frame(SimTypes.Intent.new())
	_settle(main)
	var m: MatchView = main._screen
	check(m is MatchView and m.park, "your game, an open play match")
	check(m.sim.config.open_play > 0, "counted like open play")
	var minute := c.minute
	m.sim.team_score = [7, 2]
	m.sim.match_winner = 0
	m.sim.rematch_requested = true
	m._physics_process(1.0 / 60.0)
	_settle(main)
	check(main._screen is ParkView, "back to the park")
	eq(int(c.today["wins"]), 1, "the club counts the win")
	eq(c.minute, minute + Club.MATCH_MINUTES, "the match took the clock on")
	# home, then END THE DAY (pressed twice)
	var back: ParkView = main._screen
	back.input_lock = 0
	var start := SimTypes.Intent.new()
	start.pause_pressed = 1
	back.step_frame(start)
	_settle(main)
	home = main._screen
	check(home is ClubHome, "Start: the club's home")
	var day := home.club.day
	home.page.select("end")
	home.page.press()
	home.page.press()
	_settle(main)
	home = main._screen
	check(home is ClubHome and home.view == "ledger", "the night's ledger")
	eq(home.club.day, day + 1, "the next day")
	eq(int(home.club.ledger["wins"]), 1, "your win on the ledger")
	check(Club.current(main.save) != null, "the club is saved")
	main.free()
	ClubHome.seed_override = 0
	SaveGame.default_dir = kept


## STAFF > TODAY'S DRILL plays the lesson; done, it counts for today.
func test_main_drill() -> void:
	var kept := SaveGame.default_dir
	ClubHome.seed_override = 4242
	var main := _main()
	main.show_club_home()
	_settle(main)
	var home: ClubHome = main._screen
	var c := home.club
	while c.park_closed():
		c.end_day()
	c.cash = 1000
	check(c.hire_coach())
	c.store(main.save)
	main._club_drill(c, c.drill_lesson())
	_settle(main)
	var m: MatchView = main._screen
	check(m is MatchView and m.lesson != null, "the drill: a HOW TO PLAY lesson")
	m.finished.emit(false)
	_settle(main)
	check(main._screen is ClubHome, "back home")
	check(bool(Club.current(main.save).today["drill"]), "today's drill done")
	main.free()
	ClubHome.seed_override = 0
	SaveGame.default_dir = kept


## WEEKEND CUP: the club's bracket; once it's over for you, the day ends
## with the cup on the ledger.
func test_main_cup() -> void:
	var kept := SaveGame.default_dir
	ClubHome.seed_override = 4242
	var main := _main()
	main.show_club_home()
	_settle(main)
	var c: Club = (main._screen as ClubHome).club
	while not c.saturday() or c.park_closed():
		c.end_day()
	c.store(main.save)
	main._club_cup(c)
	_settle(main)
	var b: BracketScreen = main._screen
	check(b is BracketScreen and b.club, "the WEEKEND CUP's bracket")
	eq(b.key(), "club")
	var t: Tournament = main.save.tournament("club")
	check(t != null, "made once")
	t.record(false, 3, 11)                  # out in the first round
	main.save.store_tournament(t, "club")
	b.leave.emit()
	_settle(main)
	var home: ClubHome = main._screen
	check(home is ClubHome and home.view == "ledger", "the cup was the day")
	eq(String(home.club.ledger["cup"]), "QUARTERFINALIST")
	check(main.save.tournament("club") == null, "the cup is cleared")
	main.free()
	ClubHome.seed_override = 0
	SaveGame.default_dir = kept
