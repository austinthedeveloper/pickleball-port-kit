# ADR-088 — The Painted Venues

Status: **Accepted 2026-10-24**
Milestone: `PORT-83` (the user: "I want to generate some more locations.
I would like for you to write the prompts and I'll include a reference
image... we'll do the same loop as the roadtrip", naming a Western town,
a rooftop and a pirate ship; then "the motel pool court" from ROAD TRIP's
motel scene).
Builds on: ADR-046 (the fun venues), ADR-078 (indoors), ADR-085 (the
dinosaur game's levels), ADR-087 (ROAD TRIP and its generated art).

## Context

Every venue so far was drawn in the kit's way: Python that paints
shapes, ramps and noise (`art/levels/tools/venues.py`). ROAD TRIP's art
(ADR-087) showed that generated paintings, briefed and reviewed in
rounds, give a warmer, richer look that the user prefers, and the Godot
port has no colour limit.

## Decision

Seven new venues, after STATION on COURT > VENUE (saved choices keep
their place), made from generated paintings in two rounds
(`art/venues-r1`: the prompts, the references, both reviews):

| Venue (id) | The scene | Court (DEFAULT) | Who's watching |
|---|---|---|---|
| **WESTERN** (`western`) | A dusty main street at golden hour: the saloon, the store, the sheriff's office, the water tower, red mesas | RED, CLAY kitchen, WHITE | townsfolk on the boardwalk behind its rail |
| **ROOFTOP** (`rooftop`) | A city roof at dusk: the parapet, a wooden water tower, a blank billboard, the skyline | BLUE, NAVY kitchen, WHITE | office workers, a messenger, a pizza kid, in front of the parapet |
| **PIRATES** (`pirate`) | A galleon's deck at sea: the mast and rigging, the quarterdeck and wheel, a palm island | AQUA, NAVY kitchen, WHITE | the crew on deck before the rail; the parrot on the rail |
| **MOTEL** (`motel`) | ROAD TRIP's desert motel at sunset: the court on the floor of the drained pool | BLUE, NAVY kitchen, WHITE | guests on the far pool deck behind its rail |
| **FAIR** (`fair`) | A county fair's midway at dusk: the Ferris wheel, tents, a red barn | GREEN, ORANGE kitchen, WHITE | fairgoers (and a goat) behind the white fence |
| **DRIVE-IN** (`drivein`) | A drive-in at night: the glowing blank screen, the snack bar, a row of parked cars | PURPLE, PINK kitchen, CYAN | moviegoers in front of their cars |
| **MALL** (`mall`) | A 1994 mall's centre court: the skylight, the fountain, the escalator | AQUA, PINK kitchen, WHITE | shoppers behind the chrome railing |

- **The paintings, not the kit:** round 1 made a concept per venue from
  a clean in-game shot (`ref_scene.png`), so the scenery keeps the
  court's place. Round 2 made three images from each: a **plate** (the
  concept without the court, the net, the players or any people), the
  **cutouts** (only the barrier and the near props, on transparency),
  and the **locals** (8 spectators, standing and cheering, in the
  game's crowd style). MOTEL's plate kept the concept's low pool, so
  `art/venues-r2-fixes/motel_relayout.py` lifts it (unscaled) and
  stretches the floor.
- **Cut, not drawn:** `art/levels/tools/painted.py` makes each venue's
  layers from those images: `far` the plate (lossy WebP, like ROAD
  TRIP's backdrops), `fence` the barrier, `front` the near props, an
  empty `stands` for the crowd, and `ground` the plate's floor with the
  court painted on it by the kit's court mask. The court's paint takes
  the floor's light and grain, so it reads as painted on the planks,
  the dirt or the tar. A scene whose barrier ends below the court's far
  edge is lifted, like MOTEL's. The camera's overscan reflects the
  edges. The build is otherwise unchanged: the existing venues' files
  are byte-identical.
- **Every layer at parallax 1.0.** The plate has the barrier and the
  props painted in, so a layer that slid against it would show their
  ghosts. The camera's drift (ADR-050) pans the whole scene.
- **The surround is the painting's floor:** venues.json's surround is
  DEFAULT, like PARK's. Choosing a surround preset recolours the floor
  by its brightness (the shader's rule), so the planks, the cracks and
  the checkerboard keep their pattern. The surface, kitchen and lines
  paint their presets, as at the fun venues.
- **Their own locals:** a venue's manifest entry may carry a `crowd`
  sheet, which `Crowd` uses in place of the shared one (same layout:
  row = person, idle and cheer, anchored at the feet). Each sheet is cut
  from the generated locals, reduced so a typical adult is 50 px tall
  (BOX, hard alpha). Kids, the goat and the parrot keep their size. Two
  letters were painted out (a letterman's H, a cap's badge).
- **MALL is indoors**, and the **DRIVE-IN** joins it in
  `Settings.INDOOR`: it's painted at night already, so DUSK and NIGHT
  would only darken it. The other five take TIME like the outdoor
  venues.
- **Their own sound:** an ambience each (`audio/hd-sfx/make_sfx.py`): a
  dry wind, a creaking sign, spurs and a far whinny; traffic, a horn, a
  siren and pigeons; the sea, the timbers, gulls and the ship's bell;
  crickets, the neon's buzz, trucks and the ice machine; the midway, a
  carousel organ, bells and a goat; crickets, the film through the
  speaker posts and a car door; shoppers, the fountain, the escalator
  and the chime. And a match track each (`audio/music/make_music.py`): a
  spaghetti-western whistle over a boom-chick; city funk; a hornpipe; a
  desert lounge's twang; a calliope's oom-pah; a doo-wop ballad; smooth
  1994 mall music. The announcer's lines join the batch to record
  (`design/announcer/ADDITIONS.md`); until then the match opens with
  the format.
- **ROAD TRIP** visits them: FAIR and MOTEL on OUT OF TOWN, WESTERN and
  the DRIVE-IN on THE LONG DRIVE, PIRATES, ROOFTOP and the MALL on THE
  COAST.

## Consequences

- Seven more venues for COURT > VENUE, the demo and ROAD TRIP, without
  new drawing code; a new venue is now three images and a `SPECS` row.
- The painted look differs from the kit's flatter pixel art. The
  players, the court lines and the HUD stay the game's own, so they
  read the same everywhere.
- GLOBETROTTER (win at every venue) needs eighteen venues now. One
  already earned stays earned.
- The `.pck` grows by about 12 MB: 4.5 MB of textures (Godot imports
  each `far.webp` and `ground.png` lossy, at quality 0.9, set in their
  `.import` files; lossless they were 14 MB, and the difference doesn't
  show) and 8 MB of Ogg ambience and music.
- Known gap: the announcer's lines aren't recorded.
