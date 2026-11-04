extends Node3D
## Alasdair Ross in the stair doorway: a deliberately undetailed silhouette (oilskin, sou'wester,
## face in shadow). He is meant to be read through light and posture, not a face (NARRATIVE.md).

var _t := 0.0
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var oil := StandardMaterial3D.new()
	oil.albedo_color = Color(0.32, 0.27, 0.12)
	oil.roughness = 0.22
	oil.metallic_specular = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.045, 0.04)
	dark.roughness = 0.8
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.35, 0.26, 0.21)
	skin.roughness = 0.7
	_part(_cyl(0.26, 0.36, 1.0), Vector3(0, 0.95, 0), oil)            # oilskin coat
	_part(_cyl(0.2, 0.26, 0.32), Vector3(0, 1.58, 0), oil)            # shoulders
	_part(_cyl(0.07, 0.08, 0.5), Vector3(-0.1, 0.25, 0), dark)        # legs / boots
	_part(_cyl(0.07, 0.08, 0.5), Vector3(0.1, 0.25, 0), dark)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.26
	head.mesh = sm
	head.material_override = skin
	head.position = Vector3(0, 1.84, 0)
	_body.add_child(head)
	_part(_cyl(0.11, 0.24, 0.1), Vector3(0, 1.97, 0.02), oil)         # sou'wester brim
	_part(_cyl(0.06, 0.11, 0.1), Vector3(0, 2.03, 0), oil)
	for s in [-1, 1]:                                                  # arms
		var arm := _part(_cyl(0.06, 0.08, 0.62), Vector3(0.29 * s, 1.3, 0.02), oil)
		arm.rotation.z = 0.12 * s


func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 14
	return c


func _part(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	_body.add_child(m)
	return m


func _process(delta: float) -> void:
	_t += delta
	_body.position.y = 0.006 * sin(_t * 1.4)          # breathing
	_body.rotation.z = 0.01 * sin(_t * 0.6)
