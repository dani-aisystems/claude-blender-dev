class_name KeeperSim
extends RefCounted
## THE LAST LIGHT v2 rules: power, generator, malfunctions, the light mechanism, radio and
## ships, in one deterministic node-free object. The room, the tests and the bots all drive it.
## Every player action is a method call; every consequence is an event dictionary.

enum Result { RUNNING, WON, LOST }
enum Mode { OFF, AUTO, MANUAL }
enum Gen { OFF, CRANKING, RUNNING, STOPPING }

var cfg: KeeperConfig
var layout: LayoutData
var rng := RandomNumberGenerator.new()
var t := 0.0
var storm := 0.0
var result := Result.RUNNING
var seed_used := 0

# ---- power ----
var battery := 62.0
var main_breaker := true
var brk_lights := true
var brk_radar := true
var demand := 0.0
var charge_flow := 0.0
var _overload_t := 0.0
var _batt_warned := false

# ---- generator ----
var fuel := 45.0
var fuel_valve := false
var charge_on := false
var gen := Gen.OFF
var gen_temp := 18.0
var gen_overheated := false
var start_held := false
var _crank_t := 0.0
var _stop_t := 0.0
var _temp_warned := false

# ---- light ----
var mode := Mode.AUTO
var intensity := 1
var bearing := 0.0
var wheel_input := 0.0
var _manual_vel := 0.0
var jammed := false
var _jam_t := 0.0
var _jam_clear_t := 0.0
var faults: Array = []

# ---- radio ----
var tx_t := 0.0                    # > 0 while the keeper is transmitting
var _pending: Array = []           # {t, ship_id, cmd} order replies waiting
var _last_reply_ok := true

# ---- ships ----
var ships: Array[FleetShip] = []
var hazards: Array[Dictionary] = []
var script_ships: Array = []
var _next_ship := 0
var _next_id := 1
var saved := 0
var lost := 0
var dark_seconds := 0.0
var score := 0
var logbook_unlocked: Array = []
var _logbook: Array = []
var _next_lightning := 20.0

# ---- story mode (the narrative campaign drives ships, storm, clock and faults) ----
var story_mode := false
var storm_override := -1.0
var clock_min := 0.0               # story clock in minutes after midnight (may exceed 1440)
var clock_rate := 0.0              # story minutes per real second


func setup(config: KeeperConfig, layout_data: LayoutData, night: Dictionary, seed_value: int) -> void:
	cfg = config
	layout = layout_data
	seed_used = seed_value
	rng.seed = seed_value
	battery = cfg.battery_start
	fuel = cfg.fuel_start
	gen_temp = cfg.temp_ambient
	hazards.clear()
	for r in layout.reefs:
		hazards.append({"pos": r["pos"], "r": r["r"]})
	hazards.append({"pos": Vector2.ZERO, "r": layout.island_radius})
	script_ships.clear()
	for e in night.get("ships", []):
		var d: Dictionary = e.duplicate()
		d["t"] = float(e["t"]) + (0.0 if e.get("stage", 0) == 1 else rng.randf_range(-3.0, 3.0))
		d["bearing"] = float(e["bearing"]) + (0.0 if e.get("stage", 0) == 1 else rng.randf_range(-4.0, 4.0))
		script_ships.append(d)
	script_ships.sort_custom(func(a, b): return a["t"] < b["t"])
	faults = []
	for f in night.get("faults", []):
		faults.append({"t": float(f["t"]), "type": f["type"], "done": false})
	_logbook = night.get("logbook", [])
	_next_lightning = 25.0 + rng.randf_range(0.0, 10.0)


# ================================================================== queries

func powered() -> bool:
	return main_breaker and battery > 0.0


func lamp_on() -> bool:
	return powered() and mode != Mode.OFF


func motor_on() -> bool:
	return powered() and mode == Mode.AUTO


func radio_on() -> bool:
	return powered()


func radar_on() -> bool:
	return powered() and brk_radar


func lights_on() -> bool:
	return powered() and brk_lights


func vis_range() -> float:
	return float(cfg.vis_range[intensity]) * (1.0 - cfg.fog_cut * storm)


func clock_minutes() -> float:
	if story_mode:
		return fmod(clock_min, 1440.0)
	return lerpf(cfg.clock_start_min, cfg.clock_end_min, clampf(t / cfg.night_length, 0.0, 1.0))


