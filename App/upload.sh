#!/bin/sh
# Archives the App Store build and uploads it to App Store Connect: ./upload.sh
# Raise CURRENT_PROJECT_VERSION in project.yml first: Apple takes each build number once.
#
# The archive is the iPhone container that holds the watch app (README.md). Everything it needs is
# in ~/code/nix/nix-secrets (where-things-are.md): the App Store Connect API key, which uploads,
# and the Apple Distribution identity, which signs. The key may not use Xcode's cloud signing, so
# the identity and three App Store profiles ("RainWatch App Store ...", in ExportOptions.plist)
# were made through Apple's API on 18 November 2026; the profiles are installed on this Mac. The
# identity goes into a keychain made for this run and removed after it. Nothing here makes a sound.
set -e
cd "$(dirname "$0")"
SECRETS="$HOME/code/nix/nix-secrets"
KEY_ID=VUP2XX3DWG
ISSUER=69a6de7b-ab59-47e3-e053-5b8c7c11a4d1

WORK=$(mktemp -d)
chmod 700 "$WORK"
KEYCHAIN="$WORK/signing.keychain-db"
PASS=$(uuidgen)
OLD=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
trap 'security list-keychains -d user -s $OLD; security delete-keychain "$KEYCHAIN" 2>/dev/null; rm -rf "$WORK"' EXIT
age -d -i "$HOME/.ssh/id_ed25519" "$SECRETS/app-store-connect-api-key-buienwatch.p8.age" > "$WORK/AuthKey_$KEY_ID.p8"
age -d -i "$HOME/.ssh/id_ed25519" "$SECRETS/apple-distribution-rainwatch.p12.age" > "$WORK/dist.p12"
security create-keychain -p "$PASS" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$PASS" "$KEYCHAIN"
security import "$WORK/dist.p12" -k "$KEYCHAIN" -P rainwatch -T /usr/bin/codesign -T /usr/bin/security > /dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$PASS" "$KEYCHAIN" > /dev/null
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $OLD
AUTH="-authenticationKeyPath $WORK/AuthKey_$KEY_ID.p8 -authenticationKeyID $KEY_ID -authenticationKeyIssuerID $ISSUER"

nix run nixpkgs#xcodegen -- generate
rm -rf build/Rain.xcarchive
# shellcheck disable=SC2086
xcodebuild -project Rain.xcodeproj -scheme RainContainer -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Rain.xcarchive -derivedDataPath build/release \
  -allowProvisioningUpdates $AUTH archive
# shellcheck disable=SC2086
xcodebuild -exportArchive -archivePath build/Rain.xcarchive -exportOptionsPlist ExportOptions.plist $AUTH
