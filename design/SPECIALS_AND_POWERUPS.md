# Player specials and powerups

A running document, started 2026-10-21 at the project lead's ask: "maybe
there's a dedicated special button, or they can pick up a powerup." Like
[GOOFY_IDEAS.md](GOOFY_IDEAS.md), nothing here is a commitment. Add to it as
ideas come; when a piece is chosen, it gets a PORT task, an ADR and a
line in the bible's §5 in the same branch.

## Where it fits

- **The '95 story.** The bible's §5.8 lists the *Pickleball '95* promises:
  features the ROM never had, which the remaster "finally delivers". Specials
  fit there, and the strongest candidate on that list, the **overhead
  smash** (§5.7), is a special already: the '94 overhead swing that has
  always done nothing. That could be the first one built.
- **Remaster-only, behind a switch.** Like the modifiers, specials and
  powerups are off in `MatchConfig` (the ROM's game, so the golden and
  conformance traces never move) and offered on MODIFIERS or the tuning
  panel. A RULES row could be **SPECIALS** (the meter and button) and a
  MODIFIERS row **POWERUPS** (pickups on the court), so each can be on
  alone.
- **The sim stays exact.** Everything below has to be ints, with no
  randomness: where a powerup appears and which one comes from the
  match's own counters (the shot serial, the score, the frame), so
  replays, PLAY OF THE MATCH and online lockstep keep working unchanged.

## Route A: a SPECIAL button and a meter

Each player has a meter that fills with good play. When it's full, the
SPECIAL button spends it on the next shot.

- **The button.** The SNES pad has none free: B hits, Y soft, A drive, X
  SLICE, and L or R held is SHORT (all canon, SNES ADR-056). So SPECIAL is
  something the SNES never had: the right trigger on a modern pad, O on the
  keyboard, remappable on CONTROLS and shown through `PromptBar` like the
  rest (built: ADR-080).
- **What fills it:** rallies you win, a long rally (any outcome), a clean
  dink exchange, a return from deep. Not aces: they shouldn't snowball.
  A side that's behind could fill faster (a catch-up rule), to be tuned.
- **On screen:** a short bar under each team's score on the HUD. When it's
  full the player's tag flashes, and the announcer gets a "SPECIAL READY!"
  line (and one per special, for ADDITIONS).
- **The AI uses it too**, by personality: ACE fires at once, the dinkers
  save it for the kitchen, and RAVEN (who slices) has a slice special.

### Specials by paddle

The paddles have a 9-point budget across POWER, CONTROL and SPEED (bible,
ADR-015). A special per paddle keeps that identity, and the hats stay
looks or stat trades:

| Paddle | Special | What it does |
|---|---|---|
| RED (power) | **PICKLE SMASH** | The overhead smash, from any height: a hard, steep shot that lands at the opponent's feet. The '95 promise. |
| GOLD (speed) | **BLUR** | Two seconds of top speed and a longer reach: get to anything. |
| BLUE (balanced) | **CURVEBALL** | The shot bends late toward the far sideline, the way WIND pushes a ball, but only this one. |
| WOOD (control) | **NEEDLE DINK** | A dink that dies on the bounce (it barely rises), nearly unreturnable from the baseline. |

Other candidates: **THE WALL** (one free return, made for you, of the next
ball you'd miss), **DOUBLE TAP** (the ball hangs for a beat at its peak,
then drops fast), **SPIN SERVE** (a serve that kicks sideways off the
bounce).

## Route B: powerups on the court

Every so often, an item appears on one side of the court. The first
player to run over it (or to hit the ball through it?) takes it. It's held
until used with the SPECIAL button, or it acts at once.

| Powerup | Effect | Notes |
|---|---|---|
| **BIG PADDLE** | Your reach grows for the next 3 shots | |
| **PICKLE JAR** | Your next shot is a PICKLE SMASH | Ties route B to route A |
| **ICE PATCH** | The other side slides (ICE) until the point ends | Reuses the ICE modifier, for one side |
| **SLOW-MO** | The ball moves at half speed for 2 seconds | Like BALL SPEED, for one rally |
| **MAGNET** | The next ball to your side bends toward you | |
| **SNEAKERS** | You move faster until you lose a point | |
| **GOLDEN BALL** | This rally counts for 2 points | Strong: maybe only with FIRST TO 11 or more |
| **BANANA** | The other side's next step-turn spins them around | Goofy; the crowd laughs |

- **Where they appear:** in a lane the rally doesn't reach often (the
  deep corners) so taking one is a risk. Never in the kitchen.
- **How often:** about one every 3 or 4 points, set from the score so
  it's the same in a replay.
- **Look:** a floating box with an icon, bobbing, and a pickup chime. The
  art is drawn like the ball machine (`art/sprites/machine`, built in
  Aseprite).

## Route C: both

The meter and the button are always the same (route A). Powerups (route
B) are an optional modifier that fills the meter or gives a special
outright. This is the pick so far: the button is learned once, and
pickups work as a party mode on top.

## Where else it shows up

- **Story mode:** a chapter that teaches the button. The rival unlocks a
  special at the end.
- **Achievements:** "SMASH HIT" (win a point with PICKLE SMASH), "FULL
  JAR" (take five powerups in one match).
- **PICKLEBALL 101:** none. The course teaches real pickleball, and
  specials aren't.
- **Open play:** off at the park by default ("house rules" could turn
  them on per court).
- **Online:** fine, since everything is in the sim and the lockstep sends
  only inputs. The SPECIAL button needs one more bit in the input.

## Questions for you

1. Route A, B or C? (I'd go with C.)
2. Specials per paddle (above), per character, or one shared set?
3. Should specials be canon '95 features (into the bible's §5.8), or a
   remaster-only party mode?
4. Is GOLDEN BALL (a 2-point rally) too much?

## Log

- 2026-10-21: started. Routes A/B/C, specials by paddle, the first
  powerup list, where it touches the rest of the game.
- 2026-10-21: route A's first special built (PORT-65, ADR-080): SPECIALS
  on RULES, a meter for each player, PICKLE SMASH on O / the right
  trigger (not X: X became SLICE, SNES ADR-056; not the shoulders: they're
  SHORT in the bible). A smash's return pops up (the knock-back). Next:
  the other paddles' specials, if PICKLE SMASH plays well.
