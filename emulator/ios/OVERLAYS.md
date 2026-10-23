# Commandes tactiles actives

`App/MGBAConsoleView.swift` affiche le jeu aussi grand que le permet la zone sûre, au ratio 3:2. Des PNG blancs transparents venant de `assets/ios-outline` sont posés par-dessus. Le projet Xcode embarque ce dossier.

`MGBAControls.m` capte les contacts indépendamment. Le premier contact dans la moitié gauche, hors boutons, définit le pivot flottant ; le glissement émet les huit directions de `MGBAInput.c`. Les boutons fixes ont priorité. Un second doigt ne vole pas la croix. Les touches se libèrent à la fin/annulation du contact, au changement de géométrie et lors des interruptions gérées par le contrôleur.

La position du pivot n’est pas déplacée pour faire tenir le dessin à un bord. La zone neutre reste donc centrée sous le doigt. L’artwork peut être partiellement hors champ près d’un bord, tandis que les zones d’activation respectent les marges.

A/B, L/R et les fonctions secondaires se placent avec des tailles en points et des ancrages indépendants du jeu. Le menu natif se trouve en haut au centre. Les effets d’appui reposent sur l’opacité et la lueur, sans mouvement animé. Le retour haptique reste désactivable.

Le [guide complet](../../docs/TOUCH-CONTROLS.md) donne les tailles, les sources, les règles de placement et les limites de validation. L’ancien pack Indigo reste consultable dans `preview/indigo.html` et `assets/gba-indigo`, mais sa coque ne sert plus de fenêtre au jeu.
