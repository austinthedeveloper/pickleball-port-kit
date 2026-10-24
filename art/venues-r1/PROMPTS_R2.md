# New venues, round 2 prompts

Three images per venue, made **in this order**, each from the one before:

1. **`<venue>_plate.png`**: attach `<venue>_concept.png`. (MOTEL also
   takes `ref_zones.png`: see its block.)
2. **`<venue>_cutouts.png`**: attach the `<venue>_plate.png` you just made.
3. **`<venue>_locals.png`**: attach `ref_locals.png` and `<venue>_concept.png`.

Keep the plate and the cutouts at the source image's size (1672x941), so
they line up with it pixel for pixel. Save them in this folder. If one
comes back wrong, tell me which and I'll write a fix, as in ROAD TRIP's
round 4.

The cutouts ask for real transparency. If your tool can only do an
opaque background, say "on a flat pure magenta (#FF00FF) background"
instead and I'll key it out.

## Shared blocks (for reference: already in every prompt below)

**Plate:**

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.

**Cutouts:**

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.

**Locals:**

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.

---

## WESTERN

**`western_plate.png`** (attach `western_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is packed sandy dirt,
> continue it with soft wheel ruts running left to right. The barrier is
> the wooden boardwalk rail with hitching posts. Remove the horses too.
> Also: raise the boardwalk rail slightly, so its bottom edge sits at 38
> percent of the image's height; the buildings above it stay in place.

**`western_cutouts.png`** (attach `western_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the wooden boardwalk rail with its hitching
> posts and barrels along the back, and in the bottom strip the hitching
> rail, the water trough, the wagon wheel and the tumbleweed.

**`western_locals.png`** (attach `ref_locals.png`, `western_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a cowboy in a tan hat and a vest; a
> sheriff with a star badge and a moustache; a lady in a long pink dress
> and bonnet; a grizzled prospector with a white beard; a kid in
> suspenders; a saloon bartender in an apron with a bow tie; a cowgirl
> in a fringed jacket; a rancher in a black hat and a long coat.

## ROOFTOP

**`rooftop_plate.png`** (attach `rooftop_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is grey tar roofing with
> patched seams and a few puddle stains. The barrier is the brick
> parapet with the chain-link panel on top. Remove the pigeons too.

**`rooftop_cutouts.png`** (attach `rooftop_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the brick parapet and its chain-link panel along
> the back, and in the bottom strip the near parapet wall, the AC unit,
> the pipes, the roof hatch and the satellite dish.

**`rooftop_locals.png`** (attach `ref_locals.png`, `rooftop_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: an office worker in a white shirt with a
> loose red tie; a businesswoman in a blazer with shoulder pads; a bike
> messenger in a cap with a bag across the chest; a pizza delivery kid
> in a red cap holding a pizza box; a building super in grey overalls; a
> skater teen in a flannel; a jogger in a headband; an older man in a
> cardigan holding a coffee.

## PIRATE SHIP

**`pirate_plate.png`** (attach `pirate_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is honey-coloured wooden deck
> planks running left to right, continue them evenly. The barrier is the
> ship's carved wooden rail. Remove the parrot and the lookout in the
> rigging too; the rigging stays.

**`pirate_cutouts.png`** (attach `pirate_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the carved wooden rail along the back with its
> barrels, and in the bottom strip the near gunwale, the cannon, the
> coiled ropes, the barrels, the crate and the treasure chest.

**`pirate_locals.png`** (attach `ref_locals.png`, `pirate_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a captain in a red coat and a black
> tricorn; a deckhand in a red-and-white striped shirt and a red
> bandana; a pirate with an eye patch and a blue bandana; a big bald
> pirate with a beard; a cabin boy in a too-big vest; a lady pirate with
> a red sash and a headscarf; a cook in an apron holding a ladle; an old
> pirate with a peg leg. Then a 9th column, in the same two rows: a
> green and red parrot sitting (row 1) and flapping (row 2).

## MOTEL POOL

**`motel_plate.png`** (attach `motel_concept.png` and `ref_zones.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> This one is also re-laid out, which overrides "every object's
> position" above. Reference 2 is a layout
> map of the same 16:9 frame: match its bands; don't copy its colours or
> labels. Move the drained pool so its FLOOR fills the map's SURROUND
> and COURT zones: the floor starts at 41 percent of the image's height.
> The pool's back wall becomes a short band of tiled wall from 37 to 41
> percent, with the two chrome ladders on it near the ends; the coping
> and the low chrome rail run along its top. The far pool deck with the
> loungers sits in the band from 21 to 37 percent, with the motel
> building, the van, the ice machine and the neon arrow sign above it,
> shorter to fit. The pool's side walls slant out toward the bottom
> corners, just outside the map's court. The near coping and the
> chain-link fence stay in the bottom strip, from 83 percent. Keep the
> cracked, sun-bleached pale-blue plaster with weeds and dry leaves, the
> sky, the mountains, the palms and the colours.

**`motel_cutouts.png`** (attach `motel_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the pool's coping and its low chrome rail along
> the back, with the two ladders, and in the bottom strip the near
> coping, the chain-link fence, the striped lounger, the side table and
> the agave.

**`motel_locals.png`** (attach `ref_locals.png`, `motel_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a man in a white bathrobe with a coffee
> mug; a lady in a big sun hat and sunglasses; a trucker in a mesh cap
> and a flannel; a kid in water wings and swim trunks; the motel manager
> in a short-sleeved shirt and a tie; a teen in a band-less black tee
> and headphones; a grandma in a floral swimsuit cap; a tourist in a
> Hawaiian shirt with a camera.

## COUNTY FAIR

**`fair_plate.png`** (attach `fair_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is trampled summer grass with
> a few worn dirt patches. The barrier is the white wooden livestock
> fence with the blue ribbon. Remove the front row of people at the
> fence and the goat; the tiny far crowd under the tents may stay.

**`fair_cutouts.png`** (attach `fair_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the white wooden fence with the blue ribbon
> along the back, and in the bottom strip the hay bales, the low wooden
> rail, the pumpkin, the milk can and the barrel.

**`fair_locals.png`** (attach `ref_locals.png`, `fair_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a farmer in overalls and a straw hat; a
> kid holding pink cotton candy; a teenager hugging a giant purple
> teddy bear; a lady in a gingham dress with a blue-ribbon pie; a
> grandpa in a feed cap; a 4-H kid in a green shirt; a carnival barker
> in a striped vest and a boater hat. The 8th is a white goat standing
> on its hind legs, front hooves up (row 1) and bleating with its head
> up (row 2).

## DRIVE-IN

**`drivein_plate.png`** (attach `drivein_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is dark asphalt with faded
> white parking lines, continue the lines' perspective. The barrier is
> the row of parked cars facing the court. Remove the people inside and
> on the cars and the popcorn tubs; the cars' windows show dark empty
> seats.

**`drivein_cutouts.png`** (attach `drivein_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the whole row of parked cars along the back, and
> in the bottom strip the two speaker posts, the wheel stops and the two
> near cars' bonnets at the corners.

**`drivein_locals.png`** (attach `ref_locals.png`, `drivein_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a teen couple's boy in a letterman
> jacket; the girl in a poodle skirt; a dad in a polo holding a popcorn
> tub; a kid in pyjamas; a greaser with slicked hair and a leather
> jacket; a carhop on roller skates in a short-sleeved uniform; a
> grandma with a blanket over her shoulders; a teen in a neon
> windbreaker. Night lighting: the same colours, a touch of blue rim
> light, no glow.

## MALL

**`mall_plate.png`** (attach `mall_concept.png`)

> Use case: precise-object-edit. Keep this exact image: its size,
> framing, camera, perspective, lighting, colours and every object's
> position. Remove ONLY: the pickleball court (its colours and lines),
> the net and its posts, the four players, their shadows, the ball, and
> every person and animal anywhere in the scene. Where the court was,
> continue the floor naturally: the same material, perspective, light
> and texture, slightly calmer in the middle, with no new objects, marks
> or lines. Where people stood, paint what was behind them. Keep the
> barrier along the back and the props in the bottom strip exactly as
> they are. No text, letters, numbers or logos.
>
> Venue specifics: the floor is glossy cream-and-teal
> checkerboard tile with soft skylight reflections; continue the tiles'
> perspective. The barrier is the chrome railing with planters. Remove
> the people on the upper floors and the escalator too.

**`mall_cutouts.png`** (attach `mall_plate.png`)

> Use case: precise-object-edit. Keep this exact image's size, framing
> and every object's position, pixel for pixel. Keep ONLY two things:
> the barrier along the back of the floor (named below) and the props in
> the bottom strip (named below). Make everything else fully
> transparent: the sky, the buildings, the scenery, the floor. Genuine
> alpha with clean edges: no backdrop, no ground shadows, halo or glow.
> Don't redraw, move or restyle what's kept.
>
> Keep: the chrome railing and its planters along the
> back, and in the bottom strip the palm planter at the left, and the
> bench and the fountain's rim and spray at the right.

**`mall_locals.png`** (attach `ref_locals.png`, `mall_concept.png`)

> Use case: sprite sheet in an existing game style. Reference 1 is the
> game's own crowd sprite sheet: match its style exactly, its small
> chunky pixel-art people with dark outlines, simple faces, big heads,
> and the same proportions; ignore its grey background. Reference 2 is
> the venue: the locals belong there. Draw 8 different people, standing,
> facing the viewer, in 8 columns. Row 1: each standing idle, arms at
> the sides. Row 2: the same 8 people in the same order, cheering with
> both arms up. Every figure is the same height, feet on one baseline
> per row, each in an equal-width cell with space between them, nothing
> touching. Transparent background, no shadows, no text. Bold readable
> shapes for a final size of 32x64 pixels each.
>
> The 8 locals: a teen girl in a neon windbreaker with a
> scrunchie; a teen boy in a backwards cap and baggy jeans; a mall walker
> in a purple tracksuit; a security guard in a navy uniform and cap; a
> kid holding a pink balloon; a mum with shopping bags; a food-court
> worker in a paper hat; an older man in a sweater vest.

