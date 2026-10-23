# ADR-085 — The Dinosaur Game's Levels as Courts

Status: **Accepted 2026-10-22**
Milestone: `PORT-77` (the user: "Level concepts we can take from the
original dinosaur game and use as court levels. Implement these", pointing
at the dinosaur game's `assets/levels`).
Builds on: ADR-046 (the fun venues), ADR-078 (the GYM, indoors),
ADR-084 (the dinosaur game's dinosaurs at DINOSAUR).

## Context

The user's SNES dinosaur game (`../dinosaur`) has four level concept
sheets in `assets/levels`: `01-ruins.png` (a drowned city burning under a
purple and orange sunset, mossy stone and rusted girders),
`ice-wilderness.png` (snowy peaks at dusk, a frozen castle, a stone
aqueduct hung with icicles, snowy pines), `science-lab.png` (green tanks
of dinosaur skeletons, hazard-striped catwalks, pipes and consoles) and
`space.png` (a station's windows on a nebula, a ringed planet, asteroids
and a wreck, orange-lit girders and railings). Each shows Nathan on the
Carnotaurus and the level's dinosaurs: purple raptors, a stegosaurus or a
triceratops, the pterodactyl. Ruins and ice also have SNES tile kits
(256 px backdrops, 16 px tiles): too small and too few colours for the
960x540 courts, so they're reference, like the concept sheets.

## Decision

Four new venues, after the GYM (so saved choices keep their place), on
COURT > VENUE like the others:

| Venue | From | Court (DEFAULT) | Who's watching |
|---|---|---|---|
| **RUINS** | `01-ruins.png` | PURPLE, CLAY kitchen, CONCRETE (cracked), WHITE | two raptors and a stegosaurus on a mossy wall, a burning skyline over a river and a broken bridge |
| **GLACIER** | `ice-wilderness.png` | BLUE, NAVY kitchen, SNOW, WHITE | two pale raptors and a triceratops in the drifts, snowy peaks, ice spires, the aqueduct, a pterodactyl |
| **LAB** (indoors) | `science-lab.png` | BLACK, GREEN kitchen, ASPHALT (steel plates), YELLOW | a raptor loose on the grated deck behind a yellow safety rail; a T. rex, a raptor and a long-neck in the tanks |
| **STATION** (indoors) | `space.png` | SLATE, ORANGE kitchen, ASPHALT (deck plates), WHITE | a raptor, an astronaut and a drone behind an orange rail; the windows' planet, asteroids and wreck |

- **Drawn in the kit's way**, not traced: `art/levels/tools/venues.py`
  gains `ruins()`, `glacier()`, `lab()` and `station()`, and
  `scenery.py` the pieces they share (ruined towers, fires, arch bridges,
  stone pillars, girders, barrels, crates, peaks, pines, icicles, snow
  banks, hazard stripes, safety rails, pipes, consoles, specimen tanks,
  asteroids). The concept sheets set the palettes, the motifs and where
  things go; the dinosaurs are `critters.py`'s. The surround's marks
  (cracks, plates) are darker paint, so a recoloured surround keeps them,
  as the GYM's boards do.
- **LAB and STATION are indoors** (`Settings.INDOOR`): always lit,
  whatever COURT's TIME says. RUINS and GLACIER take TIME like the
  outdoor venues.
- **The Carnotaurus comes too** (ADR-084's sprites, as drawn): Nathan
  rides him along each venue's deck behind the fence, among the crowd
  (`DinoWalkers.RIDES`: the deck's y), with the same route, idle and roar
  as at DINOSAUR. The pterodactyl crosses RUINS' and GLACIER's skies
  (`SKIES`). DINOSAUR's own cast is unchanged.
- **Their own sound:** an ambience each (`audio/hd-sfx/make_sfx.py`:
  wind, fires, a river and far raptors; a howling wind and groaning ice;
  mains hum, bubbling tanks and beeps; an engine drone, vents and doors)
  and a match track each (`audio/music/make_music.py`: C minor brass and
  toms; a B minor bell arpeggio and flute; an A minor pulse sequence; an
  E dorian synth drive).
- **The announcer** has two lines per venue in the batch to record
  (`design/announcer/ADDITIONS.md`); until they're recorded those matches
  open with the format, as the GYM's did.
- **GLOBETROTTER** still asks for a win at every venue (ADR-078), so
  eleven now. One already earned stays earned.

## Not done

- No story chapter, opponent home or OPEN PLAY location plays at them;
  they're picked on COURT > VENUE (and QUICK MATCH, the demo and replays
  follow it).
- No venue critter (SNES ADR-064) at them: the Carnotaurus and the
  pterodactyl are their life.

## Tests

`test_dinos` (the levels have the Carnotaurus on their deck, the
pterodactyl outdoors, behind the fence at each); `test_court` (the four
paint their venues.json presets); `test_announcer` (their lines are to
record); and the suites that run every venue (`test_view`,
`test_layout`, `test_night`, `test_music`, `test_audio`, `test_replay`,
`test_achievements`).
