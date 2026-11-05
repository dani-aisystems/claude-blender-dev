extends Control
## Cinematic dialogue presentation for THE LAST LIGHT.
##  radio   : compact panel lower-left, identity card (call sign / vessel / station), signal meter,
##            typewriter text with punctuation pauses, squelch on each line. Choices only unlock
##            at the radio (the keeper has to pick up the handset).
##  person  : low centred subtitles, speaker name, nothing covering the scene (the door scene).
##  thought : italic low subtitles, no name.
## Input: E / Space / left click = finish the line, then (after a short guard) advance. 1-4 = choose.

signal advance_requested
signal choice_made(index: int)
signal blip(kind: String)                  # audio hooks: "char", "squelch", "open", "close"

const CARDS := {
	"MORAG": ["STORNOWAY COASTGUARD", "MRSC · Radio officer M. Fraser", "station"],
	"RORY": ["KITTIWAKE  SY 37", "Fishing · skipper R. Bain", "fishing"],
	"HECTOR": ["GANNET  SY 112", "Schooner · master H. Macleod", "schooner"],
	"CORRIE": ["CORRIE MAY  BRD 9", "Fishing", "fishing"],
	"LOWESTOFT": ["LOWESTOFT STAR  LT 401", "Schooner", "schooner"],
	"ELSPETH": ["IONA STAR  ·  GMXQ", "Coaster · 1st mate E. Ross", "steamer"],
	"MARY ELLEN": ["MARY ELLEN  SY 214", "Registry: LOST 15.11.1953", "fishing"],
	"VISITOR": ["", "", ""],
	"ROSS": ["MARY ELLEN  SY 214", "A. Ross, master", "fishing"],
	"CALLUM": ["NORTH POINT LIGHT", "C. Mackay, principal keeper", "station"],
}
const NAMES := {"MORAG": "Morag Fraser", "RORY": "Rory Bain", "HECTOR": "Hector Macleod", "CORRIE": "Corrie May",
	"LOWESTOFT": "Lowestoft Star", "ELSPETH": "Elspeth Ross", "MARY ELLEN": "Mary Ellen", "VISITOR": "The man at the door",
	"ROSS": "Alasdair Ross", "CALLUM": "Callum"}

