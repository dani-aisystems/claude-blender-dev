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
signal beat_autosave                   # brief item 4: a quiet autosave at every beat entry (no manual saves)
signal campaign_finished(ending: Dictionary)
## Stage 3B: the presenter runs the chapter change as fade out -> (midpoint: the chapter switches under
## black) -> fade in -> card, and calls transition_midpoint() / transition_done(). Headless, nothing waits.
signal transition_requested(kind: String, args: Array)

## The beat-action contract (Stage 2): actions the director runs itself, and presentation events it
## forwards to game_fp._on_story_event. story_test fails on any "do" name outside these two lists, so a
## no-op like the retired hint_device cannot creep back in.
const ACTIONS := ["talk", "wait", "objective", "set", "unset", "add", "clue", "ship", "storm", "clock", "fault",
	"battery", "mode", "intensity", "autosave", "end_campaign", "timeskip", "ending_card", "until", "release"]
const PRESENTATION_EVENTS := ["hint", "sky", "phantom_echo", "door_open", "visitor_enter", "knock",
	"footsteps", "sfx", "static", "music", "caption"]
## Actions that may run while a transition holds the story at its midpoint (the screen is black): they
## change the world, not what the player reads. Everything else waits for transition_done().
const INSTANT_ACTIONS := ["objective", "set", "unset", "add", "clue", "storm", "clock", "battery", "mode",
	"intensity", "sky", "music", "phantom_echo", "autosave"]
## The four endings (STAGE3_NARRATIVE_MASTER §15): the dawn report x whether Iona Star came through.
const ENDINGS := {
	"correction": "Correction",
	"heard_together": "Heard Together",
	"nothing_to_report": "Nothing to Report",
	"light_exhibited": "Light Exhibited Throughout",
}
const HOLD_SAFETY_S := 8.0             # a lost tween can never strand the story
const POWER_HINT_S := [8.0, 45.0]      # item 32: first and repeat delay of the "no power" hint
const DAYTANK_CONV := "sys_daytank"    # item 32: Callum's line when the day tank is pumped up once
const ENDING_HOLD_S := 240.0           # the ending card is read at the player's pace

var sim: KeeperSim
var state := StoryState.new()
var db := DialogueDB.new()
var runner: DialogueRunner
var chapters: Array = []
var after_read: Dictionary = {}        # doc id -> [[first chapter, last chapter, conv], ...] (3B, E7)
var bot := false                   # auto-advance dialogue + auto-choose (tests/captures)
var bot_choice := 0
var bot_pick_fn: Callable              # tests: (conversation id, choices) -> index; overrides bot_choice
var bot_line_s := 0.05             # capture runs read at human pace (see game_fp)
var bot_wait_mul := 0.02
var _actions: Array = []           # remaining actions of the running beat
var _wait := 0.0
var _talking := false
var _beat_hint_t := 0.0
var _hints_done := 0                   # how many of the beat's timed hints have been shown
var _until := ""                       # 3B: an `until <expr>` action holds the beat's remaining actions
var _waiting_line := false
var _line_timer := 0.0
var _pending_choice: Dictionary = {}
var _need_radio_for_choice := false
var finished := false
## Transition hold (Stage 3B). presenter_driven is set by game_fp when a presenter shows the fades;
## headless runs and story_test never hold. 0 = free, 1 = going to black, 2 = at the midpoint (only
## INSTANT_ACTIONS run) until the fade in / chapter card has finished.
var presenter_driven := false
var _hold := 0
var _hold_t := 0.0
var _hold_limit := HOLD_SAFETY_S
var _pending_chapter := 0
var _optional_running := ""            # id of the optional radio call in progress ("" = none)
var ending_lines: Array = []           # the epilogue as shown on the ending card (also kept for tests)
# Brief item 32 (Kittiwake softlock, 2026-11-06): a radio conversation never plays on a dead set. It waits
# here, the story holds, and a hint says what to fix; it starts the moment the radio has power again.
var _radio_wait := ""                  # id of the radio conversation waiting for power ("" = none)
var _nopower_t := 0.0                  # seconds the story has waited on something that needs power
var _power_hints := 0                  # power hints shown in the current wait
var ending_id := ""


