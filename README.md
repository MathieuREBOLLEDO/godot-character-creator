# Character Creator (addon Godot)

Personnages 2D à calques en 8 directions (corps, tête, torse, jambes,
chaussures, mains, ceinture, arme, main gauche, sac, monture, effets,
ombre), créés par le joueur dans le jeu ou par le développeur, à partir du
pack Unity **Character Creator - 2D Fantasy** de Small Scale Interactive
(https://smallscaleint.itch.io/character-creator-2d-fantasy).

**Les images ne sont pas dans ce dépôt** : le pack est payant et ses
fichiers ne doivent pas être redistribués. Chaque projet importe son propre
exemplaire du pack (voir Import) ; le résultat reste dans le projet.

## Installation

1. Sous-module dans `addons/character_creator` :
   `git submodule add https://github.com/MathieuREBOLLEDO/godot-character-creator.git addons/character_creator`
2. Activer le plugin (Projet > Paramètres du projet > Plugins).
3. Facultatif : réglage `character_creator/catalog_path` (par défaut
   `res://character_creator/catalog.res`) : où le catalogue et les planches
   sont écrits et lus.

## Import

Projet > Outils > **Import Character Creator pack...** : choisir le
`.unitypackage` (extrait avec la commande `tar` du système, présente sur
Windows 10+, macOS et Linux) ou un dossier déjà extrait. Environ 3 min
depuis le `.unitypackage`, 1 min depuis un dossier extrait.

En ligne de commande :

```
godot --headless --path <projet> -s res://addons/character_creator/importer/import_cli.gd -- --source=<.unitypackage ou dossier> [--dest=res://...]
```

Résultat, à côté de `catalog.res` :
- `parts/<pièce>/<animation>.png` : chaque image recadrée au plus juste et
  rangée dans une planche serrée (1024 px de large). Le pack fait 511 Mo
  (cases de 128 px surtout vides) ; l'import fait environ 106 Mo et une
  planche prend environ 10 fois moins de mémoire vidéo.
- `catalog.res` (CcCatalog) : 30 animations, celles qui bouclent, la place
  de chaque image.

Contenu du pack v1.3 : 129 pièces, 30 animations (Idle à Idle4, Walk, Run,
RunBackwards, Strafe, Crouch, Attack1 à 6, AttackRun, Kick, Special1,
Taunt, Rolling, Slide, TakeDamage, Die, versions à cheval), 15 images à
10 images/s, 8 directions. Les planches GunFire2-4 du pack sont vides :
elles sont ignorées.

## Utilisation

### Afficher un personnage

```gdscript
var sprite := CcSprite.new()
sprite.catalog = load("res://game/art/character_creator/catalog.res")
sprite.look = load("res://.../presets/knight.tres")   # ou CcLook.from_dict(...)
add_child(sprite)
sprite.play("Walk", CcSprite.direction_from_vector(velocity))
await sprite.animation_finished   # animations sans boucle (Attack1, Die...)
```

- Origine du nœud = les pieds (`CcCatalog.pivot`, 64, 84 dans la case).
- Directions : 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE.
- Filtre « nearest » par défaut (pixel art). Échelle libre (`scale`).

### Écran de création

Instancier `res://addons/character_creator/creator/cc_creator.tscn` :

- `look` : apparence à modifier (copiée ; null = personnage de départ) ;
- `confirmed(look: CcLook)` / `cancelled` ;
- `preset_dir` : si rempli et le jeu lancé depuis l'éditeur, bouton
  **Save preset** (enregistre un `.tres` : ennemis, PNJ, héros prédéfinis).

Colonnes : emplacements (pièce choisie à droite), scène (glisser ou ◀ ▶
pour tourner, choix de l'animation, pause), pièces de l'emplacement et
couleur (nuancier peau pour le corps, équipement pour le reste, couleur
libre). Random tire l'équipement et les couleurs ; Reset revient au
personnage de départ. Textes en anglais et en français (suivent la langue
du jeu, `i18n/`).

### Enregistrer le personnage du joueur

`CcLook` passe dans un ConfigFile : `config.set_value("hero", "look",
look.to_dict())`, puis `CcLook.from_dict(config.get_value("hero", "look"))`.

### Fusionner pour le jeu

Un personnage à calques charge une planche par calque et par animation.
En jeu, avec plusieurs unités, mieux vaut le fusionner une fois (après
Confirm) :

```gdscript
var baked: CcCatalog = await CcBaker.bake(look, catalog, self, "user://characters/hero")
sprite.catalog = baked                  # ou load("user://characters/hero/catalog.res") plus tard
sprite.look = CcBaker.baked_look()
```

Rendu par la carte graphique (SubViewport), 30 animations en moins d'une
seconde sur PC. Demande une fenêtre (pas en `--headless`).

## Limites

- Pas repris de l'outil Unity : export de planches PNG pour d'autres
  moteurs, contour, réduction du nombre d'images, résolution 64 px. Le
  catalogue garde les 15 images à 128 px.
- La teinte multiplie les couleurs (comme `SpriteRenderer.color` dans
  Unity) : une pièce claire se teinte bien, une pièce sombre peu.
- La fusion de toutes les animations écrit environ 30 PNG par personnage
  dans `user://`.
