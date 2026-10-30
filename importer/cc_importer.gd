@tool
extends RefCounted

## Import du pack Unity « Character Creator - 2D Fantasy » (Small Scale
## Interactive) : lit le .unitypackage (archive tar.gz, extraite avec la
## commande tar du système) ou un dossier déjà extrait, et écrit dans
## [dest] :
## - parts/<pièce>/<animation>.png : chaque image recadrée au plus juste et
##   rangée dans une planche serrée (les cases de 128 px du pack sont
##   surtout vides : beaucoup moins de mémoire vidéo) ;
## - catalog.res (CcCatalog) : animations, boucles, place de chaque image.
## Les planches du pack font 15 images x 8 directions (une ligne par
## direction, CcCatalog.DIRECTIONS) ; les clips .anim ne servent qu'à savoir
## si une animation boucle (toutes vont à 10 images/s).
## Le code Unity et les images ne sont jamais copiés ailleurs que dans
## [dest] : les images du pack ne doivent pas être redistribuées.

const SHEETS_MARK: String = "/spritesheets/"
const CLIPS_MARK: String = "/Animation Clips/"
## Pièce dont les clips donnent les boucles et la liste des animations.
const REFERENCE_PART: String = "NakedBody"
const ATLAS_WIDTH: int = 1024

## progress(ratio 0-1, texte) : appelée pendant l'import (peut venir d'un
## thread : l'appelant passe par call_deferred s'il touche l'interface).
var progress: Callable = Callable()


## Lance l'import ; renvoie "" ou un message d'erreur.
func run(source: String, dest: String) -> String:
	var root: String = source
	var temp: String = ""
	if source.get_extension().to_lower() == "unitypackage":
		temp = OS.get_user_data_dir().path_join("cc_import_tmp")
		_remove_dir(temp)
		DirAccess.make_dir_recursive_absolute(temp)
		_report(0.0, "Extracting the package...")
		var output: Array = []
		var code: int = OS.execute("tar", ["-xzf", ProjectSettings.globalize_path(source), "-C", temp], output, true)
		if code != 0:
			return "tar failed (%d): %s" % [code, "\n".join(output)]
		root = temp
	if not DirAccess.dir_exists_absolute(root):
		return "Source not found: " + source

	_report(0.02, "Reading the package index...")
	var sheets: Dictionary = {}  # pièce -> {animation: chemin du PNG}
	var loops: Dictionary = {}   # animation -> bool
	for guid in DirAccess.get_directories_at(root):
		var folder: String = root.path_join(guid)
		var pathname: String = _first_line(folder.path_join("pathname"))
		var asset: String = folder.path_join("asset")
		if pathname == "" or not FileAccess.file_exists(asset):
			continue
		var sheet_at: int = pathname.find(SHEETS_MARK)
		if sheet_at >= 0 and pathname.ends_with(".png"):
			var rest: PackedStringArray = pathname.substr(sheet_at + SHEETS_MARK.length()).split("/")
			if rest.size() == 2:
				if not sheets.has(rest[0]):
					sheets[rest[0]] = {}
				sheets[rest[0]][rest[1].get_basename()] = asset
			continue
		var clip_at: int = pathname.find(CLIPS_MARK + REFERENCE_PART + "/")
		if clip_at >= 0 and pathname.ends_with("_E.anim"):
			var anim_name: String = pathname.get_file().trim_suffix("_E.anim")
			loops[anim_name] = _clip_loops(asset)

	if not sheets.has(REFERENCE_PART):
		return "No spritesheets found (is it the Character Creator - Fantasy package?)"
	var anims: Array = sheets[REFERENCE_PART].keys()
	anims.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)

	var catalog: CcCatalog = CcCatalog.new()
	catalog.anims = PackedStringArray(anims)
	var loop_flags: PackedByteArray = PackedByteArray()
	for anim in anims:
		loop_flags.append(1 if loops.get(anim, false) else 0)
	catalog.anim_loops = loop_flags

	var part_names: Array = sheets.keys()
	part_names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var total: int = 0
	for part in part_names:
		total += sheets[part].size()
	var done: int = 0
	for part in part_names:
		var slot: String = _slot_of(part)
		if slot == "":
			continue
		var frames: Dictionary = {}
		var part_dir: String = dest.path_join("parts").path_join(part)
		DirAccess.make_dir_recursive_absolute(part_dir)
		for anim in sheets[part]:
			done += 1
			_report(0.05 + 0.93 * done / float(total), "%s / %s" % [part, anim])
			var data: PackedInt32Array = _pack_sheet(sheets[part][anim], part_dir.path_join(anim + ".png"), catalog)
			if not data.is_empty():
				frames[anim] = data
		if not frames.is_empty():
			catalog.parts[part] = {"slot": slot, "frames": frames}
		else:
			# Pièce vide dans le pack (GunFire2-4 : planches transparentes).
			DirAccess.remove_absolute(part_dir)

	_report(0.99, "Saving the catalog...")
	var error: Error = ResourceSaver.save(catalog, dest.path_join("catalog.res"))
	if temp != "":
		_remove_dir(temp)
	if error != OK:
		return "Could not save the catalog (%s)" % error_string(error)
	_report(1.0, "Done: %d parts, %d animations." % [catalog.parts.size(), anims.size()])
	return ""


