extends Control
## Dialogue history (Stage 3A). Reads StoryState.history, whose entries were resolved when they were
## spoken (Speakers): the name is what the player was shown at the time, so a hidden identity is never
## spoiled here. Opened from the pause menu, H, or the pad's Back/View button; it only exists while the
## game is paused, so nothing types, advances or gets used underneath it. game_fp owns opening, closing
## and the mouse (refresh_mouse stays the only writer of the mouse mode).
## Scroll: the wheel, Up / Down / Page Up / Page Down / Home / End, the d-pad or the right stick.
## Close: H, Esc, pad B or Back, or a right click.

signal close_requested

var text: RichTextLabel
var title: Label
var footer: Label
var chapter_title_fn: Callable                # chapter number -> title ("Strange Signals")
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(0.94))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 160
	panel.offset_right = -160
	panel.offset_top = 70
	panel.offset_bottom = -70
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	title = UIStyle.label("Dialogue history", 34, UIStyle.AMBER, UIStyle.serif())
	v.add_child(title)
	text = UIStyle.rich(22)
	text.fit_content = false
	text.scroll_active = true
	text.scroll_following = false
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_STOP          # the wheel scrolls it natively
	text.selection_enabled = false
	text.add_theme_constant_override("line_separation", 6)
	v.add_child(text)
	footer = UIStyle.label("", 16, UIStyle.DIM, UIStyle.sans())
	v.add_child(footer)


## Fill from the history and show it scrolled to the latest line.
func open(history: Array) -> void:
	text.text = compose(history)
	footer.text = "Scroll: wheel, %s, or Up / Down        Close: %s" % [
		"right stick" if InputSetup.pad_active else "Page Up / Page Down",
		("B or View" if InputSetup.pad_active else "H, Esc or right click")]
	visible = true
	_to_end.call_deferred()


func close() -> void:
	visible = false


func _to_end() -> void:
	var sb := text.get_v_scroll_bar()
	sb.value = sb.max_value


## The history as BBCode: a header when the chapter changes, then clock · speaker · line. Thoughts are
## italic and nameless, sounds are captions, the keeper's replies are marked. Script brackets are escaped.
func compose(history: Array) -> String:
	if history.is_empty():
		return "[center][i]Nothing has been said yet tonight.[/i][/center]"
	var out := PackedStringArray()
	var ch := -1
	for e in history:
		if not (e is Dictionary):
			continue
		var c := int(e.get("chapter", 0))
		if c != ch and c > 0:
			ch = c
			var t: String = chapter_title_fn.call(c) if chapter_title_fn.is_valid() else ""
			out.append("\n[center][color=#ffb347]%s%s[/color][/center]" % [ROMAN[clampi(c, 0, 6)], ("  ·  " + t) if t != "" else ""])
		var clock := String(e.get("clock", ""))
		var stamp := "[color=#7d8690]%s[/color]   " % clock if clock != "" else ""
		var line := String(e.get("text", "")).replace("[", "[lb]")
		var lk := String(e.get("look", "thought" if String(e.get("speaker", "")) == "" else "person"))
		var name := String(e.get("name", "")).replace("[", "[lb]")
		if e.get("choice", false):
			out.append("%s[color=#ffb347]Callum ▸[/color]  %s" % [stamp, line])
		elif lk == "sound":
			out.append("%s[color=#c8b88c][lb] %s ][/color]" % [stamp, Speakers.caption_text(String(e.get("text", ""))).to_upper().replace("[", "[lb]")])
		elif lk == "thought" or name == "":
			out.append("%s[color=#cfc8b6][i]%s[/i][/color]" % [stamp, line])
		else:
			var col := "#8ef0a4" if lk == "radio" else "#e9c98a"
			out.append("%s[color=%s][b]%s[/b][/color]%s  %s" % [stamp, col, name, "  (radio)" if lk == "radio" else "", line])
	return "\n".join(out)


func _scroll(px: float) -> void:
	var sb := text.get_v_scroll_bar()
	sb.value = clampf(sb.value + px, 0.0, sb.max_value)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("history") or event.is_action_pressed("pause") or event.is_action_pressed("back") \
			or event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		close_requested.emit()
	elif event.is_action_pressed("ui_up", true):
		_scroll(-60.0)
	elif event.is_action_pressed("ui_down", true):
		_scroll(60.0)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PAGEUP:
				_scroll(-text.size.y * 0.85)
			KEY_PAGEDOWN:
				_scroll(text.size.y * 0.85)
			KEY_HOME:
				_scroll(-1e9)
			KEY_END:
				_scroll(1e9)
			_:
				handled = false
	else:
		handled = event is InputEventKey or event is InputEventJoypadButton   # nothing else reacts while it's open
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		var st := InputSetup.stick("look_left", "look_right", "look_up", "look_down")
		if absf(st.y) > 0.0:
			_scroll(st.y * 1400.0 * delta)
