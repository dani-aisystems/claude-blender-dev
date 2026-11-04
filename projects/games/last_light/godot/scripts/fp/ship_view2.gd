extends Node3D
## Visual for a FleetShip: Blender model (assets/models/ship_<kind>.glb) or a shaped stand-in hull,
## proper navigation lights (white masthead, red port, green starboard, white stern), warm deck
## lights, and motion that rides OceanWaves (heave, pitch, roll) with banking into turns.

const DIMS := {"fishing": Vector3(4.2, 2.4, 13.0), "schooner": Vector3(5.0, 2.6, 19.0), "steamer": Vector3(7.5, 4.2, 30.0)}

var ship: FleetShip
var done := false
var _sink := 0.0
var _fade := 0.0
var _prev_heading := 0.0
var _bank := 0.0
var _lights: Array[OmniLight3D] = []
var _bulbs: Array[StandardMaterial3D] = []


func setup(s: FleetShip) -> void:
	ship = s
	name = "Ship_%s" % s.name.replace(" ", "_")
	_prev_heading = s.heading
	var path := "res://assets/models/ship_%s.glb" % s.kind
	if ResourceLoader.exists(path):
		var m: Node3D = load(path).instantiate()
		add_child(m)
		_swap(m)
	else:
		_stand_in(s.kind)
	var d: Vector3 = DIMS[s.kind]
	_nav(Color(1.0, 0.95, 0.85), Vector3(0, d.y + d.z * 0.35, -d.z * 0.15), 1.6, 26.0)     # masthead
	_nav(Color(1.0, 0.12, 0.08), Vector3(-d.x * 0.5, d.y * 1.15, -d.z * 0.1), 1.2, 9.0)      # port
	_nav(Color(0.2, 1.0, 0.35), Vector3(d.x * 0.5, d.y * 1.15, -d.z * 0.1), 1.2, 9.0)        # starboard
	_nav(Color(1.0, 0.95, 0.85), Vector3(0, d.y * 1.1, d.z * 0.48), 0.8, 7.0)               # stern
	_nav(Color(1.0, 0.7, 0.4), Vector3(0, d.y * 1.5, d.z * 0.05), 1.0, 14.0, true)          # deck work light


func _swap(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		for i in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(i)
			if m:
				var rep := LLMaterials.get_mat(m.resource_name)
				if rep:
					n.set_surface_override_material(i, rep)


func _stand_in(kind: String) -> void:
	var d: Vector3 = DIMS[kind]
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(d)
	hull.material_override = LLMaterials.get_mat("M_LL_SteelPaint" if kind == "steamer" else "M_LL_WoodDark")
	add_child(hull)
	var house := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(d.x * 0.62, d.y * 0.9, d.z * (0.22 if kind != "steamer" else 0.18))
	house.mesh = bm
	house.position = Vector3(0, d.y + bm.size.y * 0.5, d.z * (0.18 if kind == "fishing" else 0.25))
	house.material_override = LLMaterials.get_mat("M_LL_Concrete" if kind == "steamer" else "M_LL_SteelPaint")
	add_child(house)
	var win := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(bm.size.x * 1.01, bm.size.y * 0.22, bm.size.z * 0.6)
	win.mesh = wb
	win.position = house.position + Vector3(0, bm.size.y * 0.18, -bm.size.z * 0.05)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.08, 0.05)
	wm.emission_enabled = true
	wm.emission = Color(1.0, 0.7, 0.38)
	wm.emission_energy_multiplier = 1.6
	win.material_override = wm
	add_child(win)
	var masts := {"fishing": [-0.1], "schooner": [-0.25, 0.1], "steamer": [-0.3]}
	for z in masts[kind]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.14
		cm.height = d.z * (0.55 if kind == "schooner" else 0.4)
		m.mesh = cm
		m.position = Vector3(0, d.y + cm.height * 0.5, d.z * z)
		m.material_override = LLMaterials.get_mat("M_LL_WoodDark")
		add_child(m)
	if kind == "steamer":
		var fun := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.9
		fm.bottom_radius = 1.0
		fm.height = 4.5
		fun.mesh = fm
		fun.position = Vector3(0, d.y + 2.6, d.z * 0.02)
		fun.material_override = LLMaterials.get_mat("M_LL_Red")
		add_child(fun)
	if kind == "fishing":
		var g := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.05
		gm.bottom_radius = 0.05
		gm.height = d.z * 0.5
		g.mesh = gm
		g.rotation_degrees = Vector3(-55, 0, 0)
		g.position = Vector3(0, d.y + 2.5, d.z * 0.3)
		g.material_override = LLMaterials.get_mat("M_LL_Iron")
		add_child(g)


