extends Control

## Scène de l'écran de création : sol en losanges isométriques, vignettage
## et le personnage (CcSprite) à une échelle entière, les pieds au tiers
## bas. Glisser horizontalement tourne le personnage.

const Theme_ = preload("res://addons/character_creator/creator/cc_theme.gd")

signal turned(step: int)

## Largeur glissée pour tourner d'une direction.
const DRAG_STEP: float = 48.0

var sprite: CcSprite = CcSprite.new()
var _drag_from: float = NAN
var _vignette: GradientTexture2D


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sprite)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(Theme_.color("ink"), 0.0))
	gradient.set_color(1, Color(Theme_.color("ink"), 0.85))
	gradient.set_offset(0, 0.45)
	_vignette = GradientTexture2D.new()
	_vignette.gradient = gradient
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.55)
	_vignette.fill_to = Vector2(1.05, 1.05)


## Petit rebond du personnage (retour quand on change une pièce).
func pop() -> void:
	var base: Vector2 = sprite.scale
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", base * 1.06, 0.06)
	tween.tween_property(sprite, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var cell: float = 128.0 if sprite.catalog == null else float(sprite.catalog.cell_size)
		var zoom: int = maxi(1, floori(minf(size.x, size.y) / cell))
		sprite.scale = Vector2(zoom, zoom)
		sprite.position = Vector2(size.x * 0.5, size.y * 0.66)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Theme_.color("ink"))
	# Sol : losanges de 2:1 centrés sous les pieds, plus nets près du centre.
	var line: Color = Theme_.color("ink_line")
	var center: Vector2 = sprite.position
	var half: Vector2 = Vector2(32, 16) * sprite.scale.x
	var along_a: Vector2 = Vector2(half.x, half.y)   # bords haut-droit / bas-gauche
	var along_b: Vector2 = Vector2(half.x, -half.y)  # bords haut-gauche / bas-droit
	for k in range(-6, 7):
		var color: Color = Color(line, 0.6 * (1.0 - absf(k) / 7.0))
		var base_a: Vector2 = center + Vector2(0, -half.y) + k * Vector2(-half.x, half.y)
		var base_b: Vector2 = center + Vector2(-half.x, 0) + k * along_a
		draw_line(base_a - along_a * 8.0, base_a + along_a * 8.0, color, 1.0)
		draw_line(base_b - along_b * 8.0, base_b + along_b * 8.0, color, 1.0)
	# Case sous le personnage, cernée de l'accent : c'est lui qu'on règle.
	var tile: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -half.y), center + Vector2(half.x, 0),
		center + Vector2(0, half.y), center + Vector2(-half.x, 0), center + Vector2(0, -half.y),
	])
	draw_polyline(tile, Color(Theme_.color("accent"), 0.45), 1.0)
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = event.position.x if event.pressed else NAN
	elif event is InputEventScreenTouch:
		_drag_from = event.position.x if event.pressed else NAN
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and not is_nan(_drag_from):
		var moved: float = event.position.x - _drag_from
		if absf(moved) >= DRAG_STEP:
			turned.emit(1 if moved < 0.0 else -1)
			_drag_from = event.position.x
