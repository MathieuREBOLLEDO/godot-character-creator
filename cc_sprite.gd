@tool
class_name CcSprite
extends Node2D

## Personnage à calques : un Sprite2D interne par emplacement
## (CcCatalog.SLOTS, du dessous au dessus), tous sur la même image de la
## même animation. L'origine du nœud est aux pieds (CcCatalog.pivot).
## Pour un personnage fusionné (CcBaker), catalog = le catalogue fusionné et
## look = CcBaker.baked_look(look) : un seul calque.
## L'apparence règle aussi la taille, le contour (CanvasGroup + shader
## cc_outline, autour de tout sauf l'ombre) et la réduction d'images (moins
## d'images, même durée).

signal animation_finished(anim: String)

const OUTLINE_SHADER: Shader = preload("res://addons/character_creator/cc_outline.gdshader")

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

## Image des planches affichée (0 à catalog.frame_count - 1).
var frame: int = 0:
	set(value):
		frame = value
		_refresh()

var _layers: Dictionary = {}  # emplacement -> Sprite2D
# Calques sauf l'ombre : Node2D, ou CanvasGroup quand il y a un contour.
var _body: Node2D
var _time: float = 0.0
var _finished: bool = false
var _premult: CanvasItemMaterial = null
var _outline: ShaderMaterial = null


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


## Images jouées par animation (réduction d'images de l'apparence).
func shown_frames() -> int:
	if catalog == null:
		return 1
	var wanted: int = look.frames if look != null else 0
	return wanted if wanted > 0 and wanted < catalog.frame_count else catalog.frame_count


func _process(delta: float) -> void:
	if _body is CanvasGroup:
		_update_outline_scale()
	if not playing or catalog == null or _finished:
		return
	_time += delta * speed_scale
	# Moins d'images, même durée : on avance plus lentement et on saute des
	# images des planches.
	var shown: int = shown_frames()
	var rate: float = catalog.fps * shown / catalog.frame_count
	var index: int = int(_time * rate)
	if index >= shown:
		if catalog.is_loop(animation):
			_time = fmod(_time, shown / rate)
			index %= shown
		else:
			index = shown - 1
			_finished = true
	var source: int = index * catalog.frame_count / shown
	if source != frame:
		frame = source
	if _finished:
		animation_finished.emit(animation)


func _refresh() -> void:
	if not is_inside_tree():
		return
	_update_body()
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


func _layer(slot: String) -> Sprite2D:
	return _layers[slot]


# Calques créés tous ensemble au premier besoin, dans l'ordre de dessin :
# l'ombre directement sous le nœud, puis _body avec les autres.
func _ensure_layers() -> void:
	if not _layers.is_empty():
		return
	for each in CcCatalog.SLOTS:
		var layer: Sprite2D = Sprite2D.new()
		layer.name = each
		layer.centered = false
		layer.region_enabled = true
		layer.visible = false
		_layers[each] = layer
		if each == "shadow":
			add_child(layer, false, Node.INTERNAL_MODE_FRONT)
			_body = Node2D.new()
			_body.name = "Body"
			add_child(_body, false, Node.INTERNAL_MODE_FRONT)
		else:
			_body.add_child(layer)


# _body est un CanvasGroup (avec le shader de contour) seulement quand
# l'apparence a un contour : sinon, pas de rendu en plus.
func _update_body() -> void:
	_ensure_layers()
	var wants_group: bool = look != null and look.outline_width > 0
	if (_body is CanvasGroup) != wants_group:
		var body: Node2D = CanvasGroup.new() if wants_group else Node2D.new()
		body.name = "Body"
		add_child(body, false, Node.INTERNAL_MODE_FRONT)
		for child in _body.get_children():
			child.reparent(body, false)
		_body.queue_free()
		_body = body
	if wants_group:
		if _outline == null:
			_outline = ShaderMaterial.new()
			_outline.shader = OUTLINE_SHADER
		_body.material = _outline
		_outline.set_shader_parameter("outline_color", look.outline_color)
		_outline.set_shader_parameter("width", look.outline_width)
		_update_outline_scale()


# Pixels d'écran par pixel du pack (échelle globale, caméra comprise).
func _update_outline_scale() -> void:
	var pixel: float = absf(get_global_transform_with_canvas().get_scale().x) * (look.size.x if look != null else 1.0)
	_outline.set_shader_parameter("pixel", pixel)
	(_body as CanvasGroup).fit_margin = (look.outline_width + 1) * pixel


# Matériau des planches fusionnées (un par nœud : une ressource gardée dans
# une variable statique fait planter Godot à la fermeture).
func _premultiplied() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult
