class_name WindowGlass
extends RefCounted
## Shared rain-on-glass material for every window (one instance so the storm drives all panes).

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/rain_glass.gdshader")
		_mat.render_priority = 1          # after the other transparents (Stage 1b)
	return _mat


static func set_weather(rain: float, flash: float) -> void:
	var m := material()
	m.set_shader_parameter("rain", rain)
	m.set_shader_parameter("flash", flash)
