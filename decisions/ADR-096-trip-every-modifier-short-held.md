# ADR-096 — ROAD TRIP Plays Every Modifier; SHORT Held Slows Your Feet

Status: **Accepted 2026-10-26**
Milestone: `PORT-98` (the user, playing ROAD TRIP: "include all of them
including the visual changes like inverting colors", and "Holding the dink
button: We need a slight consequence for them holding the button. Maybe it
slows their movement down a bit when it's held").

## Decision

- **Every modifier turns up on a trip.** A grudge stop's twist
  (`trip.json` `grudge_mods`) now draws from every MODIFIERS and RULES
  toggle: the nine it had plus FAST BALL, GLOW, INVERSE, WIN BY 2,
  SIDE-OUT, MOMENTUM, SUDDEN DEATH and MULTI BALL. SPECIALS stays the
  PICKLE JAR's (and HOT HAND's), and the hazards are unchanged (WRONG
  GLASSES was INVERSE already, POWER CUT GLOW). The visuals come with the
  bits (MatchView draws INVERSE and GLOW from `config.modifiers`), so
  nothing else changed. An UMBRELLA still lifts a twist.
  `test_road_trip.test_the_data` fails if a toggle is added that no trip
  can play.
- **The map's panel** puts the prize beside the venue and the day's
  modifiers on their own line (`RoadTrip.info`): a twist, a hazard and
  SPECIALS together were wider than the panel.
- **SHORT held** (L, LB, LT, Shift or U; every shot a dink) sets a new
  `Intent.short_held`, and while it's down a human's top speed is 7/8
  (`K.SHORT_HELD_SPEED`), an eighth slower. Not
  while swinging (the paddle's swing limit applies as before). Aiming
  short with the D-pad, the ROM's way, is unaffected: it already costs a
  step back. CPUs never set it. Remaster only: off with
  `MatchConfig.overhead`, so the ROM's conformance traces and the golden
  traces are unchanged. It rides the online packet (bit 15).

## Consequences

- Grudge maps from a given seed draw different twists than before (the
  pool is larger); a trip in progress keeps its saved map.
- SUDDEN DEATH can now be a grudge's twist, not only LATE START's
  hazard: a gear pick on one point. Watch for it in play.
- Keyboard players who rest a finger on Shift will feel it; that's the
  point.
