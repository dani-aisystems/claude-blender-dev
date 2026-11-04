extends Node3D
## Everything beyond the watch-room glass: environment, storm sky, ocean, island, reefs, the lighthouse
## exterior and its beam, rain, lightning, ships, and the dawn at the end. Driven by KeeperSim state.

const SHIP_VIEW := preload("res://scripts/fp/ship_view2.gd")
const LANTERN_Y := 24.8
## Render layer 2 = the watch-room interior (station.gd LAYER_INTERIOR). Exterior lights skip it:
## the room is lit only by its own lamps and by what comes in through the windows.
const EXTERIOR_ONLY := 0xFFFFF & ~2

var sim: KeeperSim
var env: Environment
var sky_mat: ShaderMaterial
var ocean_mat: ShaderMaterial
var beam_mat: ShaderMaterial
var moon: DirectionalLight3D
var bolt_light: DirectionalLight3D
var beam_pivot: Node3D
var beam_light: SpotLight3D
var beam_cone: MeshInstance3D
var lamp_glow: OmniLight3D
var optic: Node3D
var rain: GPUParticles3D
var ship_views := {}
var dawn := 0.0
var dusk := 0.0          # story: lighting-up time at 16:20 fades to night
var _sky_mode := "night"
var attract := false     # title shot from the sea: thinner fog so the night and the beam read


func set_sky(kind: String) -> void:
	_sky_mode = kind
	match kind:
		"dusk":
			dusk = 1.0
		"dawn":
			dusk = 0.0
		_:
			dusk = 0.0
var flash := 0.0
var flash_now := 0.0      # the flicker-shaped flash actually shown this frame (station window lights read it)
var _t := 0.0
var _flash_dir := Vector2(0, -1)
var _noise_tex: NoiseTexture2D


func setup(k: KeeperSim) -> void:
	sim = k
	_noise_tex = _noise(256, 0.02, false)
	_environment()
	_ocean()
	_island()
	_reefs()
	_jetty()
	_lighthouse()
	_beam()
	_rain()


# ------------------------------------------------------------------ build

func _noise(size: int, freq: float, normal: bool, seamless := true) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = seamless
	t.noise = n
	t.as_normal_map = normal
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	return t


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("clouds", _noise(512, 0.012, false))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.35
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.065, 0.085)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.6
	env.fog_height = 30.0
	env.fog_height_density = 0.02
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.82)
	env.volumetric_fog_emission = Color(0.006, 0.008, 0.012)
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	# perf bisect flags: --novolfog --nossao --nossil --halfao --norain --noglow --noshadows
	var a: Dictionary = GameState.user_args
	env.volumetric_fog_enabled = not a.has("novolfog") and Settings.q_volumetric()
	env.ssao_enabled = not a.has("nossao") and Settings.q_ssao()
	env.ssil_enabled = not a.has("nossil") and Settings.q_ssil()
	env.ssil_radius = 2.0                      # the room is 6.5 m across: short-range bounce only
	env.ssil_intensity = 1.0
	var half: bool = Settings.q_half_size() or a.has("halfao")   # --halfao: perf bisect
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if half else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, half, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW if half else RenderingServer.ENV_SSIL_QUALITY_MEDIUM, half, 0.5, 4, 50.0, 300.0)
	env.glow_enabled = not a.has("noglow")
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.64, 0.82)
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-34, 160, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	moon.light_volumetric_fog_energy = 0.3
	moon.light_cull_mask = EXTERIOR_ONLY
	add_child(moon)
	bolt_light = DirectionalLight3D.new()
	bolt_light.light_color = Color(0.78, 0.84, 1.0)
	bolt_light.light_energy = 0.0
	bolt_light.rotation_degrees = Vector3(-50, 0, 0)
	bolt_light.light_volumetric_fog_energy = 1.2
	bolt_light.light_cull_mask = EXTERIOR_ONLY   # lightning reaches the room through the windows (station.gd)
	add_child(bolt_light)


func _ocean() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1100, 1100)
	pm.subdivide_width = 330
	pm.subdivide_depth = 330
	mi.mesh = pm
	ocean_mat = ShaderMaterial.new()
	ocean_mat.shader = load("res://shaders/ocean.gdshader")
	ocean_mat.set_shader_parameter("waves", OceanWaves.shader_array())
	ocean_mat.set_shader_parameter("detail_a", _noise(512, 0.03, true))
	ocean_mat.set_shader_parameter("detail_b", _noise(512, 0.06, true))
	ocean_mat.set_shader_parameter("foam_noise", _noise(256, 0.05, false))
	ocean_mat.set_shader_parameter("shore_field", _shore_field())
	mi.material_override = ocean_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = not GameState.user_args.has("noocean")
	add_child(mi)
	# far skirt so the horizon never shows the edge
	var far := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(6000, 6000)
	far.mesh = fm
	far.position.y = -0.6
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.012, 0.03, 0.045)
	fmat.roughness = 0.2
	far.material_override = fmat
	add_child(far)


