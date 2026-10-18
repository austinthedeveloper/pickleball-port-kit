"""The six venues as parallax layers: three from the level mocks (park,
lakeside, sunset) and ADR-046's fun venues (dinosaur, space, undersea).

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
from scenery import (OUTLINE, M, ball_icon, bin_can, bleachers, brain_coral, bubbles,
                     cloud, coral_fan, coral_tubes, dome, fence, fern_band, flowers,
                     hedge_band, house, kelp, lamp_post, moon_ridge, nebula,
                     notice_board, palisade, palm, park_bench, pavers, planet,
                     rocket, rope_fence, shipwreck, sign, skyline, sky_gradient,
                     smoke, stars, sun, towel_and_bag, tree_icon, tree_line,
                     volcano, water, water_sky)


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
    v.stands_behind_fence = True
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


VENUES = {"park": park, "lakeside": lakeside, "sunset": sunset,
          "dinosaur": dinosaur, "space": space, "undersea": undersea}
