"""Snap the generated head sheets to the game's pixels: find each head,
measure its art-pixel pitch, sample one colour per art pixel, map it to
the nine head colours, and place the skull on the guide's dome.

    .venv/bin/python art/faces-r1/snap.py [faces_a.png ...]

Writes heads.json (each head as 48 rows of palette roles, the neck at
(22, 44) like guide_cell_plain.png) and snapped_<sheet>.png (8x, for
looking at).
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CELL = 48
# the nine head colours as roles (light skin, brown hair)
PAL = {"o": (24, 20, 36), "Z": (255, 255, 255),
       "1": (140, 72, 52), "2": (192, 110, 76), "3": (238, 162, 114),
       "4": (252, 204, 158),
       "h": (56, 32, 22), "H": (102, 60, 34), "i": (150, 94, 52)}
ROLE_KEYS = list(PAL)
ROLE_RGB = np.array([PAL[k] for k in ROLE_KEYS], float)
SKULL_TOP = 14          # the guide head's top row in the cell
SKULL_CX = 23           # the dome's centre column


def blobs(alpha):
    """Column spans of the heads (runs of columns with opaque pixels)."""
    cols = (alpha > 128).sum(0) > 2
    spans, start = [], None
    for x, on in enumerate(list(cols) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 40:
                spans.append((start, x))
            start = None
    return spans


def outline_px(rgba):
    """The outline's thickness in image pixels: the median run of dark
    pixels inward from the head's top and back edges. The outline is one
    art pixel, so this is about the pitch."""
    a = rgba[..., 3] > 128
    dark = (rgba[..., :3].astype(int).sum(2) < 200) & a
    runs = []
    for line, d in [(a[:, x], dark[:, x]) for x in range(a.shape[1])] + \
                   [(a[y], dark[y]) for y in range(a.shape[0])]:
        if line.any():
            i = n = int(line.argmax())
            while n < len(d) and d[n]:
                n += 1
            if n > i:
                runs.append(n - i)
    return float(np.median(runs))


def pitch_1d(edges, lo, hi):
    """Best (pitch, phase) for a 1D edge-strength profile: the comb, with
    a pitch between lo and hi, that lands on the most edge energy."""
    best = None
    n = len(edges)
    for p10 in range(int(lo * 10), int(hi * 10) + 1):
        p = p10 / 10
        for ph10 in range(0, p10, 5):
            ph = ph10 / 10
            idx = np.arange(ph, n, p).round().astype(int)
            idx = idx[idx < n]
            if len(idx) < 4:
                continue
            score = edges[idx].mean()
            if best is None or score > best[0]:
                best = (score, p, ph)
    return best[1], best[2]


def snap_head(rgba):
    rgb = rgba[..., :3].astype(float)
    a = rgba[..., 3]
    dx = np.abs(np.diff(rgb, axis=1)).sum(2)
    dy = np.abs(np.diff(rgb, axis=0)).sum(2)
    t = outline_px(rgba)            # outlines run a little thin
    px, phx = pitch_1d(np.concatenate([[0], dx.sum(0)]), t - 0.5, t + 2.5)
    py, phy = pitch_1d(np.concatenate([[0], dy.sum(1)]), t - 0.5, t + 2.5)
    p = (px + py) / 2
    h, w = a.shape
    out = {}
    for j, y0 in enumerate(np.arange(phy - p, h, p)):
        for i, x0 in enumerate(np.arange(phx - p, w, p)):
            ys = slice(max(int(y0 + p * 0.3), 0), max(int(y0 + p * 0.7), 0))
            xs = slice(max(int(x0 + p * 0.3), 0), max(int(x0 + p * 0.7), 0))
            blk_a = a[ys, xs]
            if blk_a.size == 0 or (blk_a > 128).mean() < 0.5:
                continue
            col = np.median(rgb[ys, xs][blk_a > 128], axis=0)
            k = ROLE_KEYS[int(((ROLE_RGB - col) ** 2).sum(1).argmin())]
            out[(i, j)] = k
    return out, p


def place(px):
    """Translate so the skull's top row is SKULL_TOP and the middle of its
    top four rows sits on SKULL_CX."""
    top = min(y for _, y in px)
    xs = [x for x, y in px if y < top + 4]
    mid = (min(xs) + max(xs)) / 2
    ox, oy = round(SKULL_CX - mid), SKULL_TOP - top
    rows = [["."] * CELL for _ in range(CELL)]
    lost = 0
    for (x, y), k in px.items():
        X, Y = x + ox, y + oy
        if Y > 45:                       # below the collar: the body's
            continue
        if 0 <= X < CELL and 0 <= Y < CELL:
            rows[Y][X] = k
        else:
            lost += 1
    return ["".join(r) for r in rows], lost


def main(paths):
    store = os.path.join(HERE, "heads.json")
    heads = json.load(open(store)) if os.path.exists(store) else {}
    for path in paths:
        sheet = os.path.splitext(os.path.basename(path))[0]
        im = np.array(Image.open(path).convert("RGBA"))
        spans = blobs(im[..., 3])
        prev = Image.new("RGBA", (len(spans) * CELL * 8, CELL * 8), (200, 214, 200, 255))
        for n, (x0, x1) in enumerate(spans):
            crop = im[:, max(x0 - 4, 0):x1 + 4]
            px, p = snap_head(crop)
            rows, lost = place(px)
            name = f"{sheet[-1]}{n + 1}"
            heads[name] = rows
            xs = [x for x, _ in px]
            ys = [y for _, y in px]
            print(f"{name}: pitch {p:.2f}, {max(xs) - min(xs) + 1}x"
                  f"{max(ys) - min(ys) + 1} art px, {lost} px off the cell")
            cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            for y, r in enumerate(rows):
                for x, k in enumerate(r):
                    if k != ".":
                        cell.putpixel((x, y), PAL[k] + (255,))
            prev.alpha_composite(cell.resize((CELL * 8, CELL * 8), Image.NEAREST),
                                 (n * CELL * 8, 0))
        prev.save(os.path.join(HERE, f"snapped_{sheet}.png"))
    json.dump(heads, open(store, "w"), indent=0)


if __name__ == "__main__":
    main(sys.argv[1:] or sorted(glob.glob(os.path.join(HERE, "faces_?.png"))))


def refs(names, out_dir):
    """8x pictures of snapped heads, to attach to round 2's prompts."""
    heads = json.load(open(os.path.join(HERE, "heads.json")))
    os.makedirs(out_dir, exist_ok=True)
    for n in names:
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        for y, r in enumerate(heads[n]):
            for x, k in enumerate(r):
                if k != ".":
                    cell.putpixel((x, y), PAL[k] + (255,))
        cell.resize((CELL * 8, CELL * 8), Image.NEAREST).save(
            os.path.join(out_dir, f"ref_{n}.png"))
