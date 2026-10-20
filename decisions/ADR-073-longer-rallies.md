# ADR-073 — Longer Rallies: CPU ERRORS, and BALL SPEED by the ROM's Pace

Status: **Accepted 2026-10-20**
Milestone: `PORT-48` (the user's ask: "improve the AI a bit. We want
longer rallies"). Changes how ADR-071's BALL SPEED works (not what it
offers).

## Measured first

`tools/rally_stats.gd` plays CPU matches as MATCH SETUP builds them (a
bot for P1) and prints the mean rally and why points ended. At MEDIUM:
the ROM's game, 8.1 shots a doubles rally. The points end on **OUT!**
(about three in four) and **2 BOUNCES** (a ball no one reached).

- **OUT!** comes mostly from the ROM's deliberate misses: every Nth
  return (`late_period`, the team's style) a CPU swings late, contacts
  off the sweet spot, and the stretched shot sails wide or long.
- **ADR-071's BALL SPEED made rallies shorter** (7.3 at 78%): it slowed
  the ball by giving each launch more frames, but gravity is the sim's
  integer -3, so the longer flights were higher. The bounces rose above
  the swing's reach, and more balls bounced twice untouched.

## Decision

1. **BALL SPEED uses the ROM's own slow ball.** KID and EASY have always
   slowed the ball by pacing it: fewer ball steps a 60-frame cycle,
   spread evenly (`Sim.ball_per_cycle`, `make_ball_pace`), with the AI's
   lookahead built for it. BALL SPEED now scales that pace (at MEDIUM,
   78% is 47 steps in 60 frames). The flights are the same, step for
   step; only slower. At 100% (and in the ROM's runs) nothing changes.
   Rallies at 78%: 9.1, up from 8.1.
2. **A paced ball is drawn gliding** (`view/ball_glide.gd`), display
   only. A paced ball takes 0 or 1 steps a frame, so drawn as it is, it
   stood still on the 0-step frames (13 a second at 78%; KID's and EASY's
   ball always did). It's drawn at an even rate between the steps the sim
   took, at most a step behind.
3. **CPU ERRORS** on MATCH SETUP, 0% to 200% in steps of 5, **50% by
   default**: a CPU's late swings come 100 / percent as rarely
   (`Sim.late_period`); 0% never; 100% the ROM's. Rallies at 78% and 50%:
   about 12.5 in doubles, 9 in singles (from 8.1 and 6.4). It changes the
   CPUs only; your own misses are yours. The sim's own default
   (`MatchConfig.cpu_errors`) stays 100: the conformance and golden
   traces run the ROM.

## Tests

`test_rallies`: `late_period`; the CPUs get it; rallies at 50% longer
than at 100%; at 78% the sim's ball pauses on about one frame in five
and the drawn one glides, the view playing as a bare sim does.
`test_ball_speed`: the pace (47 of 60 at 78%, EASY's, the clamp, two
steps a frame above 100%) and the same flight, step for step, at 78% as
at 100%.
