# ADR-059 — The Sim Caught Up to the ROM

Status: **Accepted 2026-10-18**
Milestone: `PORT-35`. Ports: SNES ADR-052 (the kitchen line), 053 (GHOST,
POPCORN, ICE), 055 (a ladder per mode), 058 (CPU serve power and duds),
062 (the ladder rebalance), 063 (more quips), 068/069 (the tuning
reference and conformance traces), and TUNING_VERSION 2-4. With ADR-058
(the slice), the port's sim is the ROM's at **TUNING_VERSION 4**.

## How it's proven

`game/tools/conformance_import.sh` builds the SNES repo's
`tools/conformance.c` on the host (in a temp folder; nothing is written
there), runs its four scenarios (singles vs PETE, doubles vs the TWINS,
KID vs the default CPU, and HARD vs KAI with BIG BALL, FAST BALL, LAVA,
POPCORN and ICE), and keeps each frame's line as an md5 prefix in
`game/tests/conformance/`. `tests/test_conformance.gd` plays the same
scenarios and compares **every frame of every scenario** (5400 each: the
intents, the game state, the ball, every player). All four match. Its
first run found where the port had drifted, in this order: the CPUs'
styles (the rebalance), the serve's aim and power, KID's top speed, the
assist, and ICE and POPCORN. `K.TUNING_VERSION` records the version; a
newer import fails `test_tuning_version` until the port catches up.

## What changed in play

- **The CPUs** play the ROM's `opponents.json` (taken whole: it was a
  superset of the port's): the rebalanced ladder (SNES ADR-062 and tuning
  v2-4), serve power and duds (058), and sixteen quips a team (063).
- **The serve:** a CPU picks its depth before the press and keeps it
  through the toss; a short serve goes to the middle of the box at the
  classic power; a style's `serve_power`, and a dud when the frame count
  is a multiple of `serve_dud` (no RNG).
- **The lane covers' stagger** counts the match's frames (frame_count,
  0 at each new match), so a rematch plays like the first match.
- **KID:** a CPU's top speed is its style's *before* the difficulty
  (game.c sets it first), so KID's speed change never reaches the running
  speed. That looks unintended in the C, but the ladder is tuned with it:
  the port copies it.
- **The kitchen line counts as in** for the volley fault (`court_in_kitchen`,
  `COURT_IN_KITCHEN_FP`); LAVA's test still leaves the line out, as the
  C's does. The port's ADR-055 "arcade allowance" is gone.
- **Modifiers GHOST BALL, POPCORN, ICE** (MODIFIERS, saved): POPCORN adds a
  step to the pace table every 12 ticks per hit, up to six levels, and
  the AI's prediction knows; ICE halves the acceleration and cuts the
  friction to a sixth, and the CPUs coast to a stop; GHOST hides the ball
  above 8 px except 2 frames in 16 (display only). GLOW and INVERSE are
  PORT-39.
- **A ladder per mode** (save v6): singles and doubles each keep a place;
  a v5 save's one rung becomes both. Quitting a ladder match (pause, MAIN
  MENU) starts that mode's ladder over; a loss keeps it.
- **Quips** go through a shuffled deck per side (story_quip): every line
  once before any again, from the frame count.

The harness, bot wins of 10: KID..HARD **10, 9, 4, 3** (was 10, 6, 0, 0);
first rung 10, last rung (CHAMPS) **3** (was 0). The rebalance made the
upper rungs beatable, as the ROM's playtesting asked.

## Port-only, kept apart

- **The overhead** (port ADR-053) is the remaster's: `MatchConfig.overhead`
  (on) switches it off for the traces, which are the ROM's.
- **KID's swing assist** never plays for the stats bot (`p1_bot`): it is
  for humans, and the C's harnesses don't run it (it lives in main.c).
- The quip deck picks the side's lines the port's way (multiplayer has
  more sides than the ROM's 2P).

## Golden traces

Regenerated: all three move (the CPUs' styles and serves). The
conformance traces are now the stronger check on the sim.
