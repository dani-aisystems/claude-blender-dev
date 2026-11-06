extends SceneTree
## Story QA (headless):
##  1. every .dlg parses and every jump target exists
##  2. every conversation is walked through ALL choice paths (DFS) with permissive flags: no dead ends/loops
##  3. full campaign playthroughs (StoryDirector bot mode + KeeperBot2 at the station) for several choice
##     policies: each must reach the campaign end without a softlock, and reports the ending + sim time.
##  4. Stage 3B: all four endings (and the reunion variant, and a door-shut-throughout game) are reached by
##     valid choice policies; every flag/clue the story sets is read somewhere (or allow-listed); the beat
##     layout; old-save beat remap; an autosave inside a beat resumes there instead of replaying it.
##   godot --headless --path godot -s res://tests/story_test.gd [-- --policies=0,1,2 --quick]

var fails: Array[String] = []
var endings := {}                       # ending id -> [scenario names] (3B)
var reunion_lie := false
var autosaves: Array = []               # snapshots taken at every autosave of the policy-0 campaign
## Set but deliberately not read by a condition (STAGE3_NARRATIVE_MASTER §16.1 "engine / history only").
const HISTORY_ONLY := ["letter", "log_1953", "ending", "archive_flip", "kept_letter_unused"]
## 3B beat layout (§7): ch1 merged to 11 beats; ch6 gains jam, free, standby and ending.
const BEATS := {1: 11, 2: 8, 3: 7, 4: 5, 5: 5, 6: 7}
## Ending scenarios: reply preferences (conversation -> text fragment) and when the station goes idle.
const SCENARIOS := [
	{"name": "E2 truth + aground", "prefs": {}, "idle_at": "iona", "expect": "heard_together"},
	{"name": "E3 lie + saved + reunion", "prefs": {"ch6_morag_dawn": "Nothing to report"}, "expect": "nothing_to_report", "reunion": true},
	{"name": "E4 lie + aground", "prefs": {"ch6_morag_dawn": "Nothing to report"}, "idle_at": "iona", "expect": "light_exhibited"},
	{"name": "door shut throughout, truth", "prefs": {"ch4_door": "Keep the door shut", "ch6_jam": "Stay where you are"},
		"expect": "correction", "door_shut": true},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db := DialogueDB.new()
	db.load_dir("res://data/story")
	var probs := db.validate()
	for p in probs:
		fails.append("dlg: " + p)
	print("DLG conversations=%d problems=%d" % [db.convs.size(), probs.size()])
	var lines := 0
	for id in db.convs:
		for s in db.convs[id]["steps"]:
			if s["kind"] == "line":
				lines += 1
	print("DLG lines=%d" % lines)
	_walk_all(db)
	_check_beat_actions()
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var policies: PackedStringArray = String(args.get("policies", "0,1,2")).split(",")
	_check_layout()
	_audit_flags(db)
	_check_dlg_actions(db)
	_check_remap()
	for p in policies:
		await _campaign(int(p))
	if not args.has("quick"):
		for sc in SCENARIOS:
			await _campaign(0, sc)
		for e in ["correction", "heard_together", "nothing_to_report", "light_exhibited"]:
			if not endings.has(e):
				fails.append("ending '%s' not reached by any policy" % e)
		if not reunion_lie:
			fails.append("the lie + saved + reunion variant (C9) was not reached")
		print("ENDINGS reached=%s" % endings)
		await _autosave_resumes()
		await _kittiwake_power_out()
	await _save_roundtrip()
	_save_files()
	print("STORY_RESULT ", JSON.stringify({"failed": fails.size(), "failures": fails}))
	quit(1 if fails.size() > 0 else 0)


## DFS over choices for each conversation with a permissive state (all conditions evaluated for real
## against an empty state AND against a 'rich' state with typical flags set).
## Stage 2: every beat "do" action is one the director runs or game_fp presents (no silent no-ops).
func _check_beat_actions() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters.json"))
	var known: Array = StoryDirector.ACTIONS + StoryDirector.PRESENTATION_EVENTS
	var seen := 0
	var stack: Array = [data]
	while not stack.is_empty():
		var o = stack.pop_back()
		if o is Dictionary:
			for k in o:
				var texts: Array = []
				if k == "hint" and o[k] is Array and not o[k].is_empty():
					for h in (o[k] if o[k][0] is Array else [o[k]]):
						texts.append(String(h[1]))
				if k == "objective" and o[k] is String:
					texts.append(o[k])
				if k == "do" and o[k] is Array:
					for a in o[k]:
						if String(a[0]) == "objective":
							texts.append(String(a[1]))
				for t in texts:
					for pad in [false, true]:           # Stage 2C: glyph tokens resolve for both devices
						InputSetup.pad_active = pad
						var r: String = InputSetup.resolve(t)
						if "{" in r or "}" in r:
							fails.append("chapters.json: unresolved token in '%s'" % r)
					InputSetup.pad_active = false
				if k == "do" and o[k] is Array:
					for a in o[k]:
						seen += 1
						if not (String(a[0]) in known):
							fails.append("chapters.json: unknown beat action '%s'" % a[0])
				else:
					stack.append(o[k])
		elif o is Array:
			stack.append_array(o)
	print("BEAT_ACTIONS checked=%d" % seen)


func _walk_all(db: DialogueDB) -> void:
	var paths := 0
	for rich in [false, true]:
		for id in db.convs:
			var st := StoryState.new()
			if rich:
				for f in ["door_open", "ross_wheel", "told_truth", "admitted_to_morag"]:
					st.flags[f] = 1
				for c in ["same_hand", "sy214", "letter"]:
					st.clues[c] = true
				st.rescues = {"Iona Star": "saved", "Gannet": "saved", "Corrie May": "saved", "Lowestoft Star": "saved"}
				st.rel = {"morag": 2, "elspeth": 1, "ross": 1}
			paths += _dfs(db, id, st, [], 0)
	print("DLG explored paths=%d" % paths)


func _dfs(db: DialogueDB, id: String, st: StoryState, picks: Array, depth: int) -> int:
	var r := DialogueRunner.new(db, st)
	r.start(id)
	var item := r.advance()
	var pi := 0
	var steps := 0
	while item["type"] != "end":
		steps += 1
		if steps > 500:
			fails.append("dlg loop: %s picks=%s" % [id, picks])
			return 1
		if item["type"] == "choice":
			if pi < picks.size():
				item = r.choose(picks[pi])
				pi += 1
				continue
			var n: int = item["choices"].size()
			var total := 0
			if depth > 6:
				return 1
			for k in n:
				var st2 := StoryState.new()
				st2.flags = st.flags.duplicate()
				st2.clues = st.clues.duplicate()
				st2.rescues = st.rescues.duplicate()
				st2.rel = st.rel.duplicate()
				total += _dfs(db, id, st2, picks + [k], depth + 1)
			return total
		item = r.advance()
	return 1


## The generator part of KeeperBot2 only: start it when the battery is low, charge, stop when full.
func _keep_power(k: KeeperSim) -> Array:
	var ev: Array = []
	if k.gen == KeeperSim.Gen.OFF and k.battery < 55.0 and k.fuel > 0.0 and not (k.gen_overheated and k.gen_temp > k.cfg.temp_restart):
		if not k.fuel_valve:
			ev += k.set_fuel_valve(true)
		ev += k.set_start(true)
	elif k.gen != KeeperSim.Gen.CRANKING and k.start_held:
		ev += k.set_start(false)
	if k.gen == KeeperSim.Gen.RUNNING:
		var want := k.battery < 96.0 and k.gen_temp < 82.0
		if k.charge_on != want:
			ev += k.set_charge(want)
	return ev


## Brief item 32 (the reported Kittiwake softlock): at the ch1 `kittiwake` beat the battery AND the day
## tank are emptied and the keeper does nothing for a while. The radio call must wait (never play on a
## dead set), a power hint must be shown, the day tank must be pumped up once, and once the keeper acts
## again the chapter must finish. Also: a radio call at LAMP HIGH must not trip MAIN on its own.
func _kittiwake_power_out() -> void:
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 31)
	k.story_mode = true
	var dir := StoryDirector.new()
	root.add_child(dir)
	dir.setup(k, true)
	var bot := KeeperBot2.new("expert", 3)
	var hints: Array = []
	dir.story_event.connect(func(n, a):
		if n == "sim_events":
			dir.on_sim_events(a[0])
		elif n == "hint":
			hints.append(String(a[0])))
	dir.begin(true)
	var dt := 1.0 / 30.0
	var t := 0.0
	var phase := 0                     # 0 bot to the beat, 1 dead and idle, 2 bot again
	var idle_t := 0.0
	var played_dead := false
	while t < 3000.0 and dir.state.chapter == 1:
		t += dt
		for f in ["moved", "looked", "used_battery", "read_log_1971"]:
			if dir.state.objective != "" and t > 2.0:
				dir.state.flags[f] = 1
		var ev: Array = []
		if phase == 0 and dir.beat_id() == "kittiwake":
			phase = 1
			k.battery = 0.0
			k.fuel = 0.0
			k.charge_on = false
			k.gen = KeeperSim.Gen.OFF
		if phase == 1:
			idle_t += dt
			if dir.is_talking() and dir._is_radio_conv(String(dir.runner.conv.get("id", ""))) and not k.radio_on():
				played_dead = true
			if idle_t > 40.0:
				phase = 2
		else:
			ev = bot.act(k, dt)
		ev += k.step(dt)
		dir.on_sim_events(ev)
		dir._process(dt)
		if int(t / dt) % 60 == 0:
			await process_frame
	var power_hint := hints.any(func(h): return h.begins_with("No power"))
	if played_dead:
		fails.append("item 32: a radio conversation played while the radio had no power")
	if not power_hint:
		fails.append("item 32: no 'No power' hint while the story waited on a dead set (hints: %s)" % [hints])
	if not dir.state.has_flag("daytank_ch1"):
		fails.append("item 32: the day tank was not pumped up when it ran dry")
	if dir.state.chapter == 1:
		fails.append("item 32: ch1 still stuck at beat '%s' after power came back (%.0f s)" % [dir.beat_id(), t])
	print("KITTIWAKE_POWER_OUT dead_radio_play=%s hint=%s daytank=%s chapter=%d t=%.0f" % [played_dead, power_hint,
		dir.state.has_flag("daytank_ch1"), dir.state.chapter, t])
	dir.queue_free()
	# a call at LAMP HIGH with everything on must not trip MAIN by itself
	var k2 := KeeperSim.new()
	k2.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 5)
	k2.story_mode = true
	k2.battery = 80.0
	k2.set_mode(KeeperSim.Mode.AUTO)
	k2.set_intensity(2)
	k2.set_breaker("lights", true)
	k2.set_breaker("radar", true)
	k2.spawn_story_ship({"name": "Kittiwake", "kind": "fishing", "bearing": 14, "aim": 24, "hold": true, "protected": true})
	var sid: int = k2.active_ships()[0].id
	k2.command(sid, "confirm")
	for i in 150:
		k2.step(1.0 / 30.0)
	if not k2.main_breaker:
		fails.append("item 32: a radio call at LAMP HIGH tripped MAIN on its own (draw %.2f)" % k2.demand)
	print("TX_HIGH main_breaker=%s demand=%.2f" % [k2.main_breaker, k2.demand])


