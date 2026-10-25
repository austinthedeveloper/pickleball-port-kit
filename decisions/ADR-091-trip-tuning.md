# ADR-091 — ROAD TRIP: a Harder Leg 1, a Steadier Partner

Status: **Accepted 2026-10-24**
Milestone: `PORT-86` (the user, after a first trip: "Most were a bit too
easy. The Champs at the end felt just right... my partner missing a lot
of shots", then: "Increase leg 1 a bit. Pepper didn't hit out much, she
just plain missed hitting the ball multiple times in a match").
Amends: ADR-087 (ROAD TRIP).

## Context

A bot in your place (`tools/trip_balance.gd`, and counts of how each
point ended) showed:

- **Leg 1:** its teams are late on every 2nd or 3rd ball (a late swing
  is an off-centre hit, so it goes out). Rallies were 3 to 5 shots, and
  they lost about 95 points in 100. Their difficulty barely mattered:
  even at MEDIUM they lost nearly every point.
- **The partner:** a CPU partner is late on every Nth ball by design
  (Pepper: 7, as the ladder's partner), and as a human's partner a late
  ball is one she lets go. From leg 2 on, that was about one ball a
  match past her in the bot's games. A person's longer rallies give her
  more balls, so more of them. Her MOTEL practice (CONTROL) didn't
  change it.

## Decision

- **Leg 1:** its grudge and big matches are MEDIUM (pickups stay EASY),
  and its CPU ERRORS are 60% of the rest of the trip's
  (`RoadTrip.LEG_1_ERRORS`; 60 at HEAT 0, 45 from HEAT 1). In the bot's
  games, leg 1's rallies about doubled and its teams took three to five
  times as many points; the bot still won them. Legs 2 and 3 and the
  final are unchanged.
- **The partner** (Pepper, or a captain) is late every
  `PARTNER_LATE` = 12th ball at the start of a trip, 2 balls further apart
  for each CONTROL point over 6 (`RoadTrip.partner_late`). A partner whose
  style is never late stays so. Outside ROAD TRIP, Pepper is as before.

## Consequences

- The balance is still the bot's. A person plays differently, so these
  are starting points for the next play-test.
- CPU ERRORS also applies to the partner, so leg 1's 60% makes her late
  swings rarer there too.
