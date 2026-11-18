#!/bin/sh
# The store screenshots' captures: the real app in the "Rain Ultra 3" simulator, at the real clock,
# showing a real KNMI run (18 November 2026, 03:40 CET, a heavy shower crossing Friesland) and the
# live Apple Weather forecast for a place in the UK. Run it on the Mac mini, whose sound is muted (AGENTS.md):
#   design/capture-store.sh <simulator udid>
# The saved run in captures/store/run is served locally with its run time moved to ten minutes ago,
# as capture.sh does for the radar, so the app, the face and the radar all read it as a fresh run.
# Nothing is tapped: location is granted and set with simctl. Then: store/screenshots/make.py.
# Written by AI on 2026.11.18 by model claude opus 5.5.
set -e
cd "$(dirname "$0")"
U="$1"
APP=../App/build/Build/Products/Debug-watchsimulator/Rain.app
PORT=${PORT:-8791}
ID=nl.jjp.rain.watchkitapp
PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$U/data/Library/Preferences/.GlobalPreferences.plist"
WORK=$(mktemp -d)
cp -R captures/store/run "$WORK/serve"
if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then echo "Port $PORT is already in use" >&2; exit 1; fi
nix run nixpkgs#caddy -- file-server --listen "127.0.0.1:$PORT" --root "$WORK/serve" >/dev/null 2>&1 &
SERVER=$!
xcrun simctl shutdown "$U" 2>/dev/null || true
cp "$PREFS" "$WORK/prefs"
trap 'kill $SERVER 2>/dev/null; xcrun simctl shutdown "$U" 2>/dev/null; cp "$WORK/prefs" "$PREFS"; rm -rf "$WORK"' EXIT
until curl -sf -o /dev/null "http://127.0.0.1:$PORT/latest"; do sleep 1; done

fresh() {   # the saved run as if KNMI had published it ten minutes ago
  RUN=$(python3 -c 'from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(minutes=10)
print(t.replace(minute=t.minute - t.minute % 5).strftime("%Y-%m-%dT%H:%MZ"))')
  sed "s/\"run\":\"[^\"]*\"/\"run\":\"$RUN\"/" captures/store/run/latest > "$WORK/serve/latest"
}

shoot() {   # shoot <folder> <name> <latitude,longitude> <app options...>: the app, then the face
  OUT=$1; NAME=$2; LOC=$3; shift 3
  fresh
  xcrun simctl location "$U" set "$LOC"
  xcrun simctl launch "$U" $ID -freshInstall YES "$@" >/dev/null
  sleep 14
  xcrun simctl io "$U" screenshot --type=png "$OUT/app-$NAME.png" >/dev/null 2>&1
  xcrun simctl terminate "$U" $ID
  sleep 8
  xcrun simctl io "$U" screenshot --type=png "$OUT/face-$NAME.png" >/dev/null 2>&1
}

for LOCALE in en-GB nl-NL; do
  OUT=captures/store/$LOCALE
  mkdir -p "$OUT"
  xcrun simctl shutdown "$U" 2>/dev/null || true
  if [ $LOCALE = nl-NL ]; then plutil -replace AppleLanguages -json '["nl-NL","en-NL"]' "$PREFS"
  else cp "$WORK/prefs" "$PREFS"; plutil -replace AppleLanguages -json '["en-GB","nl-NL"]' "$PREFS"; fi
  xcrun simctl boot "$U"
  xcrun simctl bootstatus "$U" >/dev/null
  xcrun simctl install "$U" "$APP"
  xcrun simctl privacy "$U" grant location $ID
  S="-server http://127.0.0.1:$PORT"
  shoot "$OUT" coming 53.10,6.25 $S        # dry for 20 minutes, then up to 8.7 mm/h (Siegerswoude)
  shoot "$OUT" raining 53.25,6.00 $S       # 5.8 mm/h now, dry in about 25 minutes (Feanwâlden)
  shoot "$OUT" later 51.40,4.60 $S         # dry for 50 minutes, then light rain (Zundert)
  # The radar plays its frames in a loop: ten pictures a second and a half apart, to pick the one
  # where the shower is about to reach the dot.
  fresh
  xcrun simctl location "$U" set 53.10,6.25
  xcrun simctl launch "$U" $ID -freshInstall YES $S -radar YES >/dev/null
  sleep 25
  for N in 1 2 3 4 5 6 7 8 9 10; do
    xcrun simctl io "$U" screenshot --type=png "$OUT/app-radar-$N.png" >/dev/null 2>&1
    sleep 1.5
  done
  xcrun simctl terminate "$U" $ID
  # Apple Weather, live, for a UK place where it rains at the time: UK=52.49,-1.91 is Birmingham.
  if [ $LOCALE = en-GB ]; then shoot "$OUT" uk "${UK:-51.51,-0.13}"; fi
done
echo done
