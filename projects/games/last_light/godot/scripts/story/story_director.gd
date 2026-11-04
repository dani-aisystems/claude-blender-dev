class_name StoryDirector
extends Node
## Runs the campaign: chapters from data/story/chapters.json, each a list of beats
##   {"id", "when": <expr>, "objective": <text>, "hint": [<seconds>, <text>], "do": [[action, args...], ...]}
## Beats run in order. A beat waits for its `when`, then executes its actions in sequence; "talk"
## blocks until the conversation ends, "wait" blocks for seconds. Conversations come from
## data/story/*.dlg (DialogueDB). Station/player events become story flags (used_<device>, ...).
## Headless/bot mode (ui == null) auto-plays dialogue so automated playthroughs can test every chapter.

signal line_shown(item: Dictionary)       # for the dialogue UI
signal choices_shown(item: Dictionary)
signal dialogue_closed
signal objective_changed(text: String)
signal chapter_started(n: int, title: String, subtitle: String)
signal chapter_finished(n: int)
signal story_event(name_: String, args: Array)
signal request_autosave
signal campaign_finished(ending: Dictionary)

var sim: KeeperSim
var state := StoryState.new()
var db := DialogueDB.new()
var runner: DialogueRunner
var chapters: Array = []
var bot := false                   # auto-advance dialogue + auto-choose (tests/captures)
var bot_choice := 0
var bot_line_s := 0.05             # capture runs read at human pace (see game_fp)
var bot_wait_mul := 0.02
var _actions: Array = []           # remaining actions of the running beat
var _wait := 0.0
var _talking := false
var _beat_hint_t := 0.0
var _hint_shown := false
var _waiting_line := false
var _line_timer := 0.0
var _pending_choice: Dictionary = {}
var _need_radio_for_choice := false
var finished := false


func setup(k: KeeperSim, headless_bot := false) -> void:
	sim = k
	state.sim = k
	bot = headless_bot
	db.load_dir("res://data/story")
	var probs := db.validate()
	for p in probs:
		push_error("dialogue: " + p)
	runner = DialogueRunner.new(db, state)
	chapters = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters.json"))["chapters"]


func chapter_data(n: int) -> Dictionary:
	for c in chapters:
		if int(c["n"]) == n:
			return c
	return {}


## Start (or resume) at state.chapter / state.beat.
func begin(fresh := true) -> void:
	var c := chapter_data(state.chapter)
	if c.is_empty():
		_finish_campaign()
		return
	if fresh:
		state.beat = 0
		_apply_chapter_start(c)
	chapter_started.emit(state.chapter, c["title"], c.get("subtitle", ""))
	if state.objective != "":
		objective_changed.emit(state.objective)
	_enter_beat()


func _apply_chapter_start(c: Dictionary) -> void:
	var st: Dictionary = c.get("start", {})
	if st.has("clock"):
		sim.clock_min = float(st["clock"])
	if st.has("clock_rate"):
		sim.clock_rate = float(st["clock_rate"])
	if st.has("storm"):
		sim.storm_override = float(st["storm"])
		sim.storm = sim.storm_override
	if st.has("battery"):
		sim.battery = float(st["battery"])
	if st.has("fuel"):
		sim.fuel = maxf(sim.fuel, float(st["fuel"]))     # day tank topped up from the main tank


func _beats() -> Array:
	return chapter_data(state.chapter).get("beats", [])


func _enter_beat() -> void:
	_actions = []
	_beat_hint_t = 0.0
	_hint_shown = false
	var beats := _beats()
	if state.beat >= beats.size():
		_end_chapter()
		return
	var b: Dictionary = beats[state.beat]
	if b.has("objective"):
		state.objective = b["objective"]
		objective_changed.emit(state.objective)


func _process(delta: float) -> void:
	if sim == null or finished:
		return
	state.play_seconds += delta
	# conversations
	if _talking:
		_dialogue_tick(delta)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if not _actions.is_empty() or _beat_done_pending:
		_run_actions()
		return
	var beats := _beats()
	if state.beat >= beats.size():
		_end_chapter()
		return
	var b: Dictionary = beats[state.beat]
	if b.has("if") and not state.eval(b["if"]):
		_next_beat()
		return
	if state.eval(b.get("when", "")):
		_actions = b.get("do", []).duplicate(true)
		_beat_done_pending = true
		_run_actions()
	else:
		_beat_hint_t += delta
		var hint: Array = b.get("hint", [])
		if hint.size() == 2 and not _hint_shown and _beat_hint_t > float(hint[0]):
			_hint_shown = true
			story_event.emit("hint", [hint[1]])


var _beat_done_pending := false


func _run_actions() -> void:
	while not _actions.is_empty() and not _talking and _wait <= 0.0:
		var a: Array = _actions.pop_front()
		_do(a)
	if _actions.is_empty() and not _talking and _wait <= 0.0 and _beat_done_pending:
		_beat_done_pending = false
		_next_beat()


func _next_beat() -> void:
	state.beat += 1
	_enter_beat()


