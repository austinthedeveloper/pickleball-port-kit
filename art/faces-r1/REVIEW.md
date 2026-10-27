# Faces round 1: review

The four sheets (`faces_a.png` to `faces_d.png`), snapped to the game's
pixels by `snap.py` (`snapped_faces_*.png`, `heads.json`) and tried on the
real bodies by `review.py` (`review_faces_*.png`). Each row of a review
sheet is one head: bare, the cap, the eleven other hats, three more skin
and hair palettes (dark/black, tan/blonde, brown/red), the swing and the
run.

```sh
.venv/bin/python art/faces-r1/snap.py      # sheets -> heads.json, snapped_*.png
.venv/bin/python art/faces-r1/review.py    # heads.json -> review_faces_*.png
```

## What worked

- **They fit.** Every head sits under all twelve hats with nothing poking
  through. The skull-on-the-dome rule held on all twenty.
- **They recolour.** The nine-colour rule held well enough that each head
  maps cleanly onto all four skins and hairs; the dark/black column reads
  as well as the light one.
- **Character.** The goofy end landed. At game size the crescent chin
  (d1), potato nose (d2), manic yell (d4), bald old man (a4), walrus
  moustache (a5), beard (c2), granny glasses (b4) and grin (b5) all read
  at a glance.

## What didn't

- **Not on the grid.** The sheets came back 2172 x 724 (one 1983 x 793)
  with about 55,000 colours, and art pixels of 12 to 16 image px instead
  of 8. `snap.py` recovers them (it measures the outline's thickness,
  finds the grid, then takes the nearest of the nine colours). The odd
  sizes are fine; uneven pixel blocks are what cost detail.
- **The ponytails are baked in.** The game draws its own ponytail, which
  flies back in the run, swing and follow frames. A painted one can't, so
  round 2's women are drawn without one.
- **Some heads came out small.** a1 and a3 are about 21 px wide against
  the current head's 24, with the jaw ending 3 to 5 rows high, so they sit
  on a long thin neck. Most necks are narrower than the body's.
- **Ears** came back as a dark two-tone blob that reads as a bruise on
  several heads (a4, b1 to b5).
- **The long chin went soft.** The brief asked to keep it, and most of
  the women and c4 drifted to rounder, generic jaws.

## Per head