func _campaign(policy: int, sc: Dictionary = {}) -> void:
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 11 + policy)
	k.story_mode = true
	var dir := StoryDirector.new()
	root.add_child(dir)
	dir.setup(k, true)
	dir.bot_choice = policy
	var prefs: Dictionary = sc.get("prefs", {})
	if not prefs.is_empty():
		dir.bot_pick_fn = func(conv: String, choices: Array) -> int:
			if prefs.has(conv):
				for c in choices:
					if String(prefs[conv]) in String(c["text"]):
						return int(c["index"])
			return 0
	var bot := KeeperBot2.new("expert", policy + 1)
	var ended := [false, {}]
	dir.campaign_finished.connect(func(e): ended[0] = true; ended[1] = e)
	if policy == 0 and sc.is_empty():
		dir.request_autosave.connect(func(): autosaves.append({"at": "ch%d:%s" % [dir.state.chapter, dir.beat_id()],
			"text": JSON.stringify({"story": dir.state.to_dict(), "sim": k.to_dict()}), "ch_start": dir.state.beat == 0 and not dir.state.in_beat}))
	dir.story_event.connect(func(n, a): if n == "sim_events": dir.on_sim_events(a[0]))
	dir.begin(true)
	var dt := 1.0 / 30.0
	var chapter_t := {}
	var guard := 0.0
	while not ended[0] and guard < 6000.0:
		guard += dt
		# the bot "player": satisfies interaction objectives after a short delay
		for f in ["moved", "looked", "used_battery", "read_log_1971", "read_log_1953", "read_letter", "at_door"]:
			if dir.state.objective != "" and guard > 2.0:
				dir.state.flags[f] = 1
		var ev: Array = []
		if sc.has("idle_at") and dir.state.chapter == 6 and dir.beat_reached(String(sc["idle_at"])):
			# the keeper frees the jam by hand but never gives her an order: nobody vectors the Iona Star
			if k.story_jam:
				if k.mode != KeeperSim.Mode.OFF:
					ev += k.set_mode(KeeperSim.Mode.OFF)
				k.set_wheel(-1.0)
			elif k.mode != KeeperSim.Mode.MANUAL:
				k.set_wheel(0.0)
				ev += k.set_mode(KeeperSim.Mode.MANUAL)
			if not k.main_breaker:
				ev += k.set_breaker("main", true)
			# ...but keeps the power up: a dead set holds the story's radio calls (brief item 32)
			ev += _keep_power(k)
		else:
			ev = bot.act(k, dt)
		ev += k.step(dt)
		dir.on_sim_events(ev)
		dir._process(dt)
		chapter_t[dir.state.chapter] = chapter_t.get(dir.state.chapter, 0.0) + dt
		if int(guard / dt) % 30 == 0:
			await process_frame
	var label: String = sc.get("name", "policy %d" % policy)
	if not ended[0]:
		fails.append("campaign %s stuck in chapter %d beat %d (objective: %s)" % [label, dir.state.chapter, dir.state.beat, dir.state.objective])
	else:
		var eid: String = ended[1].get("ending", "")
		endings[eid] = endings.get(eid, []) + [label]
		if dir.ending_lines.size() < 3 or String(ended[1].get("title", "")) == "":
			fails.append("campaign %s: ending card '%s' has no title or too few lines %s" % [label, eid, dir.ending_lines])
		if sc.has("expect") and eid != sc["expect"]:
			fails.append("campaign %s reached '%s', expected '%s'" % [label, eid, sc["expect"]])
		if eid == "nothing_to_report" and dir.state.has_flag("reunion"):
			reunion_lie = true
		if sc.get("reunion", false) and not dir.state.has_flag("reunion"):
			fails.append("campaign %s: no reunion" % label)
		if sc.get("door_shut", false) and (dir.state.has_flag("door_open") or not dir.state.has_flag("door_shut")):
			fails.append("campaign %s: the door was opened" % label)
		for ch in [2, 6]:
			if int(dir.state.flags.get("jam_cleared_ch%d" % ch, 0)) < 1:
				fails.append("campaign %s: chapter %d jam never cleared by hand" % [label, ch])
	var rounded := {}
	for c in chapter_t:
		rounded[c] = int(chapter_t[c])
	print("CAMPAIGN %s ended=%s ending=%s sim_seconds=%d per_chapter=%s rescues=%s" % [label, ended[0],
		ended[1].get("ending", "?"), int(guard), rounded, dir.state.rescues])
	if ended[0]:
		print("  CARD %s: %s" % [ended[1].get("title", ""), " | ".join(dir.ending_lines)])
	dir.queue_free()


