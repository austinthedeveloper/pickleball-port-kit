"""ROAD TRIP round 6 (port ADR-093): brings the finished art into the game.

Drop the generated PNGs in art/roadtrip-r6/ under the names in PROMPTS.md,
then run from the repo root:  .venv/bin/python art/roadtrip-r6/import.py
Each image is checked for its exact size (and for transparency, the
sheets); backdrops go to game/assets/trip as lossy WebP, sheets as PNG,
replacing the placeholders. Files not there yet are skipped (their
placeholder stays). Then: godot --headless --path game --import
"""
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
DEST = HERE.parents[1] / "game/assets/trip"
BACKDROPS = {"trip_map_islands": (600, 330)}
SHEETS = {"trip_gear_icons_3": (512, 128)}


def main() -> int:
    bad = 0
    for name, size in {**BACKDROPS, **SHEETS}.items():
        src = HERE / (name + ".png")
        if not src.exists():
            print("waiting for", src.name)
            continue
        img = Image.open(src)
        if img.size != size:
            print(f"{src.name}: {img.size}, wants {size}")
            bad += 1
            continue
        if name in SHEETS:
            img = img.convert("RGBA")
            if img.getextrema()[3][0] > 0:
                print(f"{src.name}: no transparent pixels; a sheet needs a clear background")
                bad += 1
                continue
            img.save(DEST / (name + ".png"))
        else:
            img.convert("RGB").save(DEST / (name + ".webp"), "WEBP", quality=82, method=6)
        print("imported", name)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
