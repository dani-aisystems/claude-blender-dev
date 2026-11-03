extends Node3D
## Visual for one ShipModel: hull model (GLB from Blender, greybox fallback), running lights,
## mast lamp (amber while lit, green once it has its bearings), wake, wreck/sink animation.

const MODEL_FOR := {"fishing": "ship_fishing", "schooner": "ship_schooner", "steamer": "ship_steamer"}
const GREYBOX_SIZE := {"fishing": Vector3(2.6, 1.6, 8.0), "schooner": Vector3(3.6, 2.0, 12.0), "steamer": Vector3(5.2, 2.6, 17.0)}

var ship: ShipModel
var model: Node3D
var mast_lamp: OmniLight3D
var lamp_mesh: MeshInstance3D
var lamp_mat: StandardMaterial3D
var port_light: OmniLight3D
var stbd_light: OmniLight3D
var wake: GPUParticles3D
var _bob_phase := 0.0
var _sink := 0.0
var _rescue_fade := 0.0
var _flash := 0.0


func setup(s: ShipModel, model_scene: PackedScene) -> void:
	ship = s
	name = "Ship_%d" % s.id
	_bob_phase = float(s.id) * 1.7
	if model_scene:
		model = model_scene.instantiate()
	else:
		model = _greybox(s.kind)
	add_child(model)
	var size: Vector3 = GREYBOX_SIZE[s.kind]
	var mast_h := size.y + size.z * 0.55
	# mast lamp: the readable "state" light seen through fog
	lamp_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55 + size.x * 0.06
	sm.height = sm.radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	lamp_mesh.mesh = sm
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.95, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.9, 0.75)
	lamp_mat.emission_energy_multiplier = 3.0
	lamp_mesh.material_override = lamp_mat
	lamp_mesh.position = Vector3(0, mast_h, -size.z * 0.05)
	add_child(lamp_mesh)
	mast_lamp = OmniLight3D.new()
	mast_lamp.omni_range = 9.0 + size.z * 0.4
	mast_lamp.light_energy = 1.2
	mast_lamp.light_color = Color(1.0, 0.85, 0.6)
	mast_lamp.light_volumetric_fog_energy = 0.0
	mast_lamp.shadow_enabled = false
	mast_lamp.position = lamp_mesh.position + Vector3(0, 0.6, 0)
	add_child(mast_lamp)
	port_light = _nav_light(Color(1.0, 0.15, 0.1), Vector3(-size.x * 0.55, size.y * 0.9, -size.z * 0.2))
	stbd_light = _nav_light(Color(0.15, 1.0, 0.35), Vector3(size.x * 0.55, size.y * 0.9, -size.z * 0.2))
	_update_transform(0.0)


func _nav_light(c: Color, p: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.9
	l.omni_range = 5.0
	l.position = p
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.0
	add_child(l)
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.28
	s.height = 0.56
	s.radial_segments = 6
	s.rings = 3
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	m.position = p
	add_child(m)
	return l


func _greybox(kind: String) -> Node3D:
	var root := Node3D.new()
	var size: Vector3 = GREYBOX_SIZE[kind]
	var hull := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size.x, size.z, size.y)
	hull.mesh = pm
	hull.rotation_degrees = Vector3(-90, 0, 0)
	hull.position.y = size.y * 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.2, 0.14)
	mat.roughness = 0.8
	hull.material_override = mat
	root.add_child(hull)
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.16
	cm.height = size.z * 0.55
	mast.mesh = cm
	mast.position = Vector3(0, size.y + cm.height * 0.5, 0)
	mast.material_override = mat
	root.add_child(mast)
	return root


func _update_transform(t: float) -> void:
	var p := Geo.to_v3(ship.pos)
	var bob := sin(t * 1.3 + _bob_phase) * 0.25
	p.y = bob - _sink * 6.0
	position = p
	rotation = Vector3(sin(t * 0.9 + _bob_phase) * 0.04 + _sink * 0.5, Geo.yaw_for(ship.heading), cos(t * 1.1 + _bob_phase) * 0.06 + _sink * 0.35)


func tick(t: float, dt: float, storm: float) -> void:
	if ship.state == ShipModel.State.WRECKED:
		_sink = minf(1.0, _sink + dt * 0.12)
	elif ship.state == ShipModel.State.RESCUED or ship.state == ShipModel.State.STRAYED:
		_rescue_fade = minf(1.0, _rescue_fade + dt * 0.5)
	_flash = maxf(0.0, _flash - dt * 1.5)
	_update_transform(t)
	var c: Color
	var e := 2.5
	match ship.state:
		ShipModel.State.LOCKED, ShipModel.State.RESCUED:
			c = Color(0.35, 1.0, 0.55)
			e = 3.5 + _flash * 6.0
		ShipModel.State.WRECKED:
			c = Color(1.0, 0.35, 0.15)
			e = maxf(0.0, 3.0 * (1.0 - _sink * 1.5)) * (0.5 + 0.5 * sin(t * 18.0))
		_:
			if ship.warning:
				c = Color(1.0, 0.3, 0.2)
				e = 2.5 + 2.0 * (0.5 + 0.5 * sin(t * 12.0))
			elif ship.lit:
				c = Color(1.0, 0.78, 0.4)
				e = 4.0
			else:
				c = Color(1.0, 0.92, 0.8)
				e = 2.2
	lamp_mat.emission = c
	lamp_mat.albedo_color = c
	lamp_mat.emission_energy_multiplier = e
	mast_lamp.light_color = c
	mast_lamp.light_energy = e * 0.5
	visible = _rescue_fade < 1.0 and _sink < 1.0


func on_locked() -> void:
	_flash = 1.0
