@tool
extends Control

## Écran de création de personnage, pour le joueur (en jeu) et pour le
## développeur (scène lancée depuis l'éditeur : bouton Save preset).
## En-tête (Random, Reset), corps en trois colonnes (emplacements, scène,
## pièces et couleur), pied (Cancel, Confirm).
## Le jeu instancie cc_creator.tscn, peut lui donner [look] à modifier, et
## écoute confirmed(look) / cancelled.
## [embedded] : intégré à l'onglet Characters de l'éditeur : modifie [look]
## directement (pas de copie), sans pied ; set_look() change de fiche.

const Theme_ = preload("res://addons/character_creator/creator/cc_theme.gd")
const T = preload("res://addons/character_creator/i18n/t.gd")
const Stage = preload("res://addons/character_creator/creator/cc_stage.gd")
const DEFAULT_CATALOG: String = "res://character_creator/catalog.res"

signal confirmed(look: CcLook)
signal cancelled

## Emplacements dans l'ordre de la colonne de gauche.
const SLOT_ORDER: PackedStringArray = [
	"body", "head", "chest", "legs", "shoes", "hands", "belt", "weapon",
	"offhand", "bag", "mount", "slash", "effect", "gunfire", "shadow",
]
const SLOT_NAMES: Dictionary = {
	"body": "Body", "head": "Head", "chest": "Chest", "legs": "Legs",
	"shoes": "Shoes", "hands": "Hands", "belt": "Belt", "weapon": "Weapon",
	"offhand": "Off-hand", "bag": "Bag", "mount": "Mount", "slash": "Slash",
	"effect": "Effect", "gunfire": "Gunfire", "shadow": "Shadow",
}
## Emplacements qui ont toujours une pièce.
const REQUIRED: PackedStringArray = ["body"]
## Emplacements tirés par Random (les autres restent tels quels).
const RANDOM_SLOTS: PackedStringArray = ["body", "head", "chest", "legs", "shoes", "hands", "belt", "weapon", "offhand", "bag"]
## Nuanciers (contenu, pas des couleurs d'interface) : peau pour le corps,
## teintes d'équipement pour le reste. Blanc = couleurs d'origine.
const SKIN: PackedColorArray = [
	Color("ffffff"), Color("f6d7bd"), Color("e8b894"), Color("d39a6e"),
	Color("b77a4e"), Color("8f5a36"), Color("6b4026"), Color("4a2c1a"),
	Color("c9d6a3"), Color("9fb7c9"), Color("b0a3c9"), Color("8a8f99"),
]
const GEAR: PackedColorArray = [
	Color("ffffff"), Color("c9c2b0"), Color("8a7a63"), Color("5b4636"),
	Color("b8433a"), Color("d98a3d"), Color("e3c25a"), Color("6f9a4a"),
	Color("3f7a6e"), Color("4a6fa8"), Color("6e5aa0"), Color("3a3d44"),
]
const THUMB: int = 64

## Apparence modifiée (copiée à l'ouverture) ; null : apparence par défaut.
@export var look: CcLook
## Catalogue des pièces ; null : réglage character_creator/catalog_path.
@export var catalog: CcCatalog
## Dossier des personnages prédéfinis (bouton Save preset, seulement quand
## le jeu est lancé depuis l'éditeur) ; vide : pas de bouton.
@export_dir var preset_dir: String = ""
## Intégré à l'onglet Characters (voir en tête).
var embedded: bool = false

var _look: CcLook
var _title: Label
var _slot: String = "body"
var _stage: Stage
var _slot_buttons: Dictionary = {}  # emplacement -> Button
var _slot_values: Dictionary = {}   # emplacement -> Label (pièce choisie)
var _parts_title: Label
var _parts_grid: GridContainer
var _part_name: Label
var _swatches: GridContainer
var _custom_color: ColorPickerButton
var _height_slider: HSlider
var _width_slider: HSlider
var _outline_picker: OptionButton
var _outline_color: ColorPickerButton
var _frames_picker: OptionButton
var _anim_picker: OptionButton
var _direction_label: Label
var _play_button: Button
var _status: Label
var _preset_name: LineEdit


