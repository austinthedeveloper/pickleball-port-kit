# ADR-074 — The Tuning Panel

Status: **Accepted 2026-10-20**
Milestone: `PORT-49` (the user's ask: "an admin flyout panel where I can
tune the configurations myself during gameplay ... all the modifiers and
sliders").

## Decision

**F2** (or **TUNE** on the pause menu, for a pad) slides a panel in from
the right during a match. The match waits while it's open (the HUD steps
aside); closing swallows its press.

- **Live:** BALL SPEED (1%), BALL SIZE (1%), CPU ERRORS (5%) change the
  running match at once, and are saved as the settings (the same ones as
  MODIFIERS and MATCH SETUP).
- **MODIFIERS and RULES:** every toggle, for this match. They are built
  into the view and the sim when a match starts (LAVA's ground, WIND's
  streaks, GLOW's lights, SIDE-OUT's serve order), so **APPLY** restarts
  the match from 0-0 with them, rebuilt in place, as RESTART does (its
  new records dropped). They're kept for the next match too, except a
  story chapter's twist. In practice and lessons, APPLY keeps them for the
  next match only.
- **DEFAULTS** puts the three sliders back (78%, 105%, 50%).
- Not online (the two machines run one lockstep match) and not in the
  title's demo.

## How

`view/tuning_panel.gd` (`TuningPanel`, a CanvasLayer of MenuPages).
`Sim.retune(speed, errors)` is the one way the panel reaches the sim:
an input between frames, like a pad's; a sim retuned on its first frame
plays exactly as one built with those values. `MatchView.rebuild(cfg)`
frees the match's nodes and sim and sets it up again with the owner's
fields kept. `MatchActors.apply_ball_size()` resizes the ball live.

## Tests

`test_tuning`: a retuned sim matches one built so for 3000 frames; where
the panel is (a match, the pause menu's TUNE; not the demo, not online);
the match waits, the sliders reach it live, closing swallows the press;
APPLY rebuilds with the modifiers from 0-0 and plays on; TUNE from the
pause menu. `test_layout` checks its pages at the sliders' ends with every
modifier on, keyboard and pad.
