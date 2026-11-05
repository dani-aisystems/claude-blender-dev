extends SceneTree
## Stage 0 regression tests for the three gameplay blockers (2026-11-04 audit):
##  R1  mouse look is restored after picking a dialogue reply in free-walk (and NOT inside a device view)
##  R2  dialogue choices never overlap the radio command panel (several window aspect ratios)
##  R3  input under the pause menu does not advance dialogue, pick choices, or run the typewriter
##  R4  speakerless narration inside a radio conversation shows as a thought, not a blank transmission
##  R5  Stage 2A interaction state: prompt keys, refusals with reasons (once), the door prompt, no dead
##      prompts in device views (radio -> chart switches), pause releases a held START
##  R6  Stage 2B radio panel: stable vessel buttons, a click across a refresh, Space after an order, tips
##  R7  Stage 2C gamepad and camera: no shared pad inputs, right-stick look and deadzone, A / B / LB / RB,
##      the device-view pad cursor (room controls and screen buttons), reply focus, glyphs, head bob
##   godot --path godot -s res://tests/regress_test.gd            (windowed: all checks)
##   godot --headless --path godot -s res://tests/regress_test.gd (R1 mouse checks SKIPPED: the headless
##                                                                  display server ignores mouse modes)

var fails: Array[String] = []
var skips: Array[String] = []
var passes := 0
var g: Node3D
var dlg: Control


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("  PASS ", what)
	else:
		fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)


func _run() -> void:
	await process_frame
	g = load("res://scripts/fp/game_fp.gd").new()
	root.add_child(g)
	g.start(7, "", false, true)          # story mode, human (no bot)
	await _frames(3)
	g.director.process_mode = Node.PROCESS_MODE_DISABLED   # keep the campaign from talking over the tests
	dlg = g.presenter.dialogue
	if dlg.is_active():
		dlg.close()
	await _r1_mouse()
	await _r2_overlap()
	await _r3_pause()
	await _r4_thought_in_radio()
	await _r5_interaction_state()
	await _r6_radio_panel()
	await _r7_gamepad_and_camera()
	print("REGRESS_RESULT ", JSON.stringify({"passed": passes, "failed": fails.size(), "failures": fails, "skipped": skips}))
	quit(1 if fails.size() > 0 else 0)


