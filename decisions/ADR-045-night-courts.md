# ADR-045 — Night Courts

Status: **Accepted 2026-10-15**
Milestone: `M4-COURT-03`. From [IDEAS.md](../design/snes/IDEAS.md), "Night courts".
Depends on: ADR-022 (court colours), ADR-024 (venues), ADR-027 (kitchen),
ADR-031 (ambience), ADR-032 (save migration).

## What

A **TIME** row on the COURT page, after VENUE: **DAY**, **DUSK**, or
**NIGHT**, saved with the court settings and used at every venue, in every
match (ladder, open play, practice) and behind the title.

- **DAY** is the scene as painted.
- **DUSK** dims the scene warm; **NIGHT** darkens it and shifts it blue,
  with the court under floodlights:
  - the venue's backdrop (BG1 palettes 3-7) and the ground's dark entries
    (the surround, the fence) take the time's *dark* scales;
  - the ground's lit entries (surface, kitchen, lines, net) take its *lit*
    scales, barely dimmed, so the court and lines stay readable.
- **Players, the ball, and the HUD** keep their colours (objects and BG3):
  they are lit, and the ball stands out on a dark court.
- **Ambience:** NIGHT plays the crickets loop (SUNSET's) at every venue;
  DUSK keeps the venue's.
- No new tiles: palettes only.

## Data

`assets/source/court_colors.json` gains `times`: the lit ground entries
(4, 5, 6, 7, 9, 11, 12, 15) and, per time, three channel scales for dark and
for lit, and an optional ambience by name. The asset build:

- turns each scale into a 32-entry table per 5-bit channel
  (`g_court_time_r/g/b`, pre-shifted to their bit positions; 768 bytes);
- checks the line and ball contrast (ADR-022) at every time, through the
  same tables the game uses: every line colour on every surface (and LAVA)
  under the lights, and the ball (which keeps its colour) on each;
- requires the surface, kitchen, and line base entries to be lit, and the
  ambience name to be a venue's.

## Runtime

- `court_style_time_copy(src, dst, count, time, lit_mask)`: each colour
  through the lit or dark tables by its mask bit. The ground (in place,
  with `g_court_lit_mask`) after composing colours and LAVA; the backdrop
  from a work-RAM copy of the venue's painted palettes (all dark).
- **On the SNES** it is `src/asm/court_time.asm` (about 110 cycles a
  colour). The 816-tcc C loop, which the host tests run, overran ten title
  frames in `court.timeline`: every recolour at NIGHT, not only the time
  changes. The assembly matches it: CGRAM at NIGHT equals the tables
  applied in Python, entry for entry.
- **Loading** a court (forced blank) composes both. **On the COURT page** a
  TIME change recomposes the ground on a light frame and the backdrop on a
  later one (the existing recolour wait), each uploaded in VBlank. Closing
  the page with a new time loads its ambience under the short fade, as a
  new venue does (about 45 frames).
- The editor's rows: VENUE, TIME, then the parts (`COURT_ROW_PARTS`); the
  page box grows a row (rows 12-19).

## Save (layout 11)

`SaveSettings` gains `time` and a reserved byte (54 bytes; the checksum
stays on an even offset). Layout 10 (v0.14.0) is frozen as `SaveV10` and
migrates whole with DAY; 4, 7, 8, and 9 still migrate.

## Known

The opponent's partner watching a singles match from the stands (ADR-042)
is an object and keeps its colours among the darkened crowd at NIGHT
(KNOWN_ISSUES #24).

## Tests

- `test_court_style.c: test_editor` (the TIME row: wraps, retimes, Y puts
  it back), `test_times` (DAY changes nothing; NIGHT never brightens, lit
  white stays bright, dark white goes blue and dim; lit and dark entries;
  names; the night ambience).
- `test_save.c: test_migrate_v10` (layout 10 carries over whole, DAY; the
  time round-trips).
- Asset build: line and ball contrast at every time.
- `court.timeline` (DUSK then NIGHT live, then colours at NIGHT): zero
  overruns in `make perf`. MesenCE: PARK, LAKESIDE, and SUNSET at NIGHT, a
  match at NIGHT and at DUSK, the crickets at NIGHT, CGRAM as expected.
- Golden trace identical (DAY is the default).
