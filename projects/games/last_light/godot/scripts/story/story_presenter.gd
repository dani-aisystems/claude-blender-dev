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
	cv.offset_top = -80
	cv.offset_bottom = 80
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
	doc_tex = TextureRect.new()
	doc_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_tex.offset_left = 120
	doc_tex.offset_right = -120
	doc_tex.offset_top = 80
	doc_tex.offset_bottom = -110
	doc_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	doc_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	doc_root.add_child(doc_tex)
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
	hint.text = t
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


func open_document(id: String) -> void:
	if not docs.has(id):
		return
	_doc_open = id
	doc_tex.texture = load("res://assets/docs/%s.png" % id)
	doc_text.text = docs[id]["text"]
	doc_title.text = "%s        [T] transcription · [E] / [Esc] close" % docs[id]["title"]
	_transcript = false
	doc_text.visible = false
	doc_tex.visible = true
	doc_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_document_open() -> bool:
	return doc_root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not doc_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_transcript = not _transcript
			doc_text.visible = _transcript
			doc_tex.modulate.a = 0.15 if _transcript else 1.0
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed):
		doc_root.visible = false
		var id := _doc_open
		_doc_open = ""
		get_viewport().set_input_as_handled()
		document_closed.emit(id)


func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
		hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
