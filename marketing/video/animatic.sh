#!/bin/sh
# A quick small draft of every shot, every fourth frame, to judge the cut before the long render.
#   ./animatic.sh <language> ["<shot> ..."]
# Written by AI on 2026.11.18 by model claude fable 5.2.
cd "$(dirname "$0")"
. ./paths.sh
LANGUAGE=${1:-en}
for SHOT in ${2:-glance street rain series se end}; do
  "$BLENDER" -b --python blender/film.py -- --gen "$WORK/gen" --out "$WORK/animatic-$LANGUAGE" --language "$LANGUAGE" --shot "$SHOT" --draft --step 4 2>&1 | grep -E "Error|Traceback|Exception|line [0-9]+, in"
done
