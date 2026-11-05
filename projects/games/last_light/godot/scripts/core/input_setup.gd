class_name InputSetup
extends RefCounted
## Input actions are registered in code so they are explicit, testable and survive project edits.
## Stage 2C: bindings are grouped by context. Inside one context no two actions share a pad input
## (tests/regress_test.gd R7 checks it). The first-person keeper game is FP; the v1 top-down game is V1.

const BINDINGS := {          # keyboard (physical keycodes)
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
	"transcript": [KEY_T],
	"torch": [KEY_F],          # cabin pass: switch the carried torch on / off
	"back": [],               # keyboard "back" is Esc / right click (handled with pause / mouse)
	"turn_prev": [],          # keyboard: right click / wheel
	"turn_next": [],
	"look_left": [], "look_right": [], "look_up": [], "look_down": [],
}

## Pad bindings per context: action -> ["button", JoyButton] or ["axis", JoyAxis, direction].
const PAD_FP := {
	"interact": ["button", JOY_BUTTON_A],
	"back": ["button", JOY_BUTTON_B],
	"transcript": ["button", JOY_BUTTON_X],
	"logbook": ["button", JOY_BUTTON_Y],
	"turn_prev": ["button", JOY_BUTTON_LEFT_SHOULDER],
	"turn_next": ["button", JOY_BUTTON_RIGHT_SHOULDER],
	"sprint": ["button", JOY_BUTTON_LEFT_STICK],
	"torch": ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0],     # LT (the d-pad belongs to replies and the handwheel)
	"pause": ["button", JOY_BUTTON_START],
	"move_left": ["axis", JOY_AXIS_LEFT_X, -1.0],
	"move_right": ["axis", JOY_AXIS_LEFT_X, 1.0],
	"move_forward": ["axis", JOY_AXIS_LEFT_Y, -1.0],
	"move_back": ["axis", JOY_AXIS_LEFT_Y, 1.0],
	"look_left": ["axis", JOY_AXIS_RIGHT_X, -1.0],
	"look_right": ["axis", JOY_AXIS_RIGHT_X, 1.0],
	"look_up": ["axis", JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": ["axis", JOY_AXIS_RIGHT_Y, 1.0],
}
const PAD_V1 := {
	"beam_left": ["axis", JOY_AXIS_LEFT_X, -1.0],
	"beam_right": ["axis", JOY_AXIS_LEFT_X, 1.0],
	"boost": ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0],     # was A, which FP uses for interact
	"pause": ["button", JOY_BUTTON_START],
}
## Godot's built-in UI actions (menus, pause, dialogue replies): made explicit for the pad, since the
## engine defaults did not let A press a focused reply (regress R7).
const PAD_UI := {
	"ui_accept": ["button", JOY_BUTTON_A],
	"ui_cancel": ["button", JOY_BUTTON_B],
	"ui_up": ["button", JOY_BUTTON_DPAD_UP],
	"ui_down": ["button", JOY_BUTTON_DPAD_DOWN],
	"ui_left": ["button", JOY_BUTTON_DPAD_LEFT],
	"ui_right": ["button", JOY_BUTTON_DPAD_RIGHT],
}
## Extra pad inputs that are deliberately shared with another context (the console handwheel also
## turns with the d-pad, as in v1).
const PAD_SHARED := {
	"beam_left": ["button", JOY_BUTTON_DPAD_LEFT],
	"beam_right": ["button", JOY_BUTTON_DPAD_RIGHT],
}

## Pad stick tuning (Stage 2C): radial deadzone, then a quadratic response curve.
const STICK_DEADZONE := 0.15
const LOOK_SPEED := 2.6           # rad/s at full deflection (yaw); pitch is 70 % of it
const CURSOR_SPEED := 900.0       # device-view cursor, viewport px/s at full deflection

## true while the last input came from a gamepad (prompt glyphs, pad cursor). game_fp updates it.
static var pad_active := false
static var pad_name := ""
## Captures (--pad) pin pad mode: Daniel's real mouse moving over a background capture window must not
## flip the shots back to keyboard glyphs (seen in s2c_pad2).
static var pad_forced := false


static func ensure() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in BINDINGS[action]:
			var exists := false
			for e in InputMap.action_get_events(action):
				if e is InputEventKey and e.physical_keycode == key:
					exists = true
			if not exists:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)
	for table in [PAD_FP, PAD_V1, PAD_SHARED, PAD_UI]:
		for action in table:
			_add_pad(action, table[action])
	for action in ["look_left", "look_right", "look_up", "look_down"]:
		InputMap.action_set_deadzone(action, 0.05)    # the radial deadzone is applied in stick()


static func _add_pad(action: String, b: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in InputMap.action_get_events(action):
		if b[0] == "button" and e is InputEventJoypadButton and e.button_index == b[1]:
			return
		if b[0] == "axis" and e is InputEventJoypadMotion and e.axis == b[1] and signf(e.axis_value) == signf(b[2]):
			return
	var ev: InputEvent
	if b[0] == "button":
		ev = InputEventJoypadButton.new()
		ev.button_index = b[1]
	else:
		ev = InputEventJoypadMotion.new()
		ev.axis = b[1]
		ev.axis_value = b[2]
	InputMap.action_add_event(action, ev)


## A stick as a vector with a radial deadzone and a quadratic response (fine aim near the centre).
static func stick(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	var v := Vector2(Input.get_axis(neg_x, pos_x), Input.get_axis(neg_y, pos_y))
	var m := v.length()
	if m <= STICK_DEADZONE:
		return Vector2.ZERO
	var r := clampf((m - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
	return v / m * r * r


## Prompt glyph for a control, for the device the player is using right now.
static func glyph(what: String) -> String:
	if pad_active:
		var ps := pad_name.to_lower().contains("playstation") or pad_name.to_lower().contains("dualsense") \
			or pad_name.to_lower().contains("dualshock") or pad_name.to_lower().contains("ps4") or pad_name.to_lower().contains("ps5")
		var face := {"interact": "Cross" if ps else "A", "back": "Circle" if ps else "B",
			"transcript": "Square" if ps else "X", "logbook": "Triangle" if ps else "Y"}
		match what:
			"interact", "click":
				return face["interact"]
			"back", "step_back":
				return face["back"]
			"transcript":
				return face["transcript"]
			"logbook":
				return face["logbook"]
			"turn_back":
				return "L1" if ps else "LB"
			"turn":
				return "L1 / R1" if ps else "LB / RB"
			"next_vessel":
				return "R1" if ps else "RB"
			"torch":
				return "L2" if ps else "LT"
			"wheel", "handwheel":
				return "Left stick"
			"move":
				return "the left stick"
			"look":
				return "the right stick"
		return what
	match what:
		"interact":
			return "E"
		"click":
			return "Click"
		"back":
			return "Esc"
		"step_back":
			return "Esc / Right click"
		"transcript":
			return "T"
		"logbook":
			return "L"
		"turn_back":
			return "Right click"
		"turn":
			return "Wheel"
		"next_vessel":
			return "Tab"
		"torch":
			return "F"
		"wheel", "handwheel":
			return "A / D"
		"move":
			return "W A S D"
		"look":
			return "the mouse"
	return what


## "[E]" style key cap for prompts.
static func key(what: String) -> String:
	return "[%s]" % glyph(what)


## Hint text with {interact} {move} {look} {turn_back} {wheel} tokens resolved for the current device.
static func resolve(text: String) -> String:
	for t in ["interact", "move", "look", "turn_back", "wheel", "back", "logbook", "torch", "transcript", "turn", "next_vessel"]:
		text = text.replace("{%s}" % t, glyph(t))
	return text
