# New venues, round 1: review

`contact-sheet.png` has all seven. I checked each one at 960x540 against
the game's court outline and the zone lines (`ref_zones.png`).

**All seven are good enough to take forward.** The style is consistent
across the set and close to RUINS's look, and none of them has text or
logos (the signs are blank). The players and the court in these images
are only stand-ins: the game draws its own. What matters is that the
scenery leaves the court's place free, and it does.

| Venue | Court fit | Verdict | Notes for round 2 |
|---|---|---|---|
| WESTERN | Exact | Keep | The boardwalk rail sits about 25 px low (y 190 to 220, the court starts at 222): round 2 lifts it a little. Lovely saloon, mesas and wagon. |
| ROOFTOP | Exact | Keep | The parapet, the water tower and the blank billboard work well. The AC unit and the dish stay clear of the court's near corners. |
| PIRATE SHIP | Exact | Keep | The best fit of the set. The quarterdeck stairs at the right run into the crowd band, which is fine: no locals stand there. The parrot and the lookout come back as extras. |
| MOTEL POOL | **Off** | Keep, re-laid out | The drained pool idea reads beautifully. But the court sits about 50 px lower than the game's and the pool's back wall covers where the far court starts. Round 2's plate moves the back wall up and makes it shorter, so the pool floor begins where the court does. |
| COUNTY FAIR | About 20 px low | Keep | The Ferris wheel, the barn and the goat at the fence are great. The fence is in the right place. Grass hides the small offset. |
| DRIVE-IN | Exact | Keep | The blank screen sits right behind the score panels, which frames them nicely. The cars become the back layer and the locals sit on and in front of them. It's night already, so DAY in COURT > TIME is its night. |
| MALL | Exact | Keep (indoors) | The checkerboard, the skylight and the fountain are very 1994. Indoors like the GYM: TIME doesn't apply. The crowd band is a little low, like WESTERN. |

## How round 2 works

Three images per venue (21 in all), each from the concept, so they line
up with it pixel for pixel:

1. **`<venue>_plate.png`**: the concept with the court, the net, the
   players, all the people and the near props taken out, the floor
   painted through. I cut the sky, the backdrop and the floor from it.
2. **`<venue>_cutouts.png`**: only the barrier and the near props, on
   transparency (or flat magenta if the tool can't do transparency). The
   barrier goes in front of the locals; the props become the near strip.
3. **`<venue>_locals.png`**: 8 spectators, standing and cheering, in the
   game's own crowd style (`ref_locals.png`).

The overscan the camera needs (48 px a side) I extend myself. The prompts
are in `PROMPTS_R2.md`.

# Round 2: review

All 21 images came back (`GENERATION_R2_NOTES.md` has the generator's
own notes). I checked each plate against its concept and the court
outline, each cutout on magenta and over its plate, and the locals
side by side.

**All 21 are accepted**, with one deterministic fix and a few touch-ups
done at import. No more generation is needed.

| Venue | Plate | Cutouts | Locals |
|---|---|---|---|
| WESTERN | Clean, the street and the buildings intact | Clean | Great: the sheriff, the prospector, the lady in the bonnet |
| ROOFTOP | Clean | Clean; the chain-link is real see-through mesh | Great; the pizza box is a nice touch |
| PIRATE SHIP | Clean, the best of the set | Clean | Great, and the parrot's two frames |
| MOTEL POOL | The re-layout didn't take: fixed (below) | Fixed with the plate | Great: the robe, water wings, the grandma's bathing cap |
| COUNTY FAIR | Clean; the far crowd under the tents is gone too, which is fine | Clean | Great, and the goat |
| DRIVE-IN | Clean, the parking lines follow the court's perspective | Clean | Great |
| MALL | Clean | Clean | Great |

## The motel fix

`../venues-r2-fixes/motel_relayout.py` moves the band above the pool
floor up 40 px (at 960x540) without scaling it, so the pool's coping and
tile row end exactly where the court starts (y 222). It stretches the
floor down to the near strip, and applies the same mapping to the
cutouts so they stay registered. The pool reads as shallow now, with
the ladders' rails over the coping, and the motel, the sunset and the
sign are untouched. `../venues-r2-fixes/` holds the fixed pair, which
replaces this folder's at import.

## Done at import (no new images)

- **WESTERN's rail** ends about 6 px below the court's far edge: the
  band above it moves up a few pixels, like the motel's.
- **The camera's overscan** (24 px above, 48 px each side): the sky's
  top rows and the floor's edges are extended, and the barrier and the
  near strip continue past the sides.
- **Letters on the locals:** the H on the drive-in letterman jacket and
  the mark on the motel trucker's cap get painted out.
- **The locals' sizes:** each person is cut from the sheet, put on one
  baseline and reduced to the 32x64 cells. The kids, the goat and the
  parrot stay smaller, as drawn.
- **The near strips:** the mall's palm planter and the drive-in's bonnet
  come close to the court's near corners. I check them with the players
  at their widest and trim them if they cover a foot.
