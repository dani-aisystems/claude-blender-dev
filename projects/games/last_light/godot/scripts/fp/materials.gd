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


# ------------------------------------------------------------------ Stage 1b: the watch-room palette
## Daniel's direction (docs/ROADMAP.md): maintained-but-aged 1971 NLB station, period green + cream.
## sRGB hex; the shader's source_color hints linearise them.
const PALETTE := {
	"cream": Color("#D6C9A6"), "dado": Color("#2E4537"), "machinery": Color("#66796B"),
	"engine": Color("#55705A"), "frame_green": Color("#34493C"), "iron": Color("#2A2B28"),
	"oak": Color("#7A4E2A"), "oak_dark": Color("#4A2E1A"), "floor": Color("#4A4743"),
	"brass": Color("#B58A3C"), "skirting": Color("#1F221E"), "plaster_under": Color("#B9B4A8"),
	"primer": Color("#8A8A82"),
}
const ROOM_SHADER := preload("res://shaders/room_pbr.gdshader")
## Mean linear RGB of each 2k scan (measured from assets/textures/*_Diffuse_2k.png, 2026-11-04):
## the room shader divides by it, so the palette sets the colour and the scan only adds detail.
const SCAN_AVG := {
	"plastered_wall_02": Vector3(0.4953, 0.4434, 0.3712), "concrete_floor_worn_001": Vector3(0.0926, 0.0946, 0.0893),
	"oak_veneer_01": Vector3(0.3598, 0.21, 0.0971), "dark_wooden_planks": Vector3(0.0873, 0.0685, 0.0494),
	"green_metal_rust": Vector3(0.0497, 0.074, 0.0342), "metal_plate_02": Vector3(0.0899, 0.0663, 0.0477),
}
## Interior-only looks (the lighthouse exterior shares some names and keeps GRADES).
const ROOM := {
	# Walls: painted render over masonry. (plastered_wall_02 turned out to be plasterboard with vertical
	# panel joints in both diffuse and normal: they read as boards on the wall and lines on the ceiling.)
	"M_LL_Concrete": ["concrete_floor_worn_001", {"scale": 0.45, "base": "cream", "detail_amt": 0.28, "rough_lo": 0.3, "rough_hi": 0.55,
		"coat": 0.2, "coat_rough": 0.35, "normal_strength": 0.35, "dado": 1.0, "chips": 0.35, "under": "plaster_under", "cyl_map": 1.0}],
	"M_LL_Floor": ["concrete_floor_worn_001", {"scale": 0.35, "base": "floor", "detail_amt": 0.8, "rough_lo": 0.25, "rough_hi": 0.6,
		"coat": 0.45, "coat_rough": 0.25, "normal_strength": 0.6}],
	"M_LL_SteelPaint": ["metal_plate_02", {"scale": 0.45, "base": "machinery", "detail_amt": 0.18, "rough_lo": 0.38, "rough_hi": 0.55,
		"coat": 0.15, "coat_rough": 0.4, "chips": 0.25, "under": "primer"}],
	"M_LL_EngineGreen": ["metal_plate_02", {"scale": 0.6, "base": "engine", "detail_amt": 0.22, "rough_lo": 0.32, "rough_hi": 0.55,
		"coat": 0.25, "coat_rough": 0.3, "chips": 0.3, "under": "primer"}],
	"M_LL_SteelRust": ["green_metal_rust", {"scale": 0.9, "base": "frame_green", "detail_amt": 0.3, "rough_lo": 0.35, "rough_hi": 0.55,
		"coat": 0.2, "coat_rough": 0.3, "chips": 0.2, "under": "primer"}],
	"M_LL_Iron": ["metal_plate_02", {"scale": 1.4, "base": "iron", "detail_amt": 0.5, "rough_lo": 0.35, "rough_hi": 0.6, "metallic_v": 0.3}],
	"M_LL_Wood": ["oak_veneer_01", {"scale": 1.2, "base": "oak", "detail_amt": 1.0, "detail_color": 1.0, "rough_lo": 0.35, "rough_hi": 0.55,
		"coat": 0.35, "coat_rough": 0.32}],
	"M_LL_WoodDark": ["dark_wooden_planks", {"scale": 1.0, "base": "oak_dark", "detail_amt": 1.0, "detail_color": 1.0, "rough_lo": 0.35,
		"rough_hi": 0.6, "coat": 0.3, "coat_rough": 0.35}],
}


## Room surfaces (station.gd): interior looks first, everything else falls back to get_mat().
static func get_room_mat(name: String) -> Material:
	if GameState.user_args.has("noroom"):      # perf bisect: the pre-1b looks
		return get_mat(name)
	var key := "room:" + name
	if _cache.has(key):
		return _cache[key]
	var m: Material = null
	if ROOM.has(name):
		m = _room(ROOM[name][0], ROOM[name][1])
	elif name == "M_LL_Brass":
		var s := StandardMaterial3D.new()
		s.albedo_color = PALETTE["brass"]
		s.metallic = 0.75          # rougher, part-diffuse brass shows its own colour in a dim room
		s.roughness = 0.45
		s.metallic_specular = 0.6
		m = s
	else:
		m = get_mat(name)
	_cache[key] = m
	return m


static func _room(set_name: String, p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROOM_SHADER
	m.set_shader_parameter("albedo_tex", load(TEX % [set_name, "diff"]))
	m.set_shader_parameter("normal_tex", load(TEX % [set_name, "nor_gl"]))
	m.set_shader_parameter("arm_tex", load(TEX % [set_name, "arm"]))
	m.set_shader_parameter("scan_avg", SCAN_AVG.get(set_name, Vector3(0.45, 0.45, 0.45)))
	m.set_shader_parameter("base_color", PALETTE[p.get("base", "cream")])
	m.set_shader_parameter("dado_color", PALETTE["dado"])
	m.set_shader_parameter("skirt_color", PALETTE["skirting"])
	m.set_shader_parameter("rail_color", PALETTE["oak"])
	m.set_shader_parameter("under_color", PALETTE[p.get("under", "primer")])
	for k in p:
		if k in ["base", "under"]:
			continue
		m.set_shader_parameter(k, p[k])
	return m


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
	s.roughness = 0.07               # 0.03 / specular 0.9 flared the optic cabinet's flat panes white
	s.metallic_specular = 0.5
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
