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
