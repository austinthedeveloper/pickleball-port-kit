"""The venues as parallax layers: three from the level mocks (park,
lakeside, sunset), ADR-046's fun venues (dinosaur, space, undersea), the
port's indoor GYM (ADR-078, THE GYM's games), and the dinosaur game's four
levels (ADR-085: ruins, glacier, and the indoor lab and station).

Each builder returns a Venue: named layers (back to front), each with a
parallax factor, plus spots (spectator seats, the watcher, prop anchors).
Players, the ball, shadows, and the near net post are drawn by the game
between the 'stands' and 'front' layers.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import numpy as np

import court as C
from pix import Layer, bush, chain_link, fbm, grow as grow_, hexrgb, ramp, solid, stamp_text, tree
from scenery import (OUTLINE, M, arch_bridge, asteroid, ball_icon, barrel, bin_can, bleachers,
                     brain_coral, bubbles, hills, sailboat, cloud, console, coral_fan,
                     coral_tubes, crate, dome, fence, fern_band, fire, flowers, girder,
                     hazard, hedge_band, house, icicles, kelp, lamp_post, moon_ridge,
                     nebula, notice_board, palisade, palm, park_bench, pavers, peaks,
                     pine, pipe_run, planet, rocket, rope_fence, ruined_towers,
                     safety_rail, shipwreck, sign, skyline, sky_gradient, smoke,
                     snow_bank, stars, stone_pillar, sun, tank, towel_and_bag,
                     tree_icon, tree_line, volcano, water, water_sky)


@dataclass
class Venue:
    name: str
    layers: list = field(default_factory=list)   # (name, Layer, parallax)
    court_colors: dict = field(default_factory=dict)
    seats: list = field(default_factory=list)    # (x, y, facing) feet/seat
    watcher: dict = field(default_factory=dict)
    props: list = field(default_factory=list)
    net_colors: dict = field(default_factory=dict)

    def add(self, name, layer, parallax):
        self.layers.append((name, layer, parallax))


# -- Shared ramps -------------------------------------------------------------

LEAF_DAY = ramp("0e2433", "16443f", "2f6845", "4f8a46", "7fab55", "a8c46d")
LEAF_FAR = ramp("1a3e45", "2a5a50", "3f7552", "5a8f58", "86ad6c")
BARK = ramp("2a2830", "3d3439", "57473f", "766450")
FENCE_POST = ramp("08202c", "17384a", "3b5868")
FENCE_WIRE = hexrgb("0f2a30")
ALU = ramp("2d3944", "6c6d72", "9c958f", "c8c2b6")


def ground_band(v: Venue, ground_top, colors, seed, speckle):
    L = Layer()
    roles = C.court_mask((L.h, L.w), L.ox, L.oy, ground_top)
    C.paint_ground(L, roles, colors, seed=seed, speckle=speckle)
    v.court_colors = colors
    v.add("ground", L, 1.0)
    v.roles = roles
    return L


def front_fence(v: Venue, ground_rgb_dark, leaf, seed, posts_mock,
                gate=None, path=None, wire=FENCE_WIRE, post=FENCE_POST):
    """Near fence and corner bushes (drawn over the players)."""
    F = Layer()
    top = 461
    xs = [M(x, 0)[0] for x in posts_mock]
    gx0, gx1 = gate if gate else (None, None)
    # mesh in segments, skipping a gate gap
    segs = [(-48, 1008)] if gate is None else [(-48, gx0), (gx1, 1008)]
    for a, b in segs:
        fence(F, a, b, top, 600, [x for x in xs if a <= x <= b], wire,
              post, spacing=7)
    # posts get a little taller/thicker (closer)
    for x in xs:
        p = F.rect_mask(x - 4, top - 8, x + 5, 600)
        F.fill(p, post[1])
        F.fill(F.rect_mask(x - 4, top - 8, x - 2, 600), post[2])
        F.fill(F.rect_mask(x + 3, top - 8, x + 5, 600), post[0])
        cap = F.rect_mask(x - 5, top - 11, x + 6, top - 6)
        F.fill(cap, post[2])
        F.outline(OUTLINE, p | cap)
    rng = random.Random(seed)
    for (cx, w, h) in ((40, 230, 95), (-20, 140, 70), (150, 120, 55),
                       (920, 230, 95), (980, 140, 70), (810, 120, 55)):
        bush(F, cx + rng.randint(-8, 8), 560, w, h, leaf, seed=rng.randint(0, 9999))
    v.add("front", F, 1.3)
    return F


# -- Level 01: Riverdale Park, day ---------------------------------------------

def park() -> Venue:
    v = Venue("park")
    # sky
    S = Layer()
    sky_gradient(S, [(0, "3d8fe6"), (0.45, "5aaefc"), (0.8, "8cc4fa"),
                     (1, "b4d8f7")], y0=-24, y1=150)
    for (cx, cy, w, h, sd) in ((190, 22, 120, 26, 1), (370, 18, 70, 18, 2),
                               (620, 16, 90, 20, 3), (820, 24, 110, 24, 4),
                               (500, 40, 50, 12, 5)):
        cloud(S, cx, cy, w, h, ramp("8fbff9", "c7def6", "e6f1f6", "ffffff"),
              seed=sd)
    v.add("sky", S, 0.2)
    # far: skyline
    F = Layer()
    # the city from edge to edge (it stopped at 720, beside the right oak)
    skyline(F, -48, 1008, 112, 18, 50, ramp("8fbddd", "74a8cb", "6699bb",
                                                "b0d4ea"), hexrgb("d2e8f4"),
            seed=11, lit=0.15)
    v.add("far", F, 0.4)
    # trees: back tree line + big edge oaks
    T = Layer()
    tree_line(T, -60, 1020, 150, 42, 70, LEAF_FAR, BARK, seed=21, step=(26, 44))
    for (x, hgt, wid, sd) in ((40, 205, 170, 31), (150, 185, 120, 32),
                              (815, 185, 120, 33), (925, 205, 170, 34),
                              (-40, 190, 150, 35), (1000, 190, 150, 36)):
        tree(T, x, 175, hgt, wid, LEAF_DAY, BARK, seed=sd, trunk_w=12,
             crown_frac=0.6)
    v.add("trees", T, 0.6)
    # back fence: hedge behind, mesh, posts
    B = Layer()
    base = 190
    hedge_band(B, -48, 1008, 134, base, ramp("123037", "22544f", "3d6a50",
                                             "5f8a4c", "9db54f"), seed=100)
    posts = [M(x, 0)[0] for x in (130, 335, 540, 775, 965, 1100, 1225)]
    posts = [-30, 60] + posts + [880, 960, 1000]
    fence(B, -48, 1008, 111, base, posts, FENCE_WIRE, FENCE_POST, spacing=6)
    # ground strip under the fence (kerb)
    B.fill(B.rect_mask(-48, base - 2, 1008, base + 2), hexrgb("6e5a46"))
    B.fill(B.rect_mask(-48, base - 2, 1008, base - 1), hexrgb("9a8266"))
    v.add("fence", B, 1.0)
    # ground
    ground_band(v, 188, {
        "surround": ramp("8f6643", "b5845a", "c99560", "d6a166", "e0b077"),
        "surface": ramp("2a7c72", "2e867c", "31897f", "35907f"),
        "kitchen": ramp("2a7c72", "2e867c", "31897f", "35907f"),
        "kitchen_shade": ramp("1f5f58", "21655e", "236a62"),
        "lines": ramp("e9dfbd", "f3ebcc", "fbf3d6"),
        "lines_shade": ramp("bfb898", "cbcaab", "d6d0b2"),
    }, seed=41, speckle=(0.004, hexrgb("8a6140")))
    # stands: bleachers, sign, bin (in front of the fence)
    P = Layer()
    for (mx0, mx1) in ((90, 380), (985, 1265)):
        x0, x1 = M(mx0, 0)[0], M(mx1, 0)[0]
        seats = bleachers(P, x0, x1, 150, ALU, rows=3)
        for k in range(3):
            v.seats.append({"x": round(x0 + (k + 0.5) * (x1 - x0) / 3),
                            "y": seats[0], "pose": "sit"})
    sign(P, 425, 133, 528, 168, hexrgb("255042"), ramp("163a30", "6a8364",
                                                        "91a17e"),
         hexrgb("a6b48e"), ["RIVERDALE", "PARK"], scale=1,
         icon=lambda L: tree_icon(L, 512, 140, hexrgb("91a17e")))
    bin_can(P, 787, 190, 18, 34, ramp("233146", "49566b", "6b7584", "9499a1"))
    v.add("stands", P, 1.0)
    v.watcher = {"x": round(M(1100, 0)[0]), "y": 158, "pose": "sit"}
    front_fence(v, hexrgb("8a6140"),
                ramp("0d2b36", "1f4a3e", "325b42", "4e7a3e", "6f9a46", "98b65a"),
                seed=51, posts_mock=(255, 645, 1055))
    v.net_colors = {}
    return v


# -- Level 02: Lakeside -----------------------------------------------------------

def lakeside() -> Venue:
    v = Venue("lakeside")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "3f86e0"), (0.5, "5c9ef0"), (1, "a9cdf2")],
                 y0=-24, y1=110)
    for (cx, cy, w, h, sd) in ((520, 8, 60, 14, 61), (700, 14, 90, 18, 62),
                               (880, 30, 40, 10, 63)):
        cloud(S, cx, cy, w, h, ramp("9cc6f3", "cfe3f6", "eef5f8", "ffffff"),
              seed=sd)
    v.add("sky", S, 0.2)
    # far: hazy hills, the far shore's trees and its town, the lake: the
    # whole width (a centre-only lake read as a small rectangle between the
    # side trees)
    F = Layer()
    hills(F, -48, 1008, 86, 14, 36, ramp("5f8a8a", "6f9a94", "82aaa0",
                                         "97b8a8"), seed=70)
    tree_line(F, -60, 1020, 86, 18, 36, ramp("1d4a45", "2c6250", "437c56",
                                             "62965c"), BARK, seed=71,
              step=(14, 24))
    walls = (ramp("6b6a62", "b8b2a0", "d9d2bd"), ramp("6e6455", "c9b48e", "e2d0aa"),
             ramp("5e6a6e", "a9b6b8", "cfd8d8"), ramp("6a5a52", "c7a690", "e0c4ae"))
    roofs = (ramp("6e3a2e", "9a5440"), ramp("3e4a5a", "5a6a7e"),
             ramp("5a3a2a", "7e5236"), ramp("7a2e2a", "a8443a"))
    rng = random.Random(77)
    # three clusters along the shore, a few on their own between
    for (x0, x1, n) in ((40, 200, 5), (380, 640, 7), (790, 960, 4), (250, 320, 1),
                        (700, 740, 1)):
        for k in range(n):
            x = rng.randint(x0, x1)
            w = rng.randint(14, 24)
            house(F, x, 88 + rng.randint(-1, 0), w, rng.randint(8, 13),
                  walls[rng.randrange(4)], roofs[rng.randrange(4)])
    water(F, -48, 1008, 88, 116, ramp("3e6f9a", "4f84b3", "5f95c4", "79abd6"),
          hexrgb("d8ecf8"), seed=72)
    for (x, y, s, c) in ((600, 100, 5, "ffffff"), (730, 106, 6, "f2d36b"),
                         (880, 96, 4, "ffffff")):
        sailboat(F, x, y, s, hexrgb("8a4a32"), hexrgb(c))
    # grass field from the shore to the fence
    G = F.rect_mask(-48, 114, 1008, 200)
    n = fbm(F.h, F.w, 16, 73, 2)
    img = np.array(ramp("6f9a3b", "86ad40", "98bb45", "a8c84b"), np.uint8)[
        np.clip(((0.45 + (n - 0.5) * 0.7) * 4).astype(int), 0, 3)]
    F.fill_where(G, img)
    # a footpath across the field
    F.fill(F.poly_mask([(330, 134), (420, 126), (470, 126), (400, 136)]),
           hexrgb("c8b27a"))
    v.add("far", F, 0.4)
    # trees: big trees at both sides, a bush clump mid
    T = Layer()
    for (x, hgt, wid, sd) in ((20, 230, 200, 81), (170, 210, 170, 82),
                              (330, 150, 120, 83), (760, 170, 130, 84),
                              (880, 225, 190, 85), (990, 210, 170, 86),
                              (-40, 200, 160, 87)):
        tree(T, x, 160, hgt, wid, LEAF_DAY, BARK, seed=sd, trunk_w=12,
             crown_frac=0.62)
    for i, (cx, w, h) in enumerate(((420, 70, 46), (470, 80, 52), (520, 60, 40),
                                     (580, 50, 34), (700, 46, 30))):
        bush(T, cx, 160, w, h, LEAF_DAY, seed=90 + i)
    v.add("trees", T, 0.6)
    # stands are OUTSIDE the fence here: bleachers, bench, bins, board
    P = Layer()
    x0, x1 = M(0, 0)[0] - 30, M(370, 0)[0]
    seats = bleachers(P, x0, x1, 128, ALU, rows=3)
    for k in (1, 2):
        v.seats.append({"x": round(x0 + (k + 0.6) * (x1 - x0) / 4),
                        "y": seats[0], "pose": "sit"})
    bx0, bx1 = M(950, 0)[0], M(1090, 0)[0]
    park_bench(P, bx0, bx1, 152, ramp("3a2a22", "6a4630", "8a5c3c", "b07a52"),
               ramp("1c2a30", "34464e"))
    v.seats.append({"x": round((bx0 + bx1) / 2), "y": 152, "pose": "sit"})
    for mx in (865, 1115):
        bin_can(P, M(mx + 28, 0)[0], 168, 22, 40,
                ramp("0d2b36", "1d4a52", "306464", "4f8a7a"))
    notice_board(P, M(1190, 0)[0], 78, M(1315, 0)[0], 140,
                 ramp("3a2a22", "7f5337", "a8774c"), hexrgb("d7c6a1"),
                 hexrgb("69874b"))
    v.add("stands", P, 1.0)
    v.watcher = {"x": round(M(1020, 0)[0]), "y": 152, "pose": "sit"}
    # fence in front of the stands (green), ground
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (75, 350, 540, 765, 955, 1260)] + [990]
    fence(B, -48, 1008, 143, 188, posts, hexrgb("0f3a33"),
          ramp("0a2a24", "16463c", "2f6a58"), spacing=6, mid_rail=None)
    B.fill(B.rect_mask(-48, 186, 1008, 190), hexrgb("7c6046"))
    v.add("fence", B, 1.0)
    ground_band(v, 188, {
        "surround": ramp("9c6e4f", "b17f59", "ba865d", "c4905f", "cf9c69"),
        "surface": ramp("35736d", "397c75", "3b8078", "40877d"),
        "kitchen": ramp("35736d", "397c75", "3b8078", "40877d"),
        "kitchen_shade": ramp("29605a", "2c645e", "2f6862"),
        "lines": ramp("e9e6d6", "f4f1e2", "fffbee"),
        "lines_shade": ramp("c6c3b4", "d0cdbd", "dad7c6"),
    }, seed=74, speckle=(0.003, hexrgb("94694b")))
    front_fence(v, hexrgb("94694b"),
                ramp("0a2a2c", "1a4a3a", "2e5e3a", "4a7a3a", "6c9a44", "93b656"),
                seed=75, posts_mock=(105, 440, 900, 1250))
    # a grass verge along the bottom, under the fence and bushes
    Fr = v.layers[-1][1]
    gv = Layer()
    n = fbm(gv.h, gv.w, 8, 76, 2)
    img = np.array(ramp("4f7a32", "6a9438", "80a83e", "98bb45"), np.uint8)[
        np.clip(((0.5 + (n - 0.5) * 0.8) * 4).astype(int), 0, 3)]
    gv.fill_where(gv.rect_mask(-48, 500, 1008, 600), img)
    gv.fill(gv.rect_mask(-48, 500, 1008, 502), hexrgb("3e6230"))
    gv.over(Fr)
    v.layers[-1] = ("front", gv, 1.3)
    return v


# -- Level 03: Sunset doubles -------------------------------------------------------

LEAF_DUSK = ramp("0e1418", "1b2a2c", "2c3f30", "48552e", "6d6a2e", "9a8a3a")
BARK_DUSK = ramp("15141c", "241f26", "3a2f2e", "5a4434")


def sunset() -> Venue:
    v = Venue("sunset")
    S = Layer()
    sky_gradient(S, [(0, "3a3478"), (0.3, "7c59b3"), (0.55, "c4708a"),
                     (0.75, "ee9a48"), (0.9, "f8c060"), (1, "fbd98a")],
                 y0=-24, y1=104)
    for (cx, cy, w, h, sd) in ((300, 30, 110, 12, 91), (520, 18, 80, 10, 92),
                               (760, 40, 90, 10, 93)):
        cloud(S, cx, cy, w, h, ramp("8a5a9e", "b4708e", "d98a7c", "f0a878"),
              seed=sd)
    sun(S, 700, 74, 20, ramp("f6a84a", "fac868", "fde08a", "fdeaa0"),
        stripes=((6, 1), (11, 2), (16, 2)), sky=hexrgb("f3b45a"))
    v.add("sky", S, 0.2)
    F = Layer()
    # the city from the left edge to just short of the sun
    skyline(F, -48, 660, 100, 14, 40, ramp("3a2f5c", "4a3a70", "56407a",
                                            "6e4e7e"), hexrgb("f6c36a"),
            seed=94, lit=0.3)
    water(F, -48, 1008, 100, 118, ramp("3c3164", "5a3f78", "7a4c80", "9a5c7c"),
          hexrgb("f8c878"), seed=95, reflect=(700, 22, hexrgb("f6b45a")))
    v.add("far", F, 0.4)
    T = Layer()
    tree_line(T, 360, 600, 118, 26, 46, LEAF_DUSK, BARK_DUSK, seed=96,
              step=(20, 34))
    for (x, hgt, wid, sd) in ((30, 220, 200, 101), (190, 200, 150, 102),
                              (300, 120, 90, 103), (790, 210, 160, 104),
                              (920, 225, 200, 105), (-50, 200, 160, 106),
                              (1010, 200, 160, 107)):
        tree(T, x, 170, hgt, wid, LEAF_DUSK, BARK_DUSK, seed=sd, trunk_w=12,
             crown_frac=0.6)
    v.add("trees", T, 0.6)
    B = Layer()
    base = 186
    hedge_band(B, -48, 1008, 104, base, ramp("101a1e", "1e302c", "33442e",
                                             "4f5a2c", "746a2c"), seed=110)
    flowers(B, M(320, 0)[0], M(500, 0)[0], base, 30,
            ramp("1d302e", "2d4630", "435a2c", "5e6e2c"), hexrgb("f0b030"),
            hexrgb("c87a18"), seed=111)
    flowers(B, M(1000, 0)[0], M(1080, 0)[0], base, 20,
            ramp("1d302e", "2d4630", "435a2c", "5e6e2c"), hexrgb("f0b030"),
            hexrgb("c87a18"), seed=112)
    posts = [-30] + [M(x, 0)[0] for x in (100, 300, 490, 660, 790, 900, 1050,
                                          1195)] + [890, 990]
    fence(B, -48, 1008, 111, base, posts, hexrgb("141d26"),
          ramp("0a1018", "1d2633", "3a4250"), spacing=6)
    B.fill(B.rect_mask(-48, base - 2, 1008, base + 2), hexrgb("6a4a3e"))
    B.fill(B.rect_mask(-48, base - 2, 1008, base - 1), hexrgb("8e6450"))
    v.add("fence", B, 1.0)
    ground_band(v, 186, {
        "surround": ramp("8a4636", "a8563a", "b85f3f", "c26a46", "cc7752"),
        "surface": ramp("17616a", "1a6a71", "1d7178", "22787e"),
        "kitchen": ramp("17616a", "1a6a71", "1d7178", "22787e"),
        "kitchen_shade": ramp("114e56", "13535b", "15585f"),
        "lines": ramp("e6dcbc", "f1e8c8", "f9f0d2"),
        "lines_shade": ramp("bcb294", "c8bfa2", "d2c9ac"),
    }, seed=113, speckle=(0.004, hexrgb("8c4636")))
    P = Layer()
    x0, x1 = M(-20, 0)[0], M(300, 0)[0]
    seats = bleachers(P, x0, x1, 150, ramp("2a2a34", "5e5a5c", "8a8280",
                                            "b0a69a"), rows=3)
    for k in range(4):
        v.seats.append({"x": round(x0 + (k + 0.5) * (x1 - x0) / 4),
                        "y": seats[0], "pose": "sit"})
    bx0, bx1 = M(540, 0)[0], M(745, 0)[0]
    park_bench(P, bx0, bx1, 172, ramp("2a1c1c", "5a3a30", "7a4e3c", "9c6a4e"),
               ramp("12141c", "2a2c36"))
    towel_and_bag(P, bx0 + 16, 172, ramp("8a8a96", "d8d8e0", "ffffff"),
                  ramp("0e2a5c", "1e4a9a", "3a6ac8"))
    bin_can(P, 560, 186, 18, 32, ramp("12302a", "205046", "2f6a5a",
                                               "4f8a74"))
    sign(P, M(1205, 0)[0], 120, M(1315, 0)[0], 172, hexrgb("b5a283"),
         ramp("5a4a38", "8a7a60", "d2c4a4"), hexrgb("2f5a40"),
         ["PICKLE", "BALL"], scale=1)
    v.seats += [{"x": round(M(1080, 0)[0]), "y": 172, "pose": "sit"},
                {"x": round(M(1130, 0)[0]), "y": 186, "pose": "stand"},
                {"x": round(M(1170, 0)[0]), "y": 172, "pose": "sit"}]
    v.add("stands", P, 1.0)
    v.watcher = {"x": round(M(1130, 0)[0]), "y": 186, "pose": "stand"}
    front_fence(v, hexrgb("8c4636"), LEAF_DUSK, seed=114,
                posts_mock=(255, 400, 935, 1100), gate=(M(400, 0)[0] + 6,
                                                        M(935, 0)[0] - 6))
    # paved path through the gate, under the front fence layer
    Fr = [l for n, l, p in v.layers if n == "front"][0]
    pv = Layer()
    pavers(pv, M(420, 0)[0], M(915, 0)[0], 500, 600,
           ramp("5a4e40", "8f7a62", "a08470", "b8987a"), seed=115)
    pv.over(Fr)
    v.layers[-1] = ("front", pv, 1.3)
    return v


# -- ADR-046: the fun venues ------------------------------------------------------
#
# No level mocks: each follows its SNES mock (art/concept/court_top_*.png)
# at the levels' layout. The onlookers stand behind the fence (the stands
# draw before it), and the default court is the venues.json preset.

def preset_court(surface, kitchen, surround, lines):
    """Ground ramps around preset base colours (data/court_colors.json), so
    a venue's DEFAULT paints the preset its venues.json entry names."""
    def sc(rgb, ks):
        return [tuple(int(min(255, round(c * k))) for c in hexrgb(rgb)) for k in ks]
    return {
        "surround": sc(surround, (0.84, 0.94, 1.0, 1.06, 1.16)),
        "surface": sc(surface, (0.92, 0.98, 1.02, 1.08)),
        "kitchen": sc(kitchen, (0.92, 0.98, 1.02, 1.08)),
        "kitchen_shade": sc(kitchen, (0.74, 0.78, 0.82)),
        "lines": sc(lines, (0.96, 1.0, 1.04)),
        "lines_shade": sc(lines, (0.72, 0.76, 0.8)),
    }


