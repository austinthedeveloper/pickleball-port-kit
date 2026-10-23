# DINOSAUR's background dinosaurs

The DINOSAUR venue's walking, breathing and flying dinosaurs (ADR-084,
PORT-76), drawn with the sprites of the SNES dinosaur game
(`../dinosaur/assets`, the user's other project). They're used as drawn:
no pixel is changed here, and nothing in the dinosaur repo is written.

| File in `out/` | From (`../dinosaur/assets/`) | Cells | In the game |
|---|---|---|---|
| `carno_mount_walk.png` | `carnotaurus/aseprite/carnotaurus_mounted.aseprite`, tag `mount_walk` | 4 × 144x96, faces right, feet on row 90 | The Carnotaurus with Nathan up, walking the stands behind the fence (1x) |
| `carno_mount_idle.png` | the same file, tag `mount_idle` | 2 × 144x96 (the second is the blink) | ...and stopping to look about |
| `spinosaurus_idle.png` | `enemies/spinosaurus-idle-preview.png` | 2 × 96x64, faces left | Breathing at the jungle's edge (1x) |
| `baby_dino_walk.png` | `enemies/baby-dino-patrol-sheet.png` | 2 × 32x32, faces right | Patrolling the jungle's edge (2x) |
| `pterodactyl_flap.png` | `enemies/pterodactyl-swoop-sheet.png` | 2 × 32x32, faces left | Crossing the sky behind the volcano (1x) |

The idles come from the `-preview.png` files: they keep both full
breathing poses, where the 64x64 `-sheet.png` production cells are a
squeezed single pose (the SNES game's OBJ budget; its
`documents/concept-art-analysis.md`).

The game's timing, routes and layers are `CAST` in
`game/view/dino_walkers.gd`.

## Rebuilding

```sh
art/sprites/dinos/export.sh          # DINO=/path/to/dinosaur if it isn't ../dinosaur
game/tools/sync_assets.sh
```

The script takes the Carnotaurus tags out of the `.aseprite` file with the
Aseprite CLI (as `art/sprites/hd/README.md` finds it, or `ASE=`) and
copies the other strips. It reads the dinosaur repo's working copy, so an
uncommitted edit there comes along.

## Tried and left out

The raptor, T. rex and Brachiosaurus idles (`enemies/*-idle-preview.png`)
read well too, but the venue already paints a raptor pair, a T. rex and a
long neck (`art/levels/tools/critters.py`), and the jungle's one clear gap
(between the spectators, x 400-590) holds the Spinosaurus. The T. rex
disappeared behind the triceratops on the right; the Brachiosaurus doubled
the painted one. The golden berry isn't a dinosaur.
