# ADR-068 — Rally Heat

Status: **Accepted 2026-10-19**
Milestone: `PORT-43` (the user's ask: visual cues for a long rally; the
ball speeding up as a rally goes on is set aside for now).

## Decision

Display only: nothing in the sim changes, and the golden traces don't.

- **On fire at 10 shots** (`RallyHeat.FIRE_AT`): the ball glows warm and
  trails embers that cool from yellow through orange to red and rise as
  they fade; the RALLY counter's panel turns warm, its number flickers
  orange, and flames lick up over its top edge.
- **Focus from 15 shots, and darker every 5 after** (`FOCUS_AT`,
  `FOCUS_STEP`): everything behind the net but the court dims (the sky,
  the backdrop, the stands and crowd, the surround), and so do the front
  bushes and fence, the venue's critter and WIND's streaks. The court,
  the net, the players, their shadows and the ball stay bright: a
  spotlight on the rally. Each step is 13% darker, capped at 62%
  (`FOCUS_MAX`) so the scene never goes black; the darkness eases in over
  about half a second and out a little slower when the point ends.
- Not in the title's demo, practice (its drills keep their own streak), or
  MULTI BALL (no single rally).

## How

`view/rally_heat.gd`: `RallyHeat` (the embers, in the effects layer) and
`RallyHeat.FocusDim` (the dark sheet, placed just under the net layer:
four quads between the screen and the court's shape grown 14 world px,
and three feather rings for a soft edge, all convex quads, so no polygon
with a hole). The front layer, the critter and the wind streaks dim by
their modulate. The count is the HUD's (`shot_serial - rally_start`).

## Tests

`test_rally_heat`: the thresholds and the cap; in a match held at a
40-shot rally, embers, the burning sign and the focus coming in, then
out after the point, the ball cooling; none in the demo or MULTI BALL; a
match with it plays as a bare sim.