def verge(v: Venue, rmp, edge, seed, cell=8):
    """A strip of ground along the bottom, under the near fence."""
    Fr = v.layers[-1][1]
    gv = Layer()
    n = fbm(gv.h, gv.w, cell, seed, 2)
    img = np.array(rmp, np.uint8)[
        np.clip(((0.5 + (n - 0.5) * 0.8) * len(rmp)).astype(int), 0, len(rmp) - 1)]
    gv.fill_where(gv.rect_mask(-48, 500, 1008, 600), img)
    gv.fill(gv.rect_mask(-48, 500, 1008, 502), edge)
    gv.over(Fr)
    v.layers[-1] = ("front", gv, 1.3)


def stand_seats(v: Venue, xs, y):
    for x in xs:
        v.seats.append({"x": x, "y": y, "pose": "stand"})


# -- Dinosaur: a sunset jungle, a volcano, dinosaurs over a wooden fence ----------

JUNGLE = ramp("10261c", "1c3e26", "2e5a2c", "487a30", "6a9a3a", "94b84a")
JUNGLE_DUSK = ramp("10201e", "1a3426", "28482c", "3c6030", "587a36")


def dinosaur() -> Venue:
    import critters as K
    v = Venue("dinosaur")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "2e2050"), (0.3, "6a2c66"), (0.55, "c4485a"),
                     (0.75, "ec7a40"), (0.9, "f8ac54"), (1, "fcd47c")],
                 y0=-24, y1=140)
    sun(S, 250, 82, 22, ramp("f8c870", "fbe09a", "fdf0c0", "fffae0"))
    for (cx, cy, w, h, sd) in ((140, 30, 90, 10, 121), (470, 20, 70, 8, 122),
                               (860, 34, 100, 10, 123)):
        cloud(S, cx, cy, w, h, ramp("7a3a6a", "a84a6a", "d0646a", "e88a6a"),
              seed=sd)
    for (x, y, d, sc_, up) in ((360, 52, 1, 1.4, False), (560, 24, -1, 1.2, True),
                               (840, 70, -1, 1.0, False)):
        K.pterodactyl(S, x, y, ramp("3a1a2a", "5a2a36", "7a3e40"), d=d, s=sc_, up=up)
    v.add("sky", S, 0.2)
    F = Layer()
    for i, x in enumerate(range(-60, 1040, 70)):         # far purple hills
        bush(F, x, 150, 140, 46 + (i * 37) % 24, ramp("3a1e44", "4a2650", "5a305a",
                                                       "6e3c62"), seed=130 + i)
    smoke(F, 702, 50, 70, ramp("3a2a3a", "5a4650", "7a6468", "9a8682"), seed=131)
    volcano(F, 700, 150, 250, 100, ramp("2a1622", "3e2030", "54303c", "6a4048"),
            ramp("a8281a", "f0601a", "fcc040"), seed=132)
    v.add("far", F, 0.4)
    T = Layer()
    K.brachiosaurus(T, 330, 200, ramp("2e4a36", "4a6e46", "6a9058", "8eb070"), d=1, s=1.5)
    for i, x in enumerate(range(-60, 1040, 46)):
        bush(T, x, 172, 80, 48, JUNGLE_DUSK, seed=140 + i)
    for (x, h, lean, sd) in ((20, 150, 14, 141), (90, 120, -10, 142),
                             (190, 104, 8, 143), (470, 96, -6, 144),
                             (560, 112, 10, 145), (850, 128, -12, 146),
                             (950, 150, -16, 147), (1010, 110, 8, 148)):
        palm(T, x, 175, h, lean, ramp("1c3a26", "3a6a30", "6a9a3c"),
             ramp("2a1a14", "5a3a24", "8a5e3a"), seed=sd)
    v.add("trees", T, 0.6)
    P = Layer()
    fern_band(P, -48, 1010, 166, 26, ramp("12301c", "24502a", "3e7432"), seed=150)
    P.fill(P.rect_mask(-48, 164, 1008, 192), hexrgb("1a3a20"))
    K.stegosaurus(P, 100, 158, ramp("2a4a1e", "4a7a2a", "6ea03a", "9ac458"),
                  ramp("8a2a14", "d0582a", "f49a4a"), s=2.0)
    K.raptor(P, 236, 160, ramp("1e3a5a", "2e5a8a", "4a80b4", "7aa8d8"), d=1, s=1.6)
    K.raptor(P, 616, 160, ramp("5a1e44", "9a3a6e", "d0609a", "f09ac0"), d=-1, s=1.5)
    K.triceratops(P, 836, 158, ramp("1e3a5a", "345e8e", "5486b8", "84b0dc"),
                  ramp("6a2240", "a8406a", "d8709a"), d=-1, s=2.0)
    K.trex(P, 948, 166, ramp("1c3a1c", "2e6a2a", "4e9a3a", "84c45a"), d=-1, s=1.6)
    v.add("stands", P, 1.0)
    stand_seats(v, (320, 376, 690, 746), 174)
    v.watcher = {"x": 746, "y": 174, "pose": "stand"}
    B = Layer()
    palisade(B, -48, 1008, 150, 190, ramp("3a2214", "6a4224", "82552e", "a8743e"),
             ramp("2a180e", "5a3a20", "8a6034"), seed=151)
    B.fill(B.rect_mask(-48, 186, 1008, 190), hexrgb("6a5236"))
    B.fill(B.rect_mask(-48, 186, 1008, 187), hexrgb("8e7046"))
    v.add("fence", B, 1.0)
    ground_band(v, 188, preset_court("2e7a48", "c45c1c", "56964a", "ffffff"),
                seed=152, speckle=(0.004, hexrgb("3e7232")))
    front_fence(v, hexrgb("3e7232"), JUNGLE, seed=153,
                posts_mock=(105, 440, 900, 1250))
    verge(v, ramp("3e6a2a", "4e8030", "5e9238", "72a640"), hexrgb("2e5222"), seed=154)
    return v


