"""Reusable scenery pieces for the venues: sky, clouds, skyline, tree
lines, chain-link fences, bleachers, benches, signs, bins, bushes."""
from __future__ import annotations

import math
import random

import numpy as np

from pix import (Layer, bush, chain_link, dither_ramp, edge_dist, fbm,
                 foliage, grow, hexrgb, ramp, stamp_text, text_width, tree)

OUTLINE = hexrgb("0b1626")


def M(cx, cy):
    """Mock pixel (1340x1174 concept) -> screen pixel (960x540 at 2x the
    mocks' art density, centred, extra width at the sides)."""
    return 160 + cx * 0.4773, cy * 0.4773


# -- Sky ------------------------------------------------------------------------

def sky_gradient(layer: Layer, stops, y0=-24, y1=200, dither=1.0):
    """stops: [(t, '#hex'), ...] top to bottom, banded with Bayer edges."""
    H, W = layer.h, layer.w
    ys = np.arange(H) - layer.oy
    t = np.clip((ys - y0) / (y1 - y0), 0, 1)
    cols = [hexrgb(h) for _, h in stops]
    ts = [s for s, _ in stops]
    # build a fine ramp of 2-3 bands per stop span
    rmp = []
    for i in range(len(cols) - 1):
        a, b = np.array(cols[i]), np.array(cols[i + 1])
        for k in range(3):
            rmp.append(tuple(int(v) for v in a + (b - a) * k / 3))
    rmp.append(cols[-1])
    # remap t through stop positions
    seg = np.interp(t, ts, np.linspace(0, 1, len(ts)))
    img = dither_ramp(np.tile(seg[:, None], (1, W)), rmp, dither)
    layer.fill_where(np.ones((H, W), bool), img)


def cloud(layer: Layer, cx, cy, w, h, rmp, seed=0):
    rng = random.Random(seed)
    clumps = []
    for i in range(int(5 + w / 14)):
        px = cx + rng.uniform(-0.42, 0.42) * w
        py = cy - abs(px - cx) / w * h * 0.2 - rng.uniform(0, 0.5) * h
        r = rng.uniform(0.18, 0.32) * w * (1 - abs(px - cx) / w)
        clumps.append((px, py, max(4, r)))
    tmp = Layer(layer.w, layer.h, layer.ox, layer.oy)
    m = foliage(tmp, clumps, rmp, seed=seed, scallop=True)
    base = tmp.rect_mask(cx - w, cy + 1, cx + w, cy + h)     # flat bottoms
    tmp.a[m & base, 3] = 0
    layer.over(tmp)


def sun(layer: Layer, cx, cy, r, rmp, stripes=(), sky=None):
    m = layer.ellipse_mask(cx, cy, r, r)
    d = edge_dist(m, 3)
    img = np.array(rmp, np.uint8)[np.clip(d, 0, len(rmp) - 1)]
    layer.fill_where(m, img)
    if sky is not None:
        for y, hgt in stripes:                   # retro horizontal cuts
            cut = layer.rect_mask(cx - r - 1, cy + y, cx + r + 2, cy + y + hgt)
            layer.fill(cut & m, sky)


# -- City skyline -------------------------------------------------------------

def skyline(layer: Layer, x0, x1, base_y, h_min, h_max, rmp, window,
            seed=0, density=1.0, lit=0.25):
    """Rows of buildings: back row darker/hazier, front row taller."""
    rng = random.Random(seed)
    for row, (fac, dy) in enumerate(((0.75, -6), (1.0, 0))):
        x = x0
        while x < x1:
            w = rng.randint(14, 34)
            h = rng.uniform(h_min, h_max) * fac
            if rng.random() < 0.18:
                h *= 1.5                            # a tower
            top = base_y - h + dy
            col = rmp[row] if row == 0 else rmp[1 + rng.randint(0, 1)]
            body = layer.rect_mask(x, top, x + w, base_y + 4)
            layer.fill(body, col)
            layer.fill(layer.rect_mask(x, top, x + 2, base_y + 4), rmp[-1]
                       if row else rmp[1])
            if rng.random() < 0.3:                   # roof box / antenna
                layer.fill(layer.rect_mask(x + w // 3, top - 4, x + w // 3 + 5,
                                           top), col)
            if rng.random() < 0.2:
                layer.fill(layer.rect_mask(x + w // 2, top - 12, x + w // 2 + 1,
                                           top), col)
            if row == 1:
                for wy in range(int(top) + 4, int(base_y), 5):
                    for wx in range(x + 4, x + w - 3, 4):
                        if rng.random() < lit * density:
                            layer.px(wx, wy, window)
                            layer.px(wx + 1, wy, window)
            x += w + rng.randint(-4, 3)


# -- Fences ---------------------------------------------------------------------

def hedge_band(layer: Layer, x0, x1, top, base, rmp, seed=0):
    """Solid dark base plus a row of bushes, so nothing behind shows."""
    layer.fill(layer.rect_mask(x0, top + 18, x1, base), rmp[0])
    for i, x in enumerate(range(int(x0) - 20, int(x1) + 30, 44)):
        bush(layer, x, base + 2, 70, base - top, rmp, seed=seed + i)