func setup(k: KeeperSim, headless_bot := false) -> void:
	sim = k
	state.sim = k
	bot = headless_bot
	db.load_dir("res://data/story")
	var probs := db.validate()
	for p in probs:
		push_error("dialogue: " + p)
	runner = DialogueRunner.new(db, state)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters.json"))
	chapters = data["chapters"]
	after_read = data.get("after_read", {})


func chapter_data(n: int) -> Dictionary:
	for c in chapters:
		if int(c["n"]) == n:
			return c
	return {}


## Start (or resume) at state.chapter / state.beat. A save taken by an autosave inside a beat resumes
## that beat's remaining actions instead of re-checking its `when` (which replayed its talks, 3B).
func begin(fresh := true) -> void:
	var c := chapter_data(state.chapter)
	if c.is_empty():
		_finish_campaign()
		return
	if fresh:
		state.beat = 0
		state.resume = []
		state.in_beat = false
		_apply_chapter_start(c)
	if presenter_driven:
		_hold = 2                          # the chapter card is about to show: no talk until it has
		_hold_t = 0.0
		_hold_limit = HOLD_SAFETY_S
	chapter_started.emit(state.chapter, c["title"], c.get("subtitle", ""))
	if state.objective != "":
		objective_changed.emit(state.objective)
	if not fresh and state.in_beat:
		_actions = state.resume.duplicate(true)
		_beat_done_pending = true
		state.resume = []
		state.in_beat = false
		return
	_enter_beat()


## Presenter: the screen is fully black (chapter change or timeskip).
func transition_midpoint() -> void:
	if _hold != 1:
		return
	_hold = 2
	_hold_t = 0.0
	if _pending_chapter > 0:
		_switch_chapter()


## Presenter: the fade in and the chapter card are done; the story may speak again.
func transition_done() -> void:
	if _hold == 1:
		transition_midpoint()
	_hold = 0
	_hold_t = 0.0


func is_held() -> bool:
	return _hold != 0


func _begin_hold(kind: String, args: Array, limit := HOLD_SAFETY_S) -> void:
	_hold = 1
	_hold_t = 0.0
	_hold_limit = limit
	transition_requested.emit(kind, args)


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


## Item 32 (Daniel 2026-11-06): the chapter-start rule above ("day tank topped up from the main tank")
## also runs ONCE per chapter when the day tank runs dry and the engine has stopped, so an empty tank
## mid-chapter can never strand the story. Same rule, same amount; it is not a new event.
func _check_daytank() -> void:
	if sim == null or sim.fuel > 0.01 or sim.gen != KeeperSim.Gen.OFF:
		return
	var key := "daytank_ch%d" % state.chapter
	if state.has_flag(key):
		return
	var st: Dictionary = chapter_data(state.chapter).get("start", {})
	if not st.has("fuel"):
		return
	state.flags[key] = 1
	sim.fuel = maxf(sim.fuel, float(st["fuel"]))
	if not play_aside(DAYTANK_CONV, false):
		story_event.emit("hint", ["The day-tank was dry. Callum pumped it up from the main tank below."])


## Item 32: what the keeper should fix when the story waits on power (radio or light).
func _power_hint_text() -> String:
	if not sim.main_breaker:
		return "No power: the MAIN breaker has tripped. Reset it at the distribution board."
	if sim.battery <= 0.0:
		return "No power: the batteries are flat. Start the generator and switch CHARGE on."
	return "No power. Check the MAIN breaker, the battery and the generator."


## Does the story need power to move on right now? (a radio call waiting, or a beat marked needs_power)
func _waiting_on_power() -> bool:
	if _radio_wait != "":
		return true
	var beats := _beats()
	return state.beat < beats.size() and bool(beats[state.beat].get("needs_power", false)) and not sim.powered()


func _tick_power_hint(delta: float) -> void:
	if not _waiting_on_power() or sim.powered():
		_nopower_t = 0.0
		_power_hints = 0
		return
	_nopower_t += delta
	var due: float = POWER_HINT_S[0] if _power_hints == 0 else POWER_HINT_S[1]
	if _nopower_t >= due:
		story_event.emit("hint", [_power_hint_text()])
		_power_hints += 1
		_nopower_t = 0.0


func _beats() -> Array:
	return chapter_data(state.chapter).get("beats", [])


