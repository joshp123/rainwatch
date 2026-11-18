#!/bin/sh
# Captures the app and the watch face in every state, from the real app in the watch simulator,
# without a sound: design/capture.sh <simulator udid> [state names]
#
# It only boots the simulator, launches the app with a debug option and takes screenshots; closing
# the app shows the face. Nothing is tapped, so watchOS plays no alert or haptic sound. That is
# measured, not assumed: design/listen.swift taps every simulator process for the whole run, mutes
# them as a second guard, and this script fails if any of them played anything.
# The build must exist: xcodebuild ... -destination 'generic/platform=watchOS Simulator' build
set -e
cd "$(dirname "$0")"
U="$1"; shift
APP=../App/build/Build/Products/Debug-watchsimulator/Rain.app
RAW=captures/raw
STATES="${*:-dry coming raining stopping ageing not-updated abroad picked first-launch location-off location-not-found forecast-unavailable no-forecast-here too-old arc-0-light arc-0-heavy arc-0-burst arc-1-light arc-1-heavy arc-1-burst arc-2-light arc-2-heavy arc-2-burst arc-3-light arc-3-heavy arc-3-burst arc-4-light arc-4-heavy arc-4-burst words-new-coming words-new-stopping}"

options() {
  case "$1" in
    dry) echo "-scenario dry" ;;
    coming) echo "-scenario showerComing" ;;
    raining) echo "-scenario rainingEasing" ;;
    stopping) echo "-scenario onAndOff" ;;
    ageing) echo "-scenario showerComing -age 32" ;;
    not-updated) echo "-scenario rainingEasing -couldNotUpdate YES" ;;
    abroad) echo "-scenario ukNextHour" ;;
    picked) echo "-scenario rainComing -pickedPlace Utrecht" ;;
    first-launch) echo "-failure notAsked" ;;
    location-off) echo "-failure noLocation" ;;
    location-not-found) echo "-failure locationNotFound" ;;
    forecast-unavailable) echo "-failure offline" ;;
    no-forecast-here) echo "-failure noForecast" ;;
    too-old) echo "-failure stale" ;;
    arc-*-light) echo "-scenario rainComing -arcStyle $(echo "$1" | cut -d- -f2)" ;;
    arc-*-heavy) echo "-scenario heavy -arcStyle $(echo "$1" | cut -d- -f2)" ;;
    arc-*-burst) echo "-scenario burst -arcStyle $(echo "$1" | cut -d- -f2)" ;;
    words-new-coming) echo "-scenario showerComing -circleWords state" ;;
    words-new-stopping) echo "-scenario onAndOff -circleWords state" ;;
    *) echo "unknown state $1" >&2; exit 1 ;;
  esac
}

mkdir -p "$RAW"
LISTEN=$(mktemp -d)
swiftc -O listen.swift -o "$LISTEN/listen"
COUNT=$(echo $STATES | wc -w)
"$LISTEN/listen" $((COUNT * 16 + 240)) CoreSimulator mute > "$LISTEN/log" 2>&1 &
METER=$!
sleep 1
xcrun simctl boot "$U" 2>/dev/null || true
xcrun simctl bootstatus "$U" >/dev/null
xcrun simctl install "$U" "$APP"
for STATE in $STATES; do
  # shellcheck disable=SC2046
  xcrun simctl launch "$U" nl.jjp.rain.watchkitapp $(options "$STATE") -freshInstall YES >/dev/null
  sleep 5
  xcrun simctl io "$U" screenshot --type=png "$RAW/app-$STATE.png" >/dev/null 2>&1
  xcrun simctl terminate "$U" nl.jjp.rain.watchkitapp
  sleep 7
  xcrun simctl io "$U" screenshot --type=png "$RAW/face-$STATE.png" >/dev/null 2>&1
done
xcrun simctl shutdown "$U"
kill "$METER" 2>/dev/null || true
wait "$METER" 2>/dev/null || true
# The meter's own closing line also says "peak"; it is not a sound.
LOUD=$(grep -v "^SUMMARY" "$LISTEN/log" | grep -c -E " peak |TAP FAILED" || true)
grep -E " peak |TAP FAILED" "$LISTEN/log" || true
rm -rf "$LISTEN"
if [ "$LOUD" != "0" ]; then echo "THE SIMULATOR PLAYED SOUND $LOUD TIMES" >&2; exit 1; fi
echo "silent: no simulator process played anything"
