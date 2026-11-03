extends SceneTree
## Headless unit tests.  godot --headless --path godot -s res://tests/run_tests.gd
## Exit code 0 = all passed. Prints TEST_RESULT {json}.

var _fails: Array[String] = []
var _count := 0


func check(cond: bool, label: String) -> void:
	_count += 1
	if not cond:
		_fails.append(label)
		printerr("FAIL: ", label)


func near(a: float, b: float, eps: float = 1e-3) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	test_geo()
	test_beam_lighting()
	test_beam_energy()
	test_beam_rotation_easing()
	test_layout_and_routes()
	test_schedule()
	test_ship_lock_and_rescue()
	test_unlit_ship_wrecks()
	test_scoring_and_streak()
	test_restart_is_clean()
	test_defeat_and_victory()
	test_input_actions()
	print("TEST_RESULT ", JSON.stringify({"tests": _count, "failed": _fails.size(), "failures": _fails}))
	quit(1 if _fails.size() > 0 else 0)


func new_world(seed_value: int = 1) -> SimWorld:
	var w := SimWorld.new()
	w.setup(GameConfig.new(), LayoutData.load_file(), WaveSchedule.load_data(), seed_value)
	return w


func empty_world() -> SimWorld:
	var w := SimWorld.new()
	w.setup(GameConfig.new(), LayoutData.load_file(), {"ships": [], "gusts": []}, 1)
	return w


# ------------------------------------------------------------------ tests

func test_geo() -> void:
	check(Geo.dir(0.0).distance_to(Vector2(0, -1)) < 1e-6, "geo: bearing 0 = north (-z)")
	check(Geo.dir(PI / 2).distance_to(Vector2(1, 0)) < 1e-6, "geo: bearing 90 = east (+x)")
	check(near(Geo.bearing_of(Vector2(-1, 0)), -PI / 2), "geo: bearing_of west")
	check(near(Geo.angle_diff(deg_to_rad(170), deg_to_rad(-170)), deg_to_rad(20)), "geo: angle_diff wraps")
	check(near(Geo.ray_circle(Vector2.ZERO, Vector2(1, 0), Vector2(10, 0), 2.0), 8.0), "geo: ray hits circle")
	check(Geo.ray_circle(Vector2.ZERO, Vector2(-1, 0), Vector2(10, 0), 2.0) == INF, "geo: ray behind misses")
	# Node3D yaw: local -Z rotated by yaw must equal dir(bearing)
	var b := deg_to_rad(37.0)
	var fwd := Basis(Vector3.UP, Geo.yaw_for(b)) * Vector3(0, 0, -1)
	check(Vector2(fwd.x, fwd.z).distance_to(Geo.dir(b)) < 1e-5, "geo: yaw_for matches bearing")


func test_beam_lighting() -> void:
	var cfg := GameConfig.new()
	var beam := BeamModel.new(cfg)
	beam.bearing = 0.0
	check(beam.lights(Vector2(0, -100), 3.0), "beam: lights ship dead ahead")
	check(not beam.lights(Vector2(0, 100), 3.0), "beam: not behind")
	check(not beam.lights(Vector2(0, -200), 3.0), "beam: out of normal range")
	var off := Geo.polar(deg_to_rad(8.0), 100.0)
	check(not beam.lights(off, 0.5), "beam: 8 deg off is outside 6 deg cone")
	beam.boosting = true
	check(beam.lights(off, 0.5), "beam: boost widens cone")
	check(beam.lights(Vector2(0, -205), 3.0), "beam: boost extends range")
	beam.boosting = false
	beam.bearing = deg_to_rad(179.0)
	check(beam.lights(Geo.polar(deg_to_rad(-179.0), 80.0), 1.0), "beam: wraparound at +-180")


func test_beam_energy() -> void:
	var cfg := GameConfig.new()
	var beam := BeamModel.new(cfg)
	var ev: Array = []
	for i in 60:
		beam.step(1.0 / 60.0, 0.0, true, ev)
	check(near(beam.energy, 100.0 - cfg.energy_drain, 0.5), "energy: drains 22/s while boosting")
	check(ev.any(func(e): return e["type"] == "boost_on"), "energy: boost_on event")
	for i in 60 * 10:
		beam.step(1.0 / 60.0, 0.0, true, ev)
	check(beam.locked_out and beam.energy == 0.0, "energy: lockout at zero")
	check(not beam.boosting, "energy: cannot boost when empty")
	check(ev.any(func(e): return e["type"] == "energy_low"), "energy: low warning fired")
	# holding boost during lockout must not drain; regen resumes after delay
	for i in 60 * 3:
		beam.step(1.0 / 60.0, 0.0, true, ev)
	check(beam.energy > 15.0 and beam.locked_out, "energy: regen while locked out")
	for i in 60 * 2:
		beam.step(1.0 / 60.0, 0.0, true, ev)
	check(not beam.locked_out, "energy: lockout ends at 30")