# -- Space: stars, Earth, Saturn, a rocket, aliens behind a lit fence -------------

MOON = ramp("3a3848", "565466", "727082", "8e8c9e", "aeacbc")


def space() -> Venue:
    import critters as K
    v = Venue("space")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "06061a"), (0.5, "120e34"), (0.85, "26184e"),
                     (1, "3a2462")], y0=-24, y1=150)
    stars(S, -24, 170, 0.006, [hexrgb("6a6a9a"), hexrgb("b0b0d8"), hexrgb("ffffff")],
          seed=160, twinkles=((90, 20), (420, 8), (640, 60), (905, 18), (720, 112),
                              (40, 96)))
    nebula(S, 40, 40, ramp("1e1a4a", "3a2470", "5a3a8a", "3a6a9a"), seed=161, slope=0.06)
    planet(S, 300, 92, 34, ramp("143a7a", "1e5aa8", "3a80cc", "6aa8e4"),
           land=ramp("2a5a2a", "3e7a32", "62a044", "8cc060"), seed=162)
    planet(S, 790, 66, 17, ramp("8a4a1e", "c0783a", "e0a45a", "f4c87e"),
           bands=((-6, 3, ramp("9a5a2a", "d08a4a")), (2, 3, ramp("7a3e1a", "b06a34"))),
           ring=(34, 9, ramp("8a6a4a", "d8b888", "f4dcb0")))
    planet(S, 560, 26, 6, ramp("6a6a7a", "a0a0b0", "d0d0dc"))
    v.add("sky", S, 0.2)
    F = Layer()
    moon_ridge(F, -60, 1040, 152, 10, 34, ramp("2a2640", "3a3654", "4a4666", "5c5878"),
               seed=163, craters=0.02, step=(30, 80))
    v.add("far", F, 0.4)
    T = Layer()
    moon_ridge(T, -60, 1040, 178, 14, 36, MOON, seed=164, craters=0.04, step=(40, 110))
    dome(T, 170, 152, 64, 44, ramp("1a4a6a", "2a6a8a", "3e8aa8", "5aaac4"),
         hexrgb("8ad8f0"), hexrgb("c0f4ff"))
    T.fill(T.rect_mask(250, 130, 253, 152), hexrgb("8a8c9e"))       # antenna mast
    for k in range(4):
        T.fill(T.rect_mask(246 + k, 130 + k * 5, 257 - k, 131 + k * 5), hexrgb("aeacbc"))
    T.fill(T.ellipse_mask(251, 127, 3, 3), hexrgb("f04a6a"))
    rocket(T, 640, 156, 92, ramp("8a8c9e", "d8dce8", "f4f6fc", "ffffff"),
           ramp("8a1a2a", "d83a4a", "f87a7a"), hexrgb("4ad8f0"))
    T.fill(T.rect_mask(616, 152, 676, 158), hexrgb("565466"))       # launch pad
    T.fill(T.rect_mask(616, 152, 676, 153), hexrgb("8e8c9e"))
    v.add("trees", T, 0.6)
    P = Layer()
    reg = P.rect_mask(-48, 160, 1008, 192)
    n = fbm(P.h, P.w, 6, 165, 2)
    P.fill_where(reg, np.array(MOON[1:4], np.uint8)[
        np.clip((n * 3).astype(int), 0, 2)])
    P.fill(P.rect_mask(-48, 160, 1008, 161), MOON[4])
    for (x, h) in ((70, 64), (470, 70), (900, 64)):
        lamp_post(P, x, 186, h, ramp("2a2a3a", "4a4a5e", "7a7a8e"), hexrgb("3a3a4e"),
                  hexrgb("f8f4c0"))
    K.astronaut(P, 140, 182, ramp("8a92a4", "c4ccd8", "eef2f8", "ffffff"),
                ramp("1a2a5a", "4a7ad8"), d=1, s=1.3)
    K.alien(P, 200, 182, ramp("1a5a1a", "3a9a2a", "6ad040", "a8f070"), d=1, s=1.3, wave=True)
    K.alien(P, 250, 182, ramp("7a1a5a", "c03a8a", "f070b8", "ffa8d8"), d=1, s=1.2)
    K.alien(P, 700, 182, ramp("1a5a1a", "3a9a2a", "6ad040", "a8f070"), d=-1, s=1.25)
    K.astronaut(P, 760, 182, ramp("8a92a4", "c4ccd8", "eef2f8", "ffffff"),
                ramp("1a2a5a", "4a7ad8"), d=-1, s=1.3, wave=True)
    K.alien(P, 840, 182, ramp("1a4a6a", "2a7aa8", "4ab0e0", "8ad8f8"), d=-1, s=1.3)
    v.add("stands", P, 1.0)
    stand_seats(v, (320, 380, 560, 620), 186)
    v.watcher = {"x": 620, "y": 186, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (100, 300, 490, 660, 790, 900, 1050,
                                          1195)] + [890, 990]
    fence(B, -48, 1008, 118, 188, posts, hexrgb("2a5a7a"),
          ramp("1a2a3e", "4a5a72", "9ab0c8"), spacing=6, mid_rail=150)
    B.fill(B.rect_mask(-48, 116, 1008, 119), hexrgb("6ae8ff"))      # the lit rail
    B.fill(B.rect_mask(-48, 116, 1008, 117), hexrgb("d0faff"))
    for x in posts:
        B.fill(B.rect_mask(x - 3, 110, x + 4, 113), hexrgb("f05aa8"))
        B.fill(B.rect_mask(x - 2, 110, x + 3, 111), hexrgb("ffb0e0"))
    B.fill(B.rect_mask(-48, 186, 1008, 190), hexrgb("3a3848"))
    B.fill(B.rect_mask(-48, 186, 1008, 187), hexrgb("6a6a7e"))
    v.add("fence", B, 1.0)
    ground_band(v, 188, preset_court("223470", "60408c", "46484e", "78f0ff"),
                seed=166, speckle=(0.004, hexrgb("34363c")))
    front_fence(v, hexrgb("34363c"), ramp("2a2838", "3e3c50", "565468", "727082",
                                           "908ea0", "aeacbc"),
                seed=167, posts_mock=(105, 440, 900, 1250),
                wire=hexrgb("1e4a64"), post=ramp("1a2a3e", "4a5a72", "9ab0c8"))
    verge(v, MOON[:4], MOON[0], seed=168, cell=6)
    return v


