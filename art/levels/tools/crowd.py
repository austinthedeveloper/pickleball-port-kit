"""Spectators, front-facing, for the stands: sitting (anchor = seat) or
standing (anchor = feet). Two frames each: idle and cheering (arms up).
Colours are baked (each spectator is its own person)."""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

from players import Part, lerp

HERE = Path(__file__).resolve().parent
PAL = json.loads((HERE / "../../sprites/hd/src/palettes.json").read_text())

FW, FH = 32, 64                       # frame size
SEAT = (16, 40)                       # seat anchor in a sitting frame
FEET = (16, 62)                       # feet anchor in a standing frame

SHIRTS = [("204a9c", "2f66c8", "4f8ae6", "86b2f4"), ("8c2a2a", "b83c3c", "d85a50", "f08a78"),
          ("1e6a3a", "2c8a4c", "48a862", "7cc88a"), ("a87818", "d09a24", "eabb3a", "f6d870"),
          ("6a2a7a", "8a3c9c", "a85ab8", "c88ad4"), ("b8b8c0", "d4d4dc", "ecebf0", "ffffff"),
          ("1a6a6a", "238a88", "3aa8a2", "70c8c0"), ("b8506a", "d4688a", "e888a6", "f6b0c6"),
          ("3a3a44", "50505c", "6a6a78", "8c8c9a")]
PANTS = [("1c2438", "28344e", "3a4a6a"), ("3a3024", "54452e", "6e5a3a"),
         ("6a6a70", "8a8a90", "a8a8ae"), ("1e3a5c", "2a5080", "3c68a0")]
