class_name InputSetup
extends RefCounted
## Input actions are registered in code so they are explicit, testable and survive project edits.

const BINDINGS := {
	"beam_left": [KEY_A, KEY_LEFT],
	"beam_right": [KEY_D, KEY_RIGHT],
	"boost": [KEY_SPACE],
	"pause": [KEY_ESCAPE, KEY_P],
	"fullscreen": [KEY_F11],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"sprint": [KEY_SHIFT],
	"logbook": [KEY_L],
}


static func ensure() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			var exists := false
			for e in InputMap.action_get_events(action):
				if e is InputEventKey and e.physical_keycode == key:
					exists = true
			if not exists:
				InputMap.action_add_event(action, ev)
	# gamepad: left stick / d-pad + A/RT (cheap to support, no extra UI)
	_add_joy_axis("beam_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("beam_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("beam_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("beam_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("boost", JOY_BUTTON_A)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("interact", JOY_BUTTON_A)


static func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis == axis:
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


static func _add_joy_button(action: String, button: JoyButton) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