# -- Undersea: a shipwreck, fish, jellyfish, crabs along a rope fence -------------

SEA_ROCK = ramp("0e2a4a", "163a5e", "1e4a70", "2a5a82")


def undersea() -> Venue:
    import critters as K
    v = Venue("undersea")
    v.stands_behind_fence = True
    S = Layer()
    water_sky(S, [(0, "8ad8ec"), (0.25, "5ab8dc"), (0.6, "2e88bc"),
                  (1, "1a5e96")], -24, 150, hexrgb("8ad0e8"), seed=170)
    for (x, y, d, sc_) in ((120, 70, 1, 1.0), (620, 92, -1, 0.9), (880, 40, -1, 1.1)):
        K.fish(S, x, y, ramp("1e5a8a", "3a7aaa", "5a9ac4"), d=d, s=sc_)
    bubbles(S, -40, 1000, 0, 150, 70, hexrgb("c8f0fc"), seed=171)
    v.add("sky", S, 0.2)
    F = Layer()
    moon_ridge(F, -60, 1040, 158, 16, 46, ramp("123a62", "1a4a74", "225884", "2a6694"),
               seed=172, step=(50, 120))
    shipwreck(F, 380, 150, 210, 96, ramp("0e2a4a", "163c62", "23527a"))
    K.jellyfish(F, 70, 52, ramp("a04a90", "e080c8", "f8b0e0", "fff0fa"), s=1.3)
    K.jellyfish(F, 930, 86, ramp("6a4aa0", "a080e0", "c8b0f8", "f0e8ff"), s=1.1)
    K.turtle(F, 240, 64, ramp("2a4a1a", "4a7a2a", "7aa040", "a0c060"),
             ramp("3a6a4a", "6aa080", "a0d0a8"), s=1.3)
    v.add("far", F, 0.4)
    T = Layer()
    moon_ridge(T, -60, 1040, 178, 6, 22, SEA_ROCK, seed=173, step=(30, 70))
    for i, (x, h) in enumerate(((20, 120), (44, 90), (150, 100), (330, 80), (600, 90),
                                (780, 110), (900, 130), (930, 96), (1000, 110))):
        kelp(T, x, 176, h, ramp("1a4a2a", "2e7a3a", "52a64a"), seed=180 + i)
    for i, x in enumerate((90, 420, 700, 860)):
        coral_tubes(T, x, 176, ramp("8a1a2a", "d0383e", "f06a5a", "ff9a80"), seed=190 + i)
    for i, x in enumerate((250, 520, 960)):
        coral_fan(T, x, 176, 40, 30, ramp("6a2a7a", "a84ab0", "d07ad8"), seed=195 + i)
    v.add("trees", T, 0.6)
    P = Layer()
    reg = P.rect_mask(-48, 158, 1008, 192)
    n = fbm(P.h, P.w, 6, 175, 2)
    sand = ramp("b89a62", "d0b478", "e2c890", "eedaa8")
    P.fill_where(reg, np.array(sand[:3], np.uint8)[np.clip((n * 3).astype(int), 0, 2)])
    P.fill(P.rect_mask(-48, 158, 1008, 159), sand[3])
    brain_coral(P, 300, 170, 30, 14, ramp("8a6a1a", "c89a2a", "f0c84a", "fae08a"))
    coral_tubes(P, 860, 170, ramp("8a1a5a", "d0388a", "f06ab0", "ff9ad0"), seed=176)
    K.octopus(P, 100, 182, ramp("4a1a6a", "7a3aa8", "a86ad0", "d0a0f0"), s=1.3)
    K.crab(P, 170, 182, ramp("7a1a14", "c83a24", "f06a40", "ffa070"), s=1.3)
    K.pufferfish(P, 238, 168, ramp("8a6a1a", "d0a828", "f0d050", "fff090"), s=1.2)
    K.seahorse(P, 716, 180, ramp("8a3a10", "d07020", "f0a040", "ffd080"), d=-1, s=1.3)
    K.starfish(P, 750, 182, ramp("a83a10", "f07a30", "ffb060"), s=1.1)
    K.crab(P, 800, 182, ramp("8a3a10", "d86a1a", "f8a040", "ffd080"), d=-1, s=1.2)
    K.octopus(P, 920, 182, ramp("6a1a2a", "a83a4a", "d86a7a", "f8a0b0"), d=-1, s=1.2)
    v.add("stands", P, 1.0)
    stand_seats(v, (360, 466, 570, 676), 186)            # clear of the posts
    v.watcher = {"x": 676, "y": 186, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (75, 300, 540, 765, 955, 1260)] + [990]
    rope_fence(B, -48, 1008, 138, 190, posts, ramp("1e3e5a", "c8b080", "8a7450"),
               ramp("3a2618", "6a4a2e", "8e663e", "b08a58"), spacing=8)
    B.fill(B.rect_mask(-48, 186, 1008, 190), hexrgb("a88c5a"))
    B.fill(B.rect_mask(-48, 186, 1008, 187), hexrgb("d0b47a"))
    v.add("fence", B, 1.0)
    ground_band(v, 188, preset_court("14828c", "223470", "e2cc96", "ffffff"),
                seed=177, speckle=(0.004, hexrgb("b89a62")))
    front_fence(v, hexrgb("b89a62"), ramp("0e2a2c", "164a3a", "226a44", "38884a",
                                           "5aa854", "84c460"),
                seed=178, posts_mock=(105, 440, 900, 1250))
    verge(v, sand, hexrgb("a88c5a"), seed=179)
    return v