func test_beam_rotation_easing() -> void:
	var cfg := GameConfig.new()
	var beam := BeamModel.new(cfg)
	var ev: Array = []
	beam.step(1.0 / 60.0, 1.0, false, ev)
	check(beam.ang_vel > 0.0 and beam.ang_vel < deg_to_rad(cfg.beam_max_speed_deg), "rotation: eases in")
	for i in 60:
		beam.step(1.0 / 60.0, 1.0, false, ev)
	check(near(beam.ang_vel, deg_to_rad(cfg.beam_max_speed_deg)), "rotation: reaches max speed")
	var b0 := beam.bearing
	for i in 60:
		beam.step(1.0 / 60.0, 0.0, false, ev)
	check(near(beam.ang_vel, 0.0) and beam.bearing > b0, "rotation: eases out, keeps direction")
	beam.step(1.0 / 60.0, -1.0, false, ev)
	check(beam.ang_vel < 0.0, "rotation: reverses")


func test_layout_and_routes() -> void:
	var L := LayoutData.load_file()
	check(L != null and L.reefs.size() > 15, "layout: loads reefs")
	check(L.channels.size() == 3, "layout: three channels")
	for c in L.channels:
		for side in c["routes"]:
			var pts: PackedVector2Array = c["routes"][side]
			check(absf(pts[pts.size() - 1].x) > 150.0, "layout: route %s ends at a side exit" % side)
			check(absf(Geo.angle_diff(c["bearing"], Geo.bearing_of(pts[0]))) < 0.01, "layout: route starts on channel bearing")
	check(L.route_for(deg_to_rad(10))[-1].x > 0.0, "layout: north-east ships exit east")
	check(L.route_for(deg_to_rad(-10))[-1].x < 0.0, "layout: north-west ships exit west")


func test_schedule() -> void:
	var a := new_world(3)
	var b := new_world(3)
	var c := new_world(4)
	check(a.schedule.spawns.size() >= 18, "schedule: at least 18 ships")
	check(a.schedule.spawns[0]["t"] == b.schedule.spawns[0]["t"] and a.schedule.spawns[5]["bearing"] == b.schedule.spawns[5]["bearing"], "schedule: seed is deterministic")
	var differs := false
	for i in a.schedule.spawns.size():
		if a.schedule.spawns[i]["t"] != c.schedule.spawns[i]["t"]:
			differs = true
	check(differs, "schedule: different seeds vary timing")
	for i in range(1, a.schedule.spawns.size()):
		check(a.schedule.spawns[i]["t"] >= a.schedule.spawns[i - 1]["t"], "schedule: sorted")
	check(a.schedule.spawns[0]["t"] == 3.0, "schedule: tutorial ship is fixed")


func test_ship_lock_and_rescue() -> void:
	var w := empty_world()
	var s := w.spawn_ship("fishing", 0.0)
	w.beam.bearing = 0.0
	var events: Array = []
	var locked_at := -1.0
	var first_lit := -1.0
	for i in 60 * 120:
		# keep the beam on the ship like a perfect keeper
		w.beam.bearing = Geo.bearing_of(s.pos)
		var ev := w.step(1.0 / 60.0, 0.0, false)
		events.append_array(ev)
		if first_lit < 0.0 and s.lit:
			first_lit = w.t - 1.0 / 60.0
		if locked_at < 0.0 and s.state == ShipModel.State.LOCKED:
			locked_at = w.t - first_lit
		if not s.is_active():
			break
	check(locked_at > 1.9 and locked_at < 2.3, "ship: fishing boat locks after ~2 s of light (%.2f)" % locked_at)
	check(s.state == ShipModel.State.RESCUED, "ship: locked ship reaches exit -> rescued (state %d)" % s.state)
	check(w.rescued == 1 and w.score == 100, "ship: rescue scores base value (%d)" % w.score)
	check(events.any(func(e): return e["type"] == "ship_locked"), "ship: lock event")
	check(events.any(func(e): return e["type"] == "ship_rescued"), "ship: rescue event")


