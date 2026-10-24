# Round 2 generation notes

Generated all 21 requested PNGs with the built-in image generator, using the exact venue blocks in PROMPTS_R2.md. Plates and cutouts additionally requested an unchanged 1672x941 canvas. Cutouts and locals requested genuine transparency. Each venue followed plate, cutouts, then locals; cutouts used the generated plate, and locals used ref_locals.png followed by the concept.

## Items needing fix prompts or import review

- `western_plate.png`: the rail's lower edge remains around 43% of the frame rather than the requested 38%. The plate and `western_cutouts.png` are 1671x941, one pixel narrower than requested. Regenerate its cutouts after any plate correction.
- `motel_plate.png`: people, court and net were removed, but the requested relayout did not take. The back wall remains roughly 46–56% of the frame rather than 37–41%, so the floor starts too low. `motel_cutouts.png` follows that plate and needs regeneration after a corrected plate.
- `drivein_locals.png`: the letterman jacket has an H in both rows, despite the no-text request.
- All `*_locals.png`: all requested columns and two pose rows are present, including Pirate's ninth parrot column and Fair's goat. However, the generated characters are more detailed than ref_locals.png, heights vary, and raised hands/props sometimes nearly touch or cross the nominal cell boundaries. These are source sheets, not ready-sliced 32x64 game cells. Review spacing and style before importing.
- All `*_cutouts.png`: real alpha confirmed, with fully transparent pixels covering approximately 70–84% of each canvas. Fine colored fringes and occasional retained background fragments are visible around some edges and rail openings; review against a contrasting background before import. Pixel-for-pixel preservation of kept artwork is not guaranteed by generation.

## Dimensions verified

- Six plate/cutout pairs: 1672x941.
- Western plate/cutout pair: 1671x941.
- Locals sheets: approximately 1975–1978x795–796, with alpha channels. No downscaling or slicing applied.

Original concepts are preserved. No manual image edits or magenta-key fallback were applied.
