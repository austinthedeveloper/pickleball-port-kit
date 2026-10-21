# The ball machine

Practice's ball machine (ADR-028), the swing-arm design: row C of
`art/concept/ball-machine.png`. A grey cart with a hopper of balls and a
launcher arm on a pivot, facing left (toward P1). 36x26 art px, drawn at
2x in the game, as the players are.

| File | What |
|---|---|
| `src/machine.py` | Draws the layers into `src/layers/`: body, the arm at nine angles (32° up the screen to 32° down), the pivot hub |
| `src/build_machine.lua` | Makes `machine.aseprite` (layers body, arm, hub; a frame per angle, tag `swing`) and `out/machine.png` |
| `machine.aseprite` | The source: open it to see the arm swing |
| `out/machine.png` | The game's sheet: cell 0 the body, 1..9 the arm, 10 the hub |
| `preview.png` | Every angle composed, at 8x |

The game (`view/practice_view.gd`) draws the body, the arm frame and the
hub, so the arm swings alone: it eases toward the sim's pose through the
frames between, and recoils along itself on a feed.

## Rebuilding

```sh
.venv/bin/python art/sprites/machine/src/machine.py
ASE="$HOME/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite"
"$ASE" -b --script-param root=. --script art/sprites/machine/src/build_machine.lua
game/tools/sync_assets.sh
```

Hand-polishing in Aseprite is fine too. Once you do, export the sheet
from `machine.aseprite` and stop regenerating it.