func clock_text() -> String:
	var m := int(clock_minutes())
	return "%02d:%02d" % [m / 60, m % 60]


func active_ships() -> Array[FleetShip]:
	var out: Array[FleetShip] = []
	for s in ships:
		if s.is_active():
			out.append(s)
	return out


func find_ship(id: int) -> FleetShip:
	for s in ships:
		if s.id == id:
			return s
	return null


func motor_amps() -> float:
	if not motor_on():
		return 0.0
	return 8.6 if jammed else 3.1


func charge_amps() -> float:
	return 0.0 if charge_flow <= 0.0 else 28.0 + 6.0 * sin(t * 1.7)


func stats() -> Dictionary:
	return {"result": ["running", "won", "lost"][result], "time": snappedf(t, 0.1), "saved": saved, "lost": lost,
		"ships_total": script_ships.size(), "score": score, "dark_seconds": snappedf(dark_seconds, 0.1),
		"battery": snappedf(battery, 0.1), "fuel": snappedf(fuel, 0.1), "seed": seed_used, "clock": clock_text()}


# ================================================================== player actions (return events)

func set_fuel_valve(open: bool) -> Array:
	fuel_valve = open
	return [{"type": "fuel_valve", "open": open}]


func set_start(held: bool) -> Array:
	var ev: Array = []
	if held and not start_held:
		if gen == Gen.OFF:
			if gen_overheated and gen_temp > cfg.temp_restart:
				ev.append({"type": "gen_too_hot"})
			else:
				gen = Gen.CRANKING
				_crank_t = 0.0
				ev.append({"type": "gen_crank"})
	elif not held and start_held and gen == Gen.CRANKING:
		gen = Gen.OFF
		ev.append({"type": "gen_crank_stop"})
	start_held = held
	return ev


func set_charge(on: bool) -> Array:
	charge_on = on
	return [{"type": "charge_switch", "on": on}]


func set_breaker(which: String, on: bool) -> Array:
	match which:
		"main":
			main_breaker = on
			if on:
				_overload_t = 0.0
		"lights":
			brk_lights = on
		"radar":
			brk_radar = on
	return [{"type": "breaker", "which": which, "on": on}]


func set_mode(m: int) -> Array:
	var ev: Array = [{"type": "mode", "mode": m}]
	if m != Mode.AUTO and jammed:
		_jam_clear_t = cfg.jam_clear_time
	mode = m
	return ev


func set_intensity(i: int) -> Array:
	intensity = clampi(i, 0, 2)
	return [{"type": "intensity", "level": intensity}]


func set_wheel(axis: float) -> void:
	wheel_input = clampf(axis, -1.0, 1.0)


func can_transmit() -> bool:
	return radio_on() and tx_t <= 0.0


## Radio order to a ship: confirm, port, starboard, slow, hold, maintain.
func command(ship_id: int, cmd: String) -> Array:
	var ev: Array = []
	if not radio_on():
		return [{"type": "radio_dead"}]
	if tx_t > 0.0:
		return [{"type": "radio_busy"}]
	var s := find_ship(ship_id)
	if s == null or not s.is_active():
		return [{"type": "radio_no_answer"}]
	tx_t = cfg.tx_time
	s.answered = true
	ev.append({"type": "tx", "ship": s.id, "name": s.name, "cmd": cmd, "text": _keeper_line(s, cmd)})
	_pending.append({"t": t + cfg.tx_time + cfg.reply_delay, "ship": s.id, "cmd": cmd})
	return ev


# ================================================================== step

func step(dt: float) -> Array:
	var ev: Array = []
	if result != Result.RUNNING:
		return ev
	t += dt
	if story_mode:
		storm = storm_override if storm_override >= 0.0 else storm
		clock_min += clock_rate * dt
	else:
		storm = cfg.storm_at(t)
	tx_t = maxf(0.0, tx_t - dt)
	if not story_mode:
		_logbook_step(ev)
	_faults_step(dt, ev)
	_generator_step(dt, ev)
	_power_step(dt, ev)
	_light_step(dt, ev)
	_weather_step(ev)
	if not story_mode:
		_spawn_step(ev)
	_replies_step(ev)
	for s in ships:
		if s.is_active():
			_ship_step(s, dt, ev)
	if not story_mode:
		_end_step(ev)
	return ev


