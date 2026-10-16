# Mockup Conflict Decisions

Status: **Accepted 2026-10-12**
Supersedes: parts of `01_GAMEPLAY_SPEC.md`, `02_TECHNICAL_PLAN.md`, `03_SPRITE_ASSET_PIPELINE.md`, `06_REPO_BOOTSTRAP.md`, `07_DECISIONS_AND_RISKS.md` as listed under each decision.

The concept mockups (POC serve, POC rally, doubles match point, Player Select male/female) are the visual target. This page records how each conflict between those mockups and the baseline docs was resolved. It also lists the exact amendments each affected doc needs.

## Summary

| ID | Decision | Lands in |
|---|---|---|
| ADR-010 | Palette is per-player data, decoupled from slot | POC (M2) |
| ADR-011 | Perspective court: rules in world space, rendering projects | POC (M2, before ball rendering) |
| ADR-012 | Player bodies depth-sorted in OAM each frame | Vertical slice |
| ADR-013 | Palette contract v2 with runtime palette composition | POC (before M2 art lock) |
| ADR-014 | Body variants via an 8×8 accessory object | Vertical slice |
| ADR-015 | Paddle selection with gameplay stats | Vertical slice, gated by a rules ADR |
| ADR-016 | Scenery, HUD palettes, and contact effects budget | M2–M3 as art arrives |

---

## ADR-010 — Palette decoupled from player slot

**Decision.** A player's color is a `palette_id` field chosen per match. It is not derived from slot number. Palettes are named by color: `PAL_BLUE`, `PAL_RED`, `PAL_GREEN`, `PAL_GOLD`. Each active player in a match gets a unique palette.

**POC defaults.** P1 (slot 0) uses `PAL_BLUE` and the CPU (slot 2) uses `PAL_RED`, matching the POC mockups. The defaults live in one match-config table, not in render code.

**Doubles.** Team membership comes from slot (slots 0–1 left, 2–3 right), never from color. Blue+Gold vs Red+Green, as in the doubles mockup, is a valid assignment. A team's HUD label uses the palette name of its first slot (slot 0 or slot 2).

**Why.** The player struct already carries a palette ID. Decoupling keeps every mockup valid and is what a Player Select screen needs anyway.

**Consequences.**
- HUD text colors for each team are written into BG3 palettes at match start from the assigned palettes (see ADR-016).
- Hit flash swaps the hitter's palette for one frame and restores it from the match config.

**Amendments.**
- `03_SPRITE_ASSET_PIPELINE.md`: rename `P1_BLUE/P2_RED/P3_GREEN/P4_GOLD` to `PAL_BLUE/PAL_RED/PAL_GREEN/PAL_GOLD` and add: "Palettes are assigned per match; slot number never implies color."
- `02_TECHNICAL_PLAN.md` data model: add "palette is assigned from match config; uniqueness is asserted in debug builds."

---

## ADR-011 — Perspective court with world-to-screen projection

**Decision.** All gameplay stays in the existing rectangular **world** coordinates: movement, clamps, collision, net and line calls, AI prediction, and scoring. Only presentation projects world positions into a trapezoidal screen court.

**Projection (POC values, tunable).**

```text
s(y)      = per-row horizontal scale, 8.8 fixed point, from a ROM lookup table
screen_x  = 128 + (((world_x - 128) * s(world_y)) >> 8)    // 32-bit intermediate
screen_y  = world_y                                         // no vertical foreshortening in POC
ball draw = (screen_x, screen_y - z)                        // z unscaled in POC
shadow    = (screen_x, screen_y)
```

- `s` is linear in `y`: **0.84 (216/256) at the far sideline y=90** and **1.00 (256/256) at the near sideline y=170**. Rows outside the court extrapolate linearly and clamp to s 0.75..1.10 over y 0..223. The table stores `s - 256` as 224 signed bytes (224 bytes of ROM).
- The resulting court corners are far baseline x = 34 / 223 and near baseline x = 16 / 240. The top/bottom width ratio is about 0.84, which matches the mockups. All corners sit inside an 8 px horizontal overscan margin.
- *Amended 2026-10-12:* the endpoints follow the implemented court (`include/court.h`: baselines 16/240, sidelines 90/170), which frames the court like the level-01 mockup. The game evaluates `screen_x` with the exact 16-bit expansion `d + ((d·(s−256) + 128) >> 8)`, `d = world_x − 128`. It equals the 32-bit form above, including round-half-up, and avoids 816-tcc's slow 32-bit multiply.
- The net plane x = 128 maps to screen x = 128 on every row, so the net stays a vertical divider. Baselines and kitchen lines slant toward it, as in the mockups.

