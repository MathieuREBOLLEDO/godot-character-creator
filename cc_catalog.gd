@tool
class_name CcCatalog
extends Resource

## Catalogue des pièces importées (importer/cc_importer.gd) : pour chaque
## pièce, son emplacement et, par animation, la place de chaque image dans
## sa planche serrée (parts/<pièce>/<animation>.png à côté du catalogue).
## Un personnage fusionné (CcBaker) est aussi un catalogue, d'une seule
## pièce « baked ».

## Emplacements, dans l'ordre de dessin (du dessous au dessus), repris de la
## scène d'exemple du pack. Un emplacement porte une pièce à la fois.
const SLOTS: PackedStringArray = [
	"shadow", "body", "shoes", "legs", "mount", "chest", "belt", "hands",
	"offhand", "bag", "weapon", "head", "slash", "effect", "gunfire",
]
## Préfixe des dossiers du pack -> emplacement.
const SLOT_PREFIXES: Dictionary = {
	"Shadow": "shadow",
	"NakedBody": "body",
	"Shoes": "shoes",
	"Legs": "legs",
	"Mount": "mount",
	"Chest": "chest",
	"Belt": "belt",
	"Hands": "hands",
	"Shield": "offhand",
	"Offhand": "offhand",
	"Bag": "bag",
	"Melee": "weapon",
	"Ranged": "weapon",
	"Magic": "weapon",
	"Head": "head",
	"Slash": "slash",
	"Effect": "effect",
	"GunFire": "gunfire",
}
## Lignes des planches du pack : une direction par ligne.
const DIRECTIONS: PackedStringArray = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
## Valeurs par image dans les tableaux de frames : x, y, largeur, hauteur
## dans la planche serrée, puis x, y du coin dans la case d'origine.
const STRIDE: int = 6

@export var cell_size: int = 128
@export var frame_count: int = 15
@export var fps: float = 10.0
## Point de la case posé sur l'origine du CcSprite (les pieds).
@export var pivot: Vector2 = Vector2(64, 84)
@export var anims: PackedStringArray = []
## 1 si l'animation boucle (m_LoopTime des clips Unity).
@export var anim_loops: PackedByteArray = []
## Nom de pièce -> {"slot": String, "frames": {animation: PackedInt32Array}}.
@export var parts: Dictionary = {}
## Vrai pour une planche fusionnée : couleurs prémultipliées par l'alpha.
@export var premultiplied: bool = false

var _textures: Dictionary = {}


## Dossier du catalogue : les planches sont dans parts/ à côté.
func root_dir() -> String:
	return resource_path.get_base_dir()


func is_loop(anim: String) -> bool:
	var index: int = anims.find(anim)
	return index >= 0 and index < anim_loops.size() and anim_loops[index] == 1


## Pièces d'un emplacement, triées dans l'ordre naturel (Head2 avant Head10).
func parts_of(slot: String) -> PackedStringArray:
	var result: Array = []
	for part in parts:
		if parts[part]["slot"] == slot:
			result.append(part)
	result.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return PackedStringArray(result)


## Images d'une pièce pour une animation ; vide si la pièce ne l'a pas.
func frames(part: String, anim: String) -> PackedInt32Array:
	if not parts.has(part):
		return PackedInt32Array()
	return parts[part]["frames"].get(anim, PackedInt32Array())


## Image [param frame] de la direction [param dir] : Rect2i(planche) et coin
## dans la case, ou une taille nulle si l'image est vide.
func frame_rect(data: PackedInt32Array, dir: int, frame: int) -> Rect2i:
	var i: int = (dir * frame_count + frame) * STRIDE
	if data.size() < i + STRIDE:
		return Rect2i()
	return Rect2i(data[i], data[i + 1], data[i + 2], data[i + 3])


func frame_offset(data: PackedInt32Array, dir: int, frame: int) -> Vector2i:
	var i: int = (dir * frame_count + frame) * STRIDE
	if data.size() < i + STRIDE:
		return Vector2i.ZERO
	return Vector2i(data[i + 4], data[i + 5])


func texture_path(part: String, anim: String) -> String:
	return root_dir().path_join("parts").path_join(part).path_join(anim + ".png")


## Planche d'une pièce. res:// : ressource importée ; ailleurs (user://,
## personnage fusionné) : PNG lu directement.
func texture(part: String, anim: String) -> Texture2D:
	var path: String = texture_path(part, anim)
	if _textures.has(path):
		return _textures[path]
	var result: Texture2D = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			result = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null:
			result = ImageTexture.create_from_image(image)
	_textures[path] = result
	return result


## Oublie les planches chargées (libère la mémoire vidéo).
func clear_cache() -> void:
	_textures.clear()
