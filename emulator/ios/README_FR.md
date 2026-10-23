# mGBA iOS

Port natif indépendant de mGBA 0.10.5 pour iPhone et iPad, à partir des sources de ce dossier. Façade en SwiftUI, contrôleur du moteur et intégrations système en Objective-C/UIKit, moteur C compilé directement dans l’application. iOS/iPadOS 16 minimum. Aucun binaire Windows, Qt, SDL, téléchargement de dépendances ou JIT n’est utilisé par le projet iOS.

Le projet Xcode est déjà généré : **`mGBA-iOS.xcodeproj`**. Conserver **tout le dépôt AdvanceiOS** : `emulator/ios`, `emulator/src`, `emulator/include` et `assets/gba-indigo`. Le projet référence ces sources et les images par chemins relatifs.

## Ouvrir et installer

1. Copier et décompresser l’archive complète sur un Mac disposant de Xcode et du SDK iOS. Xcode 16 ou plus récent est la configuration visée.
2. Ouvrir `emulator/ios/mGBA-iOS.xcodeproj`. Sélectionner le schéma **mGBA iOS**.
3. Pour le simulateur, sélectionner un iPhone ou iPad simulé, puis **Run**.
4. Pour un appareil physique, dans **Signing & Capabilities**, choisir son équipe Apple et remplacer `org.example.mgba.ios` par son identifiant d’application unique. Sélectionner l’appareil, activer son mode développeur si demandé, puis **Run**.
5. Dans l’écran central de la console, choisir **Importer des ROMs** avec A, ou appuyer sur Select, puis choisir un fichier `.gba`, `.gb` ou `.gbc` dans Fichiers. Décompresser les archives ZIP au préalable.

Aucun certificat, compte Apple, profil de provisionnement ou jeu commercial n’est fourni. Le petit programme original `tests/ios-smoke-test.gba` est fourni pour vérifier le rendu : il produit un écran vert et écrit un marqueur dans la SRAM.