## The beat layout the master script specifies (and that saves are remapped to).
func _check_layout() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters.json"))
	for c in data["chapters"]:
		var n := int(c["n"])
		if BEATS.has(n) and c["beats"].size() != BEATS[n]:
			fails.append("chapter %d has %d beats, the 3B layout has %d" % [n, c["beats"].size(), BEATS[n]])


## Every `!` action inside a conversation is one the runner, director or game_fp handles.
func _check_dlg_actions(db: DialogueDB) -> void:
	var known: Array = StoryDirector.ACTIONS + StoryDirector.PRESENTATION_EVENTS + ["set", "unset", "add", "clue", "wait"]
	var seen := 0
	for id in db.convs:
		for st in db.convs[id]["steps"]:
			if st["kind"] == "action":
				seen += 1
				if not (String(st["action"]) in known):
					fails.append("%s: unknown action '! %s'" % [id, st["action"]])
	print("DLG_ACTIONS checked=%d" % seen)


## Every flag and clue the story sets is read by some condition (dialogue, chapters.json) or by the
## engine (a quoted name in scripts/), except the history-only ones: no more choices that change nothing.
func _audit_flags(db: DialogueDB) -> void:
	var sets := {}
	var reads := ""
	for id in db.convs:
		for st in db.convs[id]["steps"]:
			reads += " " + String(st.get("if", ""))
			if st["kind"] == "choice":
				for ch in st["choices"]:
					reads += " " + String(ch.get("if", ""))
			if st["kind"] == "action" and String(st["action"]) in ["set", "clue", "add"]:
				var names: Array = st["args"] if String(st["action"]) != "add" else st["args"].slice(0, 1)
				for a in names:
					var nm := String(a).split("=")[0]
					if not nm.begins_with("rel."):
						sets[nm] = id
	var txt := FileAccess.get_file_as_string("res://data/story/chapters.json")
	reads += " " + txt
	var data = JSON.parse_string(txt)
	for c in data["chapters"]:
		for b in c["beats"]:
			for a in b.get("do", []):
				if String(a[0]) in ["set", "clue"]:
					sets[String(a[1]).split("=")[0]] = "chapters.json"
	for f in _gd_files("res://scripts"):
		reads += " " + FileAccess.get_file_as_string(f)
	var unread: Array = []
	for nm in sets:
		if nm in HISTORY_ONLY:
			continue
		if not ("\"%s\"" % nm in reads):
			unread.append("%s (set in %s)" % [nm, sets[nm]])
	for u in unread:
		fails.append("flag never read: " + u)
	print("FLAG_AUDIT set=%d unread=%s" % [sets.size(), unread])


