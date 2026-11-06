extends CanvasLayer
## Screen-space UI for the keeper game. The room is the main interface; this layer only carries
## the crosshair, prompts, radio subtitles, brief notices, the radio command panel, the logbook,
## and pause / end screens.

signal command_requested(ship_id: int, cmd: String)
signal resume_requested
signal restart_requested
signal menu_requested
signal backlog_requested                   # Stage 3A: "Dialogue history" in the pause menu, or H / View while paused
signal call_requested(call_id: String)     # Stage 3B: an optional radio call ("Call Kittiwake")

const COMMANDS := [["confirm", "Confirm position"], ["port", "Turn port 30°"], ["starboard", "Turn starboard 30°"],
	["slow", "Reduce / resume speed"], ["hold", "Hold position"], ["maintain", "Maintain course"]]

const XH_VALID := Color(1.0, 0.96, 0.88, 0.85)      # warm white ring: "this does something"
const XH_UNAVAIL := Color(0.72, 0.72, 0.70, 0.55)   # grey dashed ring: "not now"
const XH_SHADE := Color(0.0, 0.0, 0.0, 0.28)        # keeps the ring readable on the cream walls
const SUB_INK := Color(0.86, 0.82, 0.72, 0.78)      # readings, reasons and help: dimmed parchment, same family as INK

