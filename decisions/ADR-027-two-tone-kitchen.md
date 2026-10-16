# ADR-027 — Two-Tone Court: the Kitchen Colour

Status: **Accepted 2026-10-13**
Amends ADR-022 (court colour parts) and ADR-024 (venue ground defaults).

Real courts are usually two-toned, with the kitchen (non-volley zone) in a
colour that stands out. A visible kitchen also makes kitchen faults easier
to read.

## Art

- `tools/art/prep_court_scene.py` paints the kitchen rectangles (net to
  `COURT_KITCHEN_LEFT_X` / `RIGHT_X`) with BG1 palette 2 **entry 12**. The
  net's shadow, which only ever falls inside the kitchen, uses **entry 5**.
  Both are painted in the court's teal, so DEFAULT art looks the same.
- Entry 12 used to be "sand in shadow". Those pixels only ever landed in
  backdrop tiles, which are quantized into palettes 3–7. The tool now paints
  them from an RGB constant with no palette entry, and fails if one reaches
  a court tile.
- All three venue scenes were regenerated. The kitchen edges add a few
  shared ground tiles, so the largest venue now uses 661 of 896 tiles.

## Colours

- The parts are now SURFACE (entries 4, 15), **KITCHEN (12, 5)**, SURROUND,
  and LINES. SaveData goes to version 6: `court[4]` replaces the reserved
  byte.
- **Kitchen presets:**
  - DEFAULT (the venue's kitchen)
  - **SAME**, which follows the surface's resolved preset
  - the surface presets in the same order (checked by the build)
  - LIME and TEAL
- The line and ball contrast checks cover every kitchen colour too.
- **Venue defaults:** every venue is two-toned out of the box.

  | Venue | Surface | Kitchen |
  |---|---|---|
  | PARK | teal | NAVY |
  | LAKESIDE | GREEN | BLUE |
  | SUNSET | teal | CLAY |

- The COURT page has a KITCHEN row between SURFACE and SURROUND, with a live
  preview like the other colour rows.

## Tests

- `test/test_court_style.c`:
  - DEFAULT with the kitchen on SAME equals the painted palette
  - SAME matches the surface; another preset is two-toned
  - kitchen names mirror the surface presets
  - each venue's default court is two-toned
- `test/smoke/court.timeline`, rewritten for the five rows (it was stale
  since the VENUE row): BLUE surface, NAVY kitchen, GRASS surround, WHITE
  lines.
- Zero overruns on every timeline. The golden trace differs only at its
  first, pre-initialization sample.
