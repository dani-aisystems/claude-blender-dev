class_name KeeperConfig
extends Resource
## All v2 (first-person keeper) tunables. Power values are percent of battery per second.
## Record tuning rounds as comments:  # Tune N: old -> new because <sim result>.

# ---- night ----
@export var night_length := 660.0          # seconds of play from 02:17 to dawn
@export var clock_start_min := 137.0       # 02:17
@export var clock_end_min := 390.0         # 06:30
@export var overtime_max := 120.0          # ships still at sea after dawn get this long to finish

# ---- power ----
@export var battery_start := 62.0
@export var lamp_draw: Array = [0.20, 0.35, 0.60]   # LOW, NORMAL, HIGH
@export var motor_draw := 0.08
@export var motor_jam_draw := 0.30
@export var radio_draw := 0.03
@export var radio_tx_draw := 0.06       # item 32: was 0.10; at LAMP HIGH every call (0.94) tripped MAIN on its own
@export var radar_draw := 0.06
@export var lights_draw := 0.05
@export var base_draw := 0.02
@export var charge_rate := 1.6
@export var overload_limit := 0.92
@export var overload_delay := 2.0
@export var battery_warn := 25.0

# ---- generator ----
@export var fuel_start := 45.0
@export var fuel_max := 50.0
@export var fuel_burn_idle := 0.05
@export var fuel_burn_charge := 0.10
@export var crank_time := 1.5
@export var crank_fail_time := 2.5
@export var stop_delay := 3.0
@export var temp_ambient := 18.0
@export var temp_idle := 55.0
@export var temp_rise_charge := 0.32       # per second while charging (x(1 + storm*0.5))
@export var temp_settle := 0.25            # toward idle temperature while running uncharged
@export var temp_cool := 0.6               # per second when stopped
@export var temp_warn := 85.0
@export var temp_trip := 100.0
@export var temp_restart := 60.0

# ---- light ----
@export var auto_speed_deg := 72.0         # 12 rpm
@export var manual_max_deg := 40.0
@export var manual_accel_deg := 120.0
@export var vis_range: Array = [90.0, 140.0, 190.0]
@export var fog_cut := 0.45                # visual range loss at full storm
@export var focus_mul := 1.6
@export var focus_half_deg := 8.0
@export var jam_trip_delay := 8.0
@export var jam_clear_time := 1.0
@export var jam_bearing_deg := 46.0        # the worn tooth on the gear race (note_046)
@export var jam_back_deg := 6.0            # 3B: back the handwheel this far past the tooth to free a story jam
@export var off_wheel_mul := 0.5           # 3B: turning the optic by hand with the motor out is slow work

# ---- ships ----
@export var ship_types := {
	"fishing": {"speed": 3.2, "turn_deg": 14.0, "radius": 2.5, "label": "fishing vessel"},
	"schooner": {"speed": 2.6, "turn_deg": 10.0, "radius": 3.5, "label": "schooner"},
	"steamer": {"speed": 2.0, "turn_deg": 7.0, "radius": 5.0, "label": "cargo steamer"},
	"launch": {"speed": 1.6, "turn_deg": 16.0, "radius": 2.0, "label": "motor launch"},
}
@export var spawn_radius := 230.0
@export var slow_mul := 0.55
@export var ship_accel := 0.5
@export var order_turn_deg := 30.0
@export var blind_turn_error_deg := 25.0
@export var storm_set := 1.6               # m/s onshore drift at full storm for ships that can't see the light
@export var channel_capture_deg := 12.0
@export var channel_capture_min := 55.0
@export var channel_capture_max := 150.0
@export var channel_heading_tol_deg := 35.0
@export var path_lookahead := 20.0
@export var path_capture := 15.0
@export var exit_reach := 15.0
@export var max_lost := 3
@export var mayday_tti := 14.0
@export var recall_interval := 35.0

# ---- radio ----
@export var tx_time := 2.5
@export var reply_delay := 1.8
@export var static_word_prob := 0.3        # at full storm

# ---- storm ----
@export var storm_curve: Array = [[0.0, 0.15], [120.0, 0.3], [270.0, 0.55], [420.0, 0.8], [520.0, 1.0], [600.0, 0.7], [660.0, 0.3]]
@export var lightning_interval_calm := 40.0
@export var lightning_interval_storm := 9.0

# ---- scoring ----
@export var score_saved := 1000
@export var score_never_dark := 250
@export var dark_penalty_per_s := 5.0


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
