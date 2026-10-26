# ADR-098 — ROAD TRIP: the Map Previews Where a Choice Leads

Status: **Accepted 2026-10-26**
Milestone: `PORT-100` (the user: "It's not clear what paths are available
if i choose an option ... Let's say i choose the top of the 3 listed ...
The next choices limit me to just the first one. It wasn't clear that was
going to happen ... maybe a preview path so they know they're not stuck in
one direction").

## Decision

While you choose a stop on the map, the map shows what choosing it means
for the rest of the leg:

- **A highlighter's gold** (on a dark edge, so it reads on sand and
  water) runs from the van to the stop under the cursor, then along every
  road on from it to the leg's big match.
- **The stops those roads miss fade** (pins at 35% alpha) in the
  columns past it. The other choices in its column stay plain.
- It follows the cursor, and is off while the van drives and under a
  pick or THE VAN.

`RoadTrip.ahead(target)` gives the stops still reachable from a stop
(pure, from the leg's edges); `TripMap._draw_path` and `_preview` draw
it. Display only: the map, the rules and the save are unchanged. The
printed roads stay as they were, so the whole map can still be read.

## Not done

- No preview past the big match: every leg starts from its big match
  with all three lanes open.

## Consequences

- `test_road_trip.test_where_a_choice_leads` checks `ahead` against every
  road (`RoadTrip.roads`) on four seeds; `test_trip_screens` checks the
  dimmed pins for each first choice and no preview under THE VAN.
  `trip_shot.gd map cursor=N` renders it.
