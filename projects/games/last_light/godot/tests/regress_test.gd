extends SceneTree
## Stage 0 regression tests for the three gameplay blockers (2026-11-04 audit):
##  R1  mouse look stays on with replies open in free walk and after picking one (cabin pass); the pointer
##      stays free inside a device view
##  R2  dialogue choices never overlap the radio command panel (several window aspect ratios)
##  R3  input under the pause menu does not advance dialogue, pick choices, or run the typewriter
##  R4  speakerless narration inside a radio conversation shows as a thought, not a blank transmission
##  R5  Stage 2A interaction state: prompt keys, refusals with reasons (once), the door prompt, no dead
##      prompts in device views (radio -> chart switches), pause releases a held START
##  R6  Stage 2B radio panel: stable vessel buttons, a click across a refresh, Space after an order, tips
##  R7  Stage 2C gamepad and camera: no shared pad inputs, right-stick look and deadzone, A / B / LB / RB,
##      the device-view pad cursor (room controls and screen buttons), reply focus, glyphs, head bob
##  R9  Stage 3A dialogue foundation: bundled fonts with a real italic, the identity resolver (no early
##      "Ross" in names, history or backlog), line looks (in-room speakers, sound captions), a typewriter
##      that lays out once and waits behind fades and documents, objective tokens, one text scale for all
##      roles, and the dialogue history (pauses, never advances, mouse and pad focus restored)
##  R10 Stage 3B narrative mechanics: the story jam (any mode, no MAIN trip, never cleared by a power loss,
##      freed only by hand: OFF + handwheel back), Ross's beam assist, transitions that hold the story and
##      block dialogue input under black, the ending card, optional calls that defer the next beat's talk,
##      no early "Alasdair Ross", the stair-door bolt and the 1953 photograph props
##  R11 brief 2026-11-06, group G1: E is never taken by dialogue, Space finishes then advances only after
##      the dwell, replies ignore their first 0.4 s, the clock card draws above the black, the radar is its
##      own target (never the radio view), sim radio chatter waits behind a story line and is logged
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
	# the ch1 card now starts on black and holds dialogue input until it lifts (item 21): let it finish
	var lift := 0
	while g.presenter.is_screen_held() and lift < 900:
		await process_frame
		lift += 1
	# windowed runs capture the real pointer: Daniel's own mouse must not turn the camera or flip the device
	# mode mid-test (cabin pass). In memory only: persist is off, so settings.cfg is never written.
	var st_node: Node = root.get_node("Settings")
	st_node.persist = false
	st_node.v["mouse_sens"] = 0.0
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
	await _r8_cabin_reliability()
	await _r9_dialogue_foundation()
	await _r10_narrative_mechanics()
	await _r11_brief_g1()
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
	g.director.state.beat = 0
	g._update_door_prompt()
	p = st.prompt_info("door", false)
	_check(p["key"] == "" and p["text"] == "The stair door", "door in ch4 before the boat is alongside: no key (%s)" % p)
	g.director.state.beat = 2                      # 3B: from `hail` the keeper may bolt it
	g._update_door_prompt()
	p = st.prompt_info("door", false)
	_check(p["key"] == "[E]" and "bolt" in p["text"], "door in ch4 once she's alongside: '[E]  Draw the bolt' (%s)" % p)
	g.director.state.flags["bolted"] = 1
	g._update_door_prompt()
	p = st.prompt_info("door", false)
	_check(p["key"] == "" and "bolted" in p["text"], "bolted door: no key (%s)" % p)
	g.director.state.flags.erase("bolted")
	g.director.state.beat = 0
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
		await _settle_focus()
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
		if view == "radio" and ids.has("chart"):      # cabin pass: the chart is a full-screen inspection (R8)
			_check(g.player._actionable("chart") and g.station.DEVICES["chart"]["kind"] == "doc",
				"radio view -> the chart is clickable and opens the chart inspection")
		g.player.leave_focus()
		await _frames(40)
		await _settle_focus()
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
	await _settle_focus()
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
	await _settle_focus()
	g.player.enter_focus("console")
	await _frames(40)
	await _settle_focus()
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
	await _settle_focus()


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


## A device-view ease (0.45 s, time-based) blends the camera, and with it the crosshair ray, between the
## views. A fixed frame count is not enough windowed: at a 120 Hz display 40 frames can end inside the ease
## (cabin pass CP4: R6/R7 failed windowed with the camera 1.97 m off the eye). Wait for the ease itself.
func _settle_focus() -> void:
	var n := 0
	while g.player._focus_t < 1.0 and n < 600:
		await process_frame
		n += 1
	await physics_frame                         # one tick so hover and the body update from the settled camera


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
	InputSetup.pad_forced = false
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
	InputSetup.pad_forced = true              # a pad-only player from here on (real mouse noise ignored)
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
	await _settle_focus()
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
	await _settle_focus()
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
	await _settle_focus()
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
	InputSetup.pad_forced = false
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