# ================================================================== story hooks

## Spawn a story ship. e: {name, kind, bearing, aim, call, route?: [[x,z],...], unlit?, speed_mul?}
func spawn_story_ship(e: Dictionary) -> Array:
	var s := spawn_ship(e)
	if e.has("speed_mul"):
		s.cruise *= float(e["speed_mul"])
		s.speed = s.cruise
	if e.has("route"):
		s.route = PackedVector2Array()
		for p in e["route"]:
			s.route.append(Vector2(p[0], p[1]))
		s.story_route = true
		s.state = FleetShip.State.PILOTING
		s.seg = 0
	s.unlit = bool(e.get("unlit", false))
	s.hold = bool(e.get("hold", false))
	s.protected = bool(e.get("protected", false))
	if s.hold:
		s.speed = 0.0
	var ev: Array = [{"type": "ship_spawned", "ship": s.id, "name": s.name}]
	if s.call_text != "":
		ev.append(_incoming(s, s.call_text, "call"))
	return ev


func find_ship_named(n: String) -> FleetShip:
	for s in ships:
		if s.name == n:
			return s
	return null


func trigger_fault(kind: String) -> Array:
	match kind:
		"jam":
			faults.append({"t": t, "type": "jam", "done": false})
		"overheat":
			gen_temp = maxf(gen_temp, cfg.temp_trip - 4.0)
		"trip":
			if main_breaker:
				main_breaker = false
				return [{"type": "breaker_trip", "cause": "story"}]
	return []


func to_dict() -> Dictionary:
	var sh: Array = []
	for s in ships:
		sh.append(s.to_dict())
	return {"t": t, "storm": storm, "battery": battery, "main_breaker": main_breaker, "brk_lights": brk_lights,
		"brk_radar": brk_radar, "fuel": fuel, "fuel_valve": fuel_valve, "charge_on": charge_on, "gen": gen,
		"gen_temp": gen_temp, "gen_overheated": gen_overheated, "mode": mode, "intensity": intensity, "bearing": bearing,
		"jammed": jammed, "faults": faults, "ships": sh, "next_id": _next_id, "saved": saved, "lost": lost,
		"dark_seconds": dark_seconds, "score": score, "story_mode": story_mode, "storm_override": storm_override,
		"clock_min": clock_min, "clock_rate": clock_rate, "seed": seed_used}


func from_dict(d: Dictionary) -> void:
	for k in ["t", "storm", "battery", "main_breaker", "brk_lights", "brk_radar", "fuel", "fuel_valve", "charge_on",
			"gen_temp", "gen_overheated", "bearing", "jammed", "dark_seconds", "story_mode", "storm_override",
			"clock_min", "clock_rate"]:
		if d.has(k):
			set(k, d[k])
	gen = int(d.get("gen", 0))
	if gen == Gen.CRANKING or gen == Gen.STOPPING:
		gen = Gen.OFF if gen == Gen.CRANKING else Gen.RUNNING
	mode = int(d.get("mode", 1))
	intensity = int(d.get("intensity", 1))
	saved = int(d.get("saved", 0))
	lost = int(d.get("lost", 0))
	score = int(d.get("score", 0))
	_next_id = int(d.get("next_id", 1))
	faults = d.get("faults", [])
	ships.clear()
	for sd in d.get("ships", []):
		ships.append(FleetShip.from_dict(sd))


func _logbook_step(ev: Array) -> void:
	for i in _logbook.size():
		if i not in logbook_unlocked and t >= float(_logbook[i]["t"]):
			logbook_unlocked.append(i)
			ev.append({"type": "logbook", "index": i, "title": _logbook[i]["title"]})


func logbook_entries() -> Array:
	var out: Array = []
	for i in logbook_unlocked:
		out.append(_logbook[i])
	return out


