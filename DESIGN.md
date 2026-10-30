# Design des interfaces

Règle de base de toutes les interfaces d'outils (écran de création, debug
menu, éditeurs, fenêtres de debug d'un jeu) : une direction propre au
contexte, appliquée avec cohérence, plutôt qu'une interface générique.

Direction commune à tous les addons : **comme l'éditeur Godot** (thème
Godot 4 par défaut : fond gris bleuté, accent bleu, police de l'éditeur),
pour que les outils se fondent dans l'éditeur. Dans l'éditeur, les outils
prennent les couleurs du thème de l'éditeur ouvert ; en jeu, les valeurs
ci-dessous.

## Jetons

Les couleurs, polices et tailles sont des jetons. **Les défauts ci-dessous
sont le design de référence**, copiés à l'identique dans chaque addon
(debug menu : settings/design_tokens.gd ; game_feel :
editor/feel_theme.gd ; character creator : creator/cc_theme.gd) : chaque
addon reste indépendant et a le bon design sans rien installer dans le
projet. Un changement de direction se fait dans les défauts de **tous** les
addons à la fois, et ce tableau suit.

`res://design_tokens.cfg` (ConfigFile, facultatif) sert seulement à
s'écarter de ces défauts dans un projet ; une valeur absente garde son
défaut.

| Section | Clé | Défaut | Rôle |
|---|---|---|---|
| profile | follow_editor | true | dans l'éditeur, couleurs du thème de l'éditeur ouvert |
| colors | ink | 1d2229 | fond le plus profond (champs, listes) |
| colors | ink_panel | 252b34 | bandeaux, barre, fenêtres |
| colors | ink_raised | 363d4a | boutons, cartes, survol |
| colors | ink_line | 414957 | filets de 1 px |
| colors | sand | e0e0e0 | texte |
| colors | sand_dim | 8b929c | texte secondaire (légendes, aide) |
| colors | accent | 70bbfa | accent unique : sélection, focus, action principale |
| colors | good | 45d17c | valide, ouvert, chargé |
| colors | bad | ff786b | problème, erreur, enregistrement |
| colors | info | a5b6cc | information, vide |
| fonts | ui | @engine | police d'interface (« @engine » : police de l'éditeur Godot, celle de Godot en jeu ; sinon des SystemFont) |
| fonts | mono | JetBrains Mono, Cascadia Mono, Consolas, Menlo | valeurs, coordonnées, champs |
| fonts | condensed_width / condensed_weight | 100 / 600 | version étroite et grasse (titres, surtitres) |
| sizes | text / title / small / radius | 14 / 16 / 12 / 3 | tailles et rayon des coins |

Exemple de fichier qui s'écarte des défauts dans un projet :

```ini
[colors]
accent="ffb020"
[sizes]
text=16
```

L'écran de création lit ces jetons dans creator/cc_theme.gd (copie des
défauts : l'addon reste indépendant).

## Règles

- **Direction d'abord.** On choisit une direction propre au contexte et on
  s'y tient. On évite l'esthétique générique : polices par défaut, gris sur
  gris, dégradés violets, mises en page passe-partout.
- **Thème centralisé.** Couleurs, polices et styles se trouvent dans un seul
  script de thème par outil ou addon, qui lit les jetons
  (`creator/cc_theme.gd` ici). Pas de couleur en dur dans les écrans, sauf
  les dessins en jeu (gizmos, grilles) et les nuanciers de teintes, qui sont
  du contenu.
- **Un seul accent**, réservé à ce qu'on manipule : sélection, focus, un
  seul bouton plein par écran, repères au survol. Les couleurs de sens ne
  servent jamais à décorer.
- **Typographie choisie.** Police étroite et grasse pour les titres, les
  surtitres de section (en capitales) et les onglets ; police à chasse fixe
  pour les valeurs.
- **Structure.** En-tête, corps, pied. Les boutons vont par groupes. La
  légende d'un champ est petite et estompée. Ici : en-tête CHARACTER
  (Random, Reset), corps en trois colonnes (emplacements, scène, pièces et
  couleur), pied (Cancel, Confirm) ; Confirm est le seul bouton plein.
- **Moins de texte.** Les explications vont en bulle (tooltip) plutôt qu'en
  blocs de texte ; seuls les messages d'état restent affichés. Un état vide
  guide l'utilisateur.
- **Atmosphère discrète.** Filets, ombres portées, lignes de fond, plutôt
  que des aplats ou des effets. Ici : sol en losanges isométriques et
  vignettage derrière le personnage.
- **Animations rares et bien placées** : apparition en cascade, retour sur
  une action, attention sur un problème.
- **Vérifier sur une vraie capture d'écran** (fenêtre lancée, image du
  viewport), pas seulement en headless.
