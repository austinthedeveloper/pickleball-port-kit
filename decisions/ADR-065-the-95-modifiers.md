# ADR-065 — The '95 Modifiers

Status: **Accepted 2026-10-19**
Milestone: `PORT-40` (the *Pickleball '95* promises, bible §5.8: "new
modifiers: MOON, BOUNCY, WIND, DINK OR DIE, SUDDEN DEATH, MULTI BALL").
Definitions from the SNES repo's GOOFY_IDEAS.md. Remaster-only.

## Decision

On MODIFIERS:
- **MOON:** low gravity. Gravity is a third lighter (`-2` in 12.4, from
  `-3`) and every shot's flight takes half as long again, so lobs hang and
  the ball floats, still landing where it was aimed.
- **BOUNCY:** the ball keeps more height on each bounce (vertical
  restitution 175/256, from 141): dinks sit up for put-aways.
- **WIND:** a crosswind, new each serve (up the screen, down it, or calm),
  pushing the ball's sideways speed every 8 frames it's in the air. Faint
  streaks drift across the picture the way it blows.

On RULES:
- **DINK OR DIE:** a drive loses the point (**DRIVE!**). The overhead is
  off (a high ball's swing stays a swing); the CPUs and the bot play the
  soft shot instead of a drive.
- **SUDDEN DEATH:** one point takes the match (whatever POINTS or WIN BY 2
  say).

MULTI BALL is its own piece of work (several balls in the sim) and comes
later.

## How

- The ball carries its physics (`Ball.gravity_fp`, `bounce_256`,
  `flight`, `wind`), set from the config (`Sim._ball_physics`), copied to
  probes and copies. Everything that flew the ROM's constants reads the
  ball's now: the step, the launch solver, the net clearance, and the
  CPUs' predictions (`ai.gd`'s `_gravity()` and `_bounce()`), so the CPUs
  read MOON and BOUNCY balls. They don't predict WIND (they correct as it
  drifts, as a person does).
- The physics fields are outside `Ball.to_array()`, and off they are the
  ROM's constants: the golden and conformance traces are unchanged.
- Tuning by bot play (singles and doubles vs the PIRATES): a first BOUNCY
  (205/256) ended nine rallies in ten on the return and a first WIND
  (every 4 frames) blew a quarter of the serves out of the box; at 175/256
  and every 8 frames rallies run 4 to 7 shots, about as without them.
- Bits: MOON 2048, BOUNCY 4096, WIND 8192, DINK OR DIE 16384, SUDDEN
  DEATH 32768; `K.FAULT_DRIVE` 9.

## Tests

`test_modifiers_95`: MOON's flight (45 frames for 30, higher, on target),
BOUNCY's higher bounce, WIND's three directions and drift and its
streaks, DINK OR DIE's fault and no CPU drives in bot play, SUDDEN
DEATH's one point, and off, the ROM's constants.
