# Commandes tactiles blanches

Le mode actif utilise des icônes originales, blanches, sans fond, sans texture ni coque. Le jeu est agrandi indépendamment des contrôles. Les anciennes images Indigo restent dans le dépôt.

## Artwork

Les huit sources SVG se trouvent dans `assets/ios-outline/svg`, les PNG RGBA @3x dans `assets/ios-outline/png`. Tous les glyphes sont des tracés, sans dépendance à une police.

| Contrôle | Taille logique de l’image | PNG @3x |
| --- | --- | --- |
| Croix | 128 × 128 | 384 × 384 |
| A, B | 64 × 64 | 192 × 192 |
| L, R | 88 × 48 | 264 × 144 |
| Select, Start | 64 × 44 | 192 × 132 |
| Pause | 44 × 44 | 132 × 132 |

Blanc #FFFFFF, trait de 2 unités, extrémités arrondies, intérieur transparent. Opacité normale 65 %, 100 % à l’appui avec une légère lueur ; croix indicative au repos 25 %. Le cercle de suivi est dessiné à l’exécution. Aucune série de PNG enfoncés n’est nécessaire.

L’aperçu utilise les SVG et propose un réglage d’opacité. SwiftUI charge les PNG du dossier de ressources `ios-outline` avec la même géométrie. Son bouton Pause/Options garde le symbole système et sa cible de 44 points. Pas de dépendance au pack Indigo pour calculer la fenêtre de jeu.

## Croix flottante

La zone de départ est la moitié gauche de la surface utilisable. Les touches L et Select ont priorité, de même que les autres boutons. Les marges caméra et indicateur d’accueil ne démarrent pas la croix.

1. Le premier contact libre crée le pivot à ses coordonnées exactes, y compris près d’un bord.
2. Le contact initial est neutre. Le centre ne suit pas le doigt durant le geste : le déplacement relatif choisit une direction.
3. Rayon de référence : 44 points (49,28 sur grand iPad). Zone neutre : 25 % du rayon, soit 11 points sur iPhone. Huit secteurs de 45°.
4. Les diagonales émettent deux directions simultanées. Le cercle visuel se déplace sur 70 % du rayon au maximum.
5. Sortir de la zone de départ ne coupe pas la direction : le contact reste capturé. Un second contact ne peut pas remplacer son propriétaire.
6. Relâcher ou annuler libère la direction et remet l’indicateur au repos. Le prochain contact choisit un nouveau centre.

Le pivot n’est jamais déplacé artificiellement pour faire tenir le dessin à l’écran : cela provoquerait une direction à l’appui initial. Près d’un bord, une partie du dessin peut sortir de la zone sûre ; les commandes fixes et leurs cibles restent protégées.

Un contact démarré sur A/B/L/R/Select/Start conserve son identité. Sortir de sa cible le relâche ; y revenir le réactive. Les autres doigts continuent leurs propres actions. Une rotation, une interruption ou un changement de géométrie libère les commandes.

## Placement

Le rectangle utilisable vient des `safeAreaInsets` réels, mesurés une seule fois par le contrôleur parent. Le jeu est le plus grand rectangle 3:2 inscrit dans cette surface ; aucune zone n’est réservée à une coque. L’image n’est ni coupée ni étirée. Pour GB/GBC, la vue image conserve le ratio 10:9 à l’intérieur.

Les groupes gauche/droite s’ancrent près des bords utilisables, avec au plus 36 points de débordement latéral par rapport au jeu. A est en haut à droite de B ; leurs centres sont séparés de 68 points horizontalement et 47 verticalement. L/R sont plus haut dans les mêmes groupes, accessibles à un pouce déplacé ou à un index. Le centre du jeu reste dégagé.

Toutes les cibles mesurent au moins 44 × 44 points. A/B font 64 × 64, L/R 88 × 48. Les commandes principales sont multipliées par 1,12 sur un écran dont le petit côté dépasse 600 points, sans proportionner les boutons à toute la résolution. Start, Select et Pause restent en haut, séparés du déplacement.

Ce sont des positions de départ fondées sur les usages tactiles, pas un optimum universel. Une combinaison direction + L peut demander un troisième doigt ou une manette. Tester avec de petites/grandes mains et ajuster les constantes de `ConsoleLayout` et `GBATouch.layout` ensemble.

## Références

Les [recommandations Apple sur les contrôles de jeu](https://developer.apple.com/design/human-interface-guidelines/game-controls) préconisent un mouvement flottant à gauche, des actions proches des pouces, les fonctions secondaires en haut et des cibles fréquentes d’au moins 44 points. Elles demandent aussi de tenir compte des zones sûres et de confirmer les appuis visuellement et par retour tactile.

La [présentation Apple sur les interfaces de jeux](https://developer.apple.com/videos/play/wwdc2024/10085/) recommande de conserver la taille physique des groupes de commandes et de les ancrer par section. Notre choix de garder A/B/L/R identifiables répond à l’usage d’un émulateur : leur action dépend de chaque ROM.

## Vérification

`node tools/test_touch.cjs` couvre neuf dimensions, l’absence de chevauchement, le ratio 3:2 maximal, les marges, l’origine exacte, les diagonales, les contacts simultanés, la priorité des boutons et la remise à zéro.

La prévisualisation est inspectée sur ordinateur. Les dimensions de modèles y sont des simulations ; les marges finales viennent toujours de l’appareil. Les tests automatiques ne prouvent pas le confort de prise en main.
