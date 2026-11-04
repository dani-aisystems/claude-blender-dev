extends Node3D
## The watch room: instantiates watch_room.glb, binds its Blender hooks and keeps every physical
## control in sync with KeeperSim. Interaction is data-driven (DEVICES), not one script per object.
##   IA_<id>   -> StaticBody3D on layer 2 (interaction raycasts) with meta "ia"
##   PT_/NDL_  -> articulated parts, animated about their local Y (Blender local Z)
##   LMP_<id>  -> per-lamp emissive material;  LIGHT_<id> -> real lights
##   FOCUS_<id>/FOCUS_<id>_at -> device-view camera;  SPAWN_player -> start position

signal sim_events(events: Array)

const INTERACT_LAYER := 2
const GAUGE_SWEEP := deg_to_rad(270.0)

var sim: KeeperSim
var room: Node3D
var parts := {}            # name -> {node, rest: Transform3D, angle, target}
var lamps := {}            # id -> StandardMaterial3D
var lights := {}           # id -> Light3D
var focus := {}            # id -> {eye: Vector3, at: Vector3}
var spawn := Transform3D()
var radar_tex: Texture2D
var _t := 0.0
var _wheel_angle := 0.0
var _rx_flash := 0.0
var _flicker := 0.0
var _hold_id := ""

## id -> descriptor. kind: toggle | hold | cycle | focus | wheel. "focus_only" ids only respond in a device view.
var DEVICES := {
	"fuel_valve": {"kind": "toggle", "on": "Close fuel valve", "off": "Open fuel valve",
		"get": func(k): return k.fuel_valve, "set": func(k, v): return k.set_fuel_valve(v)},
	"start": {"kind": "hold", "prompt": "Hold to start generator"},
	"charge": {"kind": "toggle", "on": "Switch charging OFF", "off": "Switch charging ON",
		"get": func(k): return k.charge_on, "set": func(k, v): return k.set_charge(v)},
	"brk_main": {"kind": "toggle", "on": "Open MAIN breaker", "off": "Reset MAIN breaker",
		"get": func(k): return k.main_breaker, "set": func(k, v): return k.set_breaker("main", v)},
	"brk_lights": {"kind": "toggle", "on": "Room lights OFF", "off": "Room lights ON",
		"get": func(k): return k.brk_lights, "set": func(k, v): return k.set_breaker("lights", v)},
	"brk_radar": {"kind": "toggle", "on": "Radar OFF", "off": "Radar ON",
		"get": func(k): return k.brk_radar, "set": func(k, v): return k.set_breaker("radar", v)},
	"mode": {"kind": "cycle", "names": ["OFF", "AUTO", "MANUAL"], "prompt": "Light mode",
		"get": func(k): return k.mode, "set": func(k, v): return k.set_mode(v)},
	"intensity": {"kind": "cycle", "names": ["LOW", "NORMAL", "HIGH"], "prompt": "Lamp intensity",
		"get": func(k): return k.intensity, "set": func(k, v): return k.set_intensity(v)},
	"handwheel": {"kind": "wheel", "prompt": "Turn handwheel  (hold A / D)"},
	"console": {"kind": "focus", "prompt": "Operate light console"},
	"radio": {"kind": "focus", "prompt": "Use radio"},
	"radar": {"kind": "focus", "prompt": "Use radio", "focus_id": "radio"},
	"chart": {"kind": "focus", "prompt": "Study chart"},
	"logbook": {"kind": "logbook", "prompt": "Read logbook"},
	"gen_panel": {"kind": "info", "prompt": "Generator"},
	"power_panel": {"kind": "info", "prompt": "Distribution"},
}


func setup(k: KeeperSim) -> void:
	sim = k
	room = load("res://assets/models/watch_room.glb").instantiate()
	add_child(room)
	_bind(room)