## Stage 2A: interaction state, refusals with reasons, no dead prompts, door prompt, pause releases holds.
func _r5_interaction_state() -> void:
	print("R5 interaction state (Stage 2A)")
	var st: Node3D = g.station
	var k: KeeperSim = g.sim
	# a) valid prompt in free walk carries the interact key
	var p: Dictionary = st.prompt_info("radio", false)
	_check(p["ok"] and p["key"] == "[E]" and p["text"] == "Use the radio", "radio prompt is '[E]  Use the radio' (%s)" % p)
	# b) START with the valve shut: unavailable, the reason is the valve, and a press is refused (no crank)
	k.gen = KeeperSim.Gen.OFF
	k.fuel_valve = false
	k.start_held = false
	p = st.prompt_info("start", false)
	_check(not p["ok"] and p["key"] == "" and p["sub"] == "The fuel valve is shut.", "START with the valve shut: no key, reason shown (%s)" % p)
	var ev: Array = st.use("start", "press")
	_check(ev.size() == 1 and ev[0]["type"] == "refused" and k.gen == KeeperSim.Gen.OFF and not k.start_held,
		"START press with the valve shut is refused and does not crank (%s)" % [ev])
	k.gen = KeeperSim.Gen.RUNNING
	_check(st.availability("start")["reason"] == "The generator is already running.", "START while running says so")
	k.gen = KeeperSim.Gen.OFF
	k.fuel_valve = true
	_check(st.availability("start")["ok"], "START with the valve open and the engine stopped is available")
	# c) the refusal notice is shown once, not on every press
	g.ui.notice.text = ""
	g._route([{"type": "refused", "device": "start", "reason": "Test reason."}])
	var first: String = g.ui.notice.text
	g.ui.notice.text = ""
	g._route([{"type": "refused", "device": "start", "reason": "Test reason."}])
	_check(first == "Test reason." and g.ui.notice.text == "", "a repeated refusal within 3 s is not shown again")
	# d) charging on with the generator stopped explains why nothing flows
	k.charge_on = false
	ev = st.use("charge", "press")
	_check(ev.any(func(e): return e["type"] == "note"), "charging ON with the engine stopped adds a note")
	k.charge_on = false
	# e) the door prompt follows the story: ch1 usable, ch4 bolted (no key), open (no key)
	g.director.state.chapter = 1
	st.door_open = false
	g._update_door_prompt()
	_check(st.prompt_info("door", false)["key"] == "[E]", "door in ch1: '[E]  Try the stair door'")
	g.director.state.chapter = 4
	g._update_door_prompt()
	p = st.prompt_info("door", false)
	_check(p["key"] == "" and "bolted" in p["text"], "door in ch4 before the story opens it: no key (%s)" % p)
	st.door_open = true
	g._update_door_prompt()
	_check(st.prompt_info("door", false)["text"] == "The stair door stands open", "open door says so")
	st.door_open = false
	g.director.state.chapter = 1
	g._update_door_prompt()
	# f) device views: every control the cursor can reach either acts on a click or shows no key; the
	#    chart seen from the radio view switches straight to the chart view (it used to be a dead prompt)
	for view in ["radio", "console", "chart"]:
		g.player.enter_focus(view)
		await _frames(40)
		var ids := {}
		var space: PhysicsDirectSpaceState3D = g.player.get_world_3d().direct_space_state
		var vp: Vector2 = g.player.get_viewport().get_visible_rect().size
		for ix in 32:
			for iy in 18:
				var sp := Vector2((ix + 0.5) / 32.0 * vp.x, (iy + 0.5) / 18.0 * vp.y)
				var id: String = g.player.pick(space, g.player.camera.project_ray_origin(sp), g.player.camera.project_ray_normal(sp), g.player.REACH + 1.2)
				if id != "":
					ids[id] = true
		var dead: Array = []
		for id in ids:                            # the key the player would see (player._update_prompt rule)
			var key: String = st.prompt_info(id, true)["key"] if g.player._actionable(id) else ""
			if key == "[Click]" and st.DEVICES[id]["kind"] == "focus" and not g.player._can_switch(st.DEVICES[id].get("focus_id", id)):
				dead.append(id)
		_check(dead.is_empty(), "%s view: no clickable prompt that does nothing (reachable: %s)" % [view, ids.keys()])
		if view == "radio" and ids.has("chart"):
			_check(g.player._can_switch("chart"), "radio view -> chart is a direct switch")
			g.player.enter_focus("chart")
			await _frames(5)
			_check(g.player.focused == "chart", "clicking the chart from the radio view opens the chart view")
		g.player.leave_focus()
		await _frames(40)
	# g) pause while holding START stops the crank (the key-up is lost under the pause menu)
	k.gen = KeeperSim.Gen.OFF
	k.fuel_valve = true
	g.player._holding = "start"
	g._route(st.use("start", "press"))
	var cranking := k.gen == KeeperSim.Gen.CRANKING and k.start_held
	g.set_paused(true)
	await _frames(2)
	_check(cranking and not k.start_held and k.gen != KeeperSim.Gen.CRANKING, "pause while holding START stops cranking (was cranking=%s)" % cranking)
	g.set_paused(false)
	await _frames(2)


