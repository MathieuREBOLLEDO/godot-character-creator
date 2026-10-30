@tool
extends RefCounted

## Apparence de l'écran de création (voir DESIGN.md de l'addon) : jetons de design
## du projet (couleurs, polices, tailles) lus dans res://design_tokens.cfg
## s'il existe, sinon les défauts ci-dessous. Les défauts sont la direction
## commune à tous les addons (« comme l'éditeur Godot », mêmes valeurs que
## settings/design_tokens.gd du debug menu) : sans ce fichier, l'addon a déjà
## le bon design ; le fichier ne sert qu'à s'en écarter.

const PATH: String = "res://design_tokens.cfg"
const DEFAULT_COLORS: Dictionary = {
	"ink": "1d2229",
	"ink_panel": "252b34",
	"ink_raised": "363d4a",
	"ink_line": "414957",
	"sand": "e0e0e0",
	"sand_dim": "8b929c",
	"accent": "70bbfa",
	"good": "45d17c",
	"bad": "ff786b",
	"info": "a5b6cc",
}
const DEFAULT_FONTS: Dictionary = {
	"ui": ["@engine"],
	"mono": ["JetBrains Mono", "Cascadia Mono", "Consolas", "Menlo"],
	"condensed_width": 100,
	"condensed_weight": 600,
}
const DEFAULT_SIZES: Dictionary = {"text": 14, "title": 16, "small": 12, "radius": 3}
## Dans l'éditeur, prendre les couleurs du thème de l'éditeur ouvert.
const DEFAULT_FOLLOW_EDITOR: bool = true

## Variantes de thème (theme_type_variation).
const KICKER: StringName = &"CcKicker"
const DIM: StringName = &"CcDim"
const PRIMARY: StringName = &"CcPrimary"
const TOOL: StringName = &"CcTool"

static var _config: ConfigFile = null
static var _fonts: Dictionary = {}


## Jeton de couleur ; avec [profile] follow_editor (vrai par défaut), la
## couleur équivalente du thème de l'éditeur Godot ouvert (_editor_color()).
static func color(key: String) -> Color:
	var from_editor: Variant = _editor_color(key) if _value("profile", "follow_editor", DEFAULT_FOLLOW_EDITOR) else null
	return from_editor if from_editor != null else Color(String(_value("colors", key, DEFAULT_COLORS[key])))


# Fond, panneaux, boutons, texte et accent de l'éditeur ouvert ; null hors de
# l'éditeur ou sans équivalent (info).
static func _editor_color(key: String) -> Variant:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return null
	var editor_theme: Theme = Engine.get_singleton(&"EditorInterface").get_editor_theme()
	if editor_theme == null:
		return null
	var font: Color = editor_theme.get_color(&"font_color", &"Editor")
	match key:
		"ink":
			return _box_color(editor_theme, &"Content", &"EditorStyles", false)
		"ink_panel":
			return _box_color(editor_theme, &"panel", &"Panel", false)
		"ink_raised":
			return _box_color(editor_theme, &"normal", &"Button", false)
		"ink_line":
			return _box_color(editor_theme, &"normal", &"Button", true)
		"sand":
			return font
		"sand_dim":
			return font.lerp(editor_theme.get_color(&"base_color", &"Editor"), 0.45)
		"accent":
			return editor_theme.get_color(&"accent_color", &"Editor")
		"good":
			return editor_theme.get_color(&"success_color", &"Editor")
		"bad":
			return editor_theme.get_color(&"error_color", &"Editor")
	return null


static func _box_color(editor_theme: Theme, style: StringName, type: StringName, border: bool) -> Variant:
	var box: StyleBoxFlat = editor_theme.get_stylebox(style, type) as StyleBoxFlat
	if box == null:
		return null
	return box.border_color if border else box.bg_color


static func size(key: String) -> int:
	return int(_value("sizes", key, DEFAULT_SIZES[key]))


## &"ui", &"condensed" (étroite et grasse : titres, surtitres) ou &"mono".
## Nom « @engine » : la police de l'éditeur Godot (dans l'éditeur), sinon celle
## de Godot par défaut.
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var mono: bool = kind == &"mono"
	var names: PackedStringArray = PackedStringArray(_value("fonts", "mono" if mono else "ui", DEFAULT_FONTS["mono" if mono else "ui"]))
	var result: Font
	if names.has("@engine"):
		result = _engine_font()
	else:
		var system: SystemFont = SystemFont.new()
		system.font_names = names
		result = system
	if kind == &"condensed":
		var narrow: FontVariation = FontVariation.new()
		narrow.base_font = result
		var server: TextServer = TextServerManager.get_primary_interface()
		narrow.variation_opentype = {
			server.name_to_tag("wdth"): int(_value("fonts", "condensed_width", DEFAULT_FONTS["condensed_width"])),
			server.name_to_tag("wght"): int(_value("fonts", "condensed_weight", DEFAULT_FONTS["condensed_weight"])),
		}
		result = narrow
	_fonts[kind] = result
	return result