func _gd_files(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		out += _gd_files(dir_path.path_join(sub))
	return out


## Saves are by beat index: an old (layout 1) ch1 / ch6 save lands on the same story moment.
func _check_remap() -> void:
	var cases := [[1, 0, 0], [1, 3, 1], [1, 5, 2], [1, 6, 3], [1, 9, 5], [1, 13, 9], [1, 14, 10], [6, 1, 4], [6, 2, 5], [2, 5, 5]]
	for c in cases:
		var got := StoryState.remap_beat(c[0], c[1], 1)
		if got != c[2]:
			fails.append("remap ch%d beat %d -> %d, expected %d" % [c[0], c[1], got, c[2]])
	var st := StoryState.new()
	st.from_dict({"chapter": 1, "beat": 8})            # a pre-3B save has no "layout"
	if st.beat != 5:
		fails.append("pre-3B ch1 save at beat 8 loaded at %d, expected 5 (kittiwake)" % st.beat)
	if StoryState.remap_beat(1, 8, StoryState.LAYOUT) != 8:
		fails.append("a current-layout save must not be remapped")


## 3B: each autosave of the policy-0 campaign is loaded into a fresh sim + director; the next conversation
## must be a new one (an autosave inside a beat used to replay that beat's talks), and a chapter-start save
## must carry that chapter's own start clock.
func _autosave_resumes() -> void:
	var lay := LayoutData.load_file()
	var checked := 0
	for snap in autosaves:
		var d: Dictionary = JSON.parse_string(snap["text"])
		var k := KeeperSim.new()
		k.setup(KeeperConfig.new(), lay, {"ships": [], "faults": []}, 11)
		k.from_dict(d["sim"])
		var dir := StoryDirector.new()
		root.add_child(dir)
		dir.setup(k, true)
		dir.load_data(d["story"])
		dir.story_event.connect(func(n, a): if n == "sim_events": dir.on_sim_events(a[0]))
		if snap["ch_start"]:
			var st: Dictionary = dir.chapter_data(dir.state.chapter).get("start", {})
			if st.has("clock") and absf(k.clock_min - float(st["clock"])) > 0.5:
				fails.append("autosave %s: clock %.1f, chapter start is %s" % [snap["at"], k.clock_min, st["clock"]])
		var done: Dictionary = dir.state.convs_done.duplicate()
		var first := [""]
		dir.line_shown.connect(func(_i): if first[0] == "": first[0] = String(dir.runner.conv.get("id", "")))
		dir.begin(false)
		var bot := KeeperBot2.new("expert", 1)
		var dt := 1.0 / 30.0
		var t := 0.0
		while first[0] == "" and t < 400.0 and not dir.finished:
			t += dt
			for f in ["moved", "looked", "used_battery", "read_log_1971", "read_log_1953", "read_letter", "at_door"]:
				dir.state.flags[f] = 1
			var ev := bot.act(k, dt) + k.step(dt)
			dir.on_sim_events(ev)
			dir._process(dt)
		if first[0] != "" and done.has(first[0]):
			fails.append("autosave %s replays '%s' after loading" % [snap["at"], first[0]])
		checked += 1
		print("  AUTOSAVE %s -> next conversation %s" % [snap["at"], first[0]])
		dir.queue_free()
		await process_frame
	if checked < 8:
		fails.append("only %d autosaves were taken in the policy-0 campaign" % checked)
	print("AUTOSAVE_RESUMES checked=%d" % checked)


## Save mid-campaign (chapter 3), round-trip through JSON text, restore into a fresh sim + director,
## compare state, then finish the campaign from the restored copy (no softlock, no duplicate events).
func _save_roundtrip() -> void:
	var lay := LayoutData.load_file()
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), lay, {"ships": [], "faults": []}, 21)
	k.story_mode = true
	var dir := StoryDirector.new()
	root.add_child(dir)
	dir.setup(k, true)
	dir.story_event.connect(func(n, a): if n == "sim_events": dir.on_sim_events(a[0]))
	dir.begin(true)
	var bot := KeeperBot2.new("expert", 3)
	var dt := 1.0 / 30.0
	var guard := 0.0
	while not (dir.state.chapter == 3 and dir.state.beat >= 1 and not dir.is_talking() and dir._actions.is_empty() and dir._wait <= 0.0) and guard < 3000.0:
		guard += dt
		for f in ["moved", "looked", "used_battery", "read_log_1971", "read_log_1953", "read_letter", "at_door"]:
			dir.state.flags[f] = 1
		var ev := bot.act(k, dt) + k.step(dt)
		dir.on_sim_events(ev)
		dir._process(dt)
	var text := JSON.stringify({"story": dir.state.to_dict(), "sim": k.to_dict()})
	var d: Dictionary = JSON.parse_string(text)
	var k2 := KeeperSim.new()
	k2.setup(KeeperConfig.new(), lay, {"ships": [], "faults": []}, 21)
	k2.from_dict(d["sim"])
	var dir2 := StoryDirector.new()
	root.add_child(dir2)
	dir2.setup(k2, true)
	dir2.load_data(d["story"])
	dir2.story_event.connect(func(n, a): if n == "sim_events": dir2.on_sim_events(a[0]))
	var ok: bool = dir2.state.chapter == dir.state.chapter and dir2.state.beat == dir.state.beat \
		and dir2.state.flags.size() == dir.state.flags.size() and absf(k2.battery - k.battery) < 0.01 \
		and k2.ships.size() == k.ships.size() and absf(k2.clock_min - k.clock_min) < 0.01 and k2.mode == k.mode
	if not ok:
		fails.append("save roundtrip mismatch: ch %d/%d beat %d/%d flags %d/%d ships %d/%d" % [dir.state.chapter, dir2.state.chapter,
			dir.state.beat, dir2.state.beat, dir.state.flags.size(), dir2.state.flags.size(), k.ships.size(), k2.ships.size()])
	var ended := [false]
	dir2.campaign_finished.connect(func(_e): ended[0] = true)
	dir2.begin(false)
	var spawned := {}
	guard = 0.0
	var bot2 := KeeperBot2.new("expert", 3)
	while not ended[0] and guard < 6000.0:
		guard += dt
		for f in ["moved", "looked", "used_battery", "read_log_1971", "read_log_1953", "read_letter", "at_door"]:
			dir2.state.flags[f] = 1
		var ev := bot2.act(k2, dt) + k2.step(dt)
		for e in ev:
			if e["type"] == "ship_spawned":
				spawned[e["name"]] = spawned.get(e["name"], 0) + 1
		dir2.on_sim_events(ev)
		dir2._process(dt)
	spawned = {}
	for sh in k2.ships:
		spawned[sh.name] = spawned.get(sh.name, 0) + 1
	var dupes := spawned.keys().filter(func(n): return spawned[n] > 1)
	if not ended[0]:
		fails.append("restored campaign did not finish (chapter %d beat %d)" % [dir2.state.chapter, dir2.state.beat])
	# Kittiwake/Gannet were spawned before the save and must appear exactly once (restored, not re-spawned)
	if not dupes.is_empty() or spawned.get("Kittiwake", 0) != 1 or not spawned.has("Iona Star"):
		fails.append("restored campaign duplicated events: %s" % spawned)
	print("SAVE_ROUNDTRIP saved_at=ch%d beat%d restored_ok=%s finished=%s spawned_after_load=%s" % [dir.state.chapter, dir.state.beat, ok, ended[0], spawned])
	dir.queue_free()
	dir2.queue_free()


func _save_files() -> void:
	var ss: Node = load("res://scripts/save_system.gd").new()
	ss._ready()
	var data := {"story": {"chapter": 2, "play_seconds": 600}, "sim": {"battery": 50}, "chapter_title": "Strange Signals", "clock": "00:10"}
	ss.write("3", data)
	var back: Dictionary = ss.read("3")
	var f := FileAccess.open(ss.path("2"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var bad: Dictionary = ss.read("2")
	var ok: bool = back.get("chapter_title", "") == "Strange Signals" and bad.has("corrupt") and not ss.exists("2") and ss.read("nope").is_empty()
	if not ok:
		fails.append("save files: write/read/corrupt handling failed %s %s" % [back, bad])
	print("SAVE_FILES ok=%s summary=%s" % [ok, ss.summary("3")])
	ss.delete("2")
	ss.delete("3")
	ss.free()
