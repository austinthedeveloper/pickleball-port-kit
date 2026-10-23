# ADR-084 — DINOSAUR's Dinosaurs From the Dinosaur Game

Status: **Accepted 2026-10-22**
Milestone: `PORT-76` (the user asked for the Carnotaurus of their SNES
dinosaur game to wander the dinosaur level's background, and for their
other dinosaur sprites to be tried there).
Builds on: ADR-046 (the fun venues), SNES ADR-064 (a venue's critter).

## Context

The DINOSAUR venue's dinosaurs are painted into its layers by
`art/levels/tools/critters.py` and stand still. The user's dinosaur game
(`../dinosaur`) has a Carnotaurus ridden by Nathan, in hi-res Aseprite
files with walk and idle tags, and two-pose sprites of other dinosaurs.
The user cares that these characters stay as drawn: Nathan's face is
never redrawn.

## Decision

- **Their sprites, as drawn.** `art/sprites/dinos/export.sh` takes the
  frames out of the dinosaur repo (the Aseprite CLI for the Carnotaurus's
  tags, copies for the rest) into `art/sprites/dinos/out`, and
  `sync_assets.sh` puts them in `game/assets/dinos`. No pixel is edited;
  the only change is scale (the baby dinosaur at 2x). The dinosaur repo is
  only read.
- **The cast** (`game/view/dino_walkers.gd`, `DinoWalkers.CAST`):
  - the Carnotaurus with Nathan (`mount_walk`, `mount_idle`), at 1x (144x96
    cells, the dinosaur about 104 px long, the size of the painted ones):
    he walks the stands behind the fence at 0.5 px a frame, stops to look
    about (the idle and its blink) and turns back, and once a lap walks off
    the right edge and comes back. His stops are in the gaps between the
    painted dinosaurs;
  - the Spinosaurus's two breathing poses, in the jungle's clear gap;
  - the baby dinosaur's two-frame walk at 2x, patrolling the jungle's
    edge on the left;
  - the pterodactyl's two-frame flap crossing the sky every 1800 frames,
    behind the hills and the volcano.
  The raptor, T. rex and Brachiosaurus were tried and left out: the venue
  already paints each of them, and the scene was getting crowded.
- **Depth.** Each sits just in front of a backdrop layer and under the
  next, and moves with that layer's parallax: the Carnotaurus on the
  stands (under the crowd and the fence, so his feet stay behind the
  palisade, like the painted ones'), the Spinosaurus and the baby on the
  trees, the pterodactyl on the sky. They take the backdrop's time-of-day
  tint and dim with it on a long rally (PORT-43).
- **Display only, deterministic.** Places and frames are functions of the
  sim's frame count (a looping route of walks and stops), so screenshots,
  replays and the demo repeat; the view never writes to the sim.

## Consequences

- `test_dinos.gd`: only on DINOSAUR; the sim unchanged beside a bare one;
  two views agree frame for frame; the Carnotaurus's route crosses the
  venue, turns both ways, uses every frame and never jumps, the loop
  included; everything stays under the fence and behind it.
- OPEN PLAY's DINO PARK (ADR-078, `art/park/`) doesn't have them yet.
- A rebuild of the export needs the dinosaur repo beside the kit (or
  `DINO=`). The committed `out/` strips are what the game ships.
