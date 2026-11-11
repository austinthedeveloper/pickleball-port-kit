# ADR-113 — Tuning 5: the Push

Status: **Accepted 2026-11-11** (asked for by the user: "Yes, do it", to
catching the sim up to the ROM's latest tuning).
Milestone: `PORT-128` (GitHub #18).

## Context

The port matched the ROM's **TUNING_VERSION 4** (PORT-35, the
conformance traces from the SNES repo at `6199009`). The SNES repo has
three commits since:
- **SNES ADR-075, the tutorial:** a title entry and a ball-machine
  lesson. The port has its own HOW TO PLAY (PORT-30), so there's
  nothing to copy.
- **SNES ADR-076, the push:** a rule of play, and **TUNING_VERSION 5**.
- **SNES ADR-077, story mode:** match config and save data. The port has
  its own story (PORT-44, port ADR-069).

So the push is the only rule there is to port.

## Decision

**The push (SNES ADR-076), as the C has it:**
- A standard shot or drive aimed toward the net lands deeper the longer
  the direction was held there:
  - `HIT_PUSH_START_X` (212) plus a pixel per 2 frames of
    `Intent.push`;
  - 228, the old deep spot, at 32 frames (`HIT_PUSH_DEEP`);
  - out past the baseline from 58 frames (`HIT_PUSH_OUT_FRAMES`);
  - never past `HIT_PUSH_MAX_X` (252).
- Lobs, dinks, slices, short shots and serves are unchanged.
- `Sim.apply_targeted_shot` follows `collision.c`'s shape.
- The six constants are in `k.gd`, from `tuning.json` v5 (the test
  checks their values).

**Where the count lives:**
- The C counts the push in its input layer (`input_state.c`'s
  `build_intent`). In the port, `Sim.step` counts a human's push
  (`Sim.count_push`) from the aim it is handed:
  - a frame aimed toward that player's net adds 1, to 255;
  - any other frame resets it to 0: away (SHORT's aim), or nothing held.
- So the push is part of the sim's state (it lives in `Intent`, which
  `SimState` keeps). That means:
  - it rolls back and replays with no change to the netcode;
  - it travels online as the aim it already sends, so there's no new
    message field and no protocol bump. Different builds already refuse
    each other by version.
- `MatchInput` is unchanged. The guest's mirrored aim (port ADR-110)
  is flipped before the sim reads it, so its push counts the same way.

**The CPU** pushes exactly to the old deep spot, as `ai.c` does:
- `HIT_PUSH_DEEP` on a deep plan, else 0;
- reset on each think, and carried by the held intent between thinks.

So every CPU shot, the golden traces and `rally_stats` are unchanged.

**PICKLE SMASH** (the remaster's SPECIALS, port ADR-080) aims deep with
`HIT_PUSH_DEEP`, so it still lands where it did.

**The conformance traces** are re-imported at SNES `41f12f5`. Each frame's
line now carries the intent's push, as `tools/conformance.c` prints it.
`test_conformance` replays all four frame for frame.

**HOW TO PLAY** gets one tip: P1's rally shot out past a baseline says
OUT LONG: HOLD TOWARD THE NET LESS. It isn't shown for a serve, a CPU's
shot or a wide one.

## Consequences

- A human's shot aimed deep on a tap now lands at 212, not 228. To reach
  the old deep spot, hold the direction about half a second. Held a
  second, the shot goes out. Moving toward the net while swinging pushes
  too, as on the cart.
- **Replays saved before this are refused:** a replay plays only on its
  own TUNING_VERSION (port ADR-081). They show FROM AN OLDER GAME in
  REPLAYS, and can't be fixed by a migration, since their inputs would
  play differently (KNOWN_ISSUES #100).
- `test_collision` ports the C's `test_push_depth` and `test_input`'s
  `test_push` (as `test_push_counts`, through `Sim.step` and a
  `SimState` round trip).
