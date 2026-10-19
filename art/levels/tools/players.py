"""Players for the 960x540 levels: about 96 px tall, 128x128 frames.

A 2x version of art/sprites/hd/src/rig.py (same poses, shading model and
palette roles) with a procedural head that has room for real features
(hairline, ear, eye, brow, nose, mouth). The cap is a separate overlay
layer (like the SNES hats) and the ponytail is baked into the female
sheets.

Pixels are palette roles; palettes.json colours them per team.
"""
from __future__ import annotations

import math

S = 2                                  # scale over the 48 px rig
W = H = 128
GROUND = 58 * S                        # feet end on this row
ANCHOR_X = 28 * S                      # body centre for flipping
LIGHT = (-0.55, -0.83)

ROLES = (".o" "1234" "hHi" "DdML" "qwW" "sS" "xXgkK" "pPfeEG" "Z")

RAMP = {
    "skin": ("1", "2", "3", "4"),
    "skin_far": ("1", "1", "2", "3"),
    "shirt": ("D", "d", "M", "L"),
    "shirt_far": ("D", "D", "d", "M"),
    "shorts": ("q", "q", "w", "W"),
    "shorts_far": ("q", "q", "q", "w"),
    "sock": ("S", "S", "s", "s"),
    "sock_far": ("S", "S", "S", "s"),
    "hair": ("h", "h", "H", "i"),
    "accent": ("K", "K", "k", "k"),
    "white": ("q", "w", "W", "Z"),
    "steel": ("g", "g", "q", "S"),
}


def ramp_pick(ramp, s):
    deep, shadow, base, light = RAMP[ramp]
    if s > 0.4:
        return light
    if s < -0.75:
        return deep
    if s < -0.35:
        return shadow
    return base


class Part:
    def __init__(self, outlined=True):
        self.px = {}
        self.outlined = outlined

    def capsule(self, a, b, r0, r1, ramp, light=LIGHT, only_new=False):
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy or 1e-6
        rmax = max(r0, r1)
        for y in range(int(min(ay, by) - rmax - 1), int(max(ay, by) + rmax + 2)):
            for x in range(int(min(ax, bx) - rmax - 1), int(max(ax, bx) + rmax + 2)):
                px, py = x + 0.5, y + 0.5
                t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
                cx, cy = ax + t * dx, ay + t * dy
                r = r0 + (r1 - r0) * t
                ox, oy = px - cx, py - cy
                if math.hypot(ox, oy) <= r:
                    if only_new and (x, y) in self.px:
                        continue
                    s = (ox * light[0] + oy * light[1]) / max(r, 0.8)
                    self.px[(x, y)] = ramp_pick(ramp, s)

    def despeckle(self, keep="kKgeEGfoZ"):
        fixed = dict(self.px)
        for (x, y), ch in self.px.items():
            if ch in keep:
                continue
            nb = [self.px.get(n) for n in
                  ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))]
            nb = [c for c in nb if c is not None and c not in keep]
            if len(nb) >= 3 and ch not in nb:
                fixed[(x, y)] = max(set(nb), key=nb.count)
        self.px = fixed
        return self

    def outline(self):
        out = set()
        if not self.outlined:
            return out
        for (x, y) in self.px:
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in self.px:
                    out.add(n)
        return out


