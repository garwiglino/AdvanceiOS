# Validation du port — 23 octobre 2026

## Nouvelle interface tactile

Les contrôles blancs et la croix flottante remplacent la coque dans la vue active. Vérifications locales : huit SVG et PNG RGBA @3x, neuf géométries sans chevauchement et avec cibles de 44 points minimum, jeu 3:2 maximal, origine exacte au contact, neutralité initiale, diagonales, mouvement + A + R, priorité de L, deuxième doigt, sortie/rentrée dans une touche et annulation. Le projet comporte désormais 288 objets et 133 entrées locales, pour 114 unités compilées. L’aperçu iPhone et iPad est inspecté dans le navigateur. La compilation et le lancement Apple sont suivis dans le workflow du commit concerné ; les résultats historiques ci-dessous ne les remplacent pas.

Sur appareil, vérifier particulièrement : déplacement près des quatre bords de la zone gauche, relâchement après interruption, maintien direction + action, accès à L/R avec différentes prises en main, contours blancs sur scènes claires, VoiceOver et rotations iPad.

## Vérifié dans l’environnement disponible

Environnement : Windows, GCC MinGW 16.1.0, Python 3.15. Le script `tools/test_core.py` a compilé et lié **107 unités C**, comprenant la sélection des sources originales utilisée par le projet Xcode et le pont du port. Le programme de test s’est terminé avec le code de sortie 0.

Cas exécutés avec de petits programmes originaux, sans jeu commercial :

- Refus d’une ROM absente ou non reconnue.
- Exécution du code ARM GBA, écriture vidéo et vérification d’un pixel vert au centre de l’image 240 × 160.
- Cadence GBA comprise entre 16,7 et 16,8 ms par image.
- Production et drainage du nombre attendu d’échantillons stéréo à 48 kHz.
- Création, chargement et restauration du compteur d’images d’un état.
- Refus d’un état tronqué ; restauration de la session précédente après le refus d’un état de version invalide.
- Écriture d’un marqueur SRAM depuis le programme GBA, copie de 32 Ko, destruction/recréation de la session et comparaison des données sauvegardées.
- Exécution GB et GBC : dimensions 160 × 144, images, cadence audio, création/chargement d’état.
- Tampon audio : conversion signé 16 bits vers float, silence en sous-alimentation, dépassement des indices circulaires, saturation, réduction de la latence et remise à zéro.

- Croix : 688 points répartis autour des huit secteurs, zone centrale neutre, entrées non finies et annulation des directions opposées.
- Lanceur : sélection, maintien avec délai de répétition, pagination, retour cyclique, import, blocage jusqu’au relâchement après transition, sélection tactile et rendu borné du framebuffer.
- Prévisualisation : tests JavaScript des mêmes secteurs et de l’axe de bascule ; validation des trois façades et sept sprites.
- Inspection du framebuffer réel du lanceur : `docs/launcher-render.png` (noms de jeux fictifs, pas une capture du simulateur iOS).

Les journaux mGBA affichent des avertissements lors de la restauration des programmes minimaux (DMA non configuré et absence de RAM cartouche GB), ainsi que le rejet volontaire de la mauvaise version d’état. Les assertions finales passent.

`tools/verify_project.py` a vérifié : syntaxe OpenStep du projet, **286 objets**, **132 entrées locales**, **114 unités de compilation dans la cible iOS**, références du schéma partagé, décodage des plists, XML du storyboard, icône RGB opaque 1024 × 1024 et validité des rectangles d’exemple des habillages.

L’icône provisoire a été inspectée visuellement. Les scripts Python ont passé leur vérification de syntaxe. Ces contrôles de structure ne remplacent pas la compilation par Apple Clang, `actool` et `ibtool`.

## Compilation Mac et essais interactifs

Le poste local fonctionne sous Windows. La compilation Apple a été effectuée sur le runner Mac de GitHub Actions : **Xcode 26.6**, Debug pour simulateur et Release pour appareil, avec `CODE_SIGNING_ALLOWED=NO`. Les deux compilations et les 107 unités de tests C avec Apple Clang ont réussi pour le commit `f07a17a` : [journal de référence](https://github.com/garwiglino/AdvanceiOS/actions/runs/39957221485).

Le workflow comprend aussi un essai de lancement réel sur simulateur et une capture conservée comme artefact. Cette vérification ne remplace pas les essais tactiles, audio, manettes et autonomie sur appareil. Aucun IPA signé n’est fourni.

Le workflow `.github/workflows/ios.yml` exécute ce contrôle sur un runner Mac à chaque push ; son résultat est la référence pour le commit concerné.

Le script `bash tools/verify-macos.sh` réalise le contrôle des plists par `plutil`, l’ouverture du projet par `xcodebuild`, les compilations Debug simulateur / Release appareil sans signature, puis les tests C avec Apple Clang. Il s’arrête au premier échec.

Après ces compilations, effectuer les essais interactifs suivants :

1. Importer `tests/ios-smoke-test.gba` depuis Fichiers et vérifier l’écran vert. Essayer ensuite un jeu de test ou homebrew doté de son et d’entrées interactives.
2. Vérifier les couleurs rouge/bleu, le son stéréo, les touches simultanées, le glissement de la croix, les diagonales et le relâchement après annulation d’un toucher.
3. Vérifier les deux paysages sur petit et grand iPhone, les rotations iPad, et les changements de dimensions de fenêtre iPad. Les commandes doivent rester dans la zone utilisable.
4. Essayer une manette étendue : connexion, déconnexion avec touche maintenue, croix/stick, A/B/L/R, Menu et Options/X.
5. Sauvegarder depuis le jeu, revenir à la bibliothèque, relancer et vérifier les données. Tester les cinq états et le refus d’un état invalide.
6. Exporter un `.sav`, l’importer, vérifier `battery-backup.sav` et le démarrage sans l’ancien `resume.ss0`. Vérifier les erreurs d’écriture et l’absence d’espace disque.
7. Tester verrouillage, arrière-plan, appel/interruption audio et débranchement des écouteurs. Le jeu doit rester en pause jusqu’à « Reprendre ».
8. Passer de vitesse normale à ×2 et revenir ; vérifier l’absence de son accumulé et la cadence.
9. Vérifier les contrôles SwiftUI : alignement identique à l’aperçu moderne, origine flottante de la croix, appuis simultanés, vibrations et marges des deux paysages. Tester aussi VoiceOver. Le retour visuel moderne n’utilise pas de mouvement animé.
10. Effectuer une session longue sur appareil pour mesurer stabilité, consommation, température et latence. Les performances n’ont pas été mesurées sur iPhone.

Une publication nécessitera les réglages de signature propres au propriétaire, les essais sur appareil et une vérification de la distribution des sources/licences et des déclarations de l’application. Aucune soumission à une boutique n’a été effectuée.
