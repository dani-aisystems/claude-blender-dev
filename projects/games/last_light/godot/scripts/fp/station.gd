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
## Render layer for everything in the watch room. Exterior lights (outside.gd EXTERIOR_ONLY) skip it;
## the window lights below are the only way the night, the dawn and the lightning get in.
const LAYER_INTERIOR := 2
const LAMP_LAYER := 4                   # render layer 3 (bit value 4): emissive bulbs
const F := 20.0                         # floor height (Blender z = Godot y)
const WARM := Color(1.0, 0.72, 0.45)
const GLASS_MATS := ["M_LL_Glass", "M_LL_Lens"]

var sim: KeeperSim
var room: Node3D
var parts := {}            # name -> {node, rest: Transform3D, angle, target}
var lamps := {}            # id -> StandardMaterial3D
var lights := {}           # id -> Light3D
var lamp_nodes := {}       # id -> the LMP_ mesh node (positions for lights that belong to a lamp)
var focus := {}            # id -> {eye: Vector3, at: Vector3}
var spawn := Transform3D()
var radar_tex: Texture2D
var _t := 0.0
var _wheel_angle := 0.0
var _gov_angle := 0.0
var _gov_speed := 0.0
var _rx_flash := 0.0
var _flicker := 0.0
var _hold_id := ""
var door_open := false
var door_prompt := "Try the stair door"     # game_fp keeps it in step with the chapter and the door
var outside: Node3D                     # set by game_fp: storm, dawn and lightning for the window lights
var windows: Array = []                 # [{light: SpotLight3D, out: Vector3}] one per window bay
var probe: ReflectionProbe
## parts that move continuously while the light turns: no shadows, so they never dirty the shadow cache
const MOVING_PARTS := ["PT_optic_drive", "PT_optic_gear", "PT_optic_governor"]
var fog_cut: FogMaterial                # negative-density fog volume: only a faint haze indoors
var probe_mode := "b"                   # a: capture once + scale; b: re-capture on lighting state changes
var _probe_key := ""
var _probe_recapture := 0

## id -> descriptor. kind: toggle | hold | cycle | focus | wheel | info | doc | door.
## Prompt wording (Stage 2): verb + object in sentence case; panel labels (MAIN, OFF/AUTO/MANUAL) stay in
## capitals because that is what is painted on the equipment.
var DEVICES := {
	"fuel_valve": {"kind": "toggle", "on": "Close the fuel valve", "off": "Open the fuel valve",
		"get": func(k): return k.fuel_valve, "set": func(k, v): return k.set_fuel_valve(v)},
	"start": {"kind": "hold", "prompt": "Hold to crank the generator", "prompt_toggle": "Crank the generator"},
	"charge": {"kind": "toggle", "on": "Switch charging off", "off": "Switch charging on",
		"get": func(k): return k.charge_on, "set": func(k, v): return k.set_charge(v)},
	"brk_main": {"kind": "toggle", "on": "Switch the MAIN breaker off", "off": "Reset the MAIN breaker",
		"get": func(k): return k.main_breaker, "set": func(k, v): return k.set_breaker("main", v)},
	"brk_lights": {"kind": "toggle", "on": "Switch the room lights off", "off": "Switch the room lights on",
		"get": func(k): return k.brk_lights, "set": func(k, v): return k.set_breaker("lights", v)},
	"brk_radar": {"kind": "toggle", "on": "Switch the radar off", "off": "Switch the radar on",
		"get": func(k): return k.brk_radar, "set": func(k, v): return k.set_breaker("radar", v)},
	"mode": {"kind": "cycle", "names": ["OFF", "AUTO", "MANUAL"], "prompt": "Light mode",
		"get": func(k): return k.mode, "set": func(k, v): return k.set_mode(v)},
	"intensity": {"kind": "cycle", "names": ["LOW", "NORMAL", "HIGH"], "prompt": "Lamp intensity",
		"get": func(k): return k.intensity, "set": func(k, v): return k.set_intensity(v)},
	"handwheel": {"kind": "wheel", "prompt": "Turn the handwheel"},
	"console": {"kind": "focus", "prompt": "Operate the light console"},
	"radio": {"kind": "focus", "prompt": "Use the radio"},
	"radar": {"kind": "focus", "prompt": "Use the radio", "focus_id": "radio"},
	"chart": {"kind": "doc", "prompt": "Study the chart"},          # cabin pass: full-screen inspection
	"torch": {"kind": "pickup", "prompt": "Pick up the torch", "idle": "The torch, for when the power fails"},
	"logbook": {"kind": "doc", "prompt": "Write up the station log"},
	"gen_panel": {"kind": "info", "prompt": "Check the generator"},
	"battery": {"kind": "info", "prompt": "Check the battery"},
	"archive": {"kind": "doc", "prompt": "Search the old station logs"},
	"drawer": {"kind": "doc", "prompt": "Open the desk drawer"},
	"photo": {"kind": "doc", "prompt": "Look at the photograph"},
	"note": {"kind": "doc", "prompt": "Read the note on the console"},
	"forecast": {"kind": "doc", "prompt": "Read the teleprinter forecast"},
	"coat_note": {"kind": "doc", "prompt": "Read the note in the coat pocket"},   # cabin pass
	"door": {"kind": "door", "prompt": "The stair door"},
	"power_panel": {"kind": "info", "prompt": "Check the distribution board"},
}
## Set by game_fp (Stage 2): documents only open in the story campaign; the door's prompt and whether
## pressing it does anything follow the chapter and the door state.
var docs_enabled := true
var door_usable := true
## The storage-shelf torch (cabin pass): PROP_torch* meshes and its IA body, hidden once the keeper takes it.
var torch_taken := false
var _torch_nodes: Array = []
var _ia_bodies := {}                    # id -> StaticBody3D (so a taken item stops being targetable)