## Foam proximity field: 1 at rocks/shore, fading out over ~10 m. 256 px over 520 m.
func _shore_field() -> ImageTexture:
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_R8)
	var rect := Vector4(-260, -260, 520, 520)
	var circles: Array = []
	for r in sim.layout.reefs:
		circles.append([r["pos"], r["r"]])
	circles.append([Vector2.ZERO, sim.layout.island_radius + 2.0])
	for y in N:
		for x in N:
			var p := Vector2(rect.x + (x + 0.5) / N * rect.z, rect.y + (y + 0.5) / N * rect.w)
			var best := 99.0
			for c in circles:
				best = minf(best, p.distance_to(c[0]) - c[1])
			img.set_pixel(x, y, Color(clampf(1.0 - best / 11.0, 0.0, 1.0), 0, 0))
	return ImageTexture.create_from_image(img)


func _island() -> void:
	var model := "res://assets/models/island.glb"
	if ResourceLoader.exists(model):
		add_child(load(model).instantiate())
		return
	# procedural stand-in: rugged dome with cliffs, rises to the tower plinth (3.5 m)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 4
	var R := sim.layout.island_radius + 6.0
	var n := 90
	var step := 2.0 * R / n
	var hgt := func(x: float, z: float) -> float:
		var r := Vector2(x, z).length() + noise.get_noise_2d(x, z) * 4.0
		var top := 3.4 + noise.get_noise_2d(x * 2.0, z * 2.0) * 0.6
		var cliff := smoothstep(R - 1.0, R - 9.0, r)
		var h := lerpf(-3.0, top, cliff)
		if Vector2(x, z).length() < 6.5:
			h = maxf(h, 3.5)
		return h + noise.get_noise_2d(x * 4.0, z * 4.0) * 0.4 * cliff
	for iz in n:
		for ix in n:
			var x0 := -R + ix * step
			var z0 := -R + iz * step
			var q := [Vector3(x0, hgt.call(x0, z0), z0), Vector3(x0 + step, hgt.call(x0 + step, z0), z0),
				Vector3(x0 + step, hgt.call(x0 + step, z0 + step), z0 + step), Vector3(x0, hgt.call(x0, z0 + step), z0 + step)]
			if q[0].y < -2.9 and q[1].y < -2.9 and q[2].y < -2.9 and q[3].y < -2.9:
				continue
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("rock_a", load("res://assets/textures/cliff_side_diff.png"))
	m.set_shader_parameter("rock_n", load("res://assets/textures/cliff_side_nor_gl.png"))
	m.set_shader_parameter("grass_a", load("res://assets/textures/sparse_grass_diff.png"))
	m.set_shader_parameter("shore_a", load("res://assets/textures/coast_land_rocks_01_diff.png"))
	mi.material_override = m
	add_child(mi)


func _reefs() -> void:
	var meshes: Array = []
	for v in 3:
		meshes.append(_rock_mesh(v))
	var mat := LLMaterials.get_mat("M_LL_Rock")
	for r in sim.layout.reefs:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[r["variant"] % 3]
		mi.material_override = mat
		mi.position = Geo.to_v3(r["pos"], -0.6)
		mi.rotation.y = deg_to_rad(r["rot"])
		mi.scale = Vector3(r["r"], r["r"] * (0.55 + 0.6 * r["height"]), r["r"])
		add_child(mi)


## The landing below the light (bearing 028): concrete pier, timber fenders, bollards, steps up the rock.
func _jetty() -> void:
	var root := Node3D.new()
	add_child(root)
	var b := deg_to_rad(28.0)
	var outward := Vector3(sin(b), 0, -cos(b))
	root.position = Geo.to_v3(Geo.polar(b, 18.5), 0.0)
	root.look_at(root.position + outward, Vector3.UP)
	var conc := LLMaterials.get_mat("M_LL_ConcreteExt")
	var wood := LLMaterials.get_mat("M_LL_WoodDark")
	var iron := LLMaterials.get_mat("M_LL_Iron")
	_box(root, Vector3(3.2, 1.6, 9.0), Vector3(0, 0.4, -4.5), conc)                  # pier deck (top at 1.2 m)
	for k in 6:
		_box(root, Vector3(0.25, 2.2, 0.25), Vector3(1.72, 0.0, -1.0 - k * 1.5), wood)  # fenders
	for z in [-2.0, -7.5]:
		var bol := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.2
		cm.height = 0.45
		bol.mesh = cm
		bol.material_override = iron
		bol.position = Vector3(1.2, 1.42, z)
		root.add_child(bol)
	for k in 8:                                                                         # steps up to the island
		_box(root, Vector3(1.4, 0.32, 0.5), Vector3(-0.6, 1.25 + k * 0.3, 0.3 + k * 0.45), conc)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