func _do(a: Array) -> void:
	var name_: String = a[0]
	var args := a.slice(1)
	match name_:
		"talk":
			start_conversation(args[0])
		"wait":
			_wait = float(args[0]) * (bot_wait_mul if bot else 1.0)
		"objective":
			state.objective = args[0]
			objective_changed.emit(state.objective)
		"set", "unset", "add", "clue":
			state.apply_action(name_, args)
		"ship":
			_route_sim(sim.spawn_story_ship(args[0]))
		"storm":
			sim.storm_override = float(args[0])
		"clock":
			sim.clock_min = float(args[0])
			if args.size() > 1:
				sim.clock_rate = float(args[1])
		"fault":
			_route_sim(sim.trigger_fault(args[0]))
		"battery":
			sim.battery = float(args[0])
		"mode":
			_route_sim(sim.set_mode(int(args[0])))
		"intensity":
			_route_sim(sim.set_intensity(int(args[0])))
		"autosave":
			request_autosave.emit()
		"end_campaign":
			_finish_campaign()
		_:
			story_event.emit(name_, args)    # presentation: sfx, music, cine, door, hint_device ...


func _route_sim(events: Array) -> void:
	story_event.emit("sim_events", [events])


## Called by the game with every KeeperSim/station event so the story can react.
func on_sim_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"ship_saved":
				state.rescues[e["name"]] = "saved"
			"ship_lost":
				state.rescues[e["name"]] = "lost"
			"ship_docked":
				state.flags["docked_" + String(e["name"]).replace(" ", "_")] = 1
			"ship_piloting":
				state.flags["piloting_" + str(e["ship"])] = 1
			"tx":
				state.flags["tx_" + String(e["cmd"])] = int(state.flags.get("tx_" + String(e["cmd"]), 0)) + 1
				state.flags["transmitted"] = 1
			"gen_start":
				state.flags["gen_started"] = 1
			"charge_switch":
				if e["on"]:
					state.flags["charge_on_once"] = 1
			"jam":
				state.flags["jam_count"] = int(state.flags.get("jam_count", 0)) + 1
			"jam_cleared":
				state.flags["jam_cleared"] = int(state.flags.get("jam_cleared", 0)) + 1
			"breaker_trip":
				state.flags["tripped"] = 1
			"breaker":
				if e["which"] == "main" and e["on"]:
					state.flags["main_reset"] = int(state.flags.get("main_reset", 0)) + 1
			"click":
				state.flags["used_" + String(e["device"])] = 1


func on_player_event(name_: String) -> void:
	state.flags[name_] = 1


# ------------------------------------------------------------------ dialogue

func start_conversation(id: String) -> void:
	if not runner.start(id):
		return
	_talking = true
	_waiting_line = false
	_pending_choice = {}
	_step_dialogue()


func _step_dialogue(item: Dictionary = {}) -> void:
	if item.is_empty():
		item = runner.advance()
	while item["type"] == "action":
		var act: String = item["action"]
		if act == "wait":
			_line_timer = float(item["args"][0]) * (bot_wait_mul if bot else 1.0)
			_waiting_line = true
			_pending_after_wait = true
			return
		_do([act] + item["args"])
		item = runner.advance()
	match item["type"]:
		"line":
			_waiting_line = true
			_line_timer = bot_line_s if bot else -1.0     # UI controls advancing; bot auto-advances
			line_shown.emit(item)
		"choice":
			_pending_choice = item
			if bot:
				_line_timer = bot_line_s
				_waiting_line = true
			else:
				choices_shown.emit(item)
		"end":
			_talking = false
			_waiting_line = false
			dialogue_closed.emit()


var _pending_after_wait := false


func _dialogue_tick(delta: float) -> void:
	if _waiting_line and _line_timer >= 0.0:
		_line_timer -= delta
		if _line_timer <= 0.0:
			if _pending_after_wait:
				_pending_after_wait = false
				_waiting_line = false
				_step_dialogue()
			elif not _pending_choice.is_empty():
				var n: int = _pending_choice["choices"].size()
				var pick := clampi(bot_choice, 0, n - 1)
				_pending_choice = {}
				_waiting_line = false
				_step_dialogue(runner.choose(pick))
			else:
				advance_line()


## UI: player finished reading the current line.
func advance_line() -> void:
	if not _talking or not _pending_choice.is_empty():
		return
	_waiting_line = false
	_step_dialogue()


## UI: player picked a choice.
func choose(index: int) -> void:
	if _pending_choice.is_empty():
		return
	_pending_choice = {}
	_step_dialogue(runner.choose(index))


func is_talking() -> bool:
	return _talking


func current_mode() -> String:
	return runner.mode() if _talking else ""


# ------------------------------------------------------------------ chapters

func _end_chapter() -> void:
	var n := state.chapter
	chapter_finished.emit(n)
	if chapter_data(n + 1).is_empty():
		_finish_campaign()
		return
	state.chapter = n + 1
	state.beat = 0
	request_autosave.emit()
	begin(true)


func _finish_campaign() -> void:
	if finished:
		return
	finished = true
	var truth := state.has_flag("told_truth")
	var saved_ship := state.saved("Iona Star")
	campaign_finished.emit({"truth": truth, "iona_saved": saved_ship, "flags": state.flags, "rescues": state.rescues,
		"play_seconds": state.play_seconds})


func save_data() -> Dictionary:
	return state.to_dict()


func load_data(d: Dictionary) -> void:
	state.from_dict(d)
