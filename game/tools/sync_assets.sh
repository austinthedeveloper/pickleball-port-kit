#!/bin/sh
# Copies the generated 960x540 level assets, the SFX and the music into the Godot
# project. Re-run after art/levels/tools/build.py.
#
# rsync, not rm + cp: Godot's .import files beside each asset stay (with
# their uids), so a sync changes only what the build changed; files the
# build no longer makes are deleted (KNOWN_ISSUES #43).
set -e
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
DST="$KIT/game/assets"
SYNC="rsync -a --delete --exclude=*.import"
mkdir -p "$DST/levels" "$DST/audio" "$DST/park"
for d in venues sprites ui; do
  $SYNC "$KIT/art/levels/out/$d/" "$DST/levels/$d/"
done
cp "$KIT/art/levels/out/manifest.json" "$KIT/art/levels/out/palettes.json" "$DST/levels/"
# the open-play park (art/park/build_park.py)
$SYNC "$KIT/art/park/out/" "$DST/park/"
# the HD set (audio/hd-sfx/make_sfx.py) and the soundtrack
# (audio/music/make_music.py); the SNES originals stay in audio/snes-sfx
$SYNC --include="*.wav" --exclude="*" "$KIT/audio/hd-sfx/out/" "$KIT/audio/music/out/" "$DST/audio/"
# the announcer (audio/announcer/prep.py, from the recordings in raw/)
mkdir -p "$DST/audio/announcer"
$SYNC --include="*.wav" --exclude="*" "$KIT/audio/announcer/out/" "$DST/audio/announcer/"
echo "synced assets into $DST"