def fence(layer: Layer, x0, x1, top_y, base_y, posts, wire, post_rmp,
          spacing=6, rail=True, mid_rail=None):
    """Chain-link fence over whatever is behind it. posts: x list."""
    chain_link(layer, x0, top_y + 2, x1, base_y, wire, spacing)
    if rail:
        r = layer.rect_mask(x0, top_y, x1, top_y + 3)
        layer.fill(r, post_rmp[1])
        layer.fill(layer.rect_mask(x0, top_y, x1, top_y + 1), post_rmp[2])
    if mid_rail is not None:
        layer.fill(layer.rect_mask(x0, mid_rail, x1, mid_rail + 2), post_rmp[1])
    for px in posts:
        p = layer.rect_mask(px - 2, top_y - 3, px + 3, base_y + 1)
        layer.fill(p, post_rmp[1])
        layer.fill(layer.rect_mask(px - 2, top_y - 3, px - 1, base_y + 1),
                   post_rmp[2])
        layer.fill(layer.rect_mask(px + 2, top_y - 3, px + 3, base_y + 1),
                   post_rmp[0])
        cap = layer.rect_mask(px - 3, top_y - 5, px + 4, top_y - 2)
        layer.fill(cap, post_rmp[1])
        layer.fill(layer.rect_mask(px - 3, top_y - 5, px + 4, top_y - 4),
                   post_rmp[2])


# -- Furniture -------------------------------------------------------------------

def bleachers(layer: Layer, x0, x1, seat_y, rmp, rows=2, outline=OUTLINE):
    """Aluminium bleachers seen from the front: planks, risers, legs.
    seat_y is the top plank. Returns the seat rows' y for spectators."""
    seats = []
    m_all = np.zeros((layer.h, layer.w), bool)
    for r in range(rows):
        y = seat_y + r * 11
        inset = (rows - 1 - r) * 0
        seats.append(y)
        plank = layer.rect_mask(x0 + inset, y, x1 - inset, y + 4)
        layer.fill(plank, rmp[2])
        layer.fill(layer.rect_mask(x0 + inset, y, x1 - inset, y + 1), rmp[3])
        layer.fill(layer.rect_mask(x0 + inset, y + 3, x1 - inset, y + 4), rmp[1])
        m_all |= plank
        foot = layer.rect_mask(x0 + 2, y + 4, x1 - 2, y + 7)
        layer.fill(foot & ~m_all, rmp[0])
        m_all |= foot
    bottom = seat_y + rows * 11 + 6
    for lx in np.linspace(x0 + 6, x1 - 8, max(2, int((x1 - x0) / 60) + 1)):
        leg = layer.rect_mask(lx, seat_y + 4, lx + 3, bottom)
        layer.fill(leg & ~m_all, rmp[1])
        layer.fill(layer.rect_mask(lx, seat_y + 4, lx + 1, bottom) & ~m_all,
                   rmp[2])
        m_all |= leg
    layer.outline(outline, m_all)
    return seats


def park_bench(layer: Layer, x0, x1, seat_y, wood, metal, outline=OUTLINE):
    """Slatted bench with a backrest, seen from the front."""
    m = np.zeros((layer.h, layer.w), bool)
    for i, y in enumerate((seat_y - 16, seat_y - 11)):          # back slats
        s = layer.rect_mask(x0, y, x1, y + 4)
        layer.fill(s, wood[2])
        layer.fill(layer.rect_mask(x0, y, x1, y + 1), wood[3])
        layer.fill(layer.rect_mask(x0, y + 3, x1, y + 4), wood[1])
        m |= s
    seat = layer.rect_mask(x0 - 2, seat_y, x1 + 2, seat_y + 4)
    layer.fill(seat, wood[2])
    layer.fill(layer.rect_mask(x0 - 2, seat_y, x1 + 2, seat_y + 1), wood[3])
    layer.fill(layer.rect_mask(x0 - 2, seat_y + 3, x1 + 2, seat_y + 4), wood[0])
    m |= seat
    for lx in (x0 + 3, x1 - 6):
        leg = layer.rect_mask(lx, seat_y - 18, lx + 3, seat_y + 14)
        layer.fill(leg & ~m, metal[1])
        m |= leg
    layer.outline(outline, m)


def sign(layer: Layer, x0, y0, x1, y1, panel, border, text_rgb, lines,
         icon=None, posts=None, outline=OUTLINE, scale=2, bold=True):
    if posts:
        for px in posts:
            p = layer.rect_mask(px, y1, px + 4, y1 + posts[0] if False else y1 + 18)
            layer.fill(p, border[0])
    b = layer.rect_mask(x0, y0, x1, y1)
    layer.fill(b, border[1])
    inner = layer.rect_mask(x0 + 3, y0 + 3, x1 - 3, y1 - 3)
    layer.fill(inner, panel)
    layer.fill(layer.rect_mask(x0 + 1, y0 + 1, x1 - 1, y0 + 2), border[2])
    layer.outline(outline, b)
    ty = y0 + 6
    tx0 = x0 + 8
    for text in lines:
        stamp_text(layer, text, tx0, ty, text_rgb, scale=scale, bold=bold)
        ty += 9 * scale
    if icon:
        icon(layer)


def tree_icon(layer, cx, cy, rgb):
    for r, w in enumerate((1, 3, 5, 7, 3, 5, 7, 9)):
        layer.fill(layer.rect_mask(cx - w // 2, cy + r * 2, cx + w // 2 + 1,
                                   cy + r * 2 + 2), rgb)
    layer.fill(layer.rect_mask(cx - 1, cy + 16, cx + 2, cy + 22), rgb)


