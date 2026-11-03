class_name SimWorld
extends RefCounted
## The whole game rules in one deterministic, node-free object.
## The game scene, the unit tests and the bot simulations all drive this same class.

enum Result { RUNNING, WON, LOST }

var cfg: GameConfig
var layout: LayoutData
var schedule: WaveSchedule
var rng := RandomNumberGenerator.new()
var beam: BeamModel
var ships: Array[ShipModel] = []
var hazards: Array[Dictionary] = []      # reefs + island, {pos, r}
var t := 0.0
var storm := 0.0
var result := Result.RUNNING
var rescued := 0
var lost := 0
var score := 0
var streak := 0
var best_streak := 0
var close_calls := 0
var gust_drift := Vector2.ZERO
var seed_used := 0
var _next_spawn := 0
var _next_id := 1
var _next_lightning := 0.0
var _gust_warned: Array[bool] = []
var _gust_started: Array[bool] = []


func setup(config: GameConfig, layout_data: LayoutData, waves: Dictionary, seed_value: int) -> void:
	cfg = config
	layout = layout_data
	seed_used = seed_value
	rng.seed = seed_value
	schedule = WaveSchedule.build(waves, cfg, rng, layout)
	beam = BeamModel.new(cfg)
	hazards.clear()
	for r in layout.reefs:
		hazards.append({"pos": r["pos"], "r": r["r"]})
	hazards.append({"pos": Vector2.ZERO, "r": layout.island_radius})
	_next_lightning = 14.0 + rng.randf_range(0.0, 6.0)
	_gust_warned.resize(schedule.gusts.size())
	_gust_started.resize(schedule.gusts.size())
	_gust_warned.fill(false)
	_gust_started.fill(false)


func night_progress() -> float:
	return clampf(t / cfg.shift_length, 0.0, 1.0)


func active_ships() -> Array[ShipModel]:
	var out: Array[ShipModel] = []
	for s in ships:
		if s.is_active():
			out.append(s)
	return out


func ships_total() -> int:
	return schedule.spawns.size()


func stats() -> Dictionary:
	return {
		"result": ["running", "won", "lost"][result], "time": snappedf(t, 0.01), "rescued": rescued,
		"lost": lost, "score": score, "best_streak": best_streak, "close_calls": close_calls,
		"ships_total": ships_total(), "seed": seed_used,
	}


## Advance the world by dt. Returns this step's events (Array of Dictionaries).
func step(dt: float, turn_axis: float, boost_held: bool) -> Array:
	var events: Array = []
	if result != Result.RUNNING:
		return events
	t += dt
	storm = cfg.storm_at(t)
	beam.step(dt, turn_axis, boost_held, events)
	_spawn_due(events)
	_weather(events)
	var speed_mul := lerpf(1.0, cfg.storm_speed_mul_max, storm)
	for s in ships:
		if s.is_active():
			_step_ship(s, dt, speed_mul, events)
	var keep: Array[ShipModel] = []
	for s in ships:
		if s.is_active() or t - s.resolve_time < 12.0:   # keep wrecks a while for visuals
			keep.append(s)
	ships = keep
	_check_end(events)
	return events


# ---------------------------------------------------------------- spawning

func _spawn_due(events: Array) -> void:
	while _next_spawn < schedule.spawns.size() and schedule.spawns[_next_spawn]["t"] <= t:
		var e: Dictionary = schedule.spawns[_next_spawn]
		_next_spawn += 1
		var s := spawn_ship(e["kind"], e["bearing"], e["speed_mul"])
		events.append({"type": "ship_spawned", "id": s.id, "kind": s.kind, "bearing": s.spawn_bearing})


func spawn_ship(kind: String, bearing: float, speed_mul: float = 1.0) -> ShipModel:
	var p := cfg.ship(kind)
	var s := ShipModel.new()
	s.id = _next_id
	_next_id += 1
	s.kind = kind
	s.speed = p["speed"] * speed_mul
	s.turn_rate = deg_to_rad(p["turn_deg"])
	s.radius = p["radius"]
	s.need = p["need"]
	s.value = p["value"]
	s.spawn_bearing = bearing
	s.spawn_time = t
	s.pos = Geo.polar(bearing, layout.spawn_radius)
	s.route = layout.route_for(bearing)
	s.blind_target = _pick_blind_target(bearing)
	s.heading = Geo.bearing_of(s.blind_target - s.pos)
	ships.append(s)
	return s


func _pick_blind_target(bearing: float) -> Vector2:
	# The reef this captain cannot see: one of the closest few by bearing.
	var cands := layout.reefs.duplicate()
	cands.sort_custom(func(a, b):
		return absf(Geo.angle_diff(bearing, Geo.bearing_of(a["pos"]))) < absf(Geo.angle_diff(bearing, Geo.bearing_of(b["pos"]))))
	var pick: Dictionary = cands[rng.randi_range(0, mini(2, cands.size() - 1))]
	return pick["pos"]


# ---------------------------------------------------------------- weather