func setup(k: KeeperSim) -> void:
	sim = k
	room = load("res://assets/models/watch_room.glb").instantiate()
	add_child(room)
	_bind(room)
	_make_window_lights()
	_make_instrument_lights()
	_make_probe()
	_make_fog_cut()
	apply_shadow_preset()


func _bind(root: Node) -> void:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm := String(n.name)
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = LAYER_INTERIOR
		if n is MeshInstance3D:
			_swap_materials(n)
		if nm.begins_with("PT_") or nm.begins_with("NDL_"):
			parts[nm] = {"node": n, "rest": n.transform, "angle": 0.0, "press": 0.0, "w_angle": 0.0, "w_press": 0.0}
			if nm.begins_with("NDL_") or nm in MOVING_PARTS:
				_no_shadow(n)
		elif nm.begins_with("PROP_torch"):
			_torch_nodes.append(n)
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
		var rep := LLMaterials.get_room_mat(nm)      # Stage 1b: interior palette looks (exterior keeps get_mat)
		if rep:
			mi.set_surface_override_material(i, rep)
		elif m is BaseMaterial3D and nm in ["M_LL_Atlas", "M_LL_Chart", "M_LL_Rose", "M_LL_Rug", "M_LL_Photo", "M_LL_Logbook", "M_LL_Props"]:
			var bm := (m as BaseMaterial3D).duplicate()
			# Iteration A: the framed print is semi-gloss photo paper; the ledger is matte rag paper
			bm.roughness = {"M_LL_Atlas": 0.35, "M_LL_Photo": 0.5, "M_LL_Logbook": 0.88, "M_LL_Props": 0.6}.get(nm, 0.8)
			if bm.roughness_texture != null:      # Stage 1 iteration 5: T_LL_Props_rough carries per-texel roughness
				bm.roughness = 1.0
			bm.metallic = 0.0
			bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(i, bm)
	# glass never casts shadows (lamp glass, gauge glass, the optic housing's glazing)
	var all_glass := mesh.get_surface_count() > 0
	for i in mesh.get_surface_count():
		var sm := mesh.surface_get_material(i)
		if sm == null or not (sm.resource_name in GLASS_MATS):
			all_glass = false
	if all_glass or String(mi.name).begins_with("SM_WallLamps"):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


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
	lamp_nodes[id] = n
	# bulbs on render layer 3: seen by cameras, NOT by the reflection probe (cull mask = layer 2), whose
	# low-res capture smeared each glowing globe into a large soft disc on the window glass
	(n as VisualInstance3D).layers = LAMP_LAYER