# -- Gym: indoors (ADR-078): a lit ceiling, banners and a scoreboard, bleachers
# behind a divider net, a maple floor --------------------------------------------

MAPLE_FLOOR = ramp("a06a38", "b67c46", "c88c52", "d69a5e", "e2a86c")


def gym() -> Venue:
    v = Venue("gym")
    v.stands_behind_fence = True
    # the ceiling: a dark deck, steel trusses, rows of hanging lights
    S = Layer()
    sky_gradient(S, [(0, "141822"), (0.5, "1e2430"), (1, "2c3442")], y0=-24, y1=130)
    for x in range(-60, 1040, 120):
        for k in range(0, 120, 30):
            S.fill(S.line_mask([(x + k, 4), (x + k + 30, 40)], 2), hexrgb("3a4252"))
        S.fill(S.rect_mask(x, 2, x + 122, 6), hexrgb("46505e"))
        S.fill(S.rect_mask(x, 38, x + 122, 42), hexrgb("46505e"))
    for row, (y, w) in enumerate(((54, 34), (82, 44))):
        for k in range(8 + row):
            x = 40 + k * (900 / (7 + row)) + (row * 30)
            S.fill(S.rect_mask(x - 1, 42, x + 1, y - 4), hexrgb("2a303a"))
            S.fill(S.rect_mask(x - w / 2, y - 4, x + w / 2, y + 2), hexrgb("3c4450"))
            S.fill(S.rect_mask(x - w / 2 + 2, y + 1, x + w / 2 - 2, y + 4), hexrgb("fff4d0"))
    v.add("sky", S, 0.2)
    # the far wall's top: painted block, championship banners, the scoreboard
    F = Layer()
    wall = F.rect_mask(-48, 96, 1008, 150)
    rows = ((np.arange(F.h) // 7) % 2)[:, None] * 0.12
    F.fill_where(wall, np.array(ramp("aab2be", "b8c0ca", "c6ccd4"), np.uint8)[
        np.clip(((fbm(F.h, F.w, 10, 180, 2) * 0.5 + rows + 0.2) * 3).astype(int), 0, 2)])
    banners = (("1e3a6e", "fbe46a", "93"), ("c83a32", "f4f0e6", "92"), ("2e7a48", "fbe46a", "91"),
               ("1e3a6e", "f4f0e6", "90"), ("c83a32", "fbe46a", "89"))
    for k, (cloth, trim, year) in enumerate(banners):
        x = 90 + k * 64 if k < 3 else 690 + (k - 3) * 64 + 64
        F.fill(F.poly_mask([(x - 20, 100), (x + 20, 100), (x + 20, 136), (x, 144), (x - 20, 136)]),
               hexrgb(cloth))
        F.fill(F.rect_mask(x - 20, 100, x + 20, 103), hexrgb(trim))
        stamp_text(F, year, x - 9, 116, hexrgb(trim), scale=2)
        F.outline(OUTLINE, F.poly_mask([(x - 20, 100), (x + 20, 100), (x + 20, 136), (x, 144),
                                        (x - 20, 136)]))
    F.fill(F.rect_mask(380, 98, 580, 146), hexrgb("101216"))                # the scoreboard
    F.fill(F.rect_mask(384, 102, 576, 142), hexrgb("1c2026"))
    stamp_text(F, "HOME", 398, 106, hexrgb("e8e4da"), scale=1)
    stamp_text(F, "GUEST", 518, 106, hexrgb("e8e4da"), scale=1)
    stamp_text(F, "11", 398, 118, hexrgb("f84a3a"), scale=2)
    stamp_text(F, "9", 538, 118, hexrgb("f84a3a"), scale=2)
    stamp_text(F, "PICKLEBALL", 450, 106, hexrgb("fbe46a"), scale=1)
    F.outline(OUTLINE, F.rect_mask(380, 98, 580, 146))
    v.add("far", F, 0.4)
    # the wall's foot: the stripe, the pads, an exit
    T = Layer()
    T.fill(T.rect_mask(-48, 146, 1008, 200), hexrgb("b8c0ca"))
    T.fill(T.rect_mask(-48, 148, 1008, 154), hexrgb("1e3a6e"))
    T.fill(T.rect_mask(-48, 154, 1008, 157), hexrgb("c83a32"))
    for x in range(-48, 1008, 40):
        T.fill(T.rect_mask(x + 1, 160, x + 39, 198), hexrgb("24427a"))
        T.fill(T.rect_mask(x + 1, 160, x + 39, 162), hexrgb("3a5c98"))
    T.fill(T.rect_mask(456, 158, 504, 198), hexrgb("6a727c"))              # the doors
    T.fill(T.rect_mask(479, 158, 481, 198), hexrgb("3a4250"))
    T.fill(T.rect_mask(466, 150, 494, 157), hexrgb("1a6a3a"))
    stamp_text(T, "EXIT", 469, 151, hexrgb("bff0c8"), scale=1)
    v.add("trees", T, 0.6)
    # the bleachers, behind the divider net
    P = Layer()
    for (mx0, mx1) in ((40, 420), (940, 1320)):
        x0, x1 = M(mx0, 0)[0], M(mx1, 0)[0]
        seats = bleachers(P, x0, x1, 140, ALU, rows=4)
        for k in range(4):
            v.seats.append({"x": round(x0 + (k + 0.5) * (x1 - x0) / 4), "y": seats[0], "pose": "sit"})
    v.add("stands", P, 1.0)
    v.watcher = {"x": round(M(1180, 0)[0]), "y": 151, "pose": "sit"}
    # the divider net: black mesh from a top band to the floor
    B = Layer()
    chain_link(B, -48, 118, 1008, 190, hexrgb("0e1014"), spacing=5, alpha=150)
    B.fill(B.rect_mask(-48, 114, 1008, 119), hexrgb("1a1e24"))
    B.fill(B.rect_mask(-48, 186, 1008, 190), hexrgb("8a5a30"))
    B.fill(B.rect_mask(-48, 186, 1008, 187), hexrgb("b07a44"))
    v.add("fence", B, 1.0)
    G = ground_band(v, 188, preset_court("b05434", "2e7a48", "d8a868", "ffffff"),   # CLAY, GREEN, MAPLE
                    seed=181, speckle=(0.002, hexrgb("a06a38")))
    # maple boards on the surround: lines along the court, wider apart toward
    # us (the perspective), staggered joints; darker paint, so a recoloured
    # surround keeps them (the court shader scales by brightness)
    floor = (v.roles == C.ROLE["surround"]) | (v.roles == C.ROLE["surround_shade"])
    y, k, rng = 188.0, 0, random.Random(183)
    while y < 620:
        row = int(round(y)) + G.oy
        if 0 <= row < G.h:
            band = floor[row]
            G.a[row, band, :3] = (G.a[row, band, :3] * 0.82).astype(np.uint8)
            gap = 7 + k * 0.9
            x = rng.randint(0, 160) - 48
            while x < 1010:
                col = int(x) + G.ox
                for r in range(row, min(G.h, row + int(gap))):
                    if 0 <= col < G.w and floor[r, col]:
                        G.a[r, col, :3] = (G.a[r, col, :3] * 0.86).astype(np.uint8)
                x += rng.randint(120, 220)
        y += 7 + k * 0.9
        k += 1
    # the near corners: a team bench, a cooler and a ball cart
    Fr = Layer()
    for side, x0 in ((1, 10), (-1, 950)):
        bx0, bx1 = (x0, x0 + 150) if side == 1 else (x0 - 150, x0)
        Fr.fill(Fr.rect_mask(bx0, 520, bx1, 536), hexrgb("1e3a6e"))
        Fr.fill(Fr.rect_mask(bx0, 520, bx1, 523), hexrgb("3a5c98"))
        for lx in (bx0 + 8, bx1 - 14):
            Fr.fill(Fr.rect_mask(lx, 536, lx + 6, 560), hexrgb("2a303a"))
        cx = bx1 + 34 if side == 1 else bx0 - 34
        Fr.fill(Fr.rect_mask(cx - 9, 524, cx + 9, 560), hexrgb("e6e8ea"))
        Fr.fill(Fr.ellipse_mask(cx, 515, 8, 12), hexrgb("5aa0d8"))
        Fr.fill(Fr.ellipse_mask(cx - 3, 511, 2, 5), hexrgb("a8d4f2"))
    Fr.outline(OUTLINE)
    v.add("front", Fr, 1.3)
    verge(v, MAPLE_FLOOR, hexrgb("8a5a30"), seed=182)
    return v


# -- The dinosaur game's levels (ADR-085): its ruined city, its ice wilderness,
# its science lab and its space station, each as a court ------------------------

def surround_marks(v: Venue, G: Layer, seed, kind="cracks", k=0.8):
    """Darken lines into the surround (cracks, plates, deck seams): darker
    paint, so a recoloured surround keeps them (the shader scales by
    brightness), like the GYM's boards."""
    floor = (v.roles == C.ROLE["surround"]) | (v.roles == C.ROLE["surround_shade"])
    rng = random.Random(seed)
    m = np.zeros(floor.shape, bool)
    if kind == "cracks":
        for _ in range(26):
            x, y = rng.uniform(-40, 1000), rng.uniform(196, 590)
            pts = [(x, y)]
            for _ in range(rng.randint(3, 7)):
                x += rng.uniform(-14, 14)
                y += rng.uniform(-2, 8)
                pts.append((x, y))
            m |= G.line_mask(pts, 1)
    else:                                   # plates: rows of seams, wider toward us
        y, i = 188.0, 0
        while y < 620:
            m |= G.rect_mask(-48, y, 1008, y + 1)
            x = (i % 2) * 40 - 48
            while x < 1010:
                m |= G.rect_mask(x, y, x + 1, y + 10 + i * 1.6)
                x += 80
            y += 10 + i * 1.6
            i += 1
    m &= floor
    G.a[m, :3] = (G.a[m, :3] * k).astype(np.uint8)


MOSS = ramp("263a1c", "3e5a22", "6a7e2e")
RUIN_STONE = ramp("3a3448", "5e5462", "8a7c7e", "aa9c94")
RUST = ramp("3a1a14", "6a3020", "9a4a2a", "c87040")


def ruins() -> Venue:
    """The dinosaur game's level 1: a drowned city burning under a purple
    and orange sunset, a broken bridge over the river, mossy pillars and
    rusted girders, the crowd on a mossy wall."""
    v = Venue("ruins")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "1e1440"), (0.28, "3e2266"), (0.52, "8a2e6a"), (0.72, "d8504a"),
                     (0.88, "f08a3a"), (1, "fcc060")], y0=-24, y1=136)
    sun(S, 520, 122, 26, ramp("f8b850", "fbd070", "fde69a", "fff6d0"))
    for (cx, cy, w, h, sd) in ((120, 26, 140, 9, 201), (330, 8, 110, 7, 202), (610, 30, 150, 9, 203),
                               (860, 14, 130, 8, 204), (470, 60, 120, 6, 205), (780, 70, 110, 6, 206),
                               (60, 84, 90, 5, 207)):
        cloud(S, cx, cy, w, h, ramp("5a2a6a", "9a3a6a", "d0545a", "f08a4a"), seed=sd)
    v.add("sky", S, 0.2)
    F = Layer()
    hills(F, -48, 1008, 128, 8, 26, ramp("4a2a6a", "5a3478", "6e3e84"), seed=210)
    tops = ruined_towers(F, -48, 1008, 130, 28, 74, ramp("4a3470", "1c1636", "251d44", "6a4a8a"),
                         hexrgb("f8c060"), seed=211, low=(450, 590))
    water(F, -48, 1008, 128, 160, ramp("2a1e4a", "4a2c64", "7a3a6a", "c0584e"), hexrgb("fcd080"),
          seed=212, reflect=(520, 18, hexrgb("f8b850")))
    arch_bridge(F, -48, 1008, 134, 9, ramp("1a1430", "2a2048", "3e3060"), span=44, gap=(560, 640))
    for i, k in enumerate((3, 14, 29)):
        if k < len(tops):
            x, y = tops[k]
            smoke(F, x, y - 4, 70, ramp("221a30", "2e2440", "3c3050", "4a3c5c"), seed=213 + i)
            fire(F, x, y + 2, 12, 10, ramp("c0301a", "f07020", "fcd050"), seed=216 + i)
    v.add("far", F, 0.4)
    T = Layer()
    rub = moon_ridge(T, -60, 1040, 182, 6, 22, ramp("2a2436", "3a3246", "4a4256", "5e5468"),
                     seed=220, step=(16, 40))
    for (x, w, h, sd) in ((10, 26, 84, 221), (70, 20, 56, 222), (180, 22, 40, 223),
                          (780, 22, 46, 224), (880, 24, 70, 225), (950, 28, 96, 226)):
        stone_pillar(T, x, 176, w, h, RUIN_STONE, moss=MOSS, seed=sd)
    girder(T, (30, 102), (150, 150), 6, RUST)
    girder(T, (820, 160), (930, 112), 6, RUST)
    girder(T, (250, 176), (330, 150), 5, RUST)
    v.add("trees", T, 0.6)
    P = Layer()
    wall = P.rect_mask(-48, 166, 1008, 192)
    n = fbm(P.h, P.w, 6, 230, 2)
    P.fill_where(wall, np.array(RUIN_STONE[:3], np.uint8)[np.clip((n * 3).astype(int), 0, 2)])
    for y in (172, 180):
        P.fill(wall & P.rect_mask(-48, y, 1008, y + 1), RUIN_STONE[0])
    P.fill(P.rect_mask(-48, 165, 1008, 168), MOSS[1])
    P.fill(P.rect_mask(-48, 165, 1008, 166), MOSS[2])
    barrel(P, 286, 168, 14, 20, ramp("6a1414", "a82a24", "d84a3a"), hexrgb("e8e0d0"),
           mark=(hexrgb("f4f0e6"), hexrgb("c8281e")))
    crate(P, 640, 168, 20, ramp("4a2a16", "7a4a26", "a06a3a"))
    crate(P, 662, 168, 14, ramp("4a2a16", "7a4a26", "a06a3a"))
    v.add("stands", P, 1.0)
    stand_seats(v, (140, 210, 340, 400, 470, 560, 720, 780, 850), 180)
    v.watcher = {"x": 780, "y": 180, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (110, 330, 560, 790, 1020, 1240)] + [990]
    fence(B, -48, 1008, 120, 188, posts, hexrgb("3a2a2a"), RUST, spacing=6)
    # the wire's torn: a hole, peeled back
    hole = B.poly_mask([(596, 132), (630, 128), (648, 150), (622, 164), (598, 156)])
    B.a[hole & (B.a[..., :3].sum(axis=2) < 200)] = 0
    B.fill(B.rect_mask(-48, 186, 1008, 190), RUIN_STONE[1])
    B.fill(B.rect_mask(-48, 186, 1008, 187), RUIN_STONE[3])
    v.add("fence", B, 1.0)
    G = ground_band(v, 188, preset_court("60408c", "b05434", "a0a098", "ffffff"),   # PURPLE, CLAY, CONCRETE
                    seed=231, speckle=(0.004, hexrgb("807e78")))
    surround_marks(v, G, 232)
    front_fence(v, hexrgb("807e78"), ramp("14200e", "223418", "34481e", "4e5e26", "6a7a30", "8a9440"),
                seed=233, posts_mock=(105, 440, 900, 1250), wire=hexrgb("3a2a2a"), post=RUST)
    verge(v, ramp("5e5462", "7a7076", "8a7c7e", "9a8e8c"), RUIN_STONE[0], seed=234)
    return v


