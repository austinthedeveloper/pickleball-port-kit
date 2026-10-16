# ADR-025 — Options: Points to Win and Difficulty

Status: **Accepted 2026-10-13**
Depends on: ADR-019 (shots), ADR-021 (save), ADR-023 (styles).

## Title page

**OPTIONS** is the last title entry (SINGLES, DOUBLES, COURT, RECORDS,
OPTIONS), so Up from SINGLES reaches it. It works like the COURT page:

- Up/Down picks a row and Left/Right changes it; both wrap.
- B or Start keeps the change and saves if anything changed. Y puts back the
  old values. The prompt is `@ OK  Y CANCEL`.

| Row | Values | Default |
|---|---|---|
| POINTS | 3, 5, 7, 9, 11, 15, 21 | 5 |
| DIFFICULTY | KID, EASY, MEDIUM, HARD | MEDIUM |

- Scoring stays the arcade rally scoring: first to POINTS, with no win by 2.
  `MATCH POINT` follows the setting.
- The options are kept in `SaveSettings` (SaveData v4) and copied into
  `MatchConfig` by Player Select. The attract demo always plays MEDIUM to 5.
- MEDIUM to 5 is the shipped game, and the golden trace is identical.

## Difficulty

| | Ball | CPUs you play against | Swinging |
|---|---|---|---|
| KID | 2/3 speed | Late period ÷ 3 (min 2), reaction +10, speed −4 | Automatic, plus the buttons |
| EASY | 3/4 speed | Late period ÷ 2 (min 2), reaction +5, speed −2 | Buttons |
| MEDIUM | normal | As shipped (or the ladder opponent's style) | Buttons |
| HARD | normal | Late period × 1.5 + 2 (max 30), reaction −3, speed +1 | Buttons |

- **CPUs affected:** difficulty changes the CPUs on a team with no human,
  on top of their style (ADR-023). A human's CPU partner in doubles plays as
  shipped.
- **Slow ball:**
  - The ball's physics step is skipped on some frames: every 3rd for KID,
    every 4th for EASY. The pattern repeats every 12 frames.
  - Arcs, bounces, landing spots, and rules are exactly the same; the ball
    just takes longer, and players move at full speed.
  - Slowing the shot paces instead would have raised every arc (fixed
    gravity of −3/16 px per frame²). Lobs would have gone into the HUD and
    past the CPU's 60-step prediction.
- **CPU lookahead:** its swing lookahead knows the pattern
  (`game_ball_moves_ahead`), so CPUs still time their swings on a slow ball.
  At normal speed the check is skipped entirely, because extra calls in that
  loop cost real frame time.
- **KID swing assist** (`ai_assist_swing`):
  - Each frame, the CPU's swing lookahead runs for each human. When a swing
    pressed now would meet the ball, the game presses it as a standard shot.
  - The hit area is unchanged, so the kid only has to be in the ball's path.
  - The lookahead waits for the bounce, so the assist never volleys a ball
    that must bounce first (no early-volley faults).
  - The D-pad still aims and the buttons still work (Y for a lob).
  - *Amended 2026-10-13 (M4-OPT-02):* the KID's serve also goes by itself
    after 90 frames (1.5 s, `AI_ASSIST_SERVE_FRAMES`), which leaves time to
    aim; a button serves sooner. A P1 that presses nothing still serves,
    returns, and wins (`test_options.c`).

### Measured

`make stats LATE=n DIFFICULTY=d` gives bot wins out of 30 against the
default CPU:

| Bot mistimes every | 2nd | 3rd | 5th | 8th |
|---|---:|---:|---:|---:|
| KID | 30 | 30 | 30 | 30 |
| EASY | 0 | 30 | 30 | 30 |
| MEDIUM | 0 | 0 | 15 | 22 |
| HARD | 0 | 0 | 0 | 19 |

- **KID:** a P1 that only moves, never pressing a swing button, made 92 hits
  and won 8 of 8 against the default CPU (`test_options.c`).
- **Ladder on HARD:** the bot beats DAD 2–24 of 30 depending on its skill,
  and ACE 0–5.
- **Ladder on EASY:** DAD 30 of 30; ACE 0–21.

## Frame budget

- At MEDIUM and HARD, the new code costs about one scanline (PROFILE build,
  doubles: stage maxima within 1).
- Zero overruns on the idle, records, court, venue, golden, options (KID
  match), and 3,000-frame title timelines.
- The doubles timeline was already at the edge: 223 of 225 scanlines on its
  worst frame, and `main` dropped 2 frames there. It now drops 1 (frame 361,
  scanline 226). This is tracked as `M4-UI-02`.

## Tests

- `test/test_options.c` (host):
  - values and defaults
  - the difficulty styles are ordered, and MEDIUM is unchanged
  - ball pattern counts (8 / 9 / 12 of 12)
  - the editor
  - Player Select copies the options, and the humans' CPU partner is
    unaffected
  - first to 11
  - the slow ball moves on 18 of 24 frames on EASY
  - bot wins are ordered by difficulty
  - the KID assist alone returns the ball and wins
- `test/smoke/options.timeline`: sets POINTS 7 and KID on the title, then
  plays a KID match with zero overruns.