HATS = [None, None, "cap", "sunhat", "cap", None]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def person(seed, pose="sit", cheer=False):
    rng = random.Random(seed)
    skin = PAL["skins"][rng.choice(["light", "tan", "brown", "dark", "light", "tan"])]
    hair = PAL["hairs"][rng.choice(["brown", "black", "blonde", "red", "brown", "black"])]
    shirt = [rgb(c) for c in rng.choice(SHIRTS)]
    pants = [rgb(c) for c in rng.choice(PANTS)]
    hat = rng.choice(HATS)
    hatc = [rgb(c) for c in rng.choice(SHIRTS)]
    long_hair = rng.random() < 0.4
    shades = rng.random() < 0.25
    col = {"o": (24, 20, 36), "1": skin["1"], "2": skin["2"], "3": skin["3"],
           "4": skin["4"], "h": hair["h"], "H": hair["H"], "i": hair["i"],
           "D": shirt[0], "d": shirt[1], "M": shirt[2], "L": shirt[3],
           "q": pants[0], "w": pants[1], "W": pants[2],
           "x": (238, 240, 246), "X": (170, 176, 196), "g": (110, 114, 130),
           "a": hatc[0], "b": hatc[1], "c": hatc[2], "Z": (255, 255, 255),
           "y": (196, 170, 104), "Y": (226, 204, 140), "k": (20, 20, 26)}
    sit = pose == "sit"
    ax, ay = SEAT if sit else FEET
    hip_y = ay if sit else ay - 22
    neck = (ax, hip_y - (15 if sit else 18))
    parts = []
    # legs
    legs = Part()
    for side in (-1, 1):
        hx = ax + side * 3.5
        if sit:
            knee = (hx + side * 0.8, hip_y + 2)
            ankle = (hx + side * 0.8, hip_y + 10)
            legs.capsule((hx, hip_y), knee, 3.2, 3.0, "shorts")
            legs.capsule(knee, ankle, 2.4, 2.0, "skin" if rng.random() < 0.6 else "shorts")
        else:
            knee = (hx, hip_y + 11)
            ankle = (hx + side * 0.5, hip_y + 20)
            legs.capsule((hx, hip_y), knee, 3.3, 2.8, "shorts")
            legs.capsule(knee, ankle, 2.4, 2.0, "skin")
        for x in range(int(ankle[0] - 3), int(ankle[0] + 4)):
            for y in range(int(ankle[1] + 1), int(ankle[1] + 4)):
                legs.px[(x, y)] = "g" if y == int(ankle[1] + 3) else ("x" if y == int(ankle[1] + 1) else "X")
    legs.despeckle()
    parts.append(legs)
    # torso
    body = Part()
    for y in range(int(neck[1] + 2), int(hip_y + 2)):
        t = (y - neck[1]) / (hip_y - neck[1])
        half = 7.5 - 1.2 * t
        for x in range(int(ax - half), int(ax + half + 1)):
            v = (x + 0.5 - ax) / half
            ch = "L" if v < -0.55 else ("d" if v > 0.55 else "M")
            if y >= hip_y:
                ch = "D"
            body.px[(x, y)] = ch
    for x in range(int(ax - 2), int(ax + 3)):          # neckline
        body.px[(x, int(neck[1] + 2))] = "3"
    body.px[(ax, int(neck[1] + 3))] = "2"
    parts.append(body)
    # arms
    arms = Part()
    for side in (-1, 1):
        sh = (ax + side * 6.5, neck[1] + 4)
        if cheer:
            el = (ax + side * 10, neck[1] - 2)
            ha = (ax + side * 11, neck[1] - 10)
        elif sit:
            el = (ax + side * 8, hip_y - 3)
            ha = (ax + side * 5.5, hip_y + 2)
        else:
            el = (ax + side * 8.5, hip_y - 6)
            ha = (ax + side * 8, hip_y + 1)
        arms.capsule(el, ha, 1.8, 1.6, "skin")
        arms.capsule(sh, el, 2.0, 1.8, "skin")
        arms.capsule(sh, lerp(sh, el, 0.45), 2.6, 2.3, "shirt")
        arms.capsule(ha, ha, 2.0, 2.0, "skin")
    arms.despeckle()
    # head
    head = Part()
    cx, cy = ax, neck[1] - 6
    for y in range(int(cy - 8), int(cy + 8)):
        for x in range(int(cx - 7), int(cx + 8)):
            px, py = x + 0.5 - cx, y + 0.5 - cy
            if (px / 5.6) ** 2 + (py / 6.6) ** 2 > 1:
                continue
            top = py < -2.5 + abs(px) * 0.25
            side = abs(px) > 4.2 and py < 2
            if top or (long_hair and abs(px) > 3.8 and py < 5):
                head.px[(x, y)] = "i" if px < -1 and py < -4 else "H"
            elif side and not long_hair:
                head.px[(x, y)] = "h"
            else:
                head.px[(x, y)] = "2" if py > 4 else ("4" if px < -2 and py < 0 else "3")
    if long_hair:
        for y in range(int(cy), int(cy + 9)):
            for sx in (-6, -5, 5, 6):
                head.px[(cx + sx, y)] = "H" if abs(sx) == 5 else "h"
    ey = int(cy)
    if shades:
        for x in range(int(cx - 4), int(cx + 4)):
            head.px[(x, ey)] = "k"
        head.px[(cx - 3, ey - 1)] = "k"
        head.px[(cx + 2, ey - 1)] = "k"
    else:
        head.px[(cx - 2, ey)] = "o"
        head.px[(cx + 2, ey)] = "o"
    head.px[(cx, ey + 3)] = "1" if not cheer else "o"
    if cheer:
        head.px[(cx - 1, ey + 3)] = "o"
        head.px[(cx + 1, ey + 3)] = "o"
    # neck
    nk = Part()
    nk.capsule((ax, neck[1] - 1), (ax, neck[1] + 2), 2.2, 2.2, "skin")
    for k in nk.px:
        nk.px[k] = "2"
    parts += [nk, head]
    # hat
    if hat == "cap":
        hp = Part()
        for y in range(int(cy - 8), int(cy - 2)):
            for x in range(int(cx - 6), int(cx + 7)):
                px, py = x + 0.5 - cx, y + 0.5 - cy
                if (px / 6.0) ** 2 + (py / 7.0) ** 2 <= 1 and py < -2.5:
                    hp.px[(x, y)] = "c" if px < -1 else "b"
        for x in range(int(cx - 6), int(cx + 7)):
            hp.px[(x, int(cy - 3))] = "a"
        parts.append(hp)
    elif hat == "sunhat":
        hp = Part()
        for y in range(int(cy - 9), int(cy - 2)):
            for x in range(int(cx - 5), int(cx + 6)):
                px, py = x + 0.5 - cx, y + 0.5 - cy
                if (px / 5.2) ** 2 + (py / 6.5) ** 2 <= 1 and py < -2.5:
                    hp.px[(x, y)] = "Y"
        for x in range(int(cx - 9), int(cx + 10)):
            hp.px[(x, int(cy - 3))] = "y"
            if abs(x - cx) < 8:
                hp.px[(x, int(cy - 4))] = "Y"
        for x in range(int(cx - 5), int(cx + 6)):
            hp.px[(x, int(cy - 5))] = "a"
        parts.append(hp)
    parts.append(arms)
    # composite
    g = [["."] * FW for _ in range(FH)]
    for p in parts:
        for (x, y) in p.outline():
            if 0 <= x < FW and 0 <= y < FH:
                g[y][x] = "o"
        for (x, y), ch in p.px.items():
            if 0 <= x < FW and 0 <= y < FH:
                g[y][x] = ch
    a = np.zeros((FH, FW, 4), np.uint8)
    for y in range(FH):
        for x in range(FW):
            ch = g[y][x]
            if ch != ".":
                a[y, x, :3] = col.get(ch, col["M"])
                a[y, x, 3] = 255
    return a


def sheet(n_sit=12, n_stand=4, seed=500):
    """Rows: each spectator; columns: idle, cheer."""
    rows = []
    for i in range(n_sit):
        rows.append(("sit", seed + i))
    for i in range(n_stand):
        rows.append(("stand", seed + 100 + i))
    img = np.zeros((FH * len(rows), FW * 2, 4), np.uint8)
    for r, (pose, sd) in enumerate(rows):
        img[r * FH:(r + 1) * FH, 0:FW] = person(sd, pose, False)
        img[r * FH:(r + 1) * FH, FW:2 * FW] = person(sd, pose, True)
    return img, rows
