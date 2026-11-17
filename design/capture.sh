#!/bin/sh
# Captures every screen in the Paper design file from the real app in the watch simulator:
#   design/capture.sh <simulator udid>
# The screenshots land in design/captures/raw.
#
# IT MAKES NOISE. The simulator plays watchOS's alert and haptic sounds through the Mac's speakers
# (a ping when the location question appears, clicks when the crown turns). Setting the simulator's
# volume file to zero does not stop it: design/listen.swift measured a peak of 0.19 of full scale
# with it at zero (17 November 2026). Do not run this while Josh is at the Mac until a mute is
# found and measured. Derived from App/test.sh: it serves the saved KNMI
# run, resets location permission before each first-launch test, and runs the design tests.
set -e
cd "$(dirname "$0")/../App"
U="$1"; PORT=8765; OUT="../design/captures"
if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then echo "Port $PORT is already in use" >&2; exit 1; fi
SERVE=$(mktemp -d)
mkdir -p "$SERVE/runs"
cp RainUITests/Server/runs/* "$SERVE/runs/"
RUN=$(python3 -c 'from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(minutes=10)
print(t.replace(minute=t.minute - t.minute % 5).strftime("%Y-%m-%dT%H:%MZ"))')
sed "s/\"run\":\"[^\"]*\"/\"run\":\"$RUN\"/" RainUITests/Server/latest > "$SERVE/latest"
nix run nixpkgs#caddy -- file-server --listen "127.0.0.1:$PORT" --root "$SERVE" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$SERVE"' EXIT
until curl -sf -o /dev/null "http://127.0.0.1:$PORT/latest"; do sleep 1; done
export TEST_RUNNER_RAIN_SERVER="http://127.0.0.1:$PORT"

reset() {
  xcrun simctl terminate "$U" nl.jjp.rain.watchkitapp 2>/dev/null || true
  sleep 1
  xcrun simctl privacy "$U" reset location nl.jjp.rain.watchkitapp 2>/dev/null || true
}
xcrun simctl location "$U" set 51.92,4.48
[ -n "$2" ] || rm -rf "$OUT/raw"
rm -rf build/design-*.xcresult
mkdir -p "$OUT/raw"
for TEST in ${2:-testDesignRefuseWithoutLocation testDesignAllowWithoutLocation testDesignStatesWithoutLocation}; do
  reset
  xcodebuild test -project Rain.xcodeproj -scheme Rain -destination "id=$U" -derivedDataPath build \
    -resultBundlePath "build/design-$TEST.xcresult" -only-testing:"RainUITests/RainUITests/$TEST" 2>&1 \
    | grep -E "error:|XCTAssert|\*\* TEST" || true
  TMP=$(mktemp -d)
  xcrun xcresulttool export attachments --path "build/design-$TEST.xcresult" --output-path "$TMP" >/dev/null
  python3 - "$TMP" "$OUT/raw" <<'PY'
import json, shutil, sys
src, out = sys.argv[1:]
for test in json.load(open(f"{src}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_0_")[0]
        shutil.copy(f"{src}/{a['exportedFileName']}", f"{out}/{name}.png")
PY
  rm -rf "$TMP"
done
ls "$OUT/raw"
