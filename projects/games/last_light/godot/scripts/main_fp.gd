extends Node
## THE LAST LIGHT root: cinematic title over the live lighthouse exterior, Continue / New Game / Load /
## Options / Credits / Quit, a loading screen that tracks real threaded loading, and the transition
## into the watch room. CLI (after --): --seed=N --windowed --bot=expert --mode=watch|story
##   --capture=NAME --shots=...   --autotest=SECONDS [--autotest-out=PATH]   --load=SLOT

const GAME := preload("res://scripts/fp/game_fp.gd")
const PRELOAD := ["res://assets/models/watch_room.glb", "res://assets/models/lighthouse.glb"]

var game: Node3D
var menu_bg: Node3D
var menu: CanvasLayer
var panel: Control
var _loading: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Dictionary = GameState.user_args
	if args.has("windowed") or args.has("capture") or args.has("autotest"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position + Vector2i(10, 10))
	Settings.apply_render_scale()          # preset x HiDPI fit (or --scale3d), re-applied on resize
	if args.has("capture"):
		var cap := preload("res://scripts/capture_fp.gd").new()
		cap.main = self
		add_child(cap)
		show_menu()
	elif args.has("autotest"):
		var at := preload("res://scripts/autotest.gd").new()
		at.main = self
		add_child(at)
		start_game(args.get("bot", "expert"), args.get("mode", "story") == "story")
	elif args.has("load"):
		load_slot(args["load"])
	else:
		show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game and get_tree().paused:
		game.set_paused(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and panel and is_instance_valid(panel):
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	get_tree().paused = false
	for n in [game, menu_bg, menu, _loading]:
		if n and is_instance_valid(n):
			n.queue_free()
	game = null
	menu_bg = null
	menu = null
	panel = null
	_loading = null


# ------------------------------------------------------------------ title

func show_menu() -> void:
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_bg = GAME.new()
	add_child(menu_bg)
	menu_bg.start(GameState.next_seed(), "expert", true, false)
	menu = CanvasLayer.new()
	add_child(menu)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(root)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0.01, 0.02, 0.78))
	g.set_color(1, Color(0, 0.01, 0.02, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(0.6, 0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 130
	col.offset_top = -300
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)
	var logo := TextureRect.new()             # Daniel's logotype (branding/make_branding.py)
	logo.texture = preload("res://assets/branding/logo_title.png")
	logo.custom_minimum_size = Vector2(760, 219)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo)
	col.add_child(UIStyle.label("North Point Light  ·  Outer Hebrides  ·  14 November 1971", 24, UIStyle.AMBER, UIStyle.serif()))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	col.add_child(sp)
	var latest := SaveSystem.latest()
	var cont := _menu_btn(col, "Continue", func(): load_slot(latest))
	cont.disabled = latest == ""
	if latest != "":
		col.add_child(UIStyle.label("      " + SaveSystem.summary(latest), 16, UIStyle.DIM))
	var newb := _menu_btn(col, "New Game", _new_game)
	_menu_btn(col, "Load Game", _open_load)
	_menu_btn(col, "Options", _open_options)
	_menu_btn(col, "Credits", _open_credits)
	_menu_btn(col, "Quit", func(): get_tree().quit())
	(cont if latest != "" else newb).grab_focus.call_deferred()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 2.5)


func _menu_btn(parent: Control, text: String, f: Callable) -> Button:
	var b := UIStyle.button(text)
	b.custom_minimum_size = Vector2(360, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.pressed.connect(func():
		if menu_bg and menu_bg.audio:
			menu_bg.audio.sfx("ui_click", -6.0, "SFX")
		f.call())
	b.mouse_entered.connect(func():
		if menu_bg and menu_bg.audio:
			menu_bg.audio.sfx("ui_hover", -10.0, "SFX"))
	parent.add_child(b)
	return b


func _new_game() -> void:
	if SaveSystem.exists("auto"):
		_confirm("Start a new story? Your autosave will be replaced when the new night begins.", func(): _transition_in({}))
	else:
		_transition_in({})


func load_slot(slot: String) -> void:
	var d := SaveSystem.read(slot)
	if d.is_empty() or d.has("corrupt"):
		if menu == null:
			show_menu()
		return
	_transition_in(d)


# ------------------------------------------------------------------ loading + transition

func _transition_in(save: Dictionary) -> void:
	var cam: Camera3D = menu_bg.cine_cam if menu_bg else null
	if cam and menu:
		create_tween().tween_property(menu.get_child(0), "modulate:a", 0.0, 0.8)
		var start := cam.position
		var tw2 := create_tween()
		tw2.tween_method(func(k: float):
			cam.position = start.lerp(Vector3(0, 21.5, -16.0), ease(k, 2.4))
			cam.look_at(Vector3(0, 21.5, 0), Vector3.UP), 0.0, 1.0, 2.6)
		await tw2.finished
	_show_loading(save)


func _show_loading(save: Dictionary) -> void:
	var ch := int(save.get("story", {}).get("chapter", 1))
	_clear()
	_loading = CanvasLayer.new()
	_loading.layer = 40
	add_child(_loading)
	var root := ColorRect.new()
	root.color = Color(0.01, 0.015, 0.025)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(root)
	var t := UIStyle.label(["", "I · The Watch", "II · Strange Signals", "III · The Storm", "IV · The Visitor", "V · The Truth", "VI · The Last Light"][clampi(ch, 1, 6)], 44, UIStyle.INK, UIStyle.serif())
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t.offset_left = -600
	t.offset_right = 600
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -220
	bar.offset_right = 220
	bar.offset_top = -120
	bar.offset_bottom = -112
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.AMBER
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bar.add_theme_stylebox_override("background", bg)
	root.add_child(bar)
	for p in PRELOAD:
		ResourceLoader.load_threaded_request(p)
	while true:
		var total := 0.0
		var done := true
		for p in PRELOAD:
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(p, prog)
			total += 1.0 if st == ResourceLoader.THREAD_LOAD_LOADED else (float(prog[0]) if prog.size() > 0 else 0.0)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				done = false
		bar.value = total / PRELOAD.size() * 100.0
		if done:
			break
		await get_tree().process_frame
	for p in PRELOAD:
		ResourceLoader.load_threaded_get(p)      # now cached for the game's load()
	start_game("", true, save)
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		if _loading:
			_loading.queue_free()
			_loading = null)


