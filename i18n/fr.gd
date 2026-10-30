@tool
extends RefCounted

## Traductions françaises de l'écran de création : texte anglais (tel
## qu'écrit dans le code) -> texte français. Un texte absent reste en
## anglais.

const TEXTS: Dictionary = {
	# --- En-tête et pied ---
	"CHARACTER": "PERSONNAGE",
	"Appearance": "Apparence",
	"Random": "Au hasard",
	"Random gear and colors": "Équipement et couleurs au hasard",
	"Reset": "Réinitialiser",
	"Back to the default character": "Revenir au personnage de départ",
	"Cancel": "Annuler",
	"Confirm": "Valider",
	"Keep this character": "Garder ce personnage",
	"preset name": "nom du preset",
	"Save preset": "Enregistrer le preset",
	"Save this look as a .tres in %s": "Enregistrer cette apparence en .tres dans %s",
	"Give the preset a name first.": "Donner d'abord un nom au preset.",
	"Saved %s": "Enregistré : %s",
	"Could not save %s": "Impossible d'enregistrer %s",

	# --- Emplacements ---
	"SLOTS": "EMPLACEMENTS",
	"Body": "Corps",
	"Head": "Tête",
	"Chest": "Torse",
	"Legs": "Jambes",
	"Shoes": "Chaussures",
	"Hands": "Mains",
	"Belt": "Ceinture",
	"Weapon": "Arme",
	"Off-hand": "Main gauche",
	"Bag": "Sac",
	"Mount": "Monture",
	"Slash": "Entaille",
	"Effect": "Effet",
	"Gunfire": "Tir",
	"Shadow": "Ombre",
	"None": "Aucun",

	# --- Scène ---
	"Drag to turn the character": "Glisser pour tourner le personnage",
	"Turn left": "Tourner à gauche",
	"Turn right": "Tourner à droite",
	"Animation": "Animation",
	"Pause or play the animation": "Mettre en pause ou lire l'animation",

	# --- Couleur ---
	"COLOR": "COULEUR",
	"Custom": "Autre",
	"Pick any color": "Choisir n'importe quelle couleur",

	"STYLE": "STYLE",
	"Outline": "Contour",
	"Outline around the whole character (not the shadow)": "Contour autour de tout le personnage (pas de l'ombre)",
	"Outline color": "Couleur du contour",
	"Frames": "Images",
	"Frames played per animation (same duration): fewer is choppier, retro style": "Images jouées par animation (même durée) : moins d'images, plus saccadé, style rétro",
	"SIZE": "TAILLE",
	"Back to the pack size": "Revenir à la taille du pack",
	"Height": "Hauteur",
	"Width": "Largeur",
	"Pixel art: sizes other than 50, 100 or 150 % give slightly uneven pixels in the game (x2)": "Pixel art : une taille autre que 50, 100 ou 150 % donne des pixels un peu inégaux dans le jeu (x2)",
	"Zoom out": "Dézoomer",
	"Zoom in": "Zoomer",
	"Zoom (mouse wheel or pinch on the stage)": "Zoom (molette ou pincement sur la scène)",

	# --- Onglet Characters (éditeur) ---
	"CHARACTERS": "PERSONNAGES",
	"Reload the folders": "Relire les dossiers",
	"Duplicate the selected character": "Dupliquer le personnage choisi",
	"Rename the file (its id: maps and saves use it)": "Renommer le fichier (son identifiant : cartes et sauvegardes s'en servent)",
	"Delete the selected character (moved to the trash)": "Supprimer le personnage choisi (mis à la corbeille)",
	"Add an appearance": "Ajouter une apparence",
	"Pick a character on the left, or press + to create one.": "Choisir un personnage à gauche, ou + pour en créer un.",
	"New character in %s": "Nouveau personnage dans %s",
	"empty: press +": "vide : appuyer sur +",
	"Could not load %s": "Impossible de charger %s",
	"No appearance: drawn with simple shapes in the game.": "Pas d'apparence : dessiné en formes simples dans le jeu.",
	"This resource has no appearance.": "Cette ressource n'a pas d'apparence.",
	"Save": "Enregistrer",
	"Save the character (also saved when you pick another one)": "Enregistrer le personnage (aussi fait en changeant de personnage)",
	"%s: unsaved changes": "%s : modifications non enregistrées",
	"New character": "Nouveau personnage",
	"Duplicate": "Dupliquer",
	"Rename": "Renommer",
	"file name, e.g. orc_chief": "nom du fichier, ex. chef_orc",
	"Give it a name first.": "Donner d'abord un nom.",
	"%s already exists.": "%s existe déjà.",
	"Could not write %s (%s)": "Impossible d'écrire %s (%s)",
	"Move %s to the trash?": "Mettre %s à la corbeille ?",
	"Could not delete %s": "Impossible de supprimer %s",
	"Moved %s to the trash": "%s mis à la corbeille",

	# --- État vide ---
	"NO CHARACTER PARTS": "AUCUNE PIÈCE DE PERSONNAGE",
	"Import the pack in the editor: Project > Tools > Import Character Creator pack.": "Importer le pack dans l'éditeur : Projet > Outils > Import Character Creator pack.",
}