SNOW = ramp("8a9ac8", "b8c8e8", "dce6f6", "f4f8ff")
ICE_STONE = ramp("262a48", "3a4064", "565e86", "7a84a8")
PINE = ramp("10223a", "1c3a4e", "2c5662")


def glacier() -> Venue:
    """The dinosaur game's ice wilderness: a pink dusk over snowy peaks, a
    frozen castle's spires, a stone aqueduct hung with icicles, snowy
    pines, the crowd in the drifts."""
    v = Venue("glacier")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "141a44"), (0.3, "2a2e6a"), (0.55, "5a4a8a"), (0.75, "b0607a"),
                     (0.9, "e88a70"), (1, "f8b080")], y0=-24, y1=128)
    sun(S, 610, 110, 18, ramp("f8a070", "fbc090", "fde0b8", "fff4e0"))
    for (cx, cy, w, h, sd) in ((150, 30, 150, 7, 241), (420, 14, 120, 6, 242), (700, 40, 160, 7, 243),
                               (900, 20, 110, 6, 244), (300, 66, 100, 5, 245)):
        cloud(S, cx, cy, w, h, ramp("4a3a7a", "8a4a7a", "c86a7a", "f09a8a"), seed=sd)
    v.add("sky", S, 0.2)
    F = Layer()
    peaks(F, -48, 1008, 132, 30, 84, ramp("2a3060", "3e4880", "5a68a8"), SNOW, seed=250)
    ruined_towers(F, 690, 910, 134, 34, 70, ramp("3a4278", "1e2650", "28305e", "6a7ab0"),
                  hexrgb("a8e0ff"), seed=251, lit=0.03, spires=0.9)
    ruined_towers(F, 40, 150, 134, 20, 44, ramp("3a4278", "1e2650", "28305e", "6a7ab0"),
                  hexrgb("a8e0ff"), seed=252, lit=0.02, spires=0.9)
    hills(F, -48, 1008, 150, 10, 20, ramp("7a8ab8", "9aaad4", "c0cceb"), seed=253)
    arch_bridge(F, 230, 690, 92, 16, ICE_STONE, span=34)
    icicles(F, 232, 688, 108, 9, ramp("6a9ad8", "9ac8f4", "e0f4ff"), seed=254)
    F.fill(F.rect_mask(230, 90, 690, 93), SNOW[3])
    for x in range(247, 690, 34):                       # the piers, down to the snow
        F.fill(F.rect_mask(x - 4, 108, x + 4, 150), ICE_STONE[1])
        F.fill(F.rect_mask(x - 4, 108, x - 2, 150), ICE_STONE[3])
    v.add("far", F, 0.4)
    T = Layer()
    rng = random.Random(260)
    for x in range(-60, 1040, 17):
        h = rng.uniform(40, 82) if (x < 260 or x > 700) else rng.uniform(26, 50)
        pine(T, x + rng.randint(-5, 5), 172, h, PINE, snow=SNOW, seed=261 + x)
    for (x, w, h, sd) in ((-10, 40, 90, 270), (970, 44, 100, 271)):
        stone_pillar(T, x, 176, w, h, ICE_STONE, snow=SNOW, seed=sd, broken=False)
    snow_bank(T, -48, 1008, 164, 190, SNOW, seed=272)
    v.add("trees", T, 0.6)
    P = Layer()
    snow_bank(P, -48, 1008, 168, 192, SNOW, seed=280)
    crate(P, 640, 180, 20, ramp("3a2a20", "5a4030", "7a5a40"))
    P.fill(P.ellipse_mask(650, 160, 12, 4) & P.rect_mask(638, 154, 662, 161), SNOW[2])
    icicles(P, 640, 660, 160, 5, ramp("6a9ad8", "9ac8f4", "e0f4ff"), seed=281)
    v.add("stands", P, 1.0)
    stand_seats(v, (130, 200, 330, 400, 470, 560, 720, 780, 850), 184)
    v.watcher = {"x": 780, "y": 184, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (110, 330, 560, 790, 1020, 1240)] + [990]
    fence(B, -48, 1008, 120, 188, posts, hexrgb("4a5a8a"), ICE_STONE[1:], spacing=6)
    B.fill(B.rect_mask(-48, 116, 1008, 120), SNOW[2])
    B.fill(B.rect_mask(-48, 116, 1008, 117), SNOW[3])
    icicles(B, -48, 1008, 120, 10, ramp("6a9ad8", "9ac8f4", "e0f4ff"), seed=290)
    for x in posts:
        B.fill(B.ellipse_mask(x + 0.5, 113, 5, 3), SNOW[3])
    B.fill(B.rect_mask(-48, 186, 1008, 190), SNOW[1])
    B.fill(B.rect_mask(-48, 186, 1008, 187), SNOW[3])
    v.add("fence", B, 1.0)
    G = ground_band(v, 188, preset_court("265ca8", "223470", "ecf0f6", "ffffff"),   # BLUE, NAVY, SNOW
                    seed=291, speckle=(0.004, hexrgb("c8d0e0")))
    front_fence(v, hexrgb("c8d0e0"), ramp("3a4a7a", "6a7aa8", "9aa8d0", "c8d4ee", "e8eef8", "ffffff"),
                seed=292, posts_mock=(105, 440, 900, 1250), wire=hexrgb("4a5a8a"), post=ICE_STONE[1:])
    verge(v, SNOW, SNOW[0], seed=293)
    return v


