@tool
class_name CcLook
extends Resource

## Apparence d'un personnage : la pièce et la couleur de chaque emplacement
## (CcCatalog.SLOTS) et sa taille. Enregistrable en .tres (personnages du
## développeur) ou en dictionnaire dans un ConfigFile (personnages du
## joueur, to_dict()).

const SIZE_MIN: float = 0.5
const SIZE_MAX: float = 1.5
const OUTLINE_MAX: int = 3
## Nombres d'images proposés (réduction d'images, comme l'outil Unity).
const FRAME_CHOICES: Array[int] = [15, 14, 12, 10, 8, 6, 4]

## Emplacement -> nom de pièce ; absent ou "" : rien.
@export var parts: Dictionary = {}
## Emplacement -> teinte (multipliée, comme SpriteRenderer.color dans Unity).
@export var colors: Dictionary = {}
## Largeur (x) et hauteur (y) du personnage, 1 = taille du pack. Les pieds
## restent en place. Pixel art : une échelle totale non entière (taille x
## échelle du nœud) donne des pixels un peu inégaux.
@export var size: Vector2 = Vector2.ONE:
	set(value):
		size = value.clamp(Vector2(SIZE_MIN, SIZE_MIN), Vector2(SIZE_MAX, SIZE_MAX))
		emit_changed()
## Contour autour de tout le personnage (pas de l'ombre), en pixels du pack ;
## 0 : aucun.
@export_range(0, 3) var outline_width: int = 0:
	set(value):
		outline_width = clampi(value, 0, OUTLINE_MAX)
		emit_changed()
@export var outline_color: Color = Color(0.05, 0.04, 0.06):
	set(value):
		outline_color = value
		emit_changed()
## Images jouées par animation (sur les 15 du pack, même durée) ; 0 :
## toutes. Moins d'images : animation plus saccadée, style rétro.
@export_range(0, 15) var frames: int = 0:
	set(value):
		frames = clampi(value, 0, 15)
		emit_changed()


static func default_look() -> CcLook:
	var look: CcLook = CcLook.new()
	look.parts = {
		"shadow": "Shadow", "body": "NakedBody", "head": "Head1",
		"chest": "Chest1", "legs": "Legs1", "shoes": "Shoes1",
	}
	# Ombre à 70 % comme dans la scène d'exemple du pack.
	look.colors = {"shadow": Color(1, 1, 1, 0.7)}
	return look


func part(slot: String) -> String:
	return String(parts.get(slot, ""))


func color(slot: String) -> Color:
	return colors.get(slot, Color.WHITE)


func set_part(slot: String, part_name: String) -> void:
	if part_name == "":
		parts.erase(slot)
	else:
		parts[slot] = part_name
	emit_changed()


func set_color(slot: String, value: Color) -> void:
	colors[slot] = value
	emit_changed()


func duplicate_look() -> CcLook:
	var copy: CcLook = CcLook.new()
	copy.parts = parts.duplicate()
	copy.colors = colors.duplicate()
	copy.size = size
	copy.copy_style(self)
	return copy


## Reprend le contour et la réduction d'images de [param other].
func copy_style(other: CcLook) -> void:
	outline_width = other.outline_width
	outline_color = other.outline_color
	frames = other.frames


func to_dict() -> Dictionary:
	return {
		"parts": parts.duplicate(), "colors": colors.duplicate(), "size": size,
		"outline_width": outline_width, "outline_color": outline_color, "frames": frames,
	}


static func from_dict(data: Dictionary) -> CcLook:
	var look: CcLook = CcLook.new()
	var stored_parts: Variant = data.get("parts", {})
	var stored_colors: Variant = data.get("colors", {})
	if stored_parts is Dictionary:
		for slot in stored_parts:
			look.parts[String(slot)] = String(stored_parts[slot])
	if stored_colors is Dictionary:
		for slot in stored_colors:
			if stored_colors[slot] is Color:
				look.colors[String(slot)] = stored_colors[slot]
	var stored_size: Variant = data.get("size", Vector2.ONE)
	if stored_size is Vector2:
		look.size = stored_size
	if data.get("outline_width") is int:
		look.outline_width = data["outline_width"]
	if data.get("outline_color") is Color:
		look.outline_color = data["outline_color"]
	if data.get("frames") is int:
		look.frames = data["frames"]
	return look
