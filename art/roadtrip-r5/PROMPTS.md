# ROAD TRIP round 5: prompts for the new art

The same loop as the first ROAD TRIP set and the painted venues. Generate
the images below, save each PNG in this folder under its name, and tell
me. I review them (`REVIEW.md`) and run `import.py`, which checks the
sizes and brings them into the game.

**Nothing is waiting on these.** The game already runs with placeholders
(`placeholders/`, made by `make_placeholders.py` from recoloured bits of
the accepted art), and the backdrops that aren't in yet borrow another
scene (`TripArt.FALLBACK`). Each image you add replaces its stand-in, with
no code change.

## The references

Attach the reference each prompt names. They're the accepted art, in
`game/assets/trip/`:

- **`trip_gear_icons.png`**: the item icons' style (sheet 1).
- **`trip_hazard_icons.png`**: the hazard icons' style.
- **`trip_pins.png`**: the map pins.
- **`trip_van.png`**: the van, the one drawing every vehicle follows.
- **`trip_scene_roadside.webp`**, **`trip_scene_motel.webp`**: the scene
  backdrops' style.

## The shared style (already in every prompt below)

> Preserve the accepted ROAD TRIP set's warm, rich, detailed painterly
> pixel-art game style, textured surfaces and saturated summer colours.
> This is the HD remaster, with no palette or hardware limits. Small icons
> still use bold shapes that read at their final size. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.

The rules from `design/ROAD_TRIP.md`'s "The art" still hold: exact sizes,
real transparency on sheets (no backdrop, halo, glow or ground shadow),
and the bottom 200 px of a scene quieter (lower contrast, never a flat
slab) where the speakers and the dialog panel stand.

---

## 1. Gear icons, sheet 2: `trip_gear_icons_2.png`

**512 x 192**, a grid of 8 columns x 3 rows of exactly 64 x 64 cells.
Attach `trip_gear_icons.png`.

> Use case: a new icon sheet in the exact style of the reference sheet.
> Preserve the accepted ROAD TRIP set's warm, rich, detailed painterly
> pixel-art game style, textured surfaces and saturated summer colours.
> This is the HD remaster, with no palette or hardware limits. Small icons
> still use bold shapes that read at their final size. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.
>
> A transparent PNG sheet, exactly 8 columns by 3 rows of 64 x 64 cells,
> one object per cell, each drawn whole inside its cell with a 2 px
> margin, filled left to right, top to bottom. No background, gradient,
> glow or cast shadow. The objects, in order: (1) a roll of dark grey lead
> tape; (2) a pair of beige ankle braces; (3) a tall blue energy drink can
> with a plain lightning shape; (4) a brown protein shake in a clear
> shaker bottle; (5) a pair of pink flip-flops; (6) an orange bottle of
> sunscreen with a plain sun shape; (7) a glass tip jar with a few green
> bills and coins; (8) a red first aid kit with a white cross; (9) a red
> cassette tape with a blank label; (10) a chunky CB radio handset on its
> coiled cord; (11) a blue plastic gas card, blank; (12) a gold loyalty
> punch card with punched holes, blank; (13) a teal steel thermos with a
> cup lid; (14) a pair of white dice showing pips only; (15) a purple
> pickleball paddle with a ribbon tied on the handle; (16) two matching
> green team jerseys folded together, blank; (17) an old wooden paddle,
> dark and worn, with tape on the handle and a carved notch; (18) a
> battered maroon paddle with dents and a bandana tied on the handle;
> (19) a shining gold paddle with a laurel shape on its face. Cells 20 to
> 24 stay empty and transparent.

## 2. Hazard icons, sheet 2: `trip_hazard_icons_2.png`

**256 x 64**, 4 cells of exactly 64 x 64. Attach `trip_hazard_icons.png`.

> Use case: four new hazard icons in the exact style of the reference
> sheet. Preserve the accepted ROAD TRIP set's warm, rich, detailed
> painterly pixel-art game style, textured surfaces and saturated summer
> colours. This is the HD remaster, with no palette or hardware limits.
> Small icons still use bold shapes that read at their final size. Light
> from the top left, clear dark outlines. No people, no text, letters,
> digits, symbols, logos or brands anywhere.
>
> A transparent PNG, one row of four 64 x 64 cells, each with the
> reference's 3 px red warning border and its object inside: (1) a heat
> wave: a blazing sun over wavy heat lines; (2) fog: a thick grey fog bank
> with a faint road line vanishing into it; (3) a full moon, big and pale
> yellow, with a wisp of cloud; (4) a pair of wrong glasses: thick
> mismatched spectacles, one lens cracked. Transparent inside and outside
> the border except the objects. No ground shadows.

## 3. Map pins, sheet 2: `trip_pins_2.png`

**64 x 80**, 2 columns x 2 rows of exactly 32 x 40. Attach `trip_pins.png`.

> Use case: two new map pins in the exact style of the reference pins.
> Preserve the accepted ROAD TRIP set's warm, rich, detailed painterly
> pixel-art game style, textured surfaces and saturated summer colours.
> This is the HD remaster, with no palette or hardware limits. Small icons
> still use bold shapes that read at their final size. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.
>
> A transparent PNG, 2 columns by 2 rows of 32 x 40 cells. Each pin: a
> round cream pushpin head 28 px across at the top of its cell and a 4 px
> grey needle below, exactly like the reference. On the heads: column 1, a
> steaming coffee cup beside a slice of cherry pie (the DINER); column 2,
> the front of a boxy maroon RV with a big chrome grille (the ROAD HOGS,
> the rivals). Row 2: the same two, desaturated to grey and a little
> darker, for stops already passed. No shadow, glow or ground shadow.

