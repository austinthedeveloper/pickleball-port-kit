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
