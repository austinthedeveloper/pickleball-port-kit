# Faces round 2: prompts

Round 1's review is in `REVIEW.md`: ten heads kept, five to retry, five
dropped. Round 2 is four sheets of five again: the keepers redrawn
cleaner (sheets E and F), the retries (G), and five new heads in the
style that worked (H). Save each PNG here under its name and tell me; I
snap and review it the same way.

Attach to every prompt: `guide_head_cell.png`, `guide_cell_plain.png`
and `guide_female_no_tail.png` (round 1's woman without her ponytail).
Sheets E and F also attach each head's round 1 version from `refs/`, in
the order listed.

## What changed since round 1

Round 1's rules all still hold (`PROMPTS.md`: the skull fills the pink
dome, hair stays flat above the band, facing right, nine colours). On top
of them:

- **Even pixels.** Every art pixel must be the same size square block
  across the whole sheet, on one grid. 1920 x 384 at 8x is still the ask,
  but if the image comes out another size, that's fine as long as the
  blocks stay square, even and aligned. Uneven blocks are what lose
  detail.
- **No ponytails.** The game draws its own and animates it. Women's heads
  end at the back of the skull like `guide_female_no_tail.png`, with the
  hair at the back reaching the pink line.
- **Size.** The head is 24 to 28 art px wide (more only when a nose or
  chin is the joke) and its jaw comes down to rows 41 to 43, as in the
  guide. The neck is short and as thick as the guide's, ending at the
  blue ring.
- **Ears**: a small outlined ear with a lighter inside, not a dark blob.
- **Read at game size.** Each feature must survive at 1x: no single-pixel
  freckles or fine wrinkles. Bold eyes, brows, teeth and chins.

## The style, for every prompt

> Use case: new player heads for an existing 16-bit pickleball game,
> drawn to fit its bodies and hats exactly. Match the attached guide's
> pixel art: chunky 1 px dark outline, flat colour clusters, light from
> the top left, the skin shaded with its four tones (darkest at the back
> of the jaw and under the chin). A head is about 26 x 30 art pixels;
> every pixel of the eye, brow and mouth counts, and every feature must
> read at that size. Goofy, lovable and gloriously ugly, never generic,
> cute or anime. No text, letters, digits, logos.
>
> Five cells side by side, ideally 1920 x 384 (five cells of 384 x 384,
> each the guide's 48 x 48 art-pixel cell at 8x). Every art pixel is an
> identical square block on one grid across the whole image. Each cell
> holds one right-facing profile head and its short neck in the guide's
> place: the top and back of the skull filling the pink circle, the hair
> above the pink line flat to the skull, the jaw reaching rows 41 to 43,
> the neck ending at the blue ring. The ear is small and outlined with a
> lighter inside. No ponytail, buns or tall hair. No guide marks, body,
> collar or hat. Background transparent, or else flat `#ff00ff`. Exactly
> these nine colours: outline `#181424`, white `#ffffff`, skin `#8c4834
> #c06e4c #eea272 #fccc9e`, hair `#382016 #663c22 #965e34`.

Each prompt below is the style block plus its own paragraph.

## E. Keepers, cleaner: `faces_e.png`

Attach `refs/ref_d1.png`, `ref_d2.png`, `ref_d4.png`, `ref_a4.png`,
`ref_a5.png`.

> Redraw these five heads from the attached references, keeping each one's
> design and joke exactly, on an even grid and cleaner: (1) the enormous
> crescent chin curving up and forward like a moon; (2) the huge potato
> nose with a gap-toothed grin, the nose a little rounder; (3) the wide
> manic stare and yelling mouth, brows high; (4) the bald old man with a
> fringe at the back and a droopy nose, the ear redrawn small and clean;
> (5) the walrus moustache hiding the mouth, over a long chin.

## F. Keepers, cleaner: `faces_f.png`

Attach `refs/ref_a2.png`, `ref_c2.png`, `ref_d3.png`, `ref_b4.png`,
`ref_b5.png`.

> Redraw these five heads from the attached references, keeping each
> one's design, on an even grid and cleaner: (1) the lantern jaw with
> stubble, the jaw squarer and heavier; (2) the full beard following the
> long jaw down to a point; (3) the buck teeth and weak chin, with a much
> thicker, bushier unibrow; (4) the older woman in round glasses, without
> her ponytail, the ear redrawn small and clean; (5) the woman with the
> huge white-toothed grin and squeezed-shut eyes, without her ponytail.

## G. Retries: `faces_g.png`

Attach `refs/ref_a1.png`, `ref_b1.png`, `ref_c3.png`, `ref_c4.png`,
`ref_c5.png` as what not to repeat.

> Five heads that round 1 missed; the attached references are the misses.
> (1) The guide's own man, redrawn bolder: the same size as the guide,
> the same long, forward chin pushed even a little further, a clear eye
> with a white and a dark pupil, a brow with attitude; (2) the guide's
> woman (no ponytail) the same way: keep her long chin, add a lashed eye
> and an upturned nose; (3) a bulldog: the lower jaw juts 3 or 4 px past
> the upper lip with two lower teeth showing above the lip, a heavy brow;
> (4) a horse face: the face from brow to chin a third longer than the
> guide's, the chin dropping to row 43, droopy eyelids, a flat deadpan
> mouth, the nose long; (5) mutton chops: thick sideburns in the hair
> colour from the ear down to the jaw corner, outlined so they read as
> hair, the chin shaved, a broken boxer's nose.

## H. New, in the style that worked: `faces_h.png`

> Five new heads, as funny as round 1's crescent chin and potato nose:
> (1) a woman with an enormous jutting chin and a proud smirk; (2) a woman
> with a big beaky nose, a tiny eye and a tight little mouth; (3) an old
> woman, toothless and puckered, her chin and nose almost meeting;
> (4) a man with giant ears (still outlined, lighter inside) and a nervous
> toothy grin; (5) a man with a big soft double chin and tiny eyes, nose
> and mouth bunched in the middle of a wide face.

## After you generate them

Save `faces_e.png` to `faces_h.png` here and tell me. I'll run `snap.py`
and `review.py` on them, put each head on the bodies under every hat and
palette, and pick the set for the game.
