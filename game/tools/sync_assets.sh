#!/bin/sh
# Copies the generated 960x540 level assets, the SFX and the music into the Godot
# project (the music and ambience encoded to Ogg). Re-run after art/levels/tools/build.py.
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
# the practice ball machine (art/sprites/machine, built in Aseprite)
mkdir -p "$DST/machine"
$SYNC "$KIT/art/sprites/machine/out/" "$DST/machine/"
# the HD set (audio/hd-sfx/make_sfx.py) and the soundtrack
# (audio/music/make_music.py); the SNES originals stay in audio/snes-sfx.
# Effects ship as WAV (imported as QOA); the music and the ambience loops
# as Ogg Vorbis, encoded here (ADR-083; needs soundfile in .venv). Excluded
# files are left alone by --delete, so the .ogg files stay.
$SYNC --exclude="music_*" --exclude="ambience_*" --include="*.wav" --exclude="*" \
  "$KIT/audio/hd-sfx/out/" "$KIT/audio/music/out/" "$DST/audio/"
"$KIT/.venv/bin/python" "$KIT/game/tools/encode_ogg.py" "$DST/audio" \
  "$KIT/audio/music/out/"music_*.wav "$KIT/audio/hd-sfx/out/"ambience_*.wav
# a loop whose source is gone, or the WAV it replaced, leaves files behind
for f in "$DST/audio/"music_*.ogg "$DST/audio/"ambience_*.ogg; do
  n="$(basename "${f%.ogg}")"
  [ -e "$KIT/audio/music/out/$n.wav" ] || [ -e "$KIT/audio/hd-sfx/out/$n.wav" ] || rm -f "$f" "$f.import"
done
rm -f "$DST/audio/"music_*.wav* "$DST/audio/"ambience_*.wav*
# the announcer (audio/announcer/prep.py, from the recordings in raw/)
mkdir -p "$DST/audio/announcer"
$SYNC --include="*.wav" --exclude="*" "$KIT/audio/announcer/out/" "$DST/audio/announcer/"
# a line removed (design/announcer/removed.txt) leaves its .import behind
for imp in "$DST/audio/announcer/"*.wav.import; do
  [ -e "${imp%.import}" ] || rm -f "$imp"
done
echo "synced assets into $DST"
