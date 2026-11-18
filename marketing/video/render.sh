#!/bin/sh
# Renders every cut into out/: marketing/video/render.sh [composition ...]
# Cuts: <en|nl>-<9x16|16x9>, and the same with -unnamed, which names no other app.
set -e
cd "$(dirname "$0")"
CUTS="${*:-nl-9x16 en-9x16 nl-16x9 en-16x9 nl-9x16-unnamed en-9x16-unnamed nl-16x9-unnamed en-16x9-unnamed}"
for CUT in $CUTS; do
  nix shell nixpkgs#nodejs_22 -c npx remotion render src/index.ts "$CUT" "out/rainwatch-$CUT.mp4" \
    --codec=h264 --crf=17 --pixel-format=yuv420p --muted --log=error
done