func _bind(root: Node) -> void:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm := String(n.name)
		if n is MeshInstance3D:
			_swap_materials(n)
		if nm.begins_with("PT_") or nm.begins_with("NDL_"):
			parts[nm] = {"node": n, "rest": n.transform, "angle": 0.0, "press": 0.0}
		elif nm.begins_with("LMP_"):
			_bind_lamp(n, nm.substr(4))
		elif nm.begins_with("IA_"):
			_make_interactable(n, nm.substr(3))
		elif nm.begins_with("LIGHT_"):
			_make_light(n, nm.substr(6))
		elif nm.begins_with("FOCUS_"):
			var key := nm.substr(6)
			if key.ends_with("_at"):
				var id := key.trim_suffix("_at")
				focus[id] = focus.get(id, {})
				focus[id]["at"] = n.global_position
			else:
				focus[key] = focus.get(key, {})
				focus[key]["eye"] = n.global_position
		elif nm == "SPAWN_player":
			spawn = n.global_transform
		elif nm.begins_with("SCR_radar") and n is MeshInstance3D:
			call_deferred("_bind_radar", n)
		elif nm.begins_with("GLS_window") and n is MeshInstance3D:
			n.material_override = LLMaterials.glass() if GameState.user_args.has("noglass") else WindowGlass.material()
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.begins_with("GLS_") and n is MeshInstance3D:
			n.material_override = LLMaterials.glass()
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _swap_materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m == null:
			continue
		var nm := m.resource_name
		var rep := LLMaterials.get_mat(nm)
		if rep:
			mi.set_surface_override_material(i, rep)
		elif m is BaseMaterial3D and nm in ["M_LL_Atlas", "M_LL_Chart", "M_LL_Rose", "M_LL_Rug"]:
			var bm := (m as BaseMaterial3D).duplicate()
			bm.roughness = 0.35 if nm == "M_LL_Atlas" else 0.8
			bm.metallic = 0.0
			bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(i, bm)


func _bind_lamp(n: Node, id: String) -> void:
	if not (n is MeshInstance3D):
		return
	var col := Color(1.0, 0.75, 0.42)
	var src: Material = n.mesh.surface_get_material(0) if n.mesh else null
	var src_name := src.resource_name if src else ""
	if src_name.ends_with("Red"):
		col = Color(1.0, 0.16, 0.08)
	elif src_name.ends_with("Green"):
		col = Color(0.3, 1.0, 0.45)
	elif src_name.ends_with("Amber"):
		col = Color(1.0, 0.62, 0.12)
	var m := LLMaterials.lamp(col)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps[id] = m


func _make_interactable(n: Node3D, id: String) -> void:
	var gt := n.global_transform
	var size := gt.basis.get_scale() * 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (INTERACT_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("ia", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(size.x, 0.04), maxf(size.y, 0.04), maxf(size.z, 0.04))
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin)


func _make_light(n: Node3D, id: String) -> void:
	if id == "lamp":
		return    # the lantern light lives outside (outside.gd)
	var l: Light3D
	if id == "desk":
		var s := SpotLight3D.new()
		s.spot_angle = 55.0
		s.spot_range = 3.5
		s.spot_attenuation = 1.2
		l = s
		l.light_energy = 2.6
		l.shadow_enabled = true
	else:
		var o := OmniLight3D.new()
		o.omni_range = 4.5 if id.begins_with("wall") else 2.4
		o.omni_attenuation = 1.4
		l = o
		l.light_energy = 0.9 if id.begins_with("wall") else 0.6
		l.shadow_enabled = id in ["wall_0", "wall_1"]
	l.light_color = Color(1.0, 0.72, 0.45)
	l.light_volumetric_fog_energy = 0.0
	if GameState.user_args.has("noshadows"):
		l.shadow_enabled = false
	add_child(l)
	l.global_transform = n.global_transform.orthonormalized()
	if id == "desk":
		# pool of light on the desk top: aim down and slightly toward the room centre
		var p := l.global_position
		var inward := Vector3(-p.x, 0, -p.z).normalized()
		l.look_at(p + Vector3(0, -0.8, 0) + inward * 0.35 + Vector3(0.2, 0, 0), Vector3.FORWARD)
	lights[id] = l