func _rock_mesh(variant: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 12
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 11 + variant * 7
	noise.frequency = 1.3
	noise.fractal_octaves = 3
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v * 1.0) * 0.35
		v *= d
		v.y = maxf(v.y, -0.3) * 1.0
		if v.y > 0.0:
			v.y *= 0.8 + 0.3 * absf(noise.get_noise_2d(v.x * 3.0, v.z * 3.0))
		verts[i] = v
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(am, 0)
	st.generate_normals()
	return st.commit()


func _lighthouse() -> void:
	var lh: Node3D = load("res://assets/models/lighthouse.glb").instantiate()
	add_child(lh)
	var stack: Array = [lh]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			for i in n.mesh.get_surface_count():
				var m: Material = n.mesh.surface_get_material(i)
				if m:
					var rep := LLMaterials.get_mat(m.resource_name)
					if rep:
						n.set_surface_override_material(i, rep)
			if String(n.name).begins_with("GLS_"):
				n.material_override = LLMaterials.glass()
		if String(n.name) == "PT_optic":
			optic = n
	lamp_glow = OmniLight3D.new()
	lamp_glow.position = Vector3(0, LANTERN_Y, 0)
	lamp_glow.light_color = Color(1.0, 0.76, 0.45)
	lamp_glow.omni_range = 9.0
	lamp_glow.light_energy = 2.5
	lamp_glow.light_volumetric_fog_energy = 2.0
	lamp_glow.shadow_enabled = false
	lamp_glow.light_cull_mask = EXTERIOR_ONLY    # unshadowed, 4.8 m above the floor: it lit the room through the roof
	add_child(lamp_glow)


func _beam() -> void:
	beam_pivot = Node3D.new()
	beam_pivot.position = Vector3(0, LANTERN_Y, 0)
	add_child(beam_pivot)
	beam_light = SpotLight3D.new()
	beam_light.light_color = Color(1.0, 0.78, 0.5)
	beam_light.light_energy = 40.0
	beam_light.spot_range = 230.0
	beam_light.spot_angle = 7.0
	beam_light.spot_attenuation = 0.5
	beam_light.light_volumetric_fog_energy = 5.0
	beam_light.shadow_enabled = false
	beam_light.light_cull_mask = EXTERIOR_ONLY
	beam_light.rotation_degrees.x = -3.0
	beam_pivot.add_child(beam_light)
	var tilt := Node3D.new()
	tilt.rotation_degrees.x = -3.0
	beam_pivot.add_child(tilt)
	beam_cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var L := 190.0
	cm.top_radius = 0.6
	cm.bottom_radius = tan(deg_to_rad(5.5)) * L
	cm.height = L
	cm.radial_segments = 24
	cm.rings = 8
	cm.cap_top = false
	cm.cap_bottom = false
	beam_cone.mesh = cm
	beam_cone.rotation_degrees.x = 90.0
	beam_cone.position = Vector3(0, 0, -L * 0.5)
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	beam_mat.set_shader_parameter("length_m", L)
	beam_mat.set_shader_parameter("noise", _noise_tex)
	beam_cone.material_override = beam_mat
	beam_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tilt.add_child(beam_cone)


func _rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = Settings.q_rain_amount()
	rain.lifetime = 1.4
	rain.visibility_aabb = AABB(Vector3(-40, -25, -40), Vector3(80, 50, 80))
	rain.position = Vector3(0, 30, 0)
	var pm := ParticleProcessMaterial.new()
	# Rain fix: emit only from a ring OUTSIDE the tower (never above the roof), and kill every drop that
	# reaches solid geometry (roof, gallery, walls, island, sea) via the heightfield collider below.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 34.0
	pm.emission_ring_inner_radius = 6.5
	pm.emission_ring_height = 3.0
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.collision_use_scale = false
	pm.direction = Vector3(0.35, -1, 0.15)
	pm.spread = 4.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3(0, -9.8, 0)
	rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.7, 0.76, 0.85, 0.18)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = rm
	rain.draw_pass_1 = quad
	rain.emitting = not GameState.user_args.has("norain")
	rain.collision_base_size = 0.02
	add_child(rain)
	var hf := GPUParticlesCollisionHeightField3D.new()
	hf.size = Vector3(76, 44, 76)
	hf.position = Vector3(0, 12, 0)
	hf.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(hf)


