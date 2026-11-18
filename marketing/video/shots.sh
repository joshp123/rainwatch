#!/bin/sh
# Renders shots of the film at full quality; it skips frames that are already there, so it can be stopped and run again.
#   ./shots.sh <language> <shot> [<shot> ...]      shots: glance street rain se series end end-unnamed
# A part of a shot is <shot>:<first frame>-<frame after the last>, as in rain:504-616, for sharing a shot between two Macs.
# Written by AI on 2026.11.18 by model claude fable 5.2.
cd "$(dirname "$0")"
. ./paths.sh
LANGUAGE=$1; shift
# Blender is started afresh for every two bars of the film (112 frames): its memory grows while it
# renders, and on a Mac with little to spare that ends in swapping.
for SHOT in "$@"; do
  PART=
  case $SHOT in *:*) PART=${SHOT#*:}; SHOT=${SHOT%%:*} ;; esac
  case $SHOT in
    glance) FIRST=0; LAST=196 ;; street) FIRST=196; LAST=392 ;; rain) FIRST=392; LAST=616 ;;
    se) FIRST=616; LAST=644 ;; series) FIRST=644; LAST=672 ;; end) FIRST=672; LAST=840 ;; end-unnamed) FIRST=672; LAST=800 ;;
  esac
  case $SHOT in end-unnamed) FLAGS="--shot end --unnamed" ;; *) FLAGS="--shot $SHOT" ;; esac
  case $PART in *-*) FIRST=${PART%-*}; LAST=${PART#*-} ;; esac
  while [ "$FIRST" -lt "$LAST" ]; do
    NEXT=$((FIRST + 112)); [ "$NEXT" -gt "$LAST" ] && NEXT=$LAST
    $BLENDER -b --python blender/film.py -- --gen "$WORK/gen" --out "$WORK/shots-$LANGUAGE" --language "$LANGUAGE" $FLAGS --size $SIZE --frames "$FIRST" "$NEXT" 2>&1 \
      | grep --line-buffered -E "^FRAME|Error|Traceback|Exception|line [0-9]+, in"
    FIRST=$NEXT
  done
  echo "DONE $LANGUAGE $SHOT"
done
