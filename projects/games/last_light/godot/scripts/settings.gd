extends Node
## Autoload "Settings": persistent player preferences (user://settings.cfg). Every option here is
## applied somewhere real; nothing is decorative.

signal changed

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Dialogue", "Ambient"]

var v := {
	# graphics
	"window_mode": 3,            # 0 windowed, 3 fullscreen, 4 exclusive fullscreen
	"resolution": "1920x1080",   # windowed size
	"quality": 2,                # 0 low, 1 medium, 2 high
	"render_res": 0,             # 0 auto: 3D at ~1920x1080-equivalent pixels (HiDPI), 1 native
	"vsync": true,
	"max_fps": 0,                # 0 = unlimited
	"fov": 72.0,
	"brightness": 1.0,           # exposure multiplier
	# audio (linear 0..1)
	"vol_master": 0.9, "vol_music": 0.6, "vol_sfx": 0.85, "vol_dialogue": 0.9, "vol_ambient": 0.8,
	# controls
	"mouse_sens": 1.0, "invert_y": false,
	# accessibility
	"subtitles": true, "subtitle_size": 1.0, "text_speed": 42.0, "reduce_flashing": false,
	"hold_to_crank": true,       # START button: hold (true) or press-to-toggle cranking (false)
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply()
	get_tree().root.size_changed.connect(apply_render_scale)   # window resize / fullscreen toggle


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in v:
		if cf.has_section_key("s", k):
			var val = cf.get_value("s", k)
			if typeof(val) == typeof(v[k]) or (typeof(v[k]) == TYPE_FLOAT and typeof(val) == TYPE_INT):
				v[k] = val


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in v:
		cf.set_value("s", k, v[k])
	cf.save(PATH)


func set_value(k: String, val) -> void:
	v[k] = val
	apply()
	save_settings()


func apply() -> void:
	if not GameState.user_args.has("capture") and not GameState.user_args.has("autotest") and not GameState.user_args.has("windowed"):
		DisplayServer.window_set_mode(int(v["window_mode"]))
		if int(v["window_mode"]) == 0:
			var r: PackedStringArray = String(v["resolution"]).split("x")
			if r.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(r[0]), int(r[1])))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v["max_fps"])
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v["vol_master"], 0.0001)))
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v["vol_" + b.to_lower()], 0.0001)))
	apply_render_scale()
	apply_quality_globals()
	changed.emit()


## 3D render scale actually used: the quality preset's scale, times (in Auto) the factor that brings
## the window's PHYSICAL pixel count down to 1920x1080. A Retina window of 1920x1205 points is
## 3840x2410 pixels, ~4.5x the pixels of 1080p (Stage 0 bench: 47 ms -> 18 ms per frame on High).
func render_scale() -> float:
	var base := q_scale3d()
	if int(v["render_res"]) == 1:
		return base
	var px: Vector2i = DisplayServer.window_get_size()
	var area := maxf(float(px.x) * float(px.y), 1.0)
	var fit := minf(1.0, sqrt(1920.0 * 1080.0 / area))
	return clampf(base * fit, 0.25, 1.0)


## Applies render_scale() to the root viewport, upscaling with AMD FSR 1.0 below native.
## --scale3d=X (captures / benchmarks) overrides it with a fixed scale.
func apply_render_scale() -> void:
	if not is_inside_tree():
		return
	var vp := get_tree().root
	var s := float(GameState.user_args["scale3d"]) if GameState.user_args.has("scale3d") else render_scale()
	vp.scaling_3d_scale = s
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.fsr_sharpness = 0.2


## Quality presets consumed by outside.gd / station.gd (Stage 1a: interior lighting per preset).
##   Low:    probe ambient only, no SSAO/SSIL, shadows on the desk lamp only, hard-ish shadows
##   Medium: SSAO + SSIL at half size, shadows on desk + two wall lamps + the centre window
##   High:   SSAO + SSIL (half size, higher quality), 8 interior lights cast soft shadows
func q_volumetric() -> bool:
	return int(v["quality"]) >= 1


func q_ssao() -> bool:
	return int(v["quality"]) >= 1


func q_ssil() -> bool:
	return int(v["quality"]) >= 1


## Half-resolution SSAO/SSIL on every preset: full-size AO cost ~4-15 ms more per frame at High on
## the M3 in the Stage 1a bench, for no visible gain in a dim room. High uses a higher quality level.
func q_half_size() -> bool:
	return true


## Which interior lights cast shadows ("*" = all).
func q_shadow_ids() -> Array:
	# the stair light must cast shadows from Medium up: unshadowed, its red emergency glow leaked through
	# the housing walls and tinted the whole room in a power cut (iteration 3 check)
	return [["desk"], ["desk", "wall_0", "wall_1", "stair"],
		["desk", "wall_0", "wall_1", "wall_2", "wall_3", "win_0", "win_1", "stair"]][int(v["quality"])]   # budget: <= 8 on High


func q_soft_shadows() -> int:
	return [RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][int(v["quality"])]


func q_shadow_atlas() -> int:
	return [2048, 4096, 4096][int(v["quality"])]


## Global (not per-scene) render settings for the current preset.
func apply_quality_globals() -> void:
	if not is_inside_tree():
		return
	RenderingServer.positional_soft_shadow_filter_set_quality(q_soft_shadows())
	RenderingServer.directional_soft_shadow_filter_set_quality(q_soft_shadows())
	get_tree().root.positional_shadow_atlas_size = q_shadow_atlas()


func q_rain_amount() -> int:
	return [2500, 5000, 9000][int(v["quality"])]


func q_scale3d() -> float:
	return [0.75, 0.9, 1.0][int(v["quality"])]
