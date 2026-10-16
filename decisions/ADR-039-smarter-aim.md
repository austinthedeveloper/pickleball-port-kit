# ADR-039 — Smarter Aim: the One Back, the Open Lane

Status: **Accepted 2026-10-14**
Depends on: ADR-018 (doubles lanes), ADR-036 (teamwork), ADR-038 (the
middle).

## Why

In doubles, CPUs aimed by shot count: bottom, top, top, bottom, and from
ADR-038 every other shot down the middle for `tactics` styles. Where the
opponents actually stood didn't matter. A real doubles player hits where
the opponents aren't, and at the one who's out of position.

Singles already aims at the open court: the `away` style hits away from
the opponent's side, and ADR-037 handles depth (drops against a player at
the net, lobs). This ADR is about doubles.

## What

For `tactics` styles in doubles, the aim is picked from the opponents'
positions (`ai_open_spot`):

1. **Split up and back** (one opponent at least 32 px nearer the net than
   the other): at the one back, in their lane. They have to hit up from
   there, and the one at the net can't reach it.
2. **An open lane:** a lane at least 12 px more open than the middle (the
   y distance from the lane to the nearer opponent), for example both
   crowding one side.
3. **Otherwise as before (ADR-038):** every other shot down the middle,
   the lane pattern between.

It's picked on the swing's first held frame (the windup with all four
frames left), not on the press frame, and held to contact four frames
later. The press frame already pays for the swing lookahead: even a few
array writes there dropped frames in `doubles_ladder.timeline`.

Partners and opponents use it alike (`partner_style` has `tactics`).

## Tried and dropped

- **Always down the middle unless a lane is open:** with the middle so
  rarely beaten (see below), this was "always the middle". Then even
  erratic teams' deliberate late shots stay in: GYM BROS against the net
  bot went from 51 to 4 bot wins of 60.
- **The open lane alone:** at home (y 110 and 150) the opponents stand 6 px
  from each lane and 20 from the middle, so a lane was clearly open on
  only 18 of about 2,000 shots. The split is the opening that happens
  (one opponent up, one back: 4-17% of shots).
- **Closing the middle at the net** (moving each net player 4-8 px
  inward) and **sticky ownership** (a teammate keeps a middle ball it
  already has) were tried against the balls a net-playing pair lost down
  the middle. Neither helped; those were drives they couldn't reach.

## Retuned

The split made GOTH CLUB much tougher in doubles (7 and 11 bot wins), past
SURF CREW and TWINS. GOTH CLUB's partner is late every 4th (was 6th). WALT
(SNOWBIRDS) every 2nd (was 3rd), to keep rung 2 easier than rung 3.

## Measured

Bot wins of 60, doubles (as in ADR-038: three bot skills × 20 matches;
the regular bot stays back, the net bot plays the net). Singles is
unchanged.

| Team | Regular: ADR-038 | Now | Net: ADR-038 | Now |
|---|---:|---:|---:|---:|
| HENDERSON | 60 | 59 | 60 | 60 |
| SNOWBIRDS | 44 | 44 | 60 | 59 |
| GYM BROS | 47 | 47 | 51 | 53 |
| PIRATES | 25 | 26 | 49 | 48 |
| GOTH CLUB | 11 | 10 | 32 | 27 |
| SURF CREW | 15 | 2 | 24 | 25 |
| TWINS | 14 | 6 | 21 | 20 |
| CHAMPS | 2 | 3 | 5 | 10 |

The ladder still gets harder each rung (averages 59.5, 51.5, 50, 37, 18.5,
13.5, 13, 6.5). The late teams play the split hardest: SURF CREW and TWINS
against the regular bot, whose CPU partner comes in while it stays back.

## Frame budget

`make perf`: every run within budget (`doubles_ladder` 0, `modifiers_doubles`
7, the doubles demo 4). The result screen's frame drops this timeline now
reaches (the CPUs win it 5-0) are fixed separately (`M4-UI-04`: the result
draws over more frames). The golden trace is identical: the demo's
default CPUs have no `tactics`.

## Tests

`test_ai.c: test_doubles_aim` plays a ball to a TWINS CPU and reads the
aim it holds through the swing:

- side by side: the middle on even shots, a lane on odd ones
- split up and back: the one back's lane
- both crowding the bottom: the top lane
- the default CPU: a lane always
