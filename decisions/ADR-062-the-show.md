# ADR-062 — The Show

Status: **Accepted 2026-10-18**
Milestone: `PORT-39`. Ports: SNES ADR-066 (player rings), 064 (the sprite
wish list in play) and 054 (GLOW and INVERSE), redone for full colour.
SNES ADR-063 (more quips) came with PORT-35.

## What changed

- **A filled circle at each player's feet** (the SNES's ring: an outline
  was its limit, the user's call): P1 to P4 in the lobby's colours (blue,
  red, green, gold: the port's player colours since PORT-16, not the
  SNES's 1P red), a CPU grey, none in the title demo. Drawn over the
  shadow, which shows through as its darker middle.
- **Point reactions:** the winners celebrate (DAD and KIDDO a thumbs-up,
  the GYM BROS a flex, the PIRATES en garde, everyone else the cheer); the
  losers slump; the loser nearest a ball that bounced twice past them, if
  running, dives, scrambles up, then slumps. Six new HD poses in
  `players.py`.
- **Emotes** over heads: ! into the net, ? out, sweat for a second bounce,
  anger for a rules fault (with the losers' quip, on the loser nearest the
  ball); a star over the winner of an 8-shot rally; a note over a dink
  rally's third soft shot; Z's over the receivers while a human server
  waits 5 seconds.
- **The net shivers** where a ball goes in; a drive **squashes** at
  contact and **stretches** in flight; drives and slices trail a
  **streak** (a slice's cool white) until they bounce. Not with BIG BALL.
- **Critters:** LAKESIDE's gull, SPACE's satellite (half speed) and
  UNDERSEA's fish cross under the scoreboard every 2048 frames.
- **A trophy** over CHAMPION!.
- **GLOW** (a MODIFIERS row): the court at NIGHT with LIME lines; every
  player's outline neon green, paddles purple, pink and cyan, outfits more
  saturated; the ball's outline neon.
- **INVERSE** (a MODIFIERS row): the picture under the HUD as a negative.

## How

- `view/flair.gd` follows `flair.c`'s rules (reactions, emotes and their
  lifetimes, the dive's 12 + 12 frames, the Z's for a human server only).
  The SNES's frame-budget staging (waking, waiting a frame, a celebration
  lookup a slot a frame) isn't needed and is left out. Display only:
  `test_flair` runs a match beside a bare sim.
- **INVERSE** is one full-screen negative (`view/invert.gdshader`) on a
  CanvasLayer just under the HUD's. The SNES left shadows dark; here the
  shadows and the circles are drawn as their own negatives, so the
  inversion puts them back (a black shadow at alpha a over ground g,
  drawn white, inverts to exactly the dark shadow on the inverted ground).
- **GLOW** uses the role sheets for every player (`PlayerLook.glow`), the
  ball a small outline shader. `K.MOD_INVERSE` is 256: the port's
  modifiers are wider than the SNES's byte (its `modifiers2`).
- The MODIFIERS page has nine rows now; it sits higher, over the logo
  (hidden, as CONTROLS does).

## Not done

- The practice **pickle** behind the ball machine (SNES ADR-064): the port
  draws its own machine; a pickle can come with a practice pass.
- ADR-074's hitting poses were in the port before (PORT-19's `reach`,
  `scoop` and the overhead).