func _enter_beat() -> void:
	_actions = []
	_until = ""
	_beat_hint_t = 0.0
	_hints_done = 0
	var beats := _beats()
	if state.beat >= beats.size():
		_end_chapter()
		return
	var b: Dictionary = beats[state.beat]
	if b.has("objective"):
		state.objective = b["objective"]
		objective_changed.emit(state.objective)
	if can_autosave() and _hold != 1 and _pending_chapter == 0:
		beat_autosave.emit()             # entering a beat re-runs it on load, so this is always a clean point


func _process(delta: float) -> void:
	if sim == null or finished:
		return
	state.play_seconds += delta
	sim.assist = state.has_flag("ross_wheel")    # 3B: Ross on the handwheel (sim assist in MANUAL)
	if _hold != 0:
		_hold_t += delta
		if _hold_t > _hold_limit:
			push_warning("story: transition hold timed out (phase %d)" % _hold)
			transition_done()
		elif _hold == 1:
			return
	_check_daytank()
	_tick_power_hint(delta)
	# conversations
	if _talking:
		_dialogue_tick(delta)
		return
	if _radio_wait != "":
		if sim.radio_on():
			var id := _radio_wait
			_radio_wait = ""
			start_conversation(id)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _until != "":
		if state.eval(_until):
			_until = ""
		else:
			_tick_hints(delta)
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
		_tick_hints(delta)


## A beat's hint is [seconds, text] or a list of them ([[25, "..."], [50, "..."]]). The clock runs while
## the beat waits for its `when`, or for an `until` inside its actions.
func _tick_hints(delta: float) -> void:
	_beat_hint_t += delta
	var beats := _beats()
	if state.beat >= beats.size():
		return
	var hint: Array = beats[state.beat].get("hint", [])
	var list: Array = hint if (not hint.is_empty() and hint[0] is Array) else ([hint] if hint.size() == 2 else [])
	if _hints_done < list.size() and _beat_hint_t > float(list[_hints_done][0]):
		story_event.emit("hint", [list[_hints_done][1]])
		_hints_done += 1


var _beat_done_pending := false


func _run_actions() -> void:
	while not _actions.is_empty() and not _talking and _wait <= 0.0 and _hold != 1 and _until == "" and _radio_wait == "":
		if _hold == 2 and not String(_actions[0][0]) in INSTANT_ACTIONS:
			return                         # under black / during the card: only world changes run
		var a: Array = _actions.pop_front()
		_do(a)
	if _actions.is_empty() and not _talking and _wait <= 0.0 and _beat_done_pending and _hold == 0 and _until == "" and _radio_wait == "":
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
			if _is_radio_conv(String(args[0])) and not sim.radio_on():
				_radio_wait = String(args[0])     # item 32: held until the set has power, never skipped
				_nopower_t = 0.0
				_power_hints = 0
			else:
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
		"release":
			_route_sim(sim.release_ship(String(args[0])))
		"storm":
			sim.storm_override = float(args[0])
		"clock":
			sim.clock_min = float(args[0])
			if args.size() > 1:
				sim.clock_rate = float(args[1])
		"fault":
			_route_sim(sim.trigger_fault(args[0], args.slice(1)))
		"battery":
			sim.battery = float(args[0])
		"mode":
			_route_sim(sim.set_mode(int(args[0])))
		"intensity":
			_route_sim(sim.set_intensity(int(args[0])))
		"autosave":
			# the save remembers what is left of this beat, so loading resumes here instead of re-running
			# the beat (its `when` is usually still true and its talks would play twice)
			state.in_beat = true
			state.resume = _actions.duplicate(true)
			request_autosave.emit()
			state.in_beat = false
			state.resume = []
		"timeskip":
			story_event.emit("timeskip", args)
			if presenter_driven:
				_begin_hold("timeskip", args)
		"ending_card":
			_ending_card(String(args[0]) if args.size() > 0 else "ch6_epilogue")
		"caption":
			_caption(String(args[0]))
		"until":
			if not state.eval(String(args[0])):
				_until = String(args[0])
				_beat_hint_t = 0.0
				_hints_done = 0
		"end_campaign":
			_finish_campaign()
		_:
			story_event.emit(name_, args)    # presentation: PRESENTATION_EVENTS, handled by game_fp