func _faults_step(dt: float, ev: Array) -> void:
	for f in faults:
		if not f["done"] and t >= f["t"] and f["type"] == "jam" and motor_on():
			f["done"] = true
			jammed = true
			_jam_t = 0.0
			ev.append({"type": "jam"})
	if jammed:
		if mode != Mode.AUTO or not powered():
			_jam_clear_t -= dt
			if _jam_clear_t <= 0.0 or not powered():
				jammed = false
				ev.append({"type": "jam_cleared"})
		else:
			_jam_clear_t = cfg.jam_clear_time
			_jam_t += dt
			if _jam_t >= cfg.jam_trip_delay and main_breaker:
				main_breaker = false
				ev.append({"type": "breaker_trip", "cause": "motor"})


func _generator_step(dt: float, ev: Array) -> void:
	match gen:
		Gen.CRANKING:
			_crank_t += dt
			if fuel_valve and fuel > 0.0 and _crank_t >= cfg.crank_time:
				gen = Gen.RUNNING
				gen_overheated = false
				ev.append({"type": "gen_start"})
			elif (not fuel_valve or fuel <= 0.0) and _crank_t >= cfg.crank_fail_time:
				gen = Gen.OFF
				ev.append({"type": "gen_crank_fail", "why": "no_fuel" if fuel <= 0.0 else "valve"})
		Gen.RUNNING:
			var charging := charge_on
			fuel = maxf(0.0, fuel - (cfg.fuel_burn_charge if charging else cfg.fuel_burn_idle) * dt)
			if charging:
				gen_temp += cfg.temp_rise_charge * (1.0 + storm * 0.5) * dt
			else:
				gen_temp = move_toward(gen_temp, cfg.temp_idle, cfg.temp_settle * dt)
			if gen_temp >= cfg.temp_warn and not _temp_warned:
				_temp_warned = true
				ev.append({"type": "gen_hot"})
			if gen_temp >= cfg.temp_trip:
				gen = Gen.OFF
				gen_overheated = true
				ev.append({"type": "gen_overheat"})
			elif not fuel_valve or fuel <= 0.0:
				gen = Gen.STOPPING
				_stop_t = 0.0
				ev.append({"type": "gen_stopping", "why": "valve" if fuel > 0.0 else "fuel"})
		Gen.STOPPING:
			_stop_t += dt
			if _stop_t >= cfg.stop_delay:
				gen = Gen.OFF
				ev.append({"type": "gen_stop"})
		Gen.OFF:
			pass
	if gen != Gen.RUNNING:
		gen_temp = move_toward(gen_temp, cfg.temp_ambient, cfg.temp_cool * dt)
	if gen_temp < cfg.temp_warn - 10.0:
		_temp_warned = false


func _power_step(dt: float, ev: Array) -> void:
	demand = 0.0
	if powered():
		demand = cfg.base_draw
		if lamp_on():
			demand += float(cfg.lamp_draw[intensity])
		if motor_on():
			demand += cfg.motor_jam_draw if jammed else cfg.motor_draw
		demand += cfg.radio_draw + (cfg.radio_tx_draw if tx_t > 0.0 else 0.0)
		if radar_on():
			demand += cfg.radar_draw
		if lights_on():
			demand += cfg.lights_draw
	charge_flow = cfg.charge_rate if gen == Gen.RUNNING and charge_on else 0.0
	var was_powered := powered()
	battery = clampf(battery + (charge_flow - demand) * dt, 0.0, 100.0)
	if was_powered and battery <= 0.0:
		ev.append({"type": "battery_dead"})
	if battery < cfg.battery_warn and not _batt_warned:
		_batt_warned = true
		ev.append({"type": "battery_low"})
	elif battery > cfg.battery_warn + 10.0:
		_batt_warned = false
	if powered() and demand > cfg.overload_limit:
		if _overload_t == 0.0:
			ev.append({"type": "brownout"})
		_overload_t += dt
		if _overload_t >= cfg.overload_delay:
			main_breaker = false
			_overload_t = 0.0
			ev.append({"type": "breaker_trip", "cause": "overload"})
	else:
		_overload_t = 0.0
	if not lamp_on() and not active_ships().is_empty():
		dark_seconds += dt


func _light_step(dt: float, _ev: Array) -> void:
	match mode:
		Mode.AUTO:
			if motor_on() and not jammed:
				bearing = wrapf(bearing + deg_to_rad(cfg.auto_speed_deg) * dt, -PI, PI)
			_manual_vel = 0.0
		Mode.MANUAL:
			var target := wheel_input * deg_to_rad(cfg.manual_max_deg)
			_manual_vel = move_toward(_manual_vel, target, deg_to_rad(cfg.manual_accel_deg) * dt)
			bearing = wrapf(bearing + _manual_vel * dt, -PI, PI)
		_:
			_manual_vel = 0.0


