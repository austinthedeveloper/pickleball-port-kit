# HD player sprites (modern port)

Players for the modern engine, styled after `art/concept/level-01..03`. The
SNES-sized set in `art/sprites/` (32×32, palette contract v2) is unchanged
and kept as a retro skin and reference.

- 64×64 frames, facing right. The character is about 48 px tall, matching the
  concept art's native pixel scale (the concepts are about 320×280 art pixels
  enlarged ~4.2×). Proportions follow the concepts: the head (cap included) is
  about 11×11 px, roughly 1/5 of the height. Feet end on row 58. The body's horizontal anchor is x ≈ 28;
  when you flip to face left, use 63 − 28.
- 11 frames in the same slot order as `data/player_frames.json`: idle0–1,
  run0–3, windup, swing, follow, toss (underhand serve), cheer.
- Male and female variants. The female variant has a ponytail baked in, and
  it flies back in the run, swing, and follow frames.
- Indexed by palette *role* (30 colours, listed in `src/rig.py` `ROLES`), so
  one drawing recolours to any team, skin tone, hair colour, or paddle.
  Palettes are in `src/palettes.json` (teams, paddles, 4 skins, 4 hairs).

| File | What |
|---|---|
| `player_hd_<male/female>.aseprite` | Source with tags: idle, run, swing (windup→follow), toss, cheer. Blue palette |
| `player_hd_<variant>_<team>.png` | Sheets, 704×64 (11 frames) |
| `preview_compare.png` | Close-up: an HD sprite beside a concept player at the same pixel scale |
| `archive_bighead/` | Earlier HD pass with an oversized head and thick body, kept for reference |
| `preview_scene.png` | Scale check: the four players on level-01 shrunk to native size, next to the concept's own players |
| `preview_frames.png`, `preview_<variant>_<tag>.gif` | All frames per team, and the animations |

## How the frames are made

`src/rig.py` renders each pose from joint positions (neck, hip, shoulders,
elbows, hands, knees, ankles, toe direction, paddle angle):

- Limbs, torso, shorts, shoes, and paddle are capsules lit from the upper
  left with 3–4 tone ramps. Far-side limbs use a darker ramp.
- Each body part gets its own 1 px outline, so the near arm reads over the
  torso the way it does in the concepts.
- The head (cap, hair, face) and the ponytail are hand-pixeled grids.

To add a pose (backhand, dink reach, overhead, dive…), add a joint dict to
`POSES` and its name to `SLOTS`, then rebuild:

```sh
ASE="$HOME/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite"
python3 art/sprites/hd/src/rig.py
"$ASE" -b --script-param root=. --script art/sprites/hd/src/build_hd.lua
```

The rig gets the poses and proportions right. A hand cleanup pass in Aseprite
(faces, hands, fabric folds) is where the last 20% of polish goes. Once you
start hand-editing, treat the `.aseprite` files as the source.

## Engine notes

A modern engine sets no hard limits on sprite size, colours, or frame count.
The constraint that matters is pixel density: sprites and backgrounds should
share one art-pixel grid. At the concepts' density, that's a virtual
resolution of about 384×216 (×5 = 1080p, ×10 = 4K) or 480×270 (×4 = 1080p,
×8 = 4K) for 16:9, scaled by a whole number with nearest-neighbour filtering.
Neither divides 1440p evenly, so pick letterboxing or a pixel-perfect
fractional scaler there. Bigger, more detailed characters mean redrawing the backgrounds at
the same higher density.
