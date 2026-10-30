class_name CcBaker
extends RefCounted

## Fusion d'un personnage : tous ses calques teintés dessinés en une seule
## planche par animation (rendu par la carte graphique dans un SubViewport),
## enregistrée dans [out_dir] avec son catalogue. En jeu, une unité n'a plus
## qu'une texture par animation au lieu d'une par calque.
## Les couleurs de la planche sont prémultipliées par l'alpha (résultat
## direct du rendu sur fond transparent) ; CcSprite le sait par
## catalog.premultiplied.
## Usage (dans une fonction async, [host] dans l'arbre, rendu actif) :
##   var baked: CcCatalog = await CcBaker.bake(look, catalog, self, "user://characters/hero")
##   sprite.catalog = baked
##   sprite.look = CcBaker.baked_look(look)
## La taille (look.size) n'est pas cuite dans la planche : baked_look() la
## reprend et CcSprite l'applique à l'affichage.

const PART: String = "baked"
const ATLAS_WIDTH: int = 1024


## [anims] vide : toutes les animations du catalogue. Renvoie null si rien
## n'a pu être enregistré.
static func bake(look: CcLook, catalog: CcCatalog, host: Node, out_dir: String, anims: PackedStringArray = PackedStringArray()) -> CcCatalog:
	if anims.is_empty():
		anims = catalog.anims
	var part_dir: String = out_dir.path_join("parts").path_join(PART)
	DirAccess.make_dir_recursive_absolute(part_dir)
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var painter: Node2D = Node2D.new()
	viewport.add_child(painter)
	host.add_child(viewport)
	# Dessins de l'animation en cours : [texture, rect source, rect cible, teinte].
	var commands: Array = []
	painter.draw.connect(func() -> void:
		for command in commands:
			painter.draw_texture_rect_region(command[0], command[2], command[1], command[3]))

	var result: CcCatalog = CcCatalog.new()
	result.cell_size = catalog.cell_size
	result.frame_count = catalog.frame_count
	result.fps = catalog.fps
	result.pivot = catalog.pivot
	result.premultiplied = true
	var frames: Dictionary = {}
	var baked_anims: PackedStringArray = PackedStringArray()
	var loops: PackedByteArray = PackedByteArray()
	for anim in anims:
		var layers: Array = []  # [texture, données, teinte]
		for slot in CcCatalog.SLOTS:
			var part: String = look.part(slot)
			var data: PackedInt32Array = catalog.frames(part, anim) if part != "" else PackedInt32Array()
			var texture: Texture2D = catalog.texture(part, anim) if not data.is_empty() else null
			if texture != null:
				layers.append([texture, data, look.color(slot)])
		if layers.is_empty():
			continue
		commands.clear()
		var out: PackedInt32Array = PackedInt32Array()
		out.resize(CcCatalog.DIRECTIONS.size() * catalog.frame_count * CcCatalog.STRIDE)
		var x: int = 0
		var y: int = 0
		var shelf: int = 0
		for dir in CcCatalog.DIRECTIONS.size():
			for frame in catalog.frame_count:
				# Cadre commun à tous les calques de cette image.
				var bounds: Rect2i = Rect2i()
				for layer in layers:
					var rect: Rect2i = catalog.frame_rect(layer[1], dir, frame)
					if rect.size == Vector2i.ZERO:
						continue
					var placed: Rect2i = Rect2i(catalog.frame_offset(layer[1], dir, frame), rect.size)
					bounds = placed if bounds.size == Vector2i.ZERO else bounds.merge(placed)
				if bounds.size == Vector2i.ZERO:
					continue
				if x + bounds.size.x > ATLAS_WIDTH:
					x = 0
					y += shelf
					shelf = 0
				var i: int = (dir * catalog.frame_count + frame) * CcCatalog.STRIDE
				out[i] = x
				out[i + 1] = y
				out[i + 2] = bounds.size.x
				out[i + 3] = bounds.size.y
				out[i + 4] = bounds.position.x
				out[i + 5] = bounds.position.y
				for layer in layers:
					var rect: Rect2i = catalog.frame_rect(layer[1], dir, frame)
					if rect.size == Vector2i.ZERO:
						continue
					var at: Vector2i = Vector2i(x, y) + catalog.frame_offset(layer[1], dir, frame) - bounds.position
					commands.append([layer[0], Rect2(rect), Rect2(at, rect.size), layer[2]])
				x += bounds.size.x
				shelf = maxi(shelf, bounds.size.y)
		if commands.is_empty():
			continue
		viewport.size = Vector2i(ATLAS_WIDTH if y > 0 else x, y + shelf)
		painter.queue_redraw()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		if image == null or image.is_empty():
			continue
		image.save_png(part_dir.path_join(anim + ".png"))
		frames[anim] = out
		baked_anims.append(anim)
		loops.append(1 if catalog.is_loop(anim) else 0)
	viewport.queue_free()
	if frames.is_empty():
		return null
	result.anims = baked_anims
	result.anim_loops = loops
	result.parts = {PART: {"slot": "body", "frames": frames}}
	var path: String = out_dir.path_join("catalog.res")
	if ResourceSaver.save(result, path) != OK:
		return null
	# Le chemin situe les planches (root_dir) ; FLAG_CHANGE_PATH ne le pose
	# pas hors de res://.
	result.resource_path = path
	return result


## Apparence qui montre la planche fusionnée, à la taille de [param source].
static func baked_look(source: CcLook = null) -> CcLook:
	var look: CcLook = CcLook.new()
	look.parts = {"body": PART}
	if source != null:
		look.size = source.size
	return look
