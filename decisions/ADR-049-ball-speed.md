# ADR-049 — Ball Speed

Status: **Accepted 2026-10-15**
Milestone: `M4-OPT-03`. Depends on: ADR-025 (options, the slow ball),
ADR-033 (FAST BALL).

## What

A **BALL SPEED** row on the OPTIONS page: 70% to 120% in 5% steps, saved,
for every match (the demo too). Default **100%**, today's game.

It was asked as "about 10% slower" plus a way to dial it in. At 90% the
CPUs' balance moved more than expected (below), so the default stays 100%
until the speed is chosen by play; then one pass sets the default and
retunes the ladder for it.

## How

The ball keeps its arcs and bounces; it takes fewer (or more) physics
steps per frame, as the slow difficulties already did:

- The step pattern's cycle is **60 frames** (was 12): KID's 2 in 3, EASY's
  3 in 4, and 5% steps all divide it.
- Steps per cycle = the difficulty's share x BALL SPEED
  (`options_ball_per_cycle`), spread evenly (`modifiers_ball_pace`: a step
  each time the running share passes a cycle), plus FAST BALL's step every
  3rd frame. Above 100% some frames take two steps (three with FAST BALL).
- The table holds a cycle and 12 frames of the CPUs' lookahead past it
  (`GAME_BALL_PACE_TICKS`). At 100% on MEDIUM and HARD without FAST BALL
  the ball is not paced at all, as before: the golden trace and the
  balance tables at 100% are identical.
- Saved in the settings' spare byte (`ball_speed`, was `reserved`) as
  choice + 1: 0, in every older save, is the default. No layout change.
- The HUD font gained `%`.
- `make stats ... SPEED=90` measures the ladder at a speed.

## Balance at 90% (bot wins of 60, MEDIUM, `make stats LATE=0`)

| Rung (singles) | 100% | 90% |
|---|---:|---:|
| DAD | 48 | 48 |
| MARGE | 32 | 2 |
| BRAD | 26 | 28 |
| PETE | 16 | 7 |
| RAVEN | 15 | 0 |
| KAI | 4 | 5 |
| MAX | 2 | 0 |
| ACE | 0 | 0 |

Doubles moved less (regular bot: GYM BROS 44 to 23; net bot: GOTH CLUB 24
to 37, SURF CREW 11 to 34). The bot mistimes on a schedule; a slower ball
mostly gives a human more time to react, which it doesn't model, so these
overstate the change a player feels. `test_ai: test_scheduled_reaction`
also met one legitimate ace at 90% (a deep serve carried past reach before
GYM BROS's slow reaction got there).

## Tests

`test_options.c: test_ball_pattern` (steps per cycle by difficulty and
speed, saved choices), `test_editor` (the row, cancel); `test_modifiers.c:
test_ball_steps` (90% spread with no two missed in a row, KID, FAST BALL,
120%'s double steps, the lookahead repeating the cycle). MesenCE: the row
and its `%`. Golden trace identical; `make perf` zero overruns.
