#!/usr/bin/env python3
"""Builds every level asset at 960x540 into art/levels/out/, with a JSON
manifest an engine can load, and full-screen previews of each level.

    .venv/bin/python art/levels/tools/build.py [--previews-only]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import court as C  # noqa: E402
import crowd  # noqa: E402
import players as PL  # noqa: E402
import preview  # noqa: E402
import ui  # noqa: E402
import venues  # noqa: E402
from pix import (LAYER_H, LAYER_W, OVER_X, OVER_Y, SCREEN_H, SCREEN_W,  # noqa: E402
                 Layer, hexrgb)
from scenery import M  # noqa: E402

KIT = HERE.parents[2]
OUT = HERE.parent / "out"
PAL = json.loads((KIT / "art/sprites/hd/src/palettes.json").read_text())
TEAMS = ["blue", "red", "green", "gold"]
MOCKS = {"park": "level-01.png", "lakeside": "level-02.png",
         "sunset": "level-03.png", "dinosaur": "court_top_dinosaur.png",
         "space": "court_top_space.png", "undersea": "court_top_undersea.png"}


def save(img, rel):
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(img, np.ndarray):
        img = Image.fromarray(img)
    img.save(p, optimize=True)
    return rel


# -- Players ----------------------------------------------------------------------

def team_colors(team, skin="light", hair="brown"):
    c = dict(PAL["base"])
    c.update(PAL["teams"][team])
    c.update(PAL["paddles"][team])
    c.update(PAL["skins"][skin])
    c.update(PAL["hairs"][hair])
    c["k"] = PAL["teams"][team]["M"]
    c["K"] = PAL["teams"][team]["d"]
    return c


def rows_rgba(rows, cols):
    a = np.zeros((len(rows), len(rows[0]), 4), np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                a[y, x, :3] = cols[ch]
                a[y, x, 3] = 255
    return a


def rows_index(rows):
    idx = {ch: i for i, ch in enumerate(PL.ROLES)}
    return np.array([[idx[ch] for ch in r] for r in rows], np.uint8)


def build_players():
    frames = {}
    hat_rows = {}
    for variant in ("male", "female"):
        fem = variant == "female"
        bare, capped = [], []
        hats = {h: [] for h in PL.HATS}
        for name in PL.SLOTS:
            b, clip_b = PL.render(PL.POSES[name], fem, hat=None)
            c, clip_c = PL.render(PL.POSES[name], fem, hat="cap")
            assert not (clip_b or clip_c), f"{variant} {name} clipped"
            bare.append(b)
            capped.append(c)
            for h in PL.HATS:
                r, clip = PL.render(PL.POSES[name], fem, hat=h)
                assert not clip, f"{variant} {name} {h} clipped"
                hats[h].append(PL.cap_overlay(b, r))
        frames[variant] = (bare, capped)
        hat_rows[variant] = hats
    sheets = {}
    n = len(PL.SLOTS)
    for variant, (bare, capped) in frames.items():
        caps = [PL.cap_overlay(b, c) for b, c in zip(bare, capped)]
        # indexed role sheets (palette swap in a shader) ...
        for kind, rows_list in (("body", bare), ("cap", caps),
                                *hat_rows[variant].items()):
            idx = np.zeros((PL.H, PL.W * n), np.uint8)
            for i, rows in enumerate(rows_list):
                idx[:, i * PL.W:(i + 1) * PL.W] = rows_index(rows)
            im = Image.fromarray(idx, "P")
            pal = [0] * 768
            for i in range(len(PL.ROLES)):
                pal[i * 3:i * 3 + 3] = [i * 8] * 3
            im.putpalette(pal)
            im.info["transparency"] = 0
            save(im, f"sprites/players/roles/player_{variant}_{kind}.png")
        # ... and pre-coloured sheets per team
        for team in TEAMS:
            cols = team_colors(team)
            body = np.zeros((PL.H, PL.W * n, 4), np.uint8)
            cap = np.zeros_like(body)
            for i in range(n):
                body[:, i * PL.W:(i + 1) * PL.W] = rows_rgba(bare[i], cols)
                cap[:, i * PL.W:(i + 1) * PL.W] = rows_rgba(caps[i], cols)
            sheets.setdefault(variant, {})[team] = {
                "body": save(body, f"sprites/players/player_{variant}_{team}.png"),
                "cap": save(cap, f"sprites/players/player_{variant}_{team}_cap.png")}
    return {
        "frame_size": [PL.W, PL.H], "anchor": [PL.ANCHOR_X, PL.GROUND],
        "anchor_doc": "Feet: the frame pixel on the ground at the body's "
                      "centre. Facing right; flip horizontally for left, "
                      "mirroring the anchor to frame_width - 1 - x.",
        "frames": PL.SLOTS,
        "animations": {k: {"frames": f, "ms_per_frame": ms}
                       for k, (f, ms) in PL.ANIMS.items()},
        "sheets": sheets,
        "cap_doc": "The cap is an overlay sheet with the same frames: draw it "
                   "right after the body. Leave it off for bareheaded players "
                   "or swap in another hat.",
        "roles": {"files": {v: {k: f"sprites/players/roles/player_{v}_{k}.png"
                                for k in ("body", "cap", *PL.HATS)}
                            for v in ("male", "female")},
                  "hats": ["cap", *PL.HATS],
                  "hats_doc": "Hat overlays (role sheets only), drawn like the "
                              "cap: visor and headband in the shoe accent "
                              "(k, K), tricorn in hair with a white (Z) trim, "
                              "bandana in the shirt ramp. SNES ADR-060 "
                              "(PORT-38): beanie, whirly, backcap, bucket in "
                              "the shirt ramp (whirly blades in the accent), "
                              "crown silver with shirt jewels, chef white, "
                              "viking grey with white horns and a shirt band.",
                  "order": PL.ROLES,
                  "palettes": "palettes.json",
                  "doc": "Pixel value = index into 'order' (0 transparent). "
                         "Build a palette from palettes.json: base + team + "
                         "paddle + skin + hair; shoe accent k/K = team M/d."},
    }, frames


# -- Crowd ----------------------------------------------------------------------

def build_crowd():
    img, rows = crowd.sheet()
    save(img, "sprites/crowd.png")
    return {"file": "sprites/crowd.png", "frame_size": [crowd.FW, crowd.FH],
            "frames": ["idle", "cheer"],
            "people": [{"row": i, "pose": pose} for i, (pose, _) in enumerate(rows)],
            "sit_anchor": list(crowd.SEAT), "stand_anchor": list(crowd.FEET),
            "doc": "Row = person, column 0 idle, 1 cheer. Sitting people "
                   "anchor at the seat, standing people at the feet."}, rows


# -- UI ------------------------------------------------------------------------------

PANEL_FILL = (hexrgb("0c1430"), hexrgb("141e44"))
BORDERS = {
    "blue": ("1c3a9c", "3a64d8", "8ab0f8"), "red": ("8c1c1c", "d83a3a", "f88a7a"),
    "green": ("1a6a2a", "34a84a", "8ade7a"), "gold": ("9a6a10", "e0a82a", "f8dc7a"),
    "title": ("6a7088", "a8aec4", "e4e8f4"), "sub": ("8a8e9c", "d8dce8", "ffffff"),
}


def build_ui():
    meta = {"fonts": {}, "panels": {}, "buttons": {}}
    for name, (scale, top, bot, hl, ow) in {
            "big": (3, (250, 250, 250), (196, 202, 218), None, 2),
            "big_gold": (3, hexrgb("fbe46a"), hexrgb("f4a81c"), hexrgb("fff6c0"), 2),
            "small": (2, (250, 250, 250), (210, 214, 228), None, 1)}.items():
        atlas, m = ui.font_atlas(scale, top, bot, hl, ow, name)
        m["file"] = save(atlas, f"ui/font_{name}.png")
        (OUT / f"ui/font_{name}.json").write_text(json.dumps(m, indent=1))
        meta["fonts"][name] = {"file": m["file"], "metrics": f"ui/font_{name}.json",
                               "tint": name in ("big", "small")}
    for name, border in BORDERS.items():
        fill = PANEL_FILL if name != "title" else (hexrgb("0a1028"), hexrgb("121a3c"))
        img = ui.panel(48, 48, fill, tuple(hexrgb(c) for c in border))
        meta["panels"][name] = {"file": save(img, f"ui/panel_{name}.png"),
                                "slice": [12, 12, 12, 12]}
    img = ui.panel(48, 48, (hexrgb("0e2a22"), hexrgb("16382c")),
                   tuple(hexrgb(c) for c in ("6a8a74", "a8c4ac", "e4f0e4")))
    meta["panels"]["doubles"] = {"file": save(img, "ui/panel_doubles.png"),
                                 "slice": [12, 12, 12, 12]}
    for letter, colr in (("A", (214, 40, 40)), ("B", (232, 176, 32)),
                         ("X", (44, 92, 214)), ("Y", (40, 160, 72))):
        meta["buttons"][letter] = save(ui.button_glyph(letter, colr),
                                       f"ui/button_{letter}.png")
    meta["buttons"]["B_red"] = save(ui.button_glyph("B", (214, 40, 40)),
                                    "ui/button_B_red.png")
    meta["buttons"]["doc"] = ("SFC colours (A red, B yellow, X blue, Y green); "
                              "B_red matches the mocks' prompt.")
    meta["icon_ball"] = save(ui.ball_icon(), "ui/icon_ball.png")
    # HUD layouts from the mocks (screen px)
    meta["hud_layout"] = {
        "singles": {"left_score": box(95, 75, 325, 150, "blue"),
                    "right_score": box(1015, 75, 1240, 150, "red"),
                    "title": box(435, 75, 905, 140, "title"),
                    "prompt": box(415, 1030, 920, 1105, "title")},
        "doubles": {"left_score": box(90, 40, 385, 110, "blue"),
                    "right_score": box(985, 40, 1270, 110, "red"),
                    "title": box(440, 35, 920, 115, "doubles"),
                    "subtitle": box(515, 112, 850, 160, "sub")},
        "doc": "Boxes are [x, y, w, h] at 960x540 for a 9-slice panel; text "
               "is centred in the box. Scores use font 'big' tinted with the "
               "team colour (label) and white (digits); titles use "
               "'big_gold'; prompts and subtitles use 'small'.",
    }
    return meta


def box(x0, y0, x1, y1, panel):
    a, b = M(x0, y0), M(x1, y1)
    return {"box": [round(a[0]), round(a[1]), round(b[0] - a[0]),
                    round(b[1] - a[1])], "panel": panel}


def build_fx():
    meta = {}
    frames = ui.ball_frames()
    meta["ball"] = {"file": save(np.hstack(frames), "sprites/ball.png"),
                    "frame_size": list(frames[0].shape[1::-1]),
                    "frames": len(frames), "anchor": "centre"}
    meta["ball_shadow"] = {"file": save(ui.shadow(12, 5), "sprites/ball_shadow.png"),
                           "anchor": "centre"}
    meta["player_shadow"] = {"file": save(ui.shadow(44, 11), "sprites/player_shadow.png"),
                             "anchor": "centre", "doc": "Centre on the player's anchor."}
    sp = ui.spark_frames()
    meta["spark"] = {"file": save(np.hstack(sp), "sprites/spark.png"),
                     "frame_size": [sp[0].shape[1], sp[0].shape[0]], "frames": len(sp),
                     "ms_per_frame": 50, "anchor": "centre"}
    du = ui.dust_frames()
    meta["dust"] = {"file": save(np.hstack(du), "sprites/dust.png"),
                    "frame_size": [du[0].shape[1], du[0].shape[0]], "frames": len(du),
                    "ms_per_frame": 70, "anchor": "bottom centre"}
    post = C.near_post()
    meta["net_post"] = {"file": save(post.a, "sprites/net_post_near.png"),
                        "anchor": [post.w // 2, post.h - 2],
                        "position": [round(v) for v in C.to_screen(0.5, 1)],
                        "doc": "Y-sort with the players at the near sideline."}
    return meta


# -- Venues ------------------------------------------------------------------------

ORDER = ["sky", "far", "trees", "ground", "fence", "stands", "net", "front"]


def build_venue(name, crowd_rows):
    v = venues.VENUES[name]()
    net = Layer()
    C.net(net)
    v.layers.append(("net", net, 1.0))
    order = list(ORDER)
    if getattr(v, "stands_behind_fence", False):
        # lakeside: the spectators sit outside the court, behind the fence
        i, j = order.index("fence"), order.index("stands")
        order[i], order[j] = order[j], order[i]
    v.layers.sort(key=lambda t: order.index(t[0]))
    layers = []
    for z, (lname, L, par) in enumerate(v.layers):
        if hasattr(v, "crowd_meta") and lname == "far":
            # ADR-088: a painted backdrop, opaque and photographic: lossy WebP
            rel = f"venues/{name}/far.webp"
            (OUT / rel).parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(L.a[..., :3]).save(OUT / rel, quality=90, method=6)
        else:
            rel = save(L.a, f"venues/{name}/{lname}.png")
        layers.append({"name": lname, "file": rel, "parallax": par, "z": z,
                       "origin": [-OVER_X, -OVER_Y],
                       "size": [L.w, L.h]})
    roles = Image.fromarray(v.roles, "L")
    mask = save(roles, f"venues/{name}/court_mask.png")
    seats = []
    sit = [i for i, (p, _) in enumerate(crowd_rows) if p == "sit"]
    stand = [i for i, (p, _) in enumerate(crowd_rows) if p == "stand"]
    k = {"sit": 0, "stand": 0}
    offset = {"park": 0, "lakeside": 5, "sunset": 8, "dinosaur": 2,
              "space": 6, "undersea": 10, "gym": 3,
              "ruins": 4, "glacier": 7, "lab": 1, "station": 9}.get(name, 0)
    for s in v.seats:
        if "person" in s:                  # ADR-088: a row of the venue's own sheet
            seats.append(s)
            continue
        pool = sit if s["pose"] == "sit" else stand
        person = pool[(k[s["pose"]] + offset) % len(pool)]
        k[s["pose"]] += 1
        seats.append(dict(s, person=person))
    extra = {}
    if hasattr(v, "crowd_meta"):
        save(v.crowd_sheet, v.crowd_meta["file"])
        extra["crowd"] = v.crowd_meta
    return v, {
        **extra,
        "layers": layers,
        "draw_order_doc": "Draw layers by z. Game sprites (shadows, players, "
                          "ball, near net post; y-sorted) go after 'net' and "
                          "before 'front'. Crowd sprites go after 'stands'. "
                          "Offset each layer by -camera * parallax.",
        "court_mask": mask, "court_colors": {k2: v2 for k2, v2 in
                                             v.court_colors.items()},
        "seats": seats, "watcher": v.watcher,
    }


# -- Previews ------------------------------------------------------------------------

def sprite_layer(img: np.ndarray, x, y, flip=False):
    if flip:
        img = img[:, ::-1]
    L = Layer(img.shape[1], img.shape[0], 0, 0)
    L.a[:] = img
    return (L, (int(x), int(y)))


def player_frame(variant, team, name, cap=True):
    body = np.array(Image.open(OUT / f"sprites/players/player_{variant}_{team}.png"))
    capi = np.array(Image.open(OUT / f"sprites/players/player_{variant}_{team}_cap.png"))
    i = PL.SLOTS.index(name)
    f = body[:, i * PL.W:(i + 1) * PL.W].copy()
    if cap:
        c = capi[:, i * PL.W:(i + 1) * PL.W]
        on = c[..., 3] > 0
        f[on] = c[on]
    return f


def place_player(variant, team, name, feet, flip=False):
    f = player_frame(variant, team, name)
    ax = PL.ANCHOR_X if not flip else PL.W - 1 - PL.ANCHOR_X
    return sprite_layer(f, feet[0] - ax, feet[1] - PL.GROUND, flip)


def hud_overlay(meta_ui, mode, texts):
    L = Layer(SCREEN_W, SCREEN_H, 0, 0)
    fonts = {}
    for fname in ("big", "big_gold", "small"):
        fonts[fname] = (np.array(Image.open(OUT / f"ui/font_{fname}.png")),
                        json.loads((OUT / f"ui/font_{fname}.json").read_text()))
    for key, spec in meta_ui["hud_layout"][mode].items():
        x, y, w, h = spec["box"]
        need = 0
        for (font, text, tint, align) in texts.get(key, []):
            atlas, m = fonts[font]
            need += ui.text_image(atlas, m, text).shape[1] + 12
        if key not in texts:
            continue
        if need + 14 > w:
            cxm = x + w // 2
            w = need + 14
            x = cxm - w // 2
        pan = np.array(Image.open(OUT / meta_ui["panels"][spec["panel"]]["file"]))
        img = nine_slice(pan, w, h, 12)
        sl = Layer(w, h, 0, 0)
        sl.a[:] = img
        L.over(sl, x, y)
        for (font, text, tint, align) in texts.get(key, []):
            atlas, m = fonts[font]
            t = ui.text_image(atlas, m, text)
            if tint is not None:
                t = t.copy()
                lum = t[..., :3].astype(float) / 255
                is_ink = (t[..., 3] > 0) & (t[..., :3].min(axis=2) > 60)
                t[is_ink, :3] = (lum[is_ink] * np.array(tint)).astype(np.uint8)
            tl = Layer(t.shape[1], t.shape[0], 0, 0)
            tl.a[:] = t
            ty = y + (h - t.shape[0]) // 2 + 1
            if align == "left":
                tx = x + 10
            elif align == "right":
                tx = x + w - t.shape[1] - 8
            else:
                tx = x + (w - t.shape[1]) // 2
            L.over(tl, tx, ty)
    return L


def nine_slice(img, w, h, m):
    H0, W0 = img.shape[:2]
    out = np.zeros((h, w, 4), np.uint8)
    ys = [0, m, H0 - m, H0]
    yd = [0, m, h - m, h]
    xs = [0, m, W0 - m, W0]
    xd = [0, m, w - m, w]
    for i in range(3):
        for j in range(3):
            src = img[ys[i]:ys[i + 1], xs[j]:xs[j + 1]]
            th, tw = yd[i + 1] - yd[i], xd[j + 1] - xd[j]
            if th <= 0 or tw <= 0:
                continue
            ry = np.arange(th) * src.shape[0] // th
            rx = np.arange(tw) * src.shape[1] // tw
            out[yd[i]:yd[i + 1], xd[j]:xd[j + 1]] = src[ry][:, rx]
    return out


def crowd_sprites(seats, cheer=False, own=None):
    """own: a painted venue's crowd entry (ADR-088), else the shared sheet."""
    sheet = np.array(Image.open(OUT / (own["file"] if own else "sprites/crowd.png")))
    fw, fh = own["frame_size"] if own else (crowd.FW, crowd.FH)
    out = []
    for s in seats:
        r = s["person"]
        f = sheet[r * fh:(r + 1) * fh, (fw if cheer else 0):(fw * (2 if cheer else 1))]
        if own:
            ax, ay = own["stand_anchor"]
        else:
            ax, ay = crowd.SEAT if s["pose"] == "sit" else crowd.FEET
        out.append(sprite_layer(f, s["x"] - ax, s["y"] - ay))
    return out


