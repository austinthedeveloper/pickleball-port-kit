"""The painted venues (ADR-088): WESTERN, ROOFTOP, PIRATE, MOTEL, FAIR,
DRIVE-IN and MALL, from the generated art in art/venues-r1 (the round
2 plates, cutouts and locals; MOTEL's plate and cutouts from
art/venues-r2-fixes).

Not drawn in the kit's way: each venue is cut from its paintings.

- 'far' is the plate: the whole scene without the court, opaque.
- 'fence' is the cutouts' barrier (everything above SPLIT).
- 'front' is the cutouts' near props (everything below SPLIT).
- 'ground' is the plate's floor, with the court painted on it by the
  court mask (the kit's geometry). The floor's own light and grain show
  through the court paint, so the court reads as painted on the planks,
  the dirt or the tar.

Godot imports 'far' and 'ground' lossy (quality 0.9, their .import
files in game/assets): 4.5 MB in the .pck for the seven, not 14.

Every layer has parallax 1.0. The plate bakes the barrier and the props
in, so a layer that moved against it would show their ghosts.

Each scene is lifted where its barrier ends below LIFT_TO, so the court's
far edge stays clear. The rows above the floor move up unscaled and the
floor stretches down to the near strip, like MOTEL's re-layout. The
camera's overscan reflects the edges.

The locals (one sheet per venue) are cut from their sheet, reduced
(BOX, hard alpha) so a typical adult is ADULT_H px tall, and put on one
baseline in cells of their own size. Row = person, column 0 idle,
column 1 cheering, like sprites/crowd.png.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

import court as C
from pix import LAYER_H, LAYER_W, OVER_X, OVER_Y, SCREEN_H, SCREEN_W, Layer

KIT = Path(__file__).resolve().parents[3]
SRC = KIT / "art/venues-r1"
FIX = KIT / "art/venues-r2-fixes"
SPLIT = 300          # screen row: the barrier above, the near props below
STRIP = 449          # the near strip's top: the floor stretches down to it
ADULT_H = 50         # a typical adult local's height, px

# surface, kitchen, lines (data/court_colors.json presets); the crowd
# behind the barrier (True) or in front of it (then on the floor just
# below it, LIFT_TO leaving room); seats: (x0, x1, count) and their feet's
# row; the
# court paint's grain; letters to paint out: (person, pose, box as
# fractions of the person's cut, the colour kept).
SPECS = {
    "western": {"court": ("962c34", "b05434", "ffffff"), "behind": True,
                "seats": (40, 860, 11), "feet": 198, "grain": 0.35},
    "rooftop": {"court": ("265ca8", "223470", "ffffff"), "behind": False,
                "seats": (110, 900, 10), "grain": 0.3},
    "pirate": {"court": ("14828c", "223470", "ffffff"), "behind": False,
               "seats": (40, 790, 11), "grain": 0.3, "parrot": 8},
    "motel": {"court": ("265ca8", "223470", "ffffff"), "behind": True,
              "seats": (190, 770, 8), "feet": 203, "grain": 0.45,
              "unletter": [(2, 0, (0.42, 0.04, 0.63, 0.10), "light"),     # the trucker's cap badge
                           (2, 1, (0.40, 0.07, 0.57, 0.14), "light")]},
    "fair": {"court": ("2e7a48", "c45c1c", "ffffff"), "behind": True,
             "seats": (40, 920, 11), "feet": 190, "grain": 0.3},
    "drivein": {"court": ("60408c", "c84082", "78f0ff"), "behind": False,
                "seats": (40, 920, 12), "grain": 0.25,
                "unletter": [(0, 0, (0.66, 0.39, 0.82, 0.47), "dark"),    # the letterman's H
                             (0, 1, (0.62, 0.42, 0.73, 0.50), "dark")]},
    "mall": {"court": ("14828c", "c84082", "ffffff"), "behind": True,
             "seats": (40, 920, 11), "feet": 200, "grain": 0.2},
}
NAMES = list(SPECS)
LIFT_TO = {True: 218, False: 202}   # behind the barrier / in front of it


def _rgb(h):
    h = h.replace(" ", "")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _src(name, kind):
    p = (FIX if name == "motel" and kind != "locals" else SRC) / f"{name}_{kind}.png"
    return Image.open(p).convert("RGBA")


def _screen(img: Image.Image) -> np.ndarray:
    """A 16:9 painting at 960x540 (float RGBA)."""
    return np.asarray(img.resize((SCREEN_W, SCREEN_H), Image.LANCZOS), np.float32)


def barrier_bottom(cut: np.ndarray) -> int:
    """The last row above SPLIT where the barrier crosses the court's
    middle (x 200..760)."""
    a = cut[:SPLIT, 200:760, 3] > 128
    rows = np.where(a.mean(axis=1) > 0.3)[0]
    return int(rows[-1]) if rows.size else 0


def lift_rows(bottom: int, dy: int) -> np.ndarray:
    """The source row (float) for each layer row: the band above the floor
    up dy unscaled, the floor stretched to STRIP, the rest as it is; the
    overscan reflected."""
    out = np.empty(LAYER_H, np.float32)
    top = bottom - dy
    for ly in range(LAYER_H):
        y = ly - OVER_Y
        if y < top:
            s = y + dy
        elif y < STRIP:
            s = bottom + (y - top) * (STRIP - bottom) / (STRIP - top)
        else:
            s = y
        if s < 0:
            s = -s
        if s > SCREEN_H - 1:
            s = 2 * (SCREEN_H - 1) - s
        out[ly] = s
    return out


def remap(img: np.ndarray, rows: np.ndarray) -> np.ndarray:
    """img (540, 960, 4) -> layer (588, 1056, 4), rows interpolated,
    columns reflected into the overscan."""
    r0 = np.floor(rows).astype(int)
    r1 = np.minimum(r0 + 1, SCREEN_H - 1)
    t = (rows - r0)[:, None, None]
    tall = img[r0] * (1 - t) + img[r1] * t
    cols = np.arange(LAYER_W) - OVER_X
    cols = np.where(cols < 0, -cols, cols)
    cols = np.where(cols > SCREEN_W - 1, 2 * (SCREEN_W - 1) - cols, cols)
    return tall[:, cols]


def lum(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def sc(rgb, ks):
    return [tuple(int(min(255, round(c * k))) for c in rgb) for k in ks]


def court_colors(spec, floor_mean):
    s, k, li = (_rgb(h) for h in spec["court"])
    return {
        "surround": sc(floor_mean, (0.84, 0.94, 1.0, 1.06, 1.16)),
        "surface": sc(s, (0.92, 0.98, 1.02, 1.08)),
        "kitchen": sc(k, (0.92, 0.98, 1.02, 1.08)),
        "kitchen_shade": sc(k, (0.74, 0.78, 0.82)),
        "lines": sc(li, (0.96, 1.0, 1.04)),
        "lines_shade": sc(li, (0.72, 0.76, 0.8)),
    }


def paint_court(floor: np.ndarray, roles: np.ndarray, colors: dict, grain: float) -> np.ndarray:
    """The court's paint over the floor: each role's middle colour, scaled
    by the floor's own brightness (its light and grain) to the power
    `grain`, so the mean stays the preset's."""
    out = floor[..., :3].copy()
    court = roles >= C.ROLE["surface"]
    L = lum(floor[..., :3]) + 1.0
    f = np.clip((L / L[court].mean()) ** grain, 0.72, 1.22)
    for name, rid in C.ROLE.items():
        if rid < C.ROLE["surface"]:
            continue
        key = {"surface_shade": "kitchen_shade"}.get(name, name)
        if key not in colors:
            continue
        r = np.array(colors[key], np.float32)
        base = r[len(r) // 2]
        g = f if "lines" not in name else f ** 0.5
        m = roles == rid
        out[m] = np.clip(base[None, :] * g[m][:, None], 0, 255)
    return out


# -- The locals ------------------------------------------------------------------

def _runs(on: np.ndarray, n: int) -> list:
    """n spans of True in a 1-D projection, split at its n-1 widest gaps."""
    idx = np.where(on)[0]
    gaps = np.diff(idx)
    cut = np.sort(np.argsort(gaps)[::-1][:n - 1])
    spans, start = [], idx[0]
    for c in cut:
        spans.append((start, idx[c] + 1))
        start = idx[c + 1]
    spans.append((start, idx[-1] + 1))
    return spans


def _unletter(cell: np.ndarray, box, keep: str) -> None:
    """Flattens box (fractions of the cut), all but the outline, to the
    commonest of its dark (a red jacket under a letter) or light (a white
    cap under a badge) colours."""
    h, w = cell.shape[:2]
    x0, y0, x1, y1 = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    sub = cell[y0:y1, x0:x1]
    L = lum(sub[..., :3].astype(np.float32))
    on = (sub[..., 3] > 0) & (L > 60)
    pick = on & ((L > 170) if keep == "light" else (L <= 170))
    cols, counts = np.unique(sub[pick][:, :3] // 8, axis=0, return_counts=True)
    sub[on, :3] = cols[np.argmax(counts)] * 8 + 4


def locals_sheet(name, spec) -> tuple[np.ndarray, dict, int]:
    """The venue's crowd sheet and its manifest entry, and its row count."""
    img = np.asarray(_src(name, "locals"), np.uint8).copy()
    a = img[..., 3] > 128
    rows = _runs(a.any(axis=1), 2)
    people = 9 if "parrot" in spec else 8
    cells = []                     # [person][pose] -> RGBA crop, feet at the bottom
    heights = []
    for pose, (y0, y1) in enumerate(rows):
        band = a[y0:y1]
        for k, (x0, x1) in enumerate(_runs(band.any(axis=0), people)):
            sub = img[y0:y1, x0:x1]
            ys, xs = np.where(sub[..., 3] > 128)
            c = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
            if pose == 0:
                cells.append([c, None])
                heights.append(c.shape[0])
            else:
                cells[k][1] = c
    for person, pose, box, keep in spec.get("unletter", []):
        _unletter(cells[person][pose], box, keep)
    k = ADULT_H / float(np.median(heights[:8]))
    small = []
    for idle, cheer in cells:
        pair = []
        for c in (idle, cheer):
            im = Image.fromarray(c, "RGBA")
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)
            s = np.asarray(im, np.uint8).copy()
            s[..., 3] = np.where(s[..., 3] > 110, 255, 0)
            pair.append(s)
        small.append(pair)
    fw = max(s.shape[1] for p in small for s in p) + 2
    fw += fw % 2
    fh = max(s.shape[0] for p in small for s in p) + 3
    sheet = np.zeros((fh * len(small), fw * 2, 4), np.uint8)
    for r, pair in enumerate(small):
        for col, s in enumerate(pair):
            h, w = s.shape[:2]
            x = col * fw + (fw - w) // 2
            y = r * fh + fh - 2 - h
            sheet[y:y + h, x:x + w] = s
    meta = {"file": f"venues/{name}/crowd.png", "frame_size": [fw, fh],
            "frames": ["idle", "cheer"], "sit_anchor": [fw // 2, fh - 2],
            "stand_anchor": [fw // 2, fh - 2],
            "doc": "The venue's own locals (ADR-088): row = person, column 0 "
                   "idle, 1 cheer, anchored at the feet."}
    return sheet, meta, len(small)


# -- The venue -----------------------------------------------------------------------

def build(name: str):
    from venues import Venue
    spec = SPECS[name]
    v = Venue(name)
    v.stands_behind_fence = spec["behind"]
    plate = _screen(_src(name, "plate"))
    plate[..., 3] = 255
    cut = _screen(_src(name, "cutouts"))
    bottom = barrier_bottom(cut)
    dy = max(0, bottom - LIFT_TO[spec["behind"]])
    rows = lift_rows(bottom, dy)
    far = remap(plate, rows)
    cuts = remap(cut, rows)
    v.bottom = bottom - dy                    # the barrier's bottom, after the lift
    ground_top = v.bottom - 4                 # under the barrier: no seam when recoloured

    F = Layer()
    F.a[:] = np.clip(far, 0, 255).astype(np.uint8)
    v.add("far", F, 1.0)
    split = SPLIT + OVER_Y
    alpha = (cuts[..., 3] > 128)
    B = Layer()
    B.a[:split] = np.clip(cuts[:split], 0, 255).astype(np.uint8)
    B.a[:split, :, 3] = np.where(alpha[:split], 255, 0)
    v.add("fence", B, 1.0)
    N = Layer()
    N.a[split:] = np.clip(cuts[split:], 0, 255).astype(np.uint8)
    N.a[split:, :, 3] = np.where(alpha[split:], 255, 0)
    v.add("front", N, 1.0)
    v.add("stands", Layer(), 1.0)

    G = Layer()
    roles = C.court_mask((G.h, G.w), G.ox, G.oy, ground_top)
    floor_px = far[(roles == C.ROLE["surround"])][..., :3]
    colors = court_colors(spec, tuple(int(c) for c in floor_px.mean(axis=0)))
    painted = paint_court(far, roles, colors, spec["grain"])
    G.a[..., :3] = painted.astype(np.uint8)
    G.a[..., 3] = np.where(roles > 0, 255, 0)
    v.add("ground", G, 1.0)
    v.court_colors = colors
    v.roles = roles

    sheet, meta, n = locals_sheet(name, spec)
    v.crowd_sheet, v.crowd_meta = sheet, meta
    x0, x1, count = spec["seats"]
    feet = spec.get("feet", v.bottom + 6)    # behind: set by eye, the rail at their knees
    people = [i for i in range(n) if i != spec.get("parrot", -1)]
    for i in range(count):
        x = round(x0 + (i + 0.5) * (x1 - x0) / count)
        v.seats.append({"x": x, "y": feet, "pose": "stand", "person": people[(i * 3 + 1) % len(people)]})
    if "parrot" in spec:                      # on the rail, by the captain
        top = int(np.where((cuts[:split, 400:560, 3] > 128).mean(axis=1) > 0.3)[0][0]) - OVER_Y
        v.seats.append({"x": 452, "y": top + 2, "pose": "stand", "person": spec["parrot"]})
    w = v.seats[count - 3]
    v.watcher = {"x": w["x"], "y": w["y"], "pose": "stand"}
    return v


VENUES = {n: (lambda n=n: build(n)) for n in NAMES}
