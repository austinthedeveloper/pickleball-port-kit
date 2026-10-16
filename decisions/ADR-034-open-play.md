# ADR-034 — Open Play

Status: **Accepted 2026-10-13** (first version)
Depends on: ADR-018 (doubles), ADR-020 (scenes), ADR-023 (opponents),
ADR-025 (options), ADR-033 (modifiers).
From: `docs/GOOFY_IDEAS.md`, "Open play".

## The idea

The real open-play experience: you show up at a park with several courts,
put your paddle in a court's **paddle stack**, watch the games while you
wait, and play when your turn comes.

## What it is

**OPEN PLAY** is the third title entry (SINGLES, DOUBLES, OPEN PLAY,
COURT, RECORDS, OPTIONS, MODIFIERS, PRACTICE). It opens the **park**, a
scene of its own, like Player Select:

- **Three courts** seen from above, at three skill levels (see Skill
  levels), each with a game going: the people
  rally, the score shows over the court, and a game is first to 7. Points
  come every 1 to 3 seconds, so a game takes about half a minute.
- **Paddle stacks:** each court has a rack at its gate, and the paddles
  hanging on it are the next in line (next first, up to four). Yours is in
  your colours; the others are grey.
- **The people** are the eight ladder teams (ADR-023), in their captains'
  colours. Six play while two wait.
- **Rotation:** when a game ends, all four players come off and rejoin
  their own court's stack, then the top two entries go on. A team only
  goes to another court's stack if its own is full, and a short stack
  borrows the front team of the longest other one (never your paddle).
- **You** walk the park with the D-pad. You can't walk into the courts:
  the fences are solid, and you slide along them.
  - **B at a rack** stacks your paddle, or takes it back if it's already
    there. Stacking at another court moves it.
  - Near a court, the panel names who's playing ("PIRATES VS TWINS").
  - Once stacked, it says "YOU'RE NEXT ON COURT 2" or "WAITING ON
    COURT 2".
  - **Start** goes back to the title.
- **Your game:** when your paddle reaches the top of the stack at a
  changeover, the park calls you ("YOUR GAME!", "COURT 2 VS PIRATES") for
  2.5 seconds. Then it starts a **doubles match**:
  - you and a partner against the team drawn with you. The partner is the
    captain of the team waiting next at that court ("WITH PETE VS SURF
    CREW"), with their look, body, paddle, and play style (ADR-023). Their
    team stays in line. With nobody waiting there, it's the regular (the
    default CPU).
  - at the park (AUTO venue)
  - with the saved points and modifiers, at the court's difficulty
  - no intro card, no ladder change, and no CHAMPION!
  - records count it as a doubles game against the CPU
- **After it:** the result says "@ PARK  START MENU". B takes you back,
  where the park shows "YOU WON 5-3" or "YOU LOST 2-5" and your court
  changes over.
- The park is fresh each time you enter it from the title. It waits while
  you play.

## Skill levels

*Amended 2026-10-13:* the courts are skill levels, each with its own
colour and a label over it:

| Court | Label | Apron | Teams (ladder order, ADR-023) | Your game |
|---|---|---|---|---|
| 1 | `<3.5` | teal | HENDERSON, SNOWBIRDS, GYM BROS | EASY |
| 2 | `3.5-4.5` | gold | PIRATES, GOTH CLUB, SURF CREW | MEDIUM |
| 3 | `4.5+` | red | TWINS, CHAMPS | HARD |

- Your game's difficulty comes from the court, not OPTIONS. KID stays
  KID, so its swing assist works on every court.
- Teams play at their level. They start there, and a team coming off
  rejoins its own court's stack. The two coming off join first, then the
  top two go on.
  - On the 4.5+ court, with two teams, those two keep playing until
    someone stacks there.
  - Anyone already waiting is ahead of the two coming off, so a paddle
    you stack plays at the next changeover if it's in the top two.
- Art: each court's tiles use their own copy of the park palette (BG
  palettes 1-3), differing only in the apron. The tile count is the same
  (47), since tiles are shared across palettes. The HUD font gained a `+`.

## Partners from the stack

*Amended 2026-10-13 (`M4-OPEN-03`):* `MatchConfig.partner` is a ladder
team whose captain plays slot 1. `match_config_partner(team)` sets their
variant and paddle. `match_slot_style` and `match_compose_palette` give slot
1 the captain's style and palette. OPPONENT_NONE keeps the default CPU,
and every other mode leaves it unset. Difficulty never changes your partner:
it changes the CPUs on a team with no human (ADR-025). Tests:
`test_opponents.c: test_partner` and the partner check in
`test_open_play.c`.