**Single source of truth.** The asset generator computes the table from the court constants and emits it as `assets/generated/court_projection.h`. It then rasterizes the court lines through that same table. The game includes the generated header and never re-derives the formula. Both sides round with one shared rule: round half up after the shift.

**What does not change.** Player legal-center ranges, hit reach, net height, swept crossings, PHY/HIT/RUL scenarios, and AI all remain world-space. Every predicate and test in `05_TEST_PLAN.md` keeps its current meaning.

**Accepted side effects.**
- Pressing Up moves the player along world −y. On screen that path slants slightly toward the net. This is normal for 3/4 sports games, so input stays in world space and is not remapped to screen axes.
- Objects don't scale (no Mode 7), so players and ball stay 32×32 and 8×8 at every depth. This matches the mockups.
- Hit reach is about 16% smaller in screen pixels at the far sideline than the near one. Gameplay reach is identical.
- More unique court tiles are needed. Four slanted lines crossing about 17 tile rows each produce roughly 70–140 unique line tiles, against the 512-tile capacity of the 16 KiB BG1 budget. The asset manifest must report the actual unique-tile count.

**New checks.**

| ID | Check | Expected |
|---|---|---|
| PROJ-01 | Host: table monotonic, `s(y)` within [0.75, 1.10] | Pass |
| PROJ-02 | Host: net x = 128 maps to 128 on every row | Pass |
| PROJ-03 | Host: every projected court corner within x 8..247 | Pass |
| PROJ-04 | Host: every line pixel in exported court art equals projected constant ±0 px | Pass |
| PROJ-05 | Emulator: PHY-03 ball landing on a line draws its shadow on the painted line | Visual pass |

**Schedule.** Implement in M2 before ball and shadow rendering. M1's rectangular court art is regenerated through the projection. Any M1 checkbox about court visuals is reopened and re-verified, per the bootstrap commit rule.

**Amendments.**
- `00_PRODUCT_BRIEF.md` camera section: add "The court is drawn in fixed perspective; rules are evaluated in rectangular world space."
- `01_GAMEPLAY_SPEC.md`: retitle the coordinate table "World coordinates (rules space)". Add the projection section above, and change ball step 6 to use projected positions.
- `02_TECHNICAL_PLAN.md`: add `src/projection.c/.h` (or a header-only module over the generated table). Insert "project world positions" into frame-pipeline step 8, and add PROJ-01..05 to host checks.
- `07_DECISIONS_AND_RISKS.md`: change the "Coordinate art and rules diverge" mitigation to "Generator and game share one generated projection table; PROJ-04 enforced in `make check`."

---

## ADR-012 — Depth-sorted player bodies in OAM

**Problem found while resolving the mockups.** The fixed OAM map (bodies 2–5 = players 1–4) makes P1 draw over P2 even when P2 is nearer the camera. With only two players on opposite halves this never shows. In doubles it does: teammates share a half and overlap.

**Decision.** Each frame, sort active player bodies by screen y, nearest first, and assign them to OAM 2–5 in that order. Lower OAM index wins priority, so the nearest player draws on top. Ties break by slot number for determinism. Shadows keep fixed IDs 6–9 because they never overlap meaningfully. The ball stays at OAM 0, always on top, for the "Readable" pillar. A ball passing behind a far player still draws in front, and that is accepted.

**Cost.** A four-element insertion sort per frame.

**Amendment.** `03_SPRITE_ASSET_PIPELINE.md` OAM table: change "2–5 Player bodies 1–4" to "2–5 Player bodies, sorted nearest-first each frame."

---

## ADR-013 — Palette contract v2 and runtime palette composition

**Why it changes.** ADR-014 needs a hair color, and ADR-015 needs paddle colors independent of shirt colors (for example, a Blue player holding a red paddle). Contract v1 shares shoe and racket colors in indices 11–12 and has no hair role. `03_SPRITE_ASSET_PIPELINE.md` requires the final palette-role contract by M2, so this must land before M2 art.

**Contract v2.**

