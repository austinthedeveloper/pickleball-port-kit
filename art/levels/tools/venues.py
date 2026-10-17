"""The three venues from the level mocks, as parallax layers.

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
from pix import Layer, bush, fbm, hexrgb, ramp, tree
from scenery import (OUTLINE, M, ball_icon, bin_can, bleachers, cloud, fence, flowers,
                     hedge_band, house, notice_board, park_bench, pavers, sign,
                     skyline, sky_gradient, sun, towel_and_bag, tree_icon,
                     tree_line, water)


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
                gate=None, path=None):
    """Near fence and corner bushes (drawn over the players)."""
    F = Layer()
    top = 461
    xs = [M(x, 0)[0] for x in posts_mock]
    gx0, gx1 = gate if gate else (None, None)
    # mesh in segments, skipping a gate gap
    segs = [(-48, 1008)] if gate is None else [(-48, gx0), (gx1, 1008)]
    for a, b in segs:
        fence(F, a, b, top, 600, [x for x in xs if a <= x <= b], FENCE_WIRE,
              FENCE_POST, spacing=7)
    # posts get a little taller/thicker (closer)
    for x in xs:
        p = F.rect_mask(x - 4, top - 8, x + 5, 600)
        F.fill(p, FENCE_POST[1])
        F.fill(F.rect_mask(x - 4, top - 8, x - 2, 600), FENCE_POST[2])
        F.fill(F.rect_mask(x + 3, top - 8, x + 5, 600), FENCE_POST[0])
        cap = F.rect_mask(x - 5, top - 11, x + 6, top - 6)
        F.fill(cap, FENCE_POST[2])
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
    skyline(F, 250, 720, 112, 18, 50, ramp("8fbddd", "74a8cb", "6699bb",
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
    S = Layer()
    sky_gradient(S, [(0, "3f86e0"), (0.5, "5c9ef0"), (1, "a9cdf2")],
                 y0=-24, y1=110)
    for (cx, cy, w, h, sd) in ((520, 8, 60, 14, 61), (700, 14, 90, 18, 62),
                               (880, 30, 40, 10, 63)):
        cloud(S, cx, cy, w, h, ramp("9cc6f3", "cfe3f6", "eef5f8", "ffffff"),
              seed=sd)
    v.add("sky", S, 0.2)
    # far: tree line on the far shore, houses, the lake
    F = Layer()
    tree_line(F, 300, 720, 84, 22, 40, ramp("1d4a45", "2c6250", "437c56",
                                            "62965c"), BARK, seed=71,
              step=(14, 24))
    for (x, w, h, sd) in ((420, 22, 12, 0), (450, 16, 10, 1), (568, 24, 13, 2),
                          (600, 18, 10, 3)):
        house(F, x, 88, w, h, ramp("6b6a62", "b8b2a0", "d9d2bd"),
              ramp("6e3a2e", "9a5440"))
    water(F, 320, 700, 88, 116, ramp("3e6f9a", "4f84b3", "5f95c4", "79abd6"),
          hexrgb("d8ecf8"), seed=72)
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
    skyline(F, 330, 660, 100, 14, 40, ramp("3a2f5c", "4a3a70", "56407a",
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


VENUES = {"park": park, "lakeside": lakeside, "sunset": sunset}
