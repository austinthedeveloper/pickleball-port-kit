#!/bin/sh
# DINOSAUR's background dinosaurs (ADR-084): copies frames out of the SNES
# dinosaur game's art, as drawn, into out/ (game/tools/sync_assets.sh then
# puts them in game/assets/dinos/). The sources are only read.
#
#   DINO=/path/to/dinosaur art/sprites/dinos/export.sh
#
# DINO defaults to the sibling checkout (../dinosaur next to this kit).
set -e
KIT="$(cd "$(dirname "$0")/../../.." && pwd)"
DINO="${DINO:-$(cd "$KIT/.." && pwd)/dinosaur}"
ASE="${ASE:-$HOME/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite}"
SRC="$DINO/assets"
OUT="$KIT/art/sprites/dinos/out"
mkdir -p "$OUT"
rm -f "$OUT"/*.png

# The Carnotaurus with Nathan: 144x96 cells, facing right, feet on row 90.
for tag in mount_walk mount_idle mount_roar; do
  "$ASE" -b --tag "$tag" "$SRC/carnotaurus/aseprite/carnotaurus_mounted.aseprite" \
    --sheet "$OUT/carno_$tag.png" --sheet-type horizontal >/dev/null
done

# The others, as their own exports: two-pose idles (the previews keep both
# full poses in 96x64 cells, facing left, feet on the bottom row) and the
# two-frame walk and flap strips (32x32 cells).
cp "$SRC/enemies/spinosaurus-idle-preview.png" "$OUT/spinosaurus_idle.png"
cp "$SRC/enemies/baby-dino-patrol-sheet.png" "$OUT/baby_dino_walk.png"
cp "$SRC/enemies/pterodactyl-swoop-sheet.png" "$OUT/pterodactyl_flap.png"
echo "exported $(ls "$OUT" | wc -l | tr -d ' ') strips into $OUT"
