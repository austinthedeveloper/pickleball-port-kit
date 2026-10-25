# ADR-094 — Smart Play: CPUs That Play the Kitchen, Together, and Place Their Shots

Status: **Accepted 2026-10-25**
Milestone: `PORT-95` (the user: "implement a way to fine-tune the AI. At
higher difficulties, I want them to be smarter. Their goal is to always
be at the kitchen line, moving up the line together. Same thing with the
AI partner, I move up and they do too. Smarter shot placement (ex.
default is cross-court or to someone not at the net)").

## Decision

A remaster-only layer over the ROM's AI (`sim/ai.gd`), **off unless
`MatchConfig.smarts` says otherwise**, so the golden and conformance
traces don't move (`test_conformance` switches it off, as it does
`overhead`). Three knobs a CPU slot, 0 to 100, all ints and no
randomness (a shot counter decides which shots are placed):

- **KITCHEN**: where a CPU waits between shots moves from its style's
  spot toward the kitchen line (`K.AI_SMART_KITCHEN`, 42 px from the net,
  just behind the 36 px line), once the rules let its side in (the
  serving side waits for the third shot). At 50 or more the CPU volleys,
  whatever its style (a CPU at the line must).
- **TOGETHER**: a pair stays level. Beside another CPU, no more than
  `AI_SMART_AHEAD` (10 px, plus up to 60 more as the knob falls) ahead of
  it, so the two come up side by side. With a human partner, the CPU
  follows your depth: all the way when you come up ("I move up and they
  do too"), half of it when you drop back (staying back with you left the
  net open; your side won 76% of the bot's points with the half-follow,
  50% with the full one). The ball-side shift of the team styles applies
  to every smart CPU.
- **AIM**: this many shots in 100 are placed: the serving side's third
  shot a drop (so it can come in); a dink when both sides are up; a drop
  from the back when they're up and you aren't (now and then a lob if
  the style lobs); otherwise a ball through the middle depth. It goes to
  whoever isn't up when one is back and one at the net; between two level
  players, dinks and drops go cross-court and drives down the middle.
  Volleys stay the ROM's block volleys.

**Profiles** (`data/ai_smarts.json`): opponents by difficulty (KID
0/0/0, EASY 20/30/10, MEDIUM 70/80/70, HARD 90/100/80) and a CPU on a
human's side (`partner`, 80/100/40). `Settings.smarts_for` fills each
match's config; Settings saves the tuned table (`ai_smarts`).

**Fine-tuning**: the tuning panel (F2, or the pause menu's TUNE) has
SMART PLAY: THEIR KITCHEN, TOGETHER, AIM (this match's difficulty) and
MATE KITCHEN, TOGETHER, AIM (your partner), in steps of 5, live, saved;
DEFAULTS. A change mid-match is a replay op (`["smarts", ...]`), so
PLAY OF THE MATCH and saved replays play it back the same.

## What the measurements said

`tools/smart_stats.gd` (a bot with Pepper against the SNOWBIRDS, PIRATES
and TWINS, a few matches each):

- Waiting with the ball on your side, the SNOWBIRDS stand 89 px from the
  net with smart play off and 58 at HARD; the two's depth gap falls from
  9 to 4. Net teams (PIRATES, TWINS) were already up and stay so, closer
  together.
- The first AIM (deep balls to a lane, cross-court drives) lost points:
  a deep ball to a lane off a stretched hit goes wide or long (the same
  20-26 px spray found in PORT-86), and their share fell from 39% to 17%.
  Middle depth, drives down the middle, and block volleys turned it into
  a gain (39% to 55% at AIM 80).
- With both sides smart (the profiles): the opponents take 42% of the
  points at MEDIUM (39% with smart play off) and 54% at HARD, so medium
  is a touch harder and hard clearly harder.

## Consequences

- The ladder, quick matches, open play, the tournament and ROAD TRIP all
  build their configs through Settings, so all of them get smart play;
  practice has no opponent. The numbers are a bot's; play will move them
  (the knobs are on the panel for that).
- Lowering KITCHEN below 50 mid-match leaves a CPU volleying until the
  next match (a style change isn't undone live).

## Tests

`test_smart_ai`: off by default; the profiles a match gives each slot;
KITCHEN and TOGETHER's spots (a CPU pair, a human partner up and back);
AIM's placements; tuned live and replayed the same; saved; in play,
HARD opponents waiting closer and level. `test_layout.test_tuning`:
the SMART PLAY page at 0 and 100.
