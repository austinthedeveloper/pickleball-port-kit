## ROAD TRIP's gear curve (port ADR-093), headless: trips played on paper
## (every match won, no sim), picking gear greedily (the card that adds the
## most to your stats, sets counted) or at random, buying what the shop
## has when there's cash; prints the stats you reach at each big match and
## the final, with a new GARAGE and a full one.
##   godot --headless --path game -s res://tools/trip_gear_stats.gd -- [trips=200]
## What it says: how far gear (not play) moves the stats, against the
## standard player's 8 and the 20 cap.
extends SceneTree


func _initialize() -> void:
	var trips := 200
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("trips="):
			trips = int(arg.substr(6))
	for garage in [0, 99999]:
		for policy in ["greedy", "random"]:
			var at_gate := [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
			var capped := [0, 0, 0]
			var sets := 0
			for i in trips:
				var m := {"miles": garage, "beats": [], "story_pool": [], "tapes": []}
				var t := RoadTrip.create(5000 + i, 0, RoadTrip.PEPPER, m)
				t._meta_for_draw = m
				var gates := 0
				for step in 40:
					if t.state != "on" or gates >= 3:
						break
					if not t.pending.is_empty():
						_pick(t, policy, i + step)
						continue
					var r := t.reachable() if not t.is_gate() else [[RoadTrip.GATE, 0]]
					if r.is_empty():
						r = t.targets()
					if r.is_empty():
						break
					var target: Array = r[(i + step) % r.size()]
					if int(target[0]) == RoadTrip.GATE:
						var s := t.stats(true)
						for k in 4:
							at_gate[gates][k] += int(s[k])
						if s.has(RoadTrip.STAT_MAX):
							capped[gates] += 1
						gates += 1
					var n := t.go(int(target[0]), int(target[1]))
					match String(n["type"]):
						"shop":
							for id in t.shop_stock(m):
								if t.buy(String(id)):
									break
							t.finish_stop()
						"diner":
							t.order(0)
							t.finish_stop()
						"detour":
							t.choose(RoadTrip.detour(String(n["detour"])), 0)
							t.finish_stop()
						"yard":
							t.offer_pick("yard", 0)
							t.finish_stop()
						"motel":
							t.rest(t.hearts < t.max_hearts)
							t.finish_stop()
						_:
							t.record_match(true)
				sets += t.active_sets().size()
			print("GARAGE %s, %s picks (%d trips): POWER CONTROL SPEED FEET on average, and trips with a stat at 20" % [
				"full" if garage else "new", policy, trips])
			for g in 3:
				var avg := []
				for k in 4:
					avg.append("%4.1f" % (at_gate[g][k] / float(trips)))
				print("  %-12s %s   at 20: %d%%" % [["leg 1 big", "leg 2 big", "the final"][g], "  ".join(avg),
					100 * capped[g] / trips])
			print("  sets made by the end: %.2f a trip" % (sets / float(trips)))
	quit()


## Takes a card: the one adding most to your stats (greedy), or one at random.
func _pick(t: RoadTrip, policy: String, salt: int) -> void:
	var items: Array = t.pending.get("items", [])
	if items.is_empty():
		t.skip_pick()
		return
	var best := String(items[salt % items.size()])
	if policy == "greedy":
		var top := -99
		for id in items:
			var c := RoadTrip.from_dict(t.to_dict())
			c.take(String(id))
			var gain := 0
			for k in 4:
				gain += int(c.stats()[k]) - int(t.stats()[k])
			if gain > top:
				top = gain
				best = String(id)
	t.take(best)
