# PLAN

## Objectif actuel
Première version : import du pack, CcSprite, écran de création, fusion
(2026-10-30). Installée dans DungeonTactics (branche art).

## Prochaines étapes
- [x] Premier commit et push (2026-10-30) ; sous-module de DungeonTactics.
- [ ] Tester à la main dans l'éditeur : menu Projet > Outils > Import
      (thread et barre de progression jamais lancés dans l'éditeur ouvert),
      écran de création au doigt sur mobile.

## Décisions prises
- 2026-10-30 : planches recadrées et serrées à l'import (511 -> 106 Mo,
  mémoire vidéo ~ / 10) plutôt que les planches du pack telles quelles.
- 2026-10-30 : fusion par la carte graphique (SubViewport), couleurs
  prémultipliées (rendu sur fond transparent), affichées avec
  BLEND_MODE_PREMULT_ALPHA.
- 2026-10-30 : interface selon DESIGN.md (direction commune des addons),
  pas celle du pack Unity.

## Questions ouvertes
- Outils d'export du pack Unity (contour, réduction d'images, 64 px) non
  repris : à faire seulement si besoin.