func test_unlit_ship_wrecks() -> void:
	var w := empty_world()
	w.beam.bearing = PI  # pointing south, away from every ship
	var s := w.spawn_ship("schooner", deg_to_rad(30.0))
	var warned := false
	for i in 60 * 90:
		for e in w.step(1.0 / 60.0, 0.0, false):
			if e["type"] == "ship_warning":
				warned = true
		if not s.is_active():
			break
	check(s.state == ShipModel.State.WRECKED, "ship: blind ship hits a reef")
	check(warned, "ship: warning fires before impact")
	check(w.lost == 1 and w.streak == 0, "ship: wreck counts as lost")


func test_scoring_and_streak() -> void:
	var w := empty_world()
	var s1 := w.spawn_ship("fishing", 0.0)
	w._resolve(s1, ShipModel.State.RESCUED, [])
	var s2 := w.spawn_ship("schooner", 0.0)
	w._resolve(s2, ShipModel.State.RESCUED, [])
	check(w.score == 100 + 165, "score: second rescue gets +10%% streak (%d)" % w.score)
	var s3 := w.spawn_ship("steamer", 0.0)
	s3.close_call = true
	w._resolve(s3, ShipModel.State.RESCUED, [])
	check(w.score == 265 + 300 + 50, "score: streak x1.2 plus close-call bonus (%d)" % w.score)
	var s4 := w.spawn_ship("fishing", 0.0)
	w._resolve(s4, ShipModel.State.WRECKED, [])
	check(w.streak == 0 and w.best_streak == 3, "score: wreck resets streak, best kept")


func test_restart_is_clean() -> void:
	var a := new_world(5)
	for i in 60 * 40:
		a.step(1.0 / 60.0, 1.0, i % 3 == 0)
	var b := new_world(5)
	check(b.t == 0.0 and b.ships.is_empty() and b.score == 0 and b.lost == 0 and b.rescued == 0, "restart: fresh world")
	check(b.beam.energy == b.cfg.energy_max and b.beam.bearing == 0.0, "restart: beam reset")
	# same seed + same inputs = identical outcome (determinism)
	var c := new_world(5)
	for i in 60 * 40:
		b.step(1.0 / 60.0, 1.0, i % 3 == 0)
		c.step(1.0 / 60.0, 1.0, i % 3 == 0)
	check(b.stats() == c.stats() and b.ships.size() == c.ships.size(), "restart: deterministic replay")
	var gs: Node = load("res://scripts/game_state.gd").new()
	gs.reset_session()
	gs.record_result({"score": 500})
	gs.record_result({"score": 300})
	check(gs.best_score == 500 and gs.games_played == 2, "session: personal best kept")
	gs.free()


func test_defeat_and_victory() -> void:
	var w := new_world(2)
	var bot := KeeperBot.new("idle", 2)
	while w.result == SimWorld.Result.RUNNING and w.t < 600.0:
		var d := bot.decide(w, 1.0 / 60.0)
		w.step(1.0 / 60.0, d["turn"], d["boost"])
	check(w.result == SimWorld.Result.LOST, "end: idle keeper loses (t=%.0f)" % w.t)
	check(w.lost == w.cfg.max_lost, "end: defeat exactly at max lost")
	var v := new_world(2)
	var ex := KeeperBot.new("expert", 2)
	while v.result == SimWorld.Result.RUNNING and v.t < 700.0:
		var d := ex.decide(v, 1.0 / 60.0)
		v.step(1.0 / 60.0, d["turn"], d["boost"])
	check(v.result == SimWorld.Result.WON, "end: expert keeper wins (%s)" % JSON.stringify(v.stats()))
	check(v.t >= v.cfg.shift_length, "end: victory only after the shift")


func test_input_actions() -> void:
	InputSetup.ensure()
	for a in ["beam_left", "beam_right", "boost", "pause"]:
		check(InputMap.has_action(a), "input: action %s exists" % a)
	check(_has_key("beam_left", KEY_A) and _has_key("beam_left", KEY_LEFT), "input: A and Left turn left")
	check(_has_key("beam_right", KEY_D) and _has_key("beam_right", KEY_RIGHT), "input: D and Right turn right")
	check(_has_key("boost", KEY_SPACE), "input: Space boosts")
	check(_has_key("pause", KEY_ESCAPE), "input: Escape pauses")


func _has_key(action: String, key: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e.physical_keycode == key or e.keycode == key):
			return true
	return false