func _mouse(pos: Vector2, down: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _vessel_buttons() -> Array:
	return g.ui.vessel_list.get_children().filter(func(c): return c is Button and not c.is_queued_for_deletion())


## Stage 2B: the vessel list keeps its buttons (hover, focus, clicks survive the periodic refresh),
## and a clicked order button does not keep focus (Space / Enter / pad A would send it again).
func _r6_radio_panel() -> void:
	print("R6 radio panel (Stage 2B)")
	var settings: Node = root.get_node("Settings")
	if "persist" in settings:
		settings.persist = false               # tips counted here must not reach user://settings.cfg
	for n in ["Testboat One", "Testboat Two"]:
		g._route(g.sim.spawn_story_ship({"name": n, "kind": "fishing", "bearing": 20, "aim": 24, "hold": true, "protected": true}))
	g.player.enter_focus("radio")
	await _frames(40)
	g.ui._refresh_vessels()
	await _frames(2)
	var before := _vessel_buttons().map(func(b): return b.get_instance_id())
	await _frames(125)                         # four 30-frame refresh cycles
	var after := _vessel_buttons().map(func(b): return b.get_instance_id())
	_check(before.size() >= 2 and before == after, "vessel buttons keep their identity across refreshes (%d buttons)" % before.size())
	# a click whose press and release straddle a refresh still selects the vessel
	var act: Array = g.sim.active_ships()
	var target_id: int = act[1].id if act.size() > 1 else -1
	g.ui.selected_ship = act[0].id
	g.ui._refresh_vessels()
	await _frames(2)
	var btn: Button = _vessel_buttons()[1]
	var pos: Vector2 = btn.get_global_rect().get_center()
	while Engine.get_process_frames() % 30 != 28:
		await process_frame
	_mouse(pos, true)
	await _frames(4)                           # the refresh lands between press and release
	_mouse(pos, false)
	await _frames(2)
	_check(g.ui.selected_ship == target_id, "a click across a list refresh selects the vessel (selected %d, wanted %d)" % [g.ui.selected_ship, target_id])
	# Space after clicking an order must not send it again
	var sent := [0]
	var counter := func(_id, _cmd): sent[0] += 1
	g.ui.command_requested.connect(counter)
	var order: Button = null
	for c in g.ui.radio_panel.find_children("*", "Button", true, false):
		if String(c.text).contains("Hold position"):
			order = c
	var opos: Vector2 = order.get_global_rect().get_center()
	_mouse(opos, true)
	await _frames(2)
	_mouse(opos, false)
	await _frames(2)
	var after_click: int = sent[0]
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.physical_keycode = KEY_SPACE
	sp.pressed = true
	root.push_input(sp)
	var spu := sp.duplicate()
	spu.pressed = false
	root.push_input(spu)
	await _frames(3)
	_check(after_click == 1 and sent[0] == 1, "Space after clicking an order does not send it again (click sent %d, total %d)" % [after_click, sent[0]])
	g.ui.command_requested.disconnect(counter)
	# one-time tips: shown until the control has been used twice, then gone (counted in memory only here)
	var saved_tips: Dictionary = settings.v["tips"].duplicate()
	settings.v["tips"] = {}
	g.ui._refresh_vessels()
	var tab_shown: bool = g.ui.tab_tip.visible
	for i in 2:
		var t := InputEventKey.new()
		t.keycode = KEY_TAB
		t.physical_keycode = KEY_TAB
		t.pressed = true
		root.push_input(t)
		var tu := t.duplicate()
		tu.pressed = false
		root.push_input(tu)
		await _frames(2)
	_check(tab_shown and not g.ui.tab_tip.visible, "Tab tip shows with two vessels and retires after two uses (shown=%s, now=%s)" % [tab_shown, g.ui.tab_tip.visible])
	g.player.leave_focus()
	await _frames(40)
	g.player.enter_focus("console")
	await _frames(40)
	var sub0: String = g.station.prompt_info("mode", true)["sub"]
	g.player._turn("mode", "next", "wheel")
	g.player._turn("mode", "prev", "wheel")
	var sub1: String = g.station.prompt_info("mode", true)["sub"]
	_check("[Wheel]" in sub0 and not ("[Wheel]" in sub1) and "Right click" in sub1, "knob tip: '%s' -> '%s' after two wheel turns" % [sub0, sub1])
	_check(not FileAccess.file_exists("user://settings.cfg") or not FileAccess.get_file_as_string("user://settings.cfg").contains("wheel"),
		"tips counted by tests are not written to settings.cfg")
	settings.v["tips"] = saved_tips
	g.player.leave_focus()
	await _frames(40)


func _pad_button(b: JoyButton, down := true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _pad_axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _tap(b: JoyButton) -> void:
	_pad_button(b, true)
	await _frames(2)
	_pad_button(b, false)
	await _frames(2)


## Stand 1.2 m from a control (towards the room centre) and look at it, as a player would.
func _aim_at(id: String) -> void:
	var p := _ia_pos(id)
	var inward := Vector3(-p.x, 0, -p.z).normalized()
	g.player.global_position = Vector3(p.x + inward.x * 1.2, g.player.global_position.y, p.z + inward.z * 1.2)
	var to: Vector3 = p - (g.player.global_position + Vector3(0, g.player.EYE, 0))
	g.player._yaw = atan2(-to.x, -to.z)
	g.player._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	g.player._apply_look()
	await _frames(6)


func _ia_pos(id: String) -> Vector3:
	for b in g.station.get_children():
		if b is StaticBody3D and String(b.get_meta("ia", "")) == id:
			return b.global_position
	return Vector3.INF


## Stage 2C: pad bindings have no overlaps, right-stick look with a deadzone, A / B / LB / RB, the
## device-view pad cursor (room controls and on-screen buttons), pad focus on replies, glyphs, and the
## interpolated camera.
func _r7_gamepad_and_camera() -> void:
	print("R7 gamepad and camera (Stage 2C)")
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	# a) no two first-person actions share a pad input; v1 boost is off A
	var seen := {}
	var dup: Array = []
	for action in InputSetup.PAD_FP:
		var b: Array = InputSetup.PAD_FP[action]
		var key := ("b%d" % b[1]) if b[0] == "button" else ("a%d%s" % [b[1], "+" if b[2] > 0 else "-"])
		if seen.has(key):
			dup.append("%s/%s" % [seen[key], action])
		seen[key] = action
	_check(dup.is_empty(), "no two first-person actions share a pad input (%s)" % [dup])
	var boost_on_a := InputMap.action_get_events("boost").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)
	_check(not boost_on_a, "v1 boost no longer shares A with interact")
	# b) right-stick look: a small deflection inside the deadzone does nothing, a full one turns
	g.player.focused = ""
	var y0: float = g.player._yaw
	_pad_axis(JOY_AXIS_RIGHT_X, 0.1)
	await _frames(20)
	var y_small: float = g.player._yaw
	_pad_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	var y_full: float = g.player._yaw
	_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(5)
	var y_rest: float = g.player._yaw
	await _frames(10)
	_check(is_equal_approx(y0, y_small) and absf(y_full - y0) > 0.1 and is_equal_approx(y_rest, g.player._yaw),
		"right stick: deadzone %.4f, full turn %.2f rad in 20 frames, stops on release" % [y_small - y0, y_full - y0])
	_check(InputSetup.pad_active, "a pad input switches the prompts to pad glyphs")
	_check(g.station.prompt_info("radio", false)["key"] == "[A]", "pad prompt key is [A] (%s)" % g.station.prompt_info("radio", false)["key"])
	# c) pad A uses the control under the crosshair (free walk): aim at the radar breaker
	var p := _ia_pos("brk_radar")
	var inward := Vector3(-p.x, 0, -p.z).normalized()
	g.player.global_position = Vector3(p.x + inward.x * 1.2, g.player.global_position.y, p.z + inward.z * 1.2)
	var to: Vector3 = p - (g.player.global_position + Vector3(0, g.player.EYE, 0))
	g.player._yaw = atan2(-to.x, -to.z)
	g.player._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	g.player._apply_look()
	await _frames(6)
	var radar0: bool = g.sim.brk_radar
	await _tap(JOY_BUTTON_A)
	_check(g.sim.brk_radar != radar0, "pad A switches the radar breaker under the crosshair (hovered=%s)" % g.player.hovered)
	g._route(g.sim.set_breaker("radar", radar0))
	# camera follows the body exactly after a placement (no interpolation smear)
	var cam_err: float = g.player.camera.global_position.distance_to(g.player.global_position + Vector3(0, g.player.EYE + g.player._bob_y, 0))
	_check(cam_err < 0.01, "camera sits at the eye right after a placement (%.3f m)" % cam_err)
	# generator: hold pad A on START cranks, letting go stops (hold-to-crank, valve open)
	g.sim.gen = KeeperSim.Gen.OFF
	g.sim.fuel_valve = true
	g.sim.start_held = false
	await _aim_at("start")
	_pad_button(JOY_BUTTON_A, true)
	await _frames(4)
	var cranking: bool = g.sim.start_held and g.sim.gen == KeeperSim.Gen.CRANKING
	_pad_button(JOY_BUTTON_A, false)
	await _frames(4)
	_check(cranking and not g.sim.start_held, "pad: hold A on START cranks, release stops (hovered=%s)" % g.player.hovered)
	g.sim.gen = KeeperSim.Gen.OFF
	# stair door: pad A gives the chapter-gated line (ch1)
	g.presenter.hint.text = ""
	await _aim_at("door")
	await _tap(JOY_BUTTON_A)
	_check(g.presenter.hint.text != "", "pad: A on the stair door gives the bolted-door line (hovered=%s)" % g.player.hovered)
	# d) device view: the pad cursor picks the MODE knob, A turns it, LB turns it back, B steps back
	g.player.enter_focus("console")
	await _frames(40)
	_check(g.player.virtual_cursor.is_finite(), "entering a device view on the pad starts the pad cursor")
	if DisplayServer.get_name() == "headless":
		skips.append("R7 OS pointer hidden in a pad device view (headless)")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "pad device view hides the OS pointer (mode %d)" % Input.mouse_mode)
	g.player.virtual_cursor = g.player.camera.unproject_position(_ia_pos("mode"))
	await _frames(3)
	var m0: int = g.sim.mode
	await _tap(JOY_BUTTON_A)
	var m1: int = g.sim.mode
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(m1 == (m0 + 1) % 3 and g.sim.mode == m0, "pad cursor + A turns MODE (%d -> %d), LB turns it back (%d)" % [m0, m1, g.sim.mode])
	var c0: Vector2 = g.player.virtual_cursor
	_pad_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(15)
	_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(g.player.virtual_cursor.x > c0.x + 40.0, "right stick moves the device-view cursor (%.0f -> %.0f px)" % [c0.x, g.player.virtual_cursor.x])
	await _tap(JOY_BUTTON_B)
	await _frames(30)
	_check(g.player.focused == "", "pad B steps back out of the device view")
	# e) radio view: the pad cursor presses an on-screen order button; RB picks the next vessel
	g.player.enter_focus("radio")
	await _frames(40)
	g.ui._refresh_vessels()
	var sent := [0]
	var counter := func(_id, _cmd): sent[0] += 1
	g.ui.command_requested.connect(counter)
	var order: Button = null
	for c in g.ui.radio_panel.find_children("*", "Button", true, false):
		if String(c.text).contains("Maintain course"):
			order = c
	g.player.virtual_cursor = order.get_global_rect().get_center()
	await _tap(JOY_BUTTON_A)
	g.ui.command_requested.disconnect(counter)
	_check(sent[0] == 1, "pad cursor + A presses the radio order under it (sent %d)" % sent[0])
	var s0: int = g.ui.selected_ship
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(g.ui.sim.active_ships().size() < 2 or g.ui.selected_ship != s0, "RB selects the next vessel in the radio view")
	g.player.leave_focus()
	await _frames(30)
	# f) dialogue replies take pad focus; A picks the focused reply
	var picked := [-1]
	var on_pick := func(i): picked[0] = i
	dlg.choice_made.connect(on_pick)
	_choices("person")
	await _frames(4)
	var focus_owner := root.gui_get_focus_owner()
	var first_focused: bool = focus_owner != null and dlg.choice_box.get_child_count() > 0 and focus_owner == dlg.choice_box.get_child(0)
	await _tap(JOY_BUTTON_A)
	dlg.choice_made.disconnect(on_pick)
	_check(first_focused and picked[0] == 0, "pad: the first reply has focus and A picks it (focused=%s, picked=%d)" % [first_focused, picked[0]])
	if dlg.is_active():
		dlg.close()
	# g) head bob off keeps the eye level
	settings.v["head_bob"] = false
	g.player.velocity = Vector3(1.6, 0, 0)
	for i in 20:
		g.player._process(1.0 / 60.0)
	_check(absf(g.player._bob_y) < 0.0005 and absf(g.player._roll) < 0.0001, "Head bob off: no bob or roll while walking")
	settings.v["head_bob"] = true
	g.player.velocity = Vector3.ZERO
	# back to keyboard and mouse for anything after this
	var k := InputEventKey.new()
	k.keycode = KEY_SHIFT
	k.physical_keycode = KEY_SHIFT
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(2)
	var ku := k.duplicate()
	ku.pressed = false
	Input.parse_input_event(ku)
	await _frames(2)
	_check(not InputSetup.pad_active and g.station.prompt_info("radio", false)["key"] == "[E]", "a key press switches back to keyboard glyphs")


