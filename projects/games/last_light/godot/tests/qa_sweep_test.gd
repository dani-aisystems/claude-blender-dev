extends SceneTree
## Stage 0.2 QA sweep (automated):
##  F  dialogue FIT: every line of every conversation, in its own mode, at text size 1.0 and 1.5 (the
##     Options maximum): the radio panel / subtitle block stays inside its slot and on screen; every
##     reply fits; every radio identity line sits inside the panel at its scaled size (Stage 3A: x0.8 too).
##  O  OPTIONS apply live: each Options setting changes what it claims to, without a restart.
##   godot --path godot -s res://tests/qa_sweep_test.gd -- --windowed   (all checks)
##   godot --headless --path godot -s res://tests/qa_sweep_test.gd       (display-only checks SKIPPED)
## Settings are changed in memory only (never saved to user://settings.cfg) and restored at the end.

var fails: Array[String] = []
var skips: Array[String] = []
var passes := 0
var g: Node3D
var dlg: Control
var Settings: Node                     # autoload, looked up at runtime (not a compile-time name in -s scripts)


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	Settings = root.get_node("/root/Settings")
	var saved_settings: Dictionary = Settings.v.duplicate()
	g = load("res://scripts/fp/game_fp.gd").new()
	root.add_child(g)
	g.start(5, "", false, true)
	await _frames(3)
	g.director.process_mode = Node.PROCESS_MODE_DISABLED
	dlg = g.presenter.dialogue
	await _fit()
	await _options()
	Settings.v = saved_settings
	Settings.apply()
	print("QA_RESULT ", JSON.stringify({"passed": passes, "failed": fails.size(), "failures": fails, "skipped": skips}))
	quit(1 if fails.size() > 0 else 0)


# ------------------------------------------------------------------ F: dialogue fit

func _fit() -> void:
	print("F dialogue fit")
	var db := DialogueDB.new()
	db.load_dir("res://data/story")
	var vp := dlg.get_viewport_rect()
	var n_lines := 0
	var n_choices := 0
	g.player.enter_focus("radio")          # radio replies only unlock at the radio; also shows the command panel
	await _frames(30)
	# identity lines (Stage 3A): on the radio name row at a readable, scaled size; they wrap inside the panel
	for scale in [0.8, 1.0, 1.5]:
		dlg.apply_settings(42.0, scale)
		for sp in Speakers.TABLE:
			var e: Dictionary = Speakers.TABLE[sp]
			if String(e["where"]) != "radio":
				continue
			await _show_full({"mode": "radio", "speaker": sp, "text": "North Point. Over."})
			var pr: Rect2 = dlg.radio_panel.get_global_rect()
			var ir: Rect2 = dlg.r_ident.get_global_rect()
			_check(pr.encloses(ir) and dlg.r_ident.get_theme_font_size("font_size") >= int(15 * scale) - 1,
				"x%.1f identity line for %s inside the panel at %d px (%s)" % [scale, sp, dlg.r_ident.get_theme_font_size("font_size"), dlg.r_ident.text])
	for scale in [0.8, 1.0, 1.5]:
		dlg.apply_settings(42.0, scale)
		var worst_radio := 0.0
		var worst_sub := 0.0
		for id in db.convs:
			var conv: Dictionary = db.convs[id]
			var mode: String = conv["mode"]
			var last := {"mode": mode, "speaker": "MORAG" if mode == "radio" else "", "text": "…"}
			for s in conv["steps"]:
				if s["kind"] == "line":
					n_lines += 1
					last = {"mode": mode, "speaker": s["speaker"], "text": s["text"]}
					await _show_full(last)
					var tag := "x%.1f %s '%s…'" % [scale, id, String(s["text"]).left(40)]
					if dlg.line_look == "radio":
						var r: Rect2 = dlg.radio_panel.get_global_rect()
						worst_radio = maxf(worst_radio, r.size.y)
						_check(vp.encloses(r), "%s radio panel fully on screen (%s)" % [tag, r])
					else:
						var sr: Rect2 = dlg.sub_box.get_global_rect()
						worst_sub = maxf(worst_sub, sr.size.y)
						_check(vp.encloses(sr), "%s subtitle block fully on screen (%s)" % [tag, sr])
				elif s["kind"] == "choice":
					# the replies exactly as the player meets them: after the line they answer
					await _show_full(last)
					var list: Array = []
					for i in s["choices"].size():
						list.append({"index": i, "text": s["choices"][i]["text"]})
					dlg.show_choices({"choices": list})
					await _frames(2)
					n_choices += list.size()
					var tag := "x%.1f %s (%d replies)" % [scale, id, list.size()]
					_check(dlg.choice_box.get_child_count() == list.size(), "%s replies shown" % tag)
					var box := Rect2()
					for b in dlg.choice_box.get_children():
						var br: Rect2 = (b as Control).get_global_rect()
						box = br if box.size == Vector2.ZERO else box.merge(br)
						_check(br.end.x <= 48 + 700 + 1, "%s reply stays in its 700 px column: '%s' (%s)" % [tag, String((b as Button).text).left(40), br])
					var speech: Rect2 = dlg.radio_panel.get_global_rect() if dlg.radio_panel.visible else dlg.sub_box.get_global_rect()
					_check(vp.encloses(box), "%s replies on screen (%s)" % [tag, box])
					_check(not box.intersects(speech), "%s replies clear of the speech block (%s vs %s)" % [tag, box, speech])
					if g.ui.radio_panel.visible:
						_check(not box.intersects(g.ui.radio_panel.get_global_rect()), "%s replies clear of the radio command panel" % tag)
		if g.ui.radio_panel.visible:
			var cp: Rect2 = g.ui.radio_panel.get_global_rect()
			_check(vp.encloses(cp), "x%.1f radio command panel fully on screen (%s)" % [scale, cp])
			_check(not cp.intersects(dlg.radio_panel.get_global_rect()), "x%.1f command panel clear of the dialogue radio panel" % scale)
		dlg.close()
		print("  x%.1f: tallest radio panel %.0f px, tallest subtitle block %.0f px" % [scale, worst_radio, worst_sub])
	print("  checked %d line renders and %d reply renders across 3 text sizes" % [n_lines, n_choices])
	dlg.apply_settings(Settings.v["text_speed"], Settings.v["subtitle_size"])


