class_name UIStyle
extends RefCounted
## Maritime UI palette and fonts. Stage 3A: the fonts are bundled OFL files (godot/assets/fonts, licences
## alongside and in assets/ASSET_LICENSES.md), so the game looks the same on every Mac and on Windows,
## and thoughts get a genuine italic instead of the upright serif.
##   serif / serif_italic / serif_bold : Libre Baskerville (variable wght)
##   sans / sans_italic / sans_semibold: Source Sans 3 (variable wght)
##   typewriter                        : Courier Prime (documents, teleprinter)
##   hand                              : Cedarville Cursive (Callum's hand)
## Text scale: every label, button and rich text made here is registered (group "ui_text", meta
## "ui_base") and follows Settings "subtitle_size" (Options: Text size). set_text_scale() re-applies it
## live. Large titles (>= 40 px) grow at half rate so they never outgrow their screens.

const INK := Color("#e9e2cf")          # parchment text
const DIM := Color("#9aa3ad")
const AMBER := Color("#ffb347")
const SAFE := Color("#6fe39a")
const DANGER := Color("#ff5a45")
const PANEL := Color(0.04, 0.06, 0.09, 0.78)
const LINE := Color(0.91, 0.87, 0.78, 0.25)

const FONT_DIR := "res://assets/fonts/"
const GROUP := "ui_text"
const TITLE_PX := 40                   # bases at or above this scale at half rate

static var text_scale := 1.0
static var _fonts := {}


static func _file(path: String, fallback_names: PackedStringArray) -> Font:
	var f: Font = load(FONT_DIR + path) if ResourceLoader.exists(FONT_DIR + path) else null
	if f == null:                       # never ship with a missing font: fall back to the system face
		var sf := SystemFont.new()
		sf.font_names = fallback_names
		push_warning("UIStyle: bundled font %s missing, using system fallback" % path)
		return sf
	return f


static func _variant(key: String, path: String, wght: int, fallback: PackedStringArray) -> Font:
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = _file(path, fallback)
		if wght > 0 and fv.base_font is FontFile:
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
		_fonts[key] = fv
	return _fonts[key]


static func serif() -> Font:
	return _variant("serif", "libre_baskerville/LibreBaskerville[wght].ttf", 500, PackedStringArray(["Baskerville", "Georgia", "serif"]))


static func serif_italic() -> Font:
	return _variant("serif_i", "libre_baskerville/LibreBaskerville-Italic[wght].ttf", 500, PackedStringArray(["Baskerville", "Georgia", "serif"]))


static func serif_bold() -> Font:
	return _variant("serif_b", "libre_baskerville/LibreBaskerville[wght].ttf", 700, PackedStringArray(["Baskerville", "Georgia", "serif"]))


static func sans() -> Font:
	return _variant("sans", "source_sans_3/SourceSans3[wght].ttf", 500, PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"]))


static func sans_italic() -> Font:
	return _variant("sans_i", "source_sans_3/SourceSans3-Italic[wght].ttf", 500, PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"]))


static func sans_semibold() -> Font:
	return _variant("sans_sb", "source_sans_3/SourceSans3[wght].ttf", 600, PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"]))


static func typewriter() -> Font:
	return _variant("type", "courier_prime/CourierPrime-Regular.ttf", 0, PackedStringArray(["Courier New", "Courier", "monospace"]))


static func hand() -> Font:
	return _variant("hand", "cedarville_cursive/Cedarville-Cursive.ttf", 0, PackedStringArray(["Bradley Hand", "cursive"]))


# ------------------------------------------------------------------ text scale

## Pixel size for a base size at the current text scale.
static func px(base: int) -> int:
	var k := 0.5 if base >= TITLE_PX else 1.0
	return int(round(base * (1.0 + (text_scale - 1.0) * k)))


## Register a control so its text follows the text scale. Returns the control for chaining.
static func track(c: Control, base: int) -> Control:
	c.set_meta("ui_base", base)
	if not c.is_in_group(GROUP):
		c.add_to_group(GROUP)
	_apply_size(c)
	return c


static func _apply_size(c: Control) -> void:
	var s := px(int(c.get_meta("ui_base", 20)))
	if c is RichTextLabel:
		for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size", "mono_font_size"]:
			c.add_theme_font_size_override(k, s)
		if c.has_meta("ui_bold"):
			c.add_theme_font_size_override("bold_font_size", px(int(c.get_meta("ui_bold"))))
	else:
		c.add_theme_font_size_override("font_size", s)


## Settings calls this whenever the text size changes; every registered control is resized at once.
static func set_text_scale(s: float, tree: SceneTree) -> void:
	text_scale = clampf(s, 0.6, 2.0)
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		if n is Control:
			_apply_size(n)


# ------------------------------------------------------------------ builders

static func label(text: String, size: int, color: Color = INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else sans())
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	track(l, size)
	return l


## A RichTextLabel with the serif family wired (real italic and bold faces), registered for scaling.
static func rich(size: int, color: Color = INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", serif())
	r.add_theme_font_override("italics_font", serif_italic())
	r.add_theme_font_override("bold_font", serif_bold())
	r.add_theme_font_override("bold_italics_font", serif_italic())
	r.add_theme_font_override("mono_font", typewriter())
	r.add_theme_color_override("default_color", color)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track(r, size)
	return r


static func panel_box(alpha: float = 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, alpha)
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func button(text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", serif())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.07, 0.1, 0.55)
	normal.border_color = LINE
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16        # left-aligned buttons (dialogue replies) need breathing room
	normal.content_margin_right = 16
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.09, 0.05, 0.75)
	hover.border_color = AMBER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	track(b, size)
	return b
