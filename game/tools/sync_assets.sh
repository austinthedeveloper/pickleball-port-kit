#!/bin/sh
# Copies the generated 960x540 level assets, the SFX and the music into the Godot
# project. Re-run after art/levels/tools/build.py.
set -e
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
DST="$KIT/game/assets"
rm -rf "$DST/levels" "$DST/audio"
mkdir -p "$DST/levels" "$DST/audio"
cp -R "$KIT/art/levels/out/venues" "$KIT/art/levels/out/sprites" \
      "$KIT/art/levels/out/ui" "$DST/levels/"
cp "$KIT/art/levels/out/manifest.json" "$KIT/art/levels/out/palettes.json" "$DST/levels/"
# the open-play park (art/park/build_park.py)
rm -rf "$DST/park" && mkdir -p "$DST/park" && cp "$KIT/art/park/out/"* "$DST/park/"
# the HD set (audio/hd-sfx/make_sfx.py); the SNES originals stay in audio/snes-sfx
cp "$KIT/audio/hd-sfx/out/"*.wav "$DST/audio/"
# the soundtrack (audio/music/make_music.py)
cp "$KIT/audio/music/out/"*.wav "$DST/audio/"
echo "synced assets into $DST"
