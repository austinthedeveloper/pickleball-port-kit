## A Sim's whole state as plain data, and back (port ADR-100): every script
## variable of the sim and of everything it holds (players, ball, AI,
## practice, MULTI BALL, the config), as ints, bools, strings, Arrays and
## Dictionaries, so it can be kept for a rollback, hashed for the desync
## check, or sent to a rejoining machine (var_to_bytes).
##
## Objects keep their identity: MULTI BALL's sim.ball is one of its
## entries' balls (or its idle ball), and the AI's g, style and mate point
## at records it holds. Each object is written once, as {"@": id, "class",
## "fields"}, and again as {"&": id}; loading rebuilds the same graph.
## Loading reuses the objects already in place where it can (the Sim, its
## AI, practice and MULTI BALL always), so whatever holds them still does.
##
## Nothing is listed by hand: a variable added to any of these classes is
## in the state with no change here (test_sim_state proves the round trip).
## A class the state meets that isn't in CLASSES is an error.
class_name SimState
extends RefCounted

const FORMAT := 1

## The classes a sim's state holds, by tag.
static var CLASSES := {
	"Sim": Sim,
	"SimAI": SimAI,
	"Practice": Practice,
	"MultiBallPlay": MultiBallPlay,
	"Entry": MultiBallPlay.Entry,
	"Ball": SimTypes.Ball,
	"Player": SimTypes.Player,
	"Intent": SimTypes.Intent,
	"AiStyle": SimTypes.AiStyle,
	"AiState": SimTypes.AiState,
	"MatchConfig": SimTypes.MatchConfig,
	"CareerPlayer": Career.Player,
}

## Variables that aren't state: computed properties (a getter, no storage).
const SKIP := {"Sim": ["multi"]}

static var _fields := {}         ## tag -> its variable names, in declared order


static func save(sim: Sim) -> Array:
	return [FORMAT, _encode(sim, {})]


## Loads `state` into `sim`. Returns false (and changes nothing) for a state
## of another format.
static func load_into(sim: Sim, state: Array) -> bool:
	if state.size() != 2 or state[0] != FORMAT:
		return false
	_decode(state[1], sim, {}, {})
	return true


static func tag_of(o: Object) -> String:
	var script: Script = o.get_script()
	for t: String in CLASSES:
		if CLASSES[t] == script:
			return t
	return ""


## A class's variable names, in declared order, from one of its objects.
static func fields(tag: String, o: Object) -> Array:
	if not _fields.has(tag):
		var names := []
		var skip: Array = SKIP.get(tag, [])
		for p in o.get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not p.name in skip:
				names.append(p.name)
		_fields[tag] = names
	return _fields[tag]


## A new object of `tag`, filled at once by the load. A Sim is always the
## one loaded into, and its AI, practice and MULTI BALL are its own.
static func _blank(tag: String) -> Object:
	assert(tag != "Sim" and tag != "SimAI" and tag != "Practice" and tag != "MultiBallPlay",
		"SimState: a sim's own parts are loaded in place")
	return CLASSES[tag].new()


static func _encode(v: Variant, ids: Dictionary) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return v
		TYPE_ARRAY:
			var out := []
			for e in v:
				out.append(_encode(e, ids))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _encode(v[k], ids)
			return d
		TYPE_OBJECT:
			var key: int = v.get_instance_id()
			if ids.has(key):
				return {"&": ids[key]}
			var tag := tag_of(v)
			if tag == "":
				push_error("SimState: no tag for %s" % v)
				return null
			var id := ids.size()
			ids[key] = id
			var f := {}
			for name: String in fields(tag, v):
				f[name] = _encode(v.get(name), ids)
			return {"@": id, "class": tag, "fields": f}
	push_error("SimState: can't keep a %s" % type_string(typeof(v)))
	return null


## `here` is what's in that place now: reused when it's the same class and
## not already given to another object of the state.
static func _decode(v: Variant, here: Variant, made: Dictionary, used: Dictionary) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var out := []
			var old: Array = here if here is Array else []
			for i in v.size():
				out.append(_decode(v[i], old[i] if i < old.size() else null, made, used))
			return out
		TYPE_DICTIONARY:
			if v.has("&"):
				return made[v["&"]]
			if v.has("@"):
				var tag: String = v["class"]
				var o: Object = null
				if here is Object and tag_of(here) == tag and not used.has(here.get_instance_id()):
					o = here
				else:
					o = _blank(tag)
				used[o.get_instance_id()] = true
				made[v["@"]] = o
				var f: Dictionary = v["fields"]
				for name: String in f:
					o.set(name, _decode(f[name], o.get(name), made, used))
				return o
			var d := {}
			for k in v:
				d[k] = _decode(v[k], null, made, used)
			return d
	return v
