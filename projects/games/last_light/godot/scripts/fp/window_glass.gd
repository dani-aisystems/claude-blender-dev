class_name WindowGlass
extends RefCounted
## Shared rain-on-glass material for every window (one instance so the storm drives all panes).

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/rain_glass.gdshader")
	return _mat


static func set_weather(rain: float, flash: float) -> void:
	var m := material()
	m.set_shader_parameter("rain", rain)
	m.set_shader_parameter("flash", flash)
