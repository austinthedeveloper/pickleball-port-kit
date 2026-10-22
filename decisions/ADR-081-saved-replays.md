# ADR-081 — Saved Replays

Status: **Accepted 2026-10-22**
Milestone: `PORT-69` (the user, after playing v0.27.0: "What about a way
to save an instant replay? I'm getting some good rallies and it'd be nice
to show as a demo").
Builds on: ADR-075 (PLAY OF THE MATCH).

## Decision

- **SAVE LAST RALLY** is a pause menu row wherever there's PLAY OF THE
  MATCH (not the demo, online, lessons, practice or MULTI BALL). Its value
  says what a press does: NONE YET, the last rally's shots, SAVED once it
  is, or FULL. The last rally is the most recent point that was served,
  however short.
- **What's saved** is PLAY OF THE MATCH's own recording, cut after that
  rally: the match's config (and career player, and whether P1 was a
  bot), every frame's human intents and the view's calls into the sim
  (RESTART, the tuning panel's retune) up to the rally's result, plus the
  rally's start, end, shots, how it ended, and the sim's snapshots at its
  serve and at its end. Also the venue, time of day and court colours, so
  it plays where it happened. No sim state is stored: playback runs a sim
  from the match's first frame, as PLAY OF THE MATCH does, and checks the
  serve's snapshot before showing anything.
- **Where**: one file a replay under `user://replays/`, gzipped
  `store_var` (ints stay ints, so the snapshot check holds), not in the
  save, which is rewritten whole on every write and would grow with every
  match's inputs. At most six (`SavedReplays.MAX`); the row says FULL and
  REPLAYS deletes.
- **REPLAYS** (PLAYER, under ACHIEVEMENTS): six rows, newest first ("14
  SHOTS", "DOUBLES 10/22"), EMPTY past the saved ones. A press watches one
  full screen in the title's demo view, with the PLAY OF THE MATCH
  treatment (the REPLAY dot, the score, a **SAVED REPLAY** card, half
  speed at the end, SKIP), then the menu comes back. **ON PRESS** switches
  a press to DELETE. **IN THE DEMO** (on by default, saved in settings):
  the title's demo plays a saved replay every other time, quietly (no
  card, no score, no skip), between live CPU matches.
- **Versions**: the sim must be the one that recorded it. Each replay
  carries `K.TUNING_VERSION` and a format number; another one lists as
  **OLD VERSION** and doesn't play. A sim change that keeps the tuning
  version is caught by the snapshot check, which drops the replay quietly
  (the warning PLAY OF THE MATCH already gives).

### Amended 2026-10-22 (PORT-70): SAVE at the end of the match

The user, after v0.28.0: "what about saving the replay at the end of the
game?" While PLAY OF THE MATCH plays, **SAVE** (soft: X on a pad, L on
the keyboard, beside SKIP on hit) keeps its rally, the longest of the
match. The card's rally line then reads "14-SHOT RALLY, SAVED" and SAVE
leaves the prompts; with six saved it reads REPLAYS FULL, and SAVE isn't
offered. It's the same rally as SAVE LAST RALLY's when the match ended on
it, so it's never saved twice. A saved replay's own card has no SAVE.

### Amended 2026-10-22 (PORT-71): just the rally

The user, after v0.29.0: replays "capture the entire time from the
beginning of the point til the end. That means it captures pause menus
and me sitting around on the menu." The sim steps while paused (to take
the unpause), so paused frames are in the recording, and the replay
paused too, menu and all; and it opened at the serve's setup, however
long the server stood there. The recording stays whole (the replay has
to re-run it exactly); playback now trims it:

- it opens **LEAD_FRAMES (45) before the serve is struck**, catching up
  unseen to there (a rally keeps its `serve` frame; a replay saved before
  this has none and opens at the setup, as before);
- **paused frames run unseen**, so the pause menu and the wait in it never
  show (in PLAY OF THE MATCH too);
- it ends **AFTER_FRAMES (50, was 80) after the point**, so just the ball
  dying and the result line, not the walk back.

## Why

The sim is exact, and PLAY OF THE MATCH already records everything a
rally needs, so a saved replay is that recording on disk. Re-simulating
from the match's start costs a moment of catch-up (600 frames a drawn
frame, about a second for a long match), but it needs no sim state
serialisation, which the sim doesn't have and the C reference doesn't
either.

## Not changed

The sim; the save layout (one settings key, `replay_demo`, with a
default); PLAY OF THE MATCH. Freeing a view mid-replay now disposes both
of its sims (the live one waits in the Highlight while the replay's is
drawn).

## Tests

`test_saved_replays` (saving never moves the live match; a saved replay
played on a fresh view equals the rally's end snapshot; six at most, FULL;
newest first; OLD VERSION; not in the demo or practice; REPLAYS watches
and gives the menu back, and deletes; the demo takes turns, and the
setting is saved). `test_layout` (REPLAYS full at its widest, each row
selected, DELETE; the pause row's widest value; the SAVED REPLAY card).
`test_menus` (the pause rows). Tests write replays to
`user://test_replays/`, never the player's folder.