## Can this ship see the light right now?
func ship_sees_light(s: FleetShip) -> bool:
	if not lamp_on():
		return false
	var d := s.pos.length()
	var r := vis_range()
	if mode == Mode.AUTO:
		return d <= r
	if mode == Mode.MANUAL:
		var off := absf(Geo.angle_diff(bearing, Geo.bearing_of(s.pos)))
		return off <= deg_to_rad(cfg.focus_half_deg) + atan2(s.radius, maxf(d, 1.0)) and d <= r * cfg.focus_mul
	return false


func _weather_step(ev: Array) -> void:
	if t >= _next_lightning:
		var interval := lerpf(cfg.lightning_interval_calm, cfg.lightning_interval_storm, storm)
		_next_lightning = t + interval * rng.randf_range(0.7, 1.3)
		ev.append({"type": "lightning", "power": 0.5 + 0.5 * storm, "thunder_delay": rng.randf_range(0.5, 2.5),
			"bearing": rng.randf_range(-PI * 0.6, PI * 0.6)})


# ================================================================== ships

func _spawn_step(ev: Array) -> void:
	while _next_ship < script_ships.size() and script_ships[_next_ship]["t"] <= t:
		var e: Dictionary = script_ships[_next_ship]
		_next_ship += 1
		var s := spawn_ship(e)
		ev.append({"type": "ship_spawned", "ship": s.id, "name": s.name})
		ev.append(_incoming(s, s.call_text, "call"))


func spawn_ship(e: Dictionary) -> FleetShip:
	var p: Dictionary = cfg.ship_types[e["kind"]]
	var s := FleetShip.new()
	s.id = _next_id
	_next_id += 1
	s.name = e.get("name", "Vessel %d" % s.id)
	s.kind = e["kind"]
	s.call_text = e.get("call", "")
	s.cruise = p["speed"]
	s.speed = s.cruise
	s.turn_rate = deg_to_rad(p["turn_deg"])
	s.radius = p["radius"]
	var b := deg_to_rad(float(e["bearing"]))
	s.pos = Geo.polar(b, cfg.spawn_radius)
	var aim = e.get("aim", 0)
	if typeof(aim) == TYPE_STRING and aim == "reef":
		s.heading = Geo.bearing_of(_blind_reef(b) - s.pos)
	else:
		s.heading = wrapf(Geo.bearing_of(-s.pos) + deg_to_rad(float(aim)), -PI, PI)
	s.ordered = s.heading
	s.spawn_time = t
	s.last_call = t
	ships.append(s)
	return s


func _blind_reef(b: float) -> Vector2:
	var best: Vector2 = layout.reefs[0]["pos"]
	var bd := INF
	for r in layout.reefs:
		var d := absf(Geo.angle_diff(b, Geo.bearing_of(r["pos"])))
		if d < bd:
			bd = d
			best = r["pos"]
	return best


