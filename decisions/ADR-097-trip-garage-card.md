# ADR-097 — ROAD TRIP: FROM THE GARAGE, Before a Trip

Status: **Accepted 2026-10-26**
Milestone: `PORT-99` (the user, after beating a trip and raising the
HEAT: "Do any stats or items carry over on Road Trip? ... I couldn't tell
if the stats went up"; then "show what the GARAGE added to my stats when
a trip starts, so I can tell the stats went up").

## Decision

- HEAT never raised stats (it makes a trip harder); the GARAGE's ladder,
  paid for in MILES, does. Its gains were only visible on the GARAGE
  page, so a new trip now opens on a **FROM THE GARAGE** card, before the
  first scene (`RoadTrip.garage_card`, TripScene's card):
  - the four stats you start with;
  - what the GARAGE adds ("+1 POWER, +1 FEET", or "+2 TO EVERY STAT"),
    then its hearts, cash and starting paddle;
  - **NEW:** (gold) the stat gains from ladder steps reached since the
    last trip began.
- No card while the GARAGE adds nothing, and none on TODAY'S TRIP (it
  takes nothing from the GARAGE).
- "Since the last trip" is the meta key `garage_steps`, the steps reached
  as a trip begins (`RoadTrip.begin`). A harmless default (-1, filled in
  by `RoadTrip.meta`), so the save stays v6; an older save shows no NEW
  line on its first trip.

## Consequences

- One more press at the start of a trip once the ladder's first step is
  reached (SKIP passes it with the scene).
- `test_road_trip.test_the_garage_card`, and the card at the ladder's top
  in `test_layout`; `trip_shot.gd start_garage` renders it.
