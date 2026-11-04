class_name KeeperBot2
extends RefCounted
## Scripted keepers for the v2 rules (simulations, captures, the exported-app autotest).
##   idle    - touches nothing (must lose)
##   expert  - manages power, clears faults, vectors ships onto channel leading lines (must win)
##   novice  - slow, reactive: late generator, ignores faults for a while, NORMAL lamp only

var mode := "expert"
var rng := RandomNumberGenerator.new()
var _order_cd := 0.0
var _fault_seen := -1.0
var _breaker_seen := -1.0
var _manual_for := -1
var orders_sent := 0


func _init(bot_mode: String = "expert", seed_value: int = 1) -> void:
	mode = bot_mode
	rng.seed = seed_value * 31 + 7


## Drive the sim for one step: calls KeeperSim actions directly. Returns events produced.
func act(k: KeeperSim, dt: float) -> Array:
	var ev: Array = []
	if mode == "idle":
		return ev
	var novice := mode == "novice"
	_order_cd -= dt
	# ---- faults ----
	if k.jammed:
		if _fault_seen < 0.0:
			_fault_seen = k.t
		if k.t - _fault_seen > (6.0 if novice else 0.6) and k.mode == KeeperSim.Mode.AUTO:
			ev += k.set_mode(KeeperSim.Mode.OFF)
	else:
		_fault_seen = -1.0
	if k.mode == KeeperSim.Mode.OFF and not k.jammed:
		ev += k.set_mode(KeeperSim.Mode.AUTO)
	if not k.main_breaker:
		if _breaker_seen < 0.0:
			_breaker_seen = k.t
		if k.t - _breaker_seen > (5.0 if novice else 1.0):
			ev += k.set_breaker("main", true)
			_breaker_seen = -1.0
	# ---- generator ----
	var start_at := 25.0 if novice else 55.0
	if k.gen == KeeperSim.Gen.OFF and k.battery < start_at and k.fuel > 0.0 and not (k.gen_overheated and k.gen_temp > k.cfg.temp_restart):
		if not k.fuel_valve:
			ev += k.set_fuel_valve(true)
		ev += k.set_start(true)
	elif k.gen != KeeperSim.Gen.CRANKING and k.start_held:
		ev += k.set_start(false)
	if k.gen == KeeperSim.Gen.RUNNING:
		var want_charge := k.battery < 96.0 and k.gen_temp < (95.0 if novice else 82.0)
		if k.charge_on != want_charge and (want_charge or k.gen_temp >= 82.0 or k.battery >= 96.0):
			ev += k.set_charge(want_charge)
		if not novice and k.battery >= 96.0 and k.fuel_valve:
			ev += k.set_fuel_valve(false)
	# ---- lamp ----
	if not novice:
		var want_high := k.storm > 0.55 and k.battery > 30.0
		if (k.intensity == 2) != want_high:
			ev += k.set_intensity(2 if want_high else 1)
		if want_high and k.brk_lights:
			ev += k.set_breaker("lights", false)
	# ---- ships ----
	if _order_cd <= 0.0 and k.can_transmit():
		var best: FleetShip = null
		var best_u := INF
		var best_cmd := ""
		for s in k.active_ships():
			if s.state != FleetShip.State.SAILING:
				continue
			var cmd := _order_for(k, s)
			if cmd == "":
				continue
			var u := s.tti
			if u < best_u:
				best_u = u
				best = s
				best_cmd = cmd
		if best:
			ev += k.command(best.id, best_cmd)
			orders_sent += 1
			_order_cd = (7.0 if novice else 0.3) + rng.randf_range(0.0, 1.0 if novice else 0.2)
	# expert: focus the beam manually on a ship that is blind and in danger late in the storm
	if not novice:
		_manual_focus(k)
	return ev


func _order_for(k: KeeperSim, s: FleetShip) -> String:
	var desired := desired_heading(k, s)
	var diff := Geo.angle_diff(s.ordered, desired)
	if absf(diff) > deg_to_rad(17.0):
		return "port" if diff < 0.0 else "starboard"
	if s.hold:
		return "maintain"
	return ""


## Heading that brings the ship onto the nearest channel's leading line, then inbound along it.
static func desired_heading(k: KeeperSim, s: FleetShip) -> float:
	var pb := Geo.bearing_of(s.pos)
	var best: Dictionary = k.layout.channels[0]
	for c in k.layout.channels:
		if absf(Geo.angle_diff(pb, c["bearing"])) < absf(Geo.angle_diff(pb, best["bearing"])):
			best = c
	var cb: float = best["bearing"]
	var d := s.pos.length()
	if absf(Geo.angle_diff(pb, cb)) < deg_to_rad(8.0) and d < 150.0:
		return wrapf(cb + PI, -PI, PI)
	var approach := Geo.polar(cb, clampf(d - 25.0, 110.0, 140.0))
	return Geo.bearing_of(approach - s.pos)


func _manual_focus(k: KeeperSim) -> void:
	var target: FleetShip = null
	for s in k.active_ships():
		if s.state == FleetShip.State.SAILING and not k.ship_sees_light(s) and s.tti < 40.0 and k.vis_range() < s.pos.length():
			if target == null or s.tti < target.tti:
				target = s
	if target and not k.jammed:
		if k.mode != KeeperSim.Mode.MANUAL:
			k.set_mode(KeeperSim.Mode.MANUAL)
		_manual_for = target.id
		var diff := Geo.angle_diff(k.bearing, Geo.bearing_of(target.pos))
		k.set_wheel(clampf(diff / deg_to_rad(10.0), -1.0, 1.0))
	elif _manual_for != -1:
		_manual_for = -1
		k.set_wheel(0.0)
		if k.mode == KeeperSim.Mode.MANUAL:
			k.set_mode(KeeperSim.Mode.AUTO)
