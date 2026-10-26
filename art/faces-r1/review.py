"""Try the snapped heads (heads.json, from snap.py) on the game's bodies:
one row per head, with the bare head, every hat, two more skin and hair
palettes, and the swing and run frames.

    .venv/bin/python art/faces-r1/review.py

Writes review_<sheet>.png, one per generated sheet.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
sys.path.insert(0, os.path.join(ROOT, "art", "levels", "tools"))
import build as B  # noqa: E402
import players as P  # noqa: E402

FEMALE = {"b1", "b2", "b3", "b4", "b5", "d5",           # round 1
          "f4", "f5", "g2", "h1", "h2", "h3"}             # round 2
COLS = ([("idle0", None, "light", "brown"), ("idle0", "cap", "light", "brown")]
        + [("idle0", h, "light", "brown") for h in P.HATS]
        + [("idle0", None, "dark", "black"), ("idle0", "visor", "tan", "blonde"),
           ("idle0", "beanie", "brown", "red"), ("swing", "cap", "light", "brown"),
           ("run1", None, "light", "brown")])
CROP = (26, 0, 102, 66)          # the head and shoulders of a 128 px frame
Z = 3


def head_from(rows):
    def parts(neck, female=False, pony="hang"):
        nx, ny = round(neck[0]), round(neck[1])
        head = P.Part(outlined=False)
        for y, r in enumerate(rows):
            for x, k in enumerate(r):
                if k != ".":
                    head.px[(x + nx - 22, y + ny - 44)] = k
        cap = P.Part(outlined=True)
        cap.px = ORIG(neck)[1].px
        return head, cap, None
    return parts


ORIG = P.head_parts


def frame(rows, slot, hat, skin, hair, female):
    P.head_parts = head_from(rows)
    try:
        g, _ = P.render(P.POSES[slot], female, hat=hat)
    finally:
        P.head_parts = ORIG
    cols = B.team_colors("red" if female else "blue", skin, hair)
    im = Image.fromarray(B.rows_rgba(g, cols)).crop(CROP)
    return im


def main():
    heads = json.load(open(os.path.join(HERE, "heads.json")))
    w, h = CROP[2] - CROP[0], CROP[3] - CROP[1]
    for sheet in sorted({k[0] for k in heads}):
        names = sorted(k for k in heads if k[0] == sheet)
        out = Image.new("RGBA", (w * len(COLS), h * len(names)), (88, 140, 90, 255))
        for j, name in enumerate(names):
            for i, (slot, hat, skin, hair) in enumerate(COLS):
                fr = frame(heads[name], slot, hat, skin, hair, name in FEMALE)
                out.alpha_composite(fr, (i * w, j * h))
        out = out.resize((out.width * Z, out.height * Z), Image.NEAREST)
        out.save(os.path.join(HERE, f"review_faces_{sheet}.png"))
        print("review", sheet, out.size)


if __name__ == "__main__":
    main()
