# ADR-058 — Four Swings and the Short Hold

Status: **Accepted 2026-10-18**
Milestone: `PORT-41` (part of PORT-35, the catch-up with the ROM). Ports:
SNES ADR-056 (slice on X, hold L or R to hit short) and SNES ADR-057
(CPUs slice). Depends on: ADR-052 (the port), ADR-053 (the overhead),
ADR-058 is the port's own record (SNES ADR numbers are cited as such).

## What

The ROM's four swings and its short hold, as the C does them
(`collision_apply_targeted_shot`, `build_intent`, `ai_plan_shot`):

- **SLICE** (`K.SHOT_SLICE`, the SNES's X): slow (pace 30, at least 34
  frames, the standard ceiling of 46), never deep (neutral, or short aimed
  away), steady off a stretch (10 wide, 8 long).
- **SHORT** held (the SNES's L or R) aims away from your own net, so any
  swing goes short while the D-pad still moves and aims at a sideline: a
  short shot, a fast drop, a dink, a short slice; a short serve too.
- **The fast drop's downside**: a drive aimed short sprays 34 long off a
  stretch (a drive's 22), so a mistimed one sits up mid-court.
- **CPUs slice** by style (`slice`, every Nth rally shot, after the dink
  pattern): WALT 3, RAVEN 3, VLAD 3, ACE 4, JADE 4.

## Port choices

- **Buttons.** The pad follows the SNES's layout by position: HIT south,
  DRIVE east, SOFT west, **SLICE north** (Xbox Y, PlayStation triangle,
  Switch X), **SHORT either shoulder** (LB or RB). The keyboard: HIT
  Space/J, DRIVE K, SOFT L, **SLICE I**, **SHORT Shift or U**. SLICE and
  SHORT are on CONTROLS (remappable); RB stays SHORT while SHORT is on LB.
  The read takes the slot's team, since "away" is -1 on the left, +1 on
  the right (2P, multiplayer, and an online guest play the right).
- **The overhead moved from shot 3 to 4**, so the slice has the C's number
  (3) and the code still diffs against the C. The overhead (ADR-053) stays
  HIT and DRIVE only: a slice at a high ball is a slice, as in the ROM.
  The doubles demo's golden trace changed for this alone: regenerated with
  the old numbers it is byte-identical to the old trace.
- **The ladder isn't the ROM's yet** (PORT-35): the slice knobs come from
  SNES ADR-057's table, set on the port's older ladder. The harness keeps
  its order (KID..HARD 10, 6, 0, 0; first rung 8, last 0).
- **Presentation:** its own sound (`0_hit_slice*`: padded, with the brush
  of the face across the ball; quieter than SOFT, as the ROM's), the small
  spark, a light rumble, SLICE on the stats card's winners. The title's key
  legend shows the four swings and SHORT (MOVE gave way), and HOW TO PLAY's
  SHOTS lesson asks for a DRIVE, a SOFT and a SLICE.

## Tests

`tests/test_shots.gd`, ported from the SNES repo's C tests:
`test_slice_and_fast_drop` (test_collision.c), `test_slice_and_short_hold`
(test_input.c, on fake pads), `test_cpus_slice` (test_ai.c: RAVEN slices
11 of 91 rally swings in 6 singles matches; none with her knob at 0), plus
a slice at a high ball staying a slice and the input map's bindings.