def bin_can(layer: Layer, cx, base_y, w, h, rmp, lid=None, outline=OUTLINE):
    """Slatted park bin."""
    body = layer.rect_mask(cx - w // 2, base_y - h, cx + w // 2, base_y)
    # cylinder banding: lit on the left
    cols = np.arange(layer.w) - layer.ox - (cx - w // 2)
    band = np.clip((cols / max(w, 1) * len(rmp)).astype(int), 0, len(rmp) - 1)
    order = [1, 3, 2, 2, 1, 0][:len(rmp)] if len(rmp) >= 4 else list(range(len(rmp)))
    img = np.zeros((layer.h, layer.w, 3), np.uint8)
    pal = np.array(rmp, np.uint8)
    img[:] = pal[np.clip(band, 0, len(rmp) - 1)][None, :, :]
    img[:] = pal[np.array([order[min(b, len(order) - 1)] for b in range(len(rmp))])][
        np.clip(band, 0, len(rmp) - 1)][None, :, :]
    layer.fill_where(body, img)
    for y in range(base_y - h + 5, base_y - 2, 5):              # slats
        layer.fill(layer.rect_mask(cx - w // 2, y, cx + w // 2, y + 1) & body,
                   rmp[0])
    lidm = layer.rect_mask(cx - w // 2 - 2, base_y - h - 4, cx + w // 2 + 2,
                           base_y - h + 1)
    layer.fill(lidm, lid or rmp[2])
    layer.fill(layer.rect_mask(cx - w // 2 - 2, base_y - h - 4, cx + w // 2 + 2,
                               base_y - h - 3), rmp[-1])
    layer.outline(outline, body | lidm)


def tree_line(layer: Layer, x0, x1, base_y, h_min, h_max, rmp, bark, seed=0,
              trunk_show=0.0, step=(28, 48)):
    """A row of rounded background trees."""
    rng = random.Random(seed)
    x = x0
    while x < x1:
        hgt = rng.uniform(h_min, h_max)
        wid = hgt * rng.uniform(0.75, 1.05)
        tree(layer, x, base_y, hgt, wid, rmp, bark, seed=rng.randint(0, 99999),
             trunk_w=max(3, int(wid * 0.07)),
             crown_frac=1.0 - trunk_show * rng.uniform(0.5, 1.0))
        x += rng.randint(*step)


# -- Water, houses, boards, flowers, small props ----------------------------------

def water(layer: Layer, x0, x1, y0, y1, rmp, sparkle, seed=0, reflect=None):
    """Lake band: horizontal ripple bands with sparkles; optional sun
    reflection column (cx, half_width, rgb)."""
    rng = np.random.default_rng(seed)
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = xx - layer.ox, yy - layer.oy
    m = (sx >= x0) & (sx < x1) & (sy >= y0) & (sy < y1)
    t = (sy - y0) / max(1, y1 - y0)
    n = fbm(H, W, 12, seed, 2)
    ripple = (np.sin(sx * 0.35 + n * 9 + sy * 1.7) > 0.6)
    v = np.clip(0.25 + t * 0.6 + (n - 0.5) * 0.3, 0, 0.999)
    img = np.array(rmp, np.uint8)[np.clip((v * len(rmp)).astype(int), 0,
                                           len(rmp) - 1)]
    layer.fill_where(m, img)
    rip = m & ripple & ((sy - y0) % 3 == 0)
    layer.fill(rip, rmp[-1])
    sp = m & (rng.random((H, W)) < 0.004) & ((sy - y0) % 2 == 0)
    layer.fill(sp | (np.roll(sp, 1, axis=1) & m), sparkle)
    if reflect is not None:
        cx, hw, rgb = reflect
        width = hw * (0.4 + t)
        col = m & (np.abs(sx - cx) < width) & ((sy - y0) % 2 == 0) & \
            (rng.random((H, W)) < 0.8)
        layer.fill(col, rgb)
    return m


def house(layer: Layer, x, base_y, w, h, wall, roof, outline=OUTLINE):
    body = layer.rect_mask(x, base_y - h, x + w, base_y)
    layer.fill(body, wall[1])
    layer.fill(layer.rect_mask(x, base_y - h, x + 2, base_y), wall[2])
    rf = layer.poly_mask([(x - 3, base_y - h), (x + w / 2, base_y - h - h * 0.7),
                          (x + w + 3, base_y - h)])
    layer.fill(rf, roof[1])
    layer.fill(rf & layer.rect_mask(x + w / 2, 0, x + w + 4, base_y), roof[0])
    for wx in range(x + 3, x + w - 3, 6):
        layer.fill(layer.rect_mask(wx, base_y - h + 3, wx + 2, base_y - h + 6),
                   wall[0])
    layer.outline(outline, body | rf)


def notice_board(layer: Layer, x0, y0, x1, y1, wood, poster, ink,
                 outline=OUTLINE):
    m = np.zeros((layer.h, layer.w), bool)
    for px in (x0 + 2, x1 - 6):
        leg = layer.rect_mask(px, y0, px + 5, y1 + 30)
        layer.fill(leg, wood[1])
        layer.fill(layer.rect_mask(px, y0, px + 1, y1 + 30), wood[2])
        m |= leg
    frame = layer.rect_mask(x0, y0 + 4, x1, y1)
    layer.fill(frame, wood[1])
    roof = layer.rect_mask(x0 - 4, y0, x1 + 4, y0 + 5)
    layer.fill(roof, wood[2])
    layer.fill(layer.rect_mask(x0 - 4, y0 + 4, x1 + 4, y0 + 5), wood[0])
    inner = layer.rect_mask(x0 + 5, y0 + 9, x1 - 5, y1 - 5)
    layer.fill(inner, poster)
    m |= frame | roof
    tree_icon(layer, (x0 + x1) // 2, y0 + 15, ink)
    layer.outline(outline, m)


def flowers(layer: Layer, x0, x1, base_y, h, leaf, petal, center, seed=0):
    rng = random.Random(seed)
    clumps = [(rng.uniform(x0, x1), base_y - rng.uniform(0.2, 0.8) * h,
               rng.uniform(5, 9)) for _ in range(int((x1 - x0) / 7))]
    clumps.sort(key=lambda c: c[1], reverse=True)
    foliage(layer, clumps, leaf, seed=seed)
    for _ in range(int((x1 - x0) / 5)):
        fx, fy = rng.uniform(x0, x1), base_y - rng.uniform(0.25, 1.0) * h
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            layer.px(fx + dx, fy + dy, petal)
        layer.px(fx, fy, center)


def towel_and_bag(layer: Layer, seat_x, seat_y, towel, bag, outline=OUTLINE):
    # folded towel on the seat
    t = layer.rect_mask(seat_x, seat_y - 14, seat_x + 9, seat_y)
    layer.fill(t, towel[1])
    layer.fill(layer.rect_mask(seat_x, seat_y - 14, seat_x + 9, seat_y - 12),
               towel[2])
    layer.fill(layer.rect_mask(seat_x + 3, seat_y - 14, seat_x + 4, seat_y),
               towel[0])
    layer.outline(outline, t)
    # sports bag on the ground in front of the bench
    bx, by = seat_x + 96, seat_y + 14
    b = layer.ellipse_mask(bx, by - 8, 12, 10)
    layer.fill(b, bag[1])
    layer.fill(b & layer.rect_mask(bx - 12, by - 18, bx - 3, by), bag[2])
    layer.fill(b & layer.rect_mask(bx + 5, by - 18, bx + 13, by), bag[0])
    layer.fill(layer.rect_mask(bx - 1, by - 18, bx + 1, by + 1) & b, bag[0])
    strap = layer.line_mask([(bx - 7, by - 15), (bx, by - 22), (bx + 7, by - 15)], 2)
    layer.fill(strap & ~b, bag[0])
    layer.outline(outline, b | strap)


def pavers(layer: Layer, x0, x1, y0, y1, rmp, seed=0):
    rng = random.Random(seed)
    base = layer.rect_mask(x0, y0, x1, y1)
    layer.fill(base, rmp[0])
    y = y0
    row = 0
    while y < y1:
        hgt = 14
        x = x0 - (row % 2) * 16
        while x < x1:
            w = 32
            st = layer.rect_mask(x + 1, y + 1, x + w, y + hgt) & base
            layer.fill(st, rmp[1 + rng.randint(0, 1)])
            layer.fill(layer.rect_mask(x + 1, y + 1, x + w, y + 2) & base, rmp[3])
            x += w
        y += hgt
        row += 1


def ball_icon(layer, cx, cy, r, ball, hole, outline=OUTLINE):
    m = layer.ellipse_mask(cx, cy, r, r)
    layer.fill(m, ball)
    for dx, dy in ((-2, -2), (2, -1), (-1, 2), (2, 3), (-3, 1)):
        layer.px(cx + dx, cy + dy, hole)
    layer.outline(outline, m)


# -- Fun venues (ADR-046): jungle, space, undersea --------------------------------

def stars(layer: Layer, y0, y1, density, cols, seed=0, twinkles=()):
    """Scattered 1 px stars, a few brighter crosses (twinkles: (x, y))."""
    rng = np.random.default_rng(seed)
    H, W = layer.h, layer.w
    ys = np.arange(H)[:, None] - layer.oy
    m = (rng.random((H, W)) < density) & (ys >= y0) & (ys < y1)
    pick = rng.integers(0, len(cols), (H, W))
    for i, c in enumerate(cols):
        layer.fill(m & (pick == i), c)
    for (x, y) in twinkles:
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
            layer.px(x + dx, y + dy, cols[-1])
        layer.px(x - 2, y, cols[0])
        layer.px(x + 2, y, cols[0])


def nebula(layer: Layer, y_mid, height, rmp, seed=0, slope=0.0):
    """A wispy diagonal band of dithered colour over the stars."""
    n = fbm(layer.h, layer.w, 24, seed, 3)
    ys = np.arange(layer.h)[:, None] - layer.oy
    xs = np.arange(layer.w)[None, :] - layer.ox
    d = np.abs(ys - (y_mid + xs * slope)) / height
    v = np.clip((n - 0.35) * 2.2 - d, 0, 0.999)
    m = v > 0.08
    from pix import dither_ramp
    img = dither_ramp(v, rmp, 1.0)
    layer.fill_where(m, img)


def planet(layer: Layer, cx, cy, r, rmp, bands=None, seed=0, land=None,
           ring=None, outline=OUTLINE):
    """A lit sphere: banded (gas giant) or with continents (land ramp);
    ring: (rx, ry, rmp) drawn behind and in front."""
    if ring is not None:
        rx, ry, rr = ring
        back = layer.ellipse_mask(cx, cy, rx, ry) & ~layer.ellipse_mask(cx, cy, rx - 4, ry - 2)
        layer.fill(back & layer.rect_mask(cx - rx - 1, cy - ry - 1, cx + rx + 2, cy), rr[0])
    m = layer.ellipse_mask(cx, cy, r, r)
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = (xx - layer.ox - cx) / r, (yy - layer.oy - cy) / r
    lit = np.clip(0.55 - 0.45 * (sx * 0.6 + sy * 0.8) - 0.25 * (sx * sx + sy * sy), 0, 0.999)
    img = np.array(rmp, np.uint8)[np.clip((lit * len(rmp)).astype(int), 0, len(rmp) - 1)]
    layer.fill_where(m, img)
    if bands is not None:
        for (y, h, c) in bands:
            b = m & layer.rect_mask(cx - r, cy + y, cx + r + 1, cy + y + h)
            layer.fill(b & (lit > 0.3), c[1])
            layer.fill(b & (lit <= 0.3), c[0])
    if land is not None:
        n = fbm(H, W, max(4, r // 3), seed, 3)
        lm = m & (n > 0.55)
        limg = np.array(land, np.uint8)[np.clip((lit * len(land)).astype(int), 0, len(land) - 1)]
        layer.fill_where(lm, limg)
        cl = m & (fbm(H, W, max(3, r // 5), seed + 9, 2) > 0.68)
        layer.fill(cl & (lit > 0.25), hexrgb("f4f8fa"))
        layer.fill(cl & (lit <= 0.25), hexrgb("a8b8c8"))
    if outline is not None:
        layer.outline(outline, m)
    if ring is not None:
        rx, ry, rr = ring
        front = layer.ellipse_mask(cx, cy, rx, ry) & ~layer.ellipse_mask(cx, cy, rx - 4, ry - 2)
        front &= layer.rect_mask(cx - rx - 1, cy, cx + rx + 2, cy + ry + 2)
        layer.fill(front, rr[1])
        layer.fill(front & layer.rect_mask(cx - rx - 1, cy, cx - rx // 3, cy + ry + 2), rr[2])
        layer.outline(outline, front)
    return m


def moon_ridge(layer: Layer, x0, x1, base, h_min, h_max, rmp, seed=0,
               craters=0.0, step=(24, 60)):
    """Jagged grey lunar hills (flat-topped mesas and craters)."""
    rng = random.Random(seed)
    pts = [(x0, base)]
    x = x0
    while x < x1:
        pts.append((x, base - rng.uniform(h_min, h_max)))
        x += rng.randint(*step)
        pts.append((x - rng.randint(2, 8), pts[-1][1]))
    pts += [(x1, base - h_min), (x1, base)]
    m = layer.poly_mask(pts)
    n = fbm(layer.h, layer.w, 8, seed, 2)
    ys = np.arange(layer.h)[:, None] - layer.oy
    v = np.clip(0.75 - (ys - (base - h_max)) / (h_max * 1.6) + (n - 0.5) * 0.4, 0, 0.999)
    layer.fill_where(m, np.array(rmp, np.uint8)[np.clip((v * len(rmp)).astype(int), 0,
                                                       len(rmp) - 1)])
    layer.fill(m & ~shift_(m, 0, 1), rmp[-1])
    r2 = random.Random(seed + 1)
    for _ in range(int((x1 - x0) * craters)):
        cx, cy = r2.uniform(x0, x1), r2.uniform(base - h_min + 2, base - 3)
        rw = r2.uniform(3, 9)
        c = layer.ellipse_mask(cx, cy, rw, rw * 0.35) & m
        layer.fill(c, rmp[0])
        layer.fill(c & layer.rect_mask(cx - rw, cy, cx + rw + 1, cy + rw), rmp[1])
    return m


def shift_(m, dx, dy):
    from pix import shift
    return shift(m, dx, dy)


def dome(layer: Layer, cx, base, rx, ry, glass, frame, glow, outline=OUTLINE):
    """A glass habitat dome: lattice ribs over a lit interior."""
    m = layer.ellipse_mask(cx, base, rx, ry) & layer.rect_mask(cx - rx, base - ry, cx + rx + 1, base)
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = xx - layer.ox, yy - layer.oy
    v = np.clip((base - sy) / ry, 0, 0.999)
    layer.fill_where(m, np.array(glass, np.uint8)[np.clip(((1 - v) * len(glass)).astype(int),
                                                         0, len(glass) - 1)])
    ribs = m & ((((sx - cx) % 9) == 0) | (((base - sy) % 7) == 0))
    layer.fill(ribs, frame)
    layer.fill(m & ~shift_(m, 2, 2) & ~ribs, glow)
    layer.outline(outline, m)
    layer.fill(layer.rect_mask(cx - rx - 2, base - 3, cx + rx + 3, base + 1), frame)


def rocket(layer: Layer, cx, base, h, body, trim, window, outline=OUTLINE):
    """A rocket on its pad, beside a lattice gantry."""
    w = max(8, h // 5)
    g = layer.rect_mask(cx + w, base - h - 6, cx + w + 6, base)
    lat = g & ~layer.rect_mask(cx + w + 1, base - h - 5, cx + w + 5, base)
    yy, xx = np.mgrid[0:layer.h, 0:layer.w]
    sx, sy = xx - layer.ox, yy - layer.oy
    lat |= g & (((sx + sy) % 6) == 0)
    layer.fill(lat, trim[0])
    m = layer.rect_mask(cx - w // 2, base - h + w, cx + w // 2 + 1, base - 4)
    nose = layer.poly_mask([(cx - w // 2, base - h + w), (cx, base - h - 2),
                            (cx + w // 2 + 1, base - h + w)])
    fins = layer.poly_mask([(cx - w // 2, base - 14), (cx - w // 2 - 6, base),
                            (cx - w // 2, base - 4)])
    fins |= layer.poly_mask([(cx + w // 2 + 1, base - 14), (cx + w // 2 + 7, base),
                             (cx + w // 2 + 1, base - 4)])
    from pix import solid
    solid(layer, m, body, None)
    solid(layer, nose | fins, trim, None, rim=1)
    layer.fill(layer.rect_mask(cx - w // 2, base - h // 2, cx + w // 2 + 1, base - h // 2 + 3),
               trim[1])
    win = layer.ellipse_mask(cx, base - h + w + 6, 2, 2)
    layer.fill(win, window)
    layer.outline(outline, m | nose | fins)


def lamp_post(layer: Layer, x, base, h, pole, head, light):
    layer.fill(layer.rect_mask(x - 1, base - h, x + 2, base), pole[1])
    layer.fill(layer.rect_mask(x - 1, base - h, x, base), pole[2])
    hd = layer.rect_mask(x - 7, base - h - 4, x + 8, base - h)
    layer.fill(hd, head)
    layer.fill(layer.rect_mask(x - 6, base - h, x + 7, base - h + 1), light)
    layer.outline(OUTLINE, hd | layer.rect_mask(x - 1, base - h, x + 2, base))


def palm(layer: Layer, x, base, h, lean, leaf, bark, seed=0, outline=OUTLINE):
    """A palm: a curved ringed trunk and a burst of drooping fronds."""
    rng = random.Random(seed)
    top = (x + lean, base - h)
    pts = [(x + lean * (t / 6) ** 2, base - h * t / 6) for t in range(7)]
    trunk = layer.line_mask(pts, 5)
    layer.fill(trunk, bark[1])
    for i in range(1, 12):
        t = i / 12
        px_ = x + lean * t * t
        layer.fill(layer.rect_mask(px_ - 2, base - h * t, px_ + 3, base - h * t + 1), bark[0])
    layer.fill(layer.line_mask([(p[0] - 2, p[1]) for p in pts], 1), bark[2])
    fr = np.zeros((layer.h, layer.w), bool)
    under = np.zeros_like(fr)
    for k in range(8):
        a = math.radians(-172 + k * 23 + rng.uniform(-6, 6))
        ln = h * rng.uniform(0.32, 0.42)
        dx, lift = math.cos(a), -math.sin(a)          # lift: 1 straight up
        spine = []
        for i in range(9):
            t = i / 8
            spine.append((top[0] + dx * ln * t,
                          top[1] - lift * ln * 0.45 * t + ln * 0.55 * t * t))
        wid = ln * 0.13
        left, right = [], []
        for i, (px_, py_) in enumerate(spine):
            t = i / 8
            w = wid * math.sin(math.pi * min(1, t * 1.15)) + 0.5
            left.append((px_, py_ - w))
            right.append((px_, py_ + w * 0.8))
        lm = layer.poly_mask(left + right[::-1])
        fr |= lm
        under |= lm & layer.poly_mask(spine + right[::-1])
    layer.fill(fr, leaf[1])
    layer.fill(under, leaf[0])
    layer.fill(fr & ~shift_(fr, 0, 1) & ~under, leaf[2])
    layer.outline(outline, fr)
    nuts = layer.ellipse_mask(top[0] - 2, top[1] + 3, 3, 2) | \
        layer.ellipse_mask(top[0] + 3, top[1] + 3, 3, 2)
    layer.fill(nuts, bark[0])


def volcano(layer: Layer, cx, base, w, h, rock, lava, seed=0, outline=OUTLINE):
    """A cone with a notched crater, lava streams, and a smoke plume."""
    rng = random.Random(seed)
    tw = w * 0.12
    m = layer.poly_mask([(cx - w / 2, base), (cx - tw, base - h), (cx - tw / 3, base - h + 4),
                         (cx + tw / 3, base - h + 2), (cx + tw, base - h), (cx + w / 2, base)])
    yy, xx = np.mgrid[0:layer.h, 0:layer.w]
    sx = xx - layer.ox
    v = np.clip(0.6 - (sx - cx) / w * 0.9 + (fbm(layer.h, layer.w, 6, seed, 2) - 0.5) * 0.4,
                0, 0.999)
    layer.fill_where(m, np.array(rock, np.uint8)[np.clip((v * len(rock)).astype(int), 0,
                                                        len(rock) - 1)])
    for k in range(4):
        x0 = cx + rng.uniform(-tw, tw)
        pts = [(x0, base - h + 2)]
        x, y = x0, base - h + 2
        dirn = rng.choice((-1, 1))
        while y < base - h * rng.uniform(0.05, 0.4):
            y += 4
            x += dirn * rng.uniform(0.5, 2.5) + rng.uniform(-1, 1)
            pts.append((x, y))
        st = layer.line_mask(pts, 2) & m
        layer.fill(st, lava[1])
        layer.fill(st & ~shift_(st, 1, 0), lava[2])
    layer.fill(m & layer.rect_mask(cx - tw, base - h, cx + tw + 1, base - h + 3), lava[2])
    layer.outline(outline, m)


def smoke(layer: Layer, x, y, h, rmp, seed=0):
    rng = random.Random(seed)
    cl = []
    for i in range(14):
        t = i / 13
        cl.append((x + t * h * 0.35 + rng.uniform(-4, 4), y - t * h, 5 + t * 12 + rng.uniform(0, 4)))
    foliage(layer, cl, rmp, seed=seed, scallop=True)


def fern_band(layer: Layer, x0, x1, base, h, leaf, seed=0):
    """Jungle undergrowth: big fern fans along a band."""
    rng = random.Random(seed)
    m = np.zeros((layer.h, layer.w), bool)
    x = x0
    while x < x1:
        hh = h * rng.uniform(0.6, 1.0)
        for k in range(5):
            a = math.radians(-160 + k * 35 + rng.uniform(-6, 6))
            tip = (x + math.cos(a) * hh, base + math.sin(a) * hh)
            m |= layer.line_mask([(x, base), ((x + tip[0]) / 2, (base + tip[1]) / 2 - 3), tip], 3)
        x += rng.randint(10, 18)
    layer.fill(m, leaf[1])
    layer.fill(m & ~shift_(m, 0, 2), leaf[2])
    layer.fill(m & ~shift_(m, 0, -2), leaf[0])
    return m


def palisade(layer: Layer, x0, x1, top, base, wood, rail, seed=0, outline=OUTLINE):
    """A wooden stake fence: pointed planks of slightly uneven height on
    two rails."""
    rng = random.Random(seed)
    x = x0
    m = np.zeros((layer.h, layer.w), bool)
    while x < x1:
        w = 7
        t = top + rng.randint(-2, 2)
        p = layer.poly_mask([(x, base), (x, t + 3), (x + w / 2, t), (x + w, t + 3), (x + w, base)])
        layer.fill(p, wood[1 + rng.randint(0, 1)])
        layer.fill(layer.rect_mask(x, t + 3, x + 1, base), wood[3])
        layer.fill(layer.rect_mask(x + w - 1, t + 3, x + w, base), wood[0])
        for _ in range(2):
            ky = rng.randint(int(t) + 8, base - 6)
            layer.px(x + rng.randint(2, 4), ky, wood[0])
        m |= p
        x += w
    for ry in (top + 10, base - 12):
        r = layer.rect_mask(x0, ry, x1, ry + 4)
        layer.fill(r, rail[1])
        layer.fill(layer.rect_mask(x0, ry, x1, ry + 1), rail[2])
        layer.fill(layer.rect_mask(x0, ry + 3, x1, ry + 4), rail[0])
    gaps = m & ~shift_(m, 1, 0)
    layer.fill(gaps, outline)


def water_sky(layer: Layer, stops, y0, y1, ray_rgb, seed=0):
    """Sunlit water: a gradient, slanted light shafts, a rippled surface."""
    sky_gradient(layer, stops, y0=y0, y1=y1)
    H, W = layer.h, layer.w
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = xx - layer.ox, yy - layer.oy
    rng = random.Random(seed)
    for _ in range(9):
        x = rng.uniform(-40, 1000)
        w = rng.uniform(10, 28)
        shaft = (np.abs(sx - x - (sy + 24) * 0.35) < w * (0.5 + (sy + 24) / 300)) & \
            (sy < y1 + 20) & ((sx + sy * 2) % 2 == 0)
        layer.fill(shaft & (layer.a[..., 3] > 0), ray_rgb)
    n = fbm(H, W, 10, seed, 2)
    rip = (sy < 6) & (np.sin(sx * 0.25 + n * 10) > 0.4) & ((sy % 3) == 0)
    layer.fill(rip, hexrgb("d8f4fc"))


def bubbles(layer: Layer, x0, x1, y0, y1, n, rgb, seed=0):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.choice((1, 1, 2, 2, 3))
        ring = layer.ellipse_mask(x, y, r, r) & ~layer.ellipse_mask(x, y, r - 1, r - 1) \
            if r > 1 else layer.rect_mask(x, y, x + 1, y + 1)
        layer.fill(ring, rgb)
        if r > 1:
            layer.px(x - r // 2, y - r // 2, hexrgb("ffffff"))


def shipwreck(layer: Layer, x, base, w, h, rmp, outline=None):
    """A sunken galleon in silhouette: a tilted hull, broken masts."""
    hull = layer.poly_mask([(x, base - h * 0.55), (x + w * 0.12, base), (x + w * 0.85, base + 4),
                            (x + w, base - h * 0.45), (x + w * 0.7, base - h * 0.4),
                            (x + w * 0.3, base - h * 0.5)])
    cabin = layer.rect_mask(x + w * 0.72, base - h * 0.62, x + w * 0.95, base - h * 0.4)
    mast = layer.line_mask([(x + w * 0.42, base - h * 0.45), (x + w * 0.46, base - h)], 3)
    mast |= layer.line_mask([(x + w * 0.62, base - h * 0.42), (x + w * 0.58, base - h * 0.8)], 3)
    mast |= layer.line_mask([(x + w * 0.36, base - h * 0.85), (x + w * 0.56, base - h * 0.88)], 2)
    m = hull | cabin | mast
    layer.fill(m, rmp[1])
    layer.fill(m & ~shift_(m, 1, 1), rmp[2])
    for k in range(4):
        layer.fill(layer.rect_mask(x + w * (0.25 + k * 0.13), base - h * 0.3,
                                   x + w * (0.25 + k * 0.13) + 3, base - h * 0.3 + 3) & hull,
                   rmp[0])
    layer.fill(hull & layer.rect_mask(x, base - h * 0.2, x + w, base - h * 0.17), rmp[0])
    if outline is not None:
        layer.outline(outline, m)
    return m


def kelp(layer: Layer, x, base, h, rmp, seed=0, sway=6):
    rng = random.Random(seed)
    pts = [(x + math.sin(t * 2.2 + seed) * sway * t, base - h * t) for t in
           np.linspace(0, 1, 9)]
    m = layer.line_mask(pts, 3)
    for i, (px_, py_) in enumerate(pts[1:-1]):
        side = 1 if i % 2 else -1
        m |= layer.poly_mask([(px_, py_), (px_ + side * rng.uniform(6, 10), py_ - 6),
                              (px_ + side * 2, py_ - 2)])
    layer.fill(m, rmp[1])
    layer.fill(m & ~shift_(m, 1, 0), rmp[2])
    layer.fill(m & ~shift_(m, -1, 0), rmp[0])
    return m


def coral_tubes(layer: Layer, x, base, rmp, seed=0, outline=OUTLINE):
    rng = random.Random(seed)
    m = np.zeros((layer.h, layer.w), bool)
    for k in range(rng.randint(3, 5)):
        tx = x + k * 5 + rng.randint(-1, 1)
        th = rng.randint(10, 24)
        m |= layer.rect_mask(tx, base - th, tx + 4, base)
    from pix import solid
    solid(layer, m, rmp, outline, rim=1)
    tops = m & ~shift_(m, 0, 1)
    layer.fill(tops, rmp[0])


def coral_fan(layer: Layer, x, base, w, h, rmp, seed=0):
    rng = random.Random(seed)
    m = np.zeros((layer.h, layer.w), bool)
    for k in range(9):
        a = math.radians(-160 + k * 17.5)
        tip = (x + math.cos(a) * w / 2, base + math.sin(a) * h)
        mid = (x + math.cos(a) * w / 4 + rng.uniform(-2, 2), base + math.sin(a) * h / 2)
        m |= layer.line_mask([(x, base), mid, tip], 2)
        m |= layer.line_mask([mid, (mid[0] + rng.uniform(-6, 6), mid[1] - rng.uniform(3, 8))], 1)
    layer.fill(m, rmp[1])
    layer.fill(m & ~shift_(m, 1, 1), rmp[2])
    return m


def brain_coral(layer: Layer, x, base, w, h, rmp, outline=OUTLINE):
    m = layer.ellipse_mask(x, base - h / 2, w / 2, h / 2) & layer.rect_mask(x - w, base - h - 1, x + w, base)
    from pix import solid
    solid(layer, m, rmp, outline, rim=2)
    yy, xx = np.mgrid[0:layer.h, 0:layer.w]
    sx, sy = xx - layer.ox, yy - layer.oy
    layer.fill(m & (np.sin(sx * 0.9 + np.sin(sy * 0.8) * 2) > 0.7), rmp[0])


def rope_fence(layer: Layer, x0, x1, top, base, posts, rope, wood, spacing=8,
               outline=OUTLINE):
    """Diamond rope netting on wooden posts, a rope along the top."""
    chain_link(layer, x0, top + 4, x1, base - 2, rope[0], spacing)
    yy, xx = np.mgrid[0:layer.h, 0:layer.w]
    sx, sy = xx - layer.ox, yy - layer.oy
    inside = (sx >= x0) & (sx < x1) & (sy >= top + 4) & (sy < base - 2)
    knots = inside & ((sx + sy) % spacing == 0) & ((sx - sy) % spacing == 0)
    layer.fill(knots | shift_(knots, 1, 0), rope[1])
    for ry in (top, base - 4):
        r = layer.line_mask([(x0, ry + 1), (x1, ry + 1)], 3)
        layer.fill(r, rope[1])
        layer.fill(r & ((sx + sy) % 4 < 2), rope[2])
    for px_ in posts:
        p = layer.rect_mask(px_ - 4, top - 6, px_ + 5, base + 1)
        layer.fill(p, wood[1])
        layer.fill(layer.rect_mask(px_ - 4, top - 6, px_ - 2, base + 1), wood[2])
        layer.fill(layer.rect_mask(px_ + 3, top - 6, px_ + 5, base + 1), wood[0])
        cap = layer.ellipse_mask(px_ + 0.5, top - 6, 4.5, 2)
        layer.fill(cap, wood[3])
        layer.outline(outline, p | cap)