## 4. The ROAD HOGS' RV: `trip_rv.png`

**64 x 40**, one cell. Attach `trip_van.png`.

> Use case: a second vehicle drawn to match the reference van. Preserve
> the accepted ROAD TRIP set's warm, rich, detailed painterly pixel-art
> game style, textured surfaces and saturated summer colours. This is the
> HD remaster, with no palette or hardware limits. Small icons still use
> bold shapes that read at their final size. Light from the top left,
> clear dark outlines. No people, no text, letters, digits, symbols, logos
> or brands anywhere.
>
> A transparent PNG, exactly 64 x 40, one parked vehicle, strict side
> view facing RIGHT, at the same scale and outline weight as the reference
> van: a boxy late-80s motorhome, a bit longer and taller than the van,
> maroon over cream with a wavy stripe, a chrome bumper, a ladder up the
> back, a folding lawn chair strapped to the roof and a big air horn on
> top. Dark plain windows (no reflections), black tyres with grey hubs.
> Slightly battered: a dent, a mismatched hubcap. Nothing else in the
> image.

## 5. The diner: `trip_scene_diner.png`

**960 x 540**. Attach `trip_scene_motel.webp` (the style and the quiet
lower band).

> Use case: a scene backdrop in the reference's layered style. Preserve
> the accepted ROAD TRIP set's warm, rich, detailed painterly pixel-art
> game style, textured surfaces and saturated summer colours. This is the
> HD remaster, with no palette or hardware limits. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.
>
> Inside a 1950s-style roadside diner in the late afternoon, seen
> straight on: a long chrome-edged counter with red vinyl stools, a glass
> pie case with three pies under domes, a jukebox glowing at the left, a
> coffee machine and stacked mugs behind the counter, a row of booth
> windows on the right with the desert highway and the parked van (the
> reference's cream-over-blue van) seen through the glass. A neon sign
> shape in the window with no letters. The bottom 200 px carry on the
> scene (the checkerboard floor and the counter's base) in lower contrast,
> not a flat fill: the speakers and the dialog panel stand over them. No
> people, not even behind the counter.

## 6. The old court: `trip_scene_old_court.png`

**960 x 540**. Attach `trip_scene_roadside.webp`.

> Use case: a scene backdrop in the reference's layered style. Preserve
> the accepted ROAD TRIP set's warm, rich, detailed painterly pixel-art
> game style, textured surfaces and saturated summer colours. This is the
> HD remaster, with no palette or hardware limits. Light from the top
> left, clear dark outlines. No people, no text, letters, digits, symbols,
> logos or brands anywhere.
>
> A forgotten pickleball court beside a desert highway at dusk: faded
> green paint cracked into plates, weeds growing through the kitchen line,
> a sagging net on rusty posts, one old streetlight just flickering on. In
> front of the court, an old wooden bench with carving marks on its back
> rest (scratches and hearts, never letters). Behind, a two-lane road, a
> telephone pole and red mesas under a purple and orange sky with the
> first stars. Quiet, a little sad, but warm. The bottom 200 px carry on
> the scene (the cracked court surface and gravel) in lower contrast, not
> a flat fill.

## 7. Inside the van: `trip_van_interior.png`

**960 x 540**, the backdrop of THE VAN (the stats and gear screen).
Attach `trip_van.png` and `trip_scene_roadside.webp`.

> Use case: a screen backdrop in the reference's style. Preserve the
> accepted ROAD TRIP set's warm, rich, detailed painterly pixel-art game
> style, textured surfaces and saturated summer colours. This is the HD
> remaster, with no palette or hardware limits. Light from the top left,
> clear dark outlines. No people, no text, letters, digits, symbols, logos
> or brands anywhere.
>
> The inside of the reference van, seen from the back seat looking at the
> side wall: a pegboard on the wall with pickleball paddles and caps on
> hooks, a cooler, rolled sleeping bags, a paddle bag on the floor, a
> string of warm fairy lights along the ceiling, and the sliding door open
> at the right onto a desert road at golden hour. Cream and sky-blue
> upholstery, a little worn. Most of the screen is covered by menu panels
> in the game, so keep the whole image soft and even (no bright spot in
> the middle, no busy detail at the centre), with the most interesting
> things near the edges.

## 8. The scrapbook: `trip_scrapbook.png`

**960 x 540**, the SCRAPBOOK page's backdrop. Attach
`trip_scene_motel.webp`.

> Use case: a screen backdrop in the reference's style. Preserve the
> accepted ROAD TRIP set's warm, rich, detailed painterly pixel-art game
> style, textured surfaces and saturated summer colours. This is the HD
> remaster, with no palette or hardware limits. Light from the top left,
> clear dark outlines. No people, no text, letters, digits, symbols, logos
> or brands anywhere.
>
> Seen from straight above: an open scrapbook on the van's dashboard
> vinyl, its pages full of taped-in keepsakes: instant photos of empty
> courts and roadside sights (no people in them), ticket stubs, a pressed
> flower, a postcard of the coast, a red cassette, a map corner. The
> middle of both pages, from x 200 to x 760 and y 130 to y 510, stays
> plain paper with only faint lines (the menu sits there); the keepsakes
> crowd the edges. Warm afternoon light.

---

## After you generate them

Save each as the PNG name above in this folder and tell me. I'll look at
them in the game (`tools/trip_shot.gd`: `van`, `diner`, `old_court`,
`rival`, `scrapbook`, `map`), write `REVIEW.md`, and ask for another round
on anything that doesn't sit right.
