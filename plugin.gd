@tool
extends EditorPlugin

## Réglage character_creator/catalog_path (où vit le catalogue importé) et
## menu Projet > Outils > Import Character Creator pack : choisit le
## .unitypackage (ou son dossier extrait) et lance l'import dans un thread,
## avec une barre de progression.

const Importer = preload("res://addons/character_creator/importer/cc_importer.gd")
const SETTING: String = "character_creator/catalog_path"
const DEFAULT_CATALOG: String = "res://character_creator/catalog.res"
const MENU: String = "Import Character Creator pack..."

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
	add_tool_menu_item(MENU, _open_dialog)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	for node in [_file_dialog, _progress_dialog]:
		if node != null:
			node.queue_free()


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
