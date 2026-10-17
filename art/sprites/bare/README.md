# Bareheaded SNES player set

A reference set for the SNES game, derived from the 32×32 capped set in
`art/sprites/`, which is unchanged. It uses the same style, the same palette
contract v2 (16 colours, no new ones), and the same frame format: 32×32,
facing right, feet ending on row 29, index 0 transparent, no ground shadow,
nothing outside the frame.

## What's here

| File | Contents |
|---|---|
| `player_bare.aseprite` | 15 frames, tagged: idle, run, swing (windup→follow), toss, cheer, overhead (windup→contact), reach, scoop. Blue palette |
| `ponytail_bare.aseprite` | 8×8 ponytail for the bare head |
| `hats.aseprite` | 16×8, one tagged frame per hat: cap, visor, headband, tricorn, bandana |
| `player_bare_<team>.png` | 512×32 indexed strip: 11 frames, then the 4 new poses, then the ponytail in the top-left of a 32×32 cell |
| `cap_<team>.png` | The cap cell alone, 16×8 |
| `hats_<team>.png` | 80×8: cap, visor, headband, tricorn, bandana |
| `offsets.json` | Per-frame ponytail, head, and hat positions (the table below) |
| `preview_<team>.png` | Row 1 bare, row 2 with the ponytail, row 3 with the cap, row 4 idle0 in each hat |
| `preview_<tag>.gif` | The animations, 8× |

## How it lines up

- **Bodies.** Only the head changed. From the eyes down (head row 6 and
  below), every pixel matches the capped frames, and `compose.py` asserts
  this on every build. The head origin is the same in every frame.
- **Hair.** Index 15 and the outline only, short and close to the skull, so
  a hat cell covers it.
- **Cap.** Use the 16×8 cell at the frame's accessory offset plus
  `hat_offset` (4, −4), the existing rule (M4-OPP-04). In **idle0** the cell's
  top-left goes at **(9, 1)**. The build derives the cap from the capped head
  minus the bare head, so cap over bare idle0 equals the original capped
  idle0 pixel for pixel. That holds for 9 of the 11 frames. In **follow** the
  paddle grip crosses the brim (9 px), and in **cheer** the raised fist does
  (4 px). The hat draws in front of its body, so the cap covers those pixels
  there. If that matters in game, nudge those two paddle/arm parts down a
  pixel or two.
- **Other hats.** They sit at the same place and follow the SNES hats'
  colour roles: visor and headband in the shoe accent (10), tricorn in hair
  (15) with highlight (14) trim, bandana in the shirt ramp (5–7). They only
  add pixels over the bare head, so they no longer need to hide a cap.
- **Ponytail.** It is tied at the back of the crown and drawn behind the
  body, at the same per-frame offsets as before.

## Offsets

`ponytail` is the 8×8 cell's top-left (`accessory` in `player_frames.json`).
`head` is the head origin (ponytail + (5, −2)). `hat` is the 16×8 hat cell's
top-left (ponytail + (4, −4)). The first 11 ponytail offsets are unchanged.

| Frame | Ponytail | Head | Hat |
|---|---|---|---|
| idle0 | (5, 5) | (10, 3) | (9, 1) |
| idle1 | (5, 6) | (10, 4) | (9, 2) |
| run0 | (5, 6) | (10, 4) | (9, 2) |
| run1 | (5, 7) | (10, 5) | (9, 3) |
| run2 | (5, 6) | (10, 4) | (9, 2) |
| run3 | (5, 7) | (10, 5) | (9, 3) |
| windup | (4, 6) | (9, 4) | (8, 2) |
| swing | (6, 5) | (11, 3) | (10, 1) |
| follow | (6, 5) | (11, 3) | (10, 1) |
| toss | (5, 5) | (10, 3) | (9, 1) |
| cheer | (4, 8) | (9, 6) | (8, 4) |
| overhead_windup | (6, 4) | (11, 2) | (10, 0) |
| overhead_contact | (5, 5) | (10, 3) | (9, 1) |
| reach | (3, 7) | (8, 5) | (7, 3) |
| scoop | (4, 8) | (9, 6) | (8, 4) |

## New poses

- **overhead_windup:** side-on, paddle hand cocked back behind the head, the
  paddle dropped behind the back, the off arm pointing up at the ball.
- **overhead_contact:** arm up and forward, paddle at its highest, with the
  top of the paddle on row 0.
- **reach:** a wide lunge with the far leg straight back and the paddle out
  low beyond the front foot (mirror it for the other side).
- **scoop:** deep knees, paddle flat and face-open just above the ground.

## Rebuilding

```sh
python3 art/sprites/src/compose.py        # both sets + offsets; prints any cap overlap
ASE="$HOME/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite"
"$ASE" -b --script-param root=. --script art/sprites/src/build_bare.lua
"$ASE" -b --script-param root=. --script-param team=blue \
  --script-param out=art/sprites/bare/preview_blue.png --script art/sprites/src/preview_bare.lua
```

`compose.py` also regenerates the original capped frames
(`src/player_frames.txt`), and they stay byte-identical.
