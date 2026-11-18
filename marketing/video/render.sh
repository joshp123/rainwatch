#!/bin/sh
# Makes every cut from the app's current code and words, in a few minutes, into out/:
#   marketing/video/render.sh [cut ...]
# Cuts: <en|nl>-<9x16|16x9>, and the same with -unnamed, which names no other app.
# Written by AI on 2026.11.18 by model claude opus 5.5.
set -e
cd "$(dirname "$0")"
HERE=$PWD

# 1. The KNMI run: Middenmeer's forecast, the radar frames, the coast (data.py).
uv run -q --with numpy --with pillow python data.py >/dev/null

# 2. The app's own views, drawn by the app's own code, in each language. The face's clock is in
#    Kabul's time zone because that is how the face screenshots were taken (README).
ln -sfn ../../.. export/app
(cd export && swift build -q)
TZ=Asia/Kabul ./export/.build/debug/film-export "$HERE/public" en
TZ=Asia/Kabul ./export/.build/debug/film-export "$HERE/public" nl -AppleLanguages "(nl)"

# 3. Apple's artwork, which its licences don't let us republish, so it is fetched and never committed:
#    the watch's face font from this Mac, the Ultra 4 bezel from Apple Design Resources, the badges
#    from Apple's marketing tools.
cp /System/Library/Fonts/SFCompactRounded.ttf public/fonts/
CACHE="$HOME/.cache/rainwatch-video/bezel"
BEZEL="Bezel-Apple-Watch-Ultra-4-2026/PNG/AW Ultra 4 - Natural + Ocean Band Translucent Gray.png"
if [ ! -f public/bezel.png ]; then
  mkdir -p "$CACHE"
  [ -f "$CACHE/ultra4.dmg" ] || curl -sfL -o "$CACHE/ultra4.dmg" https://devimages-cdn.apple.com/design/resources/download/Bezel-Apple-Watch-Ultra-4-2026.dmg
  (cd "$CACHE" && nix shell nixpkgs#p7zip -c 7z x -y ultra4.dmg "$BEZEL" >/dev/null)
  cp "$CACHE/$BEZEL" public/bezel.png
fi
mkdir -p public/badge
[ -f public/badge/en.svg ] || curl -sfL -o public/badge/en.svg https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us
[ -f public/badge/nl.svg ] || curl -sfL -o public/badge/nl.svg https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/nl-nl

# 4. The film.
[ -d node_modules ] || nix shell nixpkgs#nodejs_22 -c npm install --no-audit --no-fund
CUTS="${*:-nl-9x16 en-9x16 nl-16x9 en-16x9 nl-9x16-unnamed en-9x16-unnamed nl-16x9-unnamed en-16x9-unnamed}"
for CUT in $CUTS; do
  nix shell nixpkgs#nodejs_22 -c npx remotion render src/index.ts "$CUT" "out/rainwatch-$CUT.mp4" \
    --codec=h264 --crf=17 --pixel-format=yuv420p --muted --log=error
  echo "out/rainwatch-$CUT.mp4"
done
