# ADR-115 — The Push's Slack

Status: **Accepted 2026-11-12** (asked for by the user: "Be a little more
generous with players hitting out balls because they held a direction
too long").
Milestone: `PORT-172`.

## Context

The push (SNES ADR-076, port ADR-113): a human's standard shot or drive
aimed toward the net lands a pixel deeper per 2 frames the direction is
held, from 212. It reaches the old deep spot (228) at 32 frames and goes
out past the baseline from 58 frames, about one second. Moving toward
the net while swinging counts as aiming there, so a player running in
to their shot often holds past 58 without meaning to and hits long.

## Decision

**Remaster-only slack past the deep spot:**
- Up to `HIT_PUSH_DEEP` (32 frames) the push is the ROM's: a pixel per 2
  frames, so a tap and a half-second hold land as before.
- Past it, a pixel per 3 frames (`HIT_PUSH_LATE_FRAMES_PER_PX`). The last
  12 px to the baseline take 36 frames, not 24.
- So a hold goes out from 71 frames (`HIT_PUSH_OUT_FRAMES_REMASTER`),
  13 frames (about 0.2 s) later than the ROM's 58. The cap
  (`HIT_PUSH_MAX_X`, 252) is unchanged.
- `Sim.push_px` holds the curve; `apply_targeted_shot` takes the
  remaster flag (`MatchConfig.overhead`, as SHORT held does, port
  ADR-096).

**The ROM's rules are unchanged:** with `overhead` off (the conformance
traces), the push is the C's, and `test_push_depth` checks it there.

**The CPU** pushes exactly `HIT_PUSH_DEEP`, which is the same in both
curves, so CPU shots, the golden traces and `rally_stats` are unchanged.
PICKLE SMASH aims with `HIT_PUSH_DEEP` too.

## Consequences

- A long hold toward the net still deepens the shot, and still goes out,
  but about 0.2 s later. Holds of 58-70 frames that went long now land
  deep in.
- A saved replay with a human push of 58+ frames, recorded before this,
  plays differently (KNOWN_ISSUES #101). TUNING_VERSION is the ROM's and
  isn't bumped for a remaster rule.
- `test_collision.test_push_slack` checks the curve: the ROM's to the
  deep spot, in to 70 frames, out from 71, capped.
