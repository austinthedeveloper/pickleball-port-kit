# ADR-048 — Quips

Status: **Accepted 2026-10-15**
Milestone: `M4-FUN-01`. From [GOOFY_IDEAS.md](../design/GOOFY_IDEAS.md), "Quips".
Depends on: ADR-023 (opponents), ADR-026 (story lines), ADR-041 (the close
call's replay).

## What

Now and then, the side that lost a point says something on the point
result, in a panel under the point's ("CPU POINT", then "ARRRGH!"), in that
side's team colour. PG only: no cursing, no put-downs.

- **Who:** a ladder team speaks its own lines (`quips` in
  `opponents.json`, four each); a human side (1P, or 2P in versus) and
  the default CPU speak the generic ones (`assets/source/quips.json`). In
  doubles the team speaks.
- **How often:** about one lost point in three (`story_quip`: the frame
  count mod 3), never the same line twice in a row. Never over a close
  call's replay, which uses the same rows. The attract demo quips too.
- **Lines:** up to 28 HUD font characters, checked like the story lines.

| Team | Lines |
|---|---|
| HENDERSON | WELL, THAT'S A PICKLE. / I'LL BE DILLED! / THAT ONE'S ON DAD. / HOLD MY COFFEE. |
| SNOWBIRDS | OH, FIDDLESTICKS. / MY HIP, MY HIP! / WHO MOVED THE NET? / BACK IN MY DAY... |
| GYM BROS | BRO. NO. / NOT ON LEG DAY! / TOO MUCH POWER, BRO. / SPOT ME NEXT TIME! |
| PIRATES | ARRRGH! / SHIVER ME PADDLES! / BLOW ME DOWN! / THAT BALL WALKS THE PLANK! |
| GOTH CLUB | HOW TRAGIC. / AS EXPECTED. / THE VOID TOOK IT. / SIGH. OF COURSE. |
| SURF CREW | WIPEOUT! / BOGUS, DUDE. / TOTAL BAIL, BRAH. / GNARLY... NOT. |
| TWINS | THAT WAS HIS FAULT. / THAT WAS HER FAULT. / JINX! / TWIN FAIL! |
| CHAMPS | ...THAT NEVER HAPPENS. / A WARM-UP SHOT. / NOBODY SAW THAT. / PRACTICE POINT. |
| You | OOPS! / WHOOPS! / SO CLOSE! / MY BAD! |
| Default CPU | DRAT! / NOT AGAIN! / WHOOPSIE! / BEEP BOOP... OOPS. |

## Drawing

The point result draws its panel and text over three frames; the quip is
picked on the panel's frame and draws on the next two free steps (its
panel, then its text; the replay's steps when there is none), at rows
14-16. The next clear covers those rows. Display only: the simulation and
the golden trace are unchanged.

## Tests

`test_story.c: test_quips` (a third of the rolls, the right side's lines,
no repeats); the asset build checks four lines each and their characters.
MesenCE: a doubles ladder match against HENDERSON quips on 5 of 12
points, from both sides, and the panel clears for the next serve. `make
perf` zero overruns.
