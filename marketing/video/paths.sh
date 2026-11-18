# Where the film's big files go and which Blender draws them. Sourced by the scripts here.
# Written by AI on 2026.11.18 by model claude fable 5.2.
# Renders and caches are tens of gigabytes: on Josh's Macs they belong on the external SSD.
if [ -z "$WORK" ]; then
  if [ -d "/Volumes/Josh Extreme Pro USB4 4TB" ]; then WORK="/Volumes/Josh Extreme Pro USB4 4TB/rainwatch-film"; else WORK="$PWD/out"; fi
fi
# nixpkgs has no ready-built Blender for Apple silicon (it compiles for an hour), so use one already
# in the nix store if there is one.
if [ -z "$BLENDER" ]; then
  BLENDER=$(ls -d /nix/store/*-blender-5.2*/bin/blender 2>/dev/null | head -1)
  [ -n "$BLENDER" ] || BLENDER="nix shell nixpkgs#blender -c blender"
fi
mkdir -p "$WORK"
# The picture is rendered at three quarters of its size and enlarged at the end (finish.sh): it
# takes a little over half the time, and X shows most people less than this.
SIZE=${SIZE:-"810 1440"}