# Recadre chaque case de la planche, range les images dans une planche
# serrée (rangées successives) et l'enregistre ; renvoie la place de chaque
# image, ou un tableau vide si la planche est vide.
func _pack_sheet(source: String, target: String, catalog: CcCatalog) -> PackedInt32Array:
	var image: Image = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(source)) != OK:
		return PackedInt32Array()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var cell: int = catalog.cell_size
	var rows: int = mini(image.get_height() / cell, CcCatalog.DIRECTIONS.size())
	var cols: int = mini(image.get_width() / cell, catalog.frame_count)
	var used: Array[Rect2i] = []
	var data: PackedInt32Array = PackedInt32Array()
	data.resize(CcCatalog.DIRECTIONS.size() * catalog.frame_count * CcCatalog.STRIDE)
	# Place dans la planche serrée, rangée par rangée.
	var x: int = 0
	var y: int = 0
	var shelf: int = 0
	var any: bool = false
	for row in CcCatalog.DIRECTIONS.size():
		for col in catalog.frame_count:
			var rect: Rect2i = Rect2i()
			if row < rows and col < cols:
				rect = image.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect()
			used.append(rect)
			if rect.size == Vector2i.ZERO:
				continue
			any = true
			if x + rect.size.x > ATLAS_WIDTH:
				x = 0
				y += shelf
				shelf = 0
			var i: int = (row * catalog.frame_count + col) * CcCatalog.STRIDE
			data[i] = x
			data[i + 1] = y
			data[i + 2] = rect.size.x
			data[i + 3] = rect.size.y
			data[i + 4] = rect.position.x
			data[i + 5] = rect.position.y
			x += rect.size.x
			shelf = maxi(shelf, rect.size.y)
	if not any:
		return PackedInt32Array()
	var width: int = ATLAS_WIDTH if y > 0 else x
	var atlas: Image = Image.create(maxi(width, 1), maxi(y + shelf, 1), false, Image.FORMAT_RGBA8)
	for row in CcCatalog.DIRECTIONS.size():
		for col in catalog.frame_count:
			var rect: Rect2i = used[row * catalog.frame_count + col]
			if rect.size == Vector2i.ZERO:
				continue
			var i: int = (row * catalog.frame_count + col) * CcCatalog.STRIDE
			atlas.blit_rect(image, Rect2i(Vector2i(col * cell, row * cell) + rect.position, rect.size), Vector2i(data[i], data[i + 1]))
	atlas.save_png(target)
	return data


func _slot_of(part: String) -> String:
	var prefix: String = part
	while prefix != "" and prefix[prefix.length() - 1].is_valid_int():
		prefix = prefix.left(prefix.length() - 1)
	return String(CcCatalog.SLOT_PREFIXES.get(prefix, ""))


func _clip_loops(path: String) -> bool:
	var text: String = FileAccess.get_file_as_string(path)
	var at: int = text.find("m_LoopTime:")
	return at >= 0 and text.substr(at + 11, 3).strip_edges().begins_with("1")


func _first_line(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).get_slice("\n", 0).strip_edges()


func _report(ratio: float, text: String) -> void:
	if progress.is_valid():
		progress.call(ratio, text)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for folder in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(folder))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
