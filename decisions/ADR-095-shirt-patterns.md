# ADR-095 — Shirt Patterns for Opponents and Career Unlocks

Status: **Accepted 2026-10-25**
Milestone: `PORT-97` (the user: "let's design some new shirts. This will
be for opponents and unlocks throughout the game. The standard character
select with 4 colors doesn't use it (I'm trying to keep this screen
simple for faster gameplay)").

## Decision

Twelve shirt **patterns**, remaster only: RUGBY (hoops), CHEST BAND,
SASH, RAGLAN, RINGER, PINSTRIPE, POLKA DOTS, TIE-DYE, FLAMES, HAWAIIAN,
CHEVRON and SPLIT. Player Select keeps its four plain colours (the
bible's Blue / Red / Green / Gold, §5.5), and the ROM is untouched.

- **Art.** Generated in `art/levels/tools/players.py`, not drawn by hand:
  a pattern recolours shirt pixels by where they sit on the torso (down
  the spine and across it), plus the sleeves, wristbands and collar for
  some, so it follows every one of the 21 poses on both bodies (hand
  drawing would be about 500 frames). Each pattern is its own role sheet,
  `player_<body>_body_<pattern>.png`, used in place of the plain body.
  `PlayerLook.body_sheet` picks it, so every screen that draws a look
  (matches, the park, story and trip scenes, the career card, the hat
  museum) shows patterns with no other changes. The hat overlays are
  unchanged, and so are the plain body's pixels.
- **Colour.** Two new palette roles, the design ramp `y` (shadow) and `Y`
  (base), which follow the shirt's shading; the 32-entry palette had
  exactly two free. Some patterns also use the whites (`Z`, `W`).
  `palettes.json` `patterns` gives each one a default colour that stands
  out on all four shirt colours (white, charcoal, orange, pink, purple).
  GLOW brightens the design ramp with the shirt's.
- **Opponents** (`opponents.json` `pattern` and `pattern_color`, 5-bit
  `[shadow, base]`): the HENDERSONS HAWAIIAN (teal flowers, matching), the
  SNOWBIRDS a CHEST BAND each in the other's colour, the GYM BROS RAGLAN,
  the PIRATES RUGBY (Bilge's a white-on-navy sailor's stripe), the GOTH
  CLUB PINSTRIPE, the SURF CREW TIE-DYE, the TWINS SPLIT (each in the
  other's shirt colour), the CHAMPS a navy SASH. Dale Dawson wears
  FLAMES (`dawson.json`) and the ROAD HOGS a cream CHEVRON (`trip.json`).
  Pepper stays plain (the bible gives her a lime shirt).
- **Unlocks.** A career player picks a pattern on EDIT's new PATTERN row,
  under SHIRT (the shirt's colour stays the ramp under it). PLAIN and
  RINGER are free. Beating a ladder team unlocks the pattern they wear
  (one win, like the TRICORN and VIKING), and three more come from the
  existing rules: POLKA DOTS (win 5 matches), CHEVRON (10 aces), FLAMES
  (2 ladder clears). These eleven come after the ROM's sixteen in
  `career.json`, so the ROM's order, and its NEXT: card, are kept until
  they're earned.
- **The save.** `Player.pattern` is a new key (0, PLAIN, when missing),
  so the layout stays v6. The `unlocked` mask was the ROM's u16 and is
  now read as 32 bits; the ROM's sixteen keep their bits, so an older
  save means the same.

## Not done

- Online and the lobby show the Player Select look (no career look,
  KNOWN_ISSUES #54), so no patterns there.
- No pattern for a human on Player Select, by design.
- No number or logo motifs: the torso is about 16 px across, side on.

## Consequences

- 24 more role sheets (about 0.4 MB in the pack).
- `test_career.test_patterns` checks every pattern's sheets, that each
  ladder team wears what beating them gives, the free ones, the save
  round trip and an older player; `test_view` checks a ladder opponent's
  pattern sheet and colour; `test_layout` tries every pattern on EDIT.
