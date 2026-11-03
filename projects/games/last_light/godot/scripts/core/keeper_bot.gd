class_name KeeperBot
extends RefCounted
## Scripted players for simulations, captures and the attract/autotest mode.
##   idle    - never touches the controls (must lose)
##   expert  - urgency-aware priorities, smart boosting (must win every seed: fairness check)
##   average - 0.6 s reaction, aim noise, naive "closest danger" priorities (difficulty target)

var mode := "expert"
var rng := RandomNumberGenerator.new()
var reaction := 0.0
var aim_noise_deg := 0.0
var target_id := -1
var _timer := 0.0
var _aim_offset := 0.0
var _boost_plan := false


func _init(bot_mode: String = "expert", seed_value: int = 1) -> void:
	mode = bot_mode
	rng.seed = seed_value * 7919 + 13
	match mode:
		"average":
			reaction = 0.6
			aim_noise_deg = 3.0
		"expert":
			reaction = 0.1


## Returns {"turn": float, "boost": bool}.
func decide(w: SimWorld, dt: float) -> Dictionary:
	if mode == "idle":
		return {"turn": 0.0, "boost": false}
	_timer -= dt
	var target := w.find_ship(target_id)
	if target == null or target.state != ShipModel.State.SAILING:
		target = null
		_timer = minf(_timer, 0.0)
	if _timer <= 0.0:
		_timer = reaction
		var pick := _choose(w, target)
		if pick != null and (target == null or pick.id != target.id):
			target = pick
			_aim_offset = deg_to_rad(rng.randf_range(-aim_noise_deg, aim_noise_deg))
		target_id = target.id if target != null else -1
		_boost_plan = _should_boost(w, target)
	if target == null:
		return {"turn": _drift_home(w), "boost": false}
	var want := Geo.bearing_of(target.pos) + _aim_offset
	var diff := Geo.angle_diff(w.beam.bearing, want)
	# proportional aim with braking so the beam settles instead of oscillating
	var turn := clampf(diff / deg_to_rad(9.0), -1.0, 1.0)
	return {"turn": turn, "boost": _boost_plan and target.lit}


func _slack(w: SimWorld, s: ShipModel) -> float:
	var fill := w.cfg.boost_fill_mul if w.beam.energy > 25.0 else 1.0
	var light_needed := (1.0 - s.meter) * s.need / fill
	var aim_time := absf(Geo.angle_diff(w.beam.bearing, Geo.bearing_of(s.pos))) / deg_to_rad(w.cfg.beam_max_speed_deg)
	# the ship also needs time to swing onto its route once it can see
	return s.tti - light_needed - aim_time - 1.5


func _light_left(w: SimWorld, s: ShipModel) -> float:
	var fill := w.cfg.boost_fill_mul if w.beam.energy > 20.0 else 1.0
	return (1.0 - s.meter) * s.need / fill


func _choose(w: SimWorld, current: ShipModel) -> ShipModel:
	var best: ShipModel = null
	var best_v := INF
	for s in w.active_ships():
		if s.state != ShipModel.State.SAILING:
			continue
		var v: float
		if mode == "average":
			v = s.tti   # naive: whoever looks closest to the rocks
		else:
			v = _slack(w, s)
			if v < -3.0:
				v = 1000.0 + v   # hopeless: only if nothing else needs us
		if v < best_v:
			best_v = v
			best = s
	if mode == "expert" and current != null and best != null and best.id != current.id:
		# commit: keep lighting the current ship unless finishing it would doom the other one
		var finish := _light_left(w, current)
		if _slack(w, current) > -3.0 and _slack(w, best) > finish:
			return current
	return best


func _should_boost(w: SimWorld, target: ShipModel) -> bool:
	if target == null or w.beam.locked_out:
		return false
	if mode == "average":
		return target.warning and w.beam.energy > 10.0
	var waiting := 0
	for s in w.active_ships():
		if s.state == ShipModel.State.SAILING and s.id != target.id and s.pos.length() < w.cfg.beam_range:
			waiting += 1
	return (_slack(w, target) < 6.0 or waiting > 0) and w.beam.energy > 8.0


func _drift_home(w: SimWorld) -> float:
	# idle sweep back toward north so the next ship is found quickly
	return clampf(Geo.angle_diff(w.beam.bearing, 0.0) / deg_to_rad(20.0), -0.4, 0.4)
