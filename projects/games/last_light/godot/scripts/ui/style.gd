class_name UIStyle
extends RefCounted
## Maritime UI palette and fonts. Fonts are macOS system fonts (SystemFont), so nothing is bundled.

const INK := Color("#e9e2cf")          # parchment text
const DIM := Color("#9aa3ad")
const AMBER := Color("#ffb347")
const SAFE := Color("#6fe39a")
const DANGER := Color("#ff5a45")
const PANEL := Color(0.04, 0.06, 0.09, 0.78)
const LINE := Color(0.91, 0.87, 0.78, 0.25)

static var _serif: SystemFont
static var _sans: SystemFont


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
		_serif.font_weight = 600
	return _serif


static func sans() -> Font:
	if _sans == null:
		_sans = SystemFont.new()
		_sans.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
		_sans.font_weight = 500
	return _sans


static func label(text: String, size: int, color: Color = INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else sans())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


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


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.07, 0.1, 0.55)
	normal.border_color = LINE
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.09, 0.05, 0.75)
	hover.border_color = AMBER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b
