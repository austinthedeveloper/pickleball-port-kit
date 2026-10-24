# ROAD TRIP — warm revision

This pass follows the latest ROAD_TRIP.md asset table. It returns to the first round's rich, warm painterly pixel art; there is no colour quantization or forced tiny palette. Round one and round two remain unchanged.

- The motel, yard sale and pro shop retain the first-round source images and receive only the requested smooth resize.
- The dashboard edit removes the paper and tree freshener, retains textured vinyl, wheel, hula figure, deck and cup, and blanks dial markings. The specific latest asset table takes precedence over the older dashboard paragraph's empty-ornament instruction.
- Paper, pins, cards, reward tags, gear, hazards, HUD and ornaments have targeted revisions. Gear cells follow the item order, with the NONE hat represented by an empty cell.
- The canonical van retains the first-round look, with a driver window and two dark passenger windows. Animation frames share its geometry. Paints reuse its parked pixels, with RGB replacement maps and a body mask, rather than new perspective drawings.
- The roadside and Summer Open lower areas continue the scene's textured ground. There are no artificial flat-colour foreground panels.
- PNGs preserve lossless sprite art. The webp/ folder provides quality-85 copies of the seven 960 × 540 backdrops. No Godot import settings or other game code were changed.
- The existing rig's plain-paddle palette is included separately; the icon does not replace the player rig.

The exact export sizes are in validation.json and sheet rectangles in layouts.json. Generation prompts are in PROMPTS.md; original generated edits are retained in sources/. Small assets are displayed enlarged with sharp scaling on the review page, so their readability can be judged.

These are review drafts awaiting art approval and in-game composition review. Generated backdrops are flattened. Generated van appearances in scenes follow the canonical design but are not pixel-identical composites. Fine alignment of paper folds, pin-head geometry, card nine-slicing and incidental glyph-like details should be checked at native size before import. The asset pack contains the 19 main PNGs, parked van and paint variants, palette files, WebP backdrop copies, layout metadata, and these notes.
