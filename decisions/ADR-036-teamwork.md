# ADR-036 — Doubles Teamwork

Status: **Accepted 2026-10-13**
Depends on: ADR-018 (doubles lanes), ADR-035 (net play).

## Why

Doubles CPUs split the court strictly by halves (ADR-018): a ball just
across the centreline belonged to the teammate in that half, however far
away they were. Balls dropped untouched in the middle, nobody poached, and a
human's CPU partner rushed the net (ADR-035) even with the human at the
baseline.

## What

A new style knob, `team` (0/1), scaled like net play. It's on for GYM BROS,
PIRATES, GOTH CLUB, SURF CREW, CHAMPS, and `partner_style`; off for
HENDERSON, SNOWBIRDS, TWINS (see below), and the default CPU (singles and
the demo are unchanged). With it, a doubles CPU:

- **Covers the middle.** A ball within 12 px of the centreline goes to
  whichever teammate is nearer it by at least 10 px (Manhattan distance);
  otherwise the halves decide. The margin makes teammates that think on
  different frames agree. A volley's band is 20 px: at the net, the nearer
  player poaches. This is `ai_owns_point`, used for the landing, the chase
  after a bounce, the volley target, and the swing check next to a human.
- **Never leaves a human short.** A human may not go for a middle ball,
  so their partner never gives up its own half. It only poaches into
  theirs when clearly nearer, and never takes one deep in their half.
  Without this, the stand-in human's side lost up to 50 middle balls in 60
  matches.
- **Moves as a pair.** A human's partner comes in (ADR-035) only when the
  human is within 80 px of the net; otherwise it stays back beside them.
- **Shifts with the ball.** While the ball is on the other side of the
  net, home moves toward its side by a quarter of its offset from the
  centre, at most 8 px. Both partners shift, covering the angle and the
  middle.

## Measured

Doubles: the bot (slot 0, the CPU AI) and its CPU partner against each
team, three bot skills × 20 matches. The table gives bot wins of 60, and
balls lost untouched within 14 px of the centreline.

| Team | Teamwork off | On (both sides) | Middle lost, off: bot side / CPU side | On |
|---|---:|---:|---|---|
| HENDERSON | 60 | 57 | 0 / 12 | 0 / 5 |
| SNOWBIRDS | 36 | 42 | 0 / 8 | 0 / 2 |
| GYM BROS | 60 | 57 | 0 / 3 | 0 / 0 |
| PIRATES | 25 | 29 | 9 / 24 | 0 / 0 |
| GOTH CLUB | 3 | 1 | 16 / 0 | 0 / 0 |
| SURF CREW | 31 | 13 | 0 / 16 | 0 / 0 |
| TWINS | 8 | 25 | 48 / 27 | 0 / 2 |
| CHAMPS | 1 | 0 | 16 / 1 | 14 / 0 |

- **Separately:** the opponents' teamwork alone makes PIRATES (25 → 12),
  SURF CREW (31 → 20), and CHAMPS tougher. The partner's teamwork alone
  helps the human's side against every strong team (TWINS 8 → 25, GOTH
  CLUB 3 → 14).
- **The shift:** at 12 px it helped GOTH CLUB and SURF CREW but hurt
  PIRATES and TWINS. 8 px was best over a 4-6-8-12 sweep.
- **TWINS** played worse with teamwork (the shift opened their lines), so
  they keep strict halves: the mirror-image twins each hold a side. Their
  doubles number above is the human side's better partner.
- No CPU early-volley faults. Singles is untouched (no partner).

## Frame budget

`make perf`: every run within budget. `doubles_ladder.timeline` has zero
overruns, `modifiers_doubles` 4, the doubles demo 3. The golden trace is
identical.

## Tests

- `test_ai.c: test_teamwork`:
  - two teamwork CPUs give a middle ball to the nearer, across the
    centreline (and by halves without the knob)
  - a human's partner keeps its half's middle ball, poaches a near one in
    the human's half, and leaves a deep one
  - the partner stays back until the human is up
  - home shifts toward the ball's side
- `test_doubles.c`: only one teammate may chase a ball, except a CPU
  partner poaching near the middle beside a human.