STEEL = ramp("1a2228", "2e3a42", "4a5862", "6e7e88")
LAB_WALL = ramp("0c1a1e", "12262a", "1a3236")
TANK_GLASS = ramp("0e3a1e", "1e6a2e", "3a9a3a", "6ac850", "b8f4a0")
SAFETY = ramp("8a5a0a", "d09a1a", "f4c838")


def corner_props(Fr: Layer, items):
    """The near corners' clutter, drawn over the players: [(kind, x, ...)]."""
    for it in items:
        kind, x = it[0], it[1]
        if kind == "barrel":
            barrel(Fr, x, 538, 30, 44, it[2], it[3], mark=it[4] if len(it) > 4 else None)
        elif kind == "crate":
            crate(Fr, x, 538, it[2], it[3])
        elif kind == "console":
            console(Fr, x, 538, 70, 60, STEEL, it[2], it[3], seed=x)


def lab() -> Venue:
    """The dinosaur game's science lab, indoors: pipes and hanging lamps,
    green tanks with dinosaur skeletons, a hazard-striped catwalk,
    consoles, a raptor loose among the crowd, a steel floor."""
    import critters as K
    v = Venue("lab")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "060c10"), (0.6, "0c1a20"), (1, "12262c")], y0=-24, y1=120)
    pipe_run(S, [(-60, 6), (1020, 6)], 8, STEEL)
    pipe_run(S, [(-60, 20), (300, 20), (300, 34), (1020, 34)], 6, ramp("1a2a22", "2e4a3a", "4a6e52"))
    for x in (90, 330, 600, 860):                       # hanging lamps and their light
        S.fill(S.rect_mask(x - 1, 6, x + 1, 40), STEEL[0])
        S.fill(S.poly_mask([(x - 16, 40), (x + 16, 40), (x + 10, 34), (x - 10, 34)]), STEEL[2])
        S.fill(S.rect_mask(x - 14, 40, x + 14, 42), hexrgb("f4f0c0"))
        cone = S.poly_mask([(x - 14, 42), (x + 14, 42), (x + 44, 160), (x - 44, 160)])
        yy, xx = np.mgrid[0:S.h, 0:S.w]
        S.fill(cone & ((xx + yy) % 2 == 0), hexrgb("1e3a3a"))
    v.add("sky", S, 0.2)
    F = Layer()
    wall = F.rect_mask(-48, 40, 1008, 160)
    F.fill(wall, LAB_WALL[1])
    for x in range(-48, 1008, 48):                      # wall panels
        F.fill(F.rect_mask(x, 40, x + 1, 160), LAB_WALL[0])
        F.fill(F.rect_mask(x + 1, 40, x + 2, 160), LAB_WALL[2])
    F.fill(F.rect_mask(-48, 96, 1008, 97), LAB_WALL[0])
    trex = lambda L: K.trex(L, 330, 136, ramp("000000", "000000", "000000"), d=1, s=1.9)
    tank(F, 330, 150, 92, 124, TANK_GLASS, STEEL, specimen=trex, seed=300)
    rap = lambda cx: (lambda L: K.raptor(L, cx, 128, ramp("000000", "000000", "000000"), d=-1, s=1.5))
    tank(F, 640, 150, 64, 100, TANK_GLASS, STEEL, specimen=rap(642), seed=301)
    tank(F, 880, 150, 76, 116, TANK_GLASS, STEEL, specimen=lambda L: K.brachiosaurus(
        L, 868, 132, ramp("000000", "000000", "000000"), d=1, s=0.8), seed=302)
    tank(F, 90, 150, 56, 90, TANK_GLASS, STEEL, seed=303)
    # the catwalk between the tanks
    F.fill(F.rect_mask(400, 88, 600, 94), STEEL[1])
    hazard(F, 400, 94, 600, 98)
    safety_rail(F, 400, 600, 72, 88, (404, 470, 530, 596), SAFETY, mid=True)
    v.add("far", F, 0.4)
    T = Layer()
    T.fill(T.rect_mask(-48, 120, 1008, 190), STEEL[0])
    pipe_run(T, [(-60, 128), (1020, 128)], 6, STEEL)
    for x in (40, 230, 470, 700, 930):
        pipe_run(T, [(x, 128), (x, 180)], 5, ramp("1a2a22", "2e4a3a", "4a6e52"))
    for i, x in enumerate((70, 260, 520, 740)):
        console(T, x, 176, 60, 46, STEEL, ramp("0e2a1a", "5af08a"), [hexrgb("f04a3a"), hexrgb("5af08a"),
                hexrgb("f4c838")], seed=310 + i)
    T.fill(T.ellipse_mask(160, 140, 5, 5), hexrgb("f04a3a"))      # the warning light
    T.fill(T.ellipse_mask(159, 139, 2, 2), hexrgb("ffb0a0"))
    door = T.rect_mask(860, 132, 910, 180)
    T.fill(door, STEEL[1])
    hazard(T, 860, 172, 910, 180)
    T.fill(T.rect_mask(872, 140, 898, 156), hexrgb("2a1414"))
    T.fill(T.rect_mask(882, 144, 888, 150), hexrgb("f04a3a"))
    T.outline(OUTLINE, door)
    v.add("trees", T, 0.6)
    P = Layer()
    deck = P.rect_mask(-48, 166, 1008, 192)
    P.fill(deck, STEEL[1])
    yy, xx = np.mgrid[0:P.h, 0:P.w]
    P.fill(deck & (xx % 4 == 0) & (yy % 4 == 0), STEEL[0])        # the grating
    hazard(P, -48, 164, 1008, 168)
    K.raptor(P, 160, 172, ramp("3a1e5a", "6a3a8a", "9a62b4", "c49ad8"), d=1, s=1.5)
    K.raptor(P, 820, 172, ramp("1e3a1a", "3a6a2a", "62a040", "9ad070"), d=-1, s=1.2)
    barrel(P, 240, 172, 14, 20, ramp("6a1414", "a82a24", "d84a3a"), hexrgb("e8e0d0"),
           mark=(hexrgb("f4f0e6"), hexrgb("c8281e")))
    barrel(P, 258, 172, 14, 20, ramp("1a3a1a", "2e6a2e", "4a9a3a"), hexrgb("2a2a2a"),
           mark=(hexrgb("e8e0d0"), hexrgb("2e6a2e")))
    crate(P, 870, 172, 18, ramp("4a2a16", "7a4a26", "a06a3a"))
    v.add("stands", P, 1.0)
    stand_seats(v, (330, 400, 470, 560, 640, 720), 180)
    v.watcher = {"x": 720, "y": 180, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (110, 330, 560, 790, 1020, 1240)] + [990]
    safety_rail(B, -48, 1008, 140, 186, posts, SAFETY)
    hazard(B, -48, 184, 1008, 190)
    v.add("fence", B, 1.0)
    G = ground_band(v, 188, preset_court("1c1c24", "2e7a48", "46484e", "fade46"),   # BLACK, GREEN, ASPHALT, YELLOW
                    seed=320, speckle=(0.003, hexrgb("3a3c42")))
    surround_marks(v, G, 321, kind="plates", k=0.75)
    Fr = Layer()
    corner_props(Fr, [("barrel", 30, ramp("6a1414", "a82a24", "d84a3a"), hexrgb("e8e0d0"),
                       (hexrgb("f4f0e6"), hexrgb("c8281e"))),
                      ("barrel", 66, ramp("1a3a1a", "2e6a2e", "4a9a3a"), hexrgb("2a2a2a")),
                      ("crate", 86, 40, ramp("4a2a16", "7a4a26", "a06a3a")),
                      ("console", 860, ramp("0e2a1a", "5af08a"), [hexrgb("f04a3a"), hexrgb("5af08a")]),
                      ("barrel", 940, ramp("6a1414", "a82a24", "d84a3a"), hexrgb("e8e0d0"))])
    v.add("front", Fr, 1.3)
    verge(v, ramp("1e2a30", "222e34"), STEEL[2], seed=322, cell=24)
    hazard(v.layers[-1][1], -48, 500, 1008, 506)
    return v