func _make_interactable(n: Node3D, id: String) -> void:
	var gt := n.global_transform
	var size := gt.basis.get_scale() * 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (INTERACT_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("ia", id)
	_ia_bodies[id] = body
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(size.x, 0.04), maxf(size.y, 0.04), maxf(size.z, 0.04))
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin)


## Base energy of each interior light at full power (the breaker / brownout logic scales these).
func _base_energy(id: String) -> float:
	if id == "desk":
		return 2.6
	if id.begins_with("wall"):
		return 0.85
	if id.begins_with("inst"):
		return 0.8
	if id == "cage":
		return 0.55
	return 0.6


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
		l.light_size = 0.03
	else:
		var o := OmniLight3D.new()
		# low-key pools: wall lamps light their part of the wall, not the whole room
		o.omni_range = 4.0 if id.begins_with("wall") else 2.4
		o.omni_attenuation = 1.6
		l = o
		l.light_size = 0.06 if id.begins_with("wall") else 0.03
	l.light_energy = _base_energy(id)
	l.light_color = WARM
	l.light_volumetric_fog_energy = 0.0
	add_child(l)
	l.global_transform = n.global_transform.orthonormalized()
	if id == "desk":
		# pool of light on the desk top: aim down and slightly toward the room centre
		var p := l.global_position
		var inward := Vector3(-p.x, 0, -p.z).normalized()
		l.look_at(p + Vector3(0, -0.8, 0) + inward * 0.35 + Vector3(0.2, 0, 0), Vector3.FORWARD)
	lights[id] = l


## One cold spot per window bay, outside the glass, aimed down into the room: the night-sky spill,
## the dawn, and the lightning (direction-weighted by the strike bearing). Not on the breaker.
func _make_window_lights() -> void:
	var found: Array = []
	for mi in room.find_children("GLS_window*", "MeshInstance3D", true, false):
		var c: Vector3 = (mi.global_transform * (mi as MeshInstance3D).get_aabb()).get_center()
		found.append({"c": c, "out": Vector3(c.x, 0, c.z).normalized()})
	# centre bay first (bearing 0 = north = -Z): it is the one that keeps shadows on Medium
	found.sort_custom(func(a, b): return a["out"].dot(Vector3.FORWARD) > b["out"].dot(Vector3.FORWARD))
	for i in found.size():
		var c: Vector3 = found[i]["c"]
		var out: Vector3 = found[i]["out"]
		var sp := SpotLight3D.new()
		sp.light_color = Color(0.68, 0.76, 0.92)
		sp.spot_angle = 42.0
		sp.spot_range = 7.5
		sp.spot_attenuation = 0.8
		sp.light_size = 0.25
		sp.light_cull_mask = LAYER_INTERIOR
		sp.light_volumetric_fog_energy = 0.0
		sp.light_specular = 0.25       # lightning lit the varnish as white blobs (chair spindles)
		sp.light_energy = 0.0
		sp.visible = false
		add_child(sp)
		sp.global_position = c + out * 1.4 + Vector3.UP * 0.6
		sp.look_at(c - out * 1.6 + Vector3.DOWN * 1.2, Vector3.UP)
		windows.append({"light": sp, "out": out, "id": "win_%d" % i})