func _ship_step(s: FleetShip, dt: float, ev: Array) -> void:
	if s.docked:
		return
	var saw := s.sees_light
	s.sees_light = ship_sees_light(s)
	if not lamp_on():
		s.dark_time += dt
	if s.state == FleetShip.State.SAILING:
		if saw and not s.sees_light and s.pos.length() < cfg.channel_capture_max + 40.0 and t - s.last_call > 8.0 and not s.unlit:
			s.last_call = t
			ev.append(_incoming(s, "%s. We've lost your light, North Point! Can't see a thing out here." % s.name, "lost_light"))
		elif not saw and s.sees_light and s.answered and t - s.last_call > 8.0 and not s.unlit:
			s.last_call = t
			ev.append(_incoming(s, "We have your light again, North Point.", "has_light"))
		_try_capture(s, ev)
	# heading
	var desired := s.ordered
	if s.state == FleetShip.State.PILOTING:
		desired = Geo.bearing_of(s.pursue(cfg.path_lookahead, cfg.path_capture) - s.pos)
	s.heading = Geo.turn_toward(s.heading, desired, s.turn_rate * dt)
	s.speed = move_toward(s.speed, s.target_speed(cfg), cfg.ship_accel * dt)
	var vel := Geo.dir(s.heading) * s.speed
	if s.state == FleetShip.State.SAILING and not s.sees_light and not (s.protected and s.hold):
		var onshore := (-s.pos).normalized()
		vel += onshore * cfg.storm_set * storm
	s.pos += vel * dt
	if s.state == FleetShip.State.PILOTING and s.at_route_end(cfg.exit_reach if not s.story_route else 2.5):
		if s.story_route:
			if not s.docked:
				s.docked = true
				s.hold = true
				ev.append({"type": "ship_docked", "ship": s.id, "name": s.name})
			s.speed = 0.0
			return
		_resolve(s, FleetShip.State.SAVED, ev)
		return
	if s.state == FleetShip.State.SAILING and s.protected and not s.hold:
		var tti_now := s.compute_tti(hazards)
		if tti_now < 5.0:
			s.hold = true
			s.ordered = s.heading
			ev.append(_incoming(s, "%s here. I've stopped her, there's broken water right ahead of me! Tell me which way, North Point!" % s.name, "mayday"))
	if s.state == FleetShip.State.SAILING:
		for h in hazards:
			if s.pos.distance_to(h["pos"]) < h["r"] + s.radius:
				_resolve(s, FleetShip.State.LOST, ev)
				return
		s.tti = s.compute_tti(hazards)
		if s.tti < cfg.mayday_tti and not s.mayday_sent:
			s.mayday_sent = true
			ev.append(_incoming(s, "MAYDAY MAYDAY, %s! Breakers dead ahead, we're going onto the rocks!" % s.name, "mayday"))
		elif s.tti > cfg.mayday_tti * 1.6:
			s.mayday_sent = false
		if not s.answered and t - s.last_call > cfg.recall_interval and not s.unlit and not story_mode:
			s.last_call = t
			ev.append(_incoming(s, "North Point Light, %s, do you read? Requesting instructions, over." % s.name, "recall"))
	if s.pos.length() > cfg.spawn_radius + 80.0 and s.state == FleetShip.State.SAILING:
		# stood back out to sea: safe, but she still has to ride out the gale (half points)
		_resolve(s, FleetShip.State.SAVED, ev, true)


func _try_capture(s: FleetShip, ev: Array) -> void:
	if not s.sees_light:
		return
	var d := s.pos.length()
	if d < cfg.channel_capture_min or d > cfg.channel_capture_max:
		return
	var pb := Geo.bearing_of(s.pos)
	for c in layout.channels:
		var cb: float = c["bearing"]
		if absf(Geo.angle_diff(pb, cb)) > deg_to_rad(cfg.channel_capture_deg):
			continue
		if absf(Geo.angle_diff(s.heading, wrapf(cb + PI, -PI, PI))) > deg_to_rad(cfg.channel_heading_tol_deg):
			continue
		s.state = FleetShip.State.PILOTING
		s.route = layout.route_for(cb if c["exit"] != "auto" else (Geo.bearing_of(s.pos)))
		s.seg = 0
		s.hold = false
		s.channel_name = _channel_name(cb)
		ev.append({"type": "ship_piloting", "ship": s.id, "channel": s.channel_name})
		ev.append(_incoming(s, "North Point, %s. We have the channel lights, %s, proceeding in. Thank you!" % [s.name, s.channel_name], "piloting"))
		return


func _channel_name(cb: float) -> String:
	var d := rad_to_deg(cb)
	if d < -20.0:
		return "West Gut"
	if d > 20.0:
		return "East Gut"
	return "North Sound"


func _resolve(s: FleetShip, state: int, ev: Array, out_to_sea := false) -> void:
	s.state = state
	s.resolve_time = t
	s.sees_light = false
	if state == FleetShip.State.SAVED:
		saved += 1
		var pts := cfg.score_saved + (cfg.score_never_dark if s.dark_time <= 0.5 else 0)
		if out_to_sea:
			pts /= 2
		score += pts
		ev.append({"type": "ship_saved", "ship": s.id, "name": s.name, "points": pts, "out_to_sea": out_to_sea})
		ev.append(_incoming(s, ("%s standing out to sea, clear of the rocks. We'll ride it out. Thank you, North Point." if out_to_sea else "%s safe in the harbour. God bless you, North Point. Out.") % s.name, "saved"))
	else:
		lost += 1
		ev.append({"type": "ship_lost", "ship": s.id, "name": s.name, "pos": s.pos})
		ev.append(_incoming(s, "...we've struck! %s aground, taking water... abandon..." % s.name, "lost", true))