func start_game(bot_mode: String, story := true, save: Dictionary = {}) -> void:
	for n in [menu_bg, menu]:
		if n and is_instance_valid(n):
			n.queue_free()
	menu_bg = null
	menu = null
	if game and is_instance_valid(game):
		game.queue_free()
	game = GAME.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	if bot_mode == "" and GameState.user_args.has("bot"):
		bot_mode = GameState.user_args["bot"]
	if GameState.user_args.get("mode", "story") == "watch":
		story = false
	game.start(GameState.next_seed(), bot_mode, false, story, save)
	game.finished.connect(_on_finished)
	game.quit_to_menu.connect(func():
		if game.story_mode and game.can_save() and game.bot_mode == "":
			SaveSystem.write("auto", game.save_dict())
		show_menu())
	game.campaign_over.connect(_on_campaign_over)


func _on_finished(stats: Dictionary) -> void:
	if stats.has("restart"):
		start_game("", game.story_mode if game else true)
		return
	var best := GameState.record_result(stats)
	if game:
		game.show_end(stats, best)


func _on_campaign_over(_ending: Dictionary) -> void:
	await get_tree().create_timer(4.0).timeout
	_open_credits(true)


# ------------------------------------------------------------------ panels

func _panel(title: String, w := 980, h := 760) -> VBoxContainer:
	_close_panel()
	var layer: CanvasLayer = menu
	if layer == null:
		layer = CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(0.94))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -w / 2
	panel.offset_right = w / 2
	panel.offset_top = -h / 2
	panel.offset_bottom = h / 2
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIStyle.label(title, 40, UIStyle.AMBER, UIStyle.serif())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UIStyle.button("Back")
	close.custom_minimum_size = Vector2(140, 44)
	close.pressed.connect(_close_panel)
	head.add_child(close)
	return v


func _close_panel() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null


func _confirm(text: String, yes: Callable) -> void:
	var v := _panel("Are you sure?", 760, 300)
	var l := UIStyle.label(text, 24, UIStyle.INK, UIStyle.serif())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := HBoxContainer.new()
	v.add_child(h)
	var y := UIStyle.button("Yes")
	y.pressed.connect(func():
		_close_panel()
		yes.call())
	h.add_child(y)
	var n := UIStyle.button("No")
	n.pressed.connect(_close_panel)
	h.add_child(n)


func _open_load() -> void:
	var v := _panel("Load game")
	for slot in SaveSystem.SLOTS:
		var row := HBoxContainer.new()
		v.add_child(row)
		var b := UIStyle.button(("Autosave" if slot == "auto" else "Slot " + slot) + "    " + SaveSystem.summary(slot))
		b.custom_minimum_size = Vector2(820, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = not SaveSystem.exists(slot)
		b.pressed.connect(func():
			_close_panel()
			load_slot(slot))
		row.add_child(b)
		if SaveSystem.exists(slot) and slot != "auto":
			var del := UIStyle.button("Delete")
			del.custom_minimum_size = Vector2(110, 56)
			del.pressed.connect(func(): _confirm("Delete save slot %s?" % slot, func():
				SaveSystem.delete(slot)
				_open_load()))
			row.add_child(del)


func _open_credits(ending := false) -> void:
	if ending:
		_clear()
		menu = CanvasLayer.new()
		add_child(menu)
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.015, 0.025)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu.add_child(bg)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var v := _panel("THE LAST LIGHT", 1000, 820)
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.custom_minimum_size = Vector2(900, 640)
	txt.add_theme_font_override("normal_font", UIStyle.serif())
	txt.add_theme_font_size_override("normal_font_size", 21)
	txt.text = FileAccess.get_file_as_string("res://data/credits.txt")
	v.add_child(txt)
	if ending:
		var b := UIStyle.button("Return to the title")
		b.pressed.connect(show_menu)
		v.add_child(b)


