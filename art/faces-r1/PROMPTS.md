# Faces round 1: prompts for 20 new heads

Four sheets of five heads each, for the 960x540 players
(`art/levels/tools/players.py`). Generate them, save each PNG here under its
name, and tell me; I review them on the real bodies under every hat, and we
do round 2 from the best.

Attach both guides to every prompt:

- `guide_head_cell.png`: the current head on its cell at 8x. Pink circle:
  the dome every hat is drawn on. Pink line: the hat band. Blue ring: the
  neck joint. Then the head under the cap, beanie, bucket and headband.
- `guide_cell_plain.png`: the same cell, unmarked.

(`make_guide.py` rebuilds both.)

## What the heads have to fit

The game draws one head per player and moves it, unrotated, onto every
frame, then lays the hat on top. The hats are fixed drawings, so:

- **The skull stays put.** The top and back of the head fill the pink
  circle exactly, at the same place and size. Everything above the pink
  line is what a hat covers: keep hair there close to the skull (no tall
  hair, buns, spikes or quiffs, which would poke out of the cap). Hair can
  vary freely below the line: sideburns, the nape, a mullet, bangs that
  peek out under a brim.
- **The face is the free part.** In front of and below the pink line:
  jaw, chin, nose, eye, brow, mouth, ear and facial hair can all change.
  Stay inside the cell and leave room in front of the face (the brim of
  the cap reaches about 12 px past the forehead).
- **The neck** meets the body at the blue ring; nothing below it (the
  shirt and collar are the body's).
- **Women's heads** keep the ponytail's tie point: the back of the head
  just behind the pink circle at the pink line, as in the guide's second
  panel. Draw the ponytail hanging, as in the guide.
- **Profile, facing right**, one eye showing, like the guide. The game
  mirrors it for the other side of the net, so nothing lopsided that
  matters (no text, no one-sided emblem).
- **Nine colours only**, flat, no anti-aliasing, so the game can recolour
  every skin and hair: outline `#181424`, white `#ffffff`, skin (deep to
  light) `#8c4834 #c06e4c #eea272 #fccc9e`, hair (deep to light) `#382016
  #663c22 #965e34`. Facial hair, brows and lashes use the hair colours;
  freckles, wrinkles and stubble use the skin's darker two; glasses use
  the outline and white.

## The style, for every prompt

> Use case: new player heads for an existing 16-bit pickleball game,
> drawn to fit its bodies and hats exactly. Match the attached guide's
> pixel art: chunky 1 px dark outline, flat colour clusters, light from
> the top left, the skin shaded with its four tones (darkest at the back
> of the jaw and under the chin). These are the HD remaster's players,
> about 96 px tall, so a head is about 24 x 30 art pixels: every pixel of
> the eye, brow and mouth counts. Keep the guide's character: a long,
> forward chin and a goofy, lovable, slightly ugly look, never generic,
> cute or anime. No text, letters, digits, logos.
>
> The image is exactly 1920 x 384: five cells of 384 x 384, side by side,
> each one cell of the guide at the same 8x scale (one art pixel is an 8 x
> 8 block, aligned to the grid). Each cell holds one head and neck in the
> same place as the guide's: the cranium filling the pink circle, the
> neck ending at the blue ring. Draw no guide marks, body, collar or hat.
> Background: transparent, or else flat `#ff00ff` with no texture.
> Exactly these nine colours and no others: `#181424 #ffffff #8c4834
> #c06e4c #eea272 #fccc9e #382016 #663c22 #965e34`.

Each prompt below is the style block above plus its own paragraph.

## 1. Close cousins: `faces_a.png`

Variations on the current man, the closest to what's in the game.

> Five men's heads, left to right: (1) the guide's own head redrawn
> cleaner: the same long chin and short hair, but an eye with a white and
> a dark pupil, a brow with some attitude, and a mouth with a corner;
> (2) a lantern jaw, square and heavy, the chin pushed even further
> forward, a shadow of stubble; (3) a big hooked nose, a smaller chin
> that slopes back, bushy brows; (4) an older man, bald (the crown in
> skin, still filling the circle), a fringe of hair at the back, wrinkles
> at the eye, a droopy nose and a bigger ear; (5) a walrus moustache
> that hides the mouth, the long chin under it.

## 2. Women: `faces_b.png`

> Five women's heads, each with the guide's hanging ponytail: (1) the
> guide's second head redrawn cleaner, with a lashed eye, small nose, the
> long chin kept; (2) a pointed chin, an upturned nose, freckles, short
> bangs peeking under the hat line above the eye; (3) a strong athletic
> jaw, a determined squint, a smirk; (4) an older woman with a soft round
> chin and round glasses (outline frame, white glint), laugh lines;
> (5) a huge grin showing white teeth, round cheeks, eyes squeezed half
> shut.

## 3. Characters: `faces_c.png`

> Five heads, left to right: (1) a teenage boy: a shorter face below the
> hat line, a button nose, a big eye, mouth open mid-shout; (2) a full
> beard in the hair colour that follows the long jaw down to a point;
> (3) a bulldog underbite, the lower jaw jutting past the upper lip, a
> heavy brow; (4) a long horse face, droopy eyelids, deadpan flat mouth;
> (5) big mutton-chop sideburns down to the jaw, short hair on top, a
> broken boxer's nose.

## 4. Gloriously ugly: `faces_d.png`

The far end of "so ugly they're awesome". Push these.

> Five heads, left to right, as funny as possible while staying readable
> at this size: (1) an enormous crescent chin that curves up and forward
> like a moon; (2) a tiny eye, a huge potato nose, a gap-toothed smile;
> (3) a unibrow and buck teeth over a weak chin; (4) a wide manic stare,
> brows high on the forehead, a mouth open in a yell; (5) an arched
> villain brow, a pointed goatee, a smug little smile, a woman's head with
> the ponytail.

## After you generate them

Save `faces_a.png` to `faces_d.png` here and tell me. I'll snap them to
the grid and the nine colours, put each on the bodies in the idle, run
and swing frames under all twelve hats and every skin and hair, and
write `REVIEW.md` with what works, what doesn't fit, and round 2's
prompts.
