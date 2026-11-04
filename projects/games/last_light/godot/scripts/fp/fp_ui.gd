extends CanvasLayer
## Screen-space UI for the keeper game. The room is the main interface; this layer only carries
## the crosshair, prompts, radio subtitles, brief notices, the radio command panel, the logbook,
## and pause / end screens.

signal command_requested(ship_id: int, cmd: String)
signal resume_requested
signal restart_requested
signal menu_requested

const COMMANDS := [["confirm", "Confirm position"], ["port", "Turn port 30°"], ["starboard", "Turn starboard 30°"],
	["slow", "Reduce / resume speed"], ["hold", "Hold position"], ["maintain", "Maintain course"]]

var sim: KeeperSim
var crosshair: Control
var prompt: Label
var subs: VBoxContainer
var notice: Label
var radio_panel: PanelContainer
var vessel_list: VBoxContainer
var radio_status: Label
var logbook: PanelContainer
var log_text: RichTextLabel
var pause_panel: Control
var end_panel: Control
var fade: ColorRect
var selected_ship := -1
var _notice_t := 0.0
var _sub_items: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func():
		crosshair.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.75))
		crosshair.draw_arc(Vector2.ZERO, 6.0, 0, TAU, 24, Color(0, 0, 0, 0.35), 1.0))
	root.add_child(crosshair)
	prompt = UIStyle.label("", 22, UIStyle.INK, UIStyle.serif())
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.offset_left = -500
	prompt.offset_right = 500
	prompt.offset_top = 40
	prompt.offset_bottom = 80
	root.add_child(prompt)
	subs = VBoxContainer.new()
	subs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subs.offset_left = 220
	subs.offset_right = -220
	subs.offset_top = -230
	subs.offset_bottom = -40
	subs.alignment = BoxContainer.ALIGNMENT_END
	subs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(subs)
	notice = UIStyle.label("", 24, UIStyle.AMBER, UIStyle.serif())
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.offset_left = -600
	notice.offset_right = 600
	notice.offset_top = 36
	notice.offset_bottom = 80
	root.add_child(notice)
	_build_radio(root)
	_build_logbook(root)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 2.0)


func _build_radio(root: Control) -> void:
	radio_panel = PanelContainer.new()
	radio_panel.add_theme_stylebox_override("panel", UIStyle.panel_box(0.82))
	radio_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	radio_panel.offset_left = -470
	radio_panel.offset_right = -40
	radio_panel.offset_top = -300
	radio_panel.offset_bottom = 300
	radio_panel.visible = false
	root.add_child(radio_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	radio_panel.add_child(v)
	v.add_child(UIStyle.label("VHF  ·  Channel 16", 26, UIStyle.AMBER, UIStyle.serif()))
	radio_status = UIStyle.label("", 16, UIStyle.DIM)
	v.add_child(radio_status)
	v.add_child(UIStyle.label("Vessel", 15, UIStyle.DIM))
	vessel_list = VBoxContainer.new()
	vessel_list.add_theme_constant_override("separation", 4)
	v.add_child(vessel_list)
	v.add_child(UIStyle.label("Instruction", 15, UIStyle.DIM))
	for i in COMMANDS.size():
		var c: Array = COMMANDS[i]
		var b := UIStyle.button("%d   %s" % [i + 1, c[1]])
		b.custom_minimum_size = Vector2(380, 40)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): _send(c[0]))
		v.add_child(b)
	v.add_child(UIStyle.label("Tab: next vessel · 1-6: send · the radar shows labelled vessels", 13, UIStyle.DIM))


func _build_logbook(root: Control) -> void:
	logbook = PanelContainer.new()
	var sb := UIStyle.panel_box(0.95)
	sb.bg_color = Color(0.86, 0.82, 0.72, 0.97)
	logbook.add_theme_stylebox_override("panel", sb)
	logbook.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	logbook.offset_left = -430
	logbook.offset_right = 430
	logbook.offset_top = -330
	logbook.offset_bottom = 330
	logbook.visible = false
	root.add_child(logbook)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = false
	log_text.add_theme_font_override("normal_font", UIStyle.serif())
	log_text.add_theme_font_override("bold_font", UIStyle.serif())
	log_text.add_theme_font_size_override("normal_font_size", 20)
	log_text.add_theme_font_size_override("bold_font_size", 24)
	log_text.add_theme_color_override("default_color", Color(0.15, 0.12, 0.1))
	logbook.add_child(log_text)


# ------------------------------------------------------------------ API

func set_prompt(text: String) -> void:
	prompt.text = text


func set_focus(id: String) -> void:
	crosshair.visible = id == ""
	radio_panel.visible = id == "radio"
	if id == "radio":
		_refresh_vessels()


func show_notice(text: String, seconds := 4.0) -> void:
	notice.text = text
	_notice_t = seconds


func toggle_logbook() -> bool:
	logbook.visible = not logbook.visible
	if logbook.visible:
		var s := "[b]Keeper's log — North Point Light[/b]\n\n"
		for e in sim.logbook_entries():
			s += "[b]%s[/b]\n%s\n\n" % [e["title"], e["text"]]
		s += "[i]Press L or Esc to close.[/i]"
		log_text.text = s
	return logbook.visible


