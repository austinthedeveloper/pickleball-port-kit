"""The fun venues' onlookers (ADR-046): dinosaurs, aliens, astronauts,
and sea creatures, built from shapes like the rest of the kit and lit by
pix.solid. Each stands on base_y at x (its centre), faces right (d=1) or
left (d=-1), and is sized by s (1.0 is about a standing spectator)."""
from __future__ import annotations

import math

import numpy as np

from pix import Layer, hexrgb, ramp, shrink, solid
from scenery import OUTLINE

EYE = hexrgb("0b1626")
WHITE = hexrgb("f4f4ec")


class Frame:
    """Local coordinates: dx right along the facing, dy up from the feet."""

    def __init__(self, L: Layer, x, base_y, d=1, s=1.0):
        self.L, self.x, self.b, self.d, self.s = L, x, base_y, d, s

    def X(self, dx):
        return self.x + dx * self.d * self.s

    def Y(self, dy):
        return self.b - dy * self.s

    def P(self, dx, dy):
        return (self.X(dx), self.Y(dy))

    def poly(self, pts):
        return self.L.poly_mask([self.P(*p) for p in pts])

    def ell(self, dx, dy, rx, ry):
        return self.L.ellipse_mask(self.X(dx), self.Y(dy), rx * self.s, ry * self.s)

    def rect(self, dx0, dy0, dx1, dy1):
        xa, xb = sorted((self.X(dx0), self.X(dx1)))
        ya, yb = sorted((self.Y(dy0), self.Y(dy1)))
        return self.L.rect_mask(round(xa), round(ya), round(xb), round(yb))

    def line(self, pts, w=1):
        return self.L.line_mask([self.P(*p) for p in pts], max(1, round(w * self.s)))

    def dot(self, dx, dy, rgb, n=1):
        x, y = round(self.X(dx)), round(self.Y(dy))
        self.L.fill(self.L.rect_mask(x, y, x + n, y + n), rgb)


def _legs(f: Frame, xs, top, w=3):
    m = np.zeros((f.L.h, f.L.w), bool)
    for dx in xs:
        m |= f.rect(dx - w / 2, top, dx + w / 2, 0)
    return m


# -- Dinosaurs -----------------------------------------------------------------