func _ready() -> void:
	# Scène ouverte dans l'éditeur : ne rien construire (ce serait enregistré
	# dans la scène).
	if Engine.is_editor_hint() and not embedded:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Theme_.build()
	if catalog == null:
		var path: String = String(ProjectSettings.get_setting("character_creator/catalog_path", DEFAULT_CATALOG))
		if ResourceLoader.exists(path):
			catalog = load(path) as CcCatalog
	_look = look if embedded and look != null else (look.duplicate_look() if look != null else CcLook.default_look())
	_build()
	if catalog == null:
		return
	_stage.sprite.catalog = catalog
	_stage.sprite.look = _look
	_look.changed.connect(_on_look_changed)
	for anim in catalog.anims:
		_anim_picker.add_item(anim)
	_anim_picker.select(maxi(0, catalog.anims.find("Idle")))
	_select_slot("body")
	_refresh_slot_values()
	_refresh_size()
	_cascade()


## Onglet Characters : montre et modifie une autre apparence (sans copie).
func set_look(new_look: CcLook, title: String = "") -> void:
	if _look != null and _look.changed.is_connected(_on_look_changed):
		_look.changed.disconnect(_on_look_changed)
	_look = new_look
	if _title != null and title != "":
		_title.text = title
	if catalog == null or _stage == null:
		return
	_look.changed.connect(_on_look_changed)
	_stage.sprite.look = _look
	_select_slot(_slot)
	_refresh_slot_values()
	_refresh_size()


# --- Construction ---

func _build() -> void:
	var background: Panel = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", Theme_.box(Theme_.color("ink")))
	add_child(background)
	var page: VBoxContainer = VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	page.add_child(_build_header())
	if catalog == null:
		page.add_child(_build_empty())
	else:
		page.add_child(_build_body())
	if not embedded:
		page.add_child(_build_footer())


func _build_header() -> Control:
	var band: PanelContainer = Theme_.band(Vector4(0, 0, 0, 1), Vector4(20, 10, 20, 10))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	band.add_child(row)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(Theme_.label(T.t("CHARACTER"), Theme_.KICKER))
	_title = Label.new()
	_title.text = T.t("Appearance")
	_title.add_theme_font_override("font", Theme_.font(&"condensed"))
	_title.add_theme_font_size_override("font_size", Theme_.size("title") + 4)
	titles.add_child(_title)
	row.add_child(titles)
	row.add_child(_spacer())
	var group: HBoxContainer = HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	group.add_child(_button(T.t("Random"), T.t("Random gear and colors"), _randomize))
	group.add_child(_button(T.t("Reset"), T.t("Back to the default character"), _reset))
	group.visible = catalog != null
	row.add_child(group)
	return band