func add_subtitle(from: String, text: String, outgoing: bool) -> void:
	var l := UIStyle.label("", 22, UIStyle.INK if not outgoing else UIStyle.AMBER, UIStyle.serif())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = ("%s:  %s" % [from, text]) if from != "" else text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subs.add_child(l)
	_sub_items.append({"node": l, "age": 0.0, "life": 5.0 + text.length() * 0.045})
	while _sub_items.size() > 3:
		_sub_items[0]["node"].queue_free()
		_sub_items.remove_at(0)


func _send(cmd: String) -> void:
	if selected_ship < 0:
		show_notice("No vessel selected.", 2.0)
		return
	command_requested.emit(selected_ship, cmd)


func _refresh_vessels() -> void:
	for c in vessel_list.get_children():
		c.queue_free()
	var act := sim.active_ships()
	if act.is_empty():
		vessel_list.add_child(UIStyle.label("— no vessels on the channel —", 18, UIStyle.DIM))
		selected_ship = -1
		return
	if sim.find_ship(selected_ship) == null or not sim.find_ship(selected_ship).is_active():
		selected_ship = act[0].id
	for s in act:
		var state := "in the channel" if s.state == FleetShip.State.PILOTING else ("MAYDAY" if s.mayday_sent else ("holding" if s.hold else ""))
		var b := UIStyle.button(("▶ " if s.id == selected_ship else "   ") + s.name + ("   · " + state if state != "" else ""))
		b.custom_minimum_size = Vector2(380, 36)
		b.add_theme_font_size_override("font_size", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sid := s.id
		b.pressed.connect(func():
			selected_ship = sid
			_refresh_vessels())
		vessel_list.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if radio_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			var act := sim.active_ships()
			if not act.is_empty():
				var i := 0
				for j in act.size():
					if act[j].id == selected_ship:
						i = j
				selected_ship = act[(i + 1) % act.size()].id
				_refresh_vessels()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_send(COMMANDS[event.keycode - KEY_1][0])
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_body(delta)
	GameState.prof_add("ui", Time.get_ticks_usec() - _pt)


func _process_body(delta: float) -> void:
	_notice_t -= delta
	notice.modulate.a = clampf(_notice_t, 0.0, 1.0)
	for it in _sub_items:
		it["age"] += delta
		it["node"].modulate.a = clampf(it["life"] - it["age"], 0.0, 1.0)
	_sub_items = _sub_items.filter(func(it):
		if it["age"] > it["life"]:
			it["node"].queue_free()
			return false
		return true)
	if radio_panel.visible and sim:
		var st := "Transmitting…" if sim.tx_t > 0.0 else ("Ready" if sim.radio_on() else "NO POWER")
		radio_status.text = "%s   ·   battery %d%%" % [st, int(sim.battery)]
		if Engine.get_process_frames() % 30 == 0:
			_refresh_vessels()


# ------------------------------------------------------------------ pause / end

signal save_requested(slot: String)


func show_pause(on: bool, story := false) -> void:
	if on and pause_panel == null:
		var buttons: Array = [["Resume", func(): resume_requested.emit()]]
		if story:
			for slot in ["1", "2", "3"]:
				buttons.append(["Save to slot %s   ·   %s" % [slot, SaveSystem.summary(slot)], func(): save_requested.emit(slot)])
		else:
			buttons.append(["Keeper's log", func(): toggle_logbook()])
			buttons.append(["Restart the night", func(): restart_requested.emit()])
		buttons.append(["Main menu", func(): menu_requested.emit()])
		pause_panel = _modal("Paused", "", buttons)
	elif not on and pause_panel:
		pause_panel.queue_free()
		pause_panel = null


func show_end(stats: Dictionary, best: bool) -> void:
	var won: bool = stats["result"] == "won"
	var body := "Ships brought home   %d of %d\nShips lost   %d\nLight dark while ships at sea   %d s\nWatch kept until   %s\n\nScore   %d%s" % [
		stats["saved"], stats["ships_total"], stats["lost"], int(stats["dark_seconds"]), stats["clock"], stats["score"],
		"   (best this session)" if best else ""]
	end_panel = _modal("Dawn over North Point" if won else "The light failed them", body,
		[["Keep another watch", func(): restart_requested.emit()], ["Main menu", func(): menu_requested.emit()]])
	end_panel.modulate.a = 0.0
	create_tween().tween_property(end_panel, "modulate:a", 1.0, 2.5)


func _modal(title: String, body: String, buttons: Array) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(0.9))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var t := UIStyle.label(title, 56, UIStyle.AMBER, UIStyle.serif())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if body != "":
		var b := UIStyle.label(body, 24, UIStyle.INK, UIStyle.serif())
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
	var first: Button = null
	for pair in buttons:
		var btn := UIStyle.button(pair[0])
		btn.pressed.connect(pair[1])
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(btn)
		if first == null:
			first = btn
	add_child(root)
	first.grab_focus.call_deferred()
	return root
