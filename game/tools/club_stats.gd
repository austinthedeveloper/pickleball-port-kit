## CLUB's balance (port ADR-106, PORT-150): clubs played headless by each
## strategy (Club.bot_day), a year of days, over several seeds. Prints the
## cash, members and upgrades at days 7, 30, 60, 120, 365 and the days
## any club went bust or rich.
##   godot --headless --path game -s res://tools/club_stats.gd [-- days seeds]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 365
	var seeds := int(args[1]) if args.size() > 1 else 8
	var marks := [7, 30, 60, 120, 365]
	for strategy: String in Club.STRATEGIES:
		print("\n", strategy)
		print("  day   cash (min..max, mean)        members (min..max)   wait  bust  rich")
		var runs: Array = []
		for s in seeds:
			runs.append(Club.simulate(1000 + s * 7919, strategy, days))
		for mark: int in marks:
			if mark > days:
				continue
			var cash: Array = []
			var mem: Array = []
			var wait := 0
			var bust := 0
			var rich := 0
			for r: Array in runs:
				if r.size() < mark:
					bust += 1
					continue
				var l: Dictionary = r[mark - 1]
				cash.append(int(l["cash"]))
				mem.append(int(l["members"]))
				wait += int(l["wait"])
				if int(l["cash"]) >= Club.RICH:
					rich += 1
			if cash.is_empty():
				print("  %3d   all bust" % mark)
				continue
			var mean := 0
			for c: int in cash:
				mean += c
			print("  %3d   %6d..%6d, %6d          %2d..%2d               %3d   %d     %d" % [mark,
				cash.min(), cash.max(), mean / cash.size(), mem.min(), mem.max(), wait / cash.size(),
				bust, rich])
	quit(0)
