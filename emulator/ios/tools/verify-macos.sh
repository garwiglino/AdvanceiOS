#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Cette vérification nécessite un Mac avec Xcode et son SDK iOS." >&2
  exit 1
fi
xcodebuild -version
plutil -lint Resources/Info.plist Resources/PrivacyInfo.xcprivacy mGBA-iOS.xcodeproj/project.pbxproj
xcodebuild -list -project mGBA-iOS.xcodeproj
xcodebuild -project mGBA-iOS.xcodeproj -scheme 'mGBA iOS' \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build-simulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project mGBA-iOS.xcodeproj -scheme 'mGBA iOS' \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build-device CODE_SIGNING_ALLOWED=NO build
CC=clang python3 tools/test_core.py
echo 'Builds simulateur + appareil et tests du moteur terminés. Effectuer ensuite les tests interactifs du guide.'
