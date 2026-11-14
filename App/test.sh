#!/bin/sh
# Runs the UI tests on a watch simulator: ./test.sh <simulator udid> [result bundle]
# The refused-location test needs location never asked, and only the simulator's own reset clears
# a watch app's location permission, so it runs on its own between two resets.
set -e
cd "$(dirname "$0")"
U="$1"; R="${2:-build/tests}"
reset() {
  xcrun simctl terminate "$U" nl.jjp.rain.watchkitapp 2>/dev/null || true
  sleep 1
  xcrun simctl privacy "$U" reset location nl.jjp.rain.watchkitapp 2>/dev/null || true
}
xcrun simctl location "$U" set 51.92,4.48
rm -rf "$R-refused.xcresult" "$R.xcresult"
reset
xcodebuild test -project Rain.xcodeproj -scheme Rain -destination "id=$U" -derivedDataPath build \
  -resultBundlePath "$R-refused.xcresult" -only-testing:RainUITests/RainUITests/testChoosePlaceWithoutLocation
reset
xcodebuild test -project Rain.xcodeproj -scheme Rain -destination "id=$U" -derivedDataPath build \
  -resultBundlePath "$R.xcresult" -skip-testing:RainUITests/RainUITests/testChoosePlaceWithoutLocation
