"""Court geometry, ground, recolourable court mask, and the net.

World court coordinates: u runs along the court's length (0 = left
baseline, 1 = right baseline, net at 0.5); v runs across it (0 = far
sideline, 1 = near sideline). The projection (ADR-011 style) keeps rows
linear and scales each row's width, so rules stay in (u, v) and only the
picture is projected.
"""
from __future__ import annotations

import numpy as np

from pix import Layer, edge_dist, fbm, grow

CX = 480
TOP_Y, BOT_Y = 222, 427          # far and near sidelines
TOP_HALF, BOT_HALF = 266, 315    # half the court's length on those rows
KITCHEN = 7 / 44                 # kitchen depth as a fraction of length
NET_H_FAR, NET_H_NEAR = 24, 45   # net tape height above the ground, px
LINE_W = 4

# Court mask roles (court_mask.png stores these ids in the red channel).
ROLE = {"none": 0, "surround": 1, "surround_shade": 2, "surface": 3,
        "surface_shade": 4, "kitchen": 5, "kitchen_shade": 6, "lines": 7,
        "lines_shade": 8}


def to_screen(u: float, v: float) -> tuple[float, float]:
    y = TOP_Y + v * (BOT_Y - TOP_Y)
    half = TOP_HALF + v * (BOT_HALF - TOP_HALF)
    return CX + (u - 0.5) * 2 * half, y


def scale_at(v: float) -> float:
    """Sprite scale at depth v (1.0 on the near sideline)."""
    return (TOP_HALF + v * (BOT_HALF - TOP_HALF)) / BOT_HALF


def quad(u0, v0, u1, v1):
    return [to_screen(u0, v0), to_screen(u1, v0), to_screen(u1, v1),
            to_screen(u0, v1)]


def geometry() -> dict:
    """Everything an engine needs to place things on the court."""
    k0, k1 = 0.5 - KITCHEN, 0.5 + KITCHEN
    return {
        "projection": {
            "comment": "u 0..1 along the court (net 0.5), v 0..1 far to near "
                       "sideline. y = top_y + v*(bottom_y-top_y); half = "
                       "top_half + v*(bottom_half-top_half); x = center_x + "
                       "(u-0.5)*2*half. Sprite scale at v = half/bottom_half "
                       "(optional; the mocks don't scale).",
            "center_x": CX, "top_y": TOP_Y, "bottom_y": BOT_Y,
            "top_half": TOP_HALF, "bottom_half": BOT_HALF,
        },
        "corners": {"far_left": to_screen(0, 0), "far_right": to_screen(1, 0),
                    "near_left": to_screen(0, 1), "near_right": to_screen(1, 1)},
        "kitchen_u": [k0, k1],
        "center_line_v": 0.5,
        "net": {"u": 0.5, "far_ground": to_screen(0.5, 0),
                "near_ground": to_screen(0.5, 1),
                "tape_height_far": NET_H_FAR, "tape_height_near": NET_H_NEAR},
        "real_size_ft": [44, 20],
    }


def court_mask(layer_shape, ox, oy, ground_top) -> np.ndarray:
    """Role ids (H, W) uint8 for the whole ground band."""
    L = Layer(layer_shape[1], layer_shape[0], ox, oy)
    roles = np.zeros((L.h, L.w), np.uint8)
    roles[L.rect_mask(-ox, ground_top, L.w, L.h)] = ROLE["surround"]
    roles[L.poly_mask(quad(0, 0, 1, 1))] = ROLE["surface"]
    k0, k1 = 0.5 - KITCHEN, 0.5 + KITCHEN
    roles[L.poly_mask(quad(k0, 0, k1, 1))] = ROLE["kitchen"]
    # net shadow on the kitchen, to the right of the net
    sh = L.poly_mask([to_screen(0.5, 0), (to_screen(0.5, 0)[0] + 7, TOP_Y),
                      (to_screen(0.5, 1)[0] + 12, BOT_Y), to_screen(0.5, 1)])
    roles[sh & (roles == ROLE["kitchen"])] = ROLE["kitchen_shade"]
    # lines: outer boundary, kitchen lines, centre service lines
    lines = np.zeros_like(roles, bool)
    w = LINE_W
    for (a, b) in [((0, 0), (1, 0)), ((0, 1), (1, 1)), ((0, 0), (0, 1)),
                   ((1, 0), (1, 1)), ((k0, 0), (k0, 1)), ((k1, 0), (k1, 1)),
                   ((0, 0.5), (k0, 0.5)), ((k1, 0.5), (1, 0.5))]:
        p0, p1 = to_screen(*a), to_screen(*b)
        lines |= L.line_mask([p0, p1], width=w if a[1] == b[1] else w - 1)
    roles[lines] = ROLE["lines"]
    # a pixel of shade on the lines' lower edge, so they read as painted
    below = np.zeros_like(lines)
    below[1:] = lines[:-1]
    roles[below & ~lines & (roles != ROLE["surround"])] = roles[
        below & ~lines & (roles != ROLE["surround"])]
    low = lines & ~np.vstack([lines[1:], np.zeros((1, lines.shape[1]), bool)])
    roles[low] = ROLE["lines_shade"]
    return roles