class Canvas:
    def __init__(self):
        self.g = [["."] * W for _ in range(H)]
        self.clipped = 0

    def put(self, x, y, ch):
        if 0 <= x < W and 0 <= y < H:
            self.g[y][x] = ch
        else:
            self.clipped += 1

    def draw(self, part):
        for (x, y) in part.outline():
            self.put(x, y, "o")
        for (x, y), ch in part.px.items():
            self.put(x, y, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


SHIRT = "DdML"
SKIN = "1234"
DARKER = {"L": "M", "M": "d", "d": "D", "D": "D", "W": "w", "w": "q", "q": "q"}


def hem(p, cloth=SHIRT, skin=SKIN):
    for (x, y), ch in list(p.px.items()):
        if ch in cloth and any(p.px.get(n, ".") in skin for n in
                               ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
            p.px[(x, y)] = DARKER[ch]


# --- Body parts (radii are the 48 px rig's, times S) --------------------------

def arm(shoulder, elbow, hand, far=False, band=True):
    p = Part()
    sk = "skin_far" if far else "skin"
    sh = "shirt_far" if far else "shirt"
    p.capsule(elbow, hand, 1.45 * S, 1.2 * S, sk)
    p.capsule(shoulder, elbow, 1.75 * S, 1.5 * S, sk)
    p.capsule(shoulder, lerp(shoulder, elbow, 0.42), 2.35 * S, 2.1 * S, sh)
    if band:
        p.capsule(lerp(elbow, hand, 0.66), lerp(elbow, hand, 0.82), 1.5 * S,
                  1.45 * S, sh)
    p.capsule(hand, hand, 1.6 * S, 1.6 * S, sk)
    p.despeckle()
    hem(p)
    # knuckle highlight on the fist
    hx, hy = round(hand[0] - 0.5), round(hand[1] - 0.5)
    if not far and (hx - 1, hy - 1) in p.px:
        p.px[(hx - 1, hy - 1)] = "4"
    return p


def leg(hip, knee, ankle, toe_dir=(1, 0), far=False):
    p = Part()
    sk = "skin_far" if far else "skin"
    p.capsule(knee, ankle, 1.95 * S, 1.3 * S, sk)
    p.capsule(hip, knee, 2.55 * S, 2.1 * S, sk)
    p.capsule(lerp(knee, ankle, 0.74), ankle, 1.45 * S, 1.4 * S,
              "sock_far" if far else "sock")
    p.despeckle()
    # knee cap highlight
    kx, ky = round(knee[0] - 0.5), round(knee[1] - 0.5)
    if not far and (kx + 1, ky - 1) in p.px:
        p.px[(kx + 1, ky - 1)] = "4"
    shoe(p, ankle, toe_dir, far)
    return p


def shoe(p, ankle, toe_dir, far):
    tx, ty = toe_dir
    n = math.hypot(tx, ty)
    tx, ty = tx / n, ty / n
    heel = (ankle[0] - tx * 1.0 * S, ankle[1] + 1.5 * S - ty * 1.0 * S)
    toe = (ankle[0] + tx * 3.4 * S, ankle[1] + 1.5 * S + ty * 3.4 * S)
    nx, ny = -ty, tx
    if ny < 0:
        nx, ny = -nx, -ny
    dx, dy = toe[0] - heel[0], toe[1] - heel[1]
    L2 = dx * dx + dy * dy
    for y in range(int(min(heel[1], toe[1])) - 6, int(max(heel[1], toe[1])) + 7):
        for x in range(int(min(heel[0], toe[0])) - 6, int(max(heel[0], toe[0])) + 7):
            px, py = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px - heel[0]) * dx + (py - heel[1]) * dy) / L2))
            r = (1.8 - 0.35 * t) * S
            cx, cy = heel[0] + t * dx, heel[1] + t * dy
            ox, oy = px - cx, py - cy
            if math.hypot(ox, oy) > r:
                continue
            down = ox * nx + oy * ny
            if down > r - 1.6:
                ch = "g"
            elif abs((t - 0.45) * 7 - down * 0.45) < 1.2 and down < r - 2:
                ch = "K" if far else "k"
            elif 0.62 < t < 0.8 and down < -r * 0.35:
                ch = "S" if far else "Z"          # laces
            elif far or down > 0.4 * S:
                ch = "X"
            else:
                ch = "x"
            p.px[(x, y)] = ch
    if not far:
        for (x, y), ch in list(p.px.items()):
            if ch == "X" and (x, y - 1) not in p.px:
                p.px[(x, y)] = "x"


def torso(neck, hip):
    """Shirt as a shaped polygon along the spine: shoulders, chest, a slight
    taper and a flat hem, shaded across its width (lit at the back)."""
    p = Part()
    ax, ay = hip[0] - neck[0], hip[1] - neck[1]
    L = math.hypot(ax, ay)
    ux, uy = ax / L, ay / L                 # down the spine
    nx, ny = -uy, ux                        # across, toward the front (right)
    if nx < 0:
        nx, ny = -nx, -ny
    # (t along neck->hip, side in 1x px; + = front)
    shape = [(0.10, -1.8), (0.16, -3.9), (0.30, -4.3), (0.55, -3.7),
             (0.80, -3.5), (1.04, -3.7), (1.04, 3.6), (0.80, 3.5),
             (0.55, 3.8), (0.34, 4.5), (0.18, 3.3), (0.08, 1.6)]
    poly = [(neck[0] + ux * t * L + nx * sd * S, neck[1] + uy * t * L + ny * sd * S)
            for t, sd in shape]
    xs, ys = [q[0] for q in poly], [q[1] for q in poly]

    def inside(x, y):
        c = False
        for i in range(len(poly)):
            x1, y1 = poly[i]
            x2, y2 = poly[(i + 1) % len(poly)]
            if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
                c = not c
        return c

    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            px, py = x + 0.5, y + 0.5
            if not inside(px, py):
                continue
            t = ((px - neck[0]) * ux + (py - neck[1]) * uy) / L
            sd = ((px - neck[0]) * nx + (py - neck[1]) * ny) / S
            half = 4.0
            v = sd / half                    # -1 back .. +1 front
            if t > 0.97:
                ch = "D"                     # hem
            elif t > 0.9:
                ch = "d"
            elif v < -0.62 and t < 0.75:
                ch = "L"
            elif v > 0.62 or (t > 0.55 and v > 0.3):
                ch = "d"
            else:
                ch = "M"
            if t < 0.2 and v < 0.2:          # top of the shoulders catch light
                ch = "L"
            p.px[(x, y)] = ch
    p.despeckle()
    # a fold from the chest toward the back hip
    for i in range(int(0.35 * L)):
        t = 0.42 + i / L
        sd = 1.2 - i * 0.16
        fx = round(neck[0] + ux * t * L + nx * sd * S)
        fy = round(neck[1] + uy * t * L + ny * sd * S)
        if p.px.get((fx, fy)) in ("M", "L"):
            p.px[(fx, fy)] = "d"
    return p