## Thème de l'écran (posé sur sa racine).
static func build() -> Theme:
	var ink: Color = color("ink")
	var panel: Color = color("ink_panel")
	var raised: Color = color("ink_raised")
	var line: Color = color("ink_line")
	var sand: Color = color("sand")
	var dim: Color = color("sand_dim")
	var accent: Color = color("accent")
	var radius: int = size("radius")
	var theme: Theme = Theme.new()
	theme.default_font = font(&"ui")
	theme.default_font_size = size("text")
	theme.set_color("font_color", "Label", sand)

	theme.set_type_variation(KICKER, "Label")
	theme.set_font("font", KICKER, font(&"condensed"))
	theme.set_font_size("font_size", KICKER, size("small"))
	theme.set_color("font_color", KICKER, accent)
	theme.set_type_variation(DIM, "Label")
	theme.set_font_size("font_size", DIM, size("text") - 2)
	theme.set_color("font_color", DIM, dim)

	# Boutons : relief cerné d'un filet, accent au survol. Outils (icônes de
	# l'éditeur) : sans cadre, accent au survol.
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type_name, framed(raised, line, radius, 10, 4))
		theme.set_stylebox("hover", type_name, framed(raised.lightened(0.05), accent, radius, 10, 4))
		theme.set_stylebox("pressed", type_name, framed(ink, accent, radius, 10, 4))
		theme.set_stylebox("hover_pressed", type_name, framed(ink, accent, radius, 10, 4))
		theme.set_stylebox("disabled", type_name, framed(Color(raised, 0.4), Color(line, 0.4), radius, 10, 4))
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		_button_colors(theme, type_name, sand, accent, dim)
	theme.set_type_variation(TOOL, "Button")
	for state in ["normal", "disabled", "focus"]:
		theme.set_stylebox(state, TOOL, box(Color(0, 0, 0, 0), 0, 6, 4))
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, TOOL, box(Color(raised, 0.8), radius, 6, 4))
	_button_colors(theme, TOOL, sand, accent, Color(dim, 0.5))
	# Bouton principal (lecture) : plein, dans l'accent.
	theme.set_type_variation(PRIMARY, "Button")
	theme.set_stylebox("normal", PRIMARY, box(accent, radius, 10, 4))
	theme.set_stylebox("hover", PRIMARY, box(accent.lightened(0.15), radius, 10, 4))
	theme.set_stylebox("pressed", PRIMARY, box(accent.darkened(0.15), radius, 10, 4))
	theme.set_stylebox("hover_pressed", PRIMARY, box(accent.darkened(0.15), radius, 10, 4))
	theme.set_stylebox("disabled", PRIMARY, box(Color(accent, 0.35), radius, 10, 4))
	theme.set_stylebox("focus", PRIMARY, StyleBoxEmpty.new())
	_button_colors(theme, PRIMARY, ink, ink, Color(ink, 0.6))

	for type_name in ["CheckBox", "CheckButton"]:
		for state in ["normal", "pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type_name, box(Color(0, 0, 0, 0), 0, 4, 2))
		theme.set_stylebox("hover", type_name, box(Color(raised, 0.6), radius, 4, 2))
		theme.set_stylebox("hover_pressed", type_name, box(Color(raised, 0.6), radius, 4, 2))
		theme.set_icon("unchecked", type_name, _check_icon(dim, Color(0, 0, 0, 0), false, ink))
		theme.set_icon("checked", type_name, _check_icon(accent, accent, true, ink))
		theme.set_icon("unchecked_disabled", type_name, _check_icon(Color(dim, 0.4), Color(0, 0, 0, 0), false, ink))
		theme.set_icon("checked_disabled", type_name, _check_icon(Color(accent, 0.4), Color(accent, 0.4), true, ink))
		_button_colors(theme, type_name, sand, accent, dim)

	theme.set_stylebox("normal", "LineEdit", framed(ink, line, radius, 8, 4))
	theme.set_stylebox("focus", "LineEdit", framed(Color(0, 0, 0, 0), accent, radius, 8, 4))
	theme.set_stylebox("read_only", "LineEdit", framed(Color(ink, 0.5), line, radius, 8, 4))
	theme.set_color("font_color", "LineEdit", sand)
	theme.set_color("font_placeholder_color", "LineEdit", dim)
	theme.set_color("caret_color", "LineEdit", accent)
	theme.set_color("selection_color", "LineEdit", Color(accent, 0.35))

	theme.set_stylebox("slider", "HSlider", framed(ink, line, 3, 0, 3))
	theme.set_stylebox("grabber_area", "HSlider", box(accent.darkened(0.25), 3, 0, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(accent, 3, 0, 3))

	# Listes et arbre : creusés dans l'encre ; la ligne choisie a un trait
	# d'accent à gauche.
	var selected: StyleBoxFlat = box(raised, 2, 4, 2)
	selected.border_color = accent
	selected.border_width_left = 2
	for type_name in ["Tree", "ItemList"]:
		theme.set_stylebox("panel", type_name, framed(ink, line, radius, 4, 4))
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("selected", type_name, selected)
		theme.set_stylebox("selected_focus", type_name, selected)
		theme.set_stylebox("hovered", type_name, box(Color(raised, 0.6), 2, 4, 2))
		theme.set_color("font_color", type_name, sand)
		theme.set_color("font_selected_color", type_name, accent)
		theme.set_color("font_hovered_color", type_name, sand)
		theme.set_color("guide_color", type_name, Color(line, 0.25))
	theme.set_constant("draw_guides", "Tree", 0)
	theme.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	theme.set_color("relationship_line_color", "Tree", line)
	theme.set_stylebox("button_pressed", "Tree", box(Color(0, 0, 0, 0)))

	var popup: StyleBoxFlat = framed(panel, line, radius, 4, 4)
	theme.set_stylebox("panel", "PopupMenu", popup)
	var hover: StyleBoxFlat = box(raised, 2, 8, 4)
	hover.border_color = accent
	hover.border_width_left = 2
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", sand)
	theme.set_color("font_hover_color", "PopupMenu", accent)
	theme.set_color("font_disabled_color", "PopupMenu", dim)
	theme.set_stylebox("panel", "TooltipPanel", framed(raised, line, radius, 8, 5))
	theme.set_color("font_color", "TooltipLabel", sand)

	for type_name in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, box(Color(0, 0, 0, 0), 0, 3, 3))
		theme.set_stylebox("grabber", type_name, box(Color(line, 0.8), 3))
		theme.set_stylebox("grabber_highlight", type_name, box(dim, 3))
		theme.set_stylebox("grabber_pressed", type_name, box(accent, 3))
	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = line
	separator.vertical = true
	theme.set_stylebox("separator", "VSeparator", separator)
	# Séparateurs : fond encre (le filet est celui des panneaux), poignée
	# cachée tant qu'on ne la survole pas.
	for type_name in ["HSplitContainer", "VSplitContainer"]:
		theme.set_constant("separation", type_name, 1)
		theme.set_constant("autohide", type_name, 1)
		theme.set_constant("minimum_grab_thickness", type_name, 8)
		theme.set_stylebox("split_bar_background", type_name, box(ink))
	return theme


## Bandeau : fond panneau, filets sur les côtés de [param borders] (gauche,
## haut, droite, bas, en pixels).
static func band(borders: Vector4, margin: Vector4) -> PanelContainer:
	var result: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = box(color("ink_panel"), 0, margin.x, margin.y)
	style.content_margin_right = margin.z
	style.content_margin_bottom = margin.w
	style.border_color = color("ink_line")
	style.border_width_left = int(borders.x)
	style.border_width_top = int(borders.y)
	style.border_width_right = int(borders.z)
	style.border_width_bottom = int(borders.w)
	result.add_theme_stylebox_override("panel", style)
	return result


static func label(text: String, variation: StringName) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.theme_type_variation = variation
	return result


static func box(fill: Color, radius: int = 0, margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = fill
	result.set_corner_radius_all(radius)
	result.content_margin_left = margin_h
	result.content_margin_right = margin_h
	result.content_margin_top = margin_v
	result.content_margin_bottom = margin_v
	return result


static func framed(fill: Color, border: Color, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var result: StyleBoxFlat = box(fill, radius, margin_h, margin_v)
	result.border_color = border
	result.set_border_width_all(1)
	return result


static func _button_colors(theme: Theme, type_name: String, text: Color, accent: Color, disabled: Color) -> void:
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, accent)
	theme.set_color("font_pressed_color", type_name, accent)
	theme.set_color("font_hover_pressed_color", type_name, accent)
	theme.set_color("font_disabled_color", type_name, disabled)
	theme.set_color("icon_normal_color", type_name, text)
	theme.set_color("icon_hover_color", type_name, accent)
	theme.set_color("icon_pressed_color", type_name, accent)
	theme.set_color("icon_hover_pressed_color", type_name, accent)
	theme.set_color("icon_disabled_color", type_name, disabled)


# Case à cocher (14 px) : carré cerné, rempli ; cochée, un carré d'encre au
# centre.
static func _check_icon(border: Color, fill: Color, checked: bool, ink: Color) -> ImageTexture:
	var side: int = 14
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	for i in side:
		for edge in [0, side - 1]:
			image.set_pixel(i, edge, border)
			image.set_pixel(edge, i, border)
	if checked:
		image.fill_rect(Rect2i(4, 4, side - 8, side - 8), ink)
	return ImageTexture.create_from_image(image)


static func _engine_font() -> Font:
	# EditorInterface n'existe pas en jeu exporté : passé par Engine.
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var editor_theme: Theme = Engine.get_singleton(&"EditorInterface").get_editor_theme()
		if editor_theme != null and editor_theme.default_font != null:
			return editor_theme.default_font
	return ThemeDB.fallback_font


static func _value(section: String, key: String, default: Variant) -> Variant:
	if _config == null:
		_config = ConfigFile.new()
		if FileAccess.file_exists(PATH):
			_config.load(PATH)
	return _config.get_value(section, key, default)
