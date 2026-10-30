@tool
extends Control

## Onglet « Characters » de l'éditeur (à côté de 2D, 3D, Script) : créer
## vite des personnages (classes, ennemis, PNJ...) rangés en .tres.
## - à gauche : les dossiers du réglage character_creator/editor_folders et
##   leurs fiches ; + crée une fiche dans un dossier ; Duplicate, Rename,
##   Delete sur la fiche choisie ;
## - au centre : son apparence (écran de création intégré) ;
## - à droite : l'Inspector de Godot montre ses autres champs.
## Une fiche est un CcLook, ou toute ressource avec une propriété « look »
## (CcLook) : le jeu définit ses propres types (stats, attaque...). Une
## nouvelle fiche reprend le type des fiches déjà présentes dans le dossier
## (CcLook s'il est vide). Save enregistre la fiche ; elle l'est aussi d'elle-
## même quand on change de fiche ou quitte l'onglet (rien ne se perd).

const Theme_ = preload("res://addons/character_creator/creator/cc_theme.gd")
const T = preload("res://addons/character_creator/i18n/t.gd")
const Creator = preload("res://addons/character_creator/creator/cc_creator.tscn")
const SETTING_FOLDERS: String = "character_creator/editor_folders"
const DEFAULT_CATALOG: String = "res://character_creator/catalog.res"

## Donné par plugin.gd (get_editor_interface() : l'addon reste compatible
## avec les Godot sans singleton EditorInterface).
var editor_interface: EditorInterface

var _tree: Tree
var _creator: Control
var _empty: CenterContainer
var _empty_text: Label
var _add_look_button: Button
var _status: Label
var _save_button: Button
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _delete_dialog: ConfirmationDialog
var _item: Resource
var _item_path: String = ""
# Action du dialogue de nom : "new", "duplicate" ou "rename" ; dossier visé.
var _name_action: String = ""
var _name_folder: String = ""
## Modifications pas encore enregistrées.
var _dirty: bool = false
var _look: CcLook


func _ready() -> void:
	theme = Theme_.build()
	_build()
	editor_interface.get_inspector().property_edited.connect(_on_property_edited)
	editor_interface.get_resource_filesystem().filesystem_changed.connect(_refresh_tree)
	_refresh_tree()


func _exit_tree() -> void:
	if editor_interface == null:
		return
	_save_if_dirty()
	var inspector: EditorInspector = editor_interface.get_inspector()
	if inspector.property_edited.is_connected(_on_property_edited):
		inspector.property_edited.disconnect(_on_property_edited)
	var file_system: EditorFileSystem = editor_interface.get_resource_filesystem()
	if file_system.filesystem_changed.is_connected(_refresh_tree):
		file_system.filesystem_changed.disconnect(_refresh_tree)


## Onglet caché : enregistre la fiche en cours.
func on_hidden() -> void:
	_save_if_dirty()


## Onglet montré : sélectionne la première fiche si rien ne l'est.
func on_shown() -> void:
	if _item == null:
		var first: TreeItem = _first_sheet()
		if first != null:
			first.select(0)
	elif _item != null:
		editor_interface.inspect_object(_item)


# --- Construction ---

