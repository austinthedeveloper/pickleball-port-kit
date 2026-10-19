# ADR-022 — Court Colours

Status: **Accepted 2026-10-13**
Starts the custom court colours idea in [IDEAS.md](../design/snes/IDEAS.md).
Depends on: ADR-016 (BG1 palettes), ADR-021 (save block).

## What changes colour

The ground (court, kitchen, surround) is BG1 palette 2, CGRAM 32–47. The
kitchen is painted in the court colour, so it follows the surface. Three
**parts** recolour fixed entries of that palette:

| Part | Entries | Painted as |
|---|---|---|
| Surface | 4 (court), 15 (lip) | teal; *ADR-027:* entry 5 moved to the kitchen |
| Surround | 1 (ground), 2–3 (speckle), 13–14 (fence mesh against the ground) | dirt |
| Lines | 6 (line), 7 (line in shadow) | cream |

The net, the fence rails and posts, and the backdrop (palettes 3–7) keep
their colours.

## Presets, not free colour

Each part has a list of named presets in `assets/source/court_colors.json`.
Preset 0 is **DEFAULT**: the painted colours read from `court_scene.png`.
*Amended by [ADR-024](ADR-024-venues.md):* DEFAULT now means the venue's
ground presets (`venues.json`). At PARK, those are the painted colours.
Each other preset gives one base colour. The generator derives the part's
other entries by scaling the base by each painted entry's brightness relative
to the painted base, which keeps the base's hue.

| Part | Presets |
|---|---|
| Surface | DEFAULT, BLUE, NAVY, GREEN, PURPLE, CLAY, SLATE, RED, PINK, ORANGE, BLACK, AQUA |
| Surround | DEFAULT, GRASS, CONCRETE, SAND, BRICK, ASPHALT, SKY, SNOW, CANDY, AUTUMN |
| Lines | DEFAULT, WHITE, YELLOW, CYAN, LIME |

*Amended 2026-10-15:* the fun colours (PINK to AQUA surfaces, mirrored as
kitchens before LIME and TEAL; SNOW, CANDY, AUTUMN surrounds; CYAN and LIME
lines) pass the checks below at every TIME (ADR-045). They push the
kitchen's own presets (LIME, TEAL) from 9-10 to 13-14, so saves from layouts
before 11 have those remapped as they migrate (`save_remap_kitchen_v10`,
`test_save.c: test_migrate_v10`). New colours go at the end of their part,
or, for the surface, with the same remap.

Presets cannot produce an unreadable court. The asset build fails unless:

- every line colour has a WCAG contrast of at least 2.5 against every surface
  (the painted cream on teal is 3.5);
- the ball's yellow has a contrast of at least 2.0 against every surface (the
  ball also has a dark outline);
- each part has 1–5 entries, no entry belongs to two parts, and names fit
  eight cells.

`court_colors.h` holds the tables. It is about 300 bytes of ROM.

## Runtime

- The choice is `g_save.settings.court[part]`, a preset index per part. It
  is saved in SaveData v2 (ADR-021's layout plus a 4-byte settings block).
  A v1 save resets to defaults.
- `court_style_compose` (pure) copies the painted palette 2 from
  `court.pal` and replaces each part's entries. An out-of-range index counts
  as DEFAULT.
- The renderer keeps the composed palette. It uploads it inside forced blank
  when the court loads (boot and returning from Player Select), and during
  VBlank when `render_apply_court_colors` marks it dirty.
- Every scene that shows the court uses the choice, including the attract
  demo.

## Title page

- The menu is SINGLES, DOUBLES, **COURT**, RECORDS.
- **COURT** opens a 24 × 5 box with one row per part (`SURFACE <BLUE    >`):
  - Up/Down moves between rows and Left/Right changes the preset. Both wrap.
  - Each change recolours the demo court behind the page at once.
  - B or Start keeps the change, and writes the save only if something
    changed. Y puts back the colours the page opened with.
  - The prompt reads `@ OK  Y CANCEL`.
- The page draws one part per idle frame, like the records page. After that,
  only a changed row is redrawn, one per frame.
- The menu now takes two parts (two items each) plus the 2P line.
- Erasing records (L + R + X on the records page) keeps the court colours.

## Locations (future)

When locations exist, DEFAULT will mean "this location's ground colours".
The saved index stays meaningful.

## Tests

- `test/test_court_style.c` (host):
  - DEFAULT equals palette 2 of the generated `court.pal`
  - a preset touches only its part's entries
  - out-of-range indices count as DEFAULT
  - names fit
  - editor rows and values wrap
  - Y restores; B keeps
- `test/test_save.c`: erasing records keeps the settings, and a full clear
  resets them.
- `test/smoke/court.timeline`: pick BLUE / GRASS / WHITE, keep, reopen,
  change, and cancel. The choice persists into a later boot and into a match
  after Player Select (MesenCE `.srm`).
- Zero frame overruns on the court, records, and idle title timelines, and in
  a full match.
- The golden trace shows the match one frame later (composing the ground
  palette while the court loads). Frames before the first serve differ only
  in player and game timers, and everything from the serve on is identical.
  The trace was re-recorded.
