"""ROAD TRIP round 5 (port ADR-092): brings the finished art into the game.

Drop the generated PNGs in art/roadtrip-r5/ under the names in PROMPTS.md,
then run from the repo root:  .venv/bin/python art/roadtrip-r5/import.py
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
BACKDROPS = {"trip_scene_diner": (960, 540), "trip_scene_old_court": (960, 540),
             "trip_van_interior": (960, 540), "trip_scrapbook": (960, 540)}
SHEETS = {"trip_gear_icons_2": (512, 192), "trip_hazard_icons_2": (256, 64),
          "trip_pins_2": (64, 80), "trip_rv": (64, 40)}


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
