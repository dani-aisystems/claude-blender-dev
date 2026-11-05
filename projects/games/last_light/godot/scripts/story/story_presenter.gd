extends CanvasLayer
## Story presentation layer: dialogue UI, document viewer, objective line, hints, chapter cards,
## time-skip fades. Owned by game_fp in story mode; talks to StoryDirector via signals.

signal document_closed(doc_id: String)

var director: StoryDirector
var dialogue: Control
var objective: Label
var hint: Label
var card: Control
var card_title: Label
var card_sub: Label
var fade: ColorRect
var doc_root: Control
var doc_tex: TextureRect
var doc_text: RichTextLabel
var doc_title: Label
var docs := {}
var _hint_t := 0.0
var _doc_open := ""
var _transcript := false
## Inspection viewer (cabin pass): zoom and pan; it closes only on interact / back / pause / right click,
## never on a stray left click or the wheel (a click used to skip the 1954 clipping).
const ZOOM_MAX := 4.0
const OPEN_GUARD_FRAMES := 3            # the press that opened the document must not also close it
var doc_view: Control                   # clipping frame the document is drawn in
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _open_frame := 0
## Documents that are not story PNGs. The chart is the desk chart's own texture (keeper's pencil marks
## included), so the inspection shows exactly what lies on the desk; the physical chart never moves.
const BUILTIN_DOCS := {
	"chart": {"title": "Chart: North Point and approaches", "tex": "res://assets/models/watch_room_T_LL_Chart.png",
		"text": "NORTH POINT and approaches. Soundings in metres.\n\nLeading lines: West Gut, North Sound (000°), East Gut (046°).\n\nIn pencil: clearing bearings, clear 336° and clear 022°. A fix marked 13/11 2100. An older line, half rubbed out."},
}


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.get_file_as_string("res://assets/docs/docs.json")
	if f != "":
		docs = JSON.parse_string(f)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	objective = UIStyle.label("", 19, UIStyle.INK, UIStyle.serif())
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective.offset_left = 40
	objective.offset_top = 32
	objective.offset_right = 900
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.modulate.a = 0.85
	root.add_child(objective)
	hint = UIStyle.label("", 18, UIStyle.DIM, UIStyle.sans())
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hint.offset_left = 40
	hint.offset_top = 70
	hint.offset_right = 900
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	dialogue = preload("res://scripts/ui/dialogue_ui.gd").new()
	root.add_child(dialogue)
	# chapter card
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	root.add_child(card)
	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cv.offset_left = -700
	cv.offset_right = 700
	# upper-middle (~37 % of the height): clear of the interaction prompt under the crosshair
	cv.offset_top = -300
	cv.offset_bottom = -140
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(cv)
	card_title = UIStyle.label("", 64, UIStyle.INK, UIStyle.serif())
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(card_title)
	card_sub = UIStyle.label("", 22, UIStyle.AMBER, UIStyle.serif())
	card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(card_sub)
	# document viewer
	doc_root = Control.new()
	doc_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_root.visible = false
	root.add_child(doc_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_root.add_child(shade)
	doc_view = Control.new()
	doc_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_view.offset_left = 120
	doc_view.offset_right = -120
	doc_view.offset_top = 80
	doc_view.offset_bottom = -110
	doc_view.clip_contents = true
	doc_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doc_root.add_child(doc_view)
	doc_tex = TextureRect.new()
	doc_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	doc_tex.stretch_mode = TextureRect.STRETCH_SCALE        # _layout_doc keeps the aspect ratio
	doc_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	doc_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doc_view.add_child(doc_tex)
	doc_text = RichTextLabel.new()
	doc_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_text.offset_left = 260
	doc_text.offset_right = -260
	doc_text.offset_top = 140
	doc_text.offset_bottom = -140
	doc_text.add_theme_font_override("normal_font", UIStyle.serif())
	doc_text.add_theme_font_size_override("normal_font_size", 28)
	doc_text.visible = false
	doc_root.add_child(doc_text)
	doc_title = UIStyle.label("", 22, UIStyle.AMBER, UIStyle.serif())
	doc_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	doc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doc_title.offset_top = -90
	doc_title.offset_bottom = -40
	doc_root.add_child(doc_title)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func bind(d: StoryDirector) -> void:
	director = d
	d.line_shown.connect(dialogue.show_line)
	d.choices_shown.connect(dialogue.show_choices)
	d.dialogue_closed.connect(dialogue.close)
	dialogue.advance_requested.connect(d.advance_line)
	dialogue.choice_made.connect(d.choose)
	d.objective_changed.connect(func(t):
		objective.text = ("▸ " + t) if t != "" else ""
		hint.text = "")
	d.chapter_started.connect(show_chapter)


func show_hint(t: String) -> void:
	hint.text = InputSetup.resolve(t)     # {interact} {move} ... -> keyboard or pad glyphs (Stage 2C)
	_hint_t = 14.0


func show_chapter(n: int, title: String, sub: String) -> void:
	card_title.text = "%s · %s" % [["", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)], title]
	card_sub.text = sub
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 1.6)
	tw.tween_interval(3.2)
	tw.tween_property(card, "modulate:a", 0.0, 1.8)


