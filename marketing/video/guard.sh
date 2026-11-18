#!/bin/sh
# Runs a render queue only while it fits in this Mac's memory: if the machine starts swapping hard
# the render is stopped (its frames are kept) and started again when memory is free.
#   ./guard.sh '<commands>'      for example  ./guard.sh './shots.sh en glance street && ./shots.sh nl glance'
# Its log is $WORK/guard.log; it ends when the queue has finished. It starts when FREE per cent of
# memory is free (45 unless set): give it more on a Mac that other work is filling.
# Written by AI on 2026.11.18 by model claude fable 5.2, after an unguarded render made Josh's MacBook swap.
cd "$(dirname "$0")"
. ./paths.sh
export WORK
QUEUE="$1 && echo QUEUE-DONE"
LOG="$WORK/guard.log"
: > "$LOG"
free() { memory_pressure | awk '/free percentage/{gsub("%","",$5); print $5}'; }
out() { a=$(vm_stat | awk '/Swapouts/{print $2+0}'); sleep 30; b=$(vm_stat | awk '/Swapouts/{print $2+0}'); echo $(( (b - a) * 16 / 1024 )); }
while true; do
  if ! pgrep -f "^/bin/sh ./shots.sh" > /dev/null; then
    grep -q QUEUE-DONE "$LOG" && exit 0
    if [ "$(free)" -ge "${FREE:-45}" ]; then echo "$(date +%H:%M:%S) start, free $(free)%" >> "$LOG"; (sh -c "$QUEUE" >> "$LOG" 2>&1 &); sleep 120; else sleep 60; continue; fi
  fi
  HARD=0
  for i in 1 2 3; do [ "$(out)" -ge 150 ] && HARD=$((HARD + 1)); done
  if [ "$HARD" -ge 3 ]; then echo "$(date +%H:%M:%S) stopped: swapping hard, free $(free)%" >> "$LOG"; pkill -f "^/bin/sh ./shots.sh"; pkill -f "blender/film.py"; sleep 300; fi
done
