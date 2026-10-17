## Base for test suites: assertions report to the runner and keep going.
class_name TestSuite
extends RefCounted

var runner
var asserts := 0


func check(cond: bool, msg: String = "check failed") -> bool:
	asserts += 1
	if not cond:
		runner.fail(msg)
	return cond


func eq(actual, expected, msg: String = "") -> bool:
	asserts += 1
	if actual != expected:
		runner.fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])
		return false
	return true


## Runs the sim until `cond` is true or `limit` frames pass; returns frames.
func run_until(sim: Sim, cond: Callable, limit: int = 20000, human: Array = []) -> int:
	for i in limit:
		if cond.call():
			return i
		sim.step(human)
	return -1
