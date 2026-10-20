# ADR-072 — The Ball: 78% by Default, and BALL SIZE

Status: **Accepted 2026-10-20**
Milestone: `PORT-47` (the user's asks: "I like it at about 78% speed.
Make that the default"; a ball about 5% larger, on a slider, smaller
than BIG BALL).

## Decision

- **BALL SPEED defaults to 78%** (`Settings.BALL_SPEED_DEFAULT`). The
  sim's own default stays 100 (`MatchConfig.ball_speed`): the ROM's
  traces, the golden traces and the tests ported from the C run the ROM's
  ball. A 0.16.0 save holds 100 for everyone who never moved the slider;
  without the new `ball_speed_v` marker, 100 reads as 78. A choice saved
  since is kept. The title's MODIFIERS row counts the speed only when it
  isn't 78.
- **BALL SIZE**, MODIFIERS' second row: 80% to 150% in 1% steps, 105% by
  default. It is **display only**: the ball's sprite and its shadow,
  never the reach (BIG BALL's bigger reach is its own, and BIG BALL still
  draws the ball at 200%). Saved with the settings; each player's own,
  online too.
- MODIFIERS moved up (it's 15 rows now) to clear the key legend.

## Tests

`test_ball_speed`: the default and the 0.16.0 migration; BALL SIZE
scales the sprite and shadow, not the reach, and BIG BALL overrides it.
`test_conformance` and the C-ported practice tests pin the ROM's 100%.
At 78% the CPUs still never commit a momentum fault (`test_momentum`).
