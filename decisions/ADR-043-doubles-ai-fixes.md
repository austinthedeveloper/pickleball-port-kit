# ADR-043 — Doubles AI Fixes: Reaction in Frames, the Partner Stays In

Status: **Accepted 2026-10-14**
Depends on: ADR-018 (doubles scheduling), ADR-035 (the partner style),
ADR-038 (doubles balance).

## Reports

1. GYM BROS, the third rung, let serves bounce twice without touching
   them.
2. A human's CPU partner kept going out past the top-left corner to hit
   balls that looked out, most of all on the third shot.

Neither showed in the host tests: they ran every CPU every frame. main.c
doesn't (ADR-018): a doubles CPU covering its lane thinks every fourth
frame and repeats its movement in between.

## 1. Reaction counts frames

`reaction_frames` was compared with `incoming_frames`, which counted
thinks. A lane-covering doubles CPU thinks every fourth frame, so its
reaction was four times as long: GYM BROS (reaction 16 and 10, M4-OPP-03)
ignored a serve for about 64 frames, longer than its flight. Now a think
adds the frames since that slot's last think (`s_last_think`, outside
AiState). A CPU that thinks every frame adds 1, as before: singles play is
unchanged. The golden trace's game, players, ball, and serve state are
identical on every frame; only the title demo's P1 (it thinks every other
frame, KNOWN_ISSUES #9) now counts 2 per think in `g_ai_slots`, so the
trace was re-recorded. On main.c's schedule, untouched serves against
GYM BROS went from 40% to none.

## 2. The partner stays in

The opponents' deep returns land just inside the top-left corner, and the
ball carries out after the bounce. Two things put the partner out there:

- **Its contact plan** met the ball near the top of its bounce, up to 10
  frames on, by then past the lines. A human's partner now meets a bounced
  ball heading out before it leaves the court, lower on its bounce
  (`ai_steps_inside`).
- **Its deliberate late shots** (every 7th, the partner style's mistake)
  wait for the stretched last chance; on a deep ball that was a ball gone
  by, hit from past the baseline. A human's partner doesn't wait for a ball
  that would be behind it and out past the lines then.

Both are for the partner only: applied to every CPU, they moved the singles
ladder and broke `test_match_flow`'s balance bounds. Contacts by the
partner with the ball already past the lines, against HENDERSON over 20
doubles matches on main.c's schedule: 18 → 0 (GYM BROS 0, GOTH CLUB 8,
TWINS 20, from 15-25). It still stands just behind the baseline to hit a
deep ball that's in, as players do.

## Tests and tools

- `test_support.h: test_step_scheduled` runs the CPUs as main.c does.
  `make stats` uses it for doubles (ADR-038's numbers were on the
  every-frame schedule).
- `test_ai.c: test_scheduled_reaction` (no untouched serves from GYM BROS;
  the old code left 12 of 30) and `test_partner_stays_in` (no partner
  contact past the lines against HENDERSON).
- The doubles ladder, re-measured on the real schedule with the steadier
  partner, needed JADE late every 18th (was 14th). Bot wins of 60: regular
  60, 57, 30, 26, 15, 7, 3, 3; net bot 60, 60, 59, 55, 41, 16, 15, 4. Both
  in ladder order. Singles is unchanged (bot wins of 180: 160, 123, 96, 79,
  42, 31, 15, 4).