func _open_options() -> void:
	var v := _panel("Options", 1100, 860)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(1040, 720)
	tabs.add_theme_font_override("font", UIStyle.serif())
	tabs.add_theme_font_size_override("font_size", 20)
	v.add_child(tabs)
	var gfx := _tab(tabs, "Graphics")
	_opt_choice(gfx, "Window mode", "window_mode", [["Windowed", 0], ["Fullscreen", 3], ["Exclusive fullscreen", 4]])
	_opt_choice(gfx, "Resolution (windowed)", "resolution", [["1280×720", "1280x720"], ["1600×900", "1600x900"], ["1920×1080", "1920x1080"], ["2560×1440", "2560x1440"]])
	_opt_choice(gfx, "Quality", "quality", [["Low", 0], ["Medium", 1], ["High", 2]], "Medium targets 60 fps (default). High adds more shadowed lamps and 2x MSAA for quality at 30 fps or more. Applies when the next scene loads.")
	_opt_choice(gfx, "Render resolution", "render_res", [["Auto (1080p-equivalent, upscaled)", 0], ["Native (sharpest, slowest)", 1]], "On high-DPI screens Auto renders 3D at about 1920×1080 and keeps text sharp.")
	_opt_toggle(gfx, "VSync", "vsync")
	_opt_choice(gfx, "Frame-rate limit", "max_fps", [["Unlimited", 0], ["30", 30], ["60", 60], ["120", 120]])
	_opt_slider(gfx, "Field of view", "fov", 60.0, 90.0, 1.0)
	_opt_slider(gfx, "Brightness", "brightness", 0.6, 1.6, 0.05)
	var au := _tab(tabs, "Audio")
	for k in [["Master", "vol_master"], ["Music", "vol_music"], ["Sound effects", "vol_sfx"], ["Dialogue & radio", "vol_dialogue"], ["Ambience", "vol_ambient"]]:
		_opt_slider(au, k[0], k[1], 0.0, 1.0, 0.05)
	var ct := _tab(tabs, "Controls")
	_opt_slider(ct, "Mouse sensitivity", "mouse_sens", 0.3, 2.5, 0.05)
	_opt_toggle(ct, "Invert Y axis", "invert_y")
	_opt_toggle(ct, "Hold E to crank the generator (off: press once to crank)", "hold_to_crank")
	ct.add_child(UIStyle.label("Key bindings", 22, UIStyle.AMBER, UIStyle.serif()))
	for b in [["Walk", "W A S D / arrows"], ["Look", "Mouse"], ["Use / talk / advance", "E · left click · Space"], ["Choose a reply", "1 – 4"],
			["Walk faster", "Shift"], ["Station log", "L"], ["Step back / pause", "Esc · right click"], ["Turn handwheel (console)", "A / D"],
			["Radio: next vessel / send", "Tab / 1 – 6"], ["Document transcription", "T"], ["Fullscreen", "F11"]]:
		var row := HBoxContainer.new()
		var a := UIStyle.label(b[0], 19)
		a.custom_minimum_size = Vector2(420, 0)
		row.add_child(a)
		row.add_child(UIStyle.label(b[1], 19, UIStyle.DIM))
		ct.add_child(row)
	var ac := _tab(tabs, "Accessibility")
	_opt_toggle(ac, "Show ship radio chatter subtitles (story dialogue always shows)", "subtitles")
	_opt_slider(ac, "Subtitle & dialogue size", "subtitle_size", 0.8, 1.5, 0.05)
	_opt_slider(ac, "Text speed (characters / s)", "text_speed", 15.0, 120.0, 1.0)
	_opt_toggle(ac, "Reduce flashing (lightning)", "reduce_flashing")


func _tab(tabs: TabContainer, name_: String) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.name = name_
	tabs.add_child(s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	return v


func _row(parent: Control, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UIStyle.label(label, 20)
	l.custom_minimum_size = Vector2(460, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	parent.add_child(h)
	return h


func _opt_choice(parent: Control, label: String, key: String, items: Array, note := "") -> void:
	var h := _row(parent, label)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(320, 40)
	for i in items.size():
		ob.add_item(items[i][0], i)
		if items[i][1] == Settings.v[key]:
			ob.select(i)
	ob.item_selected.connect(func(i): Settings.set_value(key, items[i][1]))
	h.add_child(ob)
	if note != "":
		parent.add_child(UIStyle.label("      " + note, 15, UIStyle.DIM))


func _opt_toggle(parent: Control, label: String, key: String) -> void:
	var h := _row(parent, label)
	var cb := CheckButton.new()
	cb.button_pressed = Settings.v[key]
	cb.toggled.connect(func(on): Settings.set_value(key, on))
	h.add_child(cb)


func _opt_slider(parent: Control, label: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := _row(parent, label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.v[key])
	s.custom_minimum_size = Vector2(360, 30)
	var val := UIStyle.label("%.2f" % s.value, 18, UIStyle.DIM)
	s.value_changed.connect(func(x):
		val.text = "%.2f" % x
		Settings.set_value(key, x))
	h.add_child(s)
	h.add_child(val)
