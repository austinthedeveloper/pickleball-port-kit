"""MOTEL's re-layout (round 2's plate kept the concept's pool, about 78 px
low at 960x540): the band above the pool floor moves up 40 px unscaled, so
the coping and tile row end at y 222 (the court's far edge), and the floor
from y 300 stretches down to the near strip at y 449. The same mapping is
applied to the plate and the cutouts so they stay registered. The 40 rows
cut from the top are kept as the camera's overscan by the import.

    .venv/bin/python art/venues-r2-fixes/motel_relayout.py
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
SRC = HERE.parent / "venues-r1"
TOP, COPING, FLOOR, STRIP, COURT_TOP = 40, 262, 300, 449, 222  # 960x540 rows


def relayout(im: Image.Image) -> Image.Image:
    w, h = im.size
    s = w / 960
    def r(y): return round(y * s)
    out = Image.new(im.mode, im.size)
    out.paste(im.crop((0, r(TOP), w, r(COPING))), (0, 0))
    floor = im.crop((0, r(FLOOR), w, r(STRIP)))
    out.paste(floor.resize((w, r(STRIP) - r(COURT_TOP)), Image.LANCZOS), (0, r(COURT_TOP)))
    out.paste(im.crop((0, r(STRIP), w, h)), (0, r(STRIP)))
    return out


for name in ("motel_plate", "motel_cutouts"):
    relayout(Image.open(SRC / f"{name}.png")).save(HERE / f"{name}.png")