func _show_full(item: Dictionary) -> void:
	dlg.show_line(item)
	dlg._shown = dlg._full.length()
	dlg._render()
	await _frames(2)


# ------------------------------------------------------------------ O: options apply live

func _opt(k: String, val) -> void:
	Settings.v[k] = val
	Settings.apply()                       # what set_value() does, minus the file write


func _options() -> void:
	print("O options apply live")
	var headless := DisplayServer.get_name() == "headless"
	# graphics
	_opt("max_fps", 30)
	_check(Engine.max_fps == 30, "frame-rate limit applies (Engine.max_fps=%d)" % Engine.max_fps)
	_opt("max_fps", 0)
	for q in [0, 1, 2]:
		_opt("quality", q)
		# Stage 1a presets: SSAO + SSIL from Medium, <= 8 shadowed interior lights on High
		var ids: Array = Settings.q_shadow_ids()
		_check(Settings.q_ssao() == (q >= 1) and Settings.q_ssil() == (q >= 1) and Settings.q_volumetric() == (q >= 1)
			and ids.size() <= 8 and not ("*" in ids), "quality %d presets (shadowed lights %d)" % [q, ids.size()])
		# 1p: FXAA on Low/Medium, 2x MSAA on High (4x MSAA everywhere cost about 5 ms)
		_check(root.msaa_3d == [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
			and root.screen_space_aa == [Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_DISABLED][q],
			"quality %d anti-aliasing (msaa %d, screen aa %d)" % [q, root.msaa_3d, root.screen_space_aa])
	if headless:
		skips.append("render_res / vsync (headless display)")
	else:
		_opt("render_res", 1)
		var native: float = root.scaling_3d_scale
		_opt("render_res", 0)
		var auto: float = root.scaling_3d_scale
		var px := DisplayServer.window_get_size()
		print("  window %s px: native scale %.2f, auto scale %.2f (mode %d)" % [px, native, auto, root.scaling_3d_mode])
		if px.x * px.y > 1920 * 1080 * 1.1:
			_check(auto < native - 0.05, "Auto render resolution lowers the 3D scale on a HiDPI window (%.2f < %.2f)" % [auto, native])
			_check(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "Auto upscales with FSR")
		else:
			skips.append("render_res: window not larger than 1080p")
		_opt("vsync", false)
		_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "vsync off applies")
		_opt("vsync", true)
	_opt("fov", 85.0)
	await process_frame
	_check(is_equal_approx(g.player.camera.fov, 85.0), "field of view applies live (camera fov %.1f)" % g.player.camera.fov)
	_opt("fov", 72.0)
	_opt("brightness", 1.4)
	await _frames(2)
	_check(is_equal_approx(g.outside.env.tonemap_exposure, 1.35 * 1.4), "brightness applies live (exposure %.2f)" % g.outside.env.tonemap_exposure)
	_opt("brightness", 1.0)
	# audio
	for b in Settings.BUSES:
		_opt("vol_" + b.to_lower(), 0.25)
		var i := AudioServer.get_bus_index(b)
		_check(i >= 0 and absf(AudioServer.get_bus_volume_db(i) - linear_to_db(0.25)) < 0.1, "%s volume applies" % b)
	_opt("vol_master", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.1, "master volume applies")
	# accessibility: dialogue text size and speed must apply without restarting the game
	_opt("subtitle_size", 1.4)
	_opt("text_speed", 90.0)
	await process_frame
	var fs: int = dlg.r_text.get_theme_font_size("normal_font_size")
	_check(fs == UIStyle.px(25), "dialogue text size applies live (radio font %d px, want %d)" % [fs, UIStyle.px(25)])
	_check(is_equal_approx(dlg.speed_cps, 90.0), "text speed applies live (%.0f cps)" % dlg.speed_cps)