var mode := "radio"                         # the conversation's mode (radio replies are gated on it)
var line_look := "radio"                        # how the current line is drawn (radio / person / thought)
var speed_cps := 42.0                       # Settings: typewriter speed
var text_scale := 1.0                       # Settings: subtitle size
var at_radio_fn: Callable                   # returns true when the player is at the handset
var mouse_restore_fn: Callable              # game decides the mouse mode once choices close
var radio_panel: PanelContainer
var card: Control
var r_name: Label
var r_text: RichTextLabel
var r_hint: Label
var sub_box: VBoxContainer
var s_name: Label
var s_text: RichTextLabel
var choice_box: VBoxContainer
var _full := ""
var _shown := 0.0
var _speaker := ""
var _pause := 0.0
var _done_t := 0.0
var _choices: Array = []
var _active := false
var _t := 0.0
var _freed_mouse := false                   # we made the cursor visible for the choices


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- radio panel ---
	radio_panel = PanelContainer.new()
	var sb := UIStyle.panel_box(0.8)
	sb.bg_color = Color(0.03, 0.045, 0.05, 0.86)
	sb.border_color = Color(0.35, 0.55, 0.42, 0.45)
	radio_panel.add_theme_stylebox_override("panel", sb)
	radio_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	radio_panel.offset_left = 48
	radio_panel.offset_right = 48 + 820
	radio_panel.offset_top = -270
	radio_panel.offset_bottom = -48
	radio_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN   # long lines / large text grow UP, never off-screen
	radio_panel.visible = false
	add_child(radio_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	radio_panel.add_child(h)
	card = Control.new()
	card.custom_minimum_size = Vector2(170, 190)
	card.draw.connect(_draw_card)
	h.add_child(card)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	r_name = UIStyle.label("", 20, Color(0.55, 0.95, 0.65), UIStyle.sans())
	v.add_child(r_name)
	r_text = _rich(25)
	v.add_child(r_text)
	r_hint = UIStyle.label("", 15, UIStyle.DIM)
	v.add_child(r_hint)
	# --- subtitles (person / thought) ---
	sub_box = VBoxContainer.new()
	sub_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sub_box.offset_left = -640
	sub_box.offset_right = 640
	sub_box.offset_top = -210
	sub_box.offset_bottom = -60
	sub_box.alignment = BoxContainer.ALIGNMENT_END
	sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_box.visible = false
	add_child(sub_box)
	s_name = UIStyle.label("", 18, UIStyle.AMBER, UIStyle.sans())
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_box.add_child(s_name)
	s_text = _rich(28)
	s_text.custom_minimum_size = Vector2(1280, 0)
	sub_box.add_child(s_text)
	# --- choices ---
	# Lower-left, stacked directly above whatever text is showing (radio panel or subtitles) and growing
	# upwards (_layout_choices), so replies sit next to the line they answer at any text size and never
	# cover the radio command panel (right edge) or the subtitles.
	choice_box = VBoxContainer.new()
	choice_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	choice_box.offset_left = 48
	choice_box.offset_right = 48 + 700
	choice_box.offset_bottom = -270 - 14
	choice_box.offset_top = -270 - 14 - 236
	choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choice_box.alignment = BoxContainer.ALIGNMENT_END
	choice_box.add_theme_constant_override("separation", 8)
	add_child(choice_box)


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", UIStyle.serif())
	r.add_theme_font_override("italics_font", UIStyle.serif())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", UIStyle.INK)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func apply_settings(cps: float, scale: float) -> void:
	speed_cps = cps
	text_scale = scale
	r_text.add_theme_font_size_override("normal_font_size", int(25 * scale))
	r_text.add_theme_font_size_override("italics_font_size", int(25 * scale))
	s_text.add_theme_font_size_override("normal_font_size", int(28 * scale))
	s_text.add_theme_font_size_override("italics_font_size", int(28 * scale))


# ------------------------------------------------------------------ API

func show_line(item: Dictionary) -> void:
	_active = true
	_clear_choices()
	mode = item["mode"]
	_speaker = item["speaker"]
	# narration ("~") inside a radio conversation is the keeper thinking, not a transmission: drawn as a
	# thought subtitle, never as a radio call with a blank identity card (Stage 1 s1f)
	line_look = "thought" if mode == "radio" and _speaker == "" else mode
	_full = item["text"]
	_shown = 0.0
	_pause = 0.15
	_done_t = 0.0
	var radio := line_look == "radio"
	radio_panel.visible = radio
	sub_box.visible = not radio
	if radio:
		r_name.text = NAMES.get(_speaker, _speaker.capitalize()) if _speaker != "" else ""
		r_hint.text = ""
		card.queue_redraw()
		blip.emit("squelch")
	else:
		s_name.text = "" if _speaker == "" or line_look == "thought" else NAMES.get(_speaker, _speaker.capitalize())
	_render()


func show_choices(item: Dictionary) -> void:
	_choices = item["choices"]
	_refresh_choices()


func close() -> void:
	_active = false
	radio_panel.visible = false
	sub_box.visible = false
	_choices = []
	_clear_choices()
	_restore_mouse()
	blip.emit("close")


func is_active() -> bool:
	return _active


func has_open_choices() -> bool:
	return not _choices.is_empty() and choice_box.get_child_count() > 0


# ------------------------------------------------------------------ internals

func _refresh_choices() -> void:
	_clear_choices()
	if _choices.is_empty():
		return
	var gated: bool = mode == "radio" and at_radio_fn.is_valid() and not at_radio_fn.call()
	if gated:
		r_hint.text = "▸ Pick up the handset at the radio (desk) to answer."
		return
	r_hint.text = ""
	for c in _choices:
		var b := UIStyle.button("%d   %s" % [c["index"] + 1, c["text"]])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART    # long replies wrap inside the 700 px column
		b.custom_minimum_size = Vector2(700, 46)
		b.add_theme_font_size_override("font_size", int(21 * text_scale))
		var idx: int = c["index"]
		b.pressed.connect(func(): _pick(idx))
		choice_box.add_child(b)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_freed_mouse = true
	_layout_choices()
	if InputSetup.pad_active:
		focus_first_choice()


## Gamepad (Stage 2C): the first reply takes focus so the d-pad moves between replies and A picks one.
func focus_first_choice() -> void:
	if choice_box.get_child_count() > 0 and get_viewport().gui_get_focus_owner() == null:
		(choice_box.get_child(0) as Control).grab_focus.call_deferred()


## Keep the reply stack 14 px above the top of the visible speech block (radio panel or subtitles).
func _layout_choices() -> void:
	var vp_h := get_viewport_rect().size.y
	var top := vp_h - 48.0
	if radio_panel.visible:
		top = radio_panel.get_global_rect().position.y
	elif sub_box.visible:
		top = sub_box.get_global_rect().position.y
	choice_box.offset_bottom = top - 14.0 - vp_h
	choice_box.offset_top = choice_box.offset_bottom - 236.0


func _clear_choices() -> void:
	for c in choice_box.get_children():
		choice_box.remove_child(c)      # detach now so the box is empty this frame (layout, tests)
		c.queue_free()


## Hand the mouse back to the game (it re-captures only if no device view, document, logbook or
## pause is open). Done BEFORE choice_made so that choices opened by the next step free it again.
func _restore_mouse() -> void:
	if not _freed_mouse:
		return
	_freed_mouse = false
	if mouse_restore_fn.is_valid():
		mouse_restore_fn.call()


func _pick(i: int) -> void:
	if get_tree().paused:
		return
	_choices = []
	_clear_choices()
	_restore_mouse()
	choice_made.emit(i)


func _render() -> void:
	var n := int(_shown)
	var vis := _full.substr(0, n)
	var txt := vis
	if line_look == "thought":
		txt = "[i]" + vis + "[/i]"
	if line_look == "radio":
		r_text.text = txt
	else:
		s_text.text = "[center]" + txt + "[/center]"


func _process(delta: float) -> void:
	_t += delta
	card.queue_redraw()
	if not _active or get_tree().paused:      # the typewriter freezes under the pause menu
		return
	if not _choices.is_empty() and choice_box.get_child_count() == 0:
		_refresh_choices()      # the player may have walked to the radio
	if choice_box.get_child_count() > 0:
		_layout_choices()       # the speech block can grow while the line types out
	if _shown < _full.length():
		if _pause > 0.0:
			_pause -= delta
			return
		var before := int(_shown)
		_shown = minf(_full.length(), _shown + delta * speed_cps)
		var after := int(_shown)
		if after > before:
			var ch := _full[after - 1]
			if ch in ".!?":
				_pause = 0.32
			elif ch in ",;:":
				_pause = 0.14
			elif ch == "-" or ch == "…":
				_pause = 0.2
			if after % 3 == 0:
				blip.emit("char")
			_render()
	else:
		_done_t += delta


func _unhandled_input(event: InputEvent) -> void:
	if not _active or get_tree().paused:      # this layer keeps processing during pause: ignore input
		return
	if not _choices.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			var i: int = event.keycode - KEY_1
			if i < _choices.size() and choice_box.get_child_count() > 0:
				_pick(i)
				get_viewport().set_input_as_handled()
		return
	var press: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	if _shown < _full.length():
		_shown = _full.length()      # first press completes the line
		_render()
		_done_t = 0.0
	elif _done_t > 0.25:             # guard against accidental double-skips
		advance_requested.emit()
	get_viewport().set_input_as_handled()


func _draw_card() -> void:
	var c: Array = CARDS.get(_speaker, ["", "", ""])
	var w := card.size.x
	var h := card.size.y
	card.draw_rect(Rect2(0, 0, w, h), Color(0.86, 0.82, 0.7, 0.92))
	card.draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.25, 0.2, 0.15, 0.6), false, 2.0)
	var f := UIStyle.sans()
	card.draw_string(f, Vector2(8, 22), String(c[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 16, 10, Color(0.15, 0.12, 0.1))
	card.draw_string(f, Vector2(8, h - 14), String(c[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 16, 9, Color(0.3, 0.25, 0.2))
	# a line drawing of the vessel / station, plus a live signal meter
	var kind: String = c[2]
	var ink := Color(0.18, 0.14, 0.11)
	var cx := w * 0.5
	var cy := h * 0.52
	match kind:
		"fishing", "schooner", "steamer":
			var L := 120.0 if kind == "steamer" else 100.0
			card.draw_colored_polygon(PackedVector2Array([Vector2(cx - L / 2, cy), Vector2(cx + L / 2 + 12, cy - 6), Vector2(cx + L / 2 - 4, cy + 16), Vector2(cx - L / 2 + 8, cy + 16)]), ink)
			card.draw_rect(Rect2(cx - 14, cy - 22, 30, 22), ink)
			if kind == "schooner":
				card.draw_line(Vector2(cx - 24, cy), Vector2(cx - 24, cy - 62), ink, 2.0)
				card.draw_line(Vector2(cx + 22, cy), Vector2(cx + 22, cy - 54), ink, 2.0)
			elif kind == "steamer":
				card.draw_rect(Rect2(cx + 4, cy - 46, 12, 24), Color(0.5, 0.12, 0.08))
			else:
				card.draw_line(Vector2(cx - 30, cy), Vector2(cx - 30, cy - 50), ink, 2.0)
		"station":
			card.draw_rect(Rect2(cx - 10, cy - 50, 20, 64), ink)
			card.draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, cy - 50), Vector2(cx + 14, cy - 50), Vector2(cx, cy - 66)]), ink)
			card.draw_line(Vector2(cx + 14, cy - 56), Vector2(cx + 60, cy - 70), Color(0.75, 0.5, 0.15), 3.0)
	if line_look == "radio" and _active:
		for i in 5:
			var lit := (sin(_t * 9.0 + i) * 0.5 + 0.5) * 5.0 > i
			card.draw_rect(Rect2(w - 22, h - 40 - i * 9, 12, 6), Color(0.2, 0.6, 0.3) if lit else Color(0.4, 0.35, 0.3))
