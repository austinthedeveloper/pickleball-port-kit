"""The open-play park (ADR-034), redrawn for the HD port: a 3/4 view from
about a second storey, closer in than the SNES's whole-park screen.

The park's plan comes from the sim (game/sim/open_play.gd constants,
copied below): 512 x 224 park pixels. The world is that plan scaled 4x
across and 3x down (the foreshortening that tilts the view), with margins
for trees and the clubhouse's walls. Upright things (fences, nets, walls,
trees, benches, racks, lamps) are separate sprites, anchored at their
foot, so the game sorts them with the people by depth; the roof and the
clubhouse's front wall fade when you're inside.

Pixel art with the venue kit (art/levels/tools/pix.py): hard edges,
named ramps, banded light from the upper left, 1 px outlines.

    .venv/bin/python art/park/build_park.py      # writes art/park/out/
    .venv/bin/python art/park/build_park.py dino # DINO PARK: art/park/out/dino/
    .venv/bin/python art/park/build_park.py gym  # THE GYM: art/park/out/gym/
    then copy art/park/out/* to game/assets/park/ (game/tools/sync_assets.sh)

Every location (ADR-078) is the same plan (the sim's: courts, racks, the
clubhouse, where you can walk) in its own art: THEME picks the palettes
and the decor; the park's own is the default and builds as it always has.
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

KIT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(KIT / "art/levels/tools"))
from pix import (Layer, bush, chain_link, dither_ramp, fbm, foliage, grow,  # noqa: E402
                 hexrgb, ramp, ramp_img, stamp_text, tree, value_noise)
import critters as CR  # noqa: E402
import scenery as SC  # noqa: E402

THEME = next((a for a in sys.argv[1:] if not a.startswith("-")), "park")
OUT = Path(__file__).resolve().parent / "out" / ("" if THEME == "park" else THEME)

# --- the plan (open_play.gd) --------------------------------------------------------
PARK_W, PARK_H = 512, 224
COURTS, COURT_W, COURT_H, COURT_TOP, COURT_LEFT0, COURT_PITCH = 3, 56, 112, 48, 20, 80
RACK_Y = COURT_TOP + COURT_H + 10
FENCE_MARGIN = 4
HOUSE = (296, 40, 488, 168)          # left, top, right, bottom
HOUSE_WALL = 6
DOOR_X, DOOR_W = 392, 28
BOARD_X, BOARD_Y = 336, 64
MACHINE_X, MACHINE_Y = 452, 84
BENCH_X, BENCH_Y = 344, 132
WALK = (178, 214)                    # the walkway's top and bottom

# --- the projection -------------------------------------------------------------------
SX, SY = 4, 3                        # world px per park px, across and down
MX, MT, MB = 24, 40, 26              # margins (park px): sides, top, bottom
WORLD_W = (PARK_W + 2 * MX) * SX
WORLD_H = (PARK_H + MT + MB) * SY
H_SCALE = 4                          # world px per park px of height
FENCE_H = 64                         # a fence, a bit taller than a person (~62)
WALL_H = 104
NET_H = 22


def wx(x):
    return (x + MX) * SX


def wy(y):
    return (y + MT) * SY


# --- palette ---------------------------------------------------------------------------
OUTLINE = hexrgb("0b1626")
GRASS = ramp("356b2a", "3f7a31", "4a8a38", "56993f", "63a849")
GRASS_STRIPE = ramp("3a7230", "45823a", "4f9140", "5ba147", "68b04f")
PATH = ramp("9d9488", "b3aa9c", "c4bcae", "d2cbbe", "ded8cc")
CURB = ramp("7d766c", "958d81", "aaa294")
SURFACE = ramp("2c5c9e", "335fa5", "3a68ae", "4071b6")
KITCHEN = ramp("3a72b8", "4279c0", "4a82c7", "528bce")
LINE = hexrgb("f2f3ef")
APRONS = [ramp("1f7d77", "268a83", "2e978f", "35a39b"),
          ramp("b5862a", "c29331", "cf9f39", "d9ab44"),
          ramp("a13a32", "ae4238", "bb4a3f", "c65447")]
POST = ramp("272d32", "3a4249", "56606a", "77828c")
MESH = hexrgb("2a3238")
LEAF = ramp("1e4a22", "2b5e2b", "3a7534", "4b8c3e", "62a64c")
LEAF2 = ramp("24502a", "336633", "437d3a", "579445", "70ad55")
BARK = ramp("3b2618", "533722", "6c4a2e", "84603d")
SIDING = ramp("6e4527", "835331", "98633c", "ab7448")
TRIM = ramp("c9c2b2", "e3ddcf", "f4f0e6")
ROOF = ramp("5c2a24", "73352c", "8a4236", "a0503f", "b55f4a")
FLOOR = ramp("9b7146", "ad8052", "be905e", "cc9e6a")
WOOD = ramp("5e3c20", "7a5130", "966740", "ad7c50")
METAL = ramp("4a5058", "6a727c", "8c96a0", "b0b8c0")
SHADOW = (8, 20, 12)
BG = "356b2a"                          # the view's colour past the world's edge

# ADR-078: the other locations' palettes over the park's (the same plan)
THEMES = {
    "park": {},
    # DINO PARK: a lusher jungle lawn, sandy paths, a bamboo ranger hut
    # under thatch
    "dino": {
        "GRASS": ramp("2a5520", "336426", "3e742c", "4a8532", "58963a"),
        "GRASS_STRIPE": ramp("2e5a24", "386a2a", "437a30", "4f8b36", "5d9c3e"),
        "PATH": ramp("94744a", "a98654", "bc9862", "cba872", "d8b682"),
        "CURB": ramp("6a5234", "82643c", "987648"),
        "SIDING": ramp("86662a", "9c7a32", "b4903c", "c8a448"),
        "TRIM": ramp("4a3420", "6a4a2c", "8a6438"),
        "ROOF": ramp("664a1c", "806024", "9a762c", "b28c38", "c8a046"),
        "BG": "2a5520",
    },
    # THE GYM: a maple floor everywhere, painted courts, a rubber walkway,
    # divider nets, a painted-block office under the ceiling
    "gym": {
        "PATH": ramp("2c323e", "343b48", "3c4452", "444d5c", "4c5666"),
        "CURB": ramp("1c212a", "242a34", "2c333e"),
        "SURFACE": ramp("bf8650", "cb9258", "d59e62", "dfa96e"),
        "KITCHEN": ramp("2e7868", "348272", "3a8c7c", "409686"),
        "MESH": hexrgb("15181c"),
        "POST": ramp("101215", "1c2026", "2a3038", "3a424c"),
        "SIDING": ramp("8894a4", "98a4b4", "a8b4c2", "b8c4d0"),
        "TRIM": ramp("c6cad0", "dee2e6", "f0f2f4"),
        "ROOF": ramp("585e6c", "666c7a", "767c8a", "868c9a", "969caa"),
        "BG": "b07a44",
    },
}
MAPLE = ramp("ad7742", "bd8650", "cb945c", "d8a26a", "e2ae78")
globals().update(THEMES[THEME])


def shadow(layer: Layer, m, strength=90):
    """Darken the ground under mask m (baked, soft-edged by a grow)."""
    a = layer.a
    for k, s in [(m, strength), (grow(m) & ~m, strength * 0.55)]:
        rgb = a[k, :3].astype(float)
        a[k, :3] = (rgb * (1 - s / 255) + np.array(SHADOW) * (s / 255)).astype(np.uint8)


# --- the ground -----------------------------------------------------------------------

def ground() -> Layer:
    L = Layer(WORLD_W, WORLD_H, 0, 0)
    H, W = WORLD_H, WORLD_W
    if THEME == "gym":
        gym_floor(L)
    else:
        # grass: noise in bands, with wide mowing stripes
        n = fbm(H, W, 48, seed=11, octaves=4) * 0.75 + value_noise(H, W, 6, seed=12) * 0.25
        stripes = ((np.arange(W) // 96) % 2 == 0)[None, :].repeat(H, 0)
        g = dither_ramp(np.clip(n, 0, 0.999), GRASS, 0.9)
        gs = dither_ramp(np.clip(n, 0, 0.999), GRASS_STRIPE, 0.9)
        img = np.where(stripes[..., None], gs, g)
        L.fill_where(np.ones((H, W), bool), img)
        # tufts and clover
        rng = random.Random(3)
        for _ in range(2600):
            x, y = rng.randrange(W), rng.randrange(H)
            L.px(x, y, GRASS[0])
            L.px(x + 1, y - 1, GRASS[4])
    # the walkway: pale concrete with seams and curbs, plus spurs to each
    # court's gate and the clubhouse door
    walk = L.rect_mask(0, wy(WALK[0]), W, wy(WALK[1]))
    for c in range(COURTS):
        gx = wx(court_left(c) + COURT_W // 2)
        walk |= L.rect_mask(gx - 40, wy(COURT_TOP + COURT_H + FENCE_MARGIN), gx + 40, wy(WALK[0]) + 2)
    walk |= L.rect_mask(wx(DOOR_X) - 60, wy(HOUSE[3]) - 2, wx(DOOR_X) + 60, wy(WALK[0]) + 2)
    pn = value_noise(H, W, 3, seed=21) * 0.5 + fbm(H, W, 40, seed=22) * 0.5
    L.fill_where(walk, dither_ramp(np.clip(pn * 0.8 + 0.15, 0, 0.999), PATH, 0.7))
    seams = walk & ((np.arange(W) % 64 == 0)[None, :] | (np.arange(H) % 48 == 0)[:, None])
    L.fill(seams, PATH[1])
    edge = grow(walk) & ~walk
    L.fill(edge, CURB[0])
    L.fill(grow(edge) & ~edge & ~walk, CURB[1])
    if THEME == "dino":
        footprints(L, walk)
    # the courts
    for c in range(COURTS):
        court_ground(L, c)
    # the clubhouse floor
    house_floor(L)
    return L


def gym_floor(L: Layer):
    """THE GYM: maple boards running across, staggered joints, a painted
    boundary line, and pools of light from the ceiling's lamps."""
    H, W = L.h, L.w
    n = value_noise(H, W, 5, seed=13) * 0.5 + fbm(H, W, 30, seed=14, octaves=2) * 0.3
    board = (np.arange(H) // 10)[:, None]
    grain = ((board * 7919) % 5) / 5.0 * 0.18
    L.fill_where(np.ones((H, W), bool), dither_ramp(np.clip(n + grain + 0.1, 0, 0.999), MAPLE, 0.6))
    L.fill(np.ones((H, W), bool) & ((np.arange(H) % 10) == 0)[:, None], MAPLE[0])
    yy, xx = np.mgrid[0:H, 0:W]
    joints = ((xx + (yy // 10) * 97) % 230 == 0)
    L.fill(joints, MAPLE[0])
    # the gym's boundary paint, inside the walls
    edge = L.rect_mask(14, wy(16), W - 14, H - 12) & ~L.rect_mask(18, wy(16) + 4, W - 18, H - 16)
    L.fill(edge, hexrgb("1e3a6e"))
    # light from the ceiling: soft brighter pools
    for c in range(COURTS + 1):
        cx = wx(court_left(c) - 12) if c < COURTS else wx(PARK_W - 20)
        pool = L.ellipse_mask(cx, wy(104), 150, 110)
        rgb = L.a[pool, :3].astype(int)
        L.a[pool, :3] = np.clip(rgb + 10, 0, 255).astype(np.uint8)


def footprints(L: Layer, walk):
    """DINO PARK: a big three-toed trail along the walkway."""
    ink = PATH[0]
    for k, x in enumerate(range(40, WORLD_W - 40, 170)):
        cx = x + (0 if k % 2 else 60)
        cy = wy(WALK[0]) + (30 if k % 2 else 64)
        pad = L.ellipse_mask(cx, cy, 14, 10)
        for dx, dy in ((-16, -18), (0, -24), (16, -18)):
            pad |= L.poly_mask([(cx + dx * 0.4, cy - 6), (cx + dx - 4, cy + dy), (cx + dx + 4, cy + dy)])
        L.fill(pad & walk, ink)


def court_left(c):
    return COURT_LEFT0 + COURT_PITCH * c


def court_ground(L: Layer, c):
    left = court_left(c)
    top, w, h = COURT_TOP, COURT_W, COURT_H
    apron = L.rect_mask(wx(left - 7), wy(top - 9), wx(left + w + 7), wy(top + h + 9))
    an = fbm(L.h, L.w, 10, seed=40 + c, octaves=2)
    L.fill_where(apron, dither_ramp(an * 0.5 + 0.35, APRONS[c], 0.6))
    surf = L.rect_mask(wx(left), wy(top), wx(left + w), wy(top + h))
    L.fill_where(surf, dither_ramp(an * 0.4 + 0.4, SURFACE, 0.5))
    net = top + h // 2
    kit = L.rect_mask(wx(left), wy(net - 14), wx(left + w), wy(net + 14))
    L.fill_where(kit, dither_ramp(an * 0.4 + 0.4, KITCHEN, 0.5))
    lw = 3
    for (x0, y0, x1, y1) in [(left, top, left + w, top), (left, top + h, left + w, top + h),
                             (left, top, left, top + h), (left + w, top, left + w, top + h),
                             (left, net - 14, left + w, net - 14), (left, net + 14, left + w, net + 14),
                             (left + w / 2, top, left + w / 2, net - 14),
                             (left + w / 2, net + 14, left + w / 2, top + h)]:
        L.fill(L.rect_mask(wx(x0) - lw // 2, wy(y0) - 1, wx(x1) + lw - lw // 2, wy(y1) + 2), LINE)
    # the net's shadow on the court (the light is up and to the left)
    shadow(L, L.rect_mask(wx(left), wy(net) + 2, wx(left + w) + 12, wy(net) + 10), 70)
    # the fence's shadow, to the right and below its posts
    m = FENCE_MARGIN - 1
    shadow(L, L.rect_mask(wx(left + w + m), wy(top - m), wx(left + w + m) + 14, wy(top + h + m)), 55)


def house_floor(L: Layer):
    x0, y0, x1, y1 = HOUSE
    inner = L.rect_mask(wx(x0 + HOUSE_WALL), wy(y0 + HOUSE_WALL), wx(x1 - HOUSE_WALL), wy(y1 - HOUSE_WALL))
    n = value_noise(L.h, L.w, 4, seed=50) * 0.4 + 0.3
    planks = ((np.arange(L.h) // 12) % 2)[:, None] * 0.12
    L.fill_where(inner, dither_ramp(np.clip(n + planks, 0, 0.999), FLOOR, 0.5))
    joints = inner & ((np.arange(L.h) % 12) == 0)[:, None]
    L.fill(joints, FLOOR[0])
    # a rug in the middle, a doormat at the door
    rug = L.rect_mask(wx(378), wy(84), wx(426), wy(110))
    L.fill(rug, hexrgb("8e3634"))
    L.fill(L.rect_mask(wx(381), wy(86), wx(423), wy(108)) & ~L.rect_mask(wx(383), wy(87), wx(421), wy(107)),
           hexrgb("c8a25a"))
    L.fill(L.rect_mask(wx(DOOR_X) - 40, wy(y1 - HOUSE_WALL) - 18, wx(DOOR_X) + 40, wy(y1 - HOUSE_WALL)),
           hexrgb("5a4a3a"))
    # the house's shadow on the grass: right and below
    shadow(L, L.rect_mask(wx(x1), wy(y0) - WALL_H // 2, wx(x1) + 26, wy(y1) + 10), 80)
    shadow(L, L.rect_mask(wx(x0) + 20, wy(y1), wx(x1) + 26, wy(y1) + 14), 60)
    # the doorway through the front wall's footprint
    L.fill(L.rect_mask(wx(DOOR_X - DOOR_W // 2), wy(y1 - HOUSE_WALL), wx(DOOR_X + DOOR_W // 2), wy(y1) + 2),
           FLOOR[2])


# --- sprites ----------------------------------------------------------------------------

SPRITES = []                          # [{file, x, y, sort, ...}]


def save_sprite(name, layer: Layer, ax, ay, place_x, place_y, sort=None, **extra):
    """Crop to content and record where it goes: the sprite's (ax, ay)
    pixel lands on world (place_x, place_y); `sort` is its depth (world y)."""
    a = layer.a
    on = a[..., 3] > 0
    if not on.any():
        return
    ys, xs = np.nonzero(on)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    img = Image.fromarray(a[y0:y1, x0:x1])
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png", optimize=True)
    SPRITES.append({"file": f"{name}.png", "x": int(place_x - (ax - x0)), "y": int(place_y - (ay - y0)),
                    "sort": int(place_y if sort is None else sort), **extra})


def fence_panel(width, height=FENCE_H, posts=48, gate=None):
    """A chain-link fence seen square-on: posts, top rail, mesh. `gate`:
    (x0, x1) left open."""
    L = Layer(width + 8, height + 8, 4, 4)
    mesh_on = np.ones((L.h, L.w), bool)
    if gate:
        mesh_on &= ~L.rect_mask(gate[0], -10, gate[1], height + 10)
    m = chain_link(L, 0, 6, width, height, MESH, spacing=7, alpha=210)
    L.a[m & ~mesh_on] = 0
    for x in list(range(0, width + 1, posts)) + [width] + ([gate[0], gate[1]] if gate else []):
        L.fill(L.rect_mask(x - 2, 0, x + 2, height), POST[1])
        L.fill(L.rect_mask(x - 2, 0, x - 1, height), POST[3])
        L.fill(L.rect_mask(x - 3, -2, x + 3, 1), POST[2])
    rail = L.rect_mask(0, 2, width, 6) & mesh_on
    L.fill(rail, POST[2])
    L.fill(L.rect_mask(0, 2, width, 3) & mesh_on, POST[3])
    L.fill(L.rect_mask(0, height - 2, width, height) & mesh_on, POST[1])
    return L


def side_fence(length_px, height=FENCE_H):
    """A fence running into the picture: we see its posts stacked along
    the plan's y, each `height` tall, joined by the mesh's edge. Drawn as
    one tall strip; the game cuts it into depth-sorted slices."""
    L = Layer(10, length_px + height + 4, 3, height + 2)
    m = L.rect_mask(-1, -height, 2, length_px)
    L.fill(m, MESH, 200)
    for py in range(0, length_px + 1, 36):
        L.fill(L.rect_mask(-2, py - height, 3, py), POST[1])
        L.fill(L.rect_mask(-2, py - height, -1, py), POST[3])
    L.fill(L.rect_mask(-2, -height - 1, 3, length_px - height + 3), POST[2])
    return L


def net_sprite(width):
    L = Layer(width + 24, NET_H + 10, 12, NET_H + 4)
    chain_link(L, 0, -NET_H + 3, width, -2, hexrgb("1a1f24"), spacing=4)
    L.fill(L.rect_mask(0, -NET_H, width, -NET_H + 4), hexrgb("f0f0ec"))     # the tape
    for x in (-6, width + 4):
        L.fill(L.rect_mask(x - 2, -NET_H - 4, x + 3, 1), METAL[1])
        L.fill(L.rect_mask(x - 2, -NET_H - 4, x - 1, 1), METAL[3])
    return L


def rack_sprite():
    """The paddle rack at a court's gate: a frame with slots (the game
    draws the waiting paddles in it)."""
    L = Layer(80, 60, 40, 56)
    for x in (-34, 32):
        L.fill(L.rect_mask(x, -44, x + 4, 0), METAL[1])
        L.fill(L.rect_mask(x, -44, x + 1, 0), METAL[3])
    L.fill(L.rect_mask(-36, -48, 38, -42), METAL[2])
    L.fill(L.rect_mask(-36, -48, 38, -47), METAL[3])
    L.fill(L.rect_mask(-36, -14, 38, -10), METAL[1])
    L.outline(OUTLINE)
    return L


def bench_sprite(width):
    L = Layer(width + 10, 50, 5, 44)
    L.fill(L.rect_mask(0, -30, width, -22), WOOD[2])      # back rest
    L.fill(L.rect_mask(0, -30, width, -28), WOOD[3])
    L.fill(L.rect_mask(0, -16, width, -8), WOOD[2])       # seat
    L.fill(L.rect_mask(0, -16, width, -14), WOOD[3])
    L.fill(L.rect_mask(0, -9, width, -8), WOOD[0])
    for x in (6, width - 10):
        L.fill(L.rect_mask(x, -30, x + 4, 0), METAL[0])
    L.outline(OUTLINE)
    return L


def lamp_sprite():
    L = Layer(30, 130, 15, 126)
    L.fill(L.rect_mask(-2, -110, 2, 0), POST[1])
    L.fill(L.rect_mask(-2, -110, -1, 0), POST[3])
    L.fill(L.rect_mask(-6, -4, 6, 0), POST[0])
    L.fill(L.ellipse_mask(0, -116, 9, 8), hexrgb("2a3036"))
    L.fill(L.ellipse_mask(0, -114, 6, 4), hexrgb("f4e7a6"))
    L.outline(OUTLINE)
    return L


def tree_sprite(seed, height, width):
    L = Layer(int(width * 1.3), height + 10, int(width * 0.65), height + 4)
    tree(L, 0, 0, height, width, LEAF if seed % 2 else LEAF2, BARK, seed=seed, trunk_w=12,
         outline=OUTLINE)
    return L


def bush_sprite(seed, w, h):
    L = Layer(w + 16, h + 10, w // 2 + 8, h + 4)
    bush(L, 0, 0, w, h, LEAF2 if seed % 2 else LEAF, seed=seed, outline=OUTLINE)
    return L


def flowerbed(L: Layer, x0, x1, y0, y1, seed):
    rng = random.Random(seed)
    bed = L.rect_mask(x0, y0, x1, y1)
    L.fill(bed, hexrgb("5a3e2a"))
    L.fill(grow(bed) & ~bed, hexrgb("3e2a1c"))
    for _ in range(int((x1 - x0) * (y1 - y0) / 18)):
        x, y = rng.uniform(x0 + 2, x1 - 3), rng.uniform(y0 + 2, y1 - 3)
        L.px(x, y + 1, LEAF[2])
        col = rng.choice([hexrgb("f2d24a"), hexrgb("e85a6a"), hexrgb("f4f0e6"), hexrgb("b07ae0")])
        L.px(x, y, col)
        L.px(x + 1, y, col)


def house_sprites():
    x0, y0, x1, y1 = HOUSE
    t = HOUSE_WALL
    W = wx(x1) - wx(x0)
    # the back wall: its inner face (we see it from the front, inside)
    L = Layer(W, WALL_H + 30, 0, WALL_H + 20)
    face = L.rect_mask(0, -WALL_H, W, 0)
    rows = ((np.arange(L.h) // 10) % 2)[:, None] * 0.15
    L.fill_where(face, ramp_img(np.clip(value_noise(L.h, L.w, 5, 60) * 0.4 + 0.35 + rows, 0, 0.999),
                                [hexrgb("d9cbb0"), hexrgb("e6dac2"), hexrgb("efe6d2")]))
    L.fill(L.rect_mask(0, -14, W, 0), WOOD[1])              # skirting
    # the records board, windows
    bx = wx(BOARD_X) - wx(x0)
    L.fill(L.rect_mask(bx - 58, -84, bx + 58, -26), WOOD[0])
    L.fill(L.rect_mask(bx - 54, -80, bx + 54, -30), hexrgb("2c4434"))
    for i in range(5):
        L.fill(L.rect_mask(bx - 46, -72 + i * 9, bx - 46 + 40 + (i * 23) % 50, -70 + i * 9), hexrgb("d8e4d0"))
    for wxp in (W * 0.42, W * 0.62):
        L.fill(L.rect_mask(wxp - 30, -88, wxp + 30, -40), TRIM[1])
        L.fill(L.rect_mask(wxp - 26, -84, wxp + 26, -44), hexrgb("86c0e0"))
        L.fill(L.rect_mask(wxp - 1, -84, wxp + 1, -44), TRIM[1])
        L.fill(L.rect_mask(wxp - 26, -66, wxp + 26, -63), TRIM[1])
    L.outline(OUTLINE, face)
    save_sprite("house_back", L, L.ox, L.oy, wx(x0), wy(y0 + t), sort=wy(y0 + t) - 1)
    # side walls: their tops, raised by the wall's height (sliced by depth)
    for name, xa, xb in [("house_left", x0, x0 + t), ("house_right", x1 - t, x1)]:
        w = wx(xb) - wx(xa)
        h = wy(y1) - wy(y0)
        S = Layer(w, h + WALL_H + 4, 0, WALL_H + 2)
        S.fill(S.rect_mask(0, -WALL_H, w, h - WALL_H), SIDING[1])
        S.fill(S.rect_mask(0, -WALL_H, w, -WALL_H + 3), TRIM[2])
        S.fill(S.rect_mask(0, h - WALL_H, w, h), SIDING[2])  # the end of the wall, facing us
        S.outline(OUTLINE)
        save_sprite(name, S, S.ox, S.oy, wx(xa), wy(y0), sort=wy(y1), slice=True, length=h)
    # the front wall: its outer face, with the door; fades when you're in
    F = Layer(W + 8, WALL_H + 24, 4, WALL_H + 4)
    face = F.rect_mask(0, -WALL_H, W, 0)
    planks = ((np.arange(F.h) // 9) % 3)[:, None] / 3.0
    F.fill_where(face, dither_ramp(np.clip(planks * 0.6 + value_noise(F.h, F.w, 6, 70) * 0.3 + 0.05, 0, 0.999),
                                   SIDING, 0.6))
    F.fill(F.rect_mask(0, -WALL_H, W, -WALL_H + 5), TRIM[2])
    F.fill(F.rect_mask(0, -6, W, 0), TRIM[0])
    dx = wx(DOOR_X) - wx(x0)
    dw = (DOOR_W // 2) * SX
    door = F.rect_mask(dx - dw, -72, dx + dw, 0)
    F.a[door] = 0
    F.fill(F.rect_mask(dx - dw - 5, -78, dx + dw + 5, -72), TRIM[1])
    for side in (-1, 1):
        F.fill(F.rect_mask(dx + side * (dw + 2) - 2, -78, dx + side * (dw + 2) + 3, 0), TRIM[1])
    for wxp in (W * 0.14, W * 0.32, W * 0.68, W * 0.86):
        F.fill(F.rect_mask(wxp - 28, -80, wxp + 28, -32), TRIM[1])
        F.fill(F.rect_mask(wxp - 24, -76, wxp + 24, -36), hexrgb("3e5868"))
        F.fill(F.rect_mask(wxp - 24, -76, wxp - 12, -60), hexrgb("6a90a8"))
        F.fill(F.rect_mask(wxp - 30, -34, wxp + 30, -30), TRIM[0])
        F.fill(F.rect_mask(wxp - 26, -30, wxp + 26, -24), hexrgb("4a7a38"))   # a window box
        for k in range(8):
            F.px(wxp - 22 + k * 6, -31, hexrgb("e85a6a") if k % 2 else hexrgb("f2d24a"))
    # the sign
    F.fill(F.rect_mask(dx - 70, -102, dx + 70, -84), WOOD[0])
    F.fill(F.rect_mask(dx - 67, -99, dx + 67, -87), hexrgb("f0e6c8"))
    F.outline(OUTLINE, F.alpha())
    save_sprite("house_front", F, F.ox, F.oy, wx(x0), wy(y1), sort=wy(y1), fade_inside=True)
    # the roof: a gable along x, seen from above the front; fades inside
    rh = wy(y1) - wy(y0)
    R = Layer(W + 40, rh + 40, 20, 20)
    ridge = int(rh * 0.42)
    back = R.rect_mask(-14, -6, W + 14, ridge)
    front = R.rect_mask(-14, ridge, W + 14, rh + 6)
    yy = np.arange(R.h)[:, None] - R.oy
    shingle_back = (((yy // 9) % 2) * 0.15 + value_noise(R.h, R.w, 4, 80) * 0.3 + 0.15)
    shingle_front = (((yy // 9) % 2) * 0.15 + value_noise(R.h, R.w, 4, 81) * 0.3 + 0.45)
    if THEME == "gym":
        # the office's flat ceiling: acoustic tiles in a grid, a light panel
        whole = R.rect_mask(-14, -6, W + 14, rh + 6)
        R.fill_where(whole, dither_ramp(np.clip(value_noise(R.h, R.w, 4, 82) * 0.3 + 0.4, 0, 0.999),
                                        ROOF, 0.4))
        grid = whole & (((np.arange(R.w) - R.ox) % 40 == 0)[None, :] | ((yy % 30) == 0))
        R.fill(grid, ROOF[0])
        R.fill(R.rect_mask(W * 0.45, rh * 0.35, W * 0.45 + 80, rh * 0.35 + 30), hexrgb("f4f0d8"))
        R.fill(R.rect_mask(-14, rh + 2, W + 14, rh + 8), TRIM[0])
    else:
        R.fill_where(back, dither_ramp(np.clip(shingle_back, 0, 0.999), ROOF, 0.6))
        R.fill_where(front, dither_ramp(np.clip(shingle_front, 0, 0.999), ROOF, 0.6))
        R.fill(R.rect_mask(-14, ridge - 3, W + 14, ridge + 3), ROOF[0])
        R.fill(R.rect_mask(-14, rh + 2, W + 14, rh + 8), TRIM[0])
        # a skylight and a chimney (the ranger hut's thatch has neither)
        if THEME != "dino":
            R.fill(R.rect_mask(W * 0.7, ridge + 20, W * 0.7 + 60, ridge + 56), hexrgb("6a90a8"))
            R.fill(R.rect_mask(W * 0.2, -2, W * 0.2 + 30, ridge - 8), hexrgb("8a5a48"))
    R.outline(OUTLINE)
    save_sprite("house_roof", R, R.ox, R.oy, wx(x0), wy(y0) - WALL_H, sort=wy(y1) + 1, fade_inside=True, roof=True)


def machine_sprite():
    L = Layer(80, 90, 40, 84)
    L.fill(L.rect_mask(-26, -46, 26, 0), METAL[1])
    L.fill(L.rect_mask(-26, -46, -20, 0), METAL[3])
    L.fill(L.rect_mask(-22, -70, 22, -44), hexrgb("2e3640"))
    for i in range(5):
        L.fill(L.ellipse_mask(-14 + i * 7, -60, 4, 4), hexrgb("e8e04a"))
    L.fill(L.rect_mask(-36, -30, -24, -18), hexrgb("2e3640"))     # the nozzle
    for x in (-18, 14):
        L.fill(L.ellipse_mask(x, -2, 6, 5), hexrgb("1f252b"))
    L.outline(OUTLINE)
    return L


def plant_sprite():
    L = Layer(50, 70, 25, 66)
    L.fill(L.rect_mask(-12, -18, 12, 0), hexrgb("a0583a"))
    L.fill(L.rect_mask(-12, -18, -8, 0), hexrgb("c06a48"))
    foliage(L, [(-8, -30, 12), (8, -32, 11), (0, -44, 13)], LEAF2, seed=5, outline=OUTLINE)
    L.outline(OUTLINE)
    return L


# --- the locations' decor (ADR-078) ------------------------------------------------------

def decor_park(G: Layer):
    """THE PARK: trees, bushes, flowerbeds and lamps."""
    rng = random.Random(9)
    # trees: a row behind the courts, the park's edges, and by the walkway
    trees = []
    for i in range(10):
        trees.append((-8 + i * 34 + rng.randint(-6, 6), 18 + rng.randint(-6, 8), rng.choice([0, 1, 2])))
    for x, y in [(-14, 120), (-16, 196), (506, 14), (520, 120), (514, 210), (250, 232), (110, 236)]:
        trees.append((x, y, rng.choice([0, 1, 2])))
    kinds = [(170, 130), (210, 150), (140, 110)]
    for n, (tx, ty, k) in enumerate(trees):
        h, w = kinds[k]
        shadow(G, G.ellipse_mask(wx(tx) + 26, wy(ty) + 6, w * 0.42, 18), 70)
        save_sprite(f"tree_{n}", tree_sprite(100 + n, h, w), int(w * 0.65), h + 4, wx(tx), wy(ty),
                    canopy=True)
    # bushes and flowerbeds along the walkway
    for n, x in enumerate([6, 290, 500]):                    # (the gates' right is for the court cards)
        save_sprite(f"bush_{n}", bush_sprite(200 + n, 70, 40), 43, 44, wx(x), wy(WALK[0]) - 10)
    for n, x in enumerate([60, 140, 220]):
        flowerbed(G, wx(x) - 50, wx(x) + 50, wy(WALK[1]) + 8, wy(WALK[1]) + 30, 300 + n)
    # lamps along the walkway
    for n, x in enumerate([0, 88, 168, 252, 300, 488]):     # between the courts' gates
        save_sprite(f"lamp_{n}", lamp_sprite(), 15, 126, wx(x), wy(WALK[0]) - 2)


PALM_LEAF = ramp("1c3a26", "3a6a30", "6a9a3c")
PALM_BARK = ramp("2a1a14", "5a3a24", "8a5e3a")
FERN = ramp("12301c", "24502a", "3e7432")


def palm_sprite(seed, h, lean):
    L = Layer(int(h * 1.5), h + 40, int(h * 0.75), h + 10)
    SC.palm(L, 0, 0, h, lean, PALM_LEAF, PALM_BARK, seed=seed)
    return L


def fern_sprite(seed, w, h):
    L = Layer(w + 30, h + 16, w // 2 + 15, h + 6)
    SC.fern_band(L, -w // 2, w // 2, 0, h, FERN, seed=seed)
    L.outline(OUTLINE)
    return L


def torch_sprite():
    """A tiki torch: a bound bamboo pole, a basket, a flame."""
    L = Layer(30, 130, 15, 126)
    L.fill(L.rect_mask(-2, -96, 3, 0), hexrgb("8a6a34"))
    L.fill(L.rect_mask(-2, -96, -1, 0), hexrgb("b08c48"))
    for y in (-80, -56, -30):
        L.fill(L.rect_mask(-3, y, 4, y + 2), hexrgb("5a3e20"))
    L.fill(L.poly_mask([(-8, -106), (8, -106), (5, -94), (-5, -94)]), hexrgb("6a4a24"))
    L.fill(L.ellipse_mask(0, -114, 7, 11), hexrgb("f06a1c"))
    L.fill(L.ellipse_mask(0, -111, 4, 7), hexrgb("fcc23c"))
    L.fill(L.ellipse_mask(0, -109, 2, 3), hexrgb("fff0a0"))
    L.outline(OUTLINE)
    return L


def statue_sprite(kind, s, rmp, d=1):
    """A painted dinosaur statue on a stone plinth (DINO PARK)."""
    L = Layer(330, 300, 165, 280)
    L.fill(L.rect_mask(-70, -18, 70, 0), hexrgb("6a6a62"))
    L.fill(L.rect_mask(-70, -18, 70, -14), hexrgb("8e8e84"))
    L.fill(L.rect_mask(-70, -3, 70, 0), hexrgb("4a4a44"))
    getattr(CR, kind)(L, 0, -18, rmp, d=d, s=s)
    L.outline(OUTLINE)
    return L


def nest(L: Layer, cx, cy, seed):
    """A twig nest with three speckled eggs (DINO PARK's flowerbeds)."""
    rng = random.Random(seed)
    ring = L.ellipse_mask(cx, cy, 46, 20) & ~L.ellipse_mask(cx, cy - 3, 30, 11)
    L.fill(ring, hexrgb("5a3e22"))
    for _ in range(90):
        a = rng.uniform(0, 6.283)
        x, y = cx + np.cos(a) * rng.uniform(30, 46), cy + np.sin(a) * rng.uniform(10, 20)
        L.px(x, y, hexrgb("8a6236"))
        L.px(x + 1, y, hexrgb("3e2a16"))
    L.fill(L.ellipse_mask(cx, cy - 3, 30, 11), hexrgb("3e2a16"))
    for k, ex in enumerate((-14, 2, 16)):
        egg = L.ellipse_mask(cx + ex, cy - 8 - (k % 2) * 3, 9, 12)
        L.fill(egg, hexrgb("efe6c8"))
        L.fill(L.ellipse_mask(cx + ex - 3, cy - 13 - (k % 2) * 3, 3, 4), hexrgb("fffaea"))
        for _ in range(6):
            L.px(cx + ex + rng.randint(-5, 5), cy - 8 + rng.randint(-8, 6), hexrgb("8aa04a"))
        L.outline(OUTLINE, egg)


def decor_dino(G: Layer):
    """DINO PARK: a volcano over the courts, palms and ferns where the
    trees were, two statues, tiki torches, nests of eggs."""
    rng = random.Random(9)
    V = Layer(520, 400, 260, 300)
    SC.smoke(V, 0, -140, 110, ramp("3a2a3a", "5a4650", "7a6468", "9a8682"), seed=31)
    SC.volcano(V, 0, 0, 340, 140, ramp("2a1622", "3e2030", "54303c", "6a4048"),
               ramp("a8281a", "f0601a", "fcc040"), seed=32)
    # placed by its lowest pixel: its foot sits behind court 3's back fence
    bottom = int(np.nonzero(V.alpha().any(axis=1))[0].max()) - V.oy
    save_sprite("volcano", V, V.ox, V.oy + bottom, wx(212), wy(COURT_TOP - 12), sort=0)
    palms = []
    for i in range(10):
        palms.append((-8 + i * 34 + rng.randint(-6, 6), 18 + rng.randint(-6, 8)))
    for x, y in [(-14, 120), (-16, 196), (506, 14), (520, 120), (514, 210), (250, 232), (110, 236)]:
        palms.append((x, y))
    for n, (tx, ty) in enumerate(palms):
        if (150 <= tx <= 290 and ty < 40) or (430 <= tx <= 480 and ty > 200):
            continue                          # the volcano and the long-neck show here
        # the top row's crowns stay inside the world (it ends just above them)
        h = rng.choice([118, 130, 142]) if ty < 40 else rng.choice([150, 180, 210])
        lean = rng.choice([-18, -10, 10, 18])
        shadow(G, G.ellipse_mask(wx(tx) + 30, wy(ty) + 6, 60, 16), 70)
        save_sprite(f"palm_{n}", palm_sprite(400 + n, h, lean), int(h * 0.75), h + 10, wx(tx), wy(ty),
                    canopy=True)
    for n, x in enumerate([6, 290, 500]):
        save_sprite(f"fern_{n}", fern_sprite(500 + n, 90, 46), 60, 52, wx(x), wy(WALK[0]) - 10)
    for n, x in enumerate([60, 140, 220]):
        nest(G, wx(x), wy(WALK[1]) + 20, 600 + n)
    for n, x in enumerate([0, 88, 168, 252, 300, 488]):
        save_sprite(f"torch_{n}", torch_sprite(), 15, 126, wx(x), wy(WALK[0]) - 2)
    # the statues: a T. rex between the courts and the hut, a long-neck on
    # the lawn below the walkway
    shadow(G, G.ellipse_mask(wx(264) + 10, wy(34) + 4, 80, 18), 70)
    save_sprite("statue_trex", statue_sprite("trex", 2.2, ramp("1c3a1c", "2e6a2a", "4e9a3a", "84c45a"), -1),
                165, 280, wx(264), wy(34))
    shadow(G, G.ellipse_mask(wx(450) + 10, wy(236) + 4, 80, 18), 70)
    save_sprite("statue_brachio", statue_sprite("brachiosaurus", 2.0,
                ramp("2e4a36", "4a6e46", "6a9058", "8eb070"), -1), 165, 280, wx(450), wy(236))


def gym_back_wall():
    """THE GYM's end wall over the courts: painted block, a stripe, a
    scoreboard and a clock, pennants, high windows, bleachers in front."""
    W = WORLD_W
    top = wy(14)
    L = Layer(W, top + 10, 0, top)
    face = L.rect_mask(0, -top, W, 0)
    rows = ((np.arange(L.h) // 14) % 2)[:, None] * 0.12
    L.fill_where(face, dither_ramp(np.clip(value_noise(L.h, L.w, 6, 90) * 0.3 + 0.35 + rows, 0, 0.999),
                                    ramp("aeb6c2", "bcc4ce", "c8d0d8", "d4dae2"), 0.5))
    L.fill(L.rect_mask(0, -top, W, -top + 18), hexrgb("2a3446"))          # the ceiling's edge
    L.fill(L.rect_mask(0, -86, W, -72), hexrgb("1e3a6e"))                 # the stripe
    L.fill(L.rect_mask(0, -72, W, -68), hexrgb("c83a32"))
    for k in range(9):                                                     # high windows
        x = 80 + k * (W - 160) / 8
        L.fill(L.rect_mask(x - 34, -top + 26, x + 34, -top + 52), hexrgb("2a3446"))
        L.fill(L.rect_mask(x - 31, -top + 29, x + 31, -top + 49), hexrgb("8ab8d8"))
        L.fill(L.rect_mask(x - 31, -top + 29, x - 10, -top + 39), hexrgb("b8d8ea"))
    sx = W // 2
    L.fill(L.rect_mask(sx - 120, -top + 56, sx + 120, -top + 116), hexrgb("121418"))   # the scoreboard
    L.fill(L.rect_mask(sx - 116, -top + 60, sx + 116, -top + 112), hexrgb("1c2026"))
    stamp_text(L, "HOME", sx - 100, -top + 64, hexrgb("f4f0e6"), scale=2)
    stamp_text(L, "GUEST", sx + 26, -top + 64, hexrgb("f4f0e6"), scale=2)
    stamp_text(L, "11", sx - 92, -top + 84, hexrgb("f84a3a"), scale=3)
    stamp_text(L, "9", sx + 56, -top + 84, hexrgb("f84a3a"), scale=3)
    for cx in (W * 0.18, W * 0.82):                                        # clocks
        L.fill(L.ellipse_mask(cx, -top + 84, 22, 22), hexrgb("2a3446"))
        L.fill(L.ellipse_mask(cx, -top + 84, 18, 18), hexrgb("f4f0e6"))
        L.fill(L.line_mask([(cx, -top + 84), (cx, -top + 70)], 2), hexrgb("121418"))
        L.fill(L.line_mask([(cx, -top + 84), (cx + 10, -top + 88)], 2), hexrgb("121418"))
    pennant = [hexrgb(c) for c in ("2e78c8", "d84a3a", "4aa850", "e8b030", "8a5ac8", "e06a9a")]
    L.fill(L.rect_mask(0, -68, W, -66), hexrgb("2a3446"))
    for k in range(26):                                                    # a string of pennants
        x = 30 + k * (W - 60) / 25
        if abs(x - sx) < 140:
            continue                                                       # not over the scoreboard
        L.fill(L.poly_mask([(x - 14, -66), (x + 14, -66), (x, -40)]), pennant[k % len(pennant)])
    seats = SC.bleachers(L, 30, W - 30, -34, ramp("4a5462", "6a7686", "9aa6b4", "c6d0da"), rows=3)
    L.outline(OUTLINE, face)
    return L


def gym_side_wall(length_px):
    """A padded side wall running into the picture (sliced by depth)."""
    t = 30
    L = Layer(t + 4, length_px + WALL_H + 4, 2, WALL_H + 2)
    L.fill(L.rect_mask(0, -WALL_H, t, length_px - WALL_H), hexrgb("24427a"))
    for py in range(-WALL_H, length_px - WALL_H, 40):
        L.fill(L.rect_mask(0, py, t, py + 2), hexrgb("1a3260"))
    L.fill(L.rect_mask(0, length_px - WALL_H, t, length_px), hexrgb("2e5290"))
    L.fill(L.rect_mask(0, -WALL_H, t, -WALL_H + 4), hexrgb("c6cad0"))
    L.outline(OUTLINE)
    return L


def cooler_sprite():
    L = Layer(50, 110, 25, 104)
    L.fill(L.rect_mask(-14, -46, 14, 0), hexrgb("e6e8ea"))
    L.fill(L.rect_mask(-14, -46, -10, 0), hexrgb("f6f8fa"))
    L.fill(L.ellipse_mask(0, -66, 13, 20), hexrgb("5aa0d8"))
    L.fill(L.ellipse_mask(-4, -72, 4, 8), hexrgb("a8d4f2"))
    L.fill(L.rect_mask(-4, -34, 4, -28), hexrgb("3a78c8"))
    L.outline(OUTLINE)
    return L


def cart_sprite():
    """A wire ball cart, full of yellow balls."""
    L = Layer(90, 80, 45, 74)
    L.fill(L.rect_mask(-34, -46, 34, -12), hexrgb("2a3038"))
    for k in range(-30, 32, 8):
        L.fill(L.rect_mask(k, -46, k + 1, -12), hexrgb("6a727c"))
    rng = random.Random(7)
    for _ in range(26):
        x, y = rng.randint(-28, 28), rng.randint(-52, -38)
        L.fill(L.ellipse_mask(x, y, 5, 5), hexrgb("e8e04a"))
        L.px(x - 1, y - 2, hexrgb("fffab0"))
    for x in (-28, 26):
        L.fill(L.ellipse_mask(x, -6, 6, 6), hexrgb("15181c"))
    L.outline(OUTLINE)
    return L


def decor_gym(G: Layer):
    """THE GYM: the end wall and bleachers, padded side walls, water
    coolers and ball carts, the '94 on the floor."""
    save_sprite("gym_wall", gym_back_wall(), 0, wy(14), 0, wy(14), sort=wy(14))
    length = WORLD_H - wy(14)
    for name, x in (("gym_side_l", 6), ("gym_side_r", WORLD_W - 36)):
        save_sprite(name, gym_side_wall(length), 2, WALL_H + 2, x, wy(14), sort=WORLD_H, slice=True,
                    length=length)
    for n, x in enumerate([6, 290, 500]):
        save_sprite(f"cart_{n}", cart_sprite(), 45, 74, wx(x), wy(WALK[0]) - 8)
    for n, x in enumerate([0, 168, 300]):
        save_sprite(f"cooler_{n}", cooler_sprite(), 25, 104, wx(x), wy(WALK[0]) - 2)
    # '94, painted on the floor below the walkway
    cx, cy = wx(140), wy(WALK[1]) + 30
    ring = G.ellipse_mask(cx, cy, 150, 36) & ~G.ellipse_mask(cx, cy, 141, 31)
    G.fill(ring, hexrgb("1e3a6e"))
    stamp_text(G, "94", cx - 34, cy - 21, hexrgb("c83a32"), scale=6, bold=True)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    for p in OUT.glob("*.png"):
        p.unlink()
    G = ground()
    {"park": decor_park, "dino": decor_dino, "gym": decor_gym}[THEME](G)
    G.save(OUT / "ground.png")
    # the courts' fences, nets, racks and benches
    m = FENCE_MARGIN - 1
    for c in range(COURTS):
        left = court_left(c)
        fw = wx(left + COURT_W + m) - wx(left - m)
        save_sprite(f"fence_back_{c}", fence_panel(fw), 4, FENCE_H + 4, wx(left - m), wy(COURT_TOP - m))
        gx = wx(left + COURT_W // 2) - wx(left - m)
        save_sprite(f"fence_front_{c}", fence_panel(fw, gate=(gx - 24, gx + 24)), 4, FENCE_H + 4,
                    wx(left - m), wy(COURT_TOP + COURT_H + m))
        length = wy(COURT_TOP + COURT_H + m) - wy(COURT_TOP - m)
        for side, x in [("l", left - m), ("r", left + COURT_W + m)]:
            save_sprite(f"fence_{side}_{c}", side_fence(length), 3, FENCE_H + 2, wx(x), wy(COURT_TOP - m),
                        sort=wy(COURT_TOP + COURT_H + m), slice=True, length=length)
        nw = wx(left + COURT_W) - wx(left)
        save_sprite(f"net_{c}", net_sprite(nw), 12, NET_H + 4, wx(left), wy(COURT_TOP + COURT_H // 2))
        save_sprite(f"rack_{c}", rack_sprite(), 40, 56, wx(left + COURT_W // 2), wy(RACK_Y))
        save_sprite(f"bench_{c}", bench_sprite(80), 5, 44, wx(left) - 30, wy(RACK_Y) + 4)
    # the clubhouse and its furniture
    house_sprites()
    save_sprite("machine", machine_sprite(), 40, 84, wx(MACHINE_X), wy(MACHINE_Y))
    save_sprite("bench_house", bench_sprite(wx(BENCH_X + 58) - wx(BENCH_X - 10)), 5, 44, wx(BENCH_X - 10),
                wy(BENCH_Y) + 6)
    save_sprite("plant", plant_sprite(), 25, 66, wx(HOUSE[2] - HOUSE_WALL - 10), wy(HOUSE[3] - HOUSE_WALL - 6))
    layout = {
        "doc": "art/park/build_park.py. world = ((x + margin_x) * scale_x, (y + margin_top) * scale_y) for park "
               "px (x, y); sprites: their top-left in the world, `sort` the depth (world y); `slice`: cut into "
               "depth slices of the given length; `fade_inside`: fades while you're in the clubhouse.",
        "world": [WORLD_W, WORLD_H], "scale": [SX, SY], "margin": [MX, MT, MB], "height_scale": H_SCALE,
        "sprites": SPRITES}
    if THEME != "park":
        layout["theme"] = THEME           # ADR-078 (the park's file stays as it was)
        layout["bg"] = BG
    (OUT / "park.json").write_text(json.dumps(layout, indent=1))
    preview(G)
    print(f"wrote {len(SPRITES)} sprites, world {WORLD_W}x{WORLD_H}, to {OUT}")


def preview(G: Layer):
    """Everything composited by depth (no people), for a look: the whole
    park, and a 960x540 crop around the walkway's start."""
    img = Image.fromarray(G.a)
    for s in sorted(SPRITES, key=lambda s: s["sort"]):
        sp = Image.open(OUT / s["file"])
        # a sprite over the world's top or left edge is cut there, not moved
        cx, cy = max(0, -s["x"]), max(0, -s["y"])
        img.alpha_composite(sp.crop((cx, cy, sp.width, sp.height)), (max(0, s["x"]), max(0, s["y"])))
    prev = KIT / "art/park/preview"
    prev.mkdir(exist_ok=True)
    name = "park" if THEME == "park" else THEME
    img.save(prev / f"{name}_full.png")
    cx, cy = wx(128), wy(196)
    img.crop((cx - 480, cy - 330, cx + 480, cy + 210)).save(prev / f"{name}_start.png")


if __name__ == "__main__":
    build()