| Index | Role | Source part |
|---:|---|---|
| 0 | Transparent | — |
| 1 | Outline | Shared |
| 2–4 | Skin ramp | Skin part |
| 5–7 | Shirt/team ramp (also cap) | Team part |
| 8–9 | Shorts ramp (was 3 colors) | Team part |
| 10 | Shoe accent | Team part |
| 11–13 | Paddle face dark / face light / edge-grip | Paddle part |
| 14 | Highlight and impact-flash light (was 13 + 14) | Shared |
| 15 | Hair | Skin part |

**Runtime composition.** Each player's 16-color OBJ palette is assembled from parts at match start: shared, team, skin, and paddle. It is uploaded once during the match-setup forced blank. The POC uses one skin part and one standard paddle part per team color, so its output is identical to fixed palettes.

**Side benefit.** This closes the risk "Player palette swap reduces skin diversity." Skin becomes an independent part chosen at select.

**Amendments.**
- `03_SPRITE_ASSET_PIPELINE.md`: replace the palette contract table.
- Replace `palettes.json` with part files (`palettes/team_*.json`, `skin_*.json`, `paddle_*.json`). The build validates that every frame uses only declared v2 roles.
- `07_DECISIONS_AND_RISKS.md`: mark the skin-diversity risk as mitigated by ADR-013.

---

## ADR-014 — Body variants via accessory object

**Decision.** Male and female variants share one 32×32 body tile set. The female variant adds one 8×8 accessory object (ponytail) drawn with the owner's palette, using index 15 for hair. This is escalation step 2 in the pipeline's reuse order.

**Details.**
- OAM IDs 14–17 hold accessories 1–4. Their higher index draws them behind the bodies, which is correct for a ponytail. Hidden objects move to 18–127. (Now 22–25; see the hats amendment below.)
- `player_frames.json` gains a per-frame accessory offset and tile. Horizontal flip mirrors the offset around the body's anchor.
- Tile cost is at most 14 frames × 32 bytes = 448 bytes of OBJ VRAM.
- The variant is a per-player match-config field, independent of palette.

**Worst-row budget update.**

| Object | Count | Slivers |
|---|---:|---:|
| Players | 4 | 16 |
| Player shadows | 4 | 4 |
| Accessories | 4 | 4 |
| Ball + shadow | 2 | 2 |
| Impact reserve | 4 | 4 |
| **Total** | **18** | **30 / 34** |

Four slivers remain. The OAM stress scene adds four accessories and must stay dropout-free.

**Out of scope.** A second full body tile set. Revisit only if a distinct silhouette becomes a gameplay-readability requirement (the existing ADR-004 trigger).

**Amendments.**
- `02_TECHNICAL_PLAN.md` object budget: replace the table above and change 26 to 30 throughout.
- `03_SPRITE_ASSET_PIPELINE.md`: update the OAM table and add the accessory rule to the review checklist.
- `05_TEST_PLAN.md`: update the stress scene to 30 slivers.

**Amendment 2026-10-14: hats (M4-OPP-04).** CPU opponents can wear a hat
in place of the cap every body draws: a visor, a headband, a tricorn, a
bandana, or bare hair (`opponents.json` `hat`, `assets/manifest/player_frames.json`
`hats`).
- A hat is 16×8, two small objects in the owner's palette, on blank cells of
  `objects.png` (no new tiles: 249 of 256). It sits at the frame's accessory
  offset plus `hat_offset` (4, −4), so no new per-frame data. Flipped, it
  mirrors as 16 − x with its two halves swapped. A hat can only add pixels,
  so each one covers the cap's pixels; `tools/art/author_hats.py` refuses a
  hat that leaves any showing.
- It must draw in front of its own body, so OAM 2–13 are now a group per
  player in depth order: the hat's two halves, then the body. A hat stays
  behind nearer players. Shadows move to 14–17, effects to 18–21,
  accessories (ponytails) to 22–25, the ball machine to 26–29. A player
  without a hat parks its group's hat entries every frame (the groups follow
  the depth order).
- Only CPU opponents and an open play partner wear hats, so at most three
  are on court. The worst row is now at head height: bodies 16, hats 6,
  ponytails 4, effects 4, ball and shadow 2: **32 / 34**. Shadows sit at the
  feet, 26 px below. The stress scene draws that row and stays dropout-free.

---

## ADR-015 — Paddle selection with gameplay stats (post-POC)

**Decision.** Paddle choice affects play in the vertical slice. It must **not** enter M1–M3: the POC uses a single "standard" paddle whose stats equal today's tunables. Per `07_DECISIONS_AND_RISKS.md`, a dedicated rules ADR is required before implementation and must settle the open questions below.