## A livelier park

*Amended 2026-10-13 (`M4-OPEN-02`):*

- **Walking:** after a game, its four walk to the court's gate over the
  first 64 frames of the changeover. A new game's four walk on from the
  gate over its first 64 frames (`OpenCourt.age`), and its first point
  waits for them.
  - The positions are straight lines from spot to gate; the renderer
    draws them on its every-third-frame court turn.
  - The ball is hidden while anyone walks.
- **The crowd:** three people sit on each bench, painted into BG1. Bench
  tiles use a fifth BG palette: the park's, with the colours that never
  appear by the benches (court, tree, metal) swapped for skin, hair, and
  shirts. The park is now 61 tiles.
- **Not done:** a bigger, scrolling park (`M4-OPEN-05`). All eight OBJ
  palettes are in use, and the scores over the courts are BG3 text that
  can't scroll with the map.

## Two players

*Amended 2026-10-13 (`M4-OPEN-04`):* 2P comes along as your partner.

- 2P joined on the title (Start on pad 2) comes into the park. In the park,
  Start on pad 2 joins or leaves ("2P JOINED: YOUR PARTNER!", "2P LEFT").
  The panel's idle line reads "YOU AND 2P  START EXIT".
- Your game: 2P plays slot 1 instead of the captain next in line ("WITH 2P
  VS TWINS"), in gold (the doubles default), with the KID assist on KID.
- Input: `input_assign_match` gives slot 1 the port 2 pad when slot 1 is
  human and slot 2 isn't (co-op). Versus keeps port 2 on slot 2, and slot 1
  has a pad of its own only on a Multitap. Records count the game against
  the CPU (no human on the right).
- No 2P sprite walks the park: all eight OBJ palettes are in use there.
- Found on the way: on the COURT page, a recolour and a row redraw could
  land on one frame, and a few cycles of change elsewhere tipped it over.
  The renderer now flags a recolour frame (`g_render_busy`), and the HUD
  waits a frame.

## The clubhouse

*Amended 2026-10-14 (`M4-OPEN-05`; the user chose a clubhouse over a
fourth court):* the park is two screens wide, and the view scrolls with
you.

- **The second screen:** the path goes on to a clubhouse, a room seen
  from above. Its walls are solid, and a door in the bottom wall opens onto
  the path (`open_walkable`, `open_in_house`).
  - **B at the records board** (on the back wall) shows a records page in
    the panel and turns to the next on each press: doubles and singles
    won and lost, best streak and longest rally, ladder clears and the
    practice best.
  - **B at the ball machine** starts practice on the saved PRACTICE
    settings, in the default look (no Player Select). On the pause menu,
    MAIN MENU reads **PARK** (`g_pause_park`) and goes back. The park
    waits, as for your game.
  - **The bench** seats the first two teams waiting in a stack (`open_waiting_team`),
    and the panel names them ("GYM BROS AND SURF CREW WAIT").
  - You can still be called while you're inside.
- **BG1:** a 64x32 map (the park is 512x224, 159 tiles) at VRAM
  0x0800-0x0fff, Player Select's portrait maps' place. The court's map
  stays a screen at 0x0000, and `render_load_court` puts the pointer and
  the scroll back. The clubhouse is whole tiles, in a BG palette of its
  own (6). `indexed_scene` converts two-screen pictures.
- **The court labels and scores** were BG3 text, which can't scroll with
  the park. They're sprites now: HUD font glyphs in the objects palette,
  yellow for scores and white for labels. That's 25 OBJ tiles, 249 of 256.
- **Palettes:** with the view past x 76, court 1 is off screen (its
  objects end at 64) and the bench not yet on (from 346). Court 1's two
  team palettes are then the bench teams', and court 1's people are
  hidden.
- **OAM:** the cache keeps park x, not screen x. When the view moves,
  `park_oam_scroll` (assembly) moves every shown object:
  - one byte store for an object on screen before and after
  - nothing for one off screen both times
  - `oam_write` only for one crossing an edge

  Calling `oam_write` for all of them cost about 100 scanlines a scroll
  frame; this costs about 50.
- **Frame budget:** a scroll frame plus a message step came to 230-250
  scanlines, so a message now draws over four frames: clear, the panel,
  and the text in two halves (`hud_center_prompt_half`). A score (five
  sprites) is a frame's job of its own, not after a court's animation.
  `clubhouse.timeline` and `open_play.timeline` have zero overruns.
  - The doubles match result had the same trouble (`M4-UI-04`): it draws
    its prompt and the opponent's line in halves too.

## How

- `src/open_play.c`, `include/open_play.h`: the rules, pure and
  host-tested.
  - `open_play_begin`, then `open_play_update(move_x, move_y, b)` each
    frame. It returns an event: STACKED, UNSTACKED, FULL, CALLED, or PLAY.
  - `open_play_return(won, for, against)` takes you back after your game.
  - The layout constants are shared with the art. `tools/assetgen/park.py`
    reads them from the header and paints the park (BG1, 47 tiles, a
    15-colour palette per court) through `indexed_scene`. That function is the Player
    Select converter, now shared.
- `src/render_park.c`: the scene.
  - **OBJ:** each person is 8x16, two small objects with the player
    palette roles. The second row of `objects.png` holds the new tiles:
    person top and legs, a stepping frame, a paddle, a mini ball, and its
    shadow. OBJ tiles: 224 of 256.
  - **OBJ palettes:** 0 you (P1 blue), 1-6 the teams on court (court × 2 +
    side), 7 the objects palette.
  - **OAM:** you 0-1, court people 2-25, balls 26-28, shadows 29-31, and
    rack paddles 32-43.
  - **BG3:** the message panel (rows 1-3), the scores over the courts (row
    5), and "YOUR GAME!" (rows 11-12).
- `main.c`: `SCENE_PARK`.
  - The title opens it; PLAY starts the match.
  - B on the match result (`g_back_to_park`, set by `game.c` when
    `MatchConfig.open_play`) comes back.
  - `render_load_court` treats open play as OPPONENT_NONE for AUTO, so it
    picks the park.

## Frame budget

The first build ran the park at half speed: an 8x16 person, a ball, and a
rack paddle each cost 816-tcc about three scanlines to write. Each court's
animation also divided per frame, and every court lookup multiplied. Now:

- **Animation tables** (track and arc), and the ball's landing x once per
  rally end. Court edges come from a table, and the stack helpers walk
  pointers.
- **An OAM cache:** an object is written only when its position, tile, or
  attribute changed.
- **Staggered drawing:** each court animates on every third frame. The
  racks redraw only when a stack changes (`g_open_play.stacks`), and the
  team palettes only when someone comes on or off (`.lineup`).
- **One heavy job per frame:** new palettes, a message step (clear, the
  panel, the big text: separate frames), or a court's animation.
- **No `%`** on a changeover frame: masks and a wrap.

Result: about 88 scanlines a frame on average, at most about 207, and
`open_play.timeline` has zero overruns over 2,800 frames (`make perf`,
budget 0).

On the title, moving the cursor now repaints the new item on the press
frame and the old one on the next. The pair on one frame cost about 140
scanlines, and the eighth entry's extra Up in `venue.timeline` dropped a
frame over the singles demo.

## Tests

- `test/test_open_play.c` (host):
  - the starting park
  - fences, sliding, and facing
  - stacking, taking back, moving your paddle, and a full stack
  - your turn: stack, the call (about 20 s) against a team of that
    court's level, the call frames with input ignored, PLAY, the return,
    and the changeover
  - the levels: each team's court, the labels, and each court's
    difficulty (KID kept)
  - a 20-minute soak: about 48 games per court, each team only ever at
    its own level
  - every few frames throughout, every team in exactly one place (on a
    court or in one stack), and you in at most one stack
- `test/smoke/open_play.timeline`: in from the title, walk to court 2's
  rack, stack, and wait. It shows the court scores and the peek, "YOU'RE
  NEXT ON COURT 2", the call, and the match (MesenCE). A longer scratch run
  played the match and came back to the park.
- The court, records, venue, and lake timelines press Down once more
  (OPEN PLAY is new above COURT); venue presses Up once more.

## Not yet

- The park resets on each visit. Waiting teams are drawn only on the
  clubhouse bench (the first two); elsewhere their paddles are on the
  racks.
- No wandering people. The bigger park (`M4-OPEN-05`) is the clubhouse
  above; there are still three courts.
- 2P has no sprite of their own in the park.
