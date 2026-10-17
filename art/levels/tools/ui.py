"""HUD kit for the 960x540 levels: bitmap fonts, 9-slice panels, button
glyphs, the pickleball icon, plus the ball, shadows and hit effects."""
from __future__ import annotations

import numpy as np

from pix import FONT5x7, grow, hexrgb

OUT = hexrgb("0b0f1e")


def epx(b: np.ndarray) -> np.ndarray:
    """EPX / Scale2x on a binary image: smooth 2x for pixel art."""
    h, w = b.shape
    P = np.pad(b, 1)
    A, B, C, D = P[:-2, 1:-1], P[1:-1, 2:], P[1:-1, :-2], P[2:, 1:-1]
    out = np.zeros((h * 2, w * 2), bool)
    e = b
    out[0::2, 0::2] = np.where(C & A & ~D & ~B, True, e)
    out[0::2, 1::2] = np.where(A & B & ~C & ~D, True, e)
    out[1::2, 0::2] = np.where(D & C & ~B & ~A, True, e)
    out[1::2, 1::2] = np.where(B & D & ~A & ~C, True, e)
    return out


def glyph_mask(ch: str, scale: int, bold=True) -> np.ndarray:
    g = FONT5x7.get(ch, FONT5x7[" "])
    b = np.array([[c == "1" for c in row] for row in g], bool)
    if scale & (scale - 1):                  # not a power of two: blocky
        b = np.kron(b, np.ones((scale, scale), bool))
    else:
        s = 1
        while s < scale:
            b = epx(b)
            s *= 2
    if not bold:
        return b
    # bold: widen strokes after scaling (counters are big enough by now)
    wide = max(1, (scale + 1) // 2)
    b = np.pad(b, ((0, 0), (0, wide)))
    for k in range(1, wide + 1):
        b[:, k:] |= b[:, :-k].copy()
    return b


def render_glyph(ch, scale, fill_top, fill_bot, outline=OUT, outline_w=2,
                 shadow=1, highlight=None):
    """RGBA glyph: two-band fill (top/bottom), optional 1 px highlight on
    top edges, outline_w px outline and a 1 px drop shadow."""
    m = glyph_mask(ch, scale)
    pad = outline_w + shadow + 1
    m = np.pad(m, pad)
    h, w = m.shape
    img = np.zeros((h, w, 4), np.uint8)
    o = m.copy()
    for _ in range(outline_w):
        o = grow(o, diag=True)
    sh = np.zeros_like(o)
    sh[shadow:, shadow:] = o[:-shadow, :-shadow] if shadow else o
    img[sh | o, :3] = outline
    img[sh | o, 3] = 255
    rows = np.nonzero(m.any(axis=1))[0]
    mid = (rows.min() + rows.max()) // 2 + 1 if len(rows) else 0
    top = m.copy()
    top[mid:] = False
    img[m, :3] = fill_bot
    img[top, :3] = fill_top
    img[m, 3] = 255
    if highlight is not None:
        edge = m & ~np.vstack([np.zeros((1, w), bool), m[:-1]])
        img[edge, :3] = highlight
    return img


CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,:-'/%+ "


def font_atlas(scale, fill_top, fill_bot, highlight, outline_w, name):
    """One row atlas, fixed cell. Returns (image, metrics dict)."""
    cells = [render_glyph(c, scale, fill_top, fill_bot, outline_w=outline_w,
                          highlight=highlight) for c in CHARSET]
    ch_h = max(c.shape[0] for c in cells)
    cw = max(c.shape[1] for c in cells)
    atlas = np.zeros((ch_h, cw * len(CHARSET), 4), np.uint8)
    glyphs = {}
    for i, (c, g) in enumerate(zip(CHARSET, cells)):
        atlas[:g.shape[0], i * cw:i * cw + g.shape[1]] = g
        ink = np.nonzero(g[..., 3].any(axis=0))[0]
        adv = (ink.max() + 1 - outline_w) if len(ink) else cw // 2
        glyphs[c] = {"x": i * cw, "y": 0, "w": cw, "h": ch_h,
                     "advance": int(adv if c != " " else scale * 4)}
    meta = {"name": name, "cell": [cw, ch_h], "line_height": ch_h,
            "baseline": int(7 * scale + outline_w + 1),
            "chars": CHARSET, "glyphs": glyphs}
    return atlas, meta


def text_image(atlas, meta, text, spacing=-1):
    xs = 0
    gl = meta["glyphs"]
    w = sum(gl.get(c, gl[" "])["advance"] + spacing for c in text) + 8
    h = meta["line_height"]
    out = np.zeros((h, w, 4), np.uint8)
    for c in text:
        g = gl.get(c, gl[" "])
        src = atlas[:, g["x"]:g["x"] + g["w"]]
        on = src[..., 3] > 0
        ww = min(g["w"], w - xs)
        region = out[:, xs:xs + ww]
        region[on[:, :ww]] = src[:, :ww][on[:, :ww]]
        xs += g["advance"] + spacing
    return out[:, :xs + 4]


# -- Panels (9-slice) ----------------------------------------------------------

def panel(w, h, fill, border, inner_hl=None, outline=OUT, border_w=3,
          corner=4):
    """Rounded-corner panel: outline, border band (light top, dark bottom),
    fill. border: (dark, mid, light)."""
    img = np.zeros((h, w, 4), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]

    def rounded(inset, r):
        x0, y0, x1, y1 = inset, inset, w - 1 - inset, h - 1 - inset
        m = (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
        for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r),
                       (x1 - r, y1 - r)):
            corner_zone = (np.abs(xx - cx) > 0) & (((xx < cx) & (cx == x0 + r)) |
                                                    ((xx > cx) & (cx == x1 - r)))
            corner_zone &= ((yy < cy) & (cy == y0 + r)) | ((yy > cy) & (cy == y1 - r))
            m &= ~(corner_zone & ((xx - cx) ** 2 + (yy - cy) ** 2 > r * r + r))
        return m

    o = rounded(0, corner)
    b = rounded(1, corner - 1)
    f = rounded(1 + border_w, max(1, corner - 2))
    img[o, :3] = outline
    img[o, 3] = 255
    img[b, :3] = border[1]
    img[b & (yy < h // 2), :3] = border[2]
    img[b & (yy >= h - 3 - border_w), :3] = border[0]
    inner_edge = f & ~shrink_once(f)
    img[f, :3] = fill[1]
    img[f & (yy > h * 0.55), :3] = fill[0]
    img[inner_edge, :3] = outline
    if inner_hl is not None:
        hl = f & ~shrink_once(f) & (yy < h // 2)
        img[shrink_once(f) & ~shrink_once(shrink_once(f)) & (yy < h // 3), :3] = inner_hl
    return img


def shrink_once(m):
    return ~grow(~m)


def ball_icon(r=6, ball=("c8b020", "e4d030", "f4e870"), hole="8a7a14"):
    d = r * 2 + 3
    img = np.zeros((d, d, 4), np.uint8)
    yy, xx = np.mgrid[0:d, 0:d]
    c = r + 1
    m = (xx - c) ** 2 + (yy - c) ** 2 <= r * r + r * 0.6
    o = grow(m, True) & ~m
    img[o, :3] = OUT
    img[o, 3] = 255
    b = [hexrgb(x) for x in ball]
    img[m, :3] = b[1]
    img[m & ((xx - c) + (yy - c) < -r * 0.5), :3] = b[2]
    img[m & ((xx - c) + (yy - c) > r * 0.6), :3] = b[0]
    img[m, 3] = 255
    for dx, dy in ((-2, -3), (2, -2), (-3, 1), (1, 1), (3, 3), (-1, 4), (0, -1)):
        if m[c + dy, c + dx]:
            img[c + dy, c + dx, :3] = hexrgb(hole)
    return img


def button_glyph(letter, color, r=10):
    d = r * 2 + 4
    img = np.zeros((d, d, 4), np.uint8)
    yy, xx = np.mgrid[0:d, 0:d]
    c = r + 1.5
    m = (xx - c) ** 2 + (yy - c) ** 2 <= r * r
    o = grow(m, True) & ~m
    img[o, :3] = OUT
    img[o, 3] = 255
    dark = tuple(int(v * 0.65) for v in color)
    light = tuple(min(255, int(v * 1.25 + 30)) for v in color)
    img[m, :3] = color
    img[m & (yy > c + r * 0.35), :3] = dark
    img[m & ((xx - c) ** 2 + (yy - c + r * 0.45) ** 2 < (r * 0.45) ** 2), :3] = light
    img[m, 3] = 255
    g = glyph_mask(letter, 2, bold=False)
    gh, gw = g.shape
    y0, x0 = int(c - gh / 2) + 1, int(c - gw / 2) + 1
    img[y0:y0 + gh, x0:x0 + gw][g, :3] = (250, 250, 250)
    return img


# -- Ball, shadows, effects ------------------------------------------------------

def ball_frames(r=6, n=4):
    """Rolling ball: the holes rotate between frames."""
    frames = []
    d = r * 2 + 3
    b = [hexrgb(x) for x in ("bfae1e", "e0d02c", "f2e66a")]
    holes = [(-2, -3), (2, -2), (-3, 1), (1, 1), (3, 3), (-1, 4), (0, -1), (3, -1)]
    for k in range(n):
        img = np.zeros((d, d, 4), np.uint8)
        yy, xx = np.mgrid[0:d, 0:d]
        c = r + 1
        m = (xx - c) ** 2 + (yy - c) ** 2 <= r * r + r * 0.6
        o = grow(m, True) & ~m
        img[o, :3] = OUT
        img[o, 3] = 255
        img[m, :3] = b[1]
        img[m & ((xx - c) + (yy - c) < -r * 0.5), :3] = b[2]
        img[m & ((xx - c) + (yy - c) > r * 0.6), :3] = b[0]
        img[m, 3] = 255
        a = k * np.pi / 2 / n * 2
        for hx, hy in holes:
            rx = round(hx * np.cos(a) - hy * np.sin(a))
            ry = round(hx * np.sin(a) + hy * np.cos(a))
            if 0 <= c + ry < d and 0 <= c + rx < d and m[c + ry, c + rx]:
                img[c + ry, c + rx, :3] = hexrgb("8a7a14")
        frames.append(img)
    return frames


def shadow(w, h, alpha=110):
    img = np.zeros((h, w, 4), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    m = ((xx + 0.5 - w / 2) / (w / 2)) ** 2 + ((yy + 0.5 - h / 2) / (h / 2)) ** 2 <= 1
    img[m, :3] = (10, 14, 24)
    img[m, 3] = alpha
    return img


def spark_frames(size=24):
    """Contact flash (level-02): a white star burst with yellow tips."""
    frames = []
    c = size // 2
    for k, (L, w) in enumerate(((5, 1), (10, 2), (11, 1), (7, 1))):
        img = np.zeros((size, size, 4), np.uint8)
        for a in range(8):
            ang = a * np.pi / 4 + (np.pi / 8 if k % 2 else 0)
            ln = L if a % 2 == 0 else L * 0.6
            for t in np.linspace(0, ln, int(ln * 2) + 1):
                x, y = int(round(c + np.cos(ang) * t)), int(round(c + np.sin(ang) * t))
                col = (255, 255, 255) if t < ln * 0.6 else (250, 222, 80)
                for dx in range(-(w // 2), w // 2 + 1):
                    if 0 <= x + dx < size and 0 <= y < size:
                        img[y, x + dx, :3] = col
                        img[y, x + dx, 3] = 255
        r = (3, 4, 3, 1)[k]
        yy, xx = np.mgrid[0:size, 0:size]
        core = (xx - c) ** 2 + (yy - c) ** 2 <= r * r
        img[core, :3] = (255, 255, 255)
        img[core, 3] = 255
        frames.append(img)
    return frames


def dust_frames(size=16, tint=(214, 180, 130)):
    frames = []
    rng = np.random.default_rng(3)
    dark = tuple(int(v * 0.8) for v in tint)
    for k in range(4):
        img = np.zeros((size, size, 4), np.uint8)
        yy, xx = np.mgrid[0:size, 0:size]
        for (ox, oy, r) in ((-3, 1, 3), (3, 1, 3), (0, -1, 4)):
            rr = r * (0.6 + k * 0.25) * (1 - k * 0.12)
            cx, cy = size / 2 + ox * (1 + k * 0.4), size - 5 + oy - k
            m = (xx - cx) ** 2 + (yy - cy) ** 2 <= rr * rr
            img[m, :3] = tint if k < 2 else dark
            img[m, 3] = 230 - k * 50
        frames.append(img)
    return frames
