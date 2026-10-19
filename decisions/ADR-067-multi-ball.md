# ADR-067 — MULTI BALL

Status: **Accepted 2026-10-19**
Milestone: `PORT-40` (the *Pickleball '95* promises, bible §5.8: "new
modifiers ... MULTI BALL"). The user's answers in the SNES repo's
GOOFY_IDEAS.md (2026-10-16). Remaster-only.

## Decision

**MULTI BALL**, on the RULES page:

- **No serving.** The match is live at once; the first ball appears at the
  net.
- **Balls trickle in:** a new one every 4 seconds (`MULTI_EVERY`, 240
  frames), at most 3 in play (`MULTI_MAX`). Each appears at the net,
  hangs over the tape **blinking** for a second, then **shoots onto one
  side**: the sides alternate, the left first, each landing mid-court in a
  lane of its own.
- **The two-bounce rule applies to every ball.** A launch counts as a
  serve from the far side: it must bounce on the side it lands, be
  returned, and bounce on the other before anyone volleys it.
- **Each ball scores on its own** when it dies (out, net, two bounces, a
  fault), by the usual rules for whoever hit it last. The first to the
  winning score wins, with balls still in the air or not.
- Rally scoring always (SIDE-OUT has no server to follow here), and LAVA
  and MOMENTUM aren't called (with no rally to end, standing in the
  kitchen would score every frame).

The open questions, my defaults: 3 at most; the sides alternate; the first
ball starts the match; the two bounces count from the launch, as above.

## How

The ROM's code handles one ball, and the rules, hits and the CPUs' landing
cache read it everywhere. Rather than thread "which ball" through all of
it, each ball (`Sim.MultiBall`) keeps the rally state the ROM keeps for
its one (`required_bounce`, `landing_pending`, `contact_volley`,
`shot_serial`, `ball_steps`, the side it was "served" from), and a frame
swaps each into the single-ball fields, runs the unchanged hit, physics
and rules code, and swaps it out. Each CPU (and the bot) plays the ball on
its side or flying to it, sticking with one while it's coming; its landing
cache starts over each think. FAST BALL's pace advances once a frame. Off,
none of it runs: the golden and conformance traces are unchanged, and the
state joins the snapshot only when on.

The view draws every ball with the same art (`MatchView._multi_balls`);
the HUD's serve marks are off.

## Tests

`test_multi_ball`: no serve, a ball at the net that blinks then flies to
the left first, needing a bounce; several balls at once, 3 at most; bot
matches in singles and doubles finish (a point per ball, real rallies,
alternating sides); deterministic frame by frame (online plays it in
lockstep); off, the ROM's serve; the view draws them and plays as a bare
sim.