func timeskip(clock_text: String) -> void:
	card_title.text = clock_text
	card_sub.text = ""
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 1.0)
	tw.tween_interval(1.6)
	tw.tween_property(fade, "color:a", 0.0, 1.4)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 1.4)


func fade_to(a: float, secs: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, secs)
	return tw


func doc_info(id: String) -> Dictionary:
	return docs.get(id, BUILTIN_DOCS.get(id, {}))


## Open a document or the chart for inspection. The mouse policy is game_fp's (it re-applies it after
## opening and closing); this layer never sets the mouse mode.
func open_document(id: String) -> void:
	var d := doc_info(id)
	if d.is_empty():
		return
	_doc_open = id
	doc_tex.texture = load(String(d.get("tex", "res://assets/docs/%s.png" % id)))
	doc_text.text = d["text"]
	_transcript = false
	doc_text.visible = false
	doc_tex.visible = true
	doc_tex.modulate.a = 1.0
	_zoom = 1.0
	_pan = Vector2.ZERO
	_dragging = false
	_open_frame = Engine.get_process_frames()
	_update_doc_title()
	doc_root.visible = true
	dialogue.visible = false                     # its subtitles bled through the shade under the legend
	_layout_doc.call_deferred()


func _update_doc_title() -> void:
	var d := doc_info(_doc_open)
	var zoom_keys := "%s zoom · drag to move" % InputSetup.key("turn") if not InputSetup.pad_active \
		else "%s zoom · %s move" % [InputSetup.key("turn"), "[Right stick]"]
	doc_title.text = "%s        %s  ·  %s transcription  ·  %s / %s close" % [d.get("title", ""), zoom_keys,
		InputSetup.key("transcript"), InputSetup.key("interact"), InputSetup.key("back")]


func is_document_open() -> bool:
	return doc_root.visible


func close_document() -> void:
	if not doc_root.visible:
		return
	doc_root.visible = false
	dialogue.visible = true
	_dragging = false
	var id := _doc_open
	_doc_open = ""
	document_closed.emit(id)


## Fit the texture inside the frame at zoom 1 (aspect kept), scale it by the zoom, and keep the pan
## inside the image so it can never be dragged off screen.
func _layout_doc() -> void:
	if doc_tex.texture == null:
		return
	var frame := doc_view.size
	var ts := doc_tex.texture.get_size()
	var fit := minf(frame.x / ts.x, frame.y / ts.y)
	var sz := ts * fit * _zoom
	var slack := ((sz - frame) * 0.5).max(Vector2.ZERO)
	_pan = _pan.clamp(-slack, slack)
	doc_tex.size = sz
	doc_tex.position = (frame - sz) * 0.5 + _pan


## Zoom by `factor` keeping the point under `at` (frame px) still.
func _zoom_at(factor: float, at: Vector2) -> void:
	var z := clampf(_zoom * factor, 1.0, ZOOM_MAX)
	if is_equal_approx(z, _zoom):
		return
	var centre := doc_view.size * 0.5 + _pan
	_pan += (at - centre) * (1.0 - z / _zoom)
	_zoom = z
	_layout_doc()


## _input, not _unhandled_input: the viewer owns every event while it is open (its full-screen shade is a
## GUI control that swallowed mouse buttons before _unhandled_input, so right click never closed it, R8).
func _input(event: InputEvent) -> void:
	if not doc_root.visible:
		return
	get_viewport().set_input_as_handled()          # nothing under the viewer reacts while reading
	if event.is_action_pressed("transcript"):    # T, or pad X (Stage 2C)
		_transcript = not _transcript
		doc_text.visible = _transcript
		doc_tex.modulate.a = 0.15 if _transcript else 1.0
		return
	if event is InputEventMouseButton:
		var local: Vector2 = event.position - doc_view.get_global_rect().position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(1.15, local)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1.0 / 1.15, local)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed               # drag to move; a left click never closes
			return
	if event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_layout_doc()
		return
	if event.is_action_pressed("turn_next") or event.is_action_pressed("turn_prev"):
		_zoom_at(1.25 if event.is_action_pressed("turn_next") else 0.8, doc_view.size * 0.5)
		return
	var close: bool = event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("back") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if close and Engine.get_process_frames() - _open_frame >= OPEN_GUARD_FRAMES:
		close_document()


func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
		hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
	if doc_root.visible and _zoom > 1.0:            # keys / sticks move around a zoomed document
		var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var st := InputSetup.stick("look_left", "look_right", "look_up", "look_down")
		var d := (mv + st) * 700.0 * delta
		if d != Vector2.ZERO:
			_pan -= d
			_layout_doc()
