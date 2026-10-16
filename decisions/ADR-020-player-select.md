# ADR-020 — Player Select and Paddle Stats

Status: **Accepted 2026-10-13**
Resolves the rules ADR required by ADR-015 ("Paddle stat effects") and adds
the Player Select screen, the female body variant (ADR-014), and a second
human player.
Depends on: ADR-010 (palette per player), ADR-013 (palette parts),
ADR-014 (accessory object), ADR-015 (paddle constraints), ADR-019 (shots).

## Flow

```
Title ──Start/B──▶ Player Select (1P) ──B×3──▶ [Player Select (2P)] ──B×3──▶ Match
  ▲                     │ Y                        │ Y
  └─────────────────────┘                          └──▶ back to 1P
```

- On the title, **Start on pad 2** toggles a second human (`2P JOINED`).
  2P plays slot 2, the left player's opponent, in both modes. In doubles
  each human gets a CPU partner. Super Multitap players 3 and 4 stay deferred.
- The select screen has three rows, and the cursor starts on the top one.
  Up/Down moves between rows and Left/Right changes the value. B steps to
  the next row and confirms on the paddle row, so B alone walks a new
  player through every choice. Start confirms from any row. Y steps back up
  a row; from the top row it returns to 1P (for 2P) or the title (for 1P).
  1. **MALE / FEMALE**: the body variant.
  2. **Colour**: BLUE, RED, GREEN, GOLD. A colour that 1P already took is
     skipped for 2P, and its label reads `1P` (ADR-010: unique palettes).
  3. **Paddle**: WOOD, BLUE, RED, GOLD, with live POWER / CONTROL / SPEED bars.
- CPUs take the unused colours in order BLUE, RED, GREEN, GOLD, plus the
  standard (BLUE) paddle, so a CPU's paddle is always blue whatever its
  shirt. Slots 1 and 3 are female and slot 2 is male.
  The attract demo keeps its fixed mockup colours.

## Paddle stats (ADR-015 open questions)

Stats use a single scale of 0–5 bar segments with baseline 3. Five
segments fit beside the stat labels on one 8-px BG3 row; the mockup's
inconsistent maxima (6/5/6) are retired. Every paddle
spends the same budget of **9 points**. For each stat, k = stat − 3. Each
point is 3/64 (4.7%), so the extremes are ±14.1%, inside ADR-015's ±15%
bound. All arithmetic is integer, so the simulation stays deterministic.

| Paddle | POWER | CONTROL | SPEED | Character |
|---|---:|---:|---:|---|
| WOOD | 2 | 5 | 2 | Control |
| BLUE | 3 | 3 | 3 | Standard: today's tunables, used by the CPU |
| RED | 5 | 2 | 2 | Power |
| GOLD | 2 | 2 | 5 | Speed |

1. **POWER** scales horizontal pace by (64 + 3k)/64 on every rally shot
   (standard, drive, lob, dink). Flight time is distance / pace, so power
   also shortens the flight, but always inside that shot type's existing
   frame clamps. Serves are unchanged.
2. **CONTROL** scales the stretch spray of an off-centre contact (wide and
   long) by (64 − 3k)/64. Aim lanes and the sweet box stay the same, so
   control forgives late swings but never moves a well-timed shot.
3. **SPEED** is swing speed, not movement. Recovery after a swing is
   7 − k/2 frames (truncated: 6 at SPEED 5, 8 at SPEED 0–1). Movement
   during a swing is limited to 12 × (64 + 3k)/64 in 12.4 units. The
   4-frame windup and 3-frame active window are unchanged, so contact
   timing stays the same for every paddle.

Stats live in `assets/source/paddles.json`. The asset build generates
`paddle_stats.h` and fails if any paddle breaks the budget or any modifier
goes past ±15%. The AI needs no paddle knowledge (ADR-015): it predicts from
the ball after contact.

Paddle visuals are ADR-013 paddle parts (`paddle_wood`, `paddle_blue`,
`paddle_red`, `paddle_gold`). `MatchConfig.paddle_id` indexes the paddle
list rather than the team colours.

## Female variant (ADR-014)

The female variant adds one 8×8 ponytail object per player, using OAM
14 + slot. That OAM index is behind the bodies, as ADR-014 specifies. It
uses the owner's palette with hair at index 15, and each frame gets an
offset from `player_frames.json`. When the body is mirrored, the offset is
mirrored too. `Player.variant` holds the choice and `Player.paddle` holds
the paddle ID. Player grows from 26 to 28 bytes.

## Screen and VRAM

The screen is its own scene, loaded during forced blank behind a fade. It
reuses the BG3 font, the HUD palettes, and the OBJ tiles; the match reloads
the court the same way.

| Layer | Content | VRAM (word address) |
|---|---|---|
| BG1 | Static select art from the mockup: banner, panels, paddles, footer. Palettes 2–6. | map `0x0000`, tiles `0x1000` |
| BG2 | Large portrait (ADR-015: BG art, not OBJ), traced from the mockup into ADR-013 palette roles. It is recoloured through BG palette 7, which is composed from the same parts as the OBJ palettes. | maps `0x0800` (male), `0x0C00` (female); tiles `0x4000` |
| BG3 | Toggle text, colour labels, and stat bars | map `0x0400`, tiles `0x5000` |
| OBJ | Four colour thumbnails (in-game idle frame with composed palettes 0–3, plus ponytails) and corner-bracket cursors | `0x6000` |

The portrait switches variant by repointing BG2's map, so no VRAM upload is
needed.

## Flow details

- On the match result, B rematches with the same choices and Start
  returns to the title.
- Fades are 16 frames each way (PVSnesLib `setFadeEffectEx`, one frame
  per brightness step). Scene switches resynchronize the frame profiler,
  so fades do not count as overruns.
- The score panel shows four characters, so GREEN appears as `GRN`.

## Verification

- `test/test_select.c` covers rows, wrapping, 2P colour skipping,
  confirm and back. `test/test_match.c` covers CPU colour fill, and
  `test_collision` / `test_player` cover the paddle modifiers.
- `make smoke SMOKE=select` drives 1P through the screen into a match.
  The headless Mesen runner applies `emu.setInput` to port 1 whatever port
  is passed, so 2P joining needs a manual check with a second pad.
