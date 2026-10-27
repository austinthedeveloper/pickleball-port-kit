"""The faces round 1 guide: the current head on its 48x48 art-pixel cell,
8x, with the hat zone, the hat band and the neck marked, and the head
under the cap, beanie and bucket so the generator sees what hats cover.

    .venv/bin/python art/faces-r1/make_guide.py
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..")
sys.path.insert(0, os.path.join(ROOT, "art", "levels", "tools"))
import players as P  # noqa: E402

PLAYERS = os.path.join(ROOT, "art", "levels", "out", "sprites", "players")
CELL, Z = 48, 8
NECK = (62, 44)                       # idle0's neck in the 128 px frame
OX, OY = NECK[0] - 22, NECK[1] - 44   # the cell puts the neck at (22, 44)
BG = (200, 214, 200, 255)


def cell(sheet, hat=None):
    im = Image.open(os.path.join(PLAYERS, sheet)).convert("RGBA")
    c = Image.new("RGBA", (CELL, CELL), BG)
    body = im.crop((OX, OY, OX + CELL, OY + CELL))
    c.alpha_composite(body)
    if hat:
        h = Image.open(os.path.join(PLAYERS, "roles", hat)).convert("RGBA")
        c.alpha_composite(h.crop((OX, OY, OX + CELL, OY + CELL)))
    return c.resize((CELL * Z, CELL * Z), Image.NEAREST)


def marks(img):
    d = ImageDraw.Draw(img)
    cx, cy = 22 + 1, 44 - 20                       # skull centre
    rx, ry = 11.4, 10.6                            # the hats' dome
    d.ellipse(((cx - rx) * Z, (cy - ry) * Z, (cx + rx) * Z, (cy + ry) * Z),
              outline=(255, 0, 160), width=3)
    band = (cy - 3) * Z
    d.line((0, band, CELL * Z, band), fill=(255, 0, 160), width=2)
    nx, ny = 22 * Z, 44 * Z
    d.ellipse((nx - 10, ny - 10, nx + 10, ny + 10), outline=(0, 90, 255), width=4)
    for i in range(0, CELL * Z + 1, Z * 8):        # 8 px grid
        d.line((i, 0, i, CELL * Z), fill=(0, 0, 0, 40))
        d.line((0, i, CELL * Z, i), fill=(0, 0, 0, 40))


def main():
    m = cell("player_male_blue.png")
    marks(m)
    f = cell("player_female_red.png")
    marks(f)
    panels = [m, f,
              cell("player_male_blue.png", "player_male_cap.png"),
              cell("player_male_blue.png", "player_male_beanie.png"),
              cell("player_male_blue.png", "player_male_bucket.png"),
              cell("player_female_red.png", "player_female_headband.png")]
    out = Image.new("RGBA", (len(panels) * CELL * Z + (len(panels) - 1) * 16,
                             CELL * Z), (255, 255, 255, 255))
    for i, p in enumerate(panels):
        out.alpha_composite(p, (i * (CELL * Z + 16), 0))
    out.save(os.path.join(HERE, "guide_head_cell.png"))
    # the bare cell alone, unmarked: the exact layout to copy
    cell("player_male_blue.png").save(os.path.join(HERE, "guide_cell_plain.png"))
    female_no_tail().save(os.path.join(HERE, "guide_female_no_tail.png"))


def female_no_tail():
    """Round 2: the woman's head without the ponytail the game adds."""
    import build as B
    orig = P.head_parts
    P.head_parts = lambda neck, female=False, pony="hang": orig(neck, True, pony)[:2] + (None,)
    try:
        g, _ = P.render(P.POSES["idle0"], True, hat=None)
    finally:
        P.head_parts = orig
    im = Image.fromarray(B.rows_rgba(g, B.team_colors("red")))
    c = Image.new("RGBA", (CELL, CELL), BG)
    c.alpha_composite(im.crop((OX, OY, OX + CELL, OY + CELL)))
    c = c.resize((CELL * Z, CELL * Z), Image.NEAREST)
    marks(c)
    return c


if __name__ == "__main__":
    main()