**Constraints the rules ADR must respect.**
- Stats are integer modifier tables applied to baseline tunables. Simulation remains deterministic and floating-point-free.
- Every modifier is bounded to ±15% of baseline. Out-of-range values fail the build.
- Paddles are balanced by budget: each paddle's stat points sum to the same total on one shared scale. The mockup's bars currently use inconsistent maxima (6, 5, and 6 segments) and must be redrawn to one scale.
- AI prediction uses ball state after contact, so it needs no paddle knowledge. The CPU's paddle is fixed per difficulty, with no random pick.
- Paddle visuals come from ADR-013 paddle parts. Paddles carry no tile data.

**Open questions for the rules ADR.**
1. What does **SPEED** mean? Swing speed (shorter windup, which changes the 4-frame state machine) is the likely intent. Movement speed would be a character stat, not a paddle stat.
2. Does **CONTROL** widen aim lanes, tighten target error, or shrink the out-of-bounds margin of the aim targets?
3. Does **POWER** scale only horizontal speed, or also reduce flight duration?

**Player Select screen.** The vertical slice adds this screen. The large character portrait is BG artwork with its own VRAM layout loaded during forced blank; it is not an object. Thumbnails reuse the in-game frames with composed palettes.

**Amendment.** `07_DECISIONS_AND_RISKS.md` deferred rules: add "Paddle stat effects (ADR-015; rules ADR required)."

---

## ADR-016 — Scenery, HUD palettes, and contact effects

**Scenery.** Trees, fence, spectators, and sky share BG1 with the court within the BG1 character budget. The generator deduplicates tiles (including flipped matches) and the manifest reports the unique count. If scenery pushes BG1 over budget, it moves to BG2. In that case the debug landing marker moves to BG3. Spectators are static background tiles, never objects.

*Amended 2026-10-12:* the BG1 character budget is raised from 16 KiB (512 tiles) to 28 KiB (896 tiles, VRAM bytes `0x2000–0x8FFF`; see `09_M1_VRAM_AND_BUILD.md`). The mock-derived scene needs 625 unique tiles. 896 tiles is the most a single 256×224 screen can use, so BG1 cannot overflow its region. Moving scenery to BG2 would save no VRAM.

**HUD palettes (CGRAM rule).** In Mode 1, BG3's eight 2bpp palettes occupy CGRAM 0–31, which overlaps 4bpp BG palettes 0 and 1. M1 already places the court in BG palette 1 (CGRAM 16–31). Therefore:
- The HUD uses BG3 palettes 0–3 (CGRAM 0–15). Examples: title gold, team-left color, team-right color, neutral banner.
- BG1 and BG2 must never use 4bpp palette 0.
- Team HUD palettes are rewritten at match start from ADR-010 assignments.
- A host check fails the build if any BG1/BG2 tile references palette 0.

**Contact effects.** No object-based ball trail. The swing arc in the rally mockup is approximated by one impact spark object from the existing 4-object reserve, plus the player's active-hit pose. A future trail must document its own worst-row calculation; it does not fit the current budget alongside accessories.

---

## Housekeeping

- `06_REPO_BOOTSTRAP.md` repository tree: replace `product-brief.md`, `gameplay.md`, `technical.md`, `assets.md`, `testing.md` with the actual numbered names (`00_PRODUCT_BRIEF.md` … `10_MOCKUP_DECISIONS.md`), and keep `decisions/` for future standalone ADRs.
- `07_DECISIONS_AND_RISKS.md`: append ADR-010 through ADR-016 to the accepted-decisions table with a link to this page.

## Follow-up tasks

| Task | Milestone |
|---|---|
| Generator emits `court_projection.h` and rasterizes the court through it; PROJ-01..04 in `make check` | M2 (first) |
| Regenerate M1 court art; re-verify M1 court checkboxes | M2 |
| Projection applied to players, ball, shadow, debug overlays | M2 |
| Palette contract v2, part files, runtime composition | M2 (before art lock) |
| Match config with POC defaults Blue / Red; HUD team colors | M2 |
| CGRAM palette-0 host check | M2 |
| OAM depth sort | Vertical slice (before doubles) |
| Accessory object and 30-sliver stress scene | Vertical slice |
| Paddle rules ADR, then paddle stats | Vertical slice |
| Player Select screen | Vertical slice |
| Redraw mockup stat bars on one scale | Art, any time |
