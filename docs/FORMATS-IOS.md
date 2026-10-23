# Formats paysage

Les pixels natifs servent à identifier les proportions et la densité. La disposition de l’interface doit utiliser la taille disponible en points et les marges de la vue, pas une liste figée de modèles.

| Famille | Exemples de dimensions natives en paysage | Composition du kit |
| --- | --- | --- |
| iPhone Face ID / Dynamic Island | 2340 × 1080 ; 2436 × 1125 ; 2532 × 1170 ; 2556 × 1179 ; 2622 × 1206 ; 2796 × 1290 ; 2868 × 1320 | `wide`, environ 19,5:9 |
| iPhone à bouton principal | 1136 × 640 ; 1334 × 750 ; 1920 × 1080 | `classic`, environ 16:9 |
| iPad 13″ / anciens 4:3 | 2752 × 2064 ; 2732 × 2048 ; 2048 × 1536 | `ipad`, environ 4:3 |
| iPad Pro 11″ | 2420 × 1668 | `ipad` avec prolongement latéral du fond |
| iPad mini 8,3″ | 2266 × 1488 | `ipad` avec prolongement latéral du fond |

Sources : [table Apple des résolutions matérielles](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/), [iPad Pro](https://www.apple.com/ipad-pro/specs/), [iPad mini](https://www.apple.com/ipad-mini/specs/). Les résolutions d’export vidéo acceptées par l’App Store sont une autre notion ; ce tableau reprend des dimensions matérielles, pas les formats vidéo.

## Résolution réelle des images livrées

| Image | Dimensions PNG |
| --- | --- |
| `facades/iphone-wide.png` | 1846 × 852 |
| `facades/iphone-classic.png` | 1672 × 941 |
| `facades/ipad.png` | 1448 × 1086 |
| Chaque bouton indépendant | 1254 × 1254, marges transparentes comprises |

Les façades sont des sources raster générées, pas un export natif par appareil. Un affichage sur un écran de résolution supérieure implique un rééchantillonnage. Garder l’échelle proportionnelle et vérifier le résultat Retina sur appareil. Les boutons disposent d’une définition largement supérieure à leur taille d’affichage habituelle.

## Couleur et référence

La référence visuelle est la GBA violette/indigo des [archives officielles Nintendo](https://www.nintendo.co.jp/n08/hardware/gba/index.html), [visuel violet](https://www.nintendo.co.jp/n08/hardware/gba/vaiolet.jpg). Les trois images utilisent cette même direction de couleur. Les valeurs `shellColor` du manifest sont des échantillons propres aux rendus, destinés au fond de prolongement ; elles ne constituent pas un nuancier officiel.
