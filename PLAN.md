# PLAN

## Objectif actuel
Première version : import du pack, CcSprite, écran de création, fusion
(2026-10-30). Installée dans DungeonTactics (branche art).

## Prochaines étapes
- [x] Premier commit et push (2026-10-30) ; sous-module de DungeonTactics.
- [ ] Tester à la main dans l'éditeur : menu Projet > Outils > Import
      (thread et barre de progression jamais lancés dans l'éditeur ouvert),
      écran de création au doigt sur mobile.

- [x] Onglet Characters dans l'éditeur, zoom de la scène, bouton Save
      (2026-10-30). À essayer à la main : Rename, Delete, Inspector.

- [x] Presets du pack (15), contour, réduction d'images (2026-10-30).
      À vérifier sur mobile : coût du contour (un rendu de plus par
      personnage).

## Décisions prises
- 2026-10-30 : contour par CanvasGroup seulement quand il est actif ;
  réduction d'images à l'affichage (même durée), pas dans les planches.
- 2026-10-30 : onglet générique (toute ressource avec « look ») ; les
  stats restent dans l'Inspector de Godot plutôt qu'un formulaire maison.
- 2026-10-30 : planches recadrées et serrées à l'import (511 -> 106 Mo,
  mémoire vidéo ~ / 10) plutôt que les planches du pack telles quelles.
- 2026-10-30 : fusion par la carte graphique (SubViewport), couleurs
  prémultipliées (rendu sur fond transparent), affichées avec
  BLEND_MODE_PREMULT_ALPHA.
- 2026-10-30 : interface selon DESIGN.md (direction commune des addons),
  pas celle du pack Unity.

## Questions ouvertes
- Outils d'export du pack Unity encore non repris (contour en dégradé,
  halo, 64 px) : à faire seulement si besoin.
