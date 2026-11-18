#!/bin/sh
# Archives the App Store build and uploads it to App Store Connect: ./upload.sh
# Raise CURRENT_PROJECT_VERSION in project.yml first: Apple takes each build number once.
# The archive is the iPhone container that holds the watch app (README.md). Signing is Xcode's
# own, with the Apple account Xcode is signed in to on this Mac. Nothing here makes a sound.
set -e
cd "$(dirname "$0")"
nix run nixpkgs#xcodegen -- generate
rm -rf build/Rain.xcarchive
xcodebuild -project Rain.xcodeproj -scheme RainContainer -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Rain.xcarchive -derivedDataPath build/release \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Rain.xcarchive -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
