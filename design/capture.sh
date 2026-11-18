#!/bin/sh
# Captures the app and the watch face in every state, from the real app in the watch simulator,
# without a sound: design/capture.sh <simulator udid> [state names]
#
# It only boots the simulator, launches the app with a debug option and takes screenshots; closing
# the app shows the face. Nothing is tapped, so watchOS plays no alert or haptic sound. That is
# measured, not assumed: design/listen.swift taps every simulator process for the whole run, mutes
# them as a second guard, and this script fails if any of them played anything.
# SIM_LANGUAGE=nl captures in Dutch, into captures/raw-nl: the simulator's language is switched for
# the run and put back after it.
# NO_TEXT=1 also captures each state without RainWatch's own words, into a "-notext" folder beside
# it: the design file lays its editable words over those pictures.
# The build must exist: xcodebuild ... -destination 'generic/platform=watchOS Simulator' build
set -e
cd "$(dirname "$0")"
U="$1"; shift
APP=../App/build/Build/Products/Debug-watchsimulator/Rain.app
RAW=captures/raw
PORT=${PORT:-8765}
STATES="${*:-dry coming raining stopping ageing not-updated abroad hourly picked radar first-launch location-expired location-off location-not-found forecast-unavailable no-forecast-here too-old}"

options() {
  case "$1" in
    dry) echo "-scenario dry" ;;
    coming) echo "-scenario showerComing" ;;
    raining) echo "-scenario rainingEasing" ;;
    stopping) echo "-scenario onAndOff" ;;
    ageing) echo "-scenario showerComing -age 32" ;;
    not-updated) echo "-scenario rainingEasing -couldNotUpdate YES" ;;
    abroad) echo "-scenario ukNextHour" ;;
    hourly) echo "-scenario spainHourly" ;;
    picked) echo "-scenario rainComing -pickedPlace Utrecht" ;;
    # The radar page, from the copy of the server's files the UI tests use (App/test.sh).
    radar) echo "-scenario rainComing -radar YES -server http://127.0.0.1:$PORT" ;;
    first-launch) echo "-failure notAsked" ;;
    location-expired) echo "-failure expired" ;;
    location-off) echo "-failure noLocation" ;;
    location-not-found) echo "-failure locationNotFound" ;;
    forecast-unavailable) echo "-failure offline" ;;
    no-forecast-here) echo "-failure noForecast" ;;
    too-old) echo "-failure stale" ;;
    *) echo "unknown state $1" >&2; exit 1 ;;
  esac
}

mkdir -p "$RAW"
LISTEN=$(mktemp -d)
case " $STATES " in *" radar "*)
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then echo "Port $PORT is already in use" >&2; exit 1; fi
  mkdir -p "$LISTEN/serve/runs"
  cp ../App/RainUITests/Server/runs/* "$LISTEN/serve/runs/"
  RUN=$(python3 -c 'from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(minutes=10)
print(t.replace(minute=t.minute - t.minute % 5).strftime("%Y-%m-%dT%H:%MZ"))')
  sed "s/\"run\":\"[^\"]*\"/\"run\":\"$RUN\"/" ../App/RainUITests/Server/latest > "$LISTEN/serve/latest"
  nix run nixpkgs#caddy -- file-server --listen "127.0.0.1:$PORT" --root "$LISTEN/serve" >/dev/null 2>&1 &
  SERVER=$!
  trap 'kill $SERVER 2>/dev/null' EXIT
  until curl -sf -o /dev/null "http://127.0.0.1:$PORT/latest"; do sleep 1; done ;;
esac
PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$U/data/Library/Preferences/.GlobalPreferences.plist"
if [ -n "$SIM_LANGUAGE" ]; then
  RAW="captures/raw-$SIM_LANGUAGE"
  mkdir -p "$RAW"
  xcrun simctl shutdown "$U" 2>/dev/null || true
  cp "$PREFS" "$LISTEN/prefs"
  plutil -replace AppleLanguages -json "[\"$SIM_LANGUAGE-NL\",\"en-NL\"]" "$PREFS"
fi
swiftc -O listen.swift -o "$LISTEN/listen"
COUNT=$(echo $STATES | wc -w)
"$LISTEN/listen" $((COUNT * 90 + 240)) CoreSimulator mute > "$LISTEN/log" 2>&1 &
METER=$!
sleep 1
xcrun simctl boot "$U" 2>/dev/null || true
xcrun simctl bootstatus "$U" >/dev/null
xcrun simctl install "$U" "$APP"
for STATE in $STATES; do
  # With NO_TEXT both pictures of a state are taken within one minute, so the forecast, the
  # clock and the face are the same in each.
  if [ -n "$NO_TEXT" ]; then while [ "$(date +%S)" -gt 1 ]; do sleep 1; done; fi
  # shellcheck disable=SC2046
  xcrun simctl launch "$U" nl.jjp.rain.watchkitapp $(options "$STATE") -freshInstall YES >/dev/null
  sleep 8
  # The radar fetches its squares and waits for the map.
  if [ "$STATE" = radar ]; then sleep 12; fi
  xcrun simctl io "$U" screenshot --type=png "$RAW/app-$STATE.png" >/dev/null 2>&1
  xcrun simctl terminate "$U" nl.jjp.rain.watchkitapp
  sleep 7
  xcrun simctl io "$U" screenshot --type=png "$RAW/face-$STATE.png" >/dev/null 2>&1
  if [ -n "$NO_TEXT" ]; then
    mkdir -p "$RAW-notext"
    # shellcheck disable=SC2046
    xcrun simctl launch "$U" nl.jjp.rain.watchkitapp $(options "$STATE") -freshInstall YES -hideText YES >/dev/null
    sleep 8
    if [ "$STATE" = radar ]; then sleep 12; fi
    xcrun simctl io "$U" screenshot --type=png "$RAW-notext/app-$STATE.png" >/dev/null 2>&1
    xcrun simctl terminate "$U" nl.jjp.rain.watchkitapp
    sleep 7
    xcrun simctl io "$U" screenshot --type=png "$RAW-notext/face-$STATE.png" >/dev/null 2>&1
  fi
done
xcrun simctl shutdown "$U"
if [ -n "$SIM_LANGUAGE" ]; then cp "$LISTEN/prefs" "$PREFS"; fi
kill "$METER" 2>/dev/null || true
wait "$METER" 2>/dev/null || true
# The meter's own closing line also says "peak"; it is not a sound.
LOUD=$(grep -v "^SUMMARY" "$LISTEN/log" | grep -c -E " peak |TAP FAILED" || true)
grep -E " peak |TAP FAILED" "$LISTEN/log" || true
rm -rf "$LISTEN"
if [ "$LOUD" != "0" ]; then echo "THE SIMULATOR PLAYED SOUND $LOUD TIMES" >&2; exit 1; fi
echo "silent: no simulator process played anything"
