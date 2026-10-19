# Pickleball '94 port kit

> **About this project:** the game is real; its 1993 history is invented.
> See [ABOUT.md](ABOUT.md).

Starting material for a modern version of Pickleball '94 (Godot, Unity, or
browser TypeScript). Copied from the SNES repo at commit `a7e6a90`
(release v0.18.1, 2026-10-16). These are copies, not links: the SNES repo
remains the source of truth for the SNES game, and this folder can become
the new repo (`git init` here).

## The Godot port

`game/` is the modern port (Godot 4.7, 960×540): the SNES sim ported
integer-exact, with headless tests, golden traces, and a stats harness.
Start with `game/README.md`, `CLAUDE.md`, and `decisions/ADR-052-godot-port.md`.

## Read first

1. `design/NEXT_GAME_PLAYBOOK.md`: lessons and build order. Rule 1 is to
   build a deterministic sim, a golden trace, and a bot harness in week one.
2. `design/00_PRODUCT_BRIEF.md` and `design/01_GAMEPLAY_SPEC.md`: what the
   game is.
3. `design/PLAYER_GUIDE.md`: what shipped, from the player's side.
4. `design/07_DECISIONS_AND_RISKS.md` (index of ADR-001 to 017, details in
   `design/10_MOCKUP_DECISIONS.md`) and `decisions/` (ADR-018 to 051): why
   each feature works the way it does.

## What's here

| Folder | Contents | Use in the port |
|---|---|---|
| `design/` | Brief, gameplay spec, test plan and scenario map, playbook, player guide, manual draft, ideas, known issues, mockup decisions, refactor plan, Multitap plan | Spec and backlog. `05_TEST_PLAN.md` and `SCENARIOS.md` list the rule tests to re-create. `MANUAL.md` describes four players as if shipped (planned, not in the SNES build). |
| `decisions/` | ADR-018 to 051 (earlier ones are in `design/`) | Precedent. Gameplay, AI, save, and UI decisions carry over; the frame-budget and VRAM parts don't. |
| `data/` | `opponents.json` (CPU styles and ladder), `career.json`, `venues.json`, `quips.json`, `paddles.json`, `court_colors.json`, `palettes/`, `player_frames.json` (animation frames), `m1-assets.json` | Load directly, or convert. Colours are 5-bit SNES RGB (multiply by 255/31). The per-field notes are in each file's `comment`. |
| `art/concept/` | Concept art: box art, venue courts, levels, player select (high-res) | Style targets for new art. |
| `art/snes-pixel/` | The SNES source sheets: players, objects, venues, portraits, busts | Pixel reference, or a retro skin. |
| `audio/snes-sfx/` | The SNES sound effects and venue ambience as WAV | Placeholder audio. |
| `baselines/` | AI ladder tables (`make stats LATE=0 MATCHES=20 OPPONENT=-2 DIFFICULTY=2`, `MODE` 0 singles, 1 and 3 doubles) | The port's ladder should rank the eight opponents in the same order. |
| `reference/snes-src/` | The C simulation, headers, host tests, `match_stats.c`, `court_projection.py` | The exact rules and numbers. Read it, don't port its style. |

## Reading the SNES numbers

- **Units:** world coordinates are SNES screen pixels on a 256×224 screen.
  The court runs x 16..240 (net at 128, kitchen lines at 92 and 164) and
  y 90..170 (`include/court.h`). Scale everything uniformly.
- **Fixed point:** `fx` is 12.4, so positions and velocities are in 1/16
  pixel. Gravity is -3/16 px per frame² (`include/ball.h`).
- **Time:** 60 fixed steps per second. CPU decisions run on a staggered
  schedule, not every frame (ADR-043). Tune the port's AI on the schedule
  it ships with.
- **Depth:** the 3/4 view is a projection used for display only (ADR-011).
  Rules, physics, and AI run on the flat court. Keep that split.
- **SNES-only code:** anything about 816-tcc, multiplies, pointer
  scratch copies, `src/asm/` (not copied), OBJ palettes, BG3 HUD staging,
  and SRAM. The ideas behind them (frame budget, save migration, staged
  UI) are in the playbook.

## Not included

ROMs and build output; the SNES toolchain, Makefile, and asset generators;
MesenCE smoke timelines and the golden trace (they depend on the emulator);
`docs/02_TECHNICAL_PLAN.md`, `03`, `06`, `08`, `09`, and `RELEASING.md`
(SNES build and tooling). They're all in the SNES repo if needed.

## License

MIT (`LICENSE`), same as the SNES game.
