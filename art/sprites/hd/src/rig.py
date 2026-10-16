#!/usr/bin/env python3
"""Hi-res player sprites for the modern port, rendered from a pose rig.

Style target: art/concept/level-01..03 (characters about 48 px tall,
realistic proportions, 3-4 tone shading, dark outlines between parts).

Limbs and torso are shaded capsules between joints; the head is hand-pixeled.
Each body part gets its own 1 px outline, so a near arm over the torso reads
the way it does in the concept art. Pixels are palette roles, so one render
recolors to any team (see palettes.json).

    python3 art/sprites/hd/src/rig.py      # -> frames.json (for build_hd.lua)
"""
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
W, H = 64, 64
GROUND = 58                       # feet end on this row
LIGHT = (-0.55, -0.83)            # from the upper left

# Role keys, in palette index order (index 0 is transparent).
ROLES = (
    ".o"                         # 0 transparent, 1 outline
    "1234"                       # skin: deep, shadow, base, light
    "hHi"                        # hair: dark, base, light
    "DdML"                       # shirt/cap: dark, shadow, base, light
    "qwW"                        # shorts: shadow, base, light
    "sS"                         # socks: base, shadow
    "xXgkK"                      # shoe: base, shadow, sole, accent, accent dark
    "pPfeEG"                     # paddle: face dark/base/light, rim, rim light, grip
    "Z"                          # highlight
)
assert len(set(ROLES)) == len(ROLES)

# Ramps: (deep, shadow, base, light). Missing steps fall back inward.
RAMP = {
    "skin": ("1", "2", "3", "4"),
    "skin_far": ("1", "1", "2", "3"),
    "shirt": ("D", "d", "M", "L"),
    "shirt_far": ("D", "D", "d", "M"),
    "shorts": ("q", "q", "w", "W"),
    "shorts_far": ("q", "q", "q", "w"),
    "sock": ("S", "S", "s", "s"),
    "sock_far": ("S", "S", "S", "s"),
    "hair": ("h", "h", "H", "i"),
}


def ramp_pick(ramp, s):
    """s: lighting term in [-1, 1] -> role key."""
    deep, shadow, base, light = RAMP[ramp]
    if s > 0.4:
        return light
    if s < -0.75:
        return deep
    if s < -0.35:
        return shadow
    return base


def part_rows(text):
    return text.strip("\n").split("\n")


# --- Hand-pixeled parts -----------------------------------------------------

# Head facing right. Neck attach point: NECK_AT (col, row).
HEAD = part_rows("""
...oooo.....
..oLLMMo....
.oLMMMMMo...
.oMMMMMMdooo
.oddddMMMMLo
.oHHd22ooooo
.oHh233o3o..
.oh2133334o.
.oh223332o..
..o22332o...
...oo223o...
""")
NECK_AT = (5, 10)

PONYTAIL = part_rows("""
..ooo.
.oHHHo
oHiHho
oHHho.
ohHo..
ohho..
.oo...
""")

PONY_FLY = part_rows("""
....ooo
.ooHHHo
oHHiHho
.ohhho.
..oo...
""")
PONY_FLY_AT = (5, 2)
PONY_AT = (4, 1)        # this ponytail pixel sits on the head's (2, 5)


def mirror(rows):
    w = max(len(r) for r in rows)
    return [r.ljust(w, ".")[::-1] for r in rows]


# --- Raster helpers ---------------------------------------------------------