# ------------------------------------------------------------------ per-frame

func on_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"lightning":
				flash = e["power"]
				_flash_dir = Geo.dir(e["bearing"])
				bolt_light.rotation = Vector3(deg_to_rad(-40), Geo.yaw_for(e["bearing"]) + PI, 0)
			"ship_spawned":
				var s := sim.find_ship(e["ship"])
				var v := SHIP_VIEW.new()
				add_child(v)
				v.setup(s)
				ship_views[s.id] = v
			"ship_lost":
				if ship_views.has(e["ship"]):
					ship_views[e["ship"]].wreck()


func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_body(delta)
	GameState.prof_add("outside", Time.get_ticks_usec() - _pt)


func _process_body(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	var storm := sim.storm
	if sim.story_mode:
		if _sky_mode == "dawn":
			dawn = minf(1.0, dawn + delta / 25.0)
		dusk = maxf(0.0, dusk - delta / 240.0)     # dusk drains to night over four minutes
	elif sim.result != KeeperSim.Result.RUNNING or sim.t > sim.cfg.night_length - 40.0:
		dawn = minf(1.0, dawn + delta / 25.0)
	flash = maxf(0.0, flash - delta * 2.2)
	var f := flash * (0.55 + 0.45 * sin(_t * 47.0)) if flash > 0.05 else 0.0
	if Settings.v["reduce_flashing"]:
		f *= 0.3
	flash_now = f
	bolt_light.light_energy = f * 2.6
	sky_mat.set_shader_parameter("storm", storm)
	sky_mat.set_shader_parameter("flash", f)
	sky_mat.set_shader_parameter("dawn", maxf(dawn, dusk * 0.55))
	sky_mat.set_shader_parameter("time_s", _t)
	sky_mat.set_shader_parameter("flash_dir", _flash_dir)
	ocean_mat.set_shader_parameter("storm", storm)
	ocean_mat.set_shader_parameter("time_s", _t)
	ocean_mat.set_shader_parameter("flash", f)
	beam_mat.set_shader_parameter("time_s", _t)
	env.tonemap_exposure = 1.35 * float(Settings.v["brightness"])
	env.volumetric_fog_density = lerpf(0.006, 0.016, storm) * (1.0 - 0.7 * dawn) * (0.3 if attract else 1.0)
	env.fog_density = lerpf(0.0025, 0.0065, storm) * (1.0 - 0.6 * dawn)
	env.fog_light_color = Color(0.05, 0.065, 0.085).lerp(Color(0.45, 0.42, 0.42), dawn)
	env.ambient_light_energy = 0.9 + 1.6 * dawn + 2.0 * f
	moon.light_energy = 0.45 + 0.9 * dawn
	moon.light_color = Color(0.55, 0.64, 0.82).lerp(Color(1.0, 0.8, 0.66), dawn)
	rain.amount_ratio = clampf(0.25 + storm * 0.9 - dawn * 0.8, 0.05, 1.0)
	WindowGlass.set_weather(clampf(0.3 + storm * 0.8 - dawn * 0.5, 0.1, 1.0), f)
	# beam follows the sim; lamp output follows power + intensity; flicker on a low battery
	var lit := sim.lamp_on()
	var level: float = [0.55, 0.8, 1.15][sim.intensity]
	if lit and sim.battery < 8.0:
		level *= 0.6 + 0.4 * float(randf() > 0.2)
	var focused := sim.mode == KeeperSim.Mode.MANUAL
	beam_pivot.rotation.y = Geo.yaw_for(sim.bearing)
	if optic:
		optic.rotation.y = Geo.yaw_for(sim.bearing)
	beam_light.visible = lit
	beam_cone.visible = lit
	beam_light.light_energy = 40.0 * level * (1.3 if focused else 1.0)
	beam_light.light_volumetric_fog_energy = 1.2 if attract else 5.0
	beam_light.spot_range = sim.vis_range() * (sim.cfg.focus_mul if focused else 1.0) + 40.0
	beam_mat.set_shader_parameter("intensity", (0.9 if focused else 0.6) * level * (1.0 - 0.6 * dawn))
	lamp_glow.light_energy = 2.5 * level if lit else 0.0
	for id in ship_views.keys():
		var v = ship_views[id]
		if v.done:
			v.queue_free()
			ship_views.erase(id)
		else:
			v.tick(_t, delta, storm, sim)