func _choices(mode: String) -> void:
	dlg.show_line({"mode": mode, "speaker": "MORAG" if mode == "radio" else "VISITOR",
		"text": "North Point, Stornoway Coastguard. Are you receiving, Callum? Over." if mode == "radio" else "Evening, keeper."})
	dlg.show_choices({"choices": [{"index": 0, "text": "Receiving you, Morag. All quiet here. Over."},
		{"index": 1, "text": "Go ahead, Stornoway. Over."}]})


func _r1_mouse() -> void:
	print("R1 mouse restore after a reply")
	var headless := DisplayServer.get_name() == "headless"
	var picked := []
	var cb := func(i): picked.append(i)
	dlg.choice_made.connect(cb)
	# a) free-walk, person mode (the ch4 door scene)
	g.refresh_mouse()
	_check(g.mouse_should_capture(), "free-walk wants mouse-look before dialogue")
	_choices("person")
	await _frames(2)
	_check(dlg.has_open_choices(), "person choices are shown")
	_check(not g.mouse_should_capture(), "open choices release mouse-look")
	_key(KEY_1)
	await _frames(2)
	_check(picked == [0], "key 1 picks the first reply (got %s)" % [picked])
	_check(not dlg.has_open_choices(), "choices close after the pick")
	_check(g.mouse_should_capture(), "mouse-look wanted again after the pick")
	if headless:
		skips.append("R1 Input.mouse_mode checks (headless)")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Input.mouse_mode is CAPTURED after the pick")
	dlg.close()
	# b) inside the radio device view the cursor must stay free after a pick, and the number key must
	#    pick the reply WITHOUT also sending a radio order (both layers listen to 1-6)
	picked.clear()
	var orders := [0]
	var co := func(_s, _c): orders[0] += 1
	g.ui.command_requested.connect(co)
	g.ui.selected_ship = 999          # any id: sim.command answers "no answer" for unknown ships
	g.player.enter_focus("radio")
	await _frames(2)
	_choices("radio")
	await _frames(2)
	_check(dlg.has_open_choices(), "radio choices unlocked inside the radio view")
	g.ui.selected_ship = 999
	_key(KEY_2)
	await _frames(1)
	_check(picked == [1], "key 2 picks the second reply (got %s)" % [picked])
	_check(orders[0] == 0, "picking a reply sends no radio order (orders=%d)" % orders[0])
	g.ui.selected_ship = 999          # re-set: _refresh_vessels clears it every 30 frames (no ships)
	_key(KEY_3)
	await _frames(1)
	_check(orders[0] == 1, "with no replies open, key 3 sends a radio order (orders=%d)" % orders[0])
	g.set_paused(true)
	g.ui.selected_ship = 999
	_key(KEY_4)
	await _frames(1)
	_check(orders[0] == 1, "no radio orders under pause (orders=%d)" % orders[0])
	g.set_paused(false)
	g.ui.command_requested.disconnect(co)
	g.ui.selected_ship = -1
	_check(not g.mouse_should_capture(), "device view keeps the cursor free after a pick")
	if not headless:
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Input.mouse_mode stays VISIBLE in the device view")
	# c) unpausing with choices open must not capture the mouse (buttons would become unclickable)
	_choices("radio")
	await _frames(2)
	g.player.leave_focus()
	await _frames(2)
	g.set_paused(true)
	g.set_paused(false)
	_check(not (dlg.has_open_choices() and g.mouse_should_capture()), "unpause/leave-focus with open choices keeps the cursor free")
	dlg.close()
	dlg.choice_made.disconnect(cb)
	await _frames(2)


