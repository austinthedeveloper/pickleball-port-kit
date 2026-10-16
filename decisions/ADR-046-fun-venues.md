# ADR-046 — Fun Venues: Dinosaur, Space, Undersea

Status: **Accepted 2026-10-15**
Milestone: `M4-VENUE-03` (in part). Depends on: ADR-024 (venues), ADR-031
(ambience), ADR-045 (night courts), ADR-022 (colours, amended).

## What

Three venues after PARK, LAKESIDE, and SUNSET, from the mocks in
`assets/inspiration/court_top_*.png`:

| Venue | Backdrop | Ambience | Default court | Home of |
|---|---|---|---|---|
| DINOSAUR | sunset jungle, volcano, dinosaurs over a wooden fence | jungle: a warbling trill, a far-off rumble | GREEN, ORANGE kitchen, GRASS, WHITE lines | GYM BROS (was PARK) |
| SPACE | stars, Earth, Saturn, a rocket, aliens and astronauts behind a lit fence | space: two-note blips, a wobbling sweep | NAVY, PURPLE kitchen, ASPHALT, CYAN lines | GOTH CLUB (was SUNSET) |
| UNDERSEA | a shipwreck, fish, jellyfish, crabs along a rope fence | bubbles: bubble blips, a whale | AQUA, NAVY kitchen, SAND, WHITE lines | SURF CREW (was LAKESIDE) |

They work like the others: the COURT page's VENUE (and AUTO for the home
courts), every TIME (ADR-045), and the singles watcher (ADR-042), who
stands behind the fence among the dinosaurs, aliens, or crabs.

## Art

`tools/art/prep_court_scene.py DINOSAUR|SPACE|UNDERSEA` (Pillow and numpy,
run by hand; not part of the build):

- The mocks share one layout (887 x 774, the same 256 x 224 shape): one set
  of HUD rectangles to in-paint (`FUN_HUD`); the live BG3 panels cover them.
- Their court sits on grass, which the corner-bush test (green pixels near
  the bottom corners) took for bush: whole grass blocks came through. The
  bottom rows come from the LAKESIDE mock instead (`LAKE_MOCK`), so the
  foreground matches LAKESIDE's. LAKESIDE's own output is byte-identical.
- Each venue fits the 896-tile screen budget with the shared ground.

## Sound

Three new ambience kinds in `tools/assetgen/ambience.py` (`jungle`,
`space`, `bubbles`), synthesized like the others.

*Amended 2026-10-15:* the soundbank starts at bank 13 (smconv `-b 13`), so
it may span three banks (13-15, 96 KiB). With the full-length calls (the
rumble 0.9 s, the sweep 0.55 s, the whale 1.3 s) it is 66,226 bytes, three
banks. `make` (`profile`) builds the soundbank first and counts its banks
into `assets/generated/soundbank_banks.h`; the boot code registers each
(`spcSetBank`, last first) and fails to build outside 1-3. Verified: the
MesenCE voice probe hears the ambience at UNDERSEA and SPACE (their
modules end in bank 15), and `make perf`'s sound checks pass. (At first the
calls were trimmed to fit 62,626 bytes in banks 14-15.)

## Choices

- SPACE was to default to a BLACK court; the ball's shadow (dark, or half
  brightness) disappears on black, and the shadow is how a player reads the
  ball's height. NAVY instead. BLACK stays a COURT page choice
  (KNOWN_ISSUES #26).
- New home courts give the ladder's middle rungs the new venues; each is
  one field in `opponents.json` (`venue`).

## Cost

ROM: about 42 KiB of venue data and 24 KiB of sound; bank 13 now belongs
to the soundbank (about 30 KiB of it free for more ambience).
Six venues of the nine the build allows.

## Verified

- `make check` (the venue checks: shared ground, tile budget, names,
  ground presets; ambience kinds); `make perf` zero overruns; golden trace
  identical (the demo plays at PARK).
- MesenCE: a singles match at each new venue (the watcher placed, the
  ambience module loaded: 3, 4, 5), the COURT page preview of each.
