extends SceneTree
## Full-night bot simulations (headless, fixed dt 1/60).
##   godot --headless --path godot -s res://tests/sim.gd -- --bots=idle,expert,average --seeds=1-10 [--verbose]
## Prints SIM_RESULT {json} with per-bot summaries; exit 1 if the fairness/difficulty gates fail.
## Gates (DESIGN.md): idle loses every seed; expert wins every seed; average wins >= 50% of seeds
## with 1-4 ships lost on wins; no ship ever wrecks after it found its bearings (LOCKED).

const DT := 1.0 / 60.0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var bots: PackedStringArray = String(args.get("bots", "idle,expert,average")).split(",")
	var seeds := _parse_range(String(args.get("seeds", "1-10")))
	var verbose := args.has("verbose")
	var layout := LayoutData.load_file()
	var waves := WaveSchedule.load_data()
	var summary := {}
	var gate_fail: Array[String] = []
	for bot_mode in bots:
		var runs: Array = []
		for sd in seeds:
			runs.append(run_one(bot_mode, sd, layout, waves, verbose))
		var s := summarize(runs)
		summary[bot_mode] = s
		match bot_mode:
			"idle":
				if s["wins"] > 0:
					gate_fail.append("idle bot won %d seeds" % s["wins"])
			"expert":
				if s["wins"] < seeds.size():
					gate_fail.append("expert bot lost %d seeds (unfair spawns?)" % (seeds.size() - s["wins"]))
			"average":
				if s["wins"] * 2 < seeds.size():
					gate_fail.append("average bot wins only %d/%d" % [s["wins"], seeds.size()])
		if s["locked_wrecks"] > 0:
			gate_fail.append("%s: %d ships wrecked after finding bearings" % [bot_mode, s["locked_wrecks"]])
	print("SIM_RESULT ", JSON.stringify({"summary": summary, "gate_failures": gate_fail}))
	quit(1 if gate_fail.size() > 0 else 0)


func run_one(bot_mode: String, sd: int, layout: LayoutData, waves: Dictionary, verbose: bool) -> Dictionary:
	var w := SimWorld.new()
	w.setup(GameConfig.new(), layout, waves, sd)
	var bot := KeeperBot.new(bot_mode, sd)
	var wrecks: Array = []
	var locked_wrecks := 0
	var idle_time := 0.0
	var longest_idle := 0.0
	var boost_time := 0.0
	var max_active := 0
	var first_seen := {}      # id -> t when within beam range (could be lit)
	var slack := []           # per rescued ship: tti when locked
	while w.result == SimWorld.Result.RUNNING and w.t < 900.0:
		var d := bot.decide(w, DT)
		# snapshot states before stepping to classify wrecks
		var before := {}
		for s in w.ships:
			before[s.id] = {"state": s.state, "meter": s.meter, "ever_lit": s.ever_lit, "kind": s.kind,
				"tti": s.tti, "bearing": rad_to_deg(Geo.bearing_of(s.pos)), "dist": s.pos.length()}
		var ev := w.step(DT, d["turn"], d["boost"])
		if w.beam.boosting:
			boost_time += DT
		var act := w.active_ships()
		max_active = maxi(max_active, act.size())
		for s in act:
			if not first_seen.has(s.id) and s.pos.length() <= w.cfg.beam_range:
				first_seen[s.id] = w.t
		if act.is_empty() and w.t > 30.0 and w.t < w.cfg.shift_length:
			idle_time += DT
			longest_idle = maxf(longest_idle, idle_time)
		else:
			idle_time = 0.0
		for e in ev:
			match e["type"]:
				"ship_wrecked":
					var b: Dictionary = before.get(e["id"], {})
					if b.get("state", -1) == ShipModel.State.LOCKED:
						locked_wrecks += 1
					var info := b.duplicate()
					info["t"] = snappedf(w.t, 0.1)
					info["id"] = e["id"]
					info["seen_for"] = snappedf(w.t - first_seen.get(e["id"], w.t), 0.1)
					wrecks.append(info)
				"ship_locked":
					var sh := w.find_ship(e["id"])
					if sh:
						slack.append(sh.tti)
	var st := w.stats()
	st["bot"] = bot_mode
	st["locked_wrecks"] = locked_wrecks
	st["longest_idle"] = snappedf(longest_idle, 0.1)
	st["boost_time"] = snappedf(boost_time, 0.1)
	st["max_active"] = max_active
	st["wrecks"] = wrecks
	st["lock_tti_min"] = snappedf(slack.min() if slack.size() else -1.0, 0.1)
	if verbose:
		print("RUN ", JSON.stringify(st))
	return st


func summarize(runs: Array) -> Dictionary:
	var wins := 0
	var lost_on_wins: Array = []
	var scores: Array = []
	var locked_wrecks := 0
	var idle := 0.0
	var max_active := 0
	var durations: Array = []
	for r in runs:
		if r["result"] == "won":
			wins += 1
			lost_on_wins.append(r["lost"])
		scores.append(r["score"])
		durations.append(r["time"])
		locked_wrecks += r["locked_wrecks"]
		idle = maxf(idle, r["longest_idle"])
		max_active = maxi(max_active, r["max_active"])
	return {
		"runs": runs.size(), "wins": wins, "lost_on_wins": lost_on_wins, "score_min": scores.min(),
		"score_max": scores.max(), "locked_wrecks": locked_wrecks, "longest_idle": idle,
		"max_active": max_active, "duration_min": durations.min(), "duration_max": durations.max(),
	}


func _parse_range(s: String) -> Array[int]:
	var out: Array[int] = []
	for part in s.split(","):
		if "-" in part:
			var ab := part.split("-")
			for i in range(int(ab[0]), int(ab[1]) + 1):
				out.append(i)
		elif part != "":
			out.append(int(part))
	return out
