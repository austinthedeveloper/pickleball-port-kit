# ROAD TRIP round 6: prompts for the new art

Two images for round three (port ADR-093). Same loop as round 5: generate
them, save each PNG here under its name, tell me, and I review them and
run `import.py`. The game runs with stand-ins until then: the bond items
use recoloured icons (`placeholders/`, `make_placeholders.py`), and the
islands' part of the map repeats the coast's third of the paper, tinted.

The shared style and rules are round 5's (`art/roadtrip-r5/PROMPTS.md`):
warm, rich, painterly pixel art like the accepted set, exact sizes, real
transparency on sheets, no people, no text, letters, digits or logos.

## 1. The partners' bond items: `trip_gear_icons_3.png`

**512 x 128**, 8 columns x 2 rows of exactly 64 x 64. Attach
`game/assets/trip/trip_gear_icons.png` (the style).

> Use case: a new icon sheet in the exact style of the reference sheet.
> Preserve the accepted ROAD TRIP set's warm, rich, detailed painterly
> pixel-art game style, textured surfaces and saturated summer colours.
> This is the HD remaster, with no palette or hardware limits. Small icons
> still use bold shapes that read at their final size. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.
>
> A transparent PNG sheet, exactly 8 columns by 2 rows of 64 x 64 cells,
> one object per cell, each drawn whole inside its cell with a 2 px
> margin, filled left to right, top to bottom. No background, glow or
> cast shadow. Each is a keepsake a travelling partner gives you: (1) a
> small orange megaphone with a green ribbon on the handle; (2) a worn
> brown clipboard with a coach's whistle on a cord, plain marks only;
> (3) a pie tin holding a lattice-top cherry pie; (4) a red protein
> shaker bottle with a dented lid; (5) a brass spyglass made from a
> cardboard tube wrapped in tape; (6) a black lace parasol, half open;
> (7) a round puck of surf wax in a teal wrapper; (8) a big shiny gold
> coin on a string, plain faces; (9) a white paddle grip roll wound
> tight, with a gold band. Cells 10 to 16 stay empty and transparent.

## 2. The islands' map: `trip_map_islands.png`

**600 x 330**, the fourth leg's paper, folded out to the right of the
accepted road map. Attach `game/assets/trip/trip_map_paper.webp`.

> Use case: an extension of the reference paper map, in its exact style.
> Preserve the accepted ROAD TRIP set's warm, rich, detailed painterly
> pixel-art game style, textured surfaces and saturated summer colours.
> This is the HD remaster, with no palette or hardware limits. Light from
> the top left, clear dark outlines. No people, no text, letters, digits,
> symbols, logos or brands anywhere.
>
> Exactly 600 x 330, flat and seen from straight above: one more panel of
> the reference's folded paper road map, the same off-white paper, the
> same fold crease every 300 px (one at x 300), meant to sit to the right
> of the reference's right edge. Open blue sea with three or four small
> green islands, sandy beaches, a few palms, a dotted ferry route across
> the water from the left edge, a tiny lighthouse, and a sea compass rose
> in the bottom right. Keep the middle band (y 60 to 270) light and
> sparse: pins and drawn roads go on top in the game. No words or numbers.

## After you generate them

Save each PNG here and tell me. I'll check them in the game
(`tools/trip_shot.gd`: `islands`, `van`) and write `REVIEW.md`.
