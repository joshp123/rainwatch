#!/bin/sh
# Runs the UI tests on a watch simulator: ./test.sh <simulator udid> [result bundle]
#
# The forecast comes from a copy of the server's files in RainUITests/Server: KNMI's run of
# 16 November 2026 00:35 UTC (a night of heavy rain), built by server/job.py. They are served on this
# Mac with range requests, as the real server serves them. The run time in `latest` is moved to ten
# minutes ago, so the forecast is current; every value is KNMI's.
#
# The refused-location test needs location never asked, and only the simulator's own reset clears
# a watch app's location permission, so it runs on its own between two resets.
set -e
cd "$(dirname "$0")"
U="$1"; R="${2:-build/tests}"; PORT=8765

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
rm -rf "$R-refused.xcresult" "$R.xcresult"
reset
xcodebuild test -project Rain.xcodeproj -scheme Rain -destination "id=$U" -derivedDataPath build \
  -resultBundlePath "$R-refused.xcresult" -only-testing:RainUITests/RainUITests/testChoosePlaceWithoutLocation
reset
xcodebuild test -project Rain.xcodeproj -scheme Rain -destination "id=$U" -derivedDataPath build \
  -resultBundlePath "$R.xcresult" -skip-testing:RainUITests/RainUITests/testChoosePlaceWithoutLocation