func _mouse_btn(b: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = down
	e.position = Vector2(960, 540)
	e.global_position = e.position
	root.push_input(e)


func _act(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var u := InputEventAction.new()
	u.action = action
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


## Cabin pass checkpoint 1: one owner for the mouse mode, replies answered without losing mouse look,
## radio replies re-gated, a document / chart viewer that only closes on purpose, the blackout torch,
## and a repeated interaction loop that must always come back to free-walk mouse look (IMG_3140).
func _r8_cabin_reliability() -> void:
	print("R8 cabin pass: cursor, chart, torch")
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	InputSetup.pad_active = false
	# a) a single owner: in-game scripts never set Input.mouse_mode except player.capture_mouse (main_fp's
	#    menu has the screen when no game exists)
	var writers: Array = []
	for f in ["fp/game_fp.gd", "fp/fp_ui.gd", "fp/station.gd", "ui/dialogue_ui.gd", "story/story_presenter.gd", "story/story_director.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		for line in src.split("\n"):
			if line.strip_edges().begins_with("Input.mouse_mode =") or line.contains("Input.mouse_mode = "):
				writers.append(f)
				break
	_check(writers.is_empty(), "only player.capture_mouse sets the mouse mode in-game (other writers: %s)" % [writers])
	# b) free-walk replies keep mouse look; only the number keys answer (brief item 25: the wheel, E and
	#    the arrows never pick a reply)
	g.player.leave_focus()
	await _frames(30)
	await _settle_focus()
	var picked := [-1]
	var on_pick := func(i): picked[0] = i
	dlg.choice_made.connect(on_pick)
	_choices("person")
	await _frames(3)
	_check(g.mouse_should_capture(), "replies open in free walk: mouse look stays on")
	_mouse_btn(MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse_btn(MOUSE_BUTTON_WHEEL_DOWN, false)
	await _frames(2)
	await _act("interact")
	_key(KEY_DOWN)
	_key(KEY_SPACE)
	await _frames(3)
	_check(picked[0] == -1 and dlg.has_open_choices(), "the wheel, E, Down and Space do not answer (picked %d)" % picked[0])
	_key(KEY_2)
	await _frames(3)
	_check(picked[0] == 1, "key 2 answers the second reply (picked %d)" % picked[0])
	dlg.choice_made.disconnect(on_pick)
	if dlg.is_active():
		dlg.close()
	# c) radio replies only in the radio view (item 23): standing at the handset is not enough
	var at: Vector3 = g.station.focus["radio"]["at"]
	g.player.global_position = Vector3(at.x, g.player.global_position.y, at.z)
	g.player._apply_look()
	_choices("radio")
	await _frames(3)
	var hidden_near: bool = not dlg.has_open_choices()
	g.player.enter_focus("radio")
	await _settle_focus()
	await _frames(3)
	var shown_in_view: bool = dlg.has_open_choices()
	g.player.leave_focus()
	await _settle_focus()
	await _frames(3)
	var hidden_after: bool = not dlg.has_open_choices()
	_check(hidden_near and shown_in_view and hidden_after, "radio replies: hidden beside the radio, shown in the radio view, hidden after leaving it (%s/%s/%s)" % [hidden_near, shown_in_view, hidden_after])
	g.player.enter_focus("radio")
	await _settle_focus()
	await _frames(3)
	_check(dlg.has_open_choices(), "back in the radio view the replies return")
	dlg.close()
	g.player.leave_focus()
	await _settle_focus()
	# d) the chart opens full screen; a left click or the wheel never closes it; right click / E / Esc do
	g._on_doc("chart")
	await _frames(4)
	var opened: bool = g.presenter.is_document_open()
	_mouse_btn(MOUSE_BUTTON_LEFT, true)
	_mouse_btn(MOUSE_BUTTON_LEFT, false)
	_mouse_btn(MOUSE_BUTTON_WHEEL_UP, true)
	_mouse_btn(MOUSE_BUTTON_WHEEL_UP, false)
	await _frames(3)
	var still_open: bool = g.presenter.is_document_open()
	var zoomed: bool = g.presenter._zoom > 1.0
	_check(opened and not g.mouse_should_capture(), "chart inspection opens and frees the pointer")
	_check(still_open and zoomed, "a left click and the wheel zoom instead of closing the chart (zoom %.2f)" % g.presenter._zoom)
	_mouse_btn(MOUSE_BUTTON_RIGHT, true)
	_mouse_btn(MOUSE_BUTTON_RIGHT, false)
	await _frames(3)
	_check(not g.presenter.is_document_open() and g.player.enabled and g.mouse_should_capture(),
		"right click closes the chart and gives free-walk mouse look back (open=%s enabled=%s focused=%s paused=%s capture=%s)" % [
		g.presenter.is_document_open(), g.player.enabled, g.player.focused, g._paused, g.mouse_should_capture()])
	var tex_ok: bool = g.presenter.doc_info("chart").get("tex", "") != "" and ResourceLoader.exists(g.presenter.doc_info("chart")["tex"])
	_check(tex_ok, "the chart inspection uses the desk chart's own texture")
	# e) E on a document never also advances the dialogue underneath
	_choices("person")
	await _frames(2)
	dlg.close()
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": "Evening, keeper."})
	await _frames(2)
	dlg._shown = dlg._full.length()
	dlg._done_t = 1.0
	var adv := [0]
	var on_adv := func(): adv[0] += 1
	dlg.advance_requested.connect(on_adv)
	g._on_doc("forecast")
	await _frames(4)
	await _act("interact")
	dlg.advance_requested.disconnect(on_adv)
	_check(not g.presenter.is_document_open() and adv[0] == 0, "E closes the document without advancing the line under it (advances %d)" % adv[0])
	dlg.close()
	# f) the blackout torch: not with the lights on; taken in the dark; F switches it; it stays taken
	g._route(g.sim.set_breaker("lights", true))
	await _frames(2)
	var p_on: Dictionary = g.station.prompt_info("torch", false)
	_check(not p_on["ok"] and p_on["key"] == "" and p_on["text"].contains("power fails"), "torch with the lights on: no key, 'for when the power fails' (%s)" % p_on)
	g._route(g.sim.set_breaker("lights", false))
	await _frames(2)
	var p_off: Dictionary = g.station.prompt_info("torch", false)
	_check(p_off["ok"] and p_off["key"] == "[E]" and p_off["text"] == "Pick up the torch", "torch in a blackout: '[E]  Pick up the torch' (%s)" % p_off)
	await _aim_at("torch")
	_check(g.player.hovered == "torch", "the crosshair finds the torch on the shelf (hovered=%s)" % g.player.hovered)
	await _act("interact")
	var held: bool = g.player.torch_held and g.player.torch_light != null and g.player.torch_light.visible
	var gone: bool = g.station.torch_taken and g.station._torch_nodes.all(func(n): return not n.visible)
	_check(held and gone and not g.station._torch_nodes.is_empty(), "E takes the torch: the beam is on and the shelf torch is gone (%d meshes)" % g.station._torch_nodes.size())
	await _act("torch")
	var off: bool = not g.player.torch_light.visible
	await _act("torch")
	_check(off and g.player.torch_light.visible, "F switches the torch off and on again")
	_check(g.player.torch_light.shadow_enabled and g.player.torch_light.spot_range >= 8.0, "the beam casts shadows and reaches across the room")
	_check(bool(g.save_dict()["player"].get("torch", false)), "the save remembers the keeper has the torch")
	g._route(g.sim.set_breaker("lights", true))
	# g) repeated sequences always come back to free-walk mouse look
	var bad: Array = []
	for i in 4:
		g.player.enter_focus("radio")
		await _frames(30)
		await _settle_focus()
		_choices("radio")
		await _frames(2)
		_key(KEY_1)
		await _frames(2)
		g.player.leave_focus()
		await _frames(30)
		await _settle_focus()
		if not g.mouse_should_capture():
			bad.append("radio#%d" % i)
		g._on_doc("chart")
		await _frames(4)
		await _act("pause")                       # Esc closes the chart, never pauses under it
		if g._paused or g.presenter.is_document_open() or not g.mouse_should_capture():
			bad.append("chart#%d" % i)
		await _act("pause")                       # Esc pauses ...
		if paused:
			g.set_paused(false)                   # ... and main_fp resumes on Esc under pause (not loaded here)
		await _frames(2)
		if g._paused or not g.mouse_should_capture():
			bad.append("pause#%d" % i)
		g.player.enter_focus("console")
		await _frames(30)
		await _settle_focus()
		await _act("pause")                       # Esc steps back out of the view
		await _frames(30)
		if g.player.focused != "" or not g.mouse_should_capture():
			bad.append("console#%d" % i)
		if dlg.is_active():
			dlg.close()
	_check(bad.is_empty(), "4 rounds of radio, chart, pause and console all return to mouse look (failures: %s)" % [bad])
	if DisplayServer.get_name() == "headless":
		skips.append("R8 real Input.mouse_mode after the loop (headless)")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "after the loop the pointer is captured (mode %d)" % Input.mouse_mode)


func _choices(mode: String) -> void:
	dlg.show_line({"mode": mode, "speaker": "MORAG" if mode == "radio" else "VISITOR",
		"text": "North Point, Stornoway Coastguard. Are you receiving, Callum? Over." if mode == "radio" else "Evening, keeper."})
	dlg.show_choices({"choices": [{"index": 0, "text": "Receiving you, Morag. All quiet here. Over."},
		{"index": 1, "text": "Go ahead, Stornoway. Over."}]})
	dlg._choice_age = 9.0          # past the 0.4 s anti-accident guard (item 25; checked on its own in R10)


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
	# cabin pass (Daniel 2026-11-05): replies no longer free the pointer in free walk (IMG_3140)
	_check(g.mouse_should_capture(), "open choices keep mouse-look in free walk")
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
	await _settle_focus()
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
	await _settle_focus()
	g.set_paused(true)
	g.set_paused(false)
	_check(g.mouse_should_capture(), "leaving the radio view with replies open gives mouse-look back (no stuck pointer)")
	_check(not dlg.has_open_choices() or not g._at_radio(), "radio replies hide once the keeper is away from the handset")
	dlg.close()
	dlg.choice_made.disconnect(cb)
	await _frames(2)


func _r2_overlap() -> void:
	print("R2 choices vs radio command panel")
	g.player.enter_focus("radio")
	await _frames(2)
	await _settle_focus()
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
	await _settle_focus()


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


## Stage 3A: dialogue and typography foundation.
func _r9_dialogue_foundation() -> void:
	print("R9 dialogue foundation")
	var st_node: Node = root.get_node("Settings")
	if dlg.is_active():
		dlg.close()
	# --- fonts: bundled files, a genuine italic face
	var serif_base: Font = (UIStyle.serif() as FontVariation).base_font
	var ital_base: Font = (UIStyle.serif_italic() as FontVariation).base_font
	_check(serif_base is FontFile and ital_base is FontFile and serif_base != ital_base,
		"serif and its italic are bundled font files (%s / %s)" % [serif_base, ital_base])
	_check(dlg.s_text.get_theme_font("italics_font") == UIStyle.serif_italic(), "subtitle italics use the italic face")
	for f in [UIStyle.sans(), UIStyle.typewriter(), UIStyle.hand()]:
		_check((f as FontVariation).base_font is FontFile, "bundled font loads: %s" % (f as FontVariation).base_font.resource_path.get_file())
	# --- parser: presence tags, expressions, sound captions
	var db := DialogueDB.new()
	db.parse_text("""== r9a mode=radio
ROSS: That's my girl.
MORAG(worried): Mayday received.
~ A thought.
> Three slow knocks.
ROSS@radio: On the handset.
== r9b mode=thought
VISITOR: Callum! Open the door.
== r9c mode=person
Ross said: not a speaker line
""", "r9")
	_check(db.errors.size() == 1 and String(db.errors[0]).contains("cannot parse"), "only the lower-case 'Ross said:' line is rejected (%s)" % [db.errors])
	_check(String(db.convs["r9a"]["steps"][1]["expr"]) == "worried" and db.convs["r9a"]["steps"][1]["speaker"] == "MORAG", "MORAG(worried): parses with its expression")
	# --- runner: resolved speaker, looks, history
	var stt := StoryState.new()
	var run := DialogueRunner.new(db, stt)
	run.start("r9a")
	var looks: Array = []
	var names: Array = []
	for i in 5:
		var it: Dictionary = run.advance()
		looks.append(it["look"])
		names.append(it["name"])
	_check(looks == ["person", "radio", "thought", "sound", "radio"], "looks: in-room / radio / thought / sound / @radio (%s)" % [looks])
	_check(names[0] == "The man at the door" and not "Alasdair Ross" in names, "Ross is the man at the door before his name (%s)" % [names])
	var hist_txt := JSON.stringify(stt.history)
	_check(not hist_txt.contains("ROSS") and not hist_txt.contains("Alasdair"), "history keeps the name as shown (no ROSS before the reveal)")
	_check(int(stt.history[0].get("chapter", 0)) == stt.chapter and String(stt.history[0].get("conv", "")) == "r9a", "history entries carry chapter and conversation")
	stt.flags["knows_name"] = 1
	run.start("r9a")
	_check(String(run.advance()["name"]) == "Alasdair Ross", "after knows_name the same line is Alasdair Ross")
	run.start("r9b")
	_check(String(run.advance()["look"]) == "person", "a named speaker inside a thought scene is a person subtitle, not Callum's thought")
	var legacy := Speakers.sanitize_history([{"speaker": "ROSS", "text": "x", "mode": "person"}], stt)
	_check(String(legacy[0]["name"]) == "The man at the door" and String(legacy[0]["speaker"]) == "VISITOR", "pre-3A saves: raw ROSS entries are rewritten as shown")
	# --- dialogue UI: names and the identity line
	dlg.show_line({"mode": "radio", "speaker": "MORAG", "text": "North Point, Stornoway. Over."})
	await _frames(2)
	_check(dlg.r_name.text == "Morag Fraser" and dlg.r_ident.text.contains("STORNOWAY COASTGUARD"), "radio name row carries the identity line (%s | %s)" % [dlg.r_name.text, dlg.r_ident.text])
	_check(dlg.r_ident.get_theme_font_size("font_size") >= 15, "identity line is at least 15 px (was a 9-10 px drawing)")
	dlg.show_line({"mode": "radio", "speaker": "ROSS", "text": "That's my girl."})
	await _frames(2)
	_check(dlg.sub_box.visible and dlg.s_name.text == "The man at the door", "an unresolved ROSS item still shows only the man at the door (%s)" % dlg.s_name.text)
	dlg.show_line({"mode": "person", "speaker": "", "text": "He waits."})
	_check(dlg.s_text.text.contains("[i]"), "person-scene narration is an italic thought")
	dlg.show_line({"type": "line", "mode": "person", "speaker": "", "name": "", "look": "sound", "text": "Three slow knocks."})
	_check(dlg.s_text.text.contains("THREE SLOW KNOCKS") and dlg.s_name.text == "", "sound caption in capitals, no name")
	dlg.show_line({"type": "line", "mode": "person", "speaker": "", "name": "", "look": "sound", "text": "[A carrier on Channel 16. Two clicks.]"})
	_check(dlg.s_text.text.count("[lb]") == 1, "a caption already in brackets in the script is not double-bracketed (%s)" % dlg.s_text.text)
	# --- typewriter: laid out once, waits behind a fade and a document
	var long := "The bolt is stiff with salt. The door comes in with the storm behind it, and an old man in an oilskin stands on the top step with one hand on the rail and rain running off the brim of his sou'wester."
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": long})
	await _frames(3)
	var h0: float = dlg.s_text.size.y
	dlg._shown = dlg._full.length()
	dlg._render()
	await _frames(2)
	_check(absf(dlg.s_text.size.y - h0) < 1.0, "the subtitle block keeps its height while typing (%.0f -> %.0f px)" % [h0, dlg.s_text.size.y])
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": long})
	g.presenter.fade.color.a = 1.0
	await _frames(20)
	_check(dlg._shown < 1.0, "nothing types while the screen is black (%.1f chars)" % dlg._shown)
	g.presenter.fade.color.a = 0.0
	await _frames(30)
	_check(dlg._shown > 1.0, "typing resumes when the fade lifts (%.1f chars)" % dlg._shown)
	g.presenter.open_document("forecast")
	await _frames(2)
	var s0: float = dlg._shown
	await _frames(20)
	_check(is_equal_approx(dlg._shown, s0), "the typewriter waits while a document is open")
	g.presenter.close_document()
	g.player.enabled = true
	g.refresh_mouse()
	dlg.close()
	# --- objective tokens and one text scale
	g.presenter.set_objective("Get your bearings. Walk with {move}; look around with {look}.")
	_check(not g.presenter.objective.text.contains("{"), "objective tokens resolve (%s)" % g.presenter.objective.text)
	g.presenter.show_hint("The console stands under the east window. Look at the MODE knob and press {interact}, then turn it to AUTO and wait.")
	g.presenter.objective.text = "▸ " + "Lighting-up time. Turn the MODE selector to AUTO at the light console under the east window, then the LAMP selector up to NORMAL, and write it in the log."
	for sc in [0.8, 1.0, 1.5]:
		st_node.v["subtitle_size"] = sc
		st_node.apply()
		await _frames(3)
		var o: Rect2 = g.presenter.objective.get_global_rect()
		var hr: Rect2 = g.presenter.hint.get_global_rect()
		_check(not o.intersects(hr) and hr.position.y >= o.end.y - 0.5, "x%.1f objective and hint never overlap (%s / %s)" % [sc, o, hr])
		_check(g.presenter.objective.get_theme_font_size("font_size") == UIStyle.px(19) and g.presenter.card_title.get_theme_font_size("font_size") == UIStyle.px(64)
			and g.ui.notice.get_theme_font_size("font_size") == UIStyle.px(24), "x%.1f objective, chapter card and notices follow the text size" % sc)
		var vp := g.get_viewport().get_visible_rect()
		_check(vp.encloses(o) and vp.encloses(hr), "x%.1f objective and hint on screen" % sc)
	st_node.v["subtitle_size"] = 1.0
	st_node.apply()
	g.presenter.set_objective("")
	# --- dialogue history: pauses, never advances, keeps the mouse owner and the pad focus
	var adv := [0]
	var ca := func(): adv[0] += 1
	dlg.advance_requested.connect(ca)
	g.director.state.history.append({"speaker": "VISITOR", "name": "The man at the door", "text": "Evening, keeper.", "look": "person", "chapter": 4, "clock": "02:51"})
	_choices("person")
	await _frames(3)
	InputSetup.pad_active = true
	dlg._pad_focus()
	await _frames(2)
	(dlg.choice_box.get_child(1) as Control).grab_focus()
	var focus_before: Control = g.get_viewport().gui_get_focus_owner()
	var mouse_before: bool = g.mouse_should_capture()
	await _act("history")
	await _frames(3)
	_check(g.backlog.visible and g.get_tree().paused and not g.mouse_should_capture(), "H / View opens the history, pauses and frees the pointer")
	_check(g.backlog.text.text.contains("The man at the door") and not g.backlog.text.text.contains("Alasdair"), "the history shows names as they were shown")
	for i in 3:
		_key(KEY_E)
		await _frames(3)
	_key(KEY_1)
	await _frames(3)
	_check(adv[0] == 0 and dlg.has_open_choices(), "E and 1 under the history neither advance nor answer")
	await _act("history")
	await _frames(3)
	_check(not g.backlog.visible and not g.get_tree().paused and g.mouse_should_capture() == mouse_before, "H closes it: play resumes, mouse policy as before")
	_check(g.get_viewport().gui_get_focus_owner() == focus_before, "the highlighted reply is still highlighted for the pad")
	InputSetup.pad_active = false
	g.set_paused(true)
	await _frames(2)
	g.ui.backlog_requested.emit()
	await _frames(2)
	_check(g.backlog.visible and g.ui.pause_panel != null and not g.ui.pause_panel.visible, "pause menu > Dialogue history opens over the pause menu")
	g.close_backlog()
	await _frames(2)
	_check(not g.backlog.visible and g.get_tree().paused and g.ui.pause_panel.visible, "closing it returns to the pause menu, still paused")
	g.set_paused(false)
	await _frames(2)
	dlg.advance_requested.disconnect(ca)
	dlg.close()
	# the history must never write the mouse mode (R8's single-owner rule)
	var src := FileAccess.get_file_as_string("res://scripts/ui/backlog_ui.gd")
	_check(not src.contains("mouse_mode"), "backlog_ui never touches Input.mouse_mode")


## Stage 3B: the narrative mechanics behind the approved script (STAGE3_NARRATIVE_MASTER §18).
func _r10_narrative_mechanics() -> void:
	print("R10 narrative mechanics (Stage 3B)")
	# --- a) the story jam: binds on the tooth in any mode, no MAIN trip, survives a power loss (ch2 race)
	var k := KeeperSim.new()
	k.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 3)
	k.story_mode = true
	k.battery = 90
	k.set_mode(KeeperSim.Mode.AUTO)
	k.set_intensity(1)
	var ev := k.trigger_fault("jam", ["story"])
	_check(k.jammed and k.story_jam and ev.size() == 1 and absf(rad_to_deg(k.bearing) - 46.0) < 0.5,
		"a story jam binds at once with the repeater on 046 (%.1f°)" % rad_to_deg(k.bearing))
	var cleared := false
	for i in 600:                                   # 10 s in AUTO
		for e in k.step(1.0 / 60.0):
			cleared = cleared or e["type"] == "jam_cleared"
	_check(k.main_breaker and k.jammed and not cleared, "10 s jammed in AUTO: MAIN does not trip, the jam holds")
	k.trigger_fault("trip")
	for i in 120:
		for e in k.step(1.0 / 60.0):
			cleared = cleared or e["type"] == "jam_cleared"
	_check(k.jammed and not cleared, "losing MAIN does not clear a story jam (the ch2 race)")
	k.set_breaker("main", true)
	k.set_mode(KeeperSim.Mode.MANUAL)
	var b0 := k.bearing
	k.set_wheel(1.0)
	for i in 120:
		k.step(1.0 / 60.0)
	_check(absf(k.bearing - b0) < 0.001, "MANUAL on the tooth: the handwheel is rigid")
	k.set_mode(KeeperSim.Mode.OFF)
	for i in 120:
		k.step(1.0 / 60.0)
	_check(k.jammed and absf(k.bearing - b0) < 0.001, "OFF: the wheel will not drive her forward past the tooth")
	k.set_wheel(-1.0)
	for i in 240:
		for e in k.step(1.0 / 60.0):
			cleared = cleared or (e["type"] == "jam_cleared")
	_check(cleared and not k.jammed and rad_to_deg(k.bearing) < 46.0 - k.cfg.jam_back_deg + 0.5,
		"backing the handwheel past the tooth frees it (%.1f°)" % rad_to_deg(k.bearing))
	k.set_wheel(0.0)
	# --- b) Ross on the handwheel keeps the beam on the ship in MANUAL (lit_by_hand)
	k.spawn_story_ship({"name": "Iona Star", "kind": "steamer", "bearing": 66, "aim": 30, "speed_mul": 0.55, "hold": true, "protected": true,
		"range": 150.0})                              # inside the hand beam's reach
	var st := StoryState.new()
	st.sim = k
	k.set_mode(KeeperSim.Mode.MANUAL)
	k.assist = true
	for i in 360:
		k.step(1.0 / 60.0)
	_check(st.lit_by_hand("Iona Star"), "Ross assist: the beam is held on the Iona Star in MANUAL")
	k.set_mode(KeeperSim.Mode.AUTO)
	_check(not st.lit_by_hand("Iona Star"), "the assist is only a MANUAL thing")
	# --- c) transitions hold the story; nothing types or advances under black
	var d: StoryDirector = g.director
	d._do(["timeskip", 1110, "18:30"])
	_check(d.is_held(), "a timeskip holds the story")
	dlg.show_line({"mode": "person", "speaker": "MORAG", "text": "This line must wait for the fade to lift."})
	await _frames(70)                                 # the screen is black by now (1.0 s fade)
	_key(KEY_E)
	await _frames(3)
	_check(g.presenter.fade.color.a > 0.5 and dlg._shown < 1.0, "under black: no typing, and E does not finish the line")
	var t := 0
	while d.is_held() and t < 400:
		await process_frame
		t += 1
	_check(not d.is_held() and g.presenter.fade.color.a < 0.05, "the hold is released when the fade has lifted (%d frames)" % t)
	dlg.close()
	# --- d) the ending card: title, the lines one by one, input moves it on, then it releases the story
	var lines := ["The Board opened a new inquiry in the spring.", "North Point Light. Fifteenth of November, nineteen seventy-one.", "The light was kept."]
	var done := [false]
	g.presenter.show_ending("correction", "Correction", lines)
	await _frames(5)
	_check(g.presenter.ending_root.visible and g.presenter.is_screen_held(), "the ending card covers the screen and holds dialogue")
	_check(g.presenter.ending_title.text.begins_with("C O R R E C T I O N"), "the title is set in spaced capitals (%s)" % g.presenter.ending_title.text)
	t = 0
	while g.presenter.is_ending_open() and t < 2400:
		if t > 30 and t % 25 == 0:
			_key(KEY_E)
		await process_frame
		t += 1
	_check(not g.presenter.is_ending_open() and g.presenter.ending_box.get_child_count() == lines.size(),
		"every epilogue line was shown, then the card released (%d frames)" % t)
	g.presenter.ending_root.visible = false
	g.presenter.ending_bg.color.a = 0.0
	g.presenter.dialogue.visible = true
	# --- e) optional calls: offered between their beats, deferring the next beat's talk until they end
	var k2 := KeeperSim.new()
	k2.setup(KeeperConfig.new(), LayoutData.load_file(), {"ships": [], "faults": []}, 5)
	k2.story_mode = true
	var d2 := StoryDirector.new()
	root.add_child(d2)
	d2.setup(k2, true)
	d2.state.chapter = 2
	d2.state.beat = 4                                  # second_call: wait 8, then the Mary Ellen talks
	d2._enter_beat()
	var ids: Array = d2.available_calls().map(func(c): return String(c["id"]))
	_check(ids.has("opt_ch2_rory") and ids.has("opt_ch2_morag"), "ch2 after Gannet: Rory and Morag can be called (%s)" % [ids])
	d2.state.beat = 6
	_check(d2.available_calls().is_empty(), "the calls close once the archive beat has run")
	d2.state.beat = 4
	_check(d2.request_call("opt_ch2_morag") and d2.optional_running() == "opt_ch2_morag", "a call starts from the panel")
	var convs := {}
	for i in 900:                                     # 15 s: the Mary Ellen would have spoken by now
		d2._process(1.0 / 60.0)
		if d2.is_talking():
			convs[String(d2.runner.conv.get("id", ""))] = true
		if not d2.is_talking() and i > 10:
			break
	_check(not convs.has("ch2_mary_ellen") and d2.state.clue("sister_boat"), "the beat's talk waits for the optional call (%s)" % [convs.keys()])
	for i in 900:
		d2._process(1.0 / 60.0)
		if d2.is_talking():
			convs[String(d2.runner.conv.get("id", ""))] = true
	_check(convs.has("ch2_mary_ellen"), "then the Mary Ellen calls")
	_check(not d2.available_calls().any(func(c): return c["id"] == "opt_ch2_morag"), "a call is offered once")
	d2.queue_free()
	g.director.state.chapter = 2
	g.director.state.beat = 4
	g.ui._refresh_calls()
	_check(g.ui.calls_box.visible and g.ui.calls_list.get_child_count() == 2, "the radio panel lists both calls")
	g.director.state.chapter = 1
	g.director.state.beat = 0
	g.ui._refresh_calls()
	_check(not g.ui.calls_box.visible, "no calls, no 'Call a station' box")
	# --- f) nobody sees "Alasdair Ross" before his name is spoken: ch4 door kept shut, then ch5's first line
	var st3 := StoryState.new()
	var r := DialogueRunner.new(g.director.db, st3)
	r.start("ch4_door")
	var shown: Array = []
	var item := r.advance()
	while item["type"] != "end":
		if item["type"] == "choice":
			var pick := 0
			for c in item["choices"]:
				if "Keep the door shut" in String(c["text"]):
					pick = int(c["index"])
			item = r.choose(pick)
			continue
		if item["type"] == "line":
			shown.append(String(item["name"]))
		item = r.advance()
	r.start("ch5_ross")
	item = r.advance()
	while item["type"] != "line" or String(item["name"]) == "":     # past Callum's opening thought
		item = r.advance()
	var first_name: String = item["name"]                           # "Alasdair Ross. Master of the Mary Ellen..."
	item = r.advance()
	while item["type"] != "line" or String(item["name"]) == "":
		item = r.advance()
	_check(not shown.has("Alasdair Ross") and first_name != "Alasdair Ross" and String(item["name"]) == "Alasdair Ross",
		"his name shows only after he says it (door: %s, ch5: %s -> %s)" % [shown, first_name, item["name"]])
	_check(not JSON.stringify(st3.history.slice(0, -1)).contains("Alasdair Ross\""), "the history never stored the name before it was known")
	# --- g) the bolt, and h) the photograph props
	var gs: StoryState = g.director.state
	gs.chapter = 4
	gs.beat = 2
	g.station.door_open = false
	g._use_door()
	await _frames(2)
	_check(gs.has_flag("bolted") and g.director.is_talking(), "drawing the bolt sets `bolted` and says so")
	g.director._talking = false
	dlg.close()
	gs.flags.erase("bolted")
	gs.clues["photo_1953"] = true
	g._update_story_props()
	_check(g.station.story_prop_shown("photo53") and not g.station.story_prop_shown("photo53desk"), "door kept shut: the photograph lies inside the door")
	gs.clues.erase("photo_1953")
	gs.flags["door_open"] = 1
	gs.chapter = 5
	g._update_story_props()
	_check(g.station.story_prop_shown("photo53desk") and not g.station.story_prop_shown("photo53"), "door opened: from ch5 he has left it on the desk")
	gs.flags.erase("door_open")
	gs.chapter = 1
	gs.beat = 0
	g._update_story_props()



func _r11_brief_g1() -> void:
	print("R11 brief G1: input split, guards, card order, radar, comms")
	g.player.leave_focus()
	await _settle_focus()
	# a) E while a line is up: the line neither finishes nor advances, and the press is not swallowed
	var adv := [0]
	var ca := func(): adv[0] += 1
	dlg.advance_requested.connect(ca)
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": "A line long enough to still be typing when the keeper presses E."})
	await _frames(2)
	await _act("interact")
	_check(adv[0] == 0 and dlg._shown < dlg._full.length(), "E does not finish or advance a dialogue line (item 7)")
	var dsrc := FileAccess.get_file_as_string("res://scripts/ui/dialogue_ui.gd")
	_check(not dsrc.contains('is_action_pressed("interact")'), "the dialogue layer never reads the interact action, so E always reaches the player")
	# b) Space: the first press finishes the line; a second press inside the dwell does nothing; after it, advances
	_key(KEY_SPACE)
	await _frames(1)
	_check(dlg._shown >= dlg._full.length() and adv[0] == 0, "Space finishes the typewriter first")
	_key(KEY_SPACE)
	await _frames(1)
	_check(adv[0] == 0, "a second Space inside %.1f s does not skip the line" % dlg.ADVANCE_DWELL_S)
	dlg._done_t = dlg.ADVANCE_DWELL_S + 0.1
	_key(KEY_SPACE)
	await _frames(1)
	_check(adv[0] == 1, "Space advances once the full line has been up long enough")
	dlg.advance_requested.disconnect(ca)
	dlg.close()
	# c) replies ignore input in their first moments
	var picked := [-1]
	var cp := func(i): picked[0] = i
	dlg.choice_made.connect(cp)
	dlg.show_line({"mode": "person", "speaker": "VISITOR", "text": "Evening, keeper."})
	dlg.show_choices({"choices": [{"index": 0, "text": "Who's there?"}, {"index": 1, "text": "Say nothing."}]})
	_key(KEY_1)
	await _frames(1)
	_check(picked[0] == -1, "a number key in the replies' first 0.4 s is ignored (item 25)")
	dlg._choice_age = 1.0
	_key(KEY_1)
	await _frames(1)
	_check(picked[0] == 0, "after the guard, key 1 answers")
	dlg.choice_made.disconnect(cp)
	dlg.close()
	# d) the clock card draws above the black, and is fully up on black for at least CARD_ON_BLACK_S
	var pr: CanvasLayer = g.presenter
	_check(pr.card.get_index() > pr.fade.get_index(), "the clock / chapter card draws above the fade (item 21)")
	pr.timeskip("19:40")
	var on_black_ms := 0
	var last := Time.get_ticks_msec()
	var t := 0
	while t < 2000 and (pr.fade.color.a > 0.02 or t < 5):
		await process_frame
		var now := Time.get_ticks_msec()
		if pr.fade.color.a > 0.98 and pr.card.modulate.a > 0.98:
			on_black_ms += now - last
		last = now
		t += 1
	_check(pr.card_title.text == "19:40" and on_black_ms >= 1500, "the time skip clock is fully up on black for %d ms (>= 1500)" % on_black_ms)
	g.director._hold = 0
	# e) the radar is its own target and never opens the radio view
	_check(g.station.DEVICES["radar"]["kind"] == "info", "the radar is an info target, not a radio focus (item 23)")
	g.player.focused = ""
	_check(not g._at_radio(), "standing near the radio without the radio view does not answer it")
	# f) sim radio chatter waits while a story line is up, then shows; it is in the transcript either way
	g.director.process_mode = Node.PROCESS_MODE_INHERIT
	var hist0: int = g.director.state.history.size()
	var subs0: int = g.ui._sub_items.size()
	dlg.show_line({"mode": "radio", "speaker": "MORAG", "text": "North Point, Stornoway. Radio check, over."})
	g.sim.battery = maxf(g.sim.battery, 50.0)
	g.sim.main_breaker = true
	g._comms_radio("Kittiwake", "Position bearing 014, North Point.", false, "position", -1)
	await _frames(3)
	_check(g._comms_queue.size() == 1 and g.ui._sub_items.size() == subs0, "a sim radio line waits behind a story line (item 26)")
	_check(g.director.state.history.size() == hist0 + 1, "the sim radio line is in the transcript")
	dlg.close()
	g._comms_gap = 0.0
	await _frames(3)
	_check(g._comms_queue.is_empty() and g.ui._sub_items.size() >= 1, "it shows once the story line has closed")
	g.director.process_mode = Node.PROCESS_MODE_DISABLED