**Validation actuelle :** compilation Debug simulateur et Release iOS sans signature réussie avec Xcode 26.6 sur GitHub Actions, et tests C réussis sous Windows ainsi que sur Mac. [Exécution de référence](https://github.com/garwiglino/AdvanceiOS/actions/runs/39957221485). Les essais tactiles, le son et les performances sur iPhone physique restent à effectuer. Voir `VALIDATION.md`.

## Fonctions de cette version

- Bibliothèque GBA, GB et GBC, import multiple depuis Fichiers, détection par le moteur, identification par SHA-256 pour séparer les sauvegardes des différentes ROM.
- Rendu logiciel du moteur, pixels nets, proportions conservées, interface paysage sur iPhone, disposition adaptable aux rotations et fenêtres iPad.
- Croix directionnelle avec diagonales et glissement, A/B/L/R/Start/Select simultanés ; façades Indigo et boutons du dépôt, bascule 3D de la croix en huit secteurs de 45°, zone centrale neutre, retour haptique désactivable et respect de Réduire les animations.
- Manettes exposant un profil Game Controller étendu : croix/stick gauche, A/B, épaules, Menu = Start, Options ou X = Select.
- Audio stéréo à 48 kHz, tampon circulaire sans verrou dans le callback audio, vitesse normale et accélération ×2 avec son coupé.
- Sauvegarde du jeu toutes les cinq secondes lorsqu’elle change et à la pause ; écritures atomiques.
- État de reprise à la pause et au retour au lanceur, cinq emplacements d’état manuels, import/export `.sav`.
- Pause lors du passage hors de l’application, d’une interruption audio ou d’un changement de sortie audio. Reprise explicite pour éviter de relancer un jeu pendant un appel.
- Façade transparente en SwiftUI, écran central et **images de boutons indépendantes**, choisies selon le format iPhone large/classique ou iPad : voir `OVERLAYS.md`.
- Icône provisoire, écran de lancement, manifeste de confidentialité, mentions et licences accessibles dans l’application.

Le BIOS de remplacement intégré à mGBA est utilisé. Les fonctions propres à l’interface de bureau ne sont pas toutes reproduites : pas d’interface de triche/débogage, de rewind, de câble link/multijoueur, d’enregistrement vidéo, d’import ZIP/7z direct, de sélection de BIOS externe ou de prise en charge iOS des capteurs de cartouche, de la caméra et du rumble dans cette version. Ces fonctionnalités demandent des extensions du frontal ; le moteur source d’origine reste inclus.

## Vos fichiers

Dans **Fichiers > Sur mon iPhone/iPad > AdvanceiOS** :

```text
Games/
  <SHA-256 de la ROM>/
    game.gba                 # ou game.gb / game.gbc
    game.plist               # titre et nom du fichier
    battery.sav              # sauvegarde interne au jeu
    battery-backup.sav       # copie avant un import manuel, si une sauvegarde existait
    resume.ss0               # reprise automatique à la dernière pause
    slot-1.ss0 … slot-5.ss0   # états manuels
```

Les états incluent aussi les données de sauvegarde et l’horloge du moteur. Charger un état peut donc ramener la sauvegarde interne à une situation antérieure. Les états sont liés à la ROM et à la version du moteur. L’import d’un `.sav` conserve une copie de l’ancien `.sav` puis retire la reprise automatique pour démarrer avec les données importées. Le fichier brut `.sav` ne comporte généralement pas l’identité du jeu : il faut choisir celui du bon jeu.

Une fermeture forcée peut perdre les dernières secondes non écrites et ne crée pas de nouvel état de reprise. Utiliser la pause ou le retour au lanceur avant de fermer. Si `resume.ss0` est endommagé, le déplacer ailleurs depuis Fichiers ; le prochain démarrage utilisera `battery.sav`.

## Structure et reconstruction

`App/MGBAEngine.m` exécute le moteur sur une file série, synchronisée à l’affichage. Le thread audio ne fait ni accès disque ni appel au moteur. `Bridge/MGBASession.c` adapte les API mCore et isole le chargement en mémoire, les pixels, les échantillons et les sauvegardes. `App/MGBAConsoleView.swift` assemble la façade SwiftUI à partir du manifest des images, en conservant les proportions et les marges réelles de la vue. `MGBAControls.m` suit chaque contact séparément ; `MGBAInput.c` détermine les directions. `MGBALauncher.c` rend le sélecteur dans un framebuffer 240 × 160. Le menu appartient au frontal : il ne s’agit pas d’une ROM GBA exécutée par le cœur.

Les drapeaux du projet sélectionnent les deux moteurs, le rendu 32 bits, le VFS en mémoire/fichiers et `MINIMAL_CORE=2`. `DISABLE_THREADING` désactive uniquement l’infrastructure de threads interne de mGBA ; le frontal iOS possède sa propre file d’émulation. Le projet Xcode compile les sources directement et évite les réglages macOS historiques du CMake de mGBA 0.10.5.

Pour régénérer le projet après ajout/retrait de sources, depuis le dossier `ios` :

```sh
python3 tools/generate_project.py
python3 tools/verify_project.py
bash tools/verify-macos.sh
```

`prepare_resources.py` régénère les ressources provisoires ; ne pas l’exécuter après les avoir personnalisées sans sauvegarder ces changements. Les scripts ne sont pas nécessaires à l’ouverture normale du projet Xcode.

## Sources et licences

Le moteur et les nouveaux fichiers du port sont sous MPL-2.0. `blip_buf` est sous LGPL-2.1-or-later et `inih` sous BSD-3-Clause. L’archive contient les sources et les licences pour reconstruire l’application et ses bibliothèques. Conserver cet ensemble lors d’une redistribution ; la publication d’un binaire implique aussi de fournir l’accès aux sources correspondantes et de respecter les conditions des composants liés.

Références techniques consultées : [import de documents Apple](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init%28foropeningcontenttypes%3Aascopy%3A%29), [source audio Apple](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode/init%28renderblock%3A%29), [Game Controller](https://developer.apple.com/documentation/GameController/GCController), [catégories du manifeste de confidentialité](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