func _weather(events: Array) -> void:
	if t >= _next_lightning:
		var interval := lerpf(cfg.lightning_interval_calm, cfg.lightning_interval_storm, storm)
		_next_lightning = t + interval * rng.randf_range(0.7, 1.3)
		events.append({"type": "lightning", "power": 0.55 + 0.45 * storm, "thunder_delay": rng.randf_range(0.4, 2.2)})
	gust_drift = Vector2.ZERO
	for i in schedule.gusts.size():
		var g: Dictionary = schedule.gusts[i]
		if not _gust_warned[i] and t >= g["t"] - cfg.gust_telegraph:
			_gust_warned[i] = true
			events.append({"type": "gust_warning", "dir": g["dir"]})
		var u: float = (t - g["t"]) / cfg.gust_duration
		if u >= 0.0 and u <= 1.0:
			if not _gust_started[i]:
				_gust_started[i] = true
				events.append({"type": "gust_start", "dir": g["dir"]})
			gust_drift += Vector2(g["dir"] * cfg.gust_drift * sin(u * PI), 0.0)


# ---------------------------------------------------------------- ships

func _step_ship(s: ShipModel, dt: float, speed_mul: float, events: Array) -> void:
	var was_lit := s.lit
	s.lit = beam.lights(s.pos, s.radius)
	if s.lit and not was_lit and s.state == ShipModel.State.SAILING:
		events.append({"type": "ship_lit", "id": s.id})
	var speed_now := s.speed * speed_mul
	if s.state == ShipModel.State.SAILING and s.lit:
		speed_now *= cfg.lit_speed_mul
	elif s.state == ShipModel.State.LOCKED and s.seg < 3:
		speed_now *= cfg.locked_speed_mul
	var desired: float
	var turn := s.turn_rate
	if s.state == ShipModel.State.SAILING:
		if s.lit:
			s.ever_lit = true
			s.meter += dt / s.need * beam.fill_mul()
		else:
			s.meter = maxf(0.0, s.meter - cfg.meter_decay * dt)
		if s.meter >= 1.0:
			s.meter = 1.0
			s.state = ShipModel.State.LOCKED
			s.close_call = s.tti < cfg.close_call_tti
			s.warning = false
			events.append({"type": "ship_locked", "id": s.id, "close_call": s.close_call})
	if s.state == ShipModel.State.LOCKED or s.lit:
		desired = s.avoid_heading(s.pursue(cfg.path_lookahead, cfg.path_capture), hazards, cfg)
	else:
		desired = Geo.bearing_of(s.blind_target - s.pos)
		turn *= cfg.unlit_turn_mul
	s.heading = Geo.turn_toward(s.heading, desired, turn * dt)
	s.velocity = Geo.dir(s.heading) * speed_now
	if s.state == ShipModel.State.SAILING:
		s.velocity += gust_drift
	s.pos += s.velocity * dt

	if (s.state == ShipModel.State.LOCKED or s.lit) and s.at_route_end(cfg.exit_reach):
		_resolve(s, ShipModel.State.RESCUED, events)
		return

	# collisions. Rule: a ship that found its bearings (LOCKED) is safe - it steers around rocks
	# and is never wrecked. Fill the meter before impact and the ship is saved.
	if s.state == ShipModel.State.SAILING:
		for h in hazards:
			if s.pos.distance_to(h["pos"]) < h["r"] + s.radius:
				_resolve(s, ShipModel.State.WRECKED, events)
				return
	if s.pos.length() > cfg.stray_radius:
		_resolve(s, ShipModel.State.STRAYED, events)
		return

	s.tti = s.compute_tti(hazards, speed_now)
	var warn := s.state == ShipModel.State.SAILING and s.tti < cfg.warning_tti
	if warn and not s.warning:
		events.append({"type": "ship_warning", "id": s.id})
	s.warning = warn


func _resolve(s: ShipModel, state: int, events: Array) -> void:
	s.state = state
	s.resolve_time = t
	s.lit = false
	s.warning = false
	match state:
		ShipModel.State.RESCUED:
			rescued += 1
			streak += 1
			best_streak = maxi(best_streak, streak)
			var mul := 1.0 + cfg.streak_bonus_step * mini(streak - 1, cfg.streak_bonus_cap)
			var pts := int(round(s.value * mul)) + (cfg.close_call_bonus if s.close_call else 0)
			if s.close_call:
				close_calls += 1
			score += pts
			events.append({"type": "ship_rescued", "id": s.id, "points": pts, "close_call": s.close_call, "streak": streak})
		ShipModel.State.WRECKED:
			lost += 1
			streak = 0
			events.append({"type": "ship_wrecked", "id": s.id, "pos": s.pos})
		ShipModel.State.STRAYED:
			events.append({"type": "ship_strayed", "id": s.id})


func _check_end(events: Array) -> void:
	if lost >= cfg.max_lost:
		result = Result.LOST
		events.append({"type": "game_lost"})
	elif t >= cfg.shift_length and _next_spawn >= schedule.spawns.size() and active_ships().is_empty():
		result = Result.WON
		events.append({"type": "game_won"})


func find_ship(id: int) -> ShipModel:
	for s in ships:
		if s.id == id:
			return s
	return null
