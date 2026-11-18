#!/bin/sh
# Makes the film from the app's current code and words: both cuts.
#   marketing/video/render.sh [language ...]      English unless another is named
# It takes about 45 minutes on an M4 Pro; shots.sh skips frames that are already rendered, so it
# can be stopped and run again. README.md says what each step is.
# Written by AI on 2026.11.18 by model claude fable 5.2.
set -e
cd "$(dirname "$0")"
. ./paths.sh
GEN="$WORK/gen"

# 1. The forecast, the fonts, and the app's own views drawn by the app's own code in each language.
#    The face's clock is in Kabul's time zone because that is how the face screenshots were taken.
uv run -q --with numpy python data.py "$GEN"
uv run -q --with fonttools python fonts.py "$GEN"
ln -sfn ../../.. export/app
(cd export && swift build -q)
TZ=Asia/Kabul ./export/.build/debug/film-export "$GEN" "$PWD/face" en > /dev/null
TZ=Asia/Kabul ./export/.build/debug/film-export "$GEN" "$PWD/face" nl -AppleLanguages "(nl)" > /dev/null
uv run -q --with pillow python others.py "$GEN"

# 2. The music.
(cd music && uv run -q score.py "$WORK/music")

# 3. The shots, the cut and the finished films.
mkdir -p "$WORK/films"
for LANGUAGE in ${*:-en}; do
  ./shots.sh "$LANGUAGE" glance street rain se series end end-unnamed
  for CUT in "" -unnamed; do
    uv run -q python assemble.py "$WORK/shots-$LANGUAGE" "$WORK/cut-$LANGUAGE$CUT" ${CUT:+--unnamed}
    ./finish.sh "$WORK/cut-$LANGUAGE$CUT" "$WORK/music/music.wav" "$WORK/films/rainwatch-$LANGUAGE-9x16$CUT.mp4"
  done
done
