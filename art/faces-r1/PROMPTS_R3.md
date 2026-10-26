# Faces round 3: conventional faces

Rounds 1 and 2 went for the goofy end (huge noses, crescent chins,
underbites), and that read as plain ugly. Round 3 turns the other way:
ordinary, likeable people of different ages, the roster of a good
mid-90s sports game. Character comes from age, hair, brows, expression
and facial hair, not from exaggerated features.

Four sheets of five, as before. Save each PNG here under its name and
tell me; I snap them, put them on the bodies under every hat and skin,
and make a lineup.

Attach to every prompt: `guide_head_cell.png`, `guide_cell_plain.png`
and `guide_female_no_tail.png`. Sheet P also attaches the round 2 heads
it redraws, from `refs/`.

## What carries over

All the fitting rules from rounds 1 and 2 still hold (`PROMPTS.md`,
`PROMPTS_R2.md`). They worked: every round 2 head fit every hat and skin.

- The top and back of the skull fill the pink dome; hair above the pink
  line stays flat to the skull.
- Facing right, in profile, one eye showing.
- The jaw reaches rows 41 to 43; a short neck as thick as the guide's
  ends at the blue ring.
- No ponytails, buns or tall hair. The game adds the women's ponytail.
- A small outlined ear, lighter inside.
- Nine colours, every art pixel an identical square block on one grid.

## What's new

- **Normal proportions.** The nose is a small bump of 2 to 3 px, the chin
  sits under the mouth, not in front of it, and the teeth stay behind the
  lips unless the head is smiling. Nothing is the joke.
- **Faces that read at 1x through a few pixels.** An eye with a white and
  a dark pupil, a brow that sets the mood, a mouth of 2 to 4 px, and a
  jawline that says young, old, soft or square.
- **Variety from the right places**: age (smooth skin or a crease at the
  eye and mouth), the hairline (full, receding, bald), hair at the
  temple, the sideburn and the nape, facial hair, glasses, and
  expression (a grin, a smirk, focus, calm).

## The style, for every prompt

> Use case: new player heads for an existing 16-bit pickleball game,
> drawn to fit its bodies and hats exactly. Match the attached guide's
> pixel art: chunky 1 px dark outline, flat colour clusters, light from
> the top left, the skin shaded with its four tones (darkest at the back
> of the jaw and under the chin). A head is about 26 x 30 art pixels.
> These are ordinary, likeable people with natural proportions, like the
> player roster of a polished mid-90s 16-bit sports game: a small nose,
> a natural chin, a clear eye, an expressive brow and mouth. Not
> caricatures, not exaggerated, not cute or anime. No text, letters,
> digits, logos.
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

## M. Men: `faces_m.png`

> Five men's heads, left to right: (1) early twenties, clean-shaven, a
> short crew cut, a friendly half smile; (2) thirties, a neat short beard
> along the jaw, a calm, steady look; (3) forties, a receding hairline,
> a crease at the eye, a warm open smile; (4) an athlete, a strong square
> jaw (natural, not a cartoon), focused narrowed eyes, short sideburns;
> (5) sixties, thinning hair with a full fringe at the back, a trimmed
> moustache, kind eyes and a small smile.

## N. Women: `faces_n.png`

> Five women's heads, each without a ponytail (the game adds it), the
> hair at the back reaching the pink line like the attached woman's:
> (1) early twenties, short bangs that show under the hat line, a bright
> smile; (2) thirties, strong brows, a determined, focused look;
> (3) forties, rectangular glasses (outline frame, a white glint), a
> friendly smile; (4) sixties, softer jaw, laugh lines at the eye and
> mouth, a warm grin; (5) a teenager, a round young face, laughing with
> her mouth open.

## O. Mixed: `faces_o.png`

> Five heads, left to right: (1) a teenage boy, hair falling over the ear
> and at the nape, a cocky grin; (2) a man in round glasses, a
> thoughtful, slightly amused look; (3) a man with a short goatee and a
> confident smirk; (4) a bald man in his fifties, a broad, cheerful face;
> (5) a woman in her thirties, without a ponytail, a wide easy smile and
> soft round cheeks.

## P. Round 2, toned down: `faces_p.png`

Attach `refs/ref_f1.png`, `ref_f2.png`, `ref_f4.png`, `ref_f5.png`,
`ref_g2.png`.

> Redraw these five round 2 heads from the attached references as
> ordinary people, keeping who each one is but losing the exaggeration:
> (1) the man with stubble: a firm, natural jaw instead of a lantern,
> the stubble kept; (2) the bearded man: the same full beard, a natural
> nose and brow; (3) the woman in round glasses, without her ponytail,
> a natural nose and chin; (4) the woman with the big grin, the grin
> kept but smaller, the eyes open and smiling; (5) the young woman with
> the upturned nose, without her ponytail, the nose and chin natural.

## After you generate them

Save `faces_m.png` to `faces_p.png` here and tell me. I'll snap them,
put each on the bodies under every hat and palette, and make a lineup
next to the current man and woman.