def stegosaurus(L, x, base, rmp, plate, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    plates = np.zeros((L.h, L.w), bool)
    for dx, h in ((-11, 6), (-6, 9), (-1, 10), (4, 9), (9, 6)):
        plates |= f.poly([(dx - 3, 16), (dx, 16 + h), (dx + 3, 16)])
    solid(L, plates, plate, OUTLINE, rim=1)
    back = _legs(f, (-9, 7), 8, 4)
    solid(L, back, rmp[:2] + [rmp[1]], OUTLINE, rim=1)
    body = f.ell(0, 13, 14, 7) | f.poly([(-11, 16), (-28, 7), (-26, 5), (-10, 9)])
    body |= f.poly([(10, 15), (19, 11), (19, 7), (10, 9)]) | f.ell(19, 9, 4, 3)
    body |= _legs(f, (-5, 10), 9, 4)
    solid(L, body, rmp, OUTLINE)
    f.dot(20, 10, EYE)


def triceratops(L, x, base, rmp, frill, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    fr = f.ell(10, 15, 7, 9)
    solid(L, fr, frill, OUTLINE)
    body = f.ell(-2, 12, 13, 8) | f.poly([(-12, 14), (-22, 9), (-12, 9)])
    body |= f.poly([(8, 16), (20, 12), (21, 7), (8, 8)])
    body |= _legs(f, (-9, -3, 4, 9), 8, 4)
    solid(L, body, rmp, OUTLINE)
    horns = f.poly([(14, 14), (24, 19), (15, 12)]) | f.poly([(19, 11), (25, 13), (20, 10)])
    solid(L, horns, ramp("b8ab8a", "e8dcbc", "fff6e0"), OUTLINE, rim=1)
    f.dot(15, 12, EYE)


def raptor(L, x, base, rmp, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    body = f.ell(0, 16, 8, 5) | f.poly([(-6, 18), (-22, 22), (-21, 20), (-6, 13)])
    body |= f.poly([(4, 18), (9, 28), (13, 27), (8, 16)])                # neck
    body |= f.ell(12, 29, 5, 3) | f.poly([(12, 31), (20, 28), (19, 26), (12, 26)])
    body |= f.line([(-2, 14), (-4, 7), (-1, 0)], 3) | f.line([(3, 13), (4, 6), (6, 0)], 3)
    body |= f.line([(6, 18), (11, 15)], 2)
    solid(L, body, rmp, OUTLINE)
    f.dot(13, 30, EYE)


def trex(L, x, base, rmp, d=1, s=1.0):
    """A T. rex peeking over: the head and shoulders, a big grin."""
    f = Frame(L, x, base, d, s)
    body = f.ell(-2, 18, 12, 14) | f.poly([(-6, 30), (6, 40), (14, 36), (6, 24)])
    body |= f.ell(10, 40, 9, 7) | f.poly([(8, 44), (26, 42), (27, 35), (10, 34)])
    body |= f.line([(8, 22), (14, 19), (15, 21)], 2)
    body |= f.rect(-9, 6, -3, 0) | f.rect(3, 6, 9, 0)
    solid(L, body, rmp, OUTLINE)
    L.fill(f.line([(12, 37), (26, 37)], 1), OUTLINE)
    for dx in (14, 17, 20, 23):
        f.dot(dx, 36, WHITE)
    f.dot(12, 43, EYE, 2)
    L.fill(f.ell(1, 14, 5, 8) & shrink(shrink(body)), rmp[2])


def brachiosaurus(L, x, base, rmp, d=1, s=1.0):
    """The long neck over the jungle (drawn tall; the trees hide its feet)."""
    f = Frame(L, x, base, d, s)
    body = f.ell(0, 20, 24, 14) | f.poly([(-20, 22), (-48, 8), (-46, 6), (-18, 12)])
    body |= f.poly([(12, 28), (22, 80), (30, 82), (24, 24)])
    body |= f.ell(29, 84, 8, 5) | f.poly([(30, 86), (40, 83), (39, 80), (30, 80)])
    body |= _legs(f, (-14, -6, 8, 15), 12, 7)
    solid(L, body, rmp, OUTLINE, rim=3)
    for dy in range(34, 76, 7):                       # neck stripes
        L.fill(f.line([(16 + (dy - 28) * 0.17, dy), (26 + (dy - 28) * 0.1, dy + 1)], 1) & body,
               rmp[0])
    f.dot(32, 86, EYE, 2)


def pterodactyl(L, x, y, rmp, d=1, s=1.0, up=False):
    f = Frame(L, x, y, d, s)
    wy = 6 if up else -4
    m = f.poly([(0, 0), (-16, wy), (-6, -1)]) | f.poly([(0, 0), (16, wy), (6, -1)])
    m |= f.ell(0, 0, 4, 2) | f.poly([(2, 1), (10, -1), (3, -1)]) | f.poly([(-1, 1), (-6, 4), (-2, 0)])
    solid(L, m, rmp, OUTLINE, rim=1)


# -- Space ----------------------------------------------------------------------

def alien(L, x, base, rmp, d=1, s=1.0, wave=False):
    f = Frame(L, x, base, d, s)
    ant = f.line([(-3, 30), (-6, 37)], 1) | f.line([(3, 30), (6, 37)], 1)
    L.fill(ant, rmp[0])
    knobs = f.ell(-6, 37, 2, 2) | f.ell(6, 37, 2, 2)
    solid(L, knobs, rmp, OUTLINE, rim=1)
    suit = f.rect(-6, 17, 6, 5) | f.rect(-5, 6, -1, 0) | f.rect(1, 6, 5, 0)
    arm = f.line([(5, 15), (11, 23)] if wave else [(5, 15), (8, 8)], 3) | \
        f.line([(-5, 15), (-8, 8)], 3)
    solid(L, suit, ramp("3a2a6a", "5a44a0", "7c66c8", "a08ae4"), OUTLINE)
    head = f.ell(0, 24, 8, 8) | arm & ~suit
    solid(L, head, rmp, OUTLINE)
    for ex in (-3, 3):
        L.fill(f.ell(ex, 25, 2.2, 2.8), EYE)
        f.dot(ex - 1, 27, WHITE)
    L.fill(f.line([(-2, 20), (2, 20)], 1), rmp[0])


def astronaut(L, x, base, suit, visor, d=1, s=1.0, wave=False):
    f = Frame(L, x, base, d, s)
    pack = f.rect(-9, 26, -3, 12)
    solid(L, pack, ramp("6a7080", "a0a8b8", "c8d0dc"), OUTLINE, rim=1)
    body = f.rect(-6, 22, 6, 7) | f.rect(-6, 7, -1, 0) | f.rect(1, 7, 6, 0)
    body |= f.line([(5, 20), (11, 27)] if wave else [(5, 20), (8, 10)], 4)
    body |= f.line([(-5, 20), (-8, 10)], 4)
    body |= f.ell(0, 29, 8, 8)
    solid(L, body, suit, OUTLINE)
    v = f.ell(2, 29, 5, 4)
    L.fill(v, visor[0])
    L.fill(v & f.rect(-3, 33, 7, 30), visor[1])
    f.dot(4, 32, WHITE)
    L.fill(f.rect(-3, 18, 3, 14), hexrgb("d84848"))         # chest panel
    f.dot(-2, 17, hexrgb("4ad8f0"))


# -- Undersea -----------------------------------------------------------------

def crab(L, x, base, rmp, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    legs = np.zeros((L.h, L.w), bool)
    for k in (-1, 1):
        for i, dx in enumerate((4, 7, 10)):
            legs |= f.line([(k * dx, 5), (k * (dx + 4), 3), (k * (dx + 5), 0)], 1)
    L.fill(legs, rmp[0])
    claws = np.zeros_like(legs)
    for k in (-1, 1):
        claws |= f.line([(k * 8, 8), (k * 12, 13)], 2)
        claws |= f.ell(k * 13, 15, 4, 3) & ~f.poly([(k * 13, 15), (k * 18, 17), (k * 18, 13)])
    body = f.ell(0, 7, 10, 6) | claws
    body |= f.line([(-3, 11), (-3, 15)], 1) | f.line([(3, 11), (3, 15)], 1)
    solid(L, body, rmp, OUTLINE, rim=1)
    for ex in (-3, 3):
        L.fill(f.rect(ex - 1, 17, ex + 1, 15), WHITE)
        f.dot(ex, 16, EYE)


def octopus(L, x, base, rmp, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    arms = np.zeros((L.h, L.w), bool)
    for k, dx in enumerate((-9, -5, -1, 3, 7, 10)):
        bend = 3 if k % 2 else -3
        arms |= f.line([(dx * 0.6, 10), (dx, 5), (dx + bend, 1), (dx + bend * 1.6, 2)], 3)
    body = f.ell(0, 18, 10, 11) | arms
    solid(L, body, rmp, OUTLINE)
    for ex in (-4, 4):
        L.fill(f.ell(ex, 17, 2.5, 3), WHITE)
        L.fill(f.ell(ex + 1, 16, 1.2, 1.6), EYE)
    for sx, sy in ((-5, 24), (2, 25), (6, 21)):
        f.dot(sx, sy, rmp[3] if len(rmp) > 3 else rmp[2], 2)


def pufferfish(L, x, base, rmp, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    spikes = np.zeros((L.h, L.w), bool)
    for a in range(0, 360, 30):
        r = math.radians(a)
        spikes |= f.line([(math.cos(r) * 7, 10 + math.sin(r) * 7),
                          (math.cos(r) * 12, 10 + math.sin(r) * 12)], 1)
    L.fill(spikes, rmp[0])
    body = f.ell(0, 10, 9, 9) | f.poly([(-8, 10), (-14, 15), (-14, 5)])
    solid(L, body, rmp, OUTLINE)
    L.fill(f.ell(4, 12, 2.5, 2.5), WHITE)
    f.dot(5, 12, EYE, 2)
    L.fill(f.rect(6, 7, 9, 6), hexrgb("c84848"))


def seahorse(L, x, base, rmp, d=1, s=1.0):
    f = Frame(L, x, base, d, s)
    m = f.line([(1, 3), (-3, 2), (-4, 5), (-1, 7)], 2)               # tail curl
    m |= f.poly([(-1, 6), (4, 10), (5, 18), (2, 24), (-3, 22), (-2, 14)])
    m |= f.ell(1, 26, 4, 4) | f.poly([(3, 28), (10, 27), (10, 25), (3, 24)])
    m |= f.poly([(-2, 29), (-1, 32), (1, 29)])
    solid(L, m, rmp, OUTLINE, rim=1)
    for dy in range(10, 22, 3):
        L.fill(f.line([(-1, dy), (3, dy + 1)], 1) & m, rmp[0])
    f.dot(2, 27, EYE)


def fish(L, x, y, rmp, stripe=None, d=1, s=1.0):
    f = Frame(L, x, y, d, s)
    m = f.ell(0, 0, 7, 4) | f.poly([(-5, 0), (-11, 4), (-11, -4)])
    m |= f.poly([(-2, 3), (2, 6), (3, 3)])
    solid(L, m, rmp, OUTLINE, rim=1)
    if stripe is not None:
        for dx in (-2, 2):
            L.fill(f.rect(dx, 4, dx + 1.5, -4) & m, stripe)
    f.dot(4, 1, EYE)


def jellyfish(L, x, y, rmp, s=1.0):
    f = Frame(L, x, y, 1, s)
    tent = np.zeros((L.h, L.w), bool)
    for i, dx in enumerate((-5, -2, 1, 4)):
        w = 1.5 if i % 2 else -1.5
        tent |= f.line([(dx, 0), (dx + w, -5), (dx - w, -10), (dx, -14)], 1)
    L.fill(tent, rmp[1])
    bell = f.ell(0, 1, 8, 7) & ~f.rect(-9, 0, 9, -8)
    solid(L, bell, rmp, OUTLINE, rim=1)


def turtle(L, x, y, shell, skin, d=1, s=1.0):
    f = Frame(L, x, y, d, s)
    flip = f.poly([(-2, 0), (6, -8), (9, -6), (2, 1)]) | f.poly([(-6, 0), (-12, -5), (-9, -6)])
    flip |= f.ell(11, 1, 4, 3)
    solid(L, flip, skin, OUTLINE, rim=1)
    sh = f.ell(0, 2, 10, 6)
    solid(L, sh, shell, OUTLINE)
    for dx in (-4, 1, 6):
        L.fill(f.line([(dx, 6), (dx - 1, -1)], 1) & sh, shell[0])
    f.dot(13, 2, EYE)


def starfish(L, x, base, rmp, s=1.0):
    f = Frame(L, x, base, 1, s)
    pts = []
    for i in range(10):
        a = math.radians(90 + i * 36)
        r = 8 if i % 2 == 0 else 3.5
        pts.append((math.cos(a) * r, 7 + math.sin(a) * r * 0.8))
    m = f.poly(pts)
    solid(L, m, rmp, OUTLINE, rim=1)
