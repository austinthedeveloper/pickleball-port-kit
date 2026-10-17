#!/bin/sh
# Copies the generated 960x540 level assets and the SFX into the Godot
# project. Re-run after art/levels/tools/build.py.
set -e
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
DST="$KIT/game/assets"
rm -rf "$DST/levels" "$DST/audio"
mkdir -p "$DST/levels" "$DST/audio"
cp -R "$KIT/art/levels/out/venues" "$KIT/art/levels/out/sprites" \
      "$KIT/art/levels/out/ui" "$DST/levels/"
cp "$KIT/art/levels/out/manifest.json" "$KIT/art/levels/out/palettes.json" "$DST/levels/"
cp "$KIT/audio/snes-sfx/"*.wav "$DST/audio/"
echo "synced assets into $DST"
