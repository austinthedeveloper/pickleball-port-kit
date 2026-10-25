"""ROAD TRIP round 5 (port ADR-092): stand-ins for the art being made.

Each placeholder is a recoloured cut of the accepted art (the v3/r4 sheets
in game/assets/trip), at the exact size the real image will have, so the
game runs and looks roughly right until PROMPTS.md's images replace them.
Run from the repo root:  .venv/bin/python art/roadtrip-r5/make_placeholders.py
Writes art/roadtrip-r5/placeholders/*.png and copies them into game/assets/trip.
The real art is in now (REVIEW.md): running this again would overwrite it.
"""
import colorsys
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game/assets/trip"
OUT = Path(__file__).resolve().parent / "placeholders"


def cell(img, i, cols, w, h):
    return img.crop(((i % cols) * w, (i // cols) * h, (i % cols) * w + w, (i // cols) * h + h))


def recolour(img, hue=None, sat=1.0, val=1.0):
    """Sets every pixel's hue (0..1) or keeps it, scales saturation and value."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    out = a.copy()
    flat = a[..., :3].reshape(-1, 3)
    res = np.empty_like(flat)
    for k, (r, g, b) in enumerate(flat):
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if hue is not None and s > 0.12:
            h = hue
        res[k] = colorsys.hsv_to_rgb(h, min(1.0, s * sat), min(1.0, v * val))
    out[..., :3] = res.reshape(a.shape[0], a.shape[1], 3)
    return Image.fromarray((out * 255).astype(np.uint8))


def fit(img, w, h):
    """Scales to fit inside w x h (2 px margin) and centres on a clear cell."""
    box = img.getbbox() or (0, 0, img.width, img.height)
    img = img.crop(box)
    k = min((w - 4) / img.width, (h - 4) / img.height)
    img = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS)
    c = Image.new("RGBA", (w, h))
    c.paste(img, ((w - img.width) // 2, (h - img.height) // 2), img)
    return c


def main():
    OUT.mkdir(exist_ok=True)
    gear = Image.open(SRC / "trip_gear_icons.png").convert("RGBA")
    orn = Image.open(SRC / "trip_dash_ornaments.png").convert("RGBA")
    g = lambda i: cell(gear, i, 8, 64, 64)
    cassette = orn.crop((0, 104, 40, 130))
    dice = cell(orn, 5, 6, 48, 64)
    icons = [
        recolour(g(8), sat=0.0, val=0.7),            # lead tape
        recolour(g(10), hue=0.09, sat=0.5),          # ankle braces
        recolour(g(18), hue=0.6),                    # energy drink
        recolour(g(18), hue=0.07, sat=0.6, val=0.8),  # protein shake
        recolour(g(7), hue=0.92),                    # flip-flops
        recolour(g(18), hue=0.1),                    # sunscreen
        recolour(g(18), hue=0.15),                   # tip jar
        recolour(g(2), hue=0.0),                     # first aid kit
        fit(cassette, 64, 64),                       # mixtape
        recolour(g(4), sat=0.4, val=0.6),            # CB radio
        recolour(g(5), hue=0.58),                    # gas card
        recolour(g(13), hue=0.13),                   # loyalty card
        recolour(g(9), hue=0.5),                     # thermos
        fit(dice, 64, 64),                           # lucky dice
        recolour(g(0), hue=0.78),                    # partner's paddle
        recolour(g(10), hue=0.33),                   # team jerseys
        recolour(g(23), sat=0.6, val=0.75),          # grandpa's paddle
        recolour(g(25), hue=0.97, val=0.7),          # road hog paddle
        recolour(g(26), sat=1.3, val=1.15),          # champion's paddle
    ]
    sheet = Image.new("RGBA", (8 * 64, 3 * 64))
    for i, ic in enumerate(icons):
        sheet.paste(ic, ((i % 8) * 64, (i // 8) * 64), ic)
    sheet.save(OUT / "trip_gear_icons_2.png")

    hz = Image.open(SRC / "trip_hazard_icons.png").convert("RGBA")
    h = lambda i: cell(hz, i, 5, 64, 64)
    hazards = [recolour(h(2), hue=0.06), recolour(h(2), sat=0.0, val=1.2),
               recolour(h(1), hue=0.14, val=1.4), recolour(h(3), hue=0.75)]
    sheet = Image.new("RGBA", (4 * 64, 64))
    for i, ic in enumerate(hazards):
        sheet.paste(ic, (i * 64, 0), ic)
    sheet.save(OUT / "trip_hazard_icons_2.png")

    pins = Image.open(SRC / "trip_pins.png").convert("RGBA")
    p = lambda col, row: pins.crop((col * 32, row * 40, col * 32 + 32, row * 40 + 40))
    sheet = Image.new("RGBA", (2 * 32, 2 * 40))
    for row in (0, 1):
        sheet.paste(recolour(p(6, row), hue=0.5), (0, row * 40))       # diner: the motel's sign in teal
        sheet.paste(recolour(p(3, row), hue=0.8), (32, row * 40))      # rivals: a purple paddle
    sheet.save(OUT / "trip_pins_2.png")

    van = Image.open(SRC / "trip_van.png").convert("RGBA")
    rv = recolour(van.crop((4 * 64, 0, 5 * 64, 40)), hue=0.02, sat=0.7, val=0.8)
    rv.save(OUT / "trip_rv.png")

    for f in OUT.glob("*.png"):
        shutil.copy(f, SRC / f.name)
        print("wrote", f.name)


if __name__ == "__main__":
    main()
