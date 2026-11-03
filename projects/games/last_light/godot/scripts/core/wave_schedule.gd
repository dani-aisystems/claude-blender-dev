class_name WaveSchedule
extends RefCounted
## Turns data/waves.json into a seeded, jittered, time-sorted spawn list.

const DEFAULT_PATH := "res://data/waves.json"

var spawns: Array[Dictionary] = []   # {t, kind, bearing (rad), speed_mul, phase}
var gusts: Array[Dictionary] = []    # {t, dir}


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("waves: cannot open %s" % path)
		return {}
	return JSON.parse_string(f.get_as_text())


static func build(data: Dictionary, cfg: GameConfig, rng: RandomNumberGenerator, layout: LayoutData) -> WaveSchedule:
	var s := WaveSchedule.new()
	var lo := layout.spawn_arc.x
	var hi := layout.spawn_arc.y
	for e in data["ships"]:
		var fixed: bool = e.get("fixed", false)
		var t := float(e["t"])
		var b := float(e["bearing"])
		var sm := float(e.get("speed_mul", 1.0))
		if not fixed:
			t += rng.randf_range(-cfg.spawn_time_jitter, cfg.spawn_time_jitter)
			b += rng.randf_range(-cfg.spawn_bearing_jitter_deg, cfg.spawn_bearing_jitter_deg)
			sm *= 1.0 + rng.randf_range(-cfg.spawn_speed_jitter, cfg.spawn_speed_jitter)
		s.spawns.append({
			"t": maxf(0.5, t), "kind": String(e["kind"]), "bearing": deg_to_rad(clampf(b, lo, hi)),
			"speed_mul": sm, "phase": String(e.get("phase", "")),
		})
	s.spawns.sort_custom(func(a, b): return a["t"] < b["t"])
	for g in data.get("gusts", []):
		s.gusts.append({"t": float(g["t"]), "dir": float(g["dir"])})
	return s
