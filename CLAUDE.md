# Character Creator (addon Godot)

Addon Godot 4.x : personnages 2D à calques en 8 directions, créés par le
joueur ou le développeur, depuis le pack Unity « Character Creator - 2D
Fantasy » (Small Scale Interactive). GDScript typé uniquement (pas de C#).
État du travail en cours : PLAN.md (le lire en début de session ; en fin
de tâche, mettre PLAN.md à jour).

## Règles de travail
- Ne pas ajouter de systèmes ou de fonctionnalités non demandés.
- Privilégier le code simple et lisible plutôt qu'une architecture générique.
- Expliquer les choix importants et signaler les compromis.
- Ne pas réécrire plusieurs systèmes pour corriger un petit problème.
- Tester ce qui peut l'être et annoncer clairement ce qui n'a pas été vérifié.
- Ne pas modifier l'architecture sans proposer un plan avant et attendre
  validation.
- Ne pas commiter sans qu'on le demande.

## Contraintes de l'addon
- **Aucune image ni aucun fichier du pack dans ce dépôt** (public, pack
  payant). Les images importées vivent dans le projet qui utilise l'addon.
- Aucune dépendance : ni autre addon, ni fichier du projet.
- Tous les chemins en res://addons/character_creator/...
- Classes globales préfixées « Cc » (CcCatalog, CcLook, CcSprite, CcBaker).
- Pas de ressource dans une variable statique (Godot plante à la
  fermeture).
- Dépôt Git à part (github.com/MathieuREBOLLEDO/godot-character-creator,
  branche main), sous-module des jeux : un commit ici part dans ce dépôt.

## Règles d'interface
- Textes en anglais dans le code, traduits par i18n/t.gd (fr.gd) ;
  commentaires en français, noms en anglais.
- Design : DESIGN.md (jetons et thème dans creator/cc_theme.gd, pas de
  couleur en dur dans les écrans sauf les nuanciers de teintes).

## Dossiers
- plugin.gd : réglage character_creator/catalog_path, menu d'import.
- cc_catalog.gd, cc_look.gd, cc_sprite.gd, cc_baker.gd : le runtime.
- importer/ : import du .unitypackage (cc_importer.gd) et ligne de
  commande (import_cli.gd).
- creator/ : écran de création (cc_creator ; embedded = intégré à
  l'onglet), scène (cc_stage, zoom), thème.
- editor/ : onglet Characters (cc_editor_tab.gd), fiches des dossiers de
  character_creator/editor_folders.
- i18n/ : traductions.

## Format du pack (v1.3)
- spritesheets/<Pièce>/<Animation>.png : 1920 x 1024, cases de 128 px,
  15 images par ligne, une ligne par direction (E, SE, S, SW, W, NW, N, NE).
- Animation Clips/<Pièce>/<Anim>/<Anim>_<Dir>.anim : 10 images/s ;
  m_LoopTime dit si l'animation boucle.
- Ordre des calques et ombre à 70 % : scène Example scene 1.unity.

## Test
- Chargement sans erreur, dans un jeu qui utilise l'addon (DungeonTactics) :
  `"G:\GameEngine\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path "G:\Projects\Godot\DungeonTactics" --quit`
- Import : importer/import_cli.gd (commande en tête du fichier).
- Logique : un script SceneTree lancé avec `-s` (catalogue, CcLook,
  CcSprite) passe en headless.
- Onglet Characters : appel temporaire dans plugin._enter_tree
  (`if OS.get_environment("CC_TEST") != "": load(".../zz_test_tmp.gd").run(self, _tab)`),
  éditeur lancé en fenêtre, capture de get_base_control().get_viewport() ;
  retirer l'appel et le script ensuite.
- Le sous-module du jeu est un autre clone : copier les fichiers (robocopy
  sans .git) pour tester, commiter ici, puis git pull dans le sous-module. La fusion et l'écran se vérifient dans une
  fenêtre (sans --headless) : capture avec
  `root.get_texture().get_image().save_png(...)`.
