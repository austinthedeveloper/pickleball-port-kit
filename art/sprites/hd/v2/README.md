# HD players, v2 body test

A side-by-side test of a reworked body and swing for the HD players. The
originals in `art/sprites/hd/` are untouched; nothing in the game uses
these files.

The game's players (`art/levels/tools/players.py`, the 2x rig) take the
same changes: the V-tapered torso, hips 2 px higher, the narrower shorts
and the new windup/swing/follow. The head is left alone there: every
pose keeps its neck, so heads, caps and hats are pixel-identical to
before; only the follow-through's paddle is tilted further forward to
stay clear of the face at that size.

| File | What |
|---|---|
| `player_hd_<male/female>_v2.aseprite` | Same 11 slots, tags and palette as the originals |
| `player_hd_<variant>_v2_<team>.png` | Sheets, 704×64 |
| `preview_compare_v2.png` | Every frame: old above v2, male then female |
| `compare_<tag>.gif` | Animated, left to right: male old, male v2, female old, female v2 |
| `src/rig_v2.py` | Copy of `../src/rig.py` with the changes below |

## What changed

- **Torso.** A V instead of a bean: the shoulder line runs through both
  shoulder joints and is wider than the waist, so when a pose turns the
  shoulders, the chest turns with them. The shirt hangs a little over the
  shorts.
- **Proportions.** Hips 2 px higher: a shorter torso, longer legs. Narrower
  shorts waist, slightly longer legs on the shorts.
- **Forehand.** Windup coils the shoulders (near shoulder behind the neck)
  and sits on the bent back leg, with the free hand pointing at the ball.
  Contact opens the hips and shoulders, drives onto the front knee and
  lifts the back heel. The follow-through wraps the paddle up past the face
  and drags the back foot on its toe.
- Idle, run, toss and cheer keep their joints; they change only through the
  torso and proportions.

## Rebuild

```sh
python3 art/sprites/hd/v2/src/rig_v2.py
ASE="$HOME/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite"
"$ASE" -b --script-param root=. --script art/sprites/hd/v2/src/build_hd_v2.lua
.venv/bin/python art/sprites/hd/v2/src/compare_v2.py
```
