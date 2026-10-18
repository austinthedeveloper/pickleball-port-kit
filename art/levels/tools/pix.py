"""Pixel-art drawing kit for the 960x540 levels.

Everything is hard-edged: no anti-aliasing, every colour comes from a named
ramp, shading is banded. Layers are RGBA numpy arrays (H, W, 4) uint8.
Shapes are rasterised with PIL in 1-bit mode (aliased) and coloured with
numpy.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SCREEN_W, SCREEN_H = 960, 540
OVER_X, OVER_Y = 48, 24                 # layer overscan for the camera
LAYER_W, LAYER_H = SCREEN_W + 2 * OVER_X, SCREEN_H + 2 * OVER_Y


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(*hexes: str) -> list[tuple[int, int, int]]:
    """Dark to light."""
    return [hexrgb(h) for h in hexes]


class Layer:
    """RGBA canvas in layer space. Screen (0, 0) is layer (OVER_X, OVER_Y)
    when the layer has overscan; draw with screen coordinates via `sx/sy`."""

    def __init__(self, w=LAYER_W, h=LAYER_H, ox=OVER_X, oy=OVER_Y):
        self.a = np.zeros((h, w, 4), np.uint8)
        self.ox, self.oy = ox, oy

    @property
    def h(self):
        return self.a.shape[0]

    @property
    def w(self):
        return self.a.shape[1]

    # -- masks -------------------------------------------------------------
    def mask(self) -> tuple[Image.Image, ImageDraw.ImageDraw]:
        m = Image.new("1", (self.w, self.h), 0)
        return m, ImageDraw.Draw(m)

    def pts(self, pts):
        return [(x + self.ox, y + self.oy) for x, y in pts]

    def poly_mask(self, pts) -> np.ndarray:
        m, d = self.mask()
        d.polygon(self.pts(pts), fill=1)
        return np.array(m, bool)

    def ellipse_mask(self, cx, cy, rx, ry) -> np.ndarray:
        m, d = self.mask()
        d.ellipse([cx - rx + self.ox, cy - ry + self.oy,
                   cx + rx + self.ox, cy + ry + self.oy], fill=1)
        return np.array(m, bool)

    def rect_mask(self, x0, y0, x1, y1) -> np.ndarray:
        """Inclusive-exclusive screen rect."""
        m = np.zeros((self.h, self.w), bool)
        X0, Y0 = max(0, int(x0) + self.ox), max(0, int(y0) + self.oy)
        X1, Y1 = min(self.w, int(x1) + self.ox), min(self.h, int(y1) + self.oy)
        if X1 > X0 and Y1 > Y0:
            m[Y0:Y1, X0:X1] = True
        return m

    def line_mask(self, pts, width=1) -> np.ndarray:
        m, d = self.mask()
        d.line(self.pts(pts), fill=1, width=width)
        return np.array(m, bool)

    # -- painting ----------------------------------------------------------
    def fill(self, m: np.ndarray, rgb, alpha=255):
        self.a[m, :3] = rgb
        self.a[m, 3] = alpha

    def fill_where(self, m, rgb_img: np.ndarray):
        """rgb_img: (H, W, 3) array, painted where m."""
        self.a[m, :3] = rgb_img[m]
        self.a[m, 3] = 255

    def px(self, x, y, rgb):
        X, Y = int(x) + self.ox, int(y) + self.oy
        if 0 <= X < self.w and 0 <= Y < self.h:
            self.a[Y, X, :3] = rgb
            self.a[Y, X, 3] = 255

    def over(self, other: "Layer", dx=0, dy=0):
        """Alpha-over another layer (hard alpha), offset in pixels."""
        src = other.a
        h, w = src.shape[:2]
        x0, y0 = dx, dy
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww = min(w - xs0, self.w - xd0)
        hh = min(h - ys0, self.h - yd0)
        if ww <= 0 or hh <= 0:
            return
        s = src[ys0:ys0 + hh, xs0:xs0 + ww]
        d = self.a[yd0:yd0 + hh, xd0:xd0 + ww]
        on = s[..., 3] > 0
        d[on] = s[on]

    def alpha(self) -> np.ndarray:
        return self.a[..., 3] > 0

    def outline(self, rgb, m: np.ndarray | None = None, diag=False):
        """1 px outline around mask m (default: the layer's alpha)."""
        m = self.alpha() if m is None else m
        o = grow(m, diag) & ~m
        self.fill(o, rgb)
        return o

    def save(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(path, optimize=True)

    def crop_screen(self) -> np.ndarray:
        return self.a[self.oy:self.oy + SCREEN_H, self.ox:self.ox + SCREEN_W]


def grow(m: np.ndarray, diag=False) -> np.ndarray:
    g = m.copy()
    g[1:] |= m[:-1]
    g[:-1] |= m[1:]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    if diag:
        g[1:, 1:] |= m[:-1, :-1]
        g[1:, :-1] |= m[:-1, 1:]
        g[:-1, 1:] |= m[1:, :-1]
        g[:-1, :-1] |= m[1:, 1:]
    return g


def shrink(m: np.ndarray) -> np.ndarray:
    return ~grow(~m)


def edge_dist(m: np.ndarray, n=4) -> np.ndarray:
    """Pixels' distance (0..n) from the mask edge, for banded shading."""
    d = np.zeros(m.shape, np.uint8)
    cur = m.copy()
    for i in range(1, n + 1):
        cur = shrink(cur)
        d[cur] = i
    return d


def value_noise(h, w, cell, seed=0) -> np.ndarray:
    """Smooth value noise in [0, 1], feature size ~cell px."""
    rng = np.random.default_rng(seed)
    gh, gw = h // cell + 2, w // cell + 2
    g = rng.random((gh, gw))
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, cell, seed=0, octaves=3) -> np.ndarray:
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * value_noise(h, w, max(1, cell >> o), seed + o * 101)
        tot += amp
        amp *= 0.5
    return out / tot


def ramp_img(values: np.ndarray, rmp) -> np.ndarray:
    """Map values in [0, 1] to a ramp (banded), returns (H, W, 3)."""
    idx = np.clip((values * len(rmp)).astype(int), 0, len(rmp) - 1)
    return np.array(rmp, np.uint8)[idx]


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6],
                   [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def dither_ramp(values: np.ndarray, rmp, strength=1.0) -> np.ndarray:
    """Ordered-dithered ramp: banded with a checker at band edges."""
    h, w = values.shape
    t = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    v = values * len(rmp) + (t - 0.5) * strength
    idx = np.clip(v.astype(int), 0, len(rmp) - 1)
    return np.array(rmp, np.uint8)[idx]


# -- Foliage ------------------------------------------------------------------

def foliage(layer: Layer, clumps, rmp, seed=0, light=(-0.6, -0.8),
            outline=None, scallop=True):
    """Leaf mass from overlapping clumps [(cx, cy, r), ...] in screen coords.

    Each clump is shaded by its own normal (lit from the upper left), later
    clumps cover earlier ones, edges get a scalloped leaf texture. rmp: dark
    to light, 4-5 colours.
    """
    rng = random.Random(seed)
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    mass = np.zeros((H, W), bool)
    shade = np.zeros((H, W))
    for (cx, cy, r) in clumps:
        X, Y = cx + layer.ox, cy + layer.oy
        x0, x1 = int(max(0, X - r - 2)), int(min(W, X + r + 3))
        y0, y1 = int(max(0, Y - r - 2)), int(min(H, Y + r + 3))
        if x1 <= x0 or y1 <= y0:
            continue
        sx, sy = xx[y0:y1, x0:x1] + 0.5 - X, yy[y0:y1, x0:x1] + 0.5 - Y
        d = np.hypot(sx, sy)
        rr = r
        if scallop:
            ang = np.arctan2(sy, sx)
            k = rng.randint(5, 9)
            ph = rng.random() * 6.28
            rr = r * (0.88 + 0.12 * np.cos(ang * k + ph))
        inside = d <= rr
        nx, ny = sx / max(r, 1), sy / max(r, 1)
        s = -(nx * light[0] + ny * light[1])      # 1 = facing the light
        s = 0.5 - 0.5 * s
        s = np.clip(s + (d / max(r, 1)) * 0.15, 0, 1)
        sub = shade[y0:y1, x0:x1]
        sub[inside] = s[inside]
        mass[y0:y1, x0:x1] |= inside
    # leaf texture: small noise breaks the bands into leafy clusters
    n = fbm(H, W, 6, seed + 7, 2)
    v = np.clip(1 - shade + (n - 0.5) * 0.35, 0, 0.999)
    img = ramp_img(v, rmp)
    layer.fill_where(mass, img)
    if outline is not None:
        layer.outline(outline, mass)
    return mass


def tree(layer: Layer, x, base_y, height, width, leaf_rmp, bark_rmp,
         seed=0, trunk_w=8, outline=None, crown_frac=0.72, clumpiness=1.0):
    """A broadleaf tree: trunk with a couple of branches, clumped crown."""
    rng = random.Random(seed)
    top = base_y - height
    crown_h = height * crown_frac
    cy = top + crown_h * 0.5
    # trunk
    tw = trunk_w
    trunk = layer.poly_mask([(x - tw / 2, base_y), (x + tw / 2, base_y),
                             (x + tw * 0.3, cy), (x - tw * 0.3, cy)])
    for _ in range(2):
        bx = x + rng.choice((-1, 1)) * width * rng.uniform(0.15, 0.3)
        by = cy + crown_h * rng.uniform(-0.05, 0.2)
        trunk |= layer.line_mask([(x, cy + crown_h * 0.35), (bx, by)],
                                 width=max(2, tw // 3))
    xs = np.nonzero(trunk.any(axis=0))[0]
    if len(xs):
        img = np.zeros(trunk.shape + (3,), np.uint8)
        cols = np.arange(trunk.shape[1])
        rel = (cols - (x + layer.ox - tw / 2)) / max(tw, 1)
        band = np.clip((rel * len(bark_rmp)).astype(int), 0, len(bark_rmp) - 1)
        band = len(bark_rmp) - 1 - band          # lit on the left
        img[:] = np.array(bark_rmp, np.uint8)[band][None, :, :]
        layer.fill_where(trunk, img)
    # crown clumps
    clumps = []
    n = int(10 + 14 * clumpiness * width / 100)
    for i in range(n):
        a = rng.random() * math.tau
        rr = math.sqrt(rng.random())
        px = x + math.cos(a) * rr * width * 0.42
        py = cy + math.sin(a) * rr * crown_h * 0.42
        r = rng.uniform(0.16, 0.26) * width
        clumps.append((px, py, r))
    # draw lower/back clumps first so upper-left ones overlap
    clumps.sort(key=lambda c: (c[1] + c[0] * 0.3), reverse=True)
    foliage(layer, clumps, leaf_rmp, seed=seed, outline=outline)
    return clumps


def bush(layer: Layer, cx, base_y, w, h, rmp, seed=0, outline=None):
    rng = random.Random(seed)
    clumps = []
    for i in range(int(6 + w / 10)):
        px = cx + rng.uniform(-0.45, 0.45) * w
        py = base_y - rng.uniform(0.25, 0.75) * h
        r = rng.uniform(0.18, 0.3) * min(w, h * 1.6)
        clumps.append((px, py, r))
    clumps.sort(key=lambda c: c[1], reverse=True)
    return foliage(layer, clumps, rmp, seed=seed, outline=outline)


# -- Structures ----------------------------------------------------------------

def chain_link(layer: Layer, x0, y0, x1, y1, rgb, spacing=6, alpha=255):
    """Diamond mesh in a screen rect (only the wire pixels are painted)."""
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = xx - layer.ox, yy - layer.oy
    inside = (sx >= x0) & (sx < x1) & (sy >= y0) & (sy < y1)
    a = (sx + sy) % spacing == 0
    b = (sx - sy) % spacing == 0
    m = inside & (a | b)
    layer.fill(m, rgb, alpha)
    return m


def text_glyphs():
    """5x7 matrix font (caps, digits, a few symbols) used by the UI font
    builder and for small sign lettering."""
    return FONT5x7


FONT5x7 = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    " ": ["00000"] * 7,
}


def stamp_text(layer: Layer, text, x, y, rgb, scale=1, spacing=1, bold=False):
    """Plain 5x7 text at scale (sign lettering); bold doubles each column."""
    if bold:
        stamp_text(layer, text, x + 1, y, rgb, scale, spacing + 1)
        return stamp_text(layer, text, x, y, rgb, scale, spacing + 1) + 1
    cx = x
    for ch in text.upper():
        g = FONT5x7.get(ch, FONT5x7[" "])
        for r, row in enumerate(g):
            for c, bit in enumerate(row):
                if bit == "1":
                    m = layer.rect_mask(cx + c * scale, y + r * scale,
                                        cx + (c + 1) * scale, y + (r + 1) * scale)
                    layer.fill(m, rgb)
        cx += (5 + spacing) * scale
    return cx - x - spacing * scale


def text_width(text, scale=1, spacing=1):
    return len(text) * (5 + spacing) * scale - spacing * scale


# -- Pixel sprites ------------------------------------------------------------

def sprite(layer: Layer, rows, x, y, pal, scale=1, flip=False, outline=None):
    """Stamp a hand-drawn sprite: rows of characters, each a key of pal
    ('.' or ' ' is clear). (x, y) is the screen pixel of the top-left;
    returns the painted mask. outline: a 1 px outline colour around it."""
    m = np.zeros((layer.h, layer.w), bool)
    w = max(len(r) for r in rows)
    for r, row in enumerate(rows):
        row = row.ljust(w, ".")
        if flip:
            row = row[::-1]
        for c, ch in enumerate(row):
            if ch in ". ":
                continue
            p = layer.rect_mask(x + c * scale, y + r * scale,
                                x + (c + 1) * scale, y + (r + 1) * scale)
            layer.fill(p, pal[ch])
            m |= p
    if outline is not None:
        layer.outline(outline, m)
    return m


def shift(m: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """m moved by (dx, dy) pixels; what moves in from the edge is clear."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else \
        (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else \
        (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = m[ys, xs]
    return out


def solid(layer: Layer, m: np.ndarray, rmp, outline=None, rim=2):
    """A lit solid (props, creatures): base colour, a lit rim toward the
    upper left, a shaded rim toward the lower right. rmp: shadow, base,
    light, highlight (3 colours: no highlight)."""
    layer.fill(m, rmp[1])
    shade = m & ~shift(m, -rim, -rim - 1)          # far from the light
    layer.fill(shade, rmp[0])
    lit = m & ~shift(m, rim, rim) & ~shade
    layer.fill(lit, rmp[2])
    if len(rmp) > 3:
        layer.fill(m & ~shift(m, 1, 1) & ~shade, rmp[3])
    if outline is not None:
        layer.outline(outline, m)
    return m
