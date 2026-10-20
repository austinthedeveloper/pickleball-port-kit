# ADR-071 — Ball Speed

Status: **Accepted 2026-10-20**
Milestone: `PORT-46` (the user's ask: a slider on MODIFIERS, at the
ball's current speed, in 1% steps, to try it 5-10% slower).

## Decision

**BALL SPEED** is the first row on MODIFIERS: 70% to 130%, 1% a press,
100% by default (the ball as it has always been). It is saved with the
settings, and the title's MODIFIERS row shows it when it isn't 100%
("BALL 93%").

- **What it changes:** every launch (rally shots, serves, the ball
  machine, MULTI BALL's balls) still lands where it was aimed, over
  100 / speed as many frames: at 90% a shot takes 11% longer to arrive,
  and its speed across the court is 90%.
- **What comes with it:** gravity stays the sim's integer -3, so a
  longer flight is a higher one: an arc rises by (100 / speed)², about
  11% at 95% and 23% at 90%. That's how MOON slows the ball too
  (ADR-065); shots clear the net a little more easily as the ball slows,
  and a little less as it speeds up.
- **Everything follows it:** the AI predicts the ball frame by frame from
  its real state, so it reads a slower ball correctly; the probe that
  checks a shot clears the net flies the same physics.
- At 100% the flight is untouched: the golden and conformance traces are
  unchanged, and the ROM's runs never set it.

## How

`MatchConfig.ball_speed` (percent); `Sim._ball_physics` multiplies the
ball's `flight` ([frames num, den], MOON's) by 100 / speed when it isn't
100, clamped to `K.BALL_SPEED_MIN..MAX`. `Settings.ball_speed` is set on
every config the settings build (`config_for`, the lobby, online, the
practice drills); online guests play the host's config, which carries
it.

## Tests

`test_ball_speed`: a 90% launch lands where aimed in 100/90 the frames;
the sim's flight at 100, 93, with MOON, clamped; a doubles match at 90%
plays out; the setting saved, on the lobby's config and online, the row
in 1% steps within its range, the title's label.
