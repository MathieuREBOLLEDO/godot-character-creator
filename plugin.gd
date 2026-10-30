@tool
extends EditorPlugin

## Réglages character_creator/catalog_path (où vit le catalogue importé) et
## character_creator/editor_folders (dossiers de fiches de l'onglet
## Characters), onglet « Characters » (editor/cc_editor_tab.gd) et menu
## Projet > Outils > Import Character Creator pack : choisit le
## .unitypackage (ou son dossier extrait) et lance l'import dans un thread,
## avec une barre de progression.

const Importer = preload("res://addons/character_creator/importer/cc_importer.gd")
const EditorTab = preload("res://addons/character_creator/editor/cc_editor_tab.gd")
const SETTING: String = "character_creator/catalog_path"
const DEFAULT_CATALOG: String = "res://character_creator/catalog.res"
const SETTING_FOLDERS: String = "character_creator/editor_folders"
const DEFAULT_FOLDERS: PackedStringArray = ["res://character_creator/presets"]
const MENU: String = "Import Character Creator pack..."

var _tab: EditorTab
var _file_dialog: EditorFileDialog
var _progress_dialog: AcceptDialog
var _progress_bar: ProgressBar
var _progress_label: Label
var _thread: Thread


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, DEFAULT_CATALOG)
	ProjectSettings.set_initial_value(SETTING, DEFAULT_CATALOG)
	ProjectSettings.add_property_info({"name": SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.res"})
	if not ProjectSettings.has_setting(SETTING_FOLDERS):
		ProjectSettings.set_setting(SETTING_FOLDERS, DEFAULT_FOLDERS)
	ProjectSettings.set_initial_value(SETTING_FOLDERS, DEFAULT_FOLDERS)
	ProjectSettings.add_property_info({"name": SETTING_FOLDERS, "type": TYPE_PACKED_STRING_ARRAY, "hint": PROPERTY_HINT_TYPE_STRING, "hint_string": "%d/%d:" % [TYPE_STRING, PROPERTY_HINT_DIR]})
	add_tool_menu_item(MENU, _open_dialog)
	_tab = EditorTab.new()
	_tab.editor_interface = get_editor_interface()
	_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	get_editor_interface().get_editor_main_screen().add_child(_tab)
	_make_visible(false)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	if _tab != null:
		_tab.queue_free()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	for node in [_file_dialog, _progress_dialog]:
		if node != null:
			node.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _tab == null:
		return
	_tab.visible = visible
	if visible:
		_tab.on_shown()
	else:
		_tab.on_hidden()


func _get_plugin_name() -> String:
	return "Characters"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon(&"CharacterBody2D", &"EditorIcons")


func _open_dialog() -> void:
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_ANY
		_file_dialog.title = "Character Creator - 2D Fantasy (.unitypackage or extracted folder)"
		_file_dialog.add_filter("*.unitypackage", "Unity package")
		_file_dialog.file_selected.connect(_start)
		_file_dialog.dir_selected.connect(_start)
		get_editor_interface().get_base_control().add_child(_file_dialog)
	_file_dialog.popup_file_dialog()


func _start(source: String) -> void:
	if _thread != null and _thread.is_started():
		return
	if _progress_dialog == null:
		_progress_dialog = AcceptDialog.new()
		_progress_dialog.title = "Character Creator import"
		var box: VBoxContainer = VBoxContainer.new()
		box.custom_minimum_size = Vector2(420, 0)
		_progress_label = Label.new()
		_progress_bar = ProgressBar.new()
		_progress_bar.max_value = 1.0
		box.add_child(_progress_label)
		box.add_child(_progress_bar)
		_progress_dialog.add_child(box)
		get_editor_interface().get_base_control().add_child(_progress_dialog)
	_progress_dialog.get_ok_button().disabled = true
	_progress_bar.value = 0.0
	_progress_label.text = "Starting..."
	_progress_dialog.popup_centered()
	var dest: String = String(ProjectSettings.get_setting(SETTING, DEFAULT_CATALOG)).get_base_dir()
	_thread = Thread.new()
	_thread.start(_run.bind(source, dest))


func _run(source: String, dest: String) -> void:
	var importer: Importer = Importer.new()
	importer.progress = func(ratio: float, text: String) -> void:
		_show_progress.call_deferred(ratio, text)
	var error: String = importer.run(source, dest)
	_finish.call_deferred(error)


func _show_progress(ratio: float, text: String) -> void:
	_progress_bar.value = ratio
	_progress_label.text = text


func _finish(error: String) -> void:
	_thread.wait_to_finish()
	_progress_dialog.get_ok_button().disabled = false
	if error != "":
		_progress_label.text = error
	get_editor_interface().get_resource_filesystem().scan()
