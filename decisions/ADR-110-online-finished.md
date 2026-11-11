# ADR-110 — Online, Finished: the Guest's Side, Career Looks, the Letter Grid, the Relay's Reasons

Status: **Accepted 2026-11-11** (asked for by the user: "work on anything
that's left that does not need my input"). Milestone: `PORT-114`,
`PORT-115`, `PORT-116`, `PORT-117` (GitHub issues #3, #4, #5, #6).
`PORT-110` (correction smoothing) waits on the lead's real-line playtest
of PORT-109 and isn't part of this.

## Decision

**The guest's side on the left (PORT-114, KNOWN_ISSUES #54):** the online
guest's match is drawn left for right, so they play from the left as the
host does. It's a mirror of the picture only:
- `CourtView.mirror` flips the world's x on its way to the screen, so
  everything placed through CourtView follows: players, the ball and its
  shadow, the effects, the close calls and the camera's lean. The audio pan
  follows too.
- Sprites face the net from either side (`flip_h` follows the mirror).
  Handedness flips with the picture, as a mirror does. The right team's
  paddle hand is PORT-162's.
- The HUD's two panels swap: the guest's name, colour, score and serving
  ball are on the left.
- Text never mirrors: only positions move.
- The sim and its inputs don't mirror. The guest's pad goes through the
  mirror before the session (`MatchInput.mirror_intent`), so left on the
  screen is left. SHORT's aim (away from your own net) is already the
  world's, so it stays.
- A replay saved by the guest keeps `mirrored` and plays from their side
  on REPLAYS.

The mirror is a static on CourtView, set by the MatchView that needs it
and cleared when that view goes. Only that view clears it: a demo freed
late doesn't clear a new view's mirror.

**Career looks online (PORT-115):** PROTOCOL 4. HELLO carries the career
player's look: their body, skin, hair, hat, shirt pattern and head, six
small ints (`OnlineSession.LOOK_KEYS`). A career player plays in their
shirt, body and paddle, as every career match does. The host's START hands
both looks to both machines by slot, and each view draws them
(`PlayerLook.for_career`). The looks are never in the config, so never in
the sim or the desync hash. A look from the line is made valid
(`Career.Player.from_dict`) before it's drawn.

**Telling an older game to update (PORT-115, PORT-117):** a version or
protocol that differs closes the handshake, as before. Now each side says
who updates: YOUR FRIEND HAS 0.40.0: THEY NEED TO UPDATE, or THEY HAVE
0.45.0: UPDATE THIS GAME TO PLAY. QUIT carries the sender's version, so
the other side says it too. A PROTOCOL 3 game still closes cleanly, with
its own VERSIONS DIFFER.

**The room on a letter grid (PORT-116):** the ROOM row opens a MenuPage
of the code's alphabet:
- Four rows of five letters, then DELETE and JOIN. Up and down pick the
  row, left and right the letter (a box marks it), and HIT types it.
- With the code full, the cursor jumps to JOIN.
- The touch pad drives it as a pad does. The mouse picks the letter under
  it, and a click types it.
- Keys still type and paste. The keyboard's HIT and back keys (J, K, L)
  are letters of the code, so a typed letter is only a letter. On a
  keyboard the help says ESC DONE, and SPACE still picks from the grid.
- The address (by ADDRESS) stays keyboard only: it's a desktop's, and
  it has digits and dots.

**The relay's reasons (PORT-117):** the relay already names a refusal.
Each has a line now that says what to do: NO SUCH ROOM: CHECK THE LETTERS,
THAT ROOM IS FULL: HOST YOUR OWN, TOO MANY WRONG ROOMS: WAIT A MINUTE,
and so on. The relay's welcome carries the host's version, so a guest on
another version is told before the handshake. A dial to a relay that's
waking counts down (GIVING UP IN 38) instead of sitting still. The relay
needed no change for any of this.

## What it doesn't do

- `min-replicas 1`, which would end the relay's wake-up wait, costs about
  $15 a month. That's the lead's call (For you); the countdown is the
  free half.
- Doubles online is the next milestone's (PORT-118..122).

## Consequences

- An online match needs both players on this version (PROTOCOL 4).
- Tests:
  - `test_online`: the guest sees themselves on the left; career looks
    travel (and the match is the same without them); the version lines;
    the room on a letter grid.
  - `test_relay`: each refusal has a line that fits; the welcome's version;
    the countdown; the grid joining and the real relay's full room and old
    host (`PB94_RELAY_JS`, else skipped as on CI).
  - `test_layout`: the mirrored HUD, the grid on every row on both devices,
    and the countdown.
- Screenshots: `tools/online_shot.gd guest|host|grid`.