func _r2_overlap() -> void:
	print("R2 choices vs radio command panel")
	g.player.enter_focus("radio")
	await _frames(2)
	_choices("radio")
	await _frames(2)
	var sizes := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1920, 1200), Vector2i(1440, 1080), Vector2i(2560, 1080)]
	for s in sizes:
		root.size = s
		await _frames(3)
		var panel: Control = g.ui.radio_panel
		var box: Control = dlg.choice_box
		var vp := box.get_viewport_rect()
		var a := box.get_global_rect()
		var b := panel.get_global_rect()
		var speech: Rect2 = dlg.radio_panel.get_global_rect()
		var tag := "%dx%d (canvas %dx%d)" % [s.x, s.y, vp.size.x, vp.size.y]
		_check(panel.visible and box.get_child_count() > 0, "%s both visible" % tag)
		_check(not a.intersects(b), "%s choices %s clear of command panel %s" % [tag, a, b])
		_check(not a.intersects(speech), "%s choices clear of the speech panel" % tag)
		_check(vp.encloses(a), "%s choices fully on screen" % tag)
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless":      # visual evidence for the checkpoint
		await _frames(45)                           # let the focus camera ease in and the text type out
		dlg._shown = dlg._full.length()
		dlg._render()
		await _frames(3)
		var out := ProjectSettings.globalize_path("res://").path_join("../../../../renders/last_light").simplify_path()
		DirAccess.make_dir_recursive_absolute(out)
		root.get_texture().get_image().save_png(out.path_join("s0_regress_reply_layout.png"))
		print("  saved s0_regress_reply_layout.png")
	dlg.close()
	g.player.leave_focus()
	await _frames(2)


