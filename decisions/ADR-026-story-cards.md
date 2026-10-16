# ADR-026 — Story Cards

Status: **Accepted 2026-10-13**
Starts the story wrapper from ADR-023 (`M4-STORY-01`, `M4-STORY-02`).
Depends on: ADR-021 (save), ADR-023 (opponents), ADR-025 (options).

## Cards

There was no portrait art at first, so the cards use the HUD font over the
live court, where the opponent already stands in their own colours. The
captain's bust came later (see the amendment below).

- **Intro card:** shown when a ladder match starts from Player Select. A
  rematch or a 2P match has no card.
  - The opponent's name in big text, in the team colour. Singles shows the
    captain; doubles shows the team.
  - Their intro line in a panel, then `LADDER n OF 8`, then the prompt
    `@ PLAY`.
  - The match waits underneath: no simulation and no AI. B, A, or Start
    ends the card after half a second, and it ends by itself after 5 s. The
    frame that closes the card keeps its input from the match, because the
    serve buffers early presses and the closing B would otherwise serve.
- **Match result**, under `YOU WIN!` / `CPU WINS`:
  - The opponent's line in their colour: the taunt if they won, the
    concession if you did.
  - After a win, `NEXT UP: <team>`.
- **Ladder end:** beating CHAMPS shows `CHAMPION!` instead of `YOU WIN!`,
  then `LADDER CLEARED!`. It records a **ladder clear** (a new record,
  SaveData v5, on the records page), and the ladder starts over.

Lines live in `opponents.json` (`intro`, `taunt`, `concede`). The build
checks that each is 1–28 characters from the HUD font (capitals, digits,
space, and `.,!?'-:`), with no `@`, which draws the B button.

## Amendment 2026-10-14: the captain's bust (M4-STORY-03)

The intro card shows the opponent captain's bust between the rung and the
prompt: a 48x48 framed head and shoulders on BG2, columns 13–18, rows 16–21.

- **Art.** `assets/source/opponent_busts.png` (96x48, male and female) is cut
  from the select portraits by `tools/art/prep_opponent_busts.py`, run by
  hand. The portraits shade the face and arms with the hair role, colour
  the cap logo with the shorts roles, and the shirt's dark with a paddle
  role; the tool remaps those, so any opponent's colours read right. The
  build rejects a bust that uses roles 8, 9, 11, or 12.
- **One palette.** A match leaves one BG palette free, palette 1 (the venue
  uses 2–7, and 0 is the HUD's). So the card shows one bust, the captain's,
  in singles and doubles, in the captain's colours. The frame takes two
  roles a bust never shows: 10 (shoe) is the inner border in the HUD's
  border grey and 13 (paddle edge) a blue-grey backdrop the navy outline
  reads against.
- **VRAM.** The map is at `0x0800` and the tiles at `0x4800`, past BG1's
  896-tile reservation (docs/09). BG2's tile base steps by `0x1000` words,
  so it points at `0x4000` and the map counts from tile 128; every other
  map cell is the busts' own blank tile.
- **When.** `render_load_court` loads it in forced blank when the match
  opens on its card (a ladder match from Player Select, or the next rung);
  otherwise BG2 is off. `render_commit` turns BG2 off in the VBlank after
  the card closes, the same frame the HUD clears it. Priority puts the bust
  over the court and the players and under the HUD.

Zero overruns on every `make perf` run, and the golden trace is identical.

## Frame budget

`hud_center_prompt` drew its panel border tile by tile in C. 816-tcc spent
about 60 scanlines on a wide panel, and two panels in one frame (the intro
line plus the prompt) overran.

- `hud_panel` now fills its rows with the assembly fill (`hud_fill_box`).
  This speeds up every prompt in the game.
- The cards draw one panel per frame, using two extra HUD steps.

Results:

- Zero overruns on every timeline: golden with cards, idle, records, court,
  venue, options, the 3,000-frame soak, and **doubles**. Doubles dropped a
  frame before (`M4-UI-02`).

## Tests

- `test/test_story.c` (host):
  - the intro shows only with an opponent, and never in attract
  - B can't skip it before the minimum
  - it ends by itself
  - ladder clears are recorded and saved
  - every line fits
- `test/smoke/story.timeline`: DAD's intro card, then B dismisses it without
  serving.
- The golden timeline now opens on the intro card. Its first B press closes
  the card, and traces were re-recorded.
