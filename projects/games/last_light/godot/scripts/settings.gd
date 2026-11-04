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
	changed.emit()


## Quality presets consumed by outside.gd / station.gd.
func q_volumetric() -> bool:
	return int(v["quality"]) >= 1


func q_ssao() -> bool:
	return int(v["quality"]) >= 2


func q_shadows() -> bool:
	return int(v["quality"]) >= 1


func q_rain_amount() -> int:
	return [2500, 5000, 9000][int(v["quality"])]


func q_scale3d() -> float:
	return [0.75, 0.9, 1.0][int(v["quality"])]
