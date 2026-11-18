#!/bin/sh
# Turns a run of frames into a film: the lens's glow, a little grain, the music.
#   ./finish.sh <cut folder> <music.wav or none> <out.mp4> [frames a second]
# Written by AI on 2026.11.18 by model claude fable 5.2.
set -e
CUT=$1; MUSIC=$2; OUT=$3; RATE=${4:-30}
# The picture is enlarged to 1080 x 1920 (paths.sh says why it is rendered smaller). Then the glow:
# what is bright, blurred wide and laid back over the picture, as a wet lens does.
# It is done on red, green and blue: in the film's own YUV the blend tints the picture.
LOOK="scale=1080:1920:flags=lanczos,format=gbrp,split[a][b];[b]colorlevels=rimin=0.5:gimin=0.5:bimin=0.5,gblur=sigma=24[glow];[a][glow]blend=all_mode=screen:all_opacity=0.3,vignette=a=PI/5.2,noise=alls=3:allf=t,format=yuv420p"
if [ "$MUSIC" = none ]; then
  ffmpeg -v error -y -framerate "$RATE" -i "$CUT/%04d.png" -vf "$LOOK" -c:v libx264 -preset slow -crf 20 -maxrate 12M -bufsize 24M \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -movflags +faststart "$OUT"
else
  ffmpeg -v error -y -framerate "$RATE" -i "$CUT/%04d.png" -i "$MUSIC" -vf "$LOOK" -c:v libx264 -preset slow -crf 20 -maxrate 12M -bufsize 24M \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a aac -b:a 256k -shortest -movflags +faststart "$OUT"
fi
echo "$OUT"
