extends Node
## --autotest=SECONDS [--autotest-out=PATH]: a bot plays the real game for N seconds (or to the end),
## then writes stats JSON and quits with code 0. Used to smoke-test the exported .app.

var main: Node
var limit := 20.0
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	limit = float(GameState.user_args.get("autotest", "20"))


func _process(delta: float) -> void:
	_elapsed += delta
	var w = main.get("game") if main.get("game") != null else main.get("world")
	var done: bool = _elapsed >= limit or (w != null and int(w.sim.result) != 0)
	if not done:
		return
	var stats: Dictionary = w.sim.stats() if w else {}
	stats["wall_seconds"] = snappedf(_elapsed, 0.01)
	stats["fps"] = Engine.get_frames_per_second()
	stats["ships_seen"] = w.sim._next_id - 1 if w else 0
	var out: String = GameState.user_args.get("autotest-out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(stats))
	print("AUTOTEST_RESULT ", JSON.stringify(stats))
	get_tree().quit(0)