| Head | Verdict | Notes |
|---|---|---|
| a1 the current man, cleaner | Retry | Too small, and the chin, the whole point, shrank. |
| a2 lantern jaw | Keep, polish | Reads; the stubble is good. Square the jaw more. |
| a3 hooked nose | Drop | Small, and the nose doesn't read as hooked at game size. |
| a4 bald old man | Keep, polish | Great under every hat. Fix the ear blob. |
| a5 walrus moustache | Keep | One of the best. |
| b1 the current woman, cleaner | Retry | Bland; the long chin is gone. |
| b2 bangs, freckles | Drop | Freckles vanish at game size; the bangs vanish under hats. |
| b3 strong jaw, smirk | Drop | Fine, but forgettable next to the others. |
| b4 glasses | Keep, polish | The glasses read. Fix the ear. |
| b5 big grin | Keep | The teeth carry it. |
| c1 teen, mid-shout | Drop | Reads, but d4 does the shout better. |
| c2 beard | Keep | Strong on every skin. |
| c3 bulldog underbite | Retry | Reads as a puffed cheek, not a jutting jaw. |
| c4 horse face | Retry | Not long: it came out as a normal face. |
| c5 mutton chops | Retry | The chops read as a dark smear on the cheek. |
| d1 crescent chin | Keep | The best of the set. |
| d2 potato nose | Keep | Second best. |
| d3 unibrow, buck teeth | Keep, polish | The teeth read; the unibrow needs to be thicker. |
| d4 manic yell | Keep | Great. |
| d5 villain | Drop | The goatee on a ponytailed head confuses it (my prompt's fault). |

Keep 10, retry 5, drop 5. Round 2 (`PROMPTS_R2.md`) redraws the keepers
cleaner from their snapped versions (`refs/`), retries the five, and adds
five new heads in the style that worked: the far end of goofy, including
women.

# Round 2

`faces_e.png` to `faces_h.png`, from `PROMPTS_R2.md`. `lineup_r2.png` puts
the proposed set side by side, with the current man and woman first:
bare, in the cap, and dark skin with black hair.

## What changed in the tools

- `snap.py` measures the pitch **once per sheet** (the median of each
  head's estimate) and fits only each head's grid offset. Per-head
  estimates were wrong on a few heads (h3, h4 and f2 came out about 20%
  small and sat on long necks); a generated sheet keeps one grid, so the
  median is safe. Round 1's heads were re-snapped the same way and grew
  slightly. (Fitting the grid by the least colour variance inside blocks
  doesn't work: smaller blocks always win.)
- `review.py` gives round 2's women the game's own ponytail, so the run
  and swing columns show it flying.
- `review.lineup()` draws `lineup_r2.png`.

## What worked

- **Even grid, right size.** Every head snaps to 24 to 31 px wide and 29
  to 34 tall, the jaws reach the guide's rows, and the necks match the
  body's.
- **No baked ponytails**: the women take the game's, and it animates.
- **The keepers survived the redraw.** All ten from round 1 came back as
  themselves, cleaner.
- **The retries mostly landed**: the horse face is long now, the mutton
  chops read as hair, the bulldog shows its teeth.

## Per head

| Head | Verdict | Notes |
|---|---|---|
| e1 crescent chin | Keep | Still the best. |
| e2 potato nose | Keep | |
| e3 manic yell | Keep | |
| e4 bald old man | Keep | The ear is cleaner; still dark on the darkest skin. |
| e5 walrus moustache | Keep | |
| f1 lantern jaw, stubble | Keep | |
| f2 beard | Keep | |
| f3 unibrow, buck teeth | Keep | The unibrow reads now. |
| f4 glasses | Keep | |
| f5 big grin | Keep | |
| g1 the current man, redrawn | Drop | Clean but blander than the procedural head it copies; keep that one. |
| g2 the current woman, redrawn | Keep | Upturned nose and lash read; the long chin is back. |
| g3 bulldog | Keep | Reads as a bulldog now: teeth over the lip, heavy brow. |
| g4 horse face | Keep | Long and deadpan, as asked. |
| g5 mutton chops | Keep | |
| h1 jutting chin, smirk | Keep | |
| h2 beak nose | Keep | One of the best new ones. |
| h3 toothless pucker | Drop | Reads as a squint, not a pucker. |
| h4 giant ears, nervous grin | Keep | |
| h5 double chin | Keep | |

18 kept, 2 dropped. With the current man and woman that's 20 heads,
6 of them women (g2, f4, f5, h1, h2 and the current one).

## Left to decide

- Whether the set is final, or a round 3 should add more women or swap
  out any of the 18.
- How the game uses them. Nothing reads `heads.json` yet: the heads
  would join `players.py` as head variants (each one's role grid stamped
  at the neck, the cap and hats unchanged), with a CAREER EDIT row and
  per-opponent heads. That's a design change and needs an ADR.

# Round 3: conventional faces

Rounds 1 and 2 read as plain ugly, so `PROMPTS_R3.md` asked for ordinary,
likeable people. `faces_m.png` to `faces_p.png`; `lineup_r3.png` shows all
twenty next to the current man and woman (bare, in the cap, dark skin with
black hair).

## The tools

- **Sheets M, N and O were drawn about 15% bigger than the guide.**
  Snapped on their own grid, the skulls overflowed the hats (hair out the
  back of the cap) and hid the women's ponytail. `snap.py` now checks
  each sheet's skull width against the guide's (22 px, 8 rows below the
  top) and, when the heads are more than 8% too big, resamples the source
  on the coarser grid that fits them to the dome. That's cleaner than
  shrinking snapped pixels, since the source is high resolution. Round
  1's sheet B is caught too (its baked ponytails widen the skull); it
  shrinks a little, which doesn't matter now.
- All twenty fit every hat after that, and the game's ponytail shows on
  every woman.

## What worked

- **The direction.** They read as one believable roster: natural noses
  and chins, clear eyes, and expressions you can tell apart at 1x (the
  smiles, n2's focus, n5's laugh, o3's smirk).
- **Variety from the right places**: beards (m2 short, p2 full), stubble
  (p1), a goatee (o3), a moustache (m5), glasses (o2, n3, p3), bald (o4),
  thinning (m5), shaggy (o1), age lines (n4).
- They hold up on the dark skin.

## What didn't

- **Sameness among the clean-shaven.** m1, m3, m4 and o1 are close, and
  so are n1 and p5. Hair colour and skin will separate them in a match,
  but they're near duplicates.
- **Hairlines vanish under hats.** m3's receding hairline (the point of
  the head) is covered by every hat but the headband.
- **The long chin is gone.** These are rounder and shorter than the
  current heads, which still look like the odd ones out next to them.

## Per head

| Head | Verdict | Notes |
|---|---|---|
| m1 young, crew cut | Keep | |
| m2 short beard | Keep | |
| m3 receding hairline | Drop | Close to m1; the hairline is under the hat. |
| m4 athlete, square jaw | Keep | |
| m5 older, moustache | Keep | |
| n1 young, bangs | Keep | |
| n2 determined | Keep | |
| n3 glasses | Keep | |
| n4 older, laugh lines | Keep | |
| n5 teen, laughing | Keep | |
| o1 teen boy, shaggy | Keep | |
| o2 round glasses | Keep | |
| o3 goatee, smirk | Keep | |
| o4 bald, cheerful | Keep | |
| o5 wide smile | Keep | |
| p1 stubble | Keep | Round 2's lantern jaw, made natural. |
| p2 full beard | Keep | Fuller than m2, so different enough. |
| p3 round glasses | Keep | |
| p4 grin | Keep | |
| p5 young, upturned nose | Drop | Too close to n1. |

18 kept: 10 men, 8 women.

## Left to decide

- Whether the current man and woman stay in the set beside these, and
  whether any of round 2's milder heads (the walrus moustache, the bald
  old man, the beard) belong in it.
- Wiring them in (an ADR, as above).
