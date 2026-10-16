# ADR-018 — Arcade Doubles

Status: **Accepted 2026-10-13**
Depends on: ADR-010 (palette per player), ADR-012 (depth sort), ADR-016 (HUD palettes)

Doubles is the first vertical-slice feature. It reuses the POC simulation
unchanged: the same physics, rally scoring, first to 5, and two-bounce rule,
all of which are already team-based.

## Rules (arcade simplifications, labelled ARCADE RULES)

- **Teams and lanes.** Slots 0–1 are the left team and 2–3 the right
  (ADR-010). Each player owns a lane: slot 0 bottom, slot 1 top, slot 2 top,
  slot 3 bottom. Players may move anywhere in their half; lanes decide serving
  and CPU coverage.
- **Server.** The point winner's team serves. The server is that team's player
  whose lane is the team's right-hand court for its score parity: bottom for
  the left team on an even score, top for the right team on an even score.
  Partners therefore alternate serves without swapping sides. Real
  pickleball's side switch is deferred, together with the full doubles serve
  order (`07_DECISIONS_AND_RISKS.md`).
- **Receiver.** The opponent in the diagonal lane receives. Their partner
  starts at the kitchen line, and the server's partner starts at the
  baseline.
- **Two-bounce rule, faults, and scoring** are unchanged and team-based.
- **Teammate separation.** Teammates closer than 16 px in x and 12 px in y
  are nudged apart in y by 1 px per frame. There is no physical collision.

## CPU teammates and opponents

- Each CPU covers its lane. For an incoming ball, the teammate whose lane
  holds the predicted landing point plays it; the other recovers to its lane
  home. With no active teammate, as in singles, a CPU covers the whole half.
- A CPU whose teammate is human never swings at a ball in the human's lane,
  even when it could reach it.
- Doubles aim spreads shots across both lanes (bottom, top, top, bottom by
  shot count) instead of "away from the first opponent", which would
  always aim away from slot 0, the human.
- CPU time budget: a CPU tracking the ball thinks every frame. Others think
  every fourth frame (staggered by slot) and hold their last movement in
  between.
  - *Amended 2026-10-13 (M4-UI-03/04):* only the teammate whose lane holds
    the ball runs the swing lookahead. A server thinks every frame only
    while serving (the rule had kept the last server on every frame
    through the rally). In the doubles demo, P1 follows the same rule on
    the fourth frame no other slot uses, not every other frame. Every
    frame now has at most one lane cover thinking beside the ball's owner.

## Palettes and shadows

Only OBJ palettes 0–3 are exempt from colour math, and four players need all
four.

| Mode | Players | Objects | Flash | Shadows |
|---|---|---|---|---|
| Singles | OBJ 0–1 | OBJ 2 | OBJ 3 | OBJ 4, translucent (colour math) |
| Doubles | OBJ 0–3 | OBJ 4 | OBJ 5 | OBJ 6, opaque dark (colour math off) |

Doubles shadows lose their translucency. Singles is unchanged. POC default
colours follow the doubles mockup: slot 0 BLUE, slot 1 GOLD, slot 2 RED,
slot 3 GREEN.

## HUD

- Score panels show each team's palette name (`BLUE 4`, `RED 4`); singles
  keeps `P1` and `CPU`.
- The centre panel reads `DOUBLES` in doubles and `ARCADE RULES` in singles.
  A sub-panel below it shows `ARCADE RULES` during doubles serves and
  `MATCH POINT` when a team is one point from winning, matching the doubles
  mockup.

## Input

The POC doubles is 1 human (P1, slot 0) and three CPUs. Port 2 and Multitap
human assignment arrive with character select. `g_input_owners` already
supports it.