## Hull: tapered bow (-z), flat transom (+z), flared sides, sheer line rising to the bow.
func _hull_mesh(d: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var sections: Array = []
	for i in n + 1:
		var u := float(i) / n                       # 0 = stern, 1 = bow
		var z := lerpf(d.z * 0.5, -d.z * 0.5, u)
		var half_w := d.x * 0.5 * (1.0 - pow(maxf(u - 0.55, 0.0) / 0.45, 1.6))
		var deck := d.y * (1.0 + 0.25 * u * u)
		var keel := -d.y * 0.55 * (1.0 - 0.6 * u)
		sections.append([Vector3(-half_w, deck, z), Vector3(-half_w * 0.75, keel * 0.4, z), Vector3(0, keel, z),
			Vector3(half_w * 0.75, keel * 0.4, z), Vector3(half_w, deck, z)])
	for i in n:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for j in 4:
			st.add_vertex(a[j]); st.add_vertex(b[j]); st.add_vertex(b[j + 1])
			st.add_vertex(a[j]); st.add_vertex(b[j + 1]); st.add_vertex(a[j + 1])
		st.add_vertex(a[0]); st.add_vertex(a[4]); st.add_vertex(b[4])       # deck
		st.add_vertex(a[0]); st.add_vertex(b[4]); st.add_vertex(b[0])
	var s0: Array = sections[0]
	for j in range(1, 4):                                                    # transom
		st.add_vertex(s0[0]); st.add_vertex(s0[j + 1]); st.add_vertex(s0[j])
	st.generate_normals()
	return st.commit()


func _nav(c: Color, p: Vector3, energy: float, rng_m: float, deck := false) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_m
	l.position = p
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.6 if not deck else 0.2
	add_child(l)
	_lights.append(l)
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22 if not deck else 0.3
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	b.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * 1.6
	b.material_override = m
	b.position = p
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b)
	_bulbs.append(m)


func wreck() -> void:
	_sink = 0.001


func tick(t: float, dt: float, storm: float, _k: KeeperSim) -> void:
	var p := ship.pos
	var h := OceanWaves.height_at(p, t, storm)
	var nrm := OceanWaves.normal_at(p, t, storm, DIMS[ship.kind].z * 0.25)
	var turn_rate := Geo.angle_diff(_prev_heading, ship.heading) / maxf(dt, 0.001)
	_prev_heading = ship.heading
	_bank = lerpf(_bank, clampf(-turn_rate * 1.8, -0.18, 0.18), minf(1.0, dt * 1.5))
	if _sink > 0.0:
		_sink = minf(1.0, _sink + dt * 0.06)
	if ship.state == FleetShip.State.SAVED:
		_fade = minf(1.0, _fade + dt / 10.0)
	var yaw := Geo.yaw_for(ship.heading)
	var basis := Basis(Vector3.UP, yaw)
	# align to the wave normal (pitch/roll) plus banking, plus a slow list as she sinks
	var up := nrm.lerp(Vector3.UP, 0.35)
	var tilt := Basis(Quaternion(Vector3.UP, up.normalized()))
	basis = tilt * basis * Basis(Vector3.FORWARD, _bank + _sink * 0.6) * Basis(Vector3.RIGHT, -_sink * 0.35)
	transform = Transform3D(basis, Geo.to_v3(p, h - 0.4 - _sink * 9.0))
	var lights_on := _sink < 0.35
	for l in _lights:
		l.visible = lights_on and _fade < 1.0
	visible = _sink < 1.0 and _fade < 1.0
	done = (_sink >= 1.0) or (_fade >= 1.0)