## A sound caption outside a conversation (non-blocking). It is kept in the history like a `>` line.
func _caption(text: String) -> void:
	state.history.append({"speaker": "", "name": "", "text": text, "mode": "thought", "look": "sound",
		"chapter": state.chapter, "conv": "", "clock": sim.clock_text() if sim else ""})
	story_event.emit("caption", [text])


## Which of the four endings this campaign reached (§15).
func compute_ending() -> String:
	var truth := state.has_flag("told_truth")
	var through := state.saved("Iona Star")
	if truth:
		return "correction" if through else "heard_together"
	return "nothing_to_report" if through else "light_exhibited"


## The ending card: title plus the epilogue lines that apply to this campaign, read from the
## conversation without presenting it (conditions evaluated, actions ignored). With a presenter the
## story holds until the card has been read; headless it only records them.
func _ending_card(conv_id: String) -> void:
	ending_id = compute_ending()
	ending_lines = collect_lines(conv_id)
	for t in ending_lines:
		state.history.append({"speaker": "", "name": "", "text": t, "mode": "thought", "look": "thought",
			"chapter": state.chapter, "conv": conv_id, "clock": sim.clock_text() if sim else ""})
	state.convs_done[conv_id] = true
	state.flags["ending"] = ending_id
	story_event.emit("ending_card", [ending_id, ENDINGS[ending_id], ending_lines])
	if presenter_driven:
		_begin_hold("ending", [ending_id], ENDING_HOLD_S)


## The visible lines of a conversation for the current state, in order (choices are not expected).
func collect_lines(conv_id: String) -> Array:
	var out: Array = []
	var r := DialogueRunner.new(db, state)
	var hist := state.history.size()
	if not r.start(conv_id):
		return out
	var item := r.advance()
	var guard := 0
	while item["type"] != "end" and guard < 500:
		guard += 1
		if item["type"] == "line":
			out.append(String(item["text"]))
		elif item["type"] == "choice":
			item = r.choose(0)
			continue
		item = r.advance()
	state.history.resize(hist)             # the runner logged them; the card adds them itself
	return out


func _route_sim(events: Array) -> void:
	story_event.emit("sim_events", [events])


## Called by the game with every KeeperSim/station event so the story can react.
func on_sim_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"radio":
				if e.get("kind", "") == "position":      # item 26: the beat waits for the reply, not a fixed time
					state.flags["position_" + String(e.get("from", "")).replace(" ", "_")] = 1
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
				var k := "jam_cleared_ch%d" % state.chapter      # beats key on this chapter's clear (3B)
				state.flags[k] = int(state.flags.get(k, 0)) + 1
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

func _is_radio_conv(id: String) -> bool:
	return db.convs.has(id) and String(db.convs[id].get("mode", "")) == "radio"


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
			_optional_running = ""
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
				if bot_pick_fn.is_valid():
					pick = clampi(int(bot_pick_fn.call(String(runner.conv.get("id", "")), _pending_choice["choices"])), 0, n - 1)
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


## Item 26: a sim radio line the keeper heard, kept in the transcript like a story line.
func log_radio(from: String, text: String, outgoing: bool) -> void:
	state.history.append({"speaker": "CALLUM" if outgoing else from.to_upper(), "name": "Callum" if outgoing else from,
		"text": text, "mode": "radio", "look": "radio", "chapter": state.chapter, "conv": "",
		"clock": sim.clock_text() if sim else ""})


## Item 16: a device-check thought, kept in the transcript like any thought line.
func log_thought(text: String) -> void:
	state.history.append({"speaker": "", "name": "", "text": text, "mode": "thought", "look": "thought",
		"chapter": state.chapter, "conv": "", "clock": sim.clock_text() if sim else ""})


## Item 26: ships whose arrival a story conversation already speaks (the sim's own "we have the channel
## lights" would say it twice). Listed per chapter as "story_voice" in chapters.json.
func story_voices(ship_name: String) -> bool:
	return ship_name in chapter_data(state.chapter).get("story_voice", [])


func is_talking() -> bool:
	return _talking


## A short conversation outside the beat list: an after-read room line, the bolt, the phone (3B, E7).
## It plays only when the story is quiet, and the beat queue waits for it like for an optional call.
func play_aside(conv_id: String, once := true) -> bool:
	if _talking or _hold != 0 or finished or not db.convs.has(conv_id):
		return false
	if once and state.done(conv_id):
		return false
	start_conversation(conv_id)
	return true


