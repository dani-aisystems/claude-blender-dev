class_name StoryState
extends RefCounted
## Everything the story remembers: chapter, director beat, flags, clues, relationships, choices,
## rescues, the dialogue history and the current objective. Serialises to a plain Dictionary.

var chapter := 1
var beat := 0
var flags := {}
var clues := {}
var rel := {"morag": 0, "elspeth": 0, "ross": 0}
var rescues := {}             # ship name -> "saved" | "lost"
var convs_done := {}
var history: Array = []       # {speaker (as shown), name, text, mode, look, chapter, conv, clock[, choice]}
var objective := ""
var sim: KeeperSim             # for conditions that read the station
var play_seconds := 0.0
## An autosave inside a beat (3B): the beat had started and these actions were still to run.
var in_beat := false
var resume: Array = []
## Beat layout of chapters.json. Saves are by beat INDEX, so older layouts are remapped on load.
## 2 = Stage 3B (ch1 15 -> 11 beats, ch6 3 -> 7 beats).
const LAYOUT := 2
const REMAP := {
	1: {1: [0, 1, 1, 1, 2, 2, 3, 4, 5, 5, 6, 7, 8, 9, 10]},
	6: {1: [0, 4, 5]},
}


func flag(name_: String):
	return flags.get(name_, 0)


func has_flag(name_: String) -> bool:
	if not flags.has(name_):
		return false
	var v = flags[name_]
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return v != null and str(v) != ""


func clue(name_: String) -> bool:
	return clues.has(name_)


func relation(name_: String) -> int:
	return rel.get(name_, 0)


func saved(ship: String) -> bool:
	return rescues.get(ship, "") == "saved"


func lost(ship: String) -> bool:
	return rescues.get(ship, "") == "lost"


func ship(name_: String) -> FleetShip:
	return sim.find_ship_named(name_) if sim else null


## The named ship is held in the hand-trained (MANUAL) beam right now.
func lit_by_hand(name_: String) -> bool:
	var s := ship(name_)
	return s != null and sim.mode == KeeperSim.Mode.MANUAL and sim.ship_sees_light(s)


func piloting(name_: String) -> bool:
	var s := ship(name_)
	return s != null and s.state == FleetShip.State.PILOTING


func done(conv: String) -> bool:
	return convs_done.has(conv)


## Evaluate a condition string, e.g.  has_flag("door_open") and relation("morag") > 0
## Station values: sim.battery, sim.gen, sim.mode ... (sim may be null in tests).
func eval(expr: String) -> bool:
	if expr.strip_edges() == "":
		return true
	var e := Expression.new()
	var err := e.parse(expr, ["sim"])
	if err != OK:
		push_error("story condition parse error: %s (%s)" % [expr, e.get_error_text()])
		return false
	var v = e.execute([sim], self)
	if e.has_execute_failed():
		push_error("story condition failed: %s" % expr)
		return false
	return bool(v)


func apply_action(action: String, args: Array) -> void:
	match action:
		"set":
			for a in args:
				var kv: PackedStringArray = String(a).split("=", true, 1)
				flags[kv[0]] = _val(kv[1]) if kv.size() > 1 else 1
		"unset":
			for a in args:
				flags.erase(a)
		"add":
			var key: String = args[0]
			var amt := int(args[1]) if args.size() > 1 else 1
			if key.begins_with("rel."):
				var who := key.substr(4)
				rel[who] = clampi(rel.get(who, 0) + amt, -3, 3)
			else:
				flags[key] = int(flags.get(key, 0)) + amt
		"clue":
			for a in args:
				clues[a] = true


func _val(s: String):
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	if s == "true":
		return true
	if s == "false":
		return false
	return s


func to_dict() -> Dictionary:
	return {"chapter": chapter, "beat": beat, "flags": flags, "clues": clues.keys(), "rel": rel, "rescues": rescues,
		"convs_done": convs_done.keys(), "history": history.slice(-300), "objective": objective, "play_seconds": play_seconds,
		"layout": LAYOUT, "in_beat": in_beat, "resume": resume}


func from_dict(d: Dictionary) -> void:
	chapter = int(d.get("chapter", 1))
	beat = remap_beat(chapter, int(d.get("beat", 0)), int(d.get("layout", 1)))
	in_beat = bool(d.get("in_beat", false))
	resume = d.get("resume", [])
	flags = d.get("flags", {})
	clues = {}
	for c in d.get("clues", []):
		clues[c] = true
	rel = d.get("rel", rel)
	rescues = d.get("rescues", {})
	convs_done = {}
	for c in d.get("convs_done", []):
		convs_done[c] = true
	history = Speakers.sanitize_history(d.get("history", []), self)   # pre-3A saves stored raw ids ("ROSS")
	objective = d.get("objective", "")
	play_seconds = float(d.get("play_seconds", 0.0))


## A beat index from a save made with an older chapters.json layout, in today's layout.
static func remap_beat(ch: int, b: int, layout: int) -> int:
	if layout >= LAYOUT or not REMAP.has(ch) or not REMAP[ch].has(layout):
		return b
	var m: Array = REMAP[ch][layout]
	return m[clampi(b, 0, m.size() - 1)] if b < m.size() else b - m.size() + int(m[-1]) + 1