def fx_at(file, frame_w, index, cx, cy):
    img = np.array(Image.open(OUT / file))
    f = img[:, index * frame_w:(index + 1) * frame_w]
    return sprite_layer(f, cx - f.shape[1] // 2, cy - f.shape[0] // 2)


def scene(name, v, vmeta, meta_ui, fx):
    """Recreate the mock's moment in the level."""
    shadow = np.array(Image.open(OUT / "sprites/player_shadow.png"))
    ball = fx["ball"]
    extras_net = []

    def P(variant, team, pose, mock_xy, flip=False, mock=True):
        feet = M(*mock_xy) if mock else mock_xy
        extras_net.append(sprite_layer(shadow, feet[0] - 22, feet[1] - 5))
        extras_net.append(place_player(variant, team, pose, feet, flip))

    if name in ("park", "dinosaur", "space", "undersea"):
        P("male", "blue", "toss", (150, 690))
        P("male", "red", "idle0", (1195, 700), flip=True)
        extras_net.append(fx_at(ball["file"], ball["frame_size"][0], 0, *M(212, 590)))
        hud = hud_overlay(meta_ui, "singles", {
            "left_score": [("big", "P1", hexrgb("6aa0ff"), "left"), ("big", "0", None, "right")],
            "right_score": [("big", "CPU", hexrgb("ff5a50"), "left"), ("big", "0", None, "right")],
            "title": [("big_gold", "ARCADE RULES", None, "centre")],
            "prompt": [("small", "PRESS     TO SERVE", None, "centre")]})
        btn = np.array(Image.open(OUT / "ui/button_B_red.png"))
        pb = meta_ui["hud_layout"]["singles"]["prompt"]["box"]
        hud.over(sprite_layer(btn, 0, 0)[0], pb[0] + pb[2] // 2 - 32, pb[1] + 6)
    elif name == "lakeside":
        P("male", "blue", "swing", (270, 705))
        P("male", "red", "idle1", (1140, 720), flip=True)
        sx, sy = M(437, 570)
        extras_net.append(fx_at(fx["spark"]["file"], fx["spark"]["frame_size"][0], 1, sx, sy))
        extras_net.append(fx_at(ball["file"], ball["frame_size"][0], 1, *M(560, 578)))
        extras_net.append(sprite_layer(np.array(Image.open(OUT / "sprites/ball_shadow.png")),
                                       *[round(c) for c in M(548, 652)]))
        hud = hud_overlay(meta_ui, "singles", {
            "left_score": [("big", "P1", hexrgb("6aa0ff"), "left"), ("big", "3", None, "right")],
            "right_score": [("big", "CPU", hexrgb("ff5a50"), "left"), ("big", "2", None, "right")],
            "title": [("big_gold", "ARCADE RULES", None, "centre")]})
    else:
        P("male", "blue", "reach", (450, 575))
        P("male", "red", "idle0", (930, 600), flip=True)
        P("female", "gold", "idle1", (210, 830))
        P("male", "green", "idle0", (1150, 825), flip=True)
        extras_net.append(fx_at(ball["file"], ball["frame_size"][0], 2, *M(622, 493)))
        hud = hud_overlay(meta_ui, "doubles", {
            "left_score": [("big", "BLUE", hexrgb("6aa0ff"), "left"), ("big", "4", None, "right")],
            "right_score": [("big", "RED", hexrgb("ff5a50"), "left"), ("big", "4", None, "right")],
            "title": [("big_gold", "DOUBLES", None, "centre")],
            "subtitle": [("small", "MATCH POINT", None, "centre")]})
        icon = np.array(Image.open(OUT / "ui/icon_ball.png"))
        tb = meta_ui["hud_layout"]["doubles"]["title"]["box"]
        hud.over(sprite_layer(icon, 0, 0)[0], tb[0] + 10, tb[1] + 16)
        hud.over(sprite_layer(icon, 0, 0)[0], tb[0] + tb[2] - 25, tb[1] + 16)
    # sort players by feet y (shadows first)
    shadows = extras_net[0::2] if False else []
    extra = [("stands", L, xy) for (L, xy) in crowd_sprites(vmeta["seats"], own=vmeta.get("crowd"))]
    post = np.array(Image.open(OUT / fx["net_post"]["file"]))
    ax, ay = fx["net_post"]["anchor"]
    px, py = fx["net_post"]["position"]
    extras_net.append(sprite_layer(post, px - ax, py - ay))
    extra += [("net", L, xy) for (L, xy) in extras_net]
    img = preview.composite(v, extra=extra)
    hud_img = Image.fromarray(hud.a)
    img = img.convert("RGBA")
    img.alpha_composite(hud_img)
    return img.convert("RGB")


def main():
    previews_only = "--previews-only" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1,
        "resolution": [SCREEN_W, SCREEN_H],
        "scaling": "Integer scale with nearest-neighbour filtering: x2 1080p, "
                   "x4 4K; letterbox or pixel-perfect fractional for 1440p.",
        "layer_overscan": [OVER_X, OVER_Y],
        "court": C.geometry(),
        "court_mask_roles": C.ROLE,
        "court_mask_doc": "court_mask.png is 8-bit; each pixel is a role id. "
                          "Recolour the ground by role (presets in "
                          "data/court_colors.json); the venue's ground layer "
                          "is the default colouring.",
    }
    pmeta, _ = build_players()
    cmeta, crowd_rows = build_crowd()
    umeta = build_ui()
    fmeta = build_fx()
    manifest["sprites"] = {"players": pmeta, "crowd": cmeta, **fmeta}
    manifest["ui"] = umeta
    manifest["venues"] = {}
    built = {}
    for name in venues.VENUES:
        v, vm = build_venue(name, crowd_rows)
        manifest["venues"][name] = vm
        built[name] = (v, vm)
    (OUT / "palettes.json").write_text((KIT / "art/sprites/hd/src/palettes.json")
                                       .read_text())
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    for name, (v, vm) in built.items():
        img = scene(name, v, vm, umeta, fmeta)
        save(img, f"previews/{name}.png")
        if name in MOCKS:                  # the gym (ADR-078) has no mock to compare
            save(preview.side_by_side(img, KIT / "art/concept" / MOCKS[name]),
                 f"previews/{name}_vs_mock.png")
    print("built", OUT)


if __name__ == "__main__":
    main()
