extends SceneTree

## Import en ligne de commande (même travail que Projet > Outils > Import
## Character Creator pack) :
## godot --headless --path <projet> -s res://addons/character_creator/importer/import_cli.gd -- --source=<.unitypackage ou dossier extrait> [--dest=res://...]
## Sans --dest : le dossier du réglage character_creator/catalog_path.

const Importer = preload("res://addons/character_creator/importer/cc_importer.gd")
const DEFAULT_CATALOG: String = "res://character_creator/catalog.res"


func _init() -> void:
	var source: String = ""
	var dest: String = String(ProjectSettings.get_setting("character_creator/catalog_path", DEFAULT_CATALOG)).get_base_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		elif arg.begins_with("--dest="):
			dest = arg.trim_prefix("--dest=")
	if source == "":
		printerr("Missing --source=<.unitypackage or extracted folder>")
		quit(1)
		return
	var importer: Importer = Importer.new()
	var last: Array = [-1]
	importer.progress = func(ratio: float, text: String) -> void:
		var percent: int = int(ratio * 100.0)
		if percent != last[0]:
			last[0] = percent
			print("%3d %% %s" % [percent, text])
	var started: int = Time.get_ticks_msec()
	var error: String = importer.run(source, dest)
	if error != "":
		printerr(error)
		quit(1)
		return
	print("Imported into %s in %d s" % [dest, (Time.get_ticks_msec() - started) / 1000])
	quit(0)