func _build_body() -> Control:
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)

	# Emplacements.
	var left: PanelContainer = Theme_.band(Vector4(0, 0, 1, 0), Vector4(10, 12, 10, 12))
	left.custom_minimum_size.x = 210
	var left_box: VBoxContainer = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 6)
	left.add_child(left_box)
	left_box.add_child(Theme_.label(T.t("SLOTS"), Theme_.KICKER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)
	var slots: VBoxContainer = VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 2)
	scroll.add_child(slots)
	var group: ButtonGroup = ButtonGroup.new()
	for slot in SLOT_ORDER:
		if catalog.parts_of(slot).is_empty():
			continue
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = Theme_.TOOL
		button.custom_minimum_size.y = 36
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = T.t(SLOT_NAMES[slot])
		button.pressed.connect(_select_slot.bind(slot))
		var value: Label = Theme_.label("", Theme_.DIM)
		value.add_theme_font_override("font", Theme_.font(&"mono"))
		value.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.offset_left = -90
		value.offset_right = -8
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(value)
		slots.add_child(button)
		_slot_buttons[slot] = button
		_slot_values[slot] = value
	body.add_child(left)

	# Scène et barre de lecture.
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	_stage = Stage.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.tooltip_text = T.t("Drag to turn the character")
	_stage.turned.connect(_turn)
	center.add_child(_stage)
	var bar: PanelContainer = Theme_.band(Vector4(0, 1, 0, 0), Vector4(12, 8, 12, 8))
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.add_theme_constant_override("separation", 6)
	bar.add_child(bar_row)
	bar_row.add_child(_tool_button("RotateLeft", "◀", T.t("Turn left"), _turn.bind(-1)))
	_direction_label = Theme_.label("S", Theme_.DIM)
	_direction_label.add_theme_font_override("font", Theme_.font(&"mono"))
	_direction_label.custom_minimum_size.x = 32
	_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_row.add_child(_direction_label)
	bar_row.add_child(_tool_button("RotateRight", "▶", T.t("Turn right"), _turn.bind(1)))
	bar_row.add_child(_gap(16))
	_anim_picker = OptionButton.new()
	_anim_picker.custom_minimum_size = Vector2(170, 36)
	_anim_picker.tooltip_text = T.t("Animation")
	# Noms d'animations du pack : ne pas les faire traduire par Godot.
	_anim_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_anim_picker.add_theme_font_override("font", Theme_.font(&"mono"))
	_anim_picker.item_selected.connect(_on_anim_selected)
	bar_row.add_child(_anim_picker)
	_play_button = _tool_button("Pause", "❚❚", T.t("Pause or play the animation"), _toggle_play)
	bar_row.add_child(_play_button)
	# Zoom (aussi à la molette et au pincement sur la scène).
	bar_row.add_child(_gap(16))
	bar_row.add_child(_tool_button("ZoomLess", "−", T.t("Zoom out"), _stage.step_zoom.bind(-1)))
	var zoom_label: Label = Theme_.label("", Theme_.DIM)
	zoom_label.add_theme_font_override("font", Theme_.font(&"mono"))
	zoom_label.custom_minimum_size.x = 36
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.tooltip_text = T.t("Zoom (mouse wheel or pinch on the stage)")
	zoom_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_row.add_child(zoom_label)
	bar_row.add_child(_tool_button("ZoomMore", "+", T.t("Zoom in"), _stage.step_zoom.bind(1)))
	_stage.zoom_changed.connect(func(level: int) -> void: zoom_label.text = "x%d" % level)
	_stage.resized.connect(func() -> void: zoom_label.text = "x%d" % _stage.shown_zoom())
	center.add_child(bar)
	body.add_child(center)

	# Pièces et couleur.
	var right: PanelContainer = Theme_.band(Vector4(1, 0, 0, 0), Vector4(14, 12, 14, 12))
	right.custom_minimum_size.x = 340
	var right_box: VBoxContainer = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right.add_child(right_box)
	var parts_head: HBoxContainer = HBoxContainer.new()
	_parts_title = Theme_.label("", Theme_.KICKER)
	parts_head.add_child(_parts_title)
	parts_head.add_child(_spacer())
	_part_name = Theme_.label("", Theme_.DIM)
	_part_name.add_theme_font_override("font", Theme_.font(&"mono"))
	parts_head.add_child(_part_name)
	right_box.add_child(parts_head)
	var parts_scroll: ScrollContainer = ScrollContainer.new()
	parts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_box.add_child(parts_scroll)
	_parts_grid = GridContainer.new()
	_parts_grid.columns = 4
	_parts_grid.add_theme_constant_override("h_separation", 6)
	_parts_grid.add_theme_constant_override("v_separation", 6)
	parts_scroll.add_child(_parts_grid)
	right_box.add_child(Theme_.label(T.t("COLOR"), Theme_.KICKER))
	_swatches = GridContainer.new()
	_swatches.columns = 6
	_swatches.add_theme_constant_override("h_separation", 6)
	_swatches.add_theme_constant_override("v_separation", 6)
	right_box.add_child(_swatches)
	var custom_row: HBoxContainer = HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 8)
	var custom_label: Label = Theme_.label(T.t("Custom"), Theme_.DIM)
	custom_row.add_child(custom_label)
	_custom_color = ColorPickerButton.new()
	_custom_color.edit_alpha = false
	_custom_color.custom_minimum_size = Vector2(64, 32)
	_custom_color.tooltip_text = T.t("Pick any color")
	_custom_color.color_changed.connect(func(value: Color) -> void: _look.set_color(_slot, Color(value, _look.color(_slot).a)))
	custom_row.add_child(_custom_color)
	right_box.add_child(custom_row)
	# Taille de tout le personnage (pas d'un emplacement).
	var size_head: HBoxContainer = HBoxContainer.new()
	size_head.add_child(Theme_.label(T.t("SIZE"), Theme_.KICKER))
	size_head.add_child(_spacer())
	var size_reset: Button = _button(T.t("100 %"), T.t("Back to the pack size"), func() -> void: _look.size = Vector2.ONE)
	size_reset.theme_type_variation = Theme_.TOOL
	size_reset.add_theme_font_override("font", Theme_.font(&"mono"))
	size_reset.custom_minimum_size.y = 24
	size_head.add_child(size_reset)
	right_box.add_child(size_head)
	_height_slider = _size_row(right_box, T.t("Height"), 1)
	_width_slider = _size_row(right_box, T.t("Width"), 0)
	# Style : contour et réduction d'images (comme l'outil Unity du pack).
	right_box.add_child(Theme_.label(T.t("STYLE"), Theme_.KICKER))
	var outline_row: HBoxContainer = _caption_row(right_box, T.t("Outline"))
	_outline_picker = OptionButton.new()
	_outline_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_outline_picker.add_theme_font_override("font", Theme_.font(&"mono"))
	_outline_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outline_picker.tooltip_text = T.t("Outline around the whole character (not the shadow)")
	_outline_picker.add_item(T.t("None"), 0)
	for width in range(1, CcLook.OUTLINE_MAX + 1):
		_outline_picker.add_item("%d px" % width, width)
	_outline_picker.item_selected.connect(func(index: int) -> void: _look.outline_width = _outline_picker.get_item_id(index))
	outline_row.add_child(_outline_picker)
	_outline_color = ColorPickerButton.new()
	_outline_color.custom_minimum_size = Vector2(48, 28)
	_outline_color.tooltip_text = T.t("Outline color")
	_outline_color.color_changed.connect(func(value: Color) -> void: _look.outline_color = value)
	outline_row.add_child(_outline_color)
	var frames_row: HBoxContainer = _caption_row(right_box, T.t("Frames"))
	_frames_picker = OptionButton.new()
	_frames_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_frames_picker.add_theme_font_override("font", Theme_.font(&"mono"))
	_frames_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frames_picker.tooltip_text = T.t("Frames played per animation (same duration): fewer is choppier, retro style")
	for count in CcLook.FRAME_CHOICES:
		_frames_picker.add_item("%d" % count, count)
	_frames_picker.item_selected.connect(func(index: int) -> void:
		var count: int = _frames_picker.get_item_id(index)
		_look.frames = 0 if count >= CcLook.FRAME_CHOICES[0] else count)
	frames_row.add_child(_frames_picker)
	body.add_child(right)
	return body


