# ADR-035 — Net Play

Status: **Accepted 2026-10-13**
Depends on: ADR-019 (shots), ADR-023 (styles), ADR-033 (LAVA), ADR-034
(open play partners).

## Why

The CPUs played like baseliners. Every CPU let every ball bounce, even
after the two-bounce rule was done, and recovered to a fixed spot about 80
px behind the net. Real pickleball is won at the kitchen line with volleys.

## What

Two new style knobs (`opponents.json`, `AiStyle`):

| Knob | Values | What |
|---|---|---|
| `volley` | 0 / 1 | May hit before the bounce once both bounces are done |
| `net` | 0, or 44-100 | Home distance from the net once the rally lets it come in; 0 stays back |

They scale with the ladder (the user's choice): early teams stay simple, and
late teams play the net.

| Team | `volley` | `net` |
|---|---|---|
| HENDERSON, SNOWBIRDS | 0 | 0 (as before) |
| GYM BROS | 1 | 64 |
| PIRATES, GOTH CLUB, SURF CREW, TWINS | 1 | 44 (the kitchen line, behind the LAVA margin) |
| CHAMPS | 1 | 60 |
| a human's CPU partner (`partner_style`) | 1 | 48 |
| the default CPU (singles, the demo) | 0 | 0 (unchanged; the golden trace is identical) |

- **Coming in:** once both bounces are done, or for the receiving team as
  soon as it has returned the serve, home moves up to `net`. The serving
  team stays back until the return bounces.
- **Volleys:** when a ball will pass the CPU in the air at a playable
  height (4 px up to the reach), before it would land, and it would land
  in, the CPU stands its ground (`ai_plan_volley`: one division per new
  shot). The swing lookahead then allows contact before the bounce, skips
  the "bounce is still far" early-out, and never volleys a ball headed
  out. Lobs over the head go to the bounce logic.
- **Block volleys:** a volley met off-centre sprays long and wide
  (ADR-019). Unless it is a put-away (a high ball near the net), a volley
  is a block: neutral depth, down the middle.
  - Without it, SURF CREW at the net lost 147 points out of 30 matches to
    balls hit out, against 91 from the baseline; with it, 80.
  - The flag is cleared on every serve and at `ai_initialize`. RAM isn't
    cleared at power-on, and a stale flag centred the demo's serve: the
    golden trace caught it.
- **Partners:** a CPU whose teammate is human plays `partner_style`. An
  open play partner from the stack plays their own style (ADR-034).
- **KID assist:** pinned to the default style, so it never volleys for
  you.

## Measured

Bot (the CPU AI, mistiming every 5th shot) against each team, 30 matches.
In the doubles "on" column, the bot's own partner also plays
`partner_style`. Before the final volley-check timing; the final build, over
three bot skills (mistiming every 3rd, 5th, and 8th shot) × 20 matches,
gives bot wins of 60:

| | HENDERSON | SNOWBIRDS | GYM BROS | PIRATES | GOTH CLUB | SURF CREW | TWINS | CHAMPS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Singles | 54 | 33 | 27 | 23 | 3 | 5 | 1 | 0 |
| Doubles | 60 | 36 | 60 | 25 | 3 | 31 | 8 | 1 |

The first table, 30 matches at one skill:

| Team | Singles, off | Singles, on | Doubles, off | Doubles, on |
|---|---:|---:|---:|---:|
| HENDERSON | 26 | 26 | 22 | 30 |
| SNOWBIRDS | 12 | 12 | 16 | 13 |
| GYM BROS | 10 | 11 | 29 | 30 |
| PIRATES | 22 | 20 | 11 | 10 |
| GOTH CLUB | 17 | 2 | 30 | 0 |
| SURF CREW | 13 | 6 | 10 | 13 |
| TWINS | 5 | 0 | 20 | 11 |
| CHAMPS | 0 | 0 | 0 | 1 |

- Net-playing CPUs volley about 20-35% of their shots and stand about 15-25
  px nearer the net on average.
- No early-volley faults by any CPU, in any of these matches.
- The net distances came from a sweep (44, 52, 60, 70) per team. The
  results are noisy and not monotonic; each team got the value at which it
  played strongest. CHAMPS were weaker at the kitchen line (deep balls
  passed them) and play from 60.
- GYM BROS are unchanged: their weakness is hitting out (`M4-OPP-03`).
  In doubles they and HENDERSON are easy (30 of 30), partly because the
  bot's partner is now smarter.

## Frame budget

- Volleying CPUs and the smarter partner cost frames at first: the doubles
  ladder match dropped one frame after a shot. Two changes:
  - The volley check (a division and three multiplies) waits for the
    slot's next think after the shot is planned (`s_volley_check`), so it
    never shares a frame with the landing prediction. It runs only when
    the player stands between the ball and its landing.
    - A gate on the player's distance from the net was cheaper still, but
      it stopped volleys on the way in and made SURF CREW and TWINS easy
      in doubles (46 and 35 of 60 bot wins against 31 and 8), so it's out.
  - `ai_update` and `ai_hold_intent` reach a slot's state and held intent
    by constant index. Variable indexing cost 816-tcc a multiply each,
    about 15 scanlines per CPU think.
- Every `make perf` run is within budget: `doubles_ladder.timeline` 0,
  `modifiers_doubles` 7 (budget 20), the doubles demo 5 (budget 16). The
  golden trace is identical.

## Tests

- `test_ai.c: test_net_play`:
  - TWINS at the kitchen line volley a flat ball passing at about 15 px
  - the same ball, while the serving team must let the return bounce, is
    not volleyed (no early-volley fault)
  - the default CPU lets it bounce
  - home is the net spot once the rally allows, and the recover spot
    before
- `test_opponents.c`: P1's CPU partner plays `partner_style`.
- The ladder order (`test_opponents.c: test_difficulty_order`) still
  holds.

## Next

Situational shots (drops and dinks against net players, speed-ups), doubles
teamwork (moving as a pair, covering the middle, poaching), and smarter aim
(the gap, the open court).
