@tool
class_name CcLook
extends Resource

## Apparence d'un personnage : la pièce et la couleur de chaque emplacement
## (CcCatalog.SLOTS) et sa taille. Enregistrable en .tres (personnages du
## développeur) ou en dictionnaire dans un ConfigFile (personnages du
## joueur, to_dict()).

const SIZE_MIN: float = 0.5
const SIZE_MAX: float = 1.5

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
	return copy


func to_dict() -> Dictionary:
	return {"parts": parts.duplicate(), "colors": colors.duplicate(), "size": size}


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
	return look
