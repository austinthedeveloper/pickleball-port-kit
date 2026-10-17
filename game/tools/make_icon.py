"""The app icon from the art (PORT-09): P1's head (male, blue, cap) from the
idle frame, scaled up by whole pixels onto a navy tile with a gold ring,
like the title's panels. Writes game/icon.png (256x256).
    .venv/bin/python game/tools/make_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

KIT = Path(__file__).resolve().parents[2]
SHEETS = KIT / "game/assets/levels/sprites/players"
OUT = KIT / "game/icon.png"
FRAME = 128


def head_box(img):
    """The head: the top of the body down to just past the chin."""
    alpha = img.getchannel("A")
    box = alpha.getbbox()
    top = box[1]
    return (30, top - 2, 90, top + 40)


def main():
    body = Image.open(SHEETS / "player_male_blue.png").convert("RGBA").crop((0, 0, FRAME, FRAME))
    cap = Image.open(SHEETS / "player_male_blue_cap.png").convert("RGBA").crop((0, 0, FRAME, FRAME))
    body.alpha_composite(cap)
    head = body.crop(head_box(body))
    trim = head.getbbox()
    head = head.crop(trim)
    scale = max(1, min(200 // head.width, 200 // head.height))
    head = head.resize((head.width * scale, head.height * scale), Image.NEAREST)
    tile = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((4, 4, 251, 251), radius=44, fill=(251, 228, 106, 255))
    d.rounded_rectangle((14, 14, 241, 241), radius=36, fill=(22, 30, 64, 255))
    x = (256 - head.width) // 2 - 10
    y = (256 - head.height) // 2 - 8
    tile.alpha_composite(head, (x, y))
    d = ImageDraw.Draw(tile)
    d.ellipse((160, 172, 222, 234), fill=(224, 232, 48, 255), outline=(24, 20, 36, 255), width=5)
    for cx, cy in [(180, 192), (200, 190), (190, 210), (206, 212), (174, 214)]:
        d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(150, 160, 30, 255))
    tile.save(OUT)
    print("wrote", OUT, "head x%d" % scale)


if __name__ == "__main__":
    main()