class Part:
    """One body part: role keys per pixel plus its own outline."""

    def __init__(self, outlined=True):
        self.px = {}
        self.outlined = outlined   # hand-pixeled parts carry their own

    def capsule(self, a, b, r0, r1, ramp, light=LIGHT):
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy or 1e-6
        rmax = max(r0, r1)
        for y in range(int(min(ay, by) - rmax - 1), int(max(ay, by) + rmax + 2)):
            for x in range(int(min(ax, bx) - rmax - 1), int(max(ax, bx) + rmax + 2)):
                px, py = x + 0.5, y + 0.5
                t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
                cx, cy = ax + t * dx, ay + t * dy
                r = r0 + (r1 - r0) * t
                ox, oy = px - cx, py - cy
                d = math.hypot(ox, oy)
                if d <= r:
                    s = (ox * light[0] + oy * light[1]) / max(r, 0.8)
                    self.px[(x, y)] = ramp_pick(ramp, s)

    def blit(self, rows, x0, y0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    self.px[(x0 + x, y0 + y)] = ch

    def set(self, xy, ch):
        self.px[(round(xy[0] - 0.5), round(xy[1] - 0.5))] = ch

    def outline(self):
        out = set()
        if not self.outlined:
            return out
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px:
                    out.add((nx, ny))
        return out


class Canvas:
    def __init__(self):
        self.g = [["."] * W for _ in range(H)]
        self.clipped = 0

    def put(self, x, y, ch):
        if 0 <= x < W and 0 <= y < H:
            self.g[y][x] = ch
        else:
            self.clipped += 1

    def draw(self, part):
        for (x, y) in part.outline():
            self.put(x, y, "o")
        for (x, y), ch in part.px.items():
            self.put(x, y, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


# --- Body builders ----------------------------------------------------------

def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def arm(shoulder, elbow, hand, far=False, band=True):
    p = Part()
    sk = "skin_far" if far else "skin"
    sh = "shirt_far" if far else "shirt"
    p.capsule(elbow, hand, 1.45, 1.25, sk)
    p.capsule(shoulder, elbow, 1.75, 1.5, sk)
    p.capsule(shoulder, lerp(shoulder, elbow, 0.42), 2.35, 2.1, sh)  # sleeve
    if band:
        p.capsule(lerp(elbow, hand, 0.68), lerp(elbow, hand, 0.82), 1.5, 1.5,
                  sh)                                                # wristband
    p.capsule(hand, hand, 1.6, 1.6, sk)                              # fist
    return p


def leg(hip, knee, ankle, toe_dir=(1, 0), far=False):
    """Thigh, calf, sock and shoe. toe_dir: unit-ish vector heel->toe."""
    p = Part()
    sk = "skin_far" if far else "skin"
    p.capsule(knee, ankle, 1.95, 1.35, sk)
    p.capsule(hip, knee, 2.55, 2.1, sk)
    p.capsule(lerp(knee, ankle, 0.72), ankle, 1.4, 1.4,
              "sock_far" if far else "sock")
    shoe(p, ankle, toe_dir, far)
    return p


def shoe(p, ankle, toe_dir, far):
    tx, ty = toe_dir
    n = math.hypot(tx, ty)
    tx, ty = tx / n, ty / n
    heel = (ankle[0] - tx * 1.0, ankle[1] + 1.6 - ty * 1.0)
    toe = (ankle[0] + tx * 3.3, ankle[1] + 1.6 + ty * 3.3)
    nx, ny = -ty, tx                        # foot "down" normal when toe right
    if ny < 0:
        nx, ny = -nx, -ny
    for y in range(int(min(heel[1], toe[1])) - 4, int(max(heel[1], toe[1])) + 5):
        for x in range(int(min(heel[0], toe[0])) - 4, int(max(heel[0], toe[0])) + 5):
            px, py = x + 0.5, y + 0.5
            dx, dy = toe[0] - heel[0], toe[1] - heel[1]
            L2 = dx * dx + dy * dy
            t = max(0.0, min(1.0, ((px - heel[0]) * dx + (py - heel[1]) * dy) / L2))
            r = 1.75 - 0.35 * t
            cx, cy = heel[0] + t * dx, heel[1] + t * dy
            ox, oy = px - cx, py - cy
            if math.hypot(ox, oy) > r:
                continue
            down = ox * nx + oy * ny
            if down > r - 1.0:
                ch = "g"
            elif abs((t - 0.45) * 7 - down * 0.8) < 1.1 and down < r - 1.0:
                ch = "K" if far else "k"
            elif far or down > 0.3:
                ch = "X"
            else:
                ch = "x"
            p.px[(x, y)] = ch
    # lit top edge on the near shoe
    if not far:
        for (x, y), ch in list(p.px.items()):
            if ch == "X" and (x, y - 1) not in p.px:
                p.px[(x, y)] = "x"


def torso(neck, hip):
    p = Part()
    chest = lerp(neck, hip, 0.35)
    p.capsule(chest, add(hip, (0, -1)), 4.4, 4.0, "shirt")
    p.capsule(add(neck, (0, 3)), chest, 3.8, 4.4, "shirt")
    return p


def shorts(hip, knee_n, knee_f):
    p = Part()
    p.capsule(add(hip, (-1, 0)), add(hip, (1, 0)), 4.0, 4.0, "shorts")
    p.capsule(hip, lerp(hip, knee_f, 0.5), 3.2, 2.8, "shorts_far")
    p.capsule(add(hip, (1, 0)), lerp(hip, knee_n, 0.5), 3.2, 2.8, "shorts")
    return p


def neck_part(neck):
    p = Part()
    p.capsule(add(neck, (0, -1)), add(neck, (0, 2)), 1.3, 1.5, "skin")
    return p


def paddle(grip, angle_deg, face_up=True):
    """Grip at the hand, head along angle (degrees, 0 = right, -90 = up)."""
    p = Part()
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)          # along the paddle
    vx, vy = -uy, ux                           # across
    handle_end = (grip[0] + ux * 3.0, grip[1] + uy * 3.0)
    p.capsule((grip[0] - ux * 1.5, grip[1] - uy * 1.5), handle_end, 1.0, 1.0,
              "sock_far")
    for k, ch in list(p.px.items()):
        p.px[k] = "G"
    center = (grip[0] + ux * 7.4, grip[1] + uy * 7.4)
    hl, hw = 4.7, 3.8                          # half length, half width
    for y in range(int(center[1] - 10), int(center[1] + 11)):
        for x in range(int(center[0] - 10), int(center[0] + 11)):
            px, py = x + 0.5 - center[0], y + 0.5 - center[1]
            u = px * ux + py * uy
            v = px * vx + py * vy
            # rounded rectangle-ish: superellipse
            q = (abs(u) / hl) ** 3 + (abs(v) / hw) ** 3
            if q > 1:
                continue
            if q > 0.52:
                s = (px * LIGHT[0] + py * LIGHT[1]) / hl
                ch = "E" if s > 0.35 else "e"
            else:
                s = (px * LIGHT[0] + py * LIGHT[1]) / hl
                ch = "f" if s > 0.45 else ("p" if s < -0.15 else "P")
            p.px[(x, y)] = ch
    return p


# --- Poses -----------------------------------------------------------------
# Joint coordinates in frame pixels (facing right). n = near (camera side),
# f = far. Paddle: (angle, in_front).

def shift(pose, dx=0, dy=0, **override):
    """Copy of a pose with every joint moved by (dx, dy), then overrides."""
    out = {}
    for k, v in pose.items():
        if isinstance(v, tuple) and len(v) == 2 and k[:3] not in ("toe", "pad"):
            out[k] = (v[0] + dx, v[1] + dy)
        else:
            out[k] = v
    out.update(override)
    return out


IDLE = dict(
    neck=(31, 24), hip=(26, 38.5),
    sh_n=(31, 28), el_n=(33, 34), ha_n=(39, 35),
    sh_f=(28, 28), el_f=(30, 34), ha_f=(37, 36),
    kn_n=(36.5, 46), an_n=(34, 54.5), toe_n=(1, 0),
    kn_f=(19, 46), an_f=(16, 54.5), toe_f=(1, 0),
    paddle=(-62, "front"),
)

# Run: torso leans in, paddle carried in front, far arm pumps.
RUN = dict(IDLE, neck=(33, 24), hip=(27, 37),
           sh_n=(33, 29), el_n=(35, 35), ha_n=(40, 35),
           sh_f=(30, 29), paddle=(-58, "front"), pony="fly")

POSES = {
    "idle0": IDLE,
    "idle1": shift(IDLE, 0, 1, kn_n=(37, 47), an_n=(34, 54.5),
                   kn_f=(18.5, 47), an_f=(16, 54.5)),
    "run0": shift(RUN, 0, 1, el_f=(33, 34), ha_f=(38, 32),
                  kn_n=(37, 45), an_n=(39, 54.5),
                  kn_f=(22, 46), an_f=(16, 50), toe_f=(1, 0.9)),
    "run1": shift(RUN, 0, 0, el_f=(30, 35), ha_f=(33, 38),
                  kn_n=(30, 46), an_n=(28, 54.5),
                  kn_f=(34, 43), an_f=(29, 49), toe_f=(1, 0.7)),
    "run2": shift(RUN, 0, 1, el_f=(26, 34), ha_f=(23, 38),
                  kn_n=(22, 46), an_n=(16, 50), toe_n=(1, 0.9),
                  kn_f=(36, 45), an_f=(38, 54.5)),
    "run3": shift(RUN, 0, 0, el_f=(30, 35), ha_f=(33, 38),
                  kn_n=(35, 43), an_n=(30, 49), toe_n=(1, 0.7),
                  kn_f=(28, 46), an_f=(26, 54.5)),
    # Forehand: coil back, contact out front (level-02 lunge), finish high.
    "windup": dict(IDLE, neck=(28, 24), hip=(27, 37),
                   sh_n=(29, 29), el_n=(23, 33), ha_n=(18, 32),
                   sh_f=(27, 29), el_f=(33, 31), ha_f=(38, 29),
                   kn_n=(34, 46), an_n=(36, 54.5),
                   kn_f=(21, 45), an_f=(17, 54.5),
                   paddle=(-150, "mid")),
    "swing": dict(neck=(34, 24), hip=(28, 37),
                  sh_n=(34, 29), el_n=(40, 30), ha_n=(46, 31),
                  sh_f=(31, 29), el_f=(25, 31), ha_f=(20, 29),
                  kn_n=(40, 46), an_n=(42, 54.5), toe_n=(1, 0),
                  kn_f=(21, 47), an_f=(14, 53.5), toe_f=(1, 0.35),
                  paddle=(-12, "front"), pony="fly"),
    "follow": dict(neck=(34, 24), hip=(28, 37),
                   sh_n=(34, 29), el_n=(40, 27), ha_n=(45, 21),
                   sh_f=(31, 29), el_f=(26, 33), ha_f=(22, 35),
                   kn_n=(40, 46), an_n=(42, 54.5), toe_n=(1, 0),
                   kn_f=(23, 47), an_f=(17, 52.5), toe_f=(1, 0.6),
                   paddle=(-62, "front"), pony="fly"),
    # Underhand serve: ball hand forward low, paddle back low.
    "toss": dict(IDLE, neck=(30, 23), hip=(26, 37),
                 sh_n=(30, 28), el_n=(26, 34), ha_n=(22, 38),
                 sh_f=(28, 28), el_f=(32, 33), ha_f=(37, 33),
                 kn_n=(34, 46), an_n=(35, 54.5),
                 kn_f=(22, 46), an_f=(20, 54.5),
                 paddle=(148, "back")),
    "cheer": dict(IDLE, neck=(30, 24), hip=(27, 37),
                  sh_n=(31, 29), el_n=(37, 24), ha_n=(41, 17),
                  sh_f=(28, 29), el_f=(22, 25), ha_f=(18, 18),
                  kn_n=(33, 46), an_n=(34, 54.5),
                  kn_f=(22, 46), an_f=(20, 54.5),
                  paddle=(-80, "front")),
}


def head_origin(neck):
    return (round(neck[0]) - NECK_AT[0], round(neck[1]) - NECK_AT[1])


def proportions(pose):
    """Pose joints were authored for a bigger head; raise the neck and
    shoulders so the slimmer figure keeps its height."""
    P = dict(pose)
    P["neck"] = add(P["neck"], (0, -2))
    for k in ("sh_n", "sh_f"):
        P[k] = add(P[k], (0, -1.5))
    return P


def render(pose, female=False):
    c = Canvas()
    P = proportions(pose)
    hx, hy = head_origin(P["neck"])

    if P["paddle"][1] == "back":
        c.draw(paddle(P["ha_n"], P["paddle"][0]))
    c.draw(arm(P["sh_f"], P["el_f"], P["ha_f"], far=True))
    c.draw(leg(P["hip"], P["kn_f"], P["an_f"], P["toe_f"], far=True))
    if female:
        pt = Part(outlined=False)
        if P.get("pony") == "fly":
            pt.blit(PONY_FLY, hx + 2 - PONY_FLY_AT[0], hy + 5 - PONY_FLY_AT[1])
        else:
            pt.blit(PONYTAIL, hx + 2 - PONY_AT[0], hy + 5 - PONY_AT[1])
        c.draw(pt)
    c.draw(leg(add(P["hip"], (2, 0)), P["kn_n"], P["an_n"], P["toe_n"]))
    c.draw(shorts(P["hip"], P["kn_n"], P["kn_f"]))
    c.draw(torso(P["neck"], P["hip"]))
    c.draw(neck_part(P["neck"]))
    head = Part(outlined=False)
    head.blit(HEAD, hx, hy)
    c.draw(head)
    ang, layer = P["paddle"]
    pad = paddle(P["ha_n"], ang)
    if layer == "mid":
        c.draw(pad)
    c.draw(arm(P["sh_n"], P["el_n"], P["ha_n"]))
    if layer == "front":
        c.draw(pad)
        fist = Part()
        fist.capsule(P["ha_n"], P["ha_n"], 1.6, 1.6, "skin")
        c.draw(fist)
    if c.clipped:
        print(f"warning: {c.clipped} pixels clipped")
    return c.rows()


SLOTS = ["idle0", "idle1", "run0", "run1", "run2", "run3",
         "windup", "swing", "follow", "toss", "cheer"]


def main():
    frames = {}
    for name in SLOTS:
        if name in POSES:
            frames[name] = {"male": render(POSES[name]),
                            "female": render(POSES[name], female=True)}
    (HERE / "frames.json").write_text(json.dumps(
        {"size": [W, H], "ground_row": GROUND, "roles": ROLES,
         "slots": [s for s in SLOTS if s in POSES], "frames": frames},
        indent=1))


if __name__ == "__main__":
    main()