func _bind_radar(n: MeshInstance3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = radar_tex
	m.albedo_color = Color(0.85, 0.85, 0.85)   # Look 1: emission x1.4 blew the CRT out to white
	n.material_override = m


# ------------------------------------------------------------------ interaction API (player calls these)

func describe(id: String) -> String:
	var d: Dictionary = DEVICES.get(id, {})
	if d.is_empty():
		return ""
	match d["kind"]:
		"toggle":
			return d["on"] if d["get"].call(sim) else d["off"]
		"cycle":
			var names: Array = d["names"]
			return "%s: %s  →  %s" % [d["prompt"], names[d["get"].call(sim)], names[(d["get"].call(sim) + 1) % names.size()]]
		"info":
			return info_text(id)
		_:
			return d["prompt"]


func info_text(id: String) -> String:
	match id:
		"gen_panel":
			var st: String = ["stopped", "cranking", "running", "stopping"][sim.gen]
			return "Generator %s · fuel %d L · temp %d%%" % [st, int(sim.fuel), int(sim.gen_temp)]
		"power_panel":
			return "Battery %d%% · draw %.2f %%/s%s" % [int(sim.battery), sim.demand, "" if sim.main_breaker else " · MAIN TRIPPED"]
	return ""


## action: "press" (E / LMB down), "release", "next", "prev". Returns sim events.
func use(id: String, action: String) -> Array:
	var d: Dictionary = DEVICES.get(id, {})
	if d.is_empty():
		return []
	var ev: Array = []
	match d["kind"]:
		"toggle":
			if action == "press":
				ev = d["set"].call(sim, not d["get"].call(sim))
		"cycle":
			var n: int = d["names"].size()
			if action == "press" or action == "next":
				ev = d["set"].call(sim, (d["get"].call(sim) + 1) % n)
			elif action == "prev":
				ev = d["set"].call(sim, (d["get"].call(sim) + n - 1) % n)
		"hold":
			if action == "press":
				ev = sim.set_start(true)
				_hold_id = id
			elif action == "release":
				ev = sim.set_start(false)
				_hold_id = ""
	if not ev.is_empty():
		ev.append({"type": "click", "device": id})
	return ev


func release_all() -> Array:
	if _hold_id != "":
		_hold_id = ""
		return sim.set_start(false)
	return []


func focus_for(id: String) -> Dictionary:
	var d: Dictionary = DEVICES.get(id, {})
	return focus.get(d.get("focus_id", id), {})


# ------------------------------------------------------------------ visual sync

func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_body(delta)
	GameState.prof_add("station", Time.get_ticks_usec() - _pt)


func _process_body(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	var k := sim
	_set_gauge("NDL_battery", k.battery / 100.0, delta)
	_set_gauge("NDL_charge_amps", k.charge_amps() / 50.0, delta)
	_set_gauge("NDL_fuel", k.fuel / k.cfg.fuel_max, delta)
	_set_gauge("NDL_temp", clampf((k.gen_temp - k.cfg.temp_ambient) / (k.cfg.temp_trip - k.cfg.temp_ambient), 0.0, 1.0), delta)
	_set_gauge("NDL_motor", k.motor_amps() / 10.0 + (sin(_t * 23.0) * 0.02 if k.jammed else 0.0), delta, 6.0)
	_set_gauge("NDL_signal", (0.25 + 0.6 * _rx_flash + 0.08 * sin(_t * 9.0)) if k.radio_on() else 0.0, delta)
	_set_angle("NDL_bearing", -k.bearing, delta, 30.0)
	var minutes := k.clock_minutes()
	_set_angle("NDL_clock_m", -fmod(minutes, 60.0) / 60.0 * TAU, delta, 50.0)
	_set_angle("NDL_clock_h", -fmod(minutes / 60.0, 12.0) / 12.0 * TAU, delta, 50.0)
	_set_angle("PT_optic_drive", -k.bearing * 3.0, delta, 60.0)
	_set_angle("PT_optic_gear", -k.bearing * 2.0, delta, 60.0)
	_set_angle("PT_fuel_valve", deg_to_rad(-90.0) if k.fuel_valve else 0.0, delta)
	_set_angle("PT_charge", deg_to_rad(-32.0) if k.charge_on else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_main", deg_to_rad(-32.0) if k.main_breaker else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_lights", deg_to_rad(-32.0) if k.brk_lights else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_radar", deg_to_rad(-32.0) if k.brk_radar else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_mode", deg_to_rad([60.0, 0.0, -60.0][k.mode]), delta, 16.0)
	_set_angle("PT_intensity", deg_to_rad([60.0, 0.0, -60.0][k.intensity]), delta, 16.0)
	_wheel_angle += k._manual_vel * delta * 6.0
	_set_angle("PT_handwheel", -_wheel_angle, delta, 40.0)
	_set_press("PT_start", 0.012 if k.start_held else 0.0, delta)
	_set_press("PT_handset", -0.03 if k.tx_t > 0.0 else 0.0, delta)
	# lamps
	var blink := fmod(_t, 0.6) < 0.3
	_lamp("gen_run", 3.0 if k.gen == KeeperSim.Gen.RUNNING else (2.0 if k.gen == KeeperSim.Gen.CRANKING and blink else 0.0))
	_lamp("gen_hot", 3.0 if k.gen_temp >= k.cfg.temp_warn and (not k.gen_overheated or blink) else 0.0)
	_lamp("charge", 3.0 if k.charge_flow > 0.0 else 0.0)
	_lamp("main", 3.0 if not k.main_breaker else 0.0)
	_lamp("motor_fault", 3.5 if k.jammed and blink else 0.0)
	_lamp("console_power", 2.0 if k.powered() else 0.0)
	_lamp("radio_tx", 3.0 if k.tx_t > 0.0 else 0.0)
	_rx_flash = maxf(0.0, _rx_flash - delta * 0.7)
	_lamp("radio_rx", 3.0 * _rx_flash if k.radio_on() else 0.0)
	# room lighting: powered + lights breaker; brownout flicker; stair lamp = battery-backed emergency light
	_flicker = maxf(0.0, _flicker - delta)
	var room_on := k.lights_on()
	var f := 1.0
	if _flicker > 0.0:
		f = 0.4 + 0.6 * float(randf() > 0.35)
	elif room_on and k.battery < 10.0:
		f = 0.75 + 0.25 * sin(_t * 31.0)
	for id in lights:
		var l: Light3D = lights[id]
		var on := room_on
		var base := 2.6 if id == "desk" else (0.9 if id.begins_with("wall") else 0.6)
		if id == "stair":
			l.light_color = Color(1.0, 0.72, 0.45) if room_on else Color(1.0, 0.15, 0.08)
			on = true
			base = 0.6 if room_on else 0.5
		l.light_energy = base * f if on else 0.0
	for id in lamps:
		if id == "desk" or id.begins_with("wall") or id == "cage":
			_lamp(id, 4.0 * f if room_on else 0.0)
		elif id == "stair":
			lamps[id].emission = Color(1.0, 0.75, 0.42) if room_on else Color(1.0, 0.15, 0.08)
			_lamp(id, 4.0 * f if room_on else 2.5)


func on_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"radio":
				_rx_flash = 1.0
			"brownout", "breaker_trip", "battery_dead":
				_flicker = 1.2


func _lamp(id: String, energy: float) -> void:
	if lamps.has(id):
		lamps[id].emission_energy_multiplier = energy


func _set_gauge(name_: String, v: float, delta: float, speed := 4.0) -> void:
	_set_angle(name_, (0.5 - clampf(v, 0.0, 1.0)) * GAUGE_SWEEP, delta, speed)


func _set_angle(name_: String, target: float, delta: float, speed := 8.0) -> void:
	if not parts.has(name_):
		return
	var p: Dictionary = parts[name_]
	var diff := wrapf(target - p["angle"], -PI, PI)
	p["angle"] = p["angle"] + diff * minf(1.0, delta * speed)
	var rest: Transform3D = p["rest"]
	p["node"].transform = Transform3D(rest.basis * Basis(Vector3.UP, p["angle"]), rest.origin + rest.basis * Vector3(0, p["press"], 0))


func _set_press(name_: String, depth: float, delta: float) -> void:
	if not parts.has(name_):
		return
	var p: Dictionary = parts[name_]
	p["press"] = lerpf(p["press"], -depth, minf(1.0, delta * 20.0))
	_set_angle(name_, p["angle"], delta)