HULL = ramp("141822", "222a38", "343e50", "4e5a6e")
LIGHT = ramp("8a3a10", "f07a20", "ffc070")


def drone(L: Layer, x, y, s=1.0):
    """A hovering robot drone: a round shell, a red eye, a thruster flame."""
    body = L.ellipse_mask(x, y, 9 * s, 8 * s) | L.rect_mask(x - 12 * s, y - 2 * s, x + 12 * s, y + 2 * s)
    solid(L, body, ramp("3a4252", "6a7488", "9aa4b8", "c8d0dc"), OUTLINE)
    L.fill(L.ellipse_mask(x + 3 * s, y - 1 * s, 3 * s, 3 * s), hexrgb("f04a3a"))
    L.px(x + 2 * s, y - 2 * s, hexrgb("ffd0c0"))
    L.fill(L.poly_mask([(x - 3 * s, y + 8 * s), (x, y + 16 * s), (x + 3 * s, y + 8 * s)]), LIGHT[1])


def station() -> Venue:
    """The dinosaur game's space station, indoors: big windows on a nebula,
    a ringed planet, asteroids and a wrecked station; orange-lit girders,
    consoles, an orange railing, an astronaut and a drone on the deck."""
    import critters as K
    v = Venue("station")
    v.stands_behind_fence = True
    S = Layer()
    sky_gradient(S, [(0, "06061a"), (0.5, "140e36"), (1, "2a1a52")], y0=-24, y1=150)
    nebula(S, 50, 70, ramp("1e1a4a", "3a2470", "6a3a8a", "a04a8a"), seed=330, slope=0.12)
    stars(S, -24, 170, 0.006, [hexrgb("6a6a9a"), hexrgb("b0b0d8"), hexrgb("ffffff")], seed=331,
          twinkles=((120, 24), (470, 10), (700, 70), (900, 30)))
    planet(S, 250, 96, 46, ramp("142a5a", "1e4a8a", "3a70b8", "7aa8e0"), seed=332,
           ring=(80, 12, ramp("4a3a6a", "8a7aa8", "c8b8e0")))
    planet(S, 690, 30, 10, ramp("6a6a7a", "a0a0b0", "d0d0dc"))
    # the wreck: a broken ring and its towers
    wr = ramp("1a1a2a", "2a2a40", "3e3e58", "5a5a78")
    S.fill(S.ellipse_mask(780, 90, 70, 14) & ~S.ellipse_mask(780, 90, 62, 9) &
           ~S.rect_mask(800, 70, 830, 110), wr[1])
    for (x, h) in ((760, 50), (775, 70), (792, 40), (808, 60)):
        S.fill(S.rect_mask(x, 90 - h, x + 8, 100), wr[2])
        S.fill(S.rect_mask(x, 90 - h, x + 2, 100), wr[3])
    for i, (x, y, r) in enumerate(((120, 30, 7), (420, 60, 11), (560, 24, 6), (900, 110, 13),
                                   (640, 110, 8), (40, 120, 9), (980, 40, 6))):
        asteroid(S, x, y, r, ramp("1e1a2a", "3a3448", "5a5268", "7a7088"), seed=340 + i)
    v.add("sky", S, 0.2)
    F = Layer()
    hull = F.rect_mask(-48, -24, 1008, 160)
    win = np.zeros_like(hull)
    for (x0, x1) in ((40, 440), (520, 920)):
        win |= F.poly_mask([(x0 + 14, 14), (x1 - 14, 14), (x1, 28), (x1, 104), (x1 - 14, 118),
                            (x0 + 14, 118), (x0, 104), (x0, 28)])
    struts = np.zeros_like(hull)
    for x in (140, 240, 340, 620, 720, 820):
        struts |= F.rect_mask(x - 3, 14, x + 3, 118)
    win &= ~struts
    F.fill(hull & ~win, HULL[1])
    for x in range(-48, 1008, 56):                      # hull plates
        F.fill(hull & ~win & F.rect_mask(x, -24, x + 1, 160), HULL[0])
        F.fill(hull & ~win & F.rect_mask(x + 1, -24, x + 2, 160), HULL[2])
    for y in (-2, 132, 150):
        F.fill(hull & ~win & F.rect_mask(-48, y, 1008, y + 1), HULL[0])
    F.fill(grow_(win) & ~win, HULL[3])
    F.fill(grow_(grow_(win)) & ~grow_(win), HULL[0])
    for (x0, x1) in ((40, 440), (520, 920)):
        F.fill(F.rect_mask(x0 + 20, 6, x1 - 20, 9), LIGHT[1])     # light strips
        F.fill(F.rect_mask(x0 + 20, 6, x1 - 20, 7), LIGHT[2])
        F.fill(F.rect_mask(x0 + 20, 124, x1 - 20, 127), LIGHT[1])
    for x in (-20, 480, 980):
        F.fill(F.rect_mask(x - 2, 20, x + 3, 110), LIGHT[1])
        F.fill(F.rect_mask(x - 2, 20, x - 1, 110), LIGHT[2])
    v.add("far", F, 0.4)
    T = Layer()
    T.fill(T.rect_mask(-48, 132, 1008, 190), HULL[0])
    for x in range(-48, 1008, 64):
        T.fill(T.rect_mask(x, 132, x + 1, 190), HULL[1])
    pipe_run(T, [(-60, 138), (1020, 138)], 6, HULL[1:])
    for i, x in enumerate((60, 250, 600, 800)):
        console(T, x, 176, 64, 40, HULL[1:], ramp("0e2030", "4ad8f0"),
                [hexrgb("f07a20"), hexrgb("4ad8f0"), hexrgb("f04a3a")], seed=360 + i)
    for x in (180, 470, 730, 930):
        T.fill(T.rect_mask(x - 2, 146, x + 3, 176), LIGHT[1])
        T.fill(T.rect_mask(x - 2, 146, x - 1, 176), LIGHT[2])
    crate(T, 400, 176, 22, ramp("4a2a16", "7a4a26", "a06a3a"))
    crate(T, 424, 176, 16, ramp("2a3040", "4a5268", "6a7690"))
    v.add("trees", T, 0.6)
    P = Layer()
    deck = P.rect_mask(-48, 166, 1008, 192)
    P.fill(deck, HULL[2])
    for x in range(-48, 1008, 32):
        P.fill(deck & P.rect_mask(x, 166, x + 1, 192), HULL[1])
    P.fill(P.rect_mask(-48, 166, 1008, 168), LIGHT[1])
    K.astronaut(P, 230, 172, ramp("8a92a4", "c4ccd8", "eef2f8", "ffffff"), ramp("1a2a5a", "4a7ad8"),
                d=1, s=1.3, wave=True)
    drone(P, 860, 128, s=1.2)
    v.add("stands", P, 1.0)
    stand_seats(v, (150, 330, 400, 470, 560, 640, 720, 800), 180)
    v.watcher = {"x": 720, "y": 180, "pose": "stand"}
    B = Layer()
    posts = [-30] + [M(x, 0)[0] for x in (110, 330, 560, 790, 1020, 1240)] + [990]
    safety_rail(B, -48, 1008, 140, 186, posts, LIGHT)
    for x in posts:
        B.fill(B.rect_mask(x - 2, 134, x + 3, 140), hexrgb("4ad8f0"))
    B.fill(B.rect_mask(-48, 184, 1008, 190), HULL[1])
    B.fill(B.rect_mask(-48, 184, 1008, 185), LIGHT[1])
    v.add("fence", B, 1.0)
    G = ground_band(v, 188, preset_court("4e5662", "c45c1c", "46484e", "ffffff"),   # SLATE, ORANGE, ASPHALT
                    seed=370, speckle=(0.003, hexrgb("3a3c42")))
    surround_marks(v, G, 371, kind="plates", k=0.75)
    Fr = Layer()
    corner_props(Fr, [("crate", 10, 44, ramp("4a2a16", "7a4a26", "a06a3a")),
                      ("crate", 56, 30, ramp("2a3040", "4a5268", "6a7690")),
                      ("console", 870, ramp("0e2030", "4ad8f0"), [hexrgb("f07a20"), hexrgb("4ad8f0")])])
    v.add("front", Fr, 1.3)
    verge(v, ramp("1a2030", "1e2434"), LIGHT[1], seed=372, cell=24)
    return v


VENUES = {"park": park, "lakeside": lakeside, "sunset": sunset,
          "dinosaur": dinosaur, "space": space, "undersea": undersea, "gym": gym,
          "ruins": ruins, "glacier": glacier,
          "lab": lab, "station": station}


# ADR-088: the painted venues, cut from generated paintings (painted.py)
import painted  # noqa: E402

VENUES.update(painted.VENUES)