func _build_empty() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title: Label = Theme_.label(T.t("NO CHARACTER PARTS"), Theme_.KICKER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint: Label = Theme_.label(T.t("Import the pack in the editor: Project > Tools > Import Character Creator pack."), Theme_.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return center


func _build_footer() -> Control:
	var band: PanelContainer = Theme_.band(Vector4(0, 1, 0, 0), Vector4(20, 10, 20, 10))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	band.add_child(row)
	_status = Theme_.label("", Theme_.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	if preset_dir != "" and OS.has_feature("editor") and catalog != null:
		_preset_name = LineEdit.new()
		_preset_name.placeholder_text = T.t("preset name")
		_preset_name.custom_minimum_size = Vector2(160, 36)
		_preset_name.add_theme_font_override("font", Theme_.font(&"mono"))
		row.add_child(_preset_name)
		row.add_child(_button(T.t("Save preset"), T.t("Save this look as a .tres in %s") % preset_dir, _save_preset))
		row.add_child(_gap(12))
	row.add_child(_button(T.t("Cancel"), "", func() -> void: cancelled.emit()))
	var confirm: Button = _button(T.t("Confirm"), T.t("Keep this character"), _confirm)
	confirm.theme_type_variation = Theme_.PRIMARY
	confirm.disabled = catalog == null
	row.add_child(confirm)
	return band


# --- Emplacements, pièces, couleurs ---

func _select_slot(slot: String) -> void:
	_slot = slot
	if _slot_buttons.has(slot):
		_slot_buttons[slot].button_pressed = true
	_parts_title.text = T.t(SLOT_NAMES[slot]).to_upper()
	_rebuild_parts()
	_rebuild_swatches()


func _rebuild_parts() -> void:
	for child in _parts_grid.get_children():
		child.queue_free()
	var group: ButtonGroup = ButtonGroup.new()
	if not REQUIRED.has(_slot):
		_parts_grid.add_child(_part_button("", group))
	for part in catalog.parts_of(_slot):
		_parts_grid.add_child(_part_button(part, group))
	_part_name.text = _display_name(_look.part(_slot))


func _part_button(part: String, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(THUMB + 6, THUMB + 6)
	button.tooltip_text = _display_name(part)
	button.button_pressed = _look.part(_slot) == part
	button.pressed.connect(_pick_part.bind(part))
	if part == "":
		button.text = "—"
		button.add_theme_font_override("font", Theme_.font(&"mono"))
		return button
	# Vignette agrandie d'un nombre entier de fois (pixels nets), centrée.
	var holder: CenterContainer = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(holder)
	var icon: TextureRect = TextureRect.new()
	icon.texture = _thumbnail(part)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = _look.color(_slot)
	if icon.texture != null:
		var source: Vector2 = icon.texture.get_size()
		var zoom: int = clampi(floori(THUMB / maxf(source.x, source.y)), 1, 4)
		icon.custom_minimum_size = (source * zoom).min(Vector2(THUMB, THUMB))
	holder.add_child(icon)
	return button


# Première image de l'animation la plus parlante de la pièce, vue de face.
func _thumbnail(part: String) -> Texture2D:
	for anim in ["Idle", "Attack1", "RideIdle"] + Array(catalog.anims):
		var data: PackedInt32Array = catalog.frames(part, anim)
		if data.is_empty():
			continue
		for frame in catalog.frame_count:
			var rect: Rect2i = catalog.frame_rect(data, 2, frame)
			if rect.size != Vector2i.ZERO:
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = catalog.texture(part, anim)
				atlas.region = Rect2(rect)
				return atlas
	return null


func _pick_part(part: String) -> void:
	_look.set_part(_slot, part)
	_part_name.text = _display_name(part)
	_stage.pop()


func _rebuild_swatches() -> void:
	for child in _swatches.get_children():
		child.queue_free()
	var current: Color = _look.color(_slot)
	for value in (SKIN if _slot == "body" else GEAR):
		var swatch: Button = Button.new()
		swatch.custom_minimum_size = Vector2(40, 32)
		swatch.tooltip_text = "#" + value.to_html(false)
		var selected: bool = Color(value, current.a).is_equal_approx(current)
		var border: Color = Theme_.color("accent") if selected else Theme_.color("ink_line")
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style: StyleBoxFlat = Theme_.framed(value, border if state != "hover" else Theme_.color("accent"), Theme_.size("radius"), 0, 0)
			style.set_border_width_all(2 if selected or state == "hover" else 1)
			swatch.add_theme_stylebox_override(state, style)
		# L'alpha est gardé (ombre à 70 %).
		swatch.pressed.connect(func() -> void:
			_look.set_color(_slot, Color(value, _look.color(_slot).a))
			_rebuild_swatches())
		_swatches.add_child(swatch)
	_custom_color.color = current


# Ligne « légende, curseur, valeur » ; [axis] 0 largeur, 1 hauteur.
func _size_row(parent: Container, caption: String, axis: int) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Theme_.label(caption, Theme_.DIM)
	label.custom_minimum_size.x = 64
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = CcLook.SIZE_MIN
	slider.max_value = CcLook.SIZE_MAX
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 24
	slider.tooltip_text = T.t("Pixel art: sizes other than 50, 100 or 150 % give slightly uneven pixels in the game (x2)")
	row.add_child(slider)
	var value: Label = Theme_.label("100 %", Theme_.DIM)
	value.add_theme_font_override("font", Theme_.font(&"mono"))
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(func(amount: float) -> void:
		value.text = "%d %%" % roundi(amount * 100.0)
		if not is_equal_approx(_look.size[axis], amount):
			var resized: Vector2 = _look.size
			resized[axis] = amount
			_look.size = resized)
	parent.add_child(row)
	return slider


func _caption_row(parent: Container, caption: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Theme_.label(caption, Theme_.DIM)
	label.custom_minimum_size.x = 64
	row.add_child(label)
	parent.add_child(row)
	return row


func _refresh_style() -> void:
	if _outline_picker == null:
		return
	_outline_picker.select(_outline_picker.get_item_index(_look.outline_width))
	_outline_color.color = _look.outline_color
	_outline_color.disabled = _look.outline_width == 0
	var count: int = _look.frames if _look.frames > 0 else CcLook.FRAME_CHOICES[0]
	var index: int = _frames_picker.get_item_index(count)
	_frames_picker.select(index if index >= 0 else 0)


func _refresh_size() -> void:
	_refresh_style()
	if _height_slider == null:
		return
	_height_slider.set_value_no_signal(_look.size.y)
	_width_slider.set_value_no_signal(_look.size.x)
	for slider in [_height_slider, _width_slider]:
		slider.value_changed.emit(slider.value)


func _on_look_changed() -> void:
	_refresh_slot_values()
	_refresh_size()
	# Les vignettes prennent la teinte de l'emplacement.
	for button in _parts_grid.get_children():
		for holder in button.get_children():
			for child in holder.get_children():
				if child is TextureRect:
					child.modulate = _look.color(_slot)


func _refresh_slot_values() -> void:
	for slot in _slot_values:
		var part: String = _look.part(slot)
		_slot_values[slot].text = _short_name(part)


# --- Lecture ---

func _turn(step: int) -> void:
	_stage.sprite.direction += step
	_direction_label.text = CcCatalog.DIRECTIONS[_stage.sprite.direction]


func _on_anim_selected(index: int) -> void:
	_stage.sprite.play(_anim_picker.get_item_text(index))
	_set_play_icon(true)


func _toggle_play() -> void:
	var sprite: CcSprite = _stage.sprite
	if sprite.playing:
		sprite.stop()
	else:
		# Une animation sans boucle finie repart du début.
		sprite.play(sprite.animation)
	_set_play_icon(sprite.playing)


func _set_play_icon(playing: bool) -> void:
	_set_tool_icon(_play_button, "Pause" if playing else "Play", "❚❚" if playing else "▶")


# --- En-tête et pied ---

func _randomize() -> void:
	for slot in RANDOM_SLOTS:
		var choices: PackedStringArray = catalog.parts_of(slot)
		if choices.is_empty():
			continue
		var optional: bool = not REQUIRED.has(slot) and slot not in ["head", "chest", "legs", "shoes", "weapon"]
		var part: String = "" if optional and randf() < 0.5 else choices[randi() % choices.size()]
		_look.parts[slot] = part
		if part == "":
			_look.parts.erase(slot)
		var palette: PackedColorArray = SKIN if slot == "body" else GEAR
		_look.colors[slot] = palette[randi() % palette.size()]
	_look.emit_changed()
	_select_slot(_slot)
	_stage.pop()


func _reset() -> void:
	var fresh: CcLook = CcLook.default_look()
	_look.parts = fresh.parts
	_look.colors = fresh.colors
	_look.copy_style(fresh)
	_look.size = Vector2.ONE
	_select_slot(_slot)
	_stage.pop()


func _confirm() -> void:
	confirmed.emit(_look.duplicate_look())


func _save_preset() -> void:
	var file_name: String = _preset_name.text.strip_edges().to_snake_case()
	if file_name == "":
		_set_status(T.t("Give the preset a name first."), "bad")
		return
	DirAccess.make_dir_recursive_absolute(preset_dir)
	var path: String = preset_dir.path_join(file_name + ".tres")
	var error: Error = ResourceSaver.save(_look.duplicate_look(), path)
	if error == OK:
		_set_status(T.t("Saved %s") % path, "good")
	else:
		_set_status(T.t("Could not save %s") % path, "bad")


func _set_status(text: String, meaning: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Theme_.color(meaning))


# --- Petites briques ---

func _display_name(part: String) -> String:
	if part == "":
		return T.t("None")
	var name_part: String = part.replace("NakedBody", "Body")
	var digits: int = name_part.length()
	while digits > 0 and name_part[digits - 1].is_valid_int():
		digits -= 1
	if digits < name_part.length():
		return name_part.left(digits) + " " + name_part.substr(digits)
	return name_part


# Numéro seul dans la colonne des emplacements (Melee 12 -> M12, Head 3 -> 3).
func _short_name(part: String) -> String:
	if part == "":
		return "—"
	var shown: String = _display_name(part)
	var pieces: PackedStringArray = shown.split(" ")
	var number: String = pieces[pieces.size() - 1] if pieces.size() > 1 else "1"
	var prefix: String = pieces[0]
	return (prefix.left(1) + number) if prefix in ["Melee", "Ranged", "Magic", "Shield", "Offhand"] else number


func _button(text: String, tip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	return button


func _tool_button(icon_name: String, fallback: String, tip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = Theme_.TOOL
	button.custom_minimum_size = Vector2(40, 36)
	button.tooltip_text = tip
	button.pressed.connect(action)
	_set_tool_icon(button, icon_name, fallback)
	return button


# Icône de l'éditeur Godot si elle existe (dans l'éditeur), sinon un signe.
func _set_tool_icon(button: Button, icon_name: String, fallback: String) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var editor_theme: Theme = Engine.get_singleton(&"EditorInterface").get_editor_theme()
		if editor_theme != null and editor_theme.has_icon(icon_name, &"EditorIcons"):
			button.icon = editor_theme.get_icon(icon_name, &"EditorIcons")
			button.text = ""
			return
	button.icon = null
	button.text = fallback


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _gap(width: int) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size.x = width
	return gap


# Apparition en cascade des emplacements.
func _cascade() -> void:
	var delay: float = 0.0
	for slot in SLOT_ORDER:
		if not _slot_buttons.has(slot):
			continue
		var button: Button = _slot_buttons[slot]
		button.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(button, "modulate:a", 1.0, 0.18)
		delay += 0.025