func _build() -> void:
	var background: Panel = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", Theme_.box(Theme_.color("ink")))
	add_child(background)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	# Fiches.
	var left: PanelContainer = Theme_.band(Vector4(0, 0, 1, 0), Vector4(10, 12, 10, 10))
	left.custom_minimum_size.x = 250
	row.add_child(left)
	var left_box: VBoxContainer = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left.add_child(left_box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(Theme_.label(T.t("CHARACTERS"), Theme_.KICKER))
	head.add_child(_spacer())
	head.add_child(_tool_button("Reload", T.t("Reload the folders"), _refresh_tree))
	left_box.add_child(head)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_selected)
	_tree.button_clicked.connect(_on_tree_button)
	_tree.item_activated.connect(_ask_name.bind("rename"))
	left_box.add_child(_tree)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(_tool_button("Duplicate", T.t("Duplicate the selected character"), _ask_name.bind("duplicate")))
	actions.add_child(_tool_button("Rename", T.t("Rename the file (its id: maps and saves use it)"), _ask_name.bind("rename")))
	actions.add_child(_tool_button("Remove", T.t("Delete the selected character (moved to the trash)"), _ask_delete))
	left_box.add_child(actions)

	# Apparence.
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	row.add_child(center)
	var stack: Control = Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(stack)
	_creator = Creator.instantiate()
	_creator.embedded = true
	_creator.visible = false
	stack.add_child(_creator)
	_empty = CenterContainer.new()
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_empty)
	var empty_box: VBoxContainer = VBoxContainer.new()
	empty_box.add_theme_constant_override("separation", 10)
	_empty.add_child(empty_box)
	_empty_text = Theme_.label("", Theme_.DIM)
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(_empty_text)
	_add_look_button = Button.new()
	_add_look_button.text = T.t("Add an appearance")
	_add_look_button.theme_type_variation = Theme_.PRIMARY
	_add_look_button.pressed.connect(_add_look)
	empty_box.add_child(_add_look_button)
	var footer: PanelContainer = Theme_.band(Vector4(0, 1, 0, 0), Vector4(14, 6, 14, 6))
	var footer_row: HBoxContainer = HBoxContainer.new()
	footer.add_child(footer_row)
	_status = Theme_.label("", Theme_.DIM)
	_status.add_theme_font_override("font", Theme_.font(&"mono"))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	footer_row.add_child(_status)
	_save_button = Button.new()
	_save_button.text = T.t("Save")
	_save_button.tooltip_text = T.t("Save the character (also saved when you pick another one)")
	_save_button.theme_type_variation = Theme_.PRIMARY
	_save_button.custom_minimum_size = Vector2(96, 30)
	_save_button.disabled = true
	_save_button.pressed.connect(_save_now)
	footer_row.add_child(_save_button)
	center.add_child(footer)

	_name_dialog = ConfirmationDialog.new()
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 320
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(_apply_name)
	add_child(_name_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.confirmed.connect(_delete)
	add_child(_delete_dialog)
	_show_empty(T.t("Pick a character on the left, or press + to create one."), false)


# --- Liste des fiches ---

func _folders() -> PackedStringArray:
	var default_dir: String = String(ProjectSettings.get_setting("character_creator/catalog_path", DEFAULT_CATALOG)).get_base_dir().path_join("presets")
	return PackedStringArray(ProjectSettings.get_setting(SETTING_FOLDERS, PackedStringArray([default_dir])))


func _refresh_tree() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var add_icon: Texture2D = _editor_icon("Add")
	for folder in _folders():
		var group: TreeItem = _tree.create_item(root)
		group.set_text(0, folder.get_file().capitalize().to_upper())
		group.set_tooltip_text(0, folder)
		group.set_selectable(0, false)
		group.set_custom_color(0, Theme_.color("accent"))
		group.set_custom_font(0, Theme_.font(&"condensed"))
		group.set_metadata(0, folder)
		if add_icon != null:
			group.add_button(0, add_icon, 0, false, T.t("New character in %s") % folder)
		var files: PackedStringArray = _sheet_files(folder)
		if files.is_empty():
			var hint: TreeItem = _tree.create_item(group)
			hint.set_text(0, T.t("empty: press +"))
			hint.set_custom_color(0, Theme_.color("sand_dim"))
			hint.set_selectable(0, false)
		for file in files:
			var path: String = folder.path_join(file)
			var sheet: TreeItem = _tree.create_item(group)
			sheet.set_text(0, _sheet_label(path))
			sheet.set_tooltip_text(0, path)
			sheet.set_metadata(0, path)
			if path == _item_path:
				sheet.select(0)


func _sheet_files(folder: String) -> PackedStringArray:
	var result: Array = []
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.get_extension() == "tres":
				result.append(file)
	result.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return PackedStringArray(result)


# Nom affiché (display_name s'il existe) et identifiant (nom du fichier).
func _sheet_label(path: String) -> String:
	var id: String = path.get_file().get_basename()
	var sheet: Resource = load(path)
	var shown: Variant = sheet.get("display_name") if sheet != null else null
	if shown is String and shown != "" and shown != id:
		return "%s  ·  %s" % [shown, id]
	return id


func _first_sheet() -> TreeItem:
	var root: TreeItem = _tree.get_root()
	if root == null:
		return null
	for group in root.get_children():
		for sheet in group.get_children():
			if sheet.is_selectable(0):
				return sheet
	return null


func _on_tree_selected() -> void:
	var selected: TreeItem = _tree.get_selected()
	if selected != null and selected.get_metadata(0) is String:
		_select(String(selected.get_metadata(0)))


func _on_tree_button(item: TreeItem, _column: int, _id: int, _mouse: int) -> void:
	_name_folder = String(item.get_metadata(0))
	_ask_name("new")


# --- Fiche choisie ---

func _select(path: String) -> void:
	if path != _item_path:
		_save_if_dirty()
	_item_path = path
	_item = load(path)
	if _look != null and _look.changed.is_connected(_mark_dirty):
		_look.changed.disconnect(_mark_dirty)
	_look = null
	if _item == null:
		_show_empty(T.t("Could not load %s") % path, false)
		return
	editor_interface.inspect_object(_item)
	var look: CcLook = _look_of(_item)
	if look != null:
		_look = look
		_look.changed.connect(_mark_dirty)
	if look == null:
		var can_add: bool = "look" in _item
		_show_empty(T.t("No appearance: drawn with simple shapes in the game.") if can_add else T.t("This resource has no appearance."), can_add)
	else:
		_empty.visible = false
		_creator.visible = true
		_creator.set_look(look, _sheet_label(path))
	_show_dirty()


func _look_of(sheet: Resource) -> CcLook:
	if sheet is CcLook:
		return sheet
	if "look" in sheet:
		return sheet.get("look") as CcLook
	return null


func _show_empty(text: String, can_add: bool) -> void:
	_creator.visible = false
	_empty.visible = true
	_empty_text.text = text
	_add_look_button.visible = can_add


func _add_look() -> void:
	if _item == null:
		return
	_item.set("look", CcLook.default_look())
	_dirty = true
	_select(_item_path)


# --- Enregistrement ---

func _on_property_edited(property: String) -> void:
	if _item == null or editor_interface.get_inspector().get_edited_object() != _item:
		return
	_mark_dirty()
	# Apparence posée ou retirée depuis l'Inspector.
	if property == "look":
		_select.call_deferred(_item_path)


func _mark_dirty() -> void:
	_dirty = true
	_show_dirty()


func _show_dirty() -> void:
	_save_button.disabled = not _dirty
	if _item_path == "":
		return
	if _dirty:
		_set_status("● " + T.t("%s: unsaved changes") % _item_path, "info")
	else:
		_set_status(_item_path, "sand_dim")


func _save_if_dirty() -> void:
	if _dirty:
		_save_now()


func _save_now() -> void:
	if _item == null or _item_path == "":
		return
	var error: Error = ResourceSaver.save(_item, _item_path)
	if error == OK:
		_dirty = false
		_save_button.disabled = true
		_set_status(T.t("Saved %s") % _item_path, "good")
	else:
		_set_status(T.t("Could not save %s") % _item_path, "bad")


func _set_status(text: String, meaning: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Theme_.color(meaning))


# --- Nouveau, dupliquer, renommer, supprimer ---

func _ask_name(action: String) -> void:
	if action != "new" and _item == null:
		return
	_name_action = action
	if action != "new":
		_name_folder = _item_path.get_base_dir()
	var titles: Dictionary = {"new": T.t("New character"), "duplicate": T.t("Duplicate"), "rename": T.t("Rename")}
	_name_dialog.title = titles[action]
	_name_edit.placeholder_text = T.t("file name, e.g. orc_chief")
	_name_edit.text = "" if action == "new" else _item_path.get_file().get_basename() + ("_copy" if action == "duplicate" else "")
	_name_dialog.popup_centered()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _apply_name() -> void:
	_name_dialog.hide()
	var file_name: String = _name_edit.text.strip_edges().to_snake_case().validate_filename()
	if file_name == "":
		_set_status(T.t("Give it a name first."), "bad")
		return
	var path: String = _name_folder.path_join(file_name + ".tres")
	if FileAccess.file_exists(path):
		_set_status(T.t("%s already exists.") % path, "bad")
		return
	DirAccess.make_dir_recursive_absolute(_name_folder)
	if _name_action != "rename":
		_save_if_dirty()
	var error: Error = OK
	match _name_action:
		"new":
			error = ResourceSaver.save(_new_sheet(_name_folder, file_name), path)
		"duplicate":
			error = ResourceSaver.save(_item.duplicate(true), path)
		"rename":
			error = DirAccess.rename_absolute(_item_path, path)
			if error == OK:
				_item.take_over_path(path)
	if error != OK:
		_set_status(T.t("Could not write %s (%s)") % [path, error_string(error)], "bad")
		return
	_item_path = path
	_set_status(path, "good")
	editor_interface.get_resource_filesystem().scan()
	_refresh_tree()
	_select(path)


# Fiche vierge du type des fiches du dossier (CcLook s'il est vide), avec
# l'apparence de départ.
func _new_sheet(folder: String, file_name: String) -> Resource:
	var template: Resource = null
	for file in _sheet_files(folder):
		template = load(folder.path_join(file))
		if template != null:
			break
	if template == null or template is CcLook or template.get_script() == null:
		return CcLook.default_look()
	var sheet: Resource = template.get_script().new()
	if "look" in sheet:
		sheet.set("look", CcLook.default_look())
	if "display_name" in sheet:
		sheet.set("display_name", file_name.capitalize())
	return sheet


func _ask_delete() -> void:
	if _item == null:
		return
	_delete_dialog.dialog_text = T.t("Move %s to the trash?") % _item_path
	_delete_dialog.popup_centered()


func _delete() -> void:
	var path: String = _item_path
	var error: Error = OS.move_to_trash(ProjectSettings.globalize_path(path))
	if error != OK:
		_set_status(T.t("Could not delete %s") % path, "bad")
		return
	_item = null
	_item_path = ""
	_dirty = false
	_save_button.disabled = true
	editor_interface.inspect_object(null)
	_show_empty(T.t("Pick a character on the left, or press + to create one."), false)
	_set_status(T.t("Moved %s to the trash") % path, "info")
	editor_interface.get_resource_filesystem().scan()
	_refresh_tree()


# --- Petites briques ---

func _tool_button(icon_name: String, tip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = Theme_.TOOL
	button.tooltip_text = tip
	button.icon = _editor_icon(icon_name)
	if button.icon == null:
		button.text = icon_name
	button.pressed.connect(action)
	return button


func _editor_icon(icon_name: String) -> Texture2D:
	var base: Control = editor_interface.get_base_control() if editor_interface != null else null
	if base != null and base.has_theme_icon(icon_name, &"EditorIcons"):
		return base.get_theme_icon(icon_name, &"EditorIcons")
	return null


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer
