extends Node3D
## The playable world: owns a SimWorld, builds the scene (Blender GLBs, greybox fallback),
## turns input into sim steps and sim events into visuals. HUD/audio listen to `sim_event`.

signal sim_event(e: Dictionary)
signal finished(stats: Dictionary)

const MODELS := "res://assets/models/%s.glb"

var cfg := GameConfig.new()
var sim := SimWorld.new()
var bot: KeeperBot = null           # set for captures / autotest
var camera: Camera3D
var env: Environment
var moon: DirectionalLight3D
var lightning_light: DirectionalLight3D
var beam_pivot: Node3D
var beam_light: SpotLight3D
var beam_cone: MeshInstance3D
var beam_cone_mat: StandardMaterial3D
var lantern: Node3D
var lantern_glow: OmniLight3D
var ocean: MeshInstance3D
var ship_views := {}               # id -> ship_view node
var _t := 0.0
var _flash := 0.0
var _shake := 0.0
var _cam_base := Transform3D()
var _ended := false
var _model_cache := {}
var view := "gameplay"            # capture/debug views: gameplay, lighthouse, ocean, ship


func set_view(v: String) -> void:
	view = v
	match v:
		"lighthouse":
			camera.fov = 40.0
			camera.position = Vector3(16, 14, 30)
			camera.look_at(Vector3(0, 13, 0), Vector3.UP)
		"ocean":
			camera.fov = 50.0
			camera.position = Vector3(-30, 9, 40)
			camera.look_at(Vector3(10, 0, -70), Vector3.UP)
		_:
			camera.fov = 44.0
			camera.position = Vector3(0, 92, 96)
			camera.look_at(Vector3(0, 0, -52), Vector3.UP)
	_cam_base = camera.transform


func start(seed_value: int, bot_mode: String = "") -> void:
	sim.setup(cfg, LayoutData.load_file(), WaveSchedule.load_data(), seed_value)
	if bot_mode != "":
		bot = KeeperBot.new(bot_mode, seed_value)
	_build_environment()
	_build_camera()
	_build_ocean()
	_build_island()
	_build_reefs()
	_build_lighthouse()


func model(name_: String) -> PackedScene:
	if _model_cache.has(name_):
		return _model_cache[name_]
	var path := MODELS % name_
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_model_cache[name_] = scene
	return scene


# ------------------------------------------------------------------ build

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.55)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.15)
	env.fog_density = 0.004
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	env.volumetric_fog_emission = Color(0.012, 0.016, 0.026)
	env.volumetric_fog_length = 260.0
	env.volumetric_fog_detail_spread = 2.0
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.85)
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-38, 150, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 320.0
	moon.light_volumetric_fog_energy = 0.4
	add_child(moon)
	lightning_light = DirectionalLight3D.new()
	lightning_light.light_color = Color(0.8, 0.86, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.rotation_degrees = Vector3(-60, -30, 0)
	lightning_light.light_volumetric_fog_energy = 1.0
	add_child(lightning_light)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 44.0
	camera.near = 1.0
	camera.far = 900.0
	add_child(camera)
	camera.position = Vector3(0, 92, 96)      # Look 1: (0,112,112) -> closer, lighthouse read too small
	camera.look_at(Vector3(0, 0, -52), Vector3.UP)
	_cam_base = camera.transform
	camera.current = true


func _build_ocean() -> void:
	ocean = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	ocean.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.07, 0.11)
	mat.roughness = 0.25
	mat.metallic_specular = 0.6
	ocean.material_override = mat
	add_child(ocean)


func _build_island() -> void:
	var scene := model("island")
	if scene:
		add_child(scene.instantiate())
		return
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = sim.layout.island_radius - 3.0
	cm.bottom_radius = sim.layout.island_radius + 2.0
	cm.height = 6.0
	cm.radial_segments = 14
	m.mesh = cm
	m.position.y = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.2)
	m.material_override = mat
	add_child(m)


func _build_reefs() -> void:
	var scenes := [model("reef_rock_a"), model("reef_rock_b"), model("reef_rock_c")]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.22)
	mat.roughness = 0.9
	for r in sim.layout.reefs:
		var node: Node3D
		var sc: PackedScene = scenes[r["variant"] % 3]
		if sc:
			node = sc.instantiate()
			node.scale = Vector3.ONE * r["r"]
			node.scale.y *= r["height"]
		else:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r["r"]
			sm.height = r["r"] * 2.0 * r["height"] * 0.7
			sm.radial_segments = 7
			sm.rings = 4
			mi.mesh = sm
			mi.material_override = mat
			node = mi
		node.position = Geo.to_v3(r["pos"], 0.0)
		node.rotation.y = deg_to_rad(r["rot"])
		add_child(node)