## Small warm spots on the instrument faces so gauges stay readable in a low-key room. They are on
## the room-lights breaker like the lamps. (Their fixtures are modelled in Stage 1 iteration 3.)
func _make_instrument_lights() -> void:
	for pair in [["inst_console", "NDL_bearing"], ["inst_charger", "NDL_battery"], ["inst_gen", "NDL_temp"],
			["inst_power", "PT_brk_lights"]]:
		if not parts.has(pair[1]):
			continue
		var p: Vector3 = parts[pair[1]]["node"].global_position
		var inward := Vector3(-p.x, 0, -p.z).normalized()
		var sp := SpotLight3D.new()
		sp.spot_angle = 50.0
		sp.spot_range = 1.2
		sp.spot_attenuation = 1.0
		sp.light_color = WARM
		sp.light_energy = _base_energy(pair[0])
		sp.light_volumetric_fog_energy = 0.0
		sp.light_cull_mask = LAYER_INTERIOR
		sp.light_specular = 0.0        # fill light for the gauges: no hot spot on the glossy console top
		add_child(sp)
		sp.global_position = p + inward * 0.45 + Vector3.UP * 0.35
		sp.look_at(p, Vector3.UP)
		lights[pair[0]] = sp
	# the generator cage's bulb was emissive only: give it a real light over the engine
	if lamp_nodes.has("cage"):
		var o := OmniLight3D.new()
		o.omni_range = 2.2
		o.omni_attenuation = 1.6
		o.light_size = 0.03
		o.light_color = WARM
		o.light_energy = _base_energy("cage")
		o.light_volumetric_fog_energy = 0.0
		add_child(o)
		o.global_position = (lamp_nodes["cage"] as Node3D).global_position + Vector3.DOWN * 0.06
		lights["cage"] = o


## Interior reflections and ambient: without it every metal and the floor reflected the outdoor
## storm sky. Box-projected over the room; ambient is a dark neutral colour scaled by the room lights.
func _make_probe() -> void:
	probe_mode = String(GameState.user_args.get("probe", "b"))
	if probe_mode == "off":                  # perf bisect: --probe=off
		return
	probe = ReflectionProbe.new()
	probe.size = Vector3(7.0, 3.3, 7.0)
	probe.box_projection = true
	probe.interior = true
	probe.enable_shadows = true
	probe.cull_mask = LAYER_INTERIOR
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.15, 0.13, 0.11)      # warm: the room's own tungsten bounce
	probe.ambient_color_energy = 0.45
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	probe.global_position = Vector3(0, F + 1.55, 0)


## The storm's volumetric fog also filled the room (milky at dawn). A negative-density volume over
## the room removes ~75 % of it: a faint haze keeps the lamp and window light shafts (Daniel, 1a).
func _make_fog_cut() -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(7.0, 3.4, 7.0)
	fog_cut = FogMaterial.new()
	fog_cut.density = 0.0
	fog_cut.albedo = Color(1, 1, 1)
	fog_cut.edge_fade = 0.05
	fv.material = fog_cut
	add_child(fv)
	fv.global_position = Vector3(0, F + 1.6, 0)


## Which lights cast shadows follows the quality preset (Settings.q_shadow_ids).
func apply_shadow_preset() -> void:
	var ids: Array = Settings.q_shadow_ids()
	if GameState.user_args.has("shadow_ids"):     # perf bisect: --shadow_ids=desk,wall_0,...
		ids = Array(String(GameState.user_args["shadow_ids"]).split(","))
	var off := GameState.user_args.has("noshadows")
	for id in lights:
		lights[id].shadow_enabled = not off and not String(id).begins_with("inst") and id != "cage" and ("*" in ids or id in ids)
	for w in windows:
		w["light"].shadow_enabled = not off and ("*" in ids or w["id"] in ids)
	if not Settings.changed.is_connected(apply_shadow_preset):
		Settings.changed.connect(apply_shadow_preset)


func _update_windows() -> void:
	var storm: float = sim.storm
	var dawn := 0.0
	var fl := 0.0
	var fdir := Vector3.ZERO
	if outside:
		dawn = outside.dawn
		fl = outside.flash_now
		var d2: Vector2 = outside._flash_dir
		fdir = Vector3(d2.x, 0, d2.y)
	if fog_cut and outside and outside.env:
		fog_cut.density = -0.75 * outside.env.volumetric_fog_density
	var spill := 0.12 + 0.06 * (1.0 - storm) + 1.6 * dawn
	for w in windows:
		var face := pow(0.5 + 0.5 * (w["out"] as Vector3).dot(fdir), 2.0)
		var e := spill + fl * 5.0 * (0.35 + 0.65 * face)
		var l: SpotLight3D = w["light"]
		l.light_energy = e
		l.light_color = Color(0.68, 0.76, 0.92).lerp(Color(0.95, 0.88, 0.8), dawn)
		l.visible = e > 0.02