func _r3_pause() -> void:
	print("R3 input under pause")
	var adv := [0]
	var picks := [0]
	var ca := func(): adv[0] += 1
	var cc := func(_i): picks[0] += 1
	dlg.advance_requested.connect(ca)
	dlg.choice_made.connect(cc)
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": "A long line that the typewriter should still be revealing when the keeper pauses the game."})
	await _frames(2)
	g.set_paused(true)
	await _frames(2)
	var shown_before: float = dlg._shown
	for i in 3:
		_key(KEY_E)
		await _frames(3)
	await _frames(20)
	_check(adv[0] == 0, "E under pause does not advance (advances=%d)" % adv[0])
	_check(is_equal_approx(dlg._shown, shown_before), "typewriter frozen under pause (%.1f -> %.1f)" % [shown_before, dlg._shown])
	_check(dlg._shown < dlg._full.length(), "E under pause does not complete the line")
	_choices("person")
	await _frames(2)
	_key(KEY_1)
	await _frames(3)
	dlg._pick(0)                     # a mouse click on a button under the pause menu reaches _pick
	await _frames(2)
	_check(picks[0] == 0, "choices cannot be picked under pause (picks=%d)" % picks[0])
	g.set_paused(false)
	await _frames(2)
	_key(KEY_1)
	await _frames(3)
	_check(picks[0] == 1, "after unpause key 1 picks (picks=%d)" % picks[0])
	dlg.advance_requested.disconnect(ca)
	dlg.choice_made.disconnect(cc)
	dlg.close()


