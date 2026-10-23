# Façade Indigo et boutons

L’interface active est `App/MGBAConsoleView.swift`. Elle utilise directement les trois façades, les sept PNG de boutons et `assets/gba-indigo/manifest.json` du dépôt. Les images ne sont pas recopiées ni téléchargées au lancement : le projet Xcode embarque le dossier comme ressource.

L’ordre des calques correspond à la prévisualisation : fond violet, fond sombre des ouvertures, image du jeu ou du lanceur, façade transparente, sprites, contacts tactiles invisibles. Aucun bandeau de bibliothèque ou titre n’est ajouté au-dessus de la coque. Un bouton discret en bas permet de mettre en pause et de revenir au lanceur.

Les dimensions et offsets viennent du manifest. Les marges transparentes des sprites sont exclues grâce à `contentRect`. L’échelle est uniforme ; les marges `safeAreaInsets` réelles protègent l’écran et les touches. La fenêtre garde son ratio 3:2 ; les jeux GB/GBC restent en 10:9 avec bandes latérales. Les compositions sont prévues pour le paysage ; en portrait ou fenêtre étroite, l’assemblage iPad est conservé sans déformation.

Les cibles visent au moins 44 points, 56 pour L/R, dans l’espace disponible. La croix est une pièce rigide qui bascule de 10° autour du centre : angle identique dans les directions cardinales et diagonales, axe perpendiculaire à la direction choisie. Le centre est neutre ; les huit secteurs ont chacun 45°. Chaque contact est indépendant : direction+A, direction+B, L+A, etc. Les annulations, changements de disposition et interruptions libèrent les touches.

L’enfoncement des autres touches utilise une descente de 2 points et une échelle de 0,975. Réduire les animations conserve uniquement l’assombrissement. Les vibrations se désactivent depuis les options du lanceur.

Pour modifier les images ou ajouter un format, éditer le manifest et `ConsoleLayout`, puis vérifier l’aperçu et les appareils concernés. L’ancien format expérimental `Skins/default/layout.json` n’est plus utilisé par cette façade. Voir aussi [le guide d’assemblage](../../docs/INTEGRATION.md).