var sim: KeeperSim
var crosshair: Control
var tip: VBoxContainer          # the prompt and its sub-line, under the crosshair or beside the cursor
var prompt: Label
var prompt_sub: Label
var help: Label                 # device views: how to step back / turn the handwheel
var prompt_info := {}           # last player.prompt_changed info
var _xh_ring := 0.0             # 0 = rest dot, 1 = ring
var _xh_grey := 0.0             # 0 = valid colour, 1 = unavailable (dashed grey)
var _xh_pulse := 0.0            # input received
var _notice_last := {}          # text -> ticks_msec it was last shown (refusals are not repeated)
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
var _vessel_btns := {}          # ship id -> Button (kept across refreshes)
var _no_vessels: Label
var tab_tip: Label
var radio_legend: Label
var number_keys_taken_fn: Callable          # true while dialogue replies own the number keys
var cursor_fn: Callable                     # player.cursor_pos: the device-view cursor (mouse or virtual)
var reply_root_fn: Callable                 # dialogue reply buttons' container (pad cursor can press them)
var optional_calls_fn: Callable             # Stage 3B: director.available_calls() -> [{id, label, ...}]
var calls_box: VBoxContainer                # "Call a station": shown only while a call is on offer
var calls_list: VBoxContainer
var _call_btns := {}                        # call id -> Button (keyed, like the vessel list)
var _notice_t := 0.0
var _notice_shown := 0.0                    # how long the current notice has been up (item 26)
var _notice_queue: Array = []               # [[text, seconds]] waiting behind it
const NOTICE_MIN_S := 2.5
var _sub_items: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	tip = VBoxContainer.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_constant_override("separation", 2)
	root.add_child(tip)
	prompt = UIStyle.label("", 22, UIStyle.INK, UIStyle.serif())
	tip.add_child(prompt)
	prompt_sub = UIStyle.label("", 18, SUB_INK, UIStyle.serif())
	tip.add_child(prompt_sub)
	_tip_free_walk()
	help = UIStyle.label("", 17, SUB_INK, UIStyle.serif())
	for l in [prompt, prompt_sub, help]:     # a soft dark edge: prompts sit over bright gauge dials
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.55))
		l.add_theme_constant_override("outline_size", 5)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_left = -600
	help.offset_right = 600
	help.offset_top = -40
	help.offset_bottom = -14
	root.add_child(help)
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
	# Stage 3A: larger text makes the panel wider; it grows to the LEFT (it ran off the right edge at 1.5)
	radio_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	radio_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	radio_panel.visible = false
	root.add_child(radio_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	radio_panel.add_child(v)
	v.add_child(UIStyle.label("VHF  ·  Channel 16", 26, UIStyle.AMBER, UIStyle.serif()))
	radio_status = UIStyle.label("", 16, UIStyle.DIM)
	radio_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(radio_status)
	var vh := HBoxContainer.new()
	vh.add_child(UIStyle.label("Vessel", 15, UIStyle.DIM))
	tab_tip = UIStyle.label("      Tab  ·  next vessel", 15, UIStyle.AMBER)   # one-time tip (Settings.tip_wanted)
	tab_tip.visible = false
	vh.add_child(tab_tip)
	v.add_child(vh)
	vessel_list = VBoxContainer.new()
	vessel_list.add_theme_constant_override("separation", 4)
	v.add_child(vessel_list)
	_no_vessels = UIStyle.label("— no vessels on the channel —", 18, UIStyle.DIM)
	vessel_list.add_child(_no_vessels)
	calls_box = VBoxContainer.new()
	calls_box.add_theme_constant_override("separation", 4)
	calls_box.visible = false
	v.add_child(calls_box)
	calls_box.add_child(UIStyle.label("Call a station", 15, UIStyle.DIM))
	calls_list = VBoxContainer.new()
	calls_list.add_theme_constant_override("separation", 4)
	calls_box.add_child(calls_list)
	v.add_child(UIStyle.label("Instruction", 15, UIStyle.DIM))
	for i in COMMANDS.size():
		var c: Array = COMMANDS[i]
		var b := _panel_button("%d   %s" % [i + 1, c[1]], 40, 20)
		b.pressed.connect(func(): _send(c[0]))
		v.add_child(b)
	radio_legend = UIStyle.label("", 13, UIStyle.DIM)    # text follows keyboard or pad (_refresh_vessels)
	radio_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART    # wraps instead of widening the panel
	v.add_child(radio_legend)


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
	log_text.set_meta("ui_bold", 24)
	UIStyle.track(log_text, 20)
	log_text.add_theme_color_override("default_color", Color(0.15, 0.12, 0.1))
	logbook.add_child(log_text)


# ------------------------------------------------------------------ API

## player.prompt_changed: {state, key, text, sub, in_view, help}. Free walk: under the crosshair, centred.
## Device views: beside the cursor, and the step-back help sits at the bottom of the screen.
func set_prompt(info: Dictionary) -> void:
	var was_view: bool = prompt_info.get("in_view", false)
	prompt_info = info
	var t: String = info.get("text", "")
	var k: String = info.get("key", "")
	prompt.text = ("%s  %s" % [k, t]) if k != "" and t != "" else t
	prompt.modulate.a = 1.0 if info.get("state", "") != "unavailable" else 0.62
	prompt_sub.text = info.get("sub", "")
	prompt_sub.visible = prompt_sub.text != ""
	help.text = info.get("help", "")
	var in_view: bool = info.get("in_view", false)
	if in_view != was_view:
		if in_view:
			_tip_in_view()
		else:
			_tip_free_walk()


func clear_prompt() -> void:
	set_prompt({})


## The crosshair acknowledges a press (accepted: a brief bloom; refused: the grey ring flickers).
func pulse(_accepted: bool) -> void:
	_xh_pulse = 1.0


func set_focus(id: String) -> void:
	radio_panel.visible = id == "radio"
	if id == "radio":
		_refresh_vessels()


## Item 26: a notice is up at least NOTICE_MIN_S before the next one replaces it; later ones queue
## (in order, no duplicates) instead of overwriting it unread.
func show_notice(text: String, seconds := 4.0) -> void:
	if _notice_t > 0.0 and notice.text != text and _notice_shown < NOTICE_MIN_S:
		for q in _notice_queue:
			if q[0] == text:
				return
		if _notice_queue.size() < 4:
			_notice_queue.append([text, seconds])
		return
	notice.text = text
	_notice_t = seconds
	_notice_shown = 0.0


## A notice the player triggers by pressing (refusals, consequences): the same text is not repeated
## within `cooldown` seconds, so hammering E on a shut-valve START shows the reason once.
func show_notice_once(text: String, seconds := 3.0, cooldown := 3.0) -> void:
	var now := Time.get_ticks_msec()
	if _notice_last.has(text) and now - int(_notice_last[text]) < int(cooldown * 1000.0):
		return
	_notice_last[text] = now
	show_notice(text, seconds)


func _tip_free_walk() -> void:
	tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tip.offset_left = -500
	tip.offset_right = 500
	tip.offset_top = 28
	tip.offset_bottom = 90
	for l in [prompt, prompt_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _tip_in_view() -> void:
	tip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for l in [prompt, prompt_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place_tip()


## Device views: the prompt sits just right of and below the cursor, flipped to the left / above near
## the screen edges so it never runs off.
func _place_tip() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := _cursor()
	var sz := tip.get_combined_minimum_size()
	var p := m + Vector2(26, 14)
	if p.x + sz.x > vp.x - 16:
		p.x = m.x - 26 - sz.x
	if p.y + sz.y > vp.y - 50:
		p.y = m.y - 14 - sz.y
	tip.position = p
	tip.size = sz


## Where the crosshair is drawn: the screen centre in free walk, the cursor in device views.
func _cursor() -> Vector2:
	if prompt_info.get("in_view", false):
		return cursor_fn.call() if cursor_fn.is_valid() else get_viewport().get_mouse_position()
	return get_viewport().get_visible_rect().size * 0.5


func _draw_crosshair() -> void:
	var c := _cursor()
	var in_view: bool = prompt_info.get("in_view", false)
	var col := XH_VALID.lerp(XH_UNAVAIL, _xh_grey)
	# rest dot, fading out as the ring opens. In device views only for the pad cursor: the mouse has the
	# OS pointer, the pad has nothing else to steer by (seen in the s2c_pad capture)
	if not in_view or InputSetup.pad_active:
		var a := (1.0 - _xh_ring) * 0.55
		if a > 0.01:
			crosshair.draw_circle(c, 2.6, Color(0, 0, 0, a * 0.5))
			crosshair.draw_circle(c, 2.0, Color(1, 1, 1, a))
	if _xh_ring < 0.02:
		return
	var r := lerpf(3.0, 9.0, _xh_ring) + 2.5 * _xh_pulse
	var alpha := _xh_ring * col.a
	if _xh_grey < 0.5:
		crosshair.draw_arc(c, r, 0.0, TAU, 40, Color(XH_SHADE, XH_SHADE.a * _xh_ring), 3.2, true)
		crosshair.draw_arc(c, r, 0.0, TAU, 40, Color(col, alpha), 1.5, true)
	else:
		for i in 10:                           # dashed: ten short arcs
			var a0 := TAU * i / 10.0
			crosshair.draw_arc(c, r, a0, a0 + TAU / 20.0, 6, Color(XH_SHADE, XH_SHADE.a * _xh_ring), 3.2, true)
			crosshair.draw_arc(c, r, a0, a0 + TAU / 20.0, 6, Color(col, alpha), 1.5, true)


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


## Item 26: a story line is starting: fade the sim radio subtitles out quickly so two voices are never
## drawn over each other (each line is already in the transcript).
func fade_subtitles() -> void:
	for it in _sub_items:
		it["age"] = maxf(it["age"], it["life"] - 0.4)


## Next (+1) or previous (-1) vessel on the channel: Tab, and the pad's RB / LB in the radio view.
func cycle_vessel(dir: int) -> void:
	var act := sim.active_ships()
	if act.is_empty():
		return
	var i := 0
	for j in act.size():
		if act[j].id == selected_ship:
			i = j
	selected_ship = act[posmod(i + dir, act.size())].id
	Settings.tip_used("tab")
	_refresh_vessels()


## The pad cursor pressed at `pos` (viewport px): press the on-screen button under it, if any.
## Covers the radio panel and dialogue replies; returns false when the press belongs to the room.
func click_at(pos: Vector2) -> bool:
	var roots: Array = [radio_panel]
	if reply_root_fn.is_valid():
		roots.append(reply_root_fn.call())
	for r in roots:
		if r == null or not (r as Control).is_visible_in_tree():
			continue
		for b in (r as Node).find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled and btn.get_global_rect().has_point(pos):
				btn.pressed.emit()
				return true
	return false


func _send(cmd: String) -> void:
	if selected_ship < 0:
		show_notice("No vessel selected.", 2.0)
		return
	command_requested.emit(selected_ship, cmd)


## Radio-panel buttons are clicked with the mouse: they must not keep keyboard focus afterwards, or
## Space / Enter (ui_accept) would press the last order again (Stage 2B, confirmed by regress R6).
## Stage 2C gives them focus only while a gamepad is driving the panel.
func _panel_button(text: String, h: int, font_size: int) -> Button:
	var b := UIStyle.button(text)
	b.custom_minimum_size = Vector2(380, h)
	UIStyle.track(b, font_size)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Keyed update (Stage 2B): one button per ship id, created when a ship joins the channel and removed when
## it leaves; otherwise only its text changes. Rebuilding every 30 frames dropped clicks whose press and
## release straddled a rebuild and threw away hover (regress R6).
func _refresh_vessels() -> void:
	var act := sim.active_ships()
	var ids := {}
	for s in act:
		ids[s.id] = true
	for sid in _vessel_btns.keys():
		if not ids.has(sid):
			var old: Button = _vessel_btns[sid]
			vessel_list.remove_child(old)
			old.queue_free()
			_vessel_btns.erase(sid)
	_refresh_calls()
	_no_vessels.visible = act.is_empty()
	tab_tip.visible = act.size() >= 2 and Settings.tip_wanted("tab")
	tab_tip.text = "      %s  ·  next vessel" % InputSetup.glyph("next_vessel")
	radio_legend.text = ("RB / LB: next vessel · point and press %s to send · the radar shows labelled vessels" % InputSetup.glyph("interact")) \
		if InputSetup.pad_active else "Tab: next vessel · 1-6: send · the radar shows labelled vessels"
	if act.is_empty():
		selected_ship = -1
		return
	if not ids.has(selected_ship):
		selected_ship = act[0].id
	for i in act.size():
		var s = act[i]
		var b: Button = _vessel_btns.get(s.id)
		if b == null:
			b = _panel_button("", 36, 19)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var sid: int = s.id
			b.pressed.connect(func():
				selected_ship = sid
				Settings.tip_used("tab")       # choosing a vessel directly also shows the player knows the list
				_refresh_vessels())
			vessel_list.add_child(b)
			_vessel_btns[s.id] = b
		var state := "in the channel" if s.state == FleetShip.State.PILOTING else ("MAYDAY" if s.mayday_sent else ("holding" if s.hold else ""))
		var t: String = ("▶ " if s.id == selected_ship else "   ") + s.name + ("   · " + state if state != "" else "")
		if b.text != t:
			b.text = t
		if b.get_index() != i + 1:             # child 0 is the "no vessels" label
			vessel_list.move_child(b, i + 1)


## Optional calls (Stage 3B): one button per call on offer, removed once it has been made or its window
## has closed. Greyed out with no power (the set is dead).
func _refresh_calls() -> void:
	var calls: Array = optional_calls_fn.call() if optional_calls_fn.is_valid() else []
	var ids := {}
	for c in calls:
		ids[String(c["id"])] = c
	for cid in _call_btns.keys():
		if not ids.has(cid):
			var old: Button = _call_btns[cid]
			calls_list.remove_child(old)
			old.queue_free()
			_call_btns.erase(cid)
	for cid in ids.keys():
		var b: Button = _call_btns.get(cid)
		if b == null:
			b = _panel_button("", 36, 19)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id_: String = cid
			b.pressed.connect(func(): call_requested.emit(id_))
			calls_list.add_child(b)
			_call_btns[cid] = b
		var t := "   " + String(ids[cid].get("label", cid))
		if b.text != t:
			b.text = t
		b.disabled = sim != null and not sim.radio_on()
	calls_box.visible = not _call_btns.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:                    # this layer processes during pause for its menu: no orders
		if pause_panel and pause_panel.visible and _story_pause and event.is_action_pressed("history"):
			backlog_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if pause_panel and pause_panel.visible and event.is_action_pressed("back"):
			resume_requested.emit()          # pad B resumes, like Start (Stage 2C)
			get_viewport().set_input_as_handled()
		return
	if radio_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			cycle_vessel(1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			if number_keys_taken_fn.is_valid() and number_keys_taken_fn.call():
				return                       # leave it to the dialogue replies
			_send(COMMANDS[event.physical_keycode - KEY_1][0])
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_body(delta)
	GameState.prof_add("ui", Time.get_ticks_usec() - _pt)


func _process_body(delta: float) -> void:
	var xs: String = prompt_info.get("state", "none")
	_xh_ring = move_toward(_xh_ring, 0.0 if xs == "none" else 1.0, delta / 0.09)
	_xh_grey = move_toward(_xh_grey, 1.0 if xs == "unavailable" else 0.0, delta / 0.09)
	_xh_pulse = maxf(0.0, _xh_pulse - delta * 6.0)
	crosshair.queue_redraw()
	if prompt_info.get("in_view", false):
		_place_tip()
	_notice_t -= delta
	_notice_shown += delta
	if not _notice_queue.is_empty() and (_notice_t <= 0.0 or _notice_shown >= NOTICE_MIN_S):
		var q: Array = _notice_queue.pop_front()
		notice.text = q[0]
		_notice_t = q[1]
		_notice_shown = 0.0
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


var _story_pause := false


func show_pause(on: bool, story := false) -> void:
	_story_pause = story
	if on and pause_panel == null:
		var buttons: Array = [["Resume", func(): resume_requested.emit()]]
		if story:
			buttons.append(["Dialogue history   ·   %s" % InputSetup.glyph("history"), func(): backlog_requested.emit()])
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


## Give the pause menu's first button the focus again (after the dialogue history closes over it).
func focus_pause() -> void:
	if pause_panel == null:
		return
	for b in pause_panel.find_children("*", "Button", true, false):
		(b as Button).grab_focus()
		return


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
