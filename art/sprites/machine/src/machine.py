"""The practice ball machine, swing-arm style (art/concept/ball-machine.png, row C).

Draws the machine's three layers as PNGs in src/layers/, which
build_machine.lua assembles into machine.aseprite and the game's sheet:

- body: the cart, the hopper of balls, the wheels and the shadow;
- arm: the launcher arm at ANGLES (up the screen toward the far sideline
  first), one frame each, swinging about the pivot;
- hub: the pivot cap, drawn over the arm.

Facing left (toward P1). RGBA, one colour per ramp step, a 1 px dark
outline around every part.

    .venv/bin/python art/sprites/machine/src/machine.py
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

W, H = 36, 26
PIVOT = (14.5, 13.5)          # the arm's pivot, pixel centres at .5
ARM_LEN = 13.5                # pivot to muzzle
ARM_HALF = 2.4                # the barrel's half-thickness
ANGLES = [32, 24, 16, 8, 0, -8, -16, -24, -32]   # degrees above the horizontal

OUT = (29, 34, 48, 255)
BODY_HI = (196, 204, 214, 255)
BODY = (154, 163, 173, 255)
BODY_MID = (122, 131, 143, 255)
BODY_DK = (90, 98, 112, 255)
INSIDE = (44, 49, 60, 255)
BALL_HI = (255, 246, 160, 255)
BALL = (240, 216, 56, 255)
BALL_DK = (196, 160, 32, 255)
ORANGE = (240, 138, 36, 255)
ORANGE_DK = (190, 92, 24, 255)
WHEEL = (42, 46, 56, 255)
HUBCAP = (138, 146, 156, 255)
SHADOW = (0, 0, 0, 70)

HERE = os.path.dirname(os.path.abspath(__file__))


def canvas() -> np.ndarray:
    return np.zeros((H, W, 4), np.uint8)


def outline(img: np.ndarray) -> None:
    """A 1 px OUT ring around every opaque (non-shadow) pixel, 4-connected."""
    solid = img[:, :, 3] == 255
    ring = np.zeros_like(solid)
    ring[1:, :] |= solid[:-1, :]
    ring[:-1, :] |= solid[1:, :]
    ring[:, 1:] |= solid[:, :-1]
    ring[:, :-1] |= solid[:, 1:]
    ring &= ~solid
    img[ring] = OUT


def put(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y, x] = c


def rect(img, x0, y0, x1, y1, c):
    img[y0:y1 + 1, x0:x1 + 1] = c


def disc(img, cx, cy, r, c):
    for y in range(H):
        for x in range(W):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                img[y, x] = c


def ball(img, x, y):
    """A round 4x4 ball, its top-left at x, y: lit from the upper left."""
    rows = [".hb.", "hbbb", "bbbd", ".bd."]
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ".":
                put(img, x + dx, y + dy, {"h": BALL_HI, "b": BALL, "d": BALL_DK}[ch])


def body() -> np.ndarray:
    img = canvas()
    # the cart: a box, lit from above, a panel seam, a darker skirt
    rect(img, 13, 10, 32, 19, BODY)
    rect(img, 13, 10, 32, 10, BODY_HI)
    rect(img, 13, 18, 32, 19, BODY_DK)
    rect(img, 13, 11, 14, 17, BODY_MID)        # the front edge, toward the court
    rect(img, 24, 12, 24, 17, BODY_MID)        # a seam
    rect(img, 25, 12, 25, 17, BODY_HI)
    rect(img, 27, 14, 30, 14, BODY_DK)         # vents
    rect(img, 27, 16, 30, 16, BODY_DK)
    put(img, 16, 18, ORANGE)                   # the running light
    put(img, 17, 18, ORANGE)
    # the strut under the pivot
    rect(img, 13, 17, 16, 20, BODY_DK)
    # the hopper: wider at the top, dark inside, balls heaped over the rim
    for y in range(6, 10):
        grow = (9 - y) // 2
        x0, x1 = 15 - grow, 32 + grow
        rect(img, x0, y, x1, y, BODY_MID if y > 7 else BODY)
        put(img, x0, y, BODY_DK)
        put(img, x1, y, BODY_DK)
    rect(img, 13, 6, 34, 6, BODY_HI)           # the rim
    rect(img, 15, 4, 32, 5, INSIDE)
    for x, y in [(18, 0), (23, 0), (28, 1), (15, 3), (20, 3), (25, 3), (30, 3)]:
        ball(img, x, y)
    # wheels
    for cx in (17.0, 29.0):
        disc(img, cx, 22.0, 2.9, WHEEL)
        disc(img, cx, 22.0, 1.0, HUBCAP)
    outline(img)
    # the shadow, under everything
    for x in range(12, 35):
        for y in (24, 25):
            if img[y, x, 3] == 0 and not (y == 25 and x in (12, 34)):
                img[y, x] = SHADOW
    return img


def arm(deg: float) -> np.ndarray:
    """The barrel at `deg` above the horizontal, pointing left from the pivot."""
    img = canvas()
    a = math.radians(deg)
    d = (-math.cos(a), -math.sin(a))           # along the barrel, toward the muzzle
    n = (-d[1], d[0])                          # across it: n points down-ish (the shade side)
    if n[1] < 0:
        n = (-n[0], -n[1])
    px, py = PIVOT
    for y in range(H):
        for x in range(W):
            vx, vy = x + 0.5 - px, y + 0.5 - py
            t = vx * d[0] + vy * d[1]
            s = vx * n[0] + vy * n[1]
            if t < 0 or t > ARM_LEN or abs(s) > ARM_HALF:
                continue
            if t > ARM_LEN - 1.6:
                c = INSIDE if abs(s) < 1.0 and t > ARM_LEN - 0.8 else BODY_DK     # the muzzle ring
            elif s < -1.2:
                c = BODY_HI
            elif s > 1.2:
                c = BODY_DK
            elif 3.5 < t < ARM_LEN - 3.0 and -0.4 < s < 0.8:
                c = ORANGE if s < 0.4 else ORANGE_DK
            else:
                c = BODY_MID if s > 0.4 else BODY
            img[y, x] = c
    outline(img)
    return img


def hub() -> np.ndarray:
    img = canvas()
    disc(img, PIVOT[0], PIVOT[1], 2.9, BODY_DK)
    disc(img, PIVOT[0], PIVOT[1], 2.1, BODY_MID)
    disc(img, PIVOT[0] - 0.5, PIVOT[1] - 0.5, 1.1, BODY_HI)
    put(img, int(PIVOT[0]), int(PIVOT[1]), OUT)
    outline(img)
    return img


def main() -> None:
    out = os.path.join(HERE, "layers")
    os.makedirs(out, exist_ok=True)
    Image.fromarray(body()).save(os.path.join(out, "body.png"))
    Image.fromarray(hub()).save(os.path.join(out, "hub.png"))
    for i, deg in enumerate(ANGLES):
        Image.fromarray(arm(deg)).save(os.path.join(out, "arm_%d.png" % i))
    # a preview: every angle, composed, at 8x
    sheet = Image.new("RGBA", (W * len(ANGLES), H), (46, 140, 122, 255))
    for i in range(len(ANGLES)):
        f = Image.open(os.path.join(out, "body.png"))
        f.alpha_composite(Image.open(os.path.join(out, "arm_%d.png" % i)))
        f.alpha_composite(Image.open(os.path.join(out, "hub.png")))
        sheet.alpha_composite(f, (W * i, 0))
    sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(os.path.join(HERE, "..", "preview.png"))


if __name__ == "__main__":
    main()
