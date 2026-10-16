# ADR-038 — Doubles Balance: Footwork and the Middle

Status: **Accepted 2026-10-14**
Depends on: ADR-019 (shots), ADR-023 (styles), ADR-036 (teamwork),
ADR-037 (situational shots).

## Why

After ADR-037 the doubles ladder was out of order. Against a bot that plays
the net, TWINS lost 57-59 of 60 and GYM BROS (rung 3) 57; GOTH CLUB were
harder than the TWINS.

Point-by-point stats found one cause. Almost every doubles point ends with
a ball hit out, and every CPU ball hit out was a *stretched* contact (off
the sweet spot). A stretch sprays 20 px toward the sideline and 16 px long
(ADR-019). Doubles CPUs always aim at a lane 14 px inside the sideline, so a
stretched shot at a lane is always out. A sweet-spot contact never went
out.

Stretches came from two places:

- **The deliberate late shots** (`late_period`, the difficulty).
- **Mis-hits the CPU didn't plan:** 287 of 1004 TWINS shots against the net
  bot, 219 of them out. Pressing swing stops the feet, but a running player
  slides on: friction takes the speed, held under the paddle's swing limit,
  to zero over up to three frames, about 1 px. The swing check assumed the
  player stays where it pressed. A ball predicted just inside the sweet
  spot's edge was met just outside it. Drops were the worst case: they are
  played on the run against net players.

## What

- **`footwork` (0/1), a style knob.** The swing check plans from where the
  player will stop (`ai_slide`). It's on for TWINS, CHAMPS, `partner_style`,
  and the doubles partner (players[1]) of PIRATES, GOTH CLUB, SURF CREW.
  It's off for the first three rungs and the default CPU, which keep their
  mis-hits. With it, a TWINS player's unforced outs over 10 doubles matches
  go from 11-27 to 0.
- **The middle (doubles, `tactics`).** Every other shot goes down the
  middle, between the opponents, instead of at a lane. A stretched contact
  from the middle stays in.
- **One owner after the bounce (strict halves).** A ball bouncing by the
  middle crosses it. Teammates thinking on different frames could each see
  it on their own side and both chase it. Without `team`, the owner is now
  decided by the bounce point (the shared landing cache). Teamwork styles
  still decide by who is nearer the ball now: going by the bounce point,
  PIRATES lost 60 of 60.
- **Late periods**, retuned for doubles (players[1] only plays doubles, so
  singles is untouched):

  | Team | Change |
  |---|---|
  | HENDERSON | KIDDO late every 2nd (was 3rd) |
  | SNOWBIRDS | WALT every 3rd (was 6th) |
  | GYM BROS | `tactics` on and net 44 for both (they bash down the middle now); CHAD every 6th (was 2nd) |
  | GOTH CLUB | the partner every 6th (was 7th) |
  | SURF CREW | the partner every 7th (was 5th) |
  | TWINS | the partner every 7th (was 10th) |

  - The 2nd-rung partners got *more* errors: the one-owner fix made strict
    halves teams better (HENDERSON doubles 54 → 38 bot wins).
  - A stretched-contact reset (block the ball back when the swing check
    already knows it's stretched) was tried and dropped. The check almost
    never knows.

## Measured

Bot wins of 60 (three bot skills × 20 matches). The regular bot stays back
(the default CPU); the net bot plays the net (the partner style, without
footwork: a human mis-hits too). Before is the end of ADR-037.

| Team | Singles, regular | Singles, net | Doubles, regular: before | After | Doubles, net: before | After |
|---|---:|---:|---:|---:|---:|---:|
| HENDERSON | 54 | 56 | 57 | 60 | 48 | 60 |
| SNOWBIRDS | 33 | 48 | 42 | 44 | 49 | 60 |
| GYM BROS | 25 | 26 | 57 | 47 | 57 | 51 |
| PIRATES | 23 | 38 | 27 | 25 | 41 | 49 |
| GOTH CLUB | 3 | 12 | 0 | 11 | 22 | 32 |
| SURF CREW | 5 | 24 | 18 | 15 | 35 | 24 |
| TWINS | 0 | 9 | 17 | 14 | 59 | 21 |
| CHAMPS | 0 | 0 | 0 | 2 | 12 | 5 |

- **Doubles:** each rung is now harder than the one before, on the average
  of the two bots (60, 52, 49, 37, 22, 20, 18, 4).
- **Singles:** unchanged except footwork on the TWINS and CHAMPS captains:
  against the net bot, TWINS 20 → 9 and CHAMPS 7 → 0.
- **Your CPU partner** has footwork and the middle too. Against the strong
  teams it's a better partner.

## Amendment 2026-10-14: the doubles ladder, re-measured (M4-OPP-02)

`tools/match_stats.c` plays doubles now (`make stats MODE=1`, `+2` for the
net bot) and a whole ladder (`OPPONENT=-2`, with `LATE=0` for the three bot
skills). It plays P1's side as a human gets it: the bot with the CPU
partner (the partner style), not two bots. Smarter aim (ADR-039) had moved
the top of the ladder: SURF CREW won every match, and rungs 5-8 were all
under 10 bot wins. Only the partners (players[1], doubles only) changed,
so singles is as before:

| Partner | late period |
|---|---|
| CHAD (GYM BROS) | 7 (was 6; with M4-OPP-03's BRAD) |
| VLAD (GOTH CLUB) | 3 (was 4), no footwork |
| LANI (SURF CREW) | 5 (was 7), no footwork |
| MIA (TWINS) | 7 (unchanged, after the singles pass moved MAX) |

The singles pass (ADR-023 amendment) also moved three captains, who play
doubles too: RAVEN late 6, MAX 7, ACE 8.

Bot wins of 60 (three bot skills × 20, MEDIUM), `make stats LATE=0
OPPONENT=-2 MODE=1` and `MODE=3`:

| Team | Regular: before | After | Net: before | After |
|---|---:|---:|---:|---:|
| HENDERSON | 59 | 59 | 60 | 60 |
| SNOWBIRDS | 44 | 44 | 59 | 59 |
| GYM BROS | 47 | 36 | 50 | 42 |
| PIRATES | 26 | 26 | 29 | 29 |
| GOTH CLUB | 5 | 21 | 9 | 20 |
| SURF CREW | 0 | 9 | 0 | 17 |
| TWINS | 1 | 3 | 3 | 7 |
| CHAMPS | 1 | 2 | 1 | 2 |

Both bots now see each rung harder than the one before (the tool prints
`ladder order: yes`). `test_footwork` measures 30 matches: a tuning round's extra late shots
left too few unforced outs in 10 to compare.

*Amended again 2026-10-14 (ADR-043):* those numbers ran every CPU every
frame; main.c doesn't. On its schedule, with the reaction counting frames
and a steadier human's partner, the ladder is re-measured in ADR-043 (JADE
late every 18th).

## Frame budget

`ai_slide` is a few adds, once per swing check. `make perf`: every run
within budget (`doubles_ladder` 0, `modifiers_doubles` 9, the doubles demo
6). The golden trace is identical: the demo's default CPUs have neither
knob, and the one-owner change didn't touch its 4230 frames.

## Tests

- `test_ai.c: test_footwork`: TWINS' unforced outs over 30 doubles matches (10 until M4-OPP-02),
  without footwork at least 10, with it at most a quarter of that (0 now).
- `test_ai.c: test_middle_aim`: a tactics CPU in doubles holds a middle aim
  on even shots and a lane on odd ones; the default CPU always a lane.
- `test_doubles.c`: one owner per team (it caught the double chase).
