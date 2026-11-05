extends SceneTree
## Stage 0 regression tests for the three gameplay blockers (2026-11-04 audit):
##  R1  mouse look is restored after picking a dialogue reply in free-walk (and NOT inside a device view)
##  R2  dialogue choices never overlap the radio command panel (several window aspect ratios)
##  R3  input under the pause menu does not advance dialogue, pick choices, or run the typewriter
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
	print("REGRESS_RESULT ", JSON.stringify({"passed": passes, "failed": fails.size(), "failures": fails, "skipped": skips}))
	quit(1 if fails.size() > 0 else 0)


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
