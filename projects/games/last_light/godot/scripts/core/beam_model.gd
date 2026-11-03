class_name BeamModel
extends RefCounted
## The lighthouse beam: eased rotation, boost, energy. Pure logic (no nodes).

var cfg: GameConfig
var bearing := 0.0            # radians
var ang_vel := 0.0            # radians / s
var boosting := false
var energy := 100.0
var locked_out := false
var low := false
var _since_boost := 999.0


func _init(config: GameConfig) -> void:
	cfg = config
	bearing = deg_to_rad(cfg.beam_start_bearing_deg)
	energy = cfg.energy_max


## turn_axis in [-1, 1] (+ = clockwise/east). Appends event dictionaries to `events`.
func step(dt: float, turn_axis: float, boost_held: bool, events: Array) -> void:
	var was_boosting := boosting
	boosting = boost_held and not locked_out and energy > 0.0
	if boosting:
		energy -= cfg.energy_drain * dt
		_since_boost = 0.0
		if energy <= 0.0:
			energy = 0.0
			boosting = false
			locked_out = true
			events.append({"type": "energy_depleted"})
	else:
		_since_boost += dt
		if _since_boost >= cfg.energy_regen_delay:
			energy = minf(cfg.energy_max, energy + cfg.energy_regen * dt)
	if locked_out and energy >= cfg.energy_lockout_resume:
		locked_out = false
		events.append({"type": "energy_restored"})
	if boosting and not was_boosting:
		events.append({"type": "boost_on"})
	elif was_boosting and not boosting:
		events.append({"type": "boost_off"})
	var is_low := energy < cfg.energy_low
	if is_low and not low:
		events.append({"type": "energy_low"})
	low = is_low

	var max_v := deg_to_rad(cfg.beam_max_speed_deg) * (cfg.beam_boost_speed_mul if boosting else 1.0)
	var target_v := clampf(turn_axis, -1.0, 1.0) * max_v
	ang_vel = move_toward(ang_vel, target_v, deg_to_rad(cfg.beam_accel_deg) * dt)
	bearing = wrapf(bearing + ang_vel * dt, -PI, PI)


func half_angle() -> float:
	return deg_to_rad(cfg.beam_boost_half_angle_deg if boosting else cfg.beam_half_angle_deg)


func reach() -> float:
	return cfg.beam_boost_range if boosting else cfg.beam_range


func fill_mul() -> float:
	return cfg.boost_fill_mul if boosting else 1.0


## Is a circle of `radius` at `p` inside the beam cone?
func lights(p: Vector2, radius: float) -> bool:
	var d := p.length()
	if d < 1.0 or d - radius > reach():
		return false
	var off := absf(Geo.angle_diff(bearing, Geo.bearing_of(p)))
	return off <= half_angle() + atan2(radius, d)