func _end_step(ev: Array) -> void:
	if lost >= cfg.max_lost:
		result = Result.LOST
		_final_score()
		ev.append({"type": "game_lost"})
		return
	var all_spawned := _next_ship >= script_ships.size()
	if t >= cfg.night_length and all_spawned and (active_ships().is_empty() or t >= cfg.night_length + cfg.overtime_max):
		for s in active_ships():
			_resolve(s, FleetShip.State.SAVED if s.state == FleetShip.State.PILOTING else FleetShip.State.LOST, ev)
		result = Result.WON if lost < cfg.max_lost else Result.LOST
		_final_score()
		ev.append({"type": "radio", "from": "Coastguard", "text": "North Point Light, Stornoway Coastguard. The gale's blown through. Stand down your watch, keeper, and well done. Out.", "kind": "dawn"})
		ev.append({"type": "game_won" if result == Result.WON else "game_lost"})


func _final_score() -> void:
	score = maxi(0, score - int(dark_seconds * cfg.dark_penalty_per_s))


# ================================================================== radio

func _replies_step(ev: Array) -> void:
	var keep: Array = []
	for p in _pending:
		if t < p["t"]:
			keep.append(p)
			continue
		var s := find_ship(p["ship"])
		if s == null or not s.is_active():
			continue
		ev.append(_apply_order(s, p["cmd"]))
	_pending = keep


func _apply_order(s: FleetShip, cmd: String) -> Dictionary:
	var seen := s.sees_light
	var err := 0.0 if seen else deg_to_rad(rng.randf_range(-cfg.blind_turn_error_deg, cfg.blind_turn_error_deg))
	var step := deg_to_rad(cfg.order_turn_deg)
	var text := ""
	match cmd:
		"confirm":
			s.labelled = true
			var r := s.report()
			return _incoming(s, "%s. Our position bearing %03d from your light, range %d metres, heading %03d, over." % [s.name, r["bearing"], r["range"], r["heading"]], "position", false, true)
		"port":
			s.ordered = wrapf(s.ordered - step + err, -PI, PI)
			s.hold = false
			text = "Coming thirty degrees to port, %s." % s.name
		"starboard":
			s.ordered = wrapf(s.ordered + step + err, -PI, PI)
			s.hold = false
			text = "Thirty degrees to starboard, %s." % s.name
		"slow":
			s.slow = not s.slow
			text = "%s, reducing speed." % s.name if s.slow else "%s, back to full ahead." % s.name
		"hold":
			s.hold = true
			text = "%s heaving to, holding position as best we can." % s.name
		"maintain":
			s.hold = false
			s.ordered = s.heading
			text = "Maintaining course, %s." % s.name
	if not seen and cmd in ["port", "starboard"]:
		text += " We can't see your light, steering blind!"
	return _incoming(s, text, "ack")


func _incoming(s: FleetShip, text: String, kind: String, force_static := false, clear := false) -> Dictionary:
	var shown := text
	if not clear:
		var p := cfg.static_word_prob * storm * (1.5 if force_static else 1.0)
		var words := text.split(" ")
		for i in words.size():
			if i > 1 and rng.randf() < p:
				words[i] = "—"
		shown = " ".join(words)
	return {"type": "radio", "from": s.name if s else "", "ship": s.id if s else -1, "text": shown, "kind": kind}


func _keeper_line(s: FleetShip, cmd: String) -> String:
	var orders := {"confirm": "confirm your position, over.", "port": "alter course thirty degrees to port, over.",
		"starboard": "alter course thirty degrees to starboard, over.", "slow": "reduce speed, over.",
		"hold": "hold your position, over.", "maintain": "maintain your course, over."}
	if cmd == "slow" and s.slow:
		return "%s, North Point. Resume full speed, over." % s.name
	return "%s, North Point Light. %s" % [s.name, orders.get(cmd, "say again, over.")]
