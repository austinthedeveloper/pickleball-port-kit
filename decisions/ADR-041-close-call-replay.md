# ADR-041 — Close Call Replay

Status: **Accepted 2026-10-14**
From [GOOFY_IDEAS.md](../design/GOOFY_IDEAS.md) ("Dramatic replay of a long rally
that goes out").
Depends on: ADR-021 (the rally count), ADR-022 (court colours), M4-STORY-03
(BG2 during a match).

## What

When a **long rally** (at least 8 shots, serve included) ends with the ball
landing **just out** (6 inches or less past a line), the point result shows
a close-up of the line under the OUT! banner and the point panel:

- a framed inset (BG2, 12 × 7 tiles, rows 15-21) of the court surface, the
  line, and the dirt beyond it, zoomed 4×;
- the ball (the BIG BALL sprite) dropping onto its spot in slow motion,
  with its shadow, and one small bounce, its edge 4 px per real pixel past
  the line's edge;
- a caption: `OUT BY 2 INCHES!`, `OUT BY 1 INCH!`, or `OUT BY A HAIR!`.

Short rallies and wide misses show nothing: the doc's worry was that it
would be annoying after every point. The idea's "the call is wrong!" is left
out: the rules stay the rules.

**Inches:** the court is 224 px for 44 ft, so a 12.4 pixel is 528 / 3584
inch, computed as `(d * 151) >> 10` in 16 bits (`REPLAY_INCHES`).

## How

- **Display only.** `replay_check` (src/replay.c, pure, host-tested) runs
  on the point result's first frame, from the rally length and the ball's
  landing spot, and sets `g_replay`. `GameState` is untouched, so the
  golden trace is identical, and B still skips the point result after its
  minimum, close-up or not.
- **The line, side, and distance** come from the landing spot: past a
  baseline it is a vertical line, past a sideline a horizontal one (past a
  corner, the farther). Four row blocks of the close-up map (two lines × the
  court's side) are generated, 448 bytes each; the one shown is written
  into its own BG2 map (`0x0C00`) in VBlank.
- **Colours follow the court:** the six close-up tiles use BG palette 2,
  the ground (surface 4/15, surround 1/2/3/13/14, lines 6/7), so COURT
  page presets and venues recolour it. They follow the intro card's busts
  in the same BG2 upload (57 of 128 tiles), loaded with every court.
- **Layers:** BG2 priority tiles cover the court and the players; the ball
  and its shadow are OBJ priority 3 (OAM 30-31), above BG2; the HUD frame
  (`hud_frame`, a panel border with a clear interior) is on top. BG2 turns
  on only after the HUD frame is drawn, and off when the point result
  ends.

## The point banner in parts

*Amended (practice merge):* the point result's panel and its text now
draw on separate frames, like the match result's (M4-UI-04); the close
call's frame and caption follow them, two steps later.

## Sprites per line

With opponent hats (M4-OPP-04) the worst row is at head height (32 of 34,
ADR-014). During a point result the impact effects are idle, and the close
call adds its ball (a 32 px large object: 4 slivers) and shadow (1): bodies
16, hats 6, ponytails 4, ball and shadow 2, close call 5: 33 of 34.

## Frame budget

Zero overruns on every `make perf` run, and again with the thresholds
dropped to show the close-up on every out ball (1 shot, 99 inches).

## Tests

- `test/test_replay.c`: a long rally just out, each line and direction, a
  hair, a corner (the farther line), and no close-up for a short rally,
  another fault, a wide miss, or a ball short of the net.
- MesenCE, with the thresholds dropped: the golden run's first OUT! point
  shows the close-up over a sideline, the ball dropping onto its shadow in
  the dirt.
