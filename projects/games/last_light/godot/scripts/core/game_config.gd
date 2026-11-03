class_name GameConfig
extends Resource
## Every gameplay tunable in one place. Geometry lives in blender/spec.py -> layout.json.
## Record tuning rounds as comments:  # Tune N: old -> new because <sim result>.

# ---- beam ----
@export var beam_max_speed_deg := 70.0
@export var beam_accel_deg := 320.0
@export var beam_boost_speed_mul := 0.85
@export var beam_half_angle_deg := 6.0
@export var beam_boost_half_angle_deg := 10.0
@export var beam_range := 185.0           # Tune 1: 140 -> 185, ships were only lightable ~8 s before the reef
@export var beam_boost_range := 215.0
@export var boost_fill_mul := 2.0
@export var beam_start_bearing_deg := 0.0

# ---- energy ----
@export var energy_max := 100.0
@export var energy_drain := 22.0
@export var energy_regen := 7.0
@export var energy_regen_delay := 0.6
@export var energy_lockout_resume := 30.0
@export var energy_low := 25.0

# ---- ships ----
## speed m/s, turn deg/s, need = seconds of normal light to find bearings, radius = collision (m).
@export var ship_types := {
	"fishing": {"speed": 7.0, "turn_deg": 28.0, "need": 2.0, "value": 100, "radius": 2.5},
	"schooner": {"speed": 5.5, "turn_deg": 18.0, "need": 3.0, "value": 150, "radius": 3.5},
	"steamer": {"speed": 4.0, "turn_deg": 11.0, "need": 4.5, "value": 250, "radius": 5.0},
}
@export var meter_decay := 0.12          # fraction of the bearings meter lost per second unlit
@export var unlit_turn_mul := 0.45       # blind ships drift back to their course more lazily
@export var lit_speed_mul := 0.7         # Tune 1: new. A lit captain slows to correct course (readable + fair)
@export var locked_speed_mul := 0.85     # until through the channel (route waypoint index >= 2)
@export var path_lookahead := 20.0        # Tune 2: waypoints -> pure pursuit (locked ships cut corners into reefs)
@export var path_capture := 15.0
@export var exit_reach := 15.0
@export var avoid_lookahead := 45.0
@export var avoid_margin := 3.0
@export var storm_speed_mul_max := 1.12
@export var stray_radius := 240.0        # safety net: ships beyond this are removed

# ---- danger / scoring ----
@export var warning_tti := 6.0           # seconds to impact that triggers the red warning
@export var close_call_tti := 3.0
@export var close_call_bonus := 50
@export var streak_bonus_step := 0.1     # +10% per consecutive rescue
@export var streak_bonus_cap := 5
@export var max_lost := 5

# ---- session ----
@export var shift_length := 330.0        # seconds of "night"; clock shows 22:00 -> 05:00
@export var spawn_time_jitter := 2.5     # +/- seconds
@export var spawn_bearing_jitter_deg := 7.0
@export var spawn_speed_jitter := 0.06   # +/- fraction

# ---- storm ----
## (time s, intensity 0..1) control points, linear in between.
@export var storm_curve: Array = [[0.0, 0.08], [45.0, 0.15], [105.0, 0.35], [180.0, 0.6], [270.0, 0.9], [300.0, 1.0]]
@export var lightning_interval_calm := 38.0
@export var lightning_interval_storm := 8.0
@export var gust_telegraph := 2.5
@export var gust_duration := 4.5
@export var gust_drift := 2.0            # m/s lateral push on ships that have not found bearings


func ship(kind: String) -> Dictionary:
	return ship_types[kind]


func storm_at(t: float) -> float:
	var pts := storm_curve
	if t <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if t <= pts[i][0]:
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			return lerpf(a[1], b[1], (t - a[0]) / (b[0] - a[0]))
	return pts[pts.size() - 1][1]