def paint_ground(layer: Layer, roles: np.ndarray, colors: dict, seed=0,
                 speckle=None, surround_noise=0.18):
    """Bake the default colours. colors: role name -> ramp (dark..light)."""
    H, W = roles.shape
    n = fbm(H, W, 10, seed, 3)
    fine = fbm(H, W, 2, seed + 50, 1)
    out = np.zeros((H, W, 3), np.uint8)
    for name, rid in ROLE.items():
        if rid == 0 or name not in colors:
            continue
        m = roles == rid
        r = np.array(colors[name], np.uint8)
        if name == "surround":
            v = np.clip(0.5 + (n - 0.5) * 0.35 + (fine - 0.5) * surround_noise,
                        0, 0.999)
            idx = np.clip((v * len(r)).astype(int), 0, len(r) - 1)
            out[m] = r[idx][m]
        elif name in ("surface", "kitchen"):
            v = np.clip(0.55 + (n - 0.5) * 0.12, 0, 0.999)
            idx = np.clip((v * len(r)).astype(int), 0, len(r) - 1)
            out[m] = r[idx][m]
        else:
            out[m] = r[len(r) // 2]
    layer.fill_where(roles > 0, out)
    if speckle is not None:
        rng = np.random.default_rng(seed + 3)
        sp = (rng.random((H, W)) < speckle[0]) & (roles == ROLE["surround"])
        sp2 = grow(sp) & (rng.random((H, W)) < 0.5) & (roles == ROLE["surround"])
        layer.fill(sp | sp2, speckle[1])


def net(layer: Layer, tape=(236, 238, 230), mesh=(26, 30, 34),
        post=((14, 16, 22), (52, 58, 70), (104, 112, 128))):
    """The net along u = 0.5: mesh, tape, far post. Near post is separate."""
    x = CX
    far_top, near_top = TOP_Y - NET_H_FAR, BOT_Y - NET_H_NEAR
    # mesh: a slanted strip left of the tape, checker of wire
    yy, xx = np.mgrid[0:layer.h, 0:layer.w]
    sx, sy = xx - layer.ox, yy - layer.oy
    t = (sy - TOP_Y) / (BOT_Y - TOP_Y)
    top = far_top + t * (near_top - far_top)
    width = 7 + t * 9
    in_mesh = (sy >= far_top) & (sy <= BOT_Y) & (sx < x) & (sx >= x - width) \
        & (sy >= top) & (sy <= TOP_Y + t * (BOT_Y - TOP_Y) + 1)
    wire = ((sx + sy) % 3 == 0) | ((sx - sy) % 3 == 0) | ((sx - x) == -1)
    layer.fill(in_mesh & wire, mesh)
    # lower edge band (the net's bottom cord) and the tape
    tape_m = layer.line_mask([(x, far_top), (x, near_top)], width=3)
    layer.fill(tape_m, tape)
    layer.fill(layer.line_mask([(x + 1, far_top), (x + 1, near_top)], 1),
               (180, 186, 180))
    # far post
    fp = layer.rect_mask(x - 2, far_top - 4, x + 3, TOP_Y + 1)
    layer.fill(fp, post[1])
    layer.fill(layer.rect_mask(x - 2, far_top - 4, x - 1, TOP_Y + 1), post[2])
    layer.fill(layer.rect_mask(x + 2, far_top - 4, x + 3, TOP_Y + 1), post[0])
    layer.fill(layer.rect_mask(x - 3, far_top - 6, x + 4, far_top - 3), post[1])
    layer.outline(post[0], fp | layer.rect_mask(x - 3, far_top - 6, x + 4, far_top - 3))


def near_post(post=((14, 16, 22), (52, 58, 70), (104, 112, 128))) -> Layer:
    """Near net post as its own sprite (y-sorted with players). Anchor at
    the bottom centre = to_screen(0.5, 1)."""
    w, h = 16, NET_H_NEAR + 16
    L = Layer(w, h, 0, 0)
    cx = w // 2
    body = L.rect_mask(cx - 3, 4, cx + 4, h - 3)
    L.fill(body, post[1])
    L.fill(L.rect_mask(cx - 3, 4, cx - 1, h - 3), post[2])
    L.fill(L.rect_mask(cx + 2, 4, cx + 4, h - 3), post[0])
    cap = L.rect_mask(cx - 4, 1, cx + 5, 5)
    L.fill(cap, post[2])
    foot = L.rect_mask(cx - 5, h - 5, cx + 6, h - 1)
    L.fill(foot, post[0])
    L.outline(post[0], body | cap | foot)
    return L
