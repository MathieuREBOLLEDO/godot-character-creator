@tool
class_name CcSprite
extends Node2D

## Personnage à calques : un Sprite2D interne par emplacement
## (CcCatalog.SLOTS, du dessous au dessus), tous sur la même image de la
## même animation. L'origine du nœud est aux pieds (CcCatalog.pivot).
## Pour un personnage fusionné (CcBaker), catalog = le catalogue fusionné et
## look = CcBaker.baked_look() : un seul calque.

signal animation_finished(anim: String)

@export var catalog: CcCatalog:
	set(value):
		catalog = value
		_refresh()
@export var look: CcLook:
	set(value):
		if look != null and look.changed.is_connected(_refresh):
			look.changed.disconnect(_refresh)
		look = value
		if look != null:
			look.changed.connect(_refresh)
		_refresh()
@export var animation: String = "Idle":
	set(value):
		animation = value
		_time = 0.0
		_finished = false
		_refresh()
## Ligne des planches : 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE.
@export_enum("E", "SE", "S", "SW", "W", "NW", "N", "NE") var direction: int = 2:
	set(value):
		direction = posmod(value, 8)
		_refresh()
@export var playing: bool = true
@export var speed_scale: float = 1.0

var frame: int = 0:
	set(value):
		frame = value
		_refresh()

var _layers: Dictionary = {}  # emplacement -> Sprite2D
var _time: float = 0.0
var _finished: bool = false
var _premult: CanvasItemMaterial = null


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_refresh()


## Joue [param anim] ; [param dir] -1 garde la direction.
func play(anim: String, dir: int = -1) -> void:
	if dir >= 0:
		direction = dir
	animation = anim
	playing = true


func stop() -> void:
	playing = false


## Direction (0-7) la plus proche d'un vecteur (y vers le bas).
static func direction_from_vector(vector: Vector2) -> int:
	return posmod(roundi(vector.angle() / (PI / 4.0)), 8)


func _process(delta: float) -> void:
	if not playing or catalog == null or _finished:
		return
	_time += delta * speed_scale
	var index: int = int(_time * catalog.fps)
	if index >= catalog.frame_count:
		if catalog.is_loop(animation):
			_time = fmod(_time, catalog.frame_count / catalog.fps)
			index %= catalog.frame_count
		else:
			index = catalog.frame_count - 1
			_finished = true
	if index != frame:
		frame = index
	if _finished:
		animation_finished.emit(animation)


func _refresh() -> void:
	if not is_inside_tree():
		return
	for slot in CcCatalog.SLOTS:
		var part: String = look.part(slot) if look != null else ""
		var data: PackedInt32Array = catalog.frames(part, animation) if catalog != null and part != "" else PackedInt32Array()
		var rect: Rect2i = catalog.frame_rect(data, direction, frame) if not data.is_empty() else Rect2i()
		if rect.size == Vector2i.ZERO:
			if _layers.has(slot):
				_layers[slot].visible = false
			continue
		var layer: Sprite2D = _layer(slot)
		layer.visible = true
		layer.texture = catalog.texture(part, animation)
		layer.region_rect = Rect2(rect)
		# Taille de l'apparence autour des pieds (l'origine du nœud).
		var stretch: Vector2 = look.size
		layer.scale = stretch
		layer.position = (Vector2(catalog.frame_offset(data, direction, frame)) - catalog.pivot) * stretch
		layer.modulate = look.color(slot)
		layer.material = _premultiplied() if catalog.premultiplied else null


# Calques créés tous ensemble au premier besoin : l'ordre des enfants
# internes est l'ordre de dessin.
func _layer(slot: String) -> Sprite2D:
	if _layers.is_empty():
		for each in CcCatalog.SLOTS:
			var layer: Sprite2D = Sprite2D.new()
			layer.name = each
			layer.centered = false
			layer.region_enabled = true
			layer.visible = false
			add_child(layer, false, Node.INTERNAL_MODE_FRONT)
			_layers[each] = layer
	return _layers[slot]


# Matériau des planches fusionnées (un par nœud : une ressource gardée dans
# une variable statique fait planter Godot à la fermeture).
func _premultiplied() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult
