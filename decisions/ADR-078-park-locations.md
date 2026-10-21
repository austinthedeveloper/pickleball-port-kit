# ADR-078 — OPEN PLAY's Locations, and the GYM

Status: **Accepted 2026-10-21**
Milestone: `PORT-57` (the user: "'The Park' is always displayed next to
Open Play ... I'm open to creating a few more locations. Maybe one indoor
and one dinosaur").

## Decision

OPEN PLAY's value is now its **location**, chosen with Left/Right and
saved: **THE PARK**, **DINO PARK** and **THE GYM**. All three are the same
plan (the sim's, ADR-034: three courts, their racks, the clubhouse, where
you walk), so open play works the same in each: your park points, the
CLUB and CHAMP courts and the partners you've earned are shared. Only the
look changes, and the venue each park's games play at.

- **DINO PARK** (games at DINOSAUR): a lusher lawn, a sandy path with a
  three-toed trail, palms and ferns, a smoking volcano behind the courts,
  a T. rex and a long-neck on plinths, tiki torches, nests of eggs, a
  bamboo ranger hut under thatch.
- **THE GYM** (games at the new **GYM** venue): a maple floor, painted
  courts with green kitchens, a rubber walkway, black divider nets, the
  end wall with high windows, clocks, pennants and a scoreboard over the
  bleachers, padded side walls, coolers and ball carts, the '94 on the
  floor, a painted-block office under a tiled ceiling.
- **The GYM venue** (any match: COURT > VENUE, and THE GYM's games): a
  lit ceiling with hanging lights, championship banners and a scoreboard,
  the crowd on bleachers behind a divider net, the wall's stripe and pads
  and an exit, a CLAY court with a GREEN kitchen on a MAPLE floor (a new
  surround preset, last in the list so saved choices keep their place;
  the board lines survive recolouring), team benches and coolers in the
  near corners. **Indoors it's always lit**: COURT's TIME doesn't dim it.
  Its own ambience (an echoey hall, sneakers squeaking, balls on other
  courts) and its own match track (an E minor funk, 112 BPM).

## How

`art/park/build_park.py <theme>` (THEMES: palettes and decor; the park's
build is unchanged, file for file) writes `art/park/out/<theme>/`;
`Settings.PARKS` names each location's art and venue; `ParkView` loads
the chosen one (the layout's `bg` paints past the world's edge).
`art/levels/tools/venues.py` gains `gym()`; `audio/hd-sfx/make_sfx.py`
`amb_gym`; `audio/music/make_music.py` `match_gym`. The GYM is the port's
own: the kit's `data/venues.json` (the SNES's six) is unchanged, the
port's `game/data/venues.json` adds it. GLOBETROTTER now asks for a win
at every venue. The announcer's GYM line is in the second batch to record
(`design/announcer/ADDITIONS.md`); until then it opens with the format.

## Tests

`test_park_locations` (each location's layout, art and venue; its
ParkView; the OPEN PLAY row, saved); `test_night` (indoors stays lit, its
ambience); `test_court` (the GYM paints its presets); `test_music` and
the others that run every venue.
