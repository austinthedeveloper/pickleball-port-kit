# ADR-052 — Godot port: integer sim, read-only presentation

Status: **Accepted 2026-10-16**
Milestone: `PORT-01`. Depends on: ADR-011 (projection), ADR-018 (doubles),
ADR-019 (shots), ADR-020 (paddles), ADR-023 (opponents), ADR-025 (options),
ADR-044 (charged serve); the 960×540 art (art/levels).

## Decision

The modern port is a Godot 4.7 project in `game/`. Its simulation is a
line-by-line port of the SNES C sim (`reference/snes-src/src`: ball,
collision, player, serve, rules, game flow, main.c's CPU schedule, and
ai.c) to pure GDScript in `game/sim/`, kept integer-exact: 12.4 fixed point
in ints, C's truncating division, and the u8/u16 wraps masked where the C
state wraps. Presentation (`game/view/`) only reads the sim and its event
stream, at the 960×540 art density, through the art's court geometry.

## Why

- **Playbook rule 1.** The C sim is already tuned and tested; porting it
  exactly means its tests and balance numbers port with it, and a golden
  trace protects them from day one.
- **Playbook rule 2.** A read-only view keeps every display feature (art,
  HUD, crowd, sound, animation variants) free of simulation risk; a test
  proves it frame by frame.
- **Determinism for free.** GDScript ints are 64-bit and integer math is
  exact on every platform, so no fixed-point library is needed.

## Details

- **Frame pipeline** (playbook 0.3): human intents → CPU thinks on the
  shipped schedule (singles CPU every frame; a doubles lane cover every
  4th frame staggered by slot; the demo P1 every other frame) →
  `game_update` (players, serve or live play, rules, result phases) →
  events → presentation. `Sim.step()` is the whole sim frame, run at a
  fixed 60 Hz in `_physics_process`.
- **Projection.** World x 16..240, y 90..170 map to the art's court
  (`CourtView`, the manifest's corners); height is scaled per row so the
  12 px net is the painted net. Tests compare the projected corners,
  kitchen lines, and net height with the manifest.
- **Animation variants** (overhead, scoop, reach) are chosen display-side
  at the swing's first frame from the ball height and shot; the sim has
  one swing.
- **Data.** `data/opponents.json` (styles, ladder), `paddles.json`. The
  SNES generator's paddle tables aren't in the kit, so `Paddles` rebuilds
  them from the documented rule (3/64 per point off the baseline); the
  standard paddle is exactly the C constants.
- **Ported:** singles, doubles (ADR-018 lanes and teamwork), shot types,
  the charged serve, paddle stats, opponent styles, difficulty including
  the KID/EASY slow ball and KID's swing assist, the demo, 2P versus.
- **Not ported yet:** modifiers (ADR-033), practice (ADR-028), open play
  (ADR-034), career and save (ADR-021/047), story cards and quips
  (ADR-026/048), close-call replay (ADR-041), night (ADR-045), camera and
  parallax motion (ADR-050/051; the layers carry parallax factors).

## Rejected (and why)

- **Floats with a tolerance.** The golden trace and the C balance numbers
  need exact reproduction; ints cost nothing here.
- **A new sim designed for the engine.** It would throw away the tuned
  AI and every test; the C structure (one module per section) is kept so
  a diff against the reference stays readable.
- **GUT for tests.** A 60-line runner keeps the project self-contained and
  fails the run on a script error (a test that runs no assertions fails).
- **Godot physics.** Not deterministic across frames/platforms for this
  use, and the rules are 2D-plus-height arithmetic.

## Verification

`game/tools/test.sh` (headless, 62 tests):

- Ported C host tests: PHY-01..05, HIT-01/02, RUL-01..03, SCR-01, RST-01
  (20 rematches equal a fresh match), serve setup/boxes, the charged-serve
  sweep (every level, rising and falling, every aim, both teams and
  boxes), shot types, paddle stats, doubles rotation and lane ownership.
- Balance: a stand-in that mistimes every 2nd shot wins 0/20, every 10th
  18/20 (the C build measured 1 and 19); bot wins by difficulty KID..HARD
  10/6/0/0 of 10; ladder first rung 8 vs last rung 0.
- Golden traces: three scripted runs (singles demo, doubles demo, bot vs
  CPU) × 9000 frames, hashed per frame.
- Presentation: the view's sim equals a bare sim for 1500 frames; the
  painted court is the called court; every venue builds.
- Perf gate: worst case named (doubles, four CPUs, KID ball): 159 µs worst
  frame, 4% of a quarter-frame budget.
