# Intégration du kit Indigo

## Fichiers et coordonnées

Ce guide concerne le pack historique. L’interface active est décrite dans [Commandes tactiles](TOUCH-CONTROLS.md) et l’ancien assemblage reste visible dans `preview/indigo.html`.

Le fichier `assets/gba-indigo/manifest.json` est la référence d’assemblage. Les chemins d’images sont relatifs à ce fichier. Toutes les coordonnées sont en **pixels de l’image source**, origine en haut à gauche, x vers la droite et y vers le bas.

| Champ | Usage |
| --- | --- |
| `variants.*.width`, `height` | Dimensions natives de la façade |
| `variants.*.openings` | Rectangle englobant de chacun des sept logements transparents |
| `screenOpening` | Ouverture centrale mesurée dans le PNG |
| `gameRect` | Rectangle 3:2 inscrit dans l’ouverture, avec une petite marge |
| `sprites.*.contentRect` | Limites visibles du bouton dans son PNG carré ; exclut les marges transparentes |
| `shellColor` | Couleur échantillonnée pour prolonger le fond décoratif ; ce n’est pas une couleur officielle publiée |

Les huit grandes zones transparentes de chaque façade ont été identifiées dans le canal alpha. Les bords sont anticrénelés et peuvent contenir quelques pixels partiellement transparents. Les rectangles des logements englobent des formes différentes : la croix n’est pas un rectangle plein, et A/B sont circulaires. Conserver l’alpha des PNG.

## Ordre des calques

1. Fond décoratif violet jusqu’aux limites de la vue, avec fond sombre sous les logements.
2. Vue de jeu inscrite dans `gameRect`.
3. PNG de la façade.
4. PNG des sept boutons, placés au-dessus de leur logement.
5. Zones tactiles invisibles et indépendantes des tailles des images.

Ne pas placer un PNG noir ou une capture fictive dans l’ouverture du jeu. L’aperçu montre uniquement un emplacement « GAME VIEW ».

## Assemblage sans déformation

Choisir la composition à partir de la place disponible. Comme point de départ : ratio largeur/hauteur ≥ 2 pour `wide`, ≥ 1,65 pour `classic`, sinon `ipad`. Ces seuils sont des choix du kit, à ajuster selon l’application ; ils ne sont pas des règles Apple.

Appliquer une échelle uniforme `s` à la façade et à tous ses repères. Pour un rectangle source `(x, y, w, h)`, le rectangle affiché est `(offsetX + s*x, offsetY + s*y, s*w, s*h)`. Ne pas étirer séparément la largeur et la hauteur.

Les PNG ne peuvent pas remplir tous les ratios sans adaptation. Pour les écarts entre iPad 13″, 11″ et mini, prolonger le fond violet dans l’espace restant tout en gardant l’assemblage proportionnel. L’aperçu démontre cette solution. Une déclinaison raster dédiée reste possible pour une finition sans raccord sur un appareil ciblé.

Pour chaque bouton : lire `contentRect`, ajuster son contenu visible dans le logement en conservant son ratio, puis centrer. Garder le reste du PNG transparent, sans le confondre avec la taille visuelle. Les boutons ont été générés séparément : de légers jeux entre leur contour et le logement restent visibles et font partie de la marge d’assemblage. La croix doit rester un seul élément graphique même si quatre directions logiques sont détectées.

## Jeu : toujours 3:2

La GBA produit une image de 240 × 160. Utiliser `gameRect`, dont les dimensions sont des multiples exacts de 3 et 2. Centrer la vue de jeu dans ce rectangle et conserver toute l’image. L’ouverture graphique peut être légèrement plus large : les petits espaces résiduels restent sombres. Ne pas utiliser un remplissage qui rogne le jeu.

Pour un rendu pixel net, utiliser le filtrage le plus proche voisin. Si un agrandissement entier est exigé, réduire la vue au plus grand multiple entier de 240 × 160 qui tient dans le rectangle et la centrer.

## Marges et capteurs iOS

Le fond décoratif peut aller jusqu’au bord, tandis que le jeu, les boutons et leurs zones tactiles doivent respecter les safe areas. Utiliser les valeurs **actuelles de la vue** : `safeAreaInsets` en UIKit, les guides de disposition en SwiftUI, ou `env(safe-area-inset-*)` dans une vue web avec `viewport-fit=cover`. Recalculer lors des changements de taille, de rotation et de fenêtre iPad.

Ne pas coder une unique largeur d’encoche en pixels. Les deux sens du paysage doivent fonctionner, et la zone tactile agrandie ne doit pas déborder sur les gestes système. Les bandes vierges du PNG sont une réserve visuelle, pas un remplacement des safe areas.

L’aperçu sait lire les variables CSS de safe area. Sa case « Marges simulées » ajoute des valeurs illustratives pour l’inspection sur ordinateur ; ces nombres ne constituent pas une table de mesures matérielles certifiées.

## Touches, gâchettes et animation

Prévoir au moins 44 × 44 points pour les cibles tactiles, conformément au [guide Apple sur les boutons](https://developer.apple.com/design/human-interface-guidelines/buttons). Dans la démonstration web, L/R ont une cible minimale de 56 × 56 pixels CSS. Les points UIKit et les pixels natifs de l’écran ne sont pas interchangeables.

L/R sont placés au-dessus des commandes principales. On peut agrandir leur zone tactile vers les pouces sans modifier le bouton visible, en vérifiant les collisions avec les autres cibles. Déplacer réellement le bouton graphique impose aussi de déplacer son logement dans la façade.

Une option de glissement A/B vers R a été envisagée pour maintenir une combinaison avec un pouce. Elle **n’est pas implémentée** : sa distance, son annulation et les déclenchements involontaires doivent être testés selon les jeux avant activation.

Les images livrées restent dans l’état de repos. Animation indicative de la démo : descente de 2 pixels CSS, échelle 0,975 et légère baisse de luminosité pendant l’appui, transition de 80 ms. Respecter l’option de réduction des animations. Aucun nouveau PNG d’état enfoncé n’est nécessaire.

Traiter chaque contact séparément pour autoriser A+direction ou L+A. Libérer les touches sur fin de contact, annulation, perte de capture et mise en arrière-plan afin d’éviter une touche bloquée. La croix utilise huit secteurs égaux de 45° et une zone neutre centrale de rayon 0,25 (rayon du bouton = 1). Le PNG unique bascule de 10° autour du pivot dans la direction pressée, y compris les diagonales. La géométrie d’entrée reste fixe pendant l’animation. SwiftUI et l’aperçu partagent ces règles.

L’aperçu émet un événement par changement d’état :

```js
window.addEventListener('gba-input', ({ detail }) => {
  // detail.button : a, b, l, r, start, select, up, down, left, right
  // detail.pressed : true ou false
  // Relier cet événement au moteur d’émulation de l’application.
});
```

Aucun moteur d’émulation ni retour haptique n’est relié à cette démonstration. Les positions et zones tactiles doivent être validées sur les appareils réellement visés.

Référence de disposition : [Apple — Layout](https://developer.apple.com/design/human-interface-guidelines/layout).

## Application native

Le port est dans `emulator/ios`. `MGBAConsoleView.swift` reproduit ces calques en SwiftUI, `MGBAControls.m` suit les contacts simultanés et `MGBAInput.c` quantifie les directions. Le lanceur et les images mGBA utilisent la même vue centrale. Le projet référence les assets de ce dépôt directement. Les vibrations sont disponibles dans l’application et se désactivent dans les options du lanceur.
