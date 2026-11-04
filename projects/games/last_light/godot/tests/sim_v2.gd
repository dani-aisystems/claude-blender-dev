extends SceneTree
## Full-night simulations of the v2 keeper rules (headless, dt 1/60).
##   godot --headless --path godot -s res://tests/sim_v2.gd -- --bots=idle,expert,novice --seeds=1-10 [--verbose]
## Gates: idle loses every seed; expert wins every seed (every rescue is solvable) with no battery death;
## novice wins >= 40% of seeds (beatable without mastery, but not trivial).

const DT := 1.0 / 60.0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var bots: PackedStringArray = String(args.get("bots", "idle,expert,novice")).split(",")
	var seeds := _range(String(args.get("seeds", "1-10")))
	var layout := LayoutData.load_file()
	var night: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/night.json"))
	var summary := {}
	var gates: Array[String] = []
	for b in bots:
		var runs: Array = []
		for sd in seeds:
			runs.append(run_one(b, sd, layout, night, args.has("verbose")))
		var wins := runs.filter(func(r): return r["result"] == "won").size()
		var deaths := 0
		for r in runs:
			deaths += r["battery_deaths"]
		summary[b] = {"wins": wins, "runs": runs.size(), "saved": runs.map(func(r): return r["saved"]),
			"lost": runs.map(func(r): return r["lost"]), "score": runs.map(func(r): return r["score"]),
			"battery_deaths": deaths, "min_battery": runs.map(func(r): return r["min_battery"]),
			"fuel_left": runs.map(func(r): return r["fuel"]), "orders": runs.map(func(r): return r["orders"]),
			"time": runs.map(func(r): return r["time"])}
		match b:
			"idle":
				if wins > 0:
					gates.append("idle won %d" % wins)
			"expert":
				if wins < seeds.size():
					gates.append("expert lost %d nights (unsolvable rescue?)" % (seeds.size() - wins))
				if deaths > 0:
					gates.append("expert let the battery die %d times" % deaths)
			"novice":
				if wins * 10 < seeds.size() * 4:
					gates.append("novice wins only %d/%d" % [wins, seeds.size()])
	print("SIM2_RESULT ", JSON.stringify({"summary": summary, "gate_failures": gates}))
	quit(1 if gates.size() > 0 else 0)


func run_one(bot_mode: String, sd: int, layout: LayoutData, night: Dictionary, verbose: bool) -> Dictionary:
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), layout, night, sd)
	var bot := KeeperBot2.new(bot_mode, sd)
	var deaths := 0
	var min_batt := 100.0
	var log_lines: Array = []
	while k.result == KeeperSim.Result.RUNNING and k.t < 1200.0:
		bot.act(k, DT)
		for e in k.step(DT):
			if e["type"] == "battery_dead":
				deaths += 1
			if verbose and e["type"] in ["ship_lost", "ship_saved", "ship_piloting", "jam", "breaker_trip", "gen_overheat", "battery_dead", "gen_start"]:
				log_lines.append("%6.1f %s %s" % [k.t, e["type"], e.get("name", e.get("cause", ""))])
		min_batt = minf(min_batt, k.battery)
	var st := k.stats()
	st["battery_deaths"] = deaths
	st["min_battery"] = snappedf(min_batt, 0.1)
	st["orders"] = bot.orders_sent
	if verbose:
		print("RUN ", bot_mode, " seed ", sd, " ", JSON.stringify(st))
		for l in log_lines:
			print("   ", l)
	return st


func _range(s: String) -> Array[int]:
	var out: Array[int] = []
	for part in s.split(","):
		if "-" in part:
			var ab := part.split("-")
			for i in range(int(ab[0]), int(ab[1]) + 1):
				out.append(i)
		elif part != "":
			out.append(int(part))
	return out