def collar(neck):
    p = Part(outlined=False)
    nx, ny = round(neck[0] - 0.5), round(neck[1] - 0.5)
    rows = ["LLL..LL",
            ".LLo.LL",
            "..LDoL.",
            "...Do.."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                p.px[(nx - 3 + x, ny + 3 + y)] = ch
    return p


def shorts(hip, knee_n, knee_f):
    p = Part()
    p.capsule(add(hip, (-1 * S, 0)), add(hip, (1 * S, 0)), 4.0 * S, 4.0 * S,
              "shorts")
    p.capsule(hip, lerp(hip, knee_f, 0.5), 3.2 * S, 2.8 * S, "shorts_far")
    p.capsule(add(hip, (1 * S, 0)), lerp(hip, knee_n, 0.5), 3.2 * S, 2.8 * S,
              "shorts")
    p.despeckle()
    for (x, y), ch in list(p.px.items()):            # hem shadow
        if (x, y + 1) not in p.px:
            p.px[(x, y)] = "q"
    return p


def neck_part(neck):
    p = Part()
    p.capsule(add(neck, (0, -2 * S)), add(neck, (0, 2 * S)), 1.4 * S, 1.6 * S,
              "skin")
    for (x, y), ch in list(p.px.items()):            # shadow under the jaw
        if y < neck[1] - 1:
            p.px[(x, y)] = "2"
    return p


def paddle(grip, angle_deg):
    p = Part()
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    vx, vy = -uy, ux
    handle_end = (grip[0] + ux * 3.0 * S, grip[1] + uy * 3.0 * S)
    p.capsule((grip[0] - ux * 1.5 * S, grip[1] - uy * 1.5 * S), handle_end,
              1.0 * S, 1.0 * S, "sock_far")
    for k in list(p.px):
        p.px[k] = "G"
    center = (grip[0] + ux * 7.4 * S, grip[1] + uy * 7.4 * S)
    hl, hw = 4.7 * S, 3.8 * S
    for y in range(int(center[1] - 12 * S), int(center[1] + 12 * S)):
        for x in range(int(center[0] - 12 * S), int(center[0] + 12 * S)):
            px, py = x + 0.5 - center[0], y + 0.5 - center[1]
            u = px * ux + py * uy
            v = px * vx + py * vy
            q = (abs(u) / hl) ** 3 + (abs(v) / hw) ** 3
            if q > 1:
                continue
            s = (px * LIGHT[0] + py * LIGHT[1]) / hl
            if q > 0.66:
                ch = "E" if s > 0.3 else "e"
            elif q > 0.42 and s < -0.1:
                ch = "p"
            elif -1.4 < (u * 0.8 - v) / S - 1.4 < 0.6 and s > -0.2:
                ch = "f"
            else:
                ch = "P"
            p.px[(x, y)] = ch
    # grip tape wraps: a light stripe every 3 px along the handle
    for k, ch in list(p.px.items()):
        if ch == "G":
            along = (k[0] - grip[0]) * ux + (k[1] - grip[1]) * uy
            if int(along) % 3 == 0:
                p.px[k] = "e"
    return p


# --- Head (procedural, facing right) -------------------------------------------

def head_parts(neck, female=False, pony="hang"):
    """Returns (head, cap, ponytail) parts. The cap covers the hair's crown
    and adds a brim; the ponytail goes behind the body."""
    nx, ny = neck
    cx, cy = nx + 1, ny - 10 * S / 2 * 2 / 2 - 10    # skull centre
    cx, cy = nx + 1, ny - 20
    head = Part(outlined=True)
    hair_line = lambda x, y: (y - (cy - 4)) < -0.5 * (x - (cx + 9)) - 4

    for y in range(int(cy - 14), int(ny + 3)):
        for x in range(int(cx - 13), int(cx + 18)):
            px, py = x + 0.5, y + 0.5
            sk = ((px - cx) / 10.5) ** 2 + ((py - cy) / 9.8) ** 2 <= 1
            jw = ((px - (nx + 5.5)) / 7.6) ** 2 + ((py - (ny - 6)) / 6.2) ** 2 <= 1
            if not (sk or jw):
                continue
            # hair: the crown and the back of the head
            back = px < cx - 1.5 and py < ny - 8 and sk
            crown = sk and hair_line(px, py)
            ear = ((px - (nx - 0.5)) / 2.6) ** 2 + ((py - (ny - 9)) / 3.4) ** 2 <= 1
            if (back or crown) and not ear:
                # hair shading: lit from the upper left
                s = -((px - cx) * LIGHT[0] + (py - cy) * LIGHT[1]) / 10
                ch = "i" if s < -0.45 else ("h" if s > 0.55 else "H")
                head.px[(x, y)] = ch
                continue
            # skin: mostly base, shade low and at the back
            s = ((px - cx) * LIGHT[0] + (py - cy) * LIGHT[1]) / 10
            ch = "3"
            if py > ny - 2.5 or (px < nx + 2 and py > ny - 6):
                ch = "2"
            elif s > 0.55 and py < cy:
                ch = "4"
            head.px[(x, y)] = ch
    # ear: rim + inner shadow
    for y in range(int(ny - 13), int(ny - 4)):
        for x in range(int(nx - 4), int(nx + 3)):
            px, py = x + 0.5, y + 0.5
            e = ((px - (nx - 0.5)) / 2.6) ** 2 + ((py - (ny - 9)) / 3.4) ** 2
            if e <= 1:
                head.px[(x, y)] = "2" if e > 0.45 else "1"
    # nose bump
    for (x, y, ch) in ((nx + 13, ny - 10, "3"), (nx + 14, ny - 9, "3"),
                       (nx + 14, ny - 8, "2"), (nx + 13, ny - 8, "3"),
                       (nx + 13, ny - 9, "3")):
        head.px[(x, y)] = ch
    # face features
    ex, ey = nx + 9, ny - 12
    head.px[(ex, ey)] = "o"
    head.px[(ex, ey + 1)] = "o"
    head.px[(ex - 1, ey)] = "Z"
    head.px[(ex - 1, ey + 1)] = "Z"
    for bx in range(ex - 2, ex + 2):                  # brow
        head.px[(bx, ey - 2)] = "h"
    if female:
        head.px[(ex + 1, ey - 1)] = "o"               # lash
        head.px[(ex + 1, ey)] = "o"
    head.px[(nx + 11, ny - 5)] = "1"                  # mouth
    head.px[(nx + 10, ny - 5)] = "2"
    head.px[(nx + 7, ny - 2)] = "2"                   # jaw shadow line
    # sideburn below the hairline in front of the ear
    for y in range(int(ny - 13), int(ny - 9)):
        if (nx + 2, y) in head.px and head.px[(nx + 2, y)] in "34":
            head.px[(nx + 2, y)] = "h"

    # cap: crown dome over the hair plus a brim
    cap = Part(outlined=True)
    band_y = cy - 3
    for y in range(int(cy - 12), int(band_y + 3)):
        for x in range(int(cx - 12), int(cx + 13)):
            px, py = x + 0.5, y + 0.5
            if ((px - cx) / 11.4) ** 2 + ((py - cy) / 10.6) ** 2 > 1:
                continue
            if py > band_y + (cx - px) * 0.18:
                continue
            s = -((px - cx) * LIGHT[0] + (py - cy) * LIGHT[1]) / 10
            ch = "L" if s < -0.45 else ("d" if s > 0.5 else "M")
            if py > band_y - 1.5 + (cx - px) * 0.18:
                ch = "d"                                # sweatband
            cap.px[(x, y)] = ch
    for y in range(int(band_y - 2), int(band_y + 3)):  # brim
        for x in range(int(cx + 6), int(cx + 19)):
            t = (x - (cx + 6)) / 13
            top = band_y - 1 + t * 1.5
            if top <= y + 0.5 <= top + 3.2 - t * 0.8:
                cap.px[(x, y)] = "L" if y + 0.5 < top + 1 else "M"
    cap.px[(round(cx), round(cy - 11))] = "d"          # button
    for y in range(int(cy - 9), int(band_y - 2)):     # panel seam
        sx = round(cx + 2 + (y - (cy - 9)) * 0.25)
        if (sx, y) in cap.px and cap.px[(sx, y)] in "ML":
            cap.px[(sx, y)] = "d"

    tail = None
    if female:
        tail = Part(outlined=True)
        tie = (cx - 9, cy - 3)
        if pony == "fly":
            tail.capsule(tie, (tie[0] - 9, tie[1] + 1), 3.2, 2.4, "hair")
            tail.capsule((tie[0] - 9, tie[1] + 1), (tie[0] - 15, tie[1] + 3),
                         2.4, 1.2, "hair")
        else:
            tail.capsule(tie, (tie[0] - 4, tie[1] + 6), 3.4, 2.8, "hair")
            tail.capsule((tie[0] - 4, tie[1] + 6), (tie[0] - 4, tie[1] + 13),
                         2.8, 1.2, "hair")
        tail.capsule(tie, tie, 2.2, 2.2, "shirt")      # hair tie
        tail.despeckle(keep="o")
    return head, cap, tail


HATS = ("visor", "headband", "tricorn", "bandana",
        # SNES ADR-060 (port PORT-38): looks only, the owner's palette
        "beanie", "backcap", "bucket", "crown", "whirly", "chef", "viking")


def hat_part(neck, kind):
    """The other hats (art/sprites/bare/hats.aseprite), drawn where the cap
    sits: visor and headband in the shoe accent (k, K), tricorn in hair with
    a white trim, bandana in the shirt ramp. They only add pixels over the
    bare head."""
    nx, ny = neck
    cx, cy = nx + 1, ny - 20
    band_y = cy - 3
    slope = lambda px: (cx - px) * 0.18          # the band dips at the back
    lit = lambda px, py: -((px - cx) * LIGHT[0] + (py - cy) * LIGHT[1]) / 10
    p = Part(outlined=True)

    def in_dome(px, py, rx, ry, oy=0.0):
        return ((px - cx) / rx) ** 2 + ((py - (cy + oy)) / ry) ** 2 <= 1

    if kind in ("visor", "headband"):
        rows = 3 if kind == "visor" else 2
        for y in range(int(cy - 12), int(band_y + 4)):
            for x in range(int(cx - 13), int(cx + 13)):
                px, py = x + 0.5, y + 0.5
                if not in_dome(px, py, 11.6, 10.8):
                    continue
                low = band_y + slope(px)
                if low - rows < py <= low:
                    p.px[(x, y)] = "K" if py > low - 1 else "k"
        if kind == "visor":                       # the brim, like the cap's
            for y in range(int(band_y - 2), int(band_y + 3)):
                for x in range(int(cx + 7), int(cx + 19)):
                    t = (x - (cx + 7)) / 12
                    top = band_y - 1 + t * 1.5
                    if top <= y + 0.5 <= top + 3.0 - t * 0.8:
                        p.px[(x, y)] = "k" if y + 0.5 < top + 1 else "K"
        else:                                     # knot tails at the back
            knot = (cx - 11, band_y + slope(cx - 11) - 1)
            p.capsule(knot, (knot[0] - 5, knot[1] + 3), 1.6, 1.0, "accent")
            p.capsule(knot, (knot[0] - 3, knot[1] + 7), 1.6, 1.0, "accent")
    elif kind == "tricorn":
        for y in range(int(cy - 16), int(band_y + 1)):     # crown
            for x in range(int(cx - 11), int(cx + 11)):
                px, py = x + 0.5, y + 0.5
                if in_dome(px, py, 10.2, 10.4, -3) and py <= band_y - 1:
                    s = lit(px, py)
                    p.px[(x, y)] = "i" if s < -0.45 else ("h" if s > 0.5 else "H")
        for x in range(int(cx - 18), int(cx + 20)):        # brim, cocked up
            t = (x + 0.5 - cx) / 18.5
            top = band_y - 1.5 - 8 * t * t
            bot = band_y + 2.2 - 4.5 * t * t
            first = True
            for y in range(int(top - 1), int(bot + 1)):
                if top <= y + 0.5 <= bot:
                    p.px[(x, y)] = "Z" if first else (
                        "h" if y + 0.5 > bot - 1 else "H")
                    first = False
    elif kind == "bandana":
        for y in range(int(cy - 12), int(band_y + 4)):
            for x in range(int(cx - 13), int(cx + 12)):
                px, py = x + 0.5, y + 0.5
                if not in_dome(px, py, 11.4, 10.6) or py > band_y + 1 + slope(px):
                    continue
                s = lit(px, py)
                ch = "L" if s < -0.45 else ("d" if s > 0.5 else "M")
                if py > band_y + slope(px):
                    ch = "d"                              # the rolled hem
                elif ch == "M" and (x * 3 + y * 5) % 9 == 0:
                    ch = "L"                              # spots
                p.px[(x, y)] = ch
        knot = (cx - 11, band_y + slope(cx - 11))
        p.capsule(knot, knot, 2.2, 2.2, "shirt")
        p.capsule(knot, (knot[0] - 6, knot[1] + 4), 1.8, 1.1, "shirt")
        p.capsule(knot, (knot[0] - 3, knot[1] + 8), 1.8, 1.1, "shirt")
    elif kind in ("beanie", "whirly"):
        # a knit dome down to the brow, a ribbed cuff; the beanie has a
        # white pom-pom, the whirly a propeller in the shoe accent
        for y in range(int(cy - 13), int(band_y + 4)):
            for x in range(int(cx - 13), int(cx + 13)):
                px, py = x + 0.5, y + 0.5
                low = band_y + 1 + slope(px)
                if not in_dome(px, py, 12.0, 11.4, -0.5) or py > low:
                    continue
                s = lit(px, py)
                ch = "L" if s < -0.45 else ("d" if s > 0.5 else "M")
                if py > low - 3:
                    ch = "D" if x % 2 else "d"            # the cuff's ribs
                elif kind == "whirly" and int(px - cx + 40) // 5 % 2:
                    ch = {"L": "M", "M": "d", "d": "D"}[ch]   # panels
                p.px[(x, y)] = ch
        if kind == "beanie":
            p.capsule((cx - 1, cy - 12.5), (cx - 1, cy - 12.5), 3.0, 3.0, "white")
        else:
            for y in range(int(cy - 16), int(cy - 11)):   # the stalk
                p.px[(round(cx - 1), y)] = "g"
            for x in range(int(cx - 10), int(cx + 9)):    # the blades
                if abs(x + 0.5 - (cx - 1)) < 1.5:
                    continue
                p.px[(x, int(cy - 17))] = "k"
                if abs(x + 0.5 - (cx - 1)) < 7:
                    p.px[(x, int(cy - 16))] = "K"
            p.px[(round(cx - 1), int(cy - 17))] = "g"     # the hub
    elif kind == "backcap":
        # the cap worn backwards: the brim over the nape
        for y in range(int(cy - 12), int(band_y + 3)):
            for x in range(int(cx - 12), int(cx + 13)):
                px, py = x + 0.5, y + 0.5
                if not in_dome(px, py, 11.4, 10.6) or py > band_y + slope(px):
                    continue
                s = lit(px, py)
                ch = "L" if s < -0.45 else ("d" if s > 0.5 else "M")
                if py > band_y - 1.5 + slope(px):
                    ch = "d"
                p.px[(x, y)] = ch
        for y in range(int(band_y - 1), int(band_y + 6)):
            for x in range(int(cx - 19), int(cx - 7)):
                t = (cx - 7 - x) / 12
                top = band_y + slope(cx - 7) - 1 + t * 2.5
                if top <= y + 0.5 <= top + 3.0 - t * 0.8:
                    p.px[(x, y)] = "L" if y + 0.5 < top + 1 else "M"
        p.px[(round(cx), round(cy - 11))] = "d"           # button
    elif kind == "bucket":
        for y in range(int(cy - 15), int(band_y + 1)):    # the crown
            for x in range(int(cx - 12), int(cx + 12)):
                px, py = x + 0.5, y + 0.5
                if not in_dome(px, py, 10.6, 11.0, -2) or py > band_y + slope(px) * 0.5:
                    continue
                s = lit(px, py)
                ch = "L" if s < -0.45 else ("d" if s > 0.5 else "M")
                if py > band_y - 2.5 + slope(px) * 0.5:
                    ch = "D"                              # the band
                p.px[(x, y)] = ch
        for x in range(int(cx - 17), int(cx + 18)):       # the floppy brim
            tt = (x + 0.5 - cx) / 17
            top = band_y + slope(x + 0.5) * 0.5 + 3.5 * tt * tt - 0.5
            for y in range(int(top), int(top + 4)):
                if top <= y + 0.5 <= top + 3.2:
                    p.px[(x, y)] = "M" if y + 0.5 < top + 1.2 else "d"
    elif kind == "crown":
        # silver, its points lit white, jewels in the shirt colour
        for x in range(int(cx - 11), int(cx + 12)):
            px = x + 0.5
            if not in_dome(px, cy, 11.0, 10.6):
                continue
            ph = (x - cx + 70) % 7
            spike = 4.5 - abs(ph - 3) * 1.4
            top = band_y - 5 + slope(px) - max(spike, 0)
            low = band_y + 1 + slope(px)
            for y in range(int(top), int(low) + 1):
                py = y + 0.5
                if not top <= py <= low:
                    continue
                s = lit(px, py)
                ch = "W" if s < -0.3 else ("q" if s > 0.5 else "w")
                if py < top + 1.2 and spike > 3:
                    ch = "Z"
                if py > low - 1.2:
                    ch = "q"
                p.px[(x, y)] = ch
            if ph == 3:
                p.px[(x, int(band_y - 2 + slope(px)))] = "M"
                p.px[(x, int(band_y - 1 + slope(px)))] = "d"
    elif kind == "chef":
        for y in range(int(band_y - 5), int(band_y + 3)):  # the band
            for x in range(int(cx - 11), int(cx + 11)):
                px, py = x + 0.5, y + 0.5
                if not in_dome(px, py, 11.2, 10.6) or py > band_y + 1 + slope(px):
                    continue
                p.px[(x, y)] = "q" if py > band_y + slope(px) else "w"
        for y in range(int(cy - 19), int(band_y - 4)):     # the puff
            for x in range(int(cx - 13), int(cx + 13)):
                px, py = x + 0.5, y + 0.5
                if ((px - cx) / 12.5) ** 2 + ((py - (cy - 12)) / 7.5) ** 2 > 1:
                    continue
                s = lit(px, py)
                ch = "Z" if s < -0.3 else ("q" if s > 0.6 else "W")
                if (x + 40) % 6 == 0 and py > cy - 13:
                    ch = "w"                              # the pleats
                p.px[(x, y)] = ch
    elif kind == "viking":
        for y in range(int(cy - 13), int(band_y + 4)):     # the helmet
            for x in range(int(cx - 13), int(cx + 13)):
                px, py = x + 0.5, y + 0.5
                low = band_y + 1 + slope(px)
                if not in_dome(px, py, 12.0, 11.4, -0.5) or py > low:
                    continue
                s = lit(px, py)
                ch = "S" if s < -0.4 else ("g" if s > 0.5 else "q")
                if py > low - 2.5:
                    ch = "d" if s > 0.3 else "M"          # the shirt band
                elif abs(px - cx) < 1.2:
                    ch = "S"                              # the crest
                p.px[(x, y)] = ch
        p.capsule((cx + 8, cy - 7), (cx + 11, cy - 12), 2.2, 1.6, "white")
        p.capsule((cx + 11, cy - 12), (cx + 10, cy - 17), 1.6, 0.7, "white")
        p.capsule((cx - 9, cy - 7), (cx - 13, cy - 12), 2.2, 1.6, "white")
        p.capsule((cx - 13, cy - 12), (cx - 12, cy - 17), 1.6, 0.7, "white")
    else:
        raise ValueError(kind)
    return p


# --- Poses (the 48 px rig's, times S, plus the four new SNES poses) -----------

def shift(pose, dx=0, dy=0, **override):
    out = {}
    for k, v in pose.items():
        if isinstance(v, tuple) and len(v) == 2 and k[:3] not in ("toe", "pad"):
            out[k] = (v[0] + dx, v[1] + dy)
        else:
            out[k] = v
    out.update(override)
    return out


IDLE = dict(
    neck=(31, 24), hip=(26, 38.5),
    sh_n=(31, 28), el_n=(33, 34), ha_n=(39, 35),
    sh_f=(28, 28), el_f=(30, 34), ha_f=(37, 36),
    kn_n=(36.5, 46), an_n=(34, 54.5), toe_n=(1, 0),
    kn_f=(19, 46), an_f=(16, 54.5), toe_f=(1, 0),
    paddle=(-62, "front"),
)
RUN = dict(IDLE, neck=(33, 24), hip=(27, 37),
           sh_n=(33, 29), el_n=(35, 35), ha_n=(40, 35),
           sh_f=(30, 29), paddle=(-58, "front"), pony="fly")

POSES = {
    "idle0": IDLE,
    "idle1": shift(IDLE, 0, 1, kn_n=(37, 47), an_n=(34, 54.5),
                   kn_f=(18.5, 47), an_f=(16, 54.5)),
    "run0": shift(RUN, 0, 1, el_f=(33, 34), ha_f=(38, 32),
                  ha_n=(39, 35), paddle=(-66, "front"),
                  kn_n=(37, 45), an_n=(39, 54.5),
                  kn_f=(22, 46), an_f=(16, 50), toe_f=(1, 0.9)),
    "run1": shift(RUN, 0, 0, el_f=(30, 35), ha_f=(33, 38),
                  kn_n=(30, 46), an_n=(28.5, 54.5),
                  kn_f=(29, 46), an_f=(21, 48), toe_f=(1, 1.1)),
    "run2": shift(RUN, 0, 1, el_f=(26, 34), ha_f=(23, 38),
                  ha_n=(41, 34), paddle=(-52, "front"),
                  kn_n=(22, 46), an_n=(16, 50), toe_n=(1, 0.9),
                  kn_f=(36, 45), an_f=(38, 54.5)),
    "run3": shift(RUN, 0, 0, el_f=(30, 35), ha_f=(33, 38),
                  kn_n=(31, 46), an_n=(23, 48), toe_n=(1, 1.1),
                  kn_f=(29, 46), an_f=(27.5, 54.5)),
    "windup": dict(IDLE, neck=(28, 24), hip=(27, 37),
                   sh_n=(29, 29), el_n=(23, 33), ha_n=(18, 32),
                   sh_f=(27, 29), el_f=(33, 31), ha_f=(38, 29),
                   kn_n=(34, 46), an_n=(36, 54.5),
                   kn_f=(21, 45), an_f=(17, 54.5),
                   paddle=(-150, "mid")),
    "swing": dict(neck=(34, 24), hip=(28, 37),
                  sh_n=(34, 29), el_n=(40, 30), ha_n=(46, 31),
                  sh_f=(31, 29), el_f=(25, 31), ha_f=(20, 29),
                  kn_n=(40, 46), an_n=(42, 54.5), toe_n=(1, 0),
                  kn_f=(21, 47), an_f=(14, 53.5), toe_f=(1, 0.35),
                  paddle=(-12, "front"), pony="fly"),
    "follow": dict(neck=(34, 24), hip=(28, 37),
                   sh_n=(34, 29), el_n=(40, 27), ha_n=(45, 21),
                   sh_f=(31, 29), el_f=(26, 33), ha_f=(22, 35),
                   kn_n=(40, 46), an_n=(42, 54.5), toe_n=(1, 0),
                   kn_f=(23, 47), an_f=(17, 52.5), toe_f=(1, 0.6),
                   paddle=(-62, "front"), pony="fly"),
    "toss": dict(IDLE, neck=(30, 23), hip=(26, 37),
                 sh_n=(30, 28), el_n=(26, 34), ha_n=(22, 38),
                 sh_f=(28, 28), el_f=(32, 33), ha_f=(37, 33),
                 kn_n=(34, 46), an_n=(35, 54.5),
                 kn_f=(22, 46), an_f=(20, 54.5),
                 paddle=(148, "back")),
    "cheer": dict(IDLE, neck=(30, 24), hip=(27, 37),
                  sh_n=(31, 29), el_n=(37, 24), ha_n=(41, 17),
                  sh_f=(28, 29), el_f=(22, 25), ha_f=(18, 18),
                  kn_n=(33, 46), an_n=(34, 54.5),
                  kn_f=(22, 46), an_f=(20, 54.5),
                  paddle=(-80, "front")),
    # New poses (match the SNES reference set).
    "overhead_windup": dict(neck=(29, 24), hip=(27, 37.5),
                            sh_n=(29, 28), el_n=(23, 26), ha_n=(22, 19),
                            sh_f=(28, 28), el_f=(32, 20), ha_f=(35, 10),
                            kn_n=(35, 46), an_n=(37, 54.5), toe_n=(1, 0),
                            kn_f=(21, 46), an_f=(17, 54.5), toe_f=(1, 0),
                            paddle=(125, "back")),
    "overhead_contact": dict(neck=(32, 23), hip=(28, 37),
                             sh_n=(32, 27), el_n=(36, 20), ha_n=(39, 14),
                             sh_f=(30, 27), el_f=(26, 33), ha_f=(23, 38),
                             kn_n=(38, 46), an_n=(41, 54.5), toe_n=(1, 0),
                             kn_f=(22, 46), an_f=(17, 53.5), toe_f=(1, 0.4),
                             paddle=(-82, "front"), pony="fly"),
    "reach": dict(neck=(33, 28), hip=(25, 40),
                  sh_n=(33, 32), el_n=(39, 37), ha_n=(44, 42),
                  sh_f=(30, 32), el_f=(24, 34), ha_f=(19, 33),
                  kn_n=(40, 47), an_n=(41, 54.5), toe_n=(1, 0),
                  kn_f=(18, 48), an_f=(9, 53.5), toe_f=(1, 0.5),
                  paddle=(35, "front"), pony="fly"),
    "scoop": dict(neck=(31, 30), hip=(25, 42.5),
                  sh_n=(31, 34), el_n=(35, 41), ha_n=(40, 47),
                  sh_f=(29, 34), el_f=(31, 41), ha_f=(36, 46),
                  kn_n=(35, 47.5), an_n=(33, 54.5), toe_n=(1, 0),
                  kn_f=(19, 48), an_f=(17, 54.5), toe_f=(1, 0),
                  paddle=(5, "front")),
}
SLOTS = ["idle0", "idle1", "run0", "run1", "run2", "run3", "windup", "swing",
         "follow", "toss", "cheer", "overhead_windup", "overhead_contact",
         "reach", "scoop"]
ANIMS = {"idle": (["idle0", "idle1"], 300), "run": (["run0", "run1", "run2",
                                                    "run3"], 90),
         "swing": (["windup", "swing", "follow"], 70), "toss": (["toss"], 200),
         "cheer": (["cheer"], 200),
         "overhead": (["overhead_windup", "overhead_contact"], 90),
         "reach": (["reach"], 150), "scoop": (["scoop"], 150)}


def scaled(pose):
    P = {}
    for k, v in pose.items():
        if isinstance(v, tuple) and len(v) == 2 and k[:3] not in ("toe", "pad"):
            P[k] = (v[0] * S, v[1] * S)
        else:
            P[k] = v
    # the slimmer proportions of the 48 px set (neck and shoulders up)
    P["neck"] = add(P["neck"], (0, -2 * S))
    for k in ("sh_n", "sh_f"):
        P[k] = add(P[k], (0, -1.5 * S))
    return P


def render(pose, female=False, hat="cap"):
    """hat: None (bare), "cap", or one of HATS."""
    c = Canvas()
    P = scaled(pose)
    if P["paddle"][1] == "back":
        c.draw(paddle(P["ha_n"], P["paddle"][0]))
    c.draw(arm(P["sh_f"], P["el_f"], P["ha_f"], far=True))
    c.draw(leg(P["hip"], P["kn_f"], P["an_f"], P["toe_f"], far=True))
    head, cap, tail = head_parts(P["neck"], female, P.get("pony", "hang"))
    if tail is not None:
        c.draw(tail)
    c.draw(leg(add(P["hip"], (2 * S, 0)), P["kn_n"], P["an_n"], P["toe_n"]))
    c.draw(shorts(P["hip"], P["kn_n"], P["kn_f"]))
    c.draw(torso(P["neck"], P["hip"]))
    c.draw(neck_part(P["neck"]))
    c.draw(head)
    if hat == "cap":
        c.draw(cap)
    elif hat is not None:
        c.draw(hat_part(P["neck"], hat))
    c.draw(collar(P["neck"]))
    ang, layer = P["paddle"]
    pad = paddle(P["ha_n"], ang)
    if layer == "mid":
        c.draw(pad)
    c.draw(arm(P["sh_n"], P["el_n"], P["ha_n"]))
    if layer == "front":
        c.draw(pad)
        fist = Part()
        fist.capsule(P["ha_n"], P["ha_n"], 1.6 * S, 1.6 * S, "skin")
        hx, hy = round(P["ha_n"][0] - 0.5), round(P["ha_n"][1] - 0.5)
        fist.px[(hx - 1, hy - 1)] = "4"
        c.draw(fist)
    return c.rows(), c.clipped


def cap_overlay(bare, capped):
    """Hat layer = pixels where the hatted frame differs from the bare one."""
    return ["".join(c if c != b else "." for b, c in zip(rb, rc))
            for rb, rc in zip(bare, capped)]
