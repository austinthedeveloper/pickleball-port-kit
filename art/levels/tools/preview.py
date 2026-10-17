"""Composite a venue's layers to a 960x540 screen (optionally with the
mock beside it) for review."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import court as C
from pix import SCREEN_H, SCREEN_W, Layer


def composite(venue, extra=(), cam=(0, 0)) -> Image.Image:
    """extra: [(after_layer_name, Layer, (x, y))] drawn after that layer."""
    out = np.zeros((SCREEN_H, SCREEN_W, 4), np.uint8)
    out[..., 3] = 255
    for name, L, par in venue.layers:
        dx = -L.ox - int(round(cam[0] * par))
        dy = -L.oy - int(round(cam[1] * par))
        _over(out, L.a, dx, dy)
        for after, E, (x, y) in extra:
            if after == name:
                _over(out, E.a, int(x), int(y))
    return Image.fromarray(out[..., :3], "RGB")


def _over(dst, src, x0, y0):
    h, w = src.shape[:2]
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    ww = min(w - xs0, dst.shape[1] - xd0)
    hh = min(h - ys0, dst.shape[0] - yd0)
    if ww <= 0 or hh <= 0:
        return
    s = src[ys0:ys0 + hh, xs0:xs0 + ww]
    d = dst[yd0:yd0 + hh, xd0:xd0 + ww]
    on = s[..., 3] > 0
    d[on] = s[on]


def side_by_side(img: Image.Image, mock_path: Path) -> Image.Image:
    mock = Image.open(mock_path).convert("RGB")
    mock = mock.resize((round(mock.width * SCREEN_H / mock.height), SCREEN_H),
                       Image.LANCZOS)
    out = Image.new("RGB", (img.width + mock.width + 8, SCREEN_H), (0, 0, 0))
    out.paste(img, (0, 0))
    out.paste(mock, (img.width + 8, 0))
    return out