## Probe: ambient always follows the room-light level. Mode "a" also scales the (stale) captured
## reflections; mode "b" re-captures whenever the lighting state changes (power, dawn).
func _update_probe(level: float, room_on: bool) -> void:
	if probe == null:
		return
	probe.ambient_color_energy = lerpf(0.12, 0.45, level)  # 1b: cream walls and palette albedo bounce far more
	if probe_mode == "a":
		probe.intensity = lerpf(0.25, 1.0, level)
		return
	var key := "%s|%d" % [room_on, int(round((outside.dawn if outside else 0.0) * 4.0))]
	if key != _probe_key:
		_probe_key = key
		_probe_recapture = 8
		probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	elif _probe_recapture > 0:
		_probe_recapture -= 1
		if _probe_recapture == 0:
			probe.update_mode = ReflectionProbe.UPDATE_ONCE


func _bind_radar(n: MeshInstance3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = radar_tex
	m.albedo_color = Color(0.85, 0.85, 0.85)   # Look 1: emission x1.4 blew the CRT out to white
	n.material_override = m


# ------------------------------------------------------------------ interaction API (player calls these)

## The action text for a control (what pressing it does), without the key.
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
		"hold":
			if not Settings.v["hold_to_crank"]:
				return "Stop cranking" if sim.start_held else d["prompt_toggle"]
			return d["prompt"]
		"door":
			return door_prompt
		"pickup":
			return d["prompt"] if availability(id)["ok"] else d["idle"]
		_:
			return d["prompt"]


## The live reading shown under an info control's prompt (no need to press anything to read it).
func info_text(id: String) -> String:
	match id:
		"gen_panel":
			var st: String = ["Stopped", "Cranking", "Running", "Running down"][sim.gen]
			return "%s  ·  fuel %d L  ·  engine %d °C" % [st, int(sim.fuel), int(sim.gen_temp)]
		"power_panel":
			return "Battery %d %%  ·  draw %.2f %%/s%s" % [int(sim.battery), sim.demand, "" if sim.main_breaker else "  ·  MAIN TRIPPED"]
		"battery":
			return "%d %%%s" % [int(sim.battery), "  ·  charging" if sim.charge_flow > 0.0 else ""]
	return ""


## Can this control be used right now? {ok, reason}. A reason is shown only when the keeper would know
## it by looking (a shut valve, a running engine); story-gated things are unavailable without a reason.
func availability(id: String) -> Dictionary:
	var d: Dictionary = DEVICES.get(id, {})
	if d.is_empty():
		return {"ok": false, "reason": ""}
	match d["kind"]:
		"hold":
			if Settings.v["hold_to_crank"] or not sim.start_held:
				match sim.gen:
					KeeperSim.Gen.RUNNING:
						return {"ok": false, "reason": "The generator is already running."}
					KeeperSim.Gen.STOPPING:
						return {"ok": false, "reason": "Wait for the engine to run down."}
				if sim.gen_overheated and sim.gen_temp > sim.cfg.temp_restart:
					return {"ok": false, "reason": "Still too hot to restart. Let it cool."}
				if sim.fuel <= 0.0:
					return {"ok": false, "reason": "The day-tank is empty."}
				if not sim.fuel_valve:
					return {"ok": false, "reason": "The fuel valve is shut."}
		"doc":
			if not docs_enabled:
				return {"ok": false, "reason": ""}
		"door":
			if not door_usable:
				return {"ok": false, "reason": ""}
		"pickup":                         # Daniel: the torch is for the blackout (taken once, kept)
			if torch_taken or sim.lights_on():
				return {"ok": false, "reason": ""}
	return {"ok": true, "reason": ""}


## Everything the HUD needs for one control: {text, sub, ok, reason, key}. in_view = inside a device view
## (the mouse or pad cursor clicks); free-walk uses the interact key.
func prompt_info(id: String, in_view: bool) -> Dictionary:
	var d: Dictionary = DEVICES.get(id, {})
	if d.is_empty():
		return {}
	var av := availability(id)
	var key := InputSetup.key("click" if in_view else "interact")     # glyphs follow keyboard or pad (2C)
	var sub := ""
	match d["kind"]:
		"info":
			sub = info_text(id)
		"cycle":                          # one-time tips (Stage 2B): gone once the player has used them
			var tips: Array = []
			if InputSetup.pad_active:
				if Settings.tip_wanted("wheel") or Settings.tip_wanted("back"):
					tips.append("%s turn" % InputSetup.key("turn"))
			else:
				if in_view and Settings.tip_wanted("wheel"):
					tips.append("%s turn" % InputSetup.key("turn"))
				if Settings.tip_wanted("back"):
					tips.append("%s turn it back" % InputSetup.key("turn_back"))
			sub = "  ·  ".join(tips)
		"wheel":
			if in_view:
				key = InputSetup.key("handwheel")   # the handwheel turns with A / D or the stick, not a click
	if not av["ok"]:
		key = ""
		if av["reason"] != "":
			sub = av["reason"]
	return {"text": describe(id), "sub": sub, "ok": av["ok"], "reason": av["reason"], "key": key}


## action: "press" (E / LMB down), "release", "next", "prev". Returns sim events. A press on an
## unavailable control is refused with its reason instead (game_fp shows it once, not every press).
func use(id: String, action: String) -> Array:
	var d: Dictionary = DEVICES.get(id, {})
	if d.is_empty():
		return []
	if action == "press":
		var av := availability(id)
		if not av["ok"]:
			return [{"type": "refused", "device": id, "reason": av["reason"]}]
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
		"info":
			if action == "press":
				ev = [{"type": "inspect", "device": id}]
		"hold":
			if not Settings.v["hold_to_crank"]:
				# toggle mode: press once to crank until the engine catches (or press again to stop)
				if action == "press":
					ev = sim.set_start(not sim.start_held)
				return ev + [{"type": "click", "device": id}] if not ev.is_empty() else ev
			if action == "press":
				ev = sim.set_start(true)
				_hold_id = id
			elif action == "release":
				ev = sim.set_start(false)
				_hold_id = ""
	if not ev.is_empty():
		ev.append({"type": "click", "device": id})
		if id == "charge" and sim.charge_on and sim.gen != KeeperSim.Gen.RUNNING:
			ev.append({"type": "note", "device": id, "text": "Charging is on. Nothing will flow until the generator runs."})
	return ev


## The keeper took the torch from the shelf (or a load says he has it): hide it and stop targeting it.
func set_torch_taken(v: bool) -> void:
	torch_taken = v
	for n in _torch_nodes:
		(n as Node3D).visible = not v
	if _ia_bodies.has("torch"):
		(_ia_bodies["torch"] as StaticBody3D).collision_layer = 0 if v else 1 << (INTERACT_LAYER - 1)


func door_position() -> Vector3:
	return parts["PT_stair_door"]["node"].global_position if parts.has("PT_stair_door") else Vector3(0, 20, 2)


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
	# fly-ball governor: spins while the rotation motor runs, winds down when it stops or jams
	_gov_speed = move_toward(_gov_speed, 9.0 if (k.motor_on() and not k.jammed) else 0.0, delta * 4.0)
	_gov_angle = wrapf(_gov_angle + _gov_speed * delta, -PI, PI)
	if parts.has("PT_optic_governor") and _gov_speed > 0.0:
		var gp: Dictionary = parts["PT_optic_governor"]
		gp["node"].transform = gp["rest"] * Transform3D(Basis(Vector3.UP, _gov_angle), Vector3.ZERO)
	_set_angle("PT_fuel_valve", deg_to_rad(-90.0) if k.fuel_valve else 0.0, delta)
	_set_angle("PT_charge", deg_to_rad(-32.0) if k.charge_on else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_main", deg_to_rad(-32.0) if k.main_breaker else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_lights", deg_to_rad(-32.0) if k.brk_lights else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_brk_radar", deg_to_rad(-32.0) if k.brk_radar else deg_to_rad(32.0), delta, 18.0)
	_set_angle("PT_mode", deg_to_rad([60.0, 0.0, -60.0][k.mode]), delta, 16.0)
	_set_angle("PT_intensity", deg_to_rad([60.0, 0.0, -60.0][k.intensity]), delta, 16.0)
	_wheel_angle += k._manual_vel * delta * 6.0
	_set_angle("PT_handwheel", -_wheel_angle, delta, 40.0)
	if not Settings.v["hold_to_crank"] and k.start_held and k.gen == KeeperSim.Gen.RUNNING:
		k.set_start(false)
	_set_press("PT_start", 0.012 if k.start_held else 0.0, delta)
	_set_angle("PT_stair_door", deg_to_rad(-105.0) if door_open else 0.0, delta, 1.2)
	# Stage 1 iteration 5: PT_handset is the desk mic's press-to-talk bar (it was the whole mic, which sank 3 cm into the desk)
	_set_press("PT_handset", -0.004 if k.tx_t > 0.0 else 0.0, delta)
	# lamps
	var blink := fmod(_t, 0.6) < 0.3
	_lamp("gen_run", 3.0 if k.gen == KeeperSim.Gen.RUNNING else (2.0 if k.gen == KeeperSim.Gen.CRANKING and blink else 0.0))
	_lamp("gen_hot", 3.0 if k.gen_temp >= k.cfg.temp_warn and (not k.gen_overheated or blink) else 0.0)
	_lamp("charge", 3.0 if k.charge_flow > 0.0 else 0.0)
	_lamp("main", 3.0 if not k.main_breaker else 0.0)
	_lamp("motor_fault", 3.5 if k.jammed and blink else 0.0)
	_lamp("console_power", 2.0 if k.powered() else 0.0)
	_lamp("optic_motor", 2.0 if (k.motor_on() and not k.jammed) else (2.0 if blink else 0.0) if k.jammed else 0.0)
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
		var base := _base_energy(id)
		if id == "stair":
			l.light_color = Color(1.0, 0.72, 0.45) if room_on else Color(1.0, 0.15, 0.08)
			on = true
			base = 0.3 if room_on else 0.5      # 0.6 turned the 20 mm door gap into a glowing white slot
		l.light_energy = base * f if on else 0.0
	_update_windows()
	_update_probe(f if room_on else 0.0, room_on)
	for id in lamps:
		if id.begins_with("wall"):
			# well-glass bulb: bright enough to read as lit, dim enough that the globe and guard stay
			# visible (4.0 bloomed into a white blob and a ghost disc in the window glass, iteration 2)
			_lamp(id, 1.5 * f if room_on else 0.0)
		elif id == "desk" or id == "cage":
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


## Writes the transform only when the pose really changed (1p performance): any transform write marks the
## part dirty, and a dirty shadow caster makes Godot re-render the shadow map of every shadowed light that
## reaches it. Settled controls written every frame kept all 8 shadow maps re-rendering (2.3M primitives).
func _set_angle(name_: String, target: float, delta: float, speed := 8.0) -> void:
	if not parts.has(name_):
		return
	var p: Dictionary = parts[name_]
	var diff := wrapf(target - p["angle"], -PI, PI)
	p["angle"] = target if absf(diff) < 1e-4 else p["angle"] + diff * minf(1.0, delta * speed)
	if absf(p["angle"] - p["w_angle"]) < 1e-5 and absf(p["press"] - p["w_press"]) < 1e-5:
		return
	p["w_angle"] = p["angle"]
	p["w_press"] = p["press"]
	var rest: Transform3D = p["rest"]
	p["node"].transform = Transform3D(rest.basis * Basis(Vector3.UP, p["angle"]), rest.origin + rest.basis * Vector3(0, p["press"], 0))


func _set_press(name_: String, depth: float, delta: float) -> void:
	if not parts.has(name_):
		return
	var p: Dictionary = parts[name_]
	p["press"] = -depth if absf(p["press"] + depth) < 1e-4 else lerpf(p["press"], -depth, minf(1.0, delta * 20.0))
	_set_angle(name_, p["angle"], delta)