## R4 (Stage 1 s1f): narration inside a radio conversation is the keeper thinking. It must be drawn as an
## italic thought subtitle, not as a radio call with a blank identity card and a live signal meter.
func _r4_thought_in_radio() -> void:
	dlg.show_line({"mode": "radio", "speaker": "", "text": "Static. Then nothing. Not even the carrier."})
	await _frames(2)
	_check(not dlg.radio_panel.visible, "radio narration does not open the radio panel")
	_check(dlg.sub_box.visible and dlg.s_text.text.contains("[i]"), "radio narration is an italic subtitle")
	_check(dlg.s_name.text == "", "radio narration has no speaker name")
	_check(dlg.mode == "radio", "the conversation stays a radio conversation (reply gating)")
	dlg.show_line({"mode": "radio", "speaker": "MORAG", "text": "North Point, Stornoway. Over."})
	await _frames(2)
	_check(dlg.radio_panel.visible and not dlg.sub_box.visible, "the next radio line opens the radio panel again")
	dlg.close()
	# the handset hint lives in the radio panel, so radio replies must never follow narration directly
	var db := DialogueDB.new()
	db.load_dir("res://data/story")
	var bad: Array = []
	for id in db.convs:
		var c: Dictionary = db.convs[id]
		if c["mode"] != "radio":
			continue
		var last_narr := false
		for st in c["steps"]:
			if st["kind"] == "line":
				last_narr = st["speaker"] == ""
			elif st["kind"] == "choice":
				if last_narr:
					bad.append(id)
				last_narr = false
			elif st["kind"] == "goto":
				last_narr = false
	_check(bad.is_empty(), "no radio replies directly after narration (the handset hint would be hidden): %s" % [bad])