## Manual saves only between beats and outside transitions; an autosave may also be taken by the
## `autosave` action inside a beat (the save then carries the beat's remaining actions).
func can_manual_save() -> bool:
	return not _talking and _actions.is_empty() and _wait <= 0.0 and _hold == 0 and _pending_chapter == 0 \
		and _until == "" and _radio_wait == ""


func can_autosave() -> bool:
	return not _talking and _wait <= 0.0


func current_mode() -> String:
	return runner.mode() if _talking else ""


# ------------------------------------------------------------------ chapters

func _end_chapter() -> void:
	if _pending_chapter > 0:
		return                             # already fading to the next chapter
	var n := state.chapter
	chapter_finished.emit(n)
	if chapter_data(n + 1).is_empty():
		_finish_campaign()
		return
	_pending_chapter = n + 1
	if presenter_driven:
		_begin_hold("chapter", [n + 1])    # the presenter fades out, then calls transition_midpoint()
	else:
		_switch_chapter()


## The chapter changes under black: its start values are applied BEFORE the autosave, so a load of
## that save starts the chapter with its own clock and storm (3B: the save used to keep the old ones).
func _switch_chapter() -> void:
	var c := chapter_data(_pending_chapter)
	state.chapter = _pending_chapter
	_pending_chapter = 0
	state.beat = 0
	state.resume = []
	state.in_beat = false
	_apply_chapter_start(c)
	request_autosave.emit()
	begin(false)


# ------------------------------------------------------------------ optional radio calls (3B, E6)

## Calls the keeper may make from the radio in quiet moments: chapters.json "optional_calls", each
## {id, station, label, conv, open_after, close_at, if}. A call is offered after the beat `open_after`
## has run, until the beat `close_at` has run, once, and never while the story is speaking.
func available_calls() -> Array:
	var out: Array = []
	if _talking or _hold != 0 or finished or _radio_wait != "" or (sim != null and not sim.radio_on()):
		return out                         # item 32: no calls on a dead set
	var beats := _beats()
	for oc in chapter_data(state.chapter).get("optional_calls", []):
		if state.done(String(oc["conv"])):
			continue
		var a := _beat_index(beats, String(oc.get("open_after", "")))
		var z := _beat_index(beats, String(oc.get("close_at", "")))
		if state.beat <= a or (z >= 0 and state.beat > z):
			continue
		if oc.has("if") and not state.eval(String(oc["if"])):
			continue
		out.append(oc)
	return out


func request_call(call_id: String) -> bool:
	for oc in available_calls():
		if String(oc["id"]) == call_id:
			_optional_running = call_id
			start_conversation(String(oc["conv"]))
			return true
	return false


func optional_running() -> String:
	return _optional_running if _talking else ""


## Id of the beat the story is at (or "" past the end).
func beat_id() -> String:
	var beats := _beats()
	return String(beats[state.beat].get("id", "")) if state.beat < beats.size() else ""


func beat_reached(id: String) -> bool:
	var i := _beat_index(_beats(), id)
	return i >= 0 and state.beat >= i


## The after-read room line for a document in this chapter, if one is due (played once each).
func after_read_conv(doc: String) -> String:
	for e in after_read.get(doc, []):
		if state.chapter >= int(e[0]) and state.chapter <= int(e[1]) and not state.done(String(e[2])):
			return String(e[2])
	return ""


func _beat_index(beats: Array, id: String) -> int:
	for i in beats.size():
		if String(beats[i].get("id", "")) == id:
			return i
	return -1


func _finish_campaign() -> void:
	if finished:
		return
	finished = true
	var truth := state.has_flag("told_truth")
	var saved_ship := state.saved("Iona Star")
	if ending_id == "":
		ending_id = compute_ending()
	campaign_finished.emit({"truth": truth, "iona_saved": saved_ship, "flags": state.flags, "rescues": state.rescues,
		"play_seconds": state.play_seconds, "ending": ending_id, "title": ENDINGS[ending_id], "lines": ending_lines})


func save_data() -> Dictionary:
	return state.to_dict()


func load_data(d: Dictionary) -> void:
	state.from_dict(d)
