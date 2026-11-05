extends SceneTree
## Story QA (headless):
##  1. every .dlg parses and every jump target exists
##  2. every conversation is walked through ALL choice paths (DFS) with permissive flags: no dead ends/loops
##  3. full campaign playthroughs (StoryDirector bot mode + KeeperBot2 at the station) for several choice
##     policies: each must reach the campaign end without a softlock, and reports the ending + sim time.
##   godot --headless --path godot -s res://tests/story_test.gd [-- --policies=0,1,2 --quick]

var fails: Array[String] = []


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
	for p in policies:
		await _campaign(int(p))
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
				if k == "hint" and o[k] is Array and o[k].size() == 2:
					for pad in [false, true]:           # Stage 2C: glyph tokens resolve for both devices
						InputSetup.pad_active = pad
						var r: String = InputSetup.resolve(String(o[k][1]))
						if "{" in r or "}" in r:
							fails.append("chapters.json: unresolved hint token in '%s'" % r)
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


func _campaign(policy: int) -> void:
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 11 + policy)
	k.story_mode = true
	var dir := StoryDirector.new()
	root.add_child(dir)
	dir.setup(k, true)
	dir.bot_choice = policy
	var bot := KeeperBot2.new("expert", policy + 1)
	var ended := [false, {}]
	dir.campaign_finished.connect(func(e): ended[0] = true; ended[1] = e)
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
		var ev := bot.act(k, dt)
		ev += k.step(dt)
		dir.on_sim_events(ev)
		dir._process(dt)
		chapter_t[dir.state.chapter] = chapter_t.get(dir.state.chapter, 0.0) + dt
		if int(guard / dt) % 30 == 0:
			await process_frame
	if not ended[0]:
		fails.append("campaign policy %d stuck in chapter %d beat %d (objective: %s)" % [policy, dir.state.chapter, dir.state.beat, dir.state.objective])
	var rounded := {}
	for c in chapter_t:
		rounded[c] = int(chapter_t[c])
	print("CAMPAIGN policy=%d ended=%s ending=%s sim_seconds=%d per_chapter=%s rescues=%s" % [policy, ended[0],
		{"truth": ended[1].get("truth"), "iona": ended[1].get("iona_saved")}, int(guard), rounded, dir.state.rescues])
	dir.queue_free()


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
