"""ROAD TRIP round 6 (port ADR-093): stand-ins for the art being made.

Recoloured cuts of the accepted art at the exact sizes PROMPTS.md asks
for, so the game runs until the real images replace them (import.py).
Run from the repo root:  .venv/bin/python art/roadtrip-r6/make_placeholders.py
Once the real art is in, running this again would overwrite it.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "roadtrip-r5"))
from make_placeholders import cell, recolour  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game/assets/trip"
OUT = Path(__file__).resolve().parent / "placeholders"


def main():
    OUT.mkdir(exist_ok=True)
    g1 = Image.open(SRC / "trip_gear_icons.png").convert("RGBA")
    g2 = Image.open(SRC / "trip_gear_icons_2.png").convert("RGBA")
    a = lambda i: cell(g1, i, 8, 64, 64)
    b = lambda i: cell(g2, i, 8, 64, 64)
    icons = [
        recolour(b(14), hue=0.93),            # PEP TALK
        recolour(a(19), hue=0.08),            # DAD'S PLAYBOOK
        recolour(b(7), hue=0.07, sat=0.6),    # MARGE'S PIE TIN
        recolour(b(3), hue=0.0),              # BRAD'S SHAKER
        recolour(a(4), hue=0.11, val=0.8),    # PETE'S SPYGLASS
        recolour(a(6), hue=0.78, val=0.6),    # RAVEN'S PARASOL
        recolour(b(5), hue=0.5),              # KAI'S BOARD WAX
        recolour(a(3), hue=0.13, sat=1.2),    # MAX'S LUCKY COIN
        recolour(a(8), hue=0.12),             # ACE'S GRIP
    ]
    sheet = Image.new("RGBA", (8 * 64, 2 * 64))
    for i, ic in enumerate(icons):
        sheet.paste(ic, ((i % 8) * 64, (i // 8) * 64), ic)
    sheet.save(OUT / "trip_gear_icons_3.png")
    for f in OUT.glob("*.png"):
        shutil.copy(f, SRC / f.name)
        print("wrote", f.name)


if __name__ == "__main__":
    main()