func _build_lighthouse() -> void:
	var tower_h := 15.0
	var scene := model("lighthouse")
	if scene:
		add_child(scene.instantiate())
	else:
		var tower := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.8
		cm.bottom_radius = 2.8
		cm.height = tower_h
		tower.mesh = cm
		tower.position = Vector3(0, 4.0 + tower_h * 0.5, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.83, 0.78)
		tower.material_override = mat
		add_child(tower)
	var lantern_y := 4.0 + tower_h + 1.2
	lantern = Node3D.new()
	lantern.position = Vector3(0, lantern_y, 0)
	add_child(lantern)
	var lscene := model("lantern")
	if lscene:
		lantern.add_child(lscene.instantiate())
	lantern_glow = OmniLight3D.new()
	lantern_glow.light_color = Color(1.0, 0.72, 0.38)
	lantern_glow.light_energy = 3.0
	lantern_glow.omni_range = 26.0
	lantern_glow.light_volumetric_fog_energy = 1.5
	add_child(lantern_glow)
	lantern_glow.position = lantern.position
	# beam: a pivot that yaws with the sim bearing
	beam_pivot = Node3D.new()
	beam_pivot.position = lantern.position
	add_child(beam_pivot)
	beam_light = SpotLight3D.new()
	beam_light.light_color = Color(1.0, 0.72, 0.38)
	beam_light.light_energy = 18.0
	beam_light.spot_range = cfg.beam_range + 20.0
	beam_light.spot_attenuation = 0.6
	beam_light.light_volumetric_fog_energy = 2.0
	beam_light.shadow_enabled = false
	beam_light.rotation_degrees = Vector3(-5.0, 0, 0)   # slight down-tilt toward the sea
	beam_pivot.add_child(beam_light)
	var cone_tilt := Node3D.new()
	cone_tilt.rotation_degrees = Vector3(-5.0, 0, 0)   # pitch down toward the sea, like the light
	beam_pivot.add_child(cone_tilt)
	beam_cone = MeshInstance3D.new()
	beam_cone_mat = StandardMaterial3D.new()
	beam_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_cone_mat.albedo_color = Color(1.0, 0.7, 0.35, 0.06)
	beam_cone.material_override = beam_cone_mat
	cone_tilt.add_child(beam_cone)
	_set_cone(false)


func _set_cone(boost: bool) -> void:
	var length := cfg.beam_boost_range if boost else cfg.beam_range
	var half := deg_to_rad(cfg.beam_boost_half_angle_deg if boost else cfg.beam_half_angle_deg)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = tan(half) * length
	cm.height = length
	cm.radial_segments = 24
	cm.cap_top = false
	cm.cap_bottom = false
	beam_cone.mesh = cm
	# cylinder axis is Y with the narrow top at +Y. Rotating +90 about X maps +Y -> +Z, so the
	# narrow end sits at the lantern (z = 0) and the wide end at -length (forward).
	beam_cone.rotation_degrees = Vector3(90.0, 0, 0)
	beam_cone.position = Vector3(0, 0, -length * 0.5)
	beam_light.spot_angle = rad_to_deg(half) * 1.15
	beam_light.spot_range = length + 20.0


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if _ended:
		return
	var turn := 0.0
	var boost := false
	if bot:
		var d := bot.decide(sim, delta)
		turn = d["turn"]
		boost = d["boost"]
	else:
		turn = Input.get_axis("beam_left", "beam_right")
		boost = Input.is_action_pressed("boost")
	var events := sim.step(delta, turn, boost)
	for e in events:
		_handle(e)
		sim_event.emit(e)


func _handle(e: Dictionary) -> void:
	match e["type"]:
		"ship_spawned":
			var s := sim.find_ship(e["id"])
			var v := preload("res://scripts/ship_view.gd").new()
			add_child(v)
			v.setup(s, model(v.MODEL_FOR[s.kind]))
			ship_views[s.id] = v
		"ship_locked":
			if ship_views.has(e["id"]):
				ship_views[e["id"]].on_locked()
		"ship_wrecked":
			_shake = maxf(_shake, 0.6)
		"lightning":
			_flash = e["power"]
			_shake = maxf(_shake, 0.25 * e["power"])
		"boost_on", "boost_off":
			_set_cone(sim.beam.boosting)
		"game_won", "game_lost":
			_ended = true
			finished.emit(sim.stats())


func _process(delta: float) -> void:
	_t += delta
	var storm := sim.storm
	beam_pivot.rotation.y = Geo.yaw_for(sim.beam.bearing)
	if lantern:
		lantern.rotation.y = beam_pivot.rotation.y
	var boost := sim.beam.boosting
	beam_light.light_energy = (30.0 if boost else 18.0) * (0.96 + 0.04 * sin(_t * 23.0))
	beam_cone_mat.albedo_color.a = 0.09 if boost else 0.055
	lantern_glow.light_energy = 3.5 if boost else 2.6
	# weather (M3 replaces this with the storm director)
	env.volumetric_fog_density = lerpf(0.005, 0.013, storm)
	_flash = maxf(0.0, _flash - delta * 2.6)
	var f := _flash * (0.6 + 0.4 * sin(_t * 60.0))
	lightning_light.light_energy = f * 2.2
	env.background_color = Color(0.035, 0.045, 0.07).lerp(Color(0.4, 0.45, 0.6), f * 0.35)
	# camera: gentle sway + lean toward the beam + small shakes
	_shake = maxf(0.0, _shake - delta * 1.5)
	var sway := Vector3(sin(_t * 0.23) * 0.8, sin(_t * 0.31) * 0.5, 0.0)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.6
	var lean := clampf(Geo.angle_diff(0.0, sim.beam.bearing), -1.5, 1.5) * deg_to_rad(2.0)
	if view == "ship":
		var target: ShipModel = null
		for sh in sim.active_ships():
			target = sh
			break
		if target:
			var p := Geo.to_v3(target.pos)
			var side := Geo.to_v3(Geo.dir(target.heading + PI * 0.6)) * 26.0
			camera.fov = 45.0
			camera.position = p + side + Vector3(0, 8, 0)
			camera.look_at(p + Vector3(0, 2, 0), Vector3.UP)
		return_ships(delta, storm)
		return
	camera.transform = _cam_base
	if view == "gameplay":
		camera.position += sway + shake
		camera.rotate(Vector3.UP, -lean)
	return_ships(delta, storm)


func return_ships(delta: float, storm: float) -> void:
	for id in ship_views.keys():
		var v = ship_views[id]
		if v.ship.is_active() or sim.t - v.ship.resolve_time < 12.0:
			v.tick(_t, delta, storm)
		else:
			v.queue_free()
			ship_views.erase(id)
