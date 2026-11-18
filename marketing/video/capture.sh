#!/bin/sh
# Captures what the film shows, from the real app in the watch simulator, without a sound:
#   marketing/video/capture.sh <folder for the captures>
# then: uv run --with pillow python radar_order.py <folder>, look at <folder>/r??-radar-sheet.png,
# set "now" in <folder>/r??/order.json to the index of the "Now" picture, and python3 prepare.py <folder>.
#
# It takes 40 minutes: the face is photographed in real time while the rain comes, so its clock,
# its words and its line always agree. It never touches the "Rain Ultra 3" simulator; it works on
# four copies of it and deletes them. Like design/capture.sh it only launches the app and takes
# screenshots, and design/listen.swift mutes and measures every simulator process throughout.
#
# The app is built from a throwaway worktree with capture.patch, which changes debug builds only:
# the widget extension is told the simulator's time zone (it gets no environment of its own), and
# `-timelapse YES` writes the saved forecast minute by minute, arriving from the newest five-minute
# run that is at least ten minutes old, as a watch that refreshes gets it.
#
# The simulator's clock is the Mac's. The zones below only move it to a morning: FACE_ZONE for the
# face, RADAR_ZONE (an hour later) for the app and the radar, which come after it in the film.
set -e
CAP="$1"; HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
SRC="${SIMULATOR:-19A080F0-AAA9-47BF-A49C-2B8557B0358E}"
FACE_ZONE="${FACE_ZONE:-Asia/Kabul}"; RADAR_ZONE="${RADAR_ZONE:-Asia/Kolkata}"; PORT="${PORT:-8791}"
B=nl.jjp.rain.watchkitapp
mkdir -p "$CAP"; cd "$CAP"

git -C "$REPO" worktree add --detach "$CAP/worktree" HEAD >/dev/null
git -C "$CAP/worktree" apply "$HERE/capture.patch"
(cd "$CAP/worktree/App" && xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'generic/platform=watchOS Simulator' -derivedDataPath build build >"$CAP/build.log" 2>&1)
APP="$CAP/worktree/App/build/Build/Products/Debug-watchsimulator/Rain.app"

swiftc -O "$REPO/design/listen.swift" -o listen 2>/dev/null
./listen 3000 CoreSimulator mute >listen.log 2>&1 &
METER=$!

# The radar reads the UI tests' copy of the server's files, its run moved to ten minutes ago.
mkdir -p serve/runs; cp "$REPO"/App/RainUITests/Server/runs/* serve/runs/
RUN=$(python3 -c 'from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(minutes=10)
print(t.replace(minute=t.minute - t.minute % 5).strftime("%Y-%m-%dT%H:%MZ"))')
sed "s/\"run\":\"[^\"]*\"/\"run\":\"$RUN\"/" "$REPO/App/RainUITests/Server/latest" >serve/latest
nix run nixpkgs#caddy -- file-server --listen "127.0.0.1:$PORT" --root serve >/dev/null 2>&1 &
SERVER=$!
until curl -sf -o /dev/null "http://127.0.0.1:$PORT/latest"; do sleep 1; done

# A copy of the simulator in a language, booted with its clock in a zone.
copy() {  # name language zone
  U=$(xcrun simctl clone "$SRC" "RainWatch video $1")
  if [ "$2" = nl ]; then
    plutil -replace AppleLanguages -json '["nl-NL","en-NL"]' "$HOME/Library/Developer/CoreSimulator/Devices/$U/data/Library/Preferences/.GlobalPreferences.plist"
  fi
  xcrun simctl boot "$U"; xcrun simctl bootstatus "$U" >/dev/null
  xcrun simctl spawn "$U" launchctl setenv TZ "$3"
  # The face and the status bar's clock only read the zone when they start.
  P=$(pgrep -f "launchd_sim .*$U")
  for n in RainWidget WidgetRenderer_ ClockFace chronod nanotimekitd Carousel; do pkill -9 -P "$P" -x $n || true; done
  sleep 14
  xcrun simctl install "$U" "$APP"
  echo "$U"
}

face() {  # folder udid: the face every few seconds for 34 minutes
  mkdir -p "$1/lapse"
  SIMCTL_CHILD_TZ=$FACE_ZONE xcrun simctl launch "$2" $B -scenario rainComing -timelapse YES -freshInstall YES >/dev/null
  sleep 6; xcrun simctl io "$2" screenshot --type=png "$1/app-rainComing.png" >/dev/null 2>&1
  xcrun simctl terminate "$2" $B; sleep 8
  END=$(( $(date +%s) + 34 * 60 ))
  while [ "$(date +%s)" -lt $END ]; do
    xcrun simctl io "$2" screenshot --type=png "$1/lapse/$(date +%s).png" >/dev/null 2>&1; sleep 4
  done
}

radar() {  # folder udid: the forecast page, then the radar while it plays through its frames
  mkdir -p "$1/radar"
  SIMCTL_CHILD_TZ=$RADAR_ZONE xcrun simctl launch "$2" $B -scenario rainingEasing -freshInstall YES >/dev/null
  sleep 7; xcrun simctl io "$2" screenshot --type=png "$1/page.png" >/dev/null 2>&1
  xcrun simctl terminate "$2" $B; sleep 2
  SIMCTL_CHILD_TZ=$RADAR_ZONE xcrun simctl launch "$2" $B -scenario rainingEasing -radar YES -server "http://127.0.0.1:$PORT" -freshInstall YES >/dev/null
  sleep 16
  i=0; while [ $i -lt 150 ]; do xcrun simctl io "$2" screenshot --type=png "$1/radar/$(printf %03d $i).png" >/dev/null 2>&1; i=$((i+1)); done
  xcrun simctl terminate "$2" $B
}

EN=$(copy en en "$FACE_ZONE"); NL=$(copy nl nl "$FACE_ZONE")
REN=$(copy "radar en" en "$RADAR_ZONE"); RNL=$(copy "radar nl" nl "$RADAR_ZONE")
face en "$EN" & face nl "$NL" & radar ren "$REN" & radar rnl "$RNL" &
wait %1 %2 %3 %4 2>/dev/null || wait

for U in $EN $NL $REN $RNL; do xcrun simctl shutdown "$U"; xcrun simctl delete "$U"; done
kill $SERVER $METER 2>/dev/null || true
git -C "$REPO" worktree remove --force "$CAP/worktree"
LOUD=$(grep -v "^SUMMARY" listen.log | grep -c -E " peak |TAP FAILED" || true)
if [ "$LOUD" != "0" ]; then echo "THE SIMULATOR PLAYED SOUND $LOUD TIMES" >&2; exit 1; fi
echo "silent: no simulator process played anything"
