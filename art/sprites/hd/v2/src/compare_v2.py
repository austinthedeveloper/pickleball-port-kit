#!/usr/bin/env python3
"""Old vs v2 previews from the built sheets: a still of every frame and one
side-by-side GIF per tag (old left, v2 right), on the court colour.

    .venv/bin/python art/sprites/hd/v2/src/compare_v2.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

V2 = Path(__file__).resolve().parent.parent
HD = V2.parent
CELL, PAD, GROUND = 64, 4, 58
BG, SHADOW = (44, 122, 108), (28, 82, 72)
TAGS = {"idle": ([0, 1], 300), "run": ([2, 3, 4, 5], 90),
        "swing": ([6, 7, 8], 140), "toss": ([9], 200), "cheer": ([10], 200)}


def frames(path):
    sheet = Image.open(path).convert("RGBA")
    return [sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
            for i in range(sheet.width // CELL)]


def cell(img):
    c = Image.new("RGB", (CELL, CELL), BG)
    ImageDraw.Draw(c).ellipse((12, GROUND - 2.5, 42, GROUND + 2.5), fill=SHADOW)
    c.paste(img, (0, 0), img)
    return c


def main(team="blue", scale=6):
    rows = []
    for v in ("male", "female"):
        rows.append(frames(HD / f"player_hd_{v}_{team}.png"))
        rows.append(frames(V2 / f"player_hd_{v}_v2_{team}.png"))
    n = len(rows[0])
    still = Image.new("RGB", (n * (CELL + PAD) + PAD, len(rows) * (CELL + PAD) + PAD), BG)
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            still.paste(cell(f), (PAD + i * (CELL + PAD), PAD + r * (CELL + PAD)))
    still = still.resize((still.width * scale, still.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(still)
    for r, label in enumerate(("male, old", "male, v2", "female, old", "female, v2")):
        d.text((8, (PAD + r * (CELL + PAD)) * scale + 6), label, fill=(255, 255, 255))
    still.save(V2 / "preview_compare_v2.png")

    for tag, (idx, ms) in TAGS.items():
        out = []
        for i in idx:
            f = Image.new("RGB", (4 * CELL + 5 * PAD, CELL + 2 * PAD), BG)
            for k, row in enumerate(rows[0:2] + rows[2:4]):
                f.paste(cell(row[i]), (PAD + k * (CELL + PAD), PAD))
            out.append(f.resize((f.width * scale, f.height * scale), Image.NEAREST))
        out[0].save(V2 / f"compare_{tag}.gif", save_all=True,
                    append_images=out[1:], duration=ms, loop=0, disposal=1)


if __name__ == "__main__":
    main()
