class_name LLMaterials
extends RefCounted
## Blender material name -> Godot material. Scanned CC0 maps (assets/textures, logged in
## assets/ASSET_LICENSES.md) are graded into the reference palette with shaders/tri_pbr.gdshader.

const TEX := "res://assets/textures/%s_%s.png"
const TRI := preload("res://shaders/tri_pbr.gdshader")

static var _cache := {}

# name: [texture set, params]
const GRADES := {
	"M_LL_Concrete": ["painted_concrete", {"scale": 0.22, "desat": 1.0, "tint": Color(0.6, 0.57, 0.52), "contrast": 0.5, "brightness": 1.05, "rough_mul": 1.0, "normal_strength": 0.6, "grime_amount": 0.6}],  # Look 1: contrast 1.15 -> 0.5, peeled-paint splotches read as marble
	"M_LL_ConcreteExt": ["painted_concrete", {"scale": 0.12, "desat": 1.0, "tint": Color(0.6, 0.6, 0.58), "contrast": 0.7, "wetness": 0.5, "normal_strength": 0.8}],
	"M_LL_Stone": ["cliff_side", {"scale": 0.25, "desat": 0.85, "tint": Color(0.42, 0.42, 0.43), "wetness": 0.6}],
	"M_LL_Floor": ["painted_concrete", {"scale": 0.2, "desat": 1.0, "tint": Color(0.36, 0.34, 0.31), "contrast": 0.55, "rough_mul": 0.6, "normal_strength": 0.5}],  # Look 1: contrast 1.3 -> 0.55
	"M_LL_Wood": ["distressed_painted_planks", {"scale": 1.1, "desat": 0.9, "tint": Color(0.48, 0.3, 0.18), "contrast": 1.6, "brightness": 0.9, "rough_mul": 0.8}],
	"M_LL_WoodDark": ["distressed_painted_planks", {"scale": 1.0, "desat": 0.9, "tint": Color(0.27, 0.17, 0.11), "contrast": 1.6, "rough_mul": 0.75}],
	"M_LL_SteelPaint": ["rusty_painted_metal", {"scale": 0.9, "desat": 0.82, "tint": Color(0.43, 0.52, 0.47), "contrast": 1.35, "metallic_v": 0.35, "rough_mul": 0.85}],
	"M_LL_SteelRust": ["rusty_painted_metal", {"scale": 1.1, "desat": 0.55, "tint": Color(0.4, 0.33, 0.28), "contrast": 1.3, "metallic_v": 0.55, "rough_mul": 0.9}],
	"M_LL_Iron": ["rusty_painted_metal", {"scale": 1.4, "desat": 0.85, "tint": Color(0.18, 0.18, 0.19), "metallic_v": 0.7, "rough_mul": 0.7}],
	"M_LL_EngineGreen": ["rusty_painted_metal", {"scale": 1.2, "desat": 0.8, "tint": Color(0.42, 0.55, 0.43), "contrast": 1.3, "metallic_v": 0.4, "rough_mul": 0.7}],
	"M_LL_Rock": ["cliff_side", {"scale": 0.18, "desat": 0.88, "tint": Color(0.36, 0.36, 0.37), "contrast": 1.35, "wetness": 0.7, "normal_strength": 1.6}],
	"M_LL_Shore": ["coast_land_rocks_01", {"scale": 0.15, "desat": 0.6, "tint": Color(0.45, 0.45, 0.42), "wetness": 0.4}],
	"M_LL_Grass": ["sparse_grass", {"scale": 0.2, "desat": 0.45, "tint": Color(0.5, 0.55, 0.42), "contrast": 1.1, "wetness": 0.3}],
}

const PLAIN := {
	# name: [albedo, roughness, metallic]
	"M_LL_Brass": [Color(0.66, 0.5, 0.24), 0.3, 1.0],
	"M_LL_Bakelite": [Color(0.05, 0.045, 0.045), 0.38, 0.0],
	"M_LL_Red": [Color(0.5, 0.08, 0.06), 0.42, 0.1],
	"M_LL_Rope": [Color(0.5, 0.42, 0.28), 0.9, 0.0],
	"M_LL_Copper": [Color(0.27, 0.42, 0.37), 0.55, 0.6],
	"M_LL_Paper": [Color(0.8, 0.76, 0.66), 0.85, 0.0],
	"M_LL_Leather": [Color(0.3, 0.1, 0.08), 0.55, 0.0],
	"M_LL_Ceramic": [Color(0.85, 0.83, 0.78), 0.25, 0.0],
	"M_LL_Screen": [Color(0.01, 0.04, 0.02), 0.15, 0.0],
}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material = null
	if GRADES.has(name):
		m = _tri(GRADES[name][0], GRADES[name][1])
	elif PLAIN.has(name):
		var s := StandardMaterial3D.new()
		var p: Array = PLAIN[name]
		s.albedo_color = p[0]
		s.roughness = p[1]
		s.metallic = p[2]
		if name == "M_LL_Brass":
			s.metallic_specular = 0.6
		m = s
	elif name == "M_LL_Glass":
		m = glass()
	elif name == "M_LL_Lens":
		var s := StandardMaterial3D.new()
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.albedo_color = Color(0.85, 0.92, 0.9, 0.3)
		s.roughness = 0.02
		s.metallic_specular = 1.0
		s.rim_enabled = true
		s.rim = 0.6
		m = s
	_cache[name] = m
	return m


static func _tri(set_name: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TRI
	m.set_shader_parameter("albedo_tex", load(TEX % [set_name, "diff"]))
	m.set_shader_parameter("normal_tex", load(TEX % [set_name, "nor_gl"]))
	m.set_shader_parameter("rough_tex", load(TEX % [set_name, "rough"]))
	for k in params:
		var v = params[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		m.set_shader_parameter(k, v)
	return m


static func glass() -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.albedo_color = Color(0.62, 0.7, 0.74, 0.12)
	s.roughness = 0.03
	s.metallic_specular = 0.9
	s.cull_mode = BaseMaterial3D.CULL_DISABLED
	return s


static func lamp(color: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = color.darkened(0.6)
	s.emission_enabled = true
	s.emission = color
	s.emission_energy_multiplier = 0.0
	s.roughness = 0.3
	return s
