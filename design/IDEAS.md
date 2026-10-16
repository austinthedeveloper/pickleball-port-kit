# Ideas

Candidate features that have not been planned yet. When one is picked up, it
gets an ADR in [decisions/](decisions/) and this entry links to it. Started
ideas and their follow-ups are tracked as tasks in
[M4 — Game Features](../milestones/04_GAME_FEATURES.md). Unbaked, just-for-fun
ideas live in [GOOFY_IDEAS.md](GOOFY_IDEAS.md).

Budget update (2026-10-16, R19): the ROM is now 1 MiB (32 banks), with about
624 KiB free; the snapshot below is from before. Budget snapshot (2026-10-15,
release build of `20d22ec`): the ROM was 512 KiB
(16 LoROM banks); about 307 KiB is used and 205 KiB free. Banks 0-7 are
full; the free space is in banks 8-13 and 15 (14-15 hold the soundbank).
`tools/build_report.py` prints the table. Per-screen limits are in
[09_M1_VRAM_AND_BUILD.md](09_M1_VRAM_AND_BUILD.md).

## Locations

**Started:** [ADR-024](decisions/ADR-024-venues.md) adds three venues (PARK,
LAKESIDE, SUNSET) built from the inspiration mocks, with shared ground
tiles, per-venue default ground colours, and home courts for opponents. The
notes below are the original idea.

A location swaps the **backdrop** (the top of the screen: sky, trees, fence,
bleachers, sign) and **recolours the ground**. The court geometry, lines, and
projection stay the same, so gameplay and collision are untouched.

How `court_scene.png` splits today:

| Part | Tile rows | Unique tiles | BG1 palettes |
|---|---|---:|---|
| Backdrop | 0–9 | 307 | 3–7 |
| Ground (court, kitchen, surround) | 10–27 | 329 | almost all 2; a few edge tiles use 4–5 |

The two parts share no tiles, so a location is:

- **Backdrop:** its own tiles (≤ 567, the 896-tile screen budget minus the
  ground) plus 320 map entries and palettes 3–7. About 10 KiB at today's
  detail.
- **Ground:** palette 2 only, 32 bytes. Same tiles, new colours (clay, blue
  hard court, green, night-lit).

That's about 10 KiB per location, so free ROM fits about 12 of them.

Constraints to resolve:

- The few ground-edge tiles on palettes 4–5 would also change colour with the
  backdrop. Either move them to palette 2 or check them against each backdrop.
- Palette 2 holds the line colours (entries 6–7, checked by the asset build).
  Any ground recolour must keep the lines readable.
- Loading happens in forced blank, the same way Player Select already swaps
  the court out and back.

Built: PARK, LAKESIDE, SUNSET (ADR-024); DINOSAUR, SPACE, UNDERSEA
(ADR-046). Starter list: Riverside Park (current), Beach Boardwalk, Indoor Rec Center,
Rooftop at Night, Pirate Dock, Gothic Courtyard, Suburban Driveway, Championship
Stadium. Each story opponent can have a home court (see below).

### Custom court colours

**Started:** [ADR-022](decisions/ADR-022-court-colors.md) adds preset
colours for the surface, surround, and lines, chosen on the title's COURT
page and saved. The notes below are the original idea.

A config screen where the player picks the ground colours (surface, kitchen,
outer area; maybe the lines), and the choice is used for later matches.

- Small: a few colour values in palette 2. SNES colours are 5 bits per channel
  (32 levels each of R, G, B), so a picker can be three sliders, or a grid of
  preset swatches, which is simpler and harder to make ugly.
- Guardrail: refuse or adjust a choice whose lines don't contrast with the
  surface, so the ball and lines stay visible.
- **Remembering it across power-off needs battery save** (below). Without it,
  the choice lasts until the console is turned off.

### Two-tone court: a separate kitchen colour

**Done:** [ADR-027](decisions/ADR-027-two-tone-kitchen.md). The notes below
are the original idea.

Real courts are usually two-toned, with the kitchen (non-volley zone) in a
colour that stands out. Today the kitchen is painted with the same palette
entry as the rest of the court (entry 4, plus 5/15 for the net shadow), so it
can't be coloured on its own.

- **Art:** `tools/art/prep_court_scene.py` paints the kitchen rectangles (net
  to the kitchen lines, `COURT_KITCHEN_LEFT_X`/`RIGHT_X` in `court.h`) with
  their own entries: kitchen, and kitchen in net shadow. The net shadow falls
  inside the kitchen, so both are needed. Palette 2 has two entries no ground
  pixel uses today (7, "line in shadow", and 12, "sand in shadow"). Entry 7
  is in the PROJ-04 line set, so take 12 and one more, or repurpose 7 and
  update `LINE_COLORS`. The kitchen boundary adds a few unique ground tiles,
  well within the 896-tile budget.
- **Colours:** a fourth court colour part, KITCHEN (ADR-022). Its presets
  include SAME (follow the surface) and contrasting tones, for example a
  lighter or darker shade of the surface, BLUE on GREEN, or GREEN on BLUE.
  Each venue's ground can set a default kitchen (`venues.json`).
- **Checks:** the line contrast check covers the kitchen too, because the
  kitchen lines and centre line border it. Adding the part changes the save's
  settings layout, which bumps `SAVE_VERSION`.
- **UI:** one more row on the COURT page (5 rows; the box has room through
  row 21).
- **Gameplay bonus:** a kitchen you can see at a glance makes kitchen faults
  easier to read.

## Story mode: CPU personalities

**Started:** [ADR-023](decisions/ADR-023-cpu-personalities.md) adds eight
opponents (looks from palette parts, play styles, a saved ladder). Story
screens (intro cards, portraits, trash talk) are not built yet. The notes
below are the original plan; the shipped ladder order and tuning are in the
ADR.

A ladder of themed opponents. Each one is **data, not new code**: a look, a
home court, and a set of play-style numbers fed into the existing CPU.

### What the CPU can vary today

These knobs already exist in [src/ai.c](../src/ai.c) as fixed constants
(ADR-019). Per-opponent values would come from a table:

| Knob | Today | Personality use |
|---|---|---|
| Dink frequency | every 4th shot | Soft-game players dink constantly; bangers never |
| Lob trigger | opponent within 44 px of the net | Lob-happy players lob from farther out |
| Put-away appetite | drive if ball ≥ 14 px high and CPU within 48 px of net | Aggressive players drive lower balls from farther back |
| Mistake rate | mistimes every 7th shot | Main difficulty dial |
| Aim pattern | away from the opponent; alternating depth | Body shots, always deep, always cross-court, random |
| Paddle stats | POWER / CONTROL / SPEED (ADR-020) | Already per-player |

New knobs worth adding: **home position** (net rusher vs baseline camper) and
**reaction delay** (frames before moving to the predicted landing spot).

### Look

Cheap: palette swaps of the shared body (palette parts, ADR-020) plus one
accessory sprite (the ponytail slot, ADR-014): hats, hair, bandanas. Plus a
select-style portrait (about 3.5 KiB each). New body animations are the
expensive option: the OBJ tile budget is 249 of 256 (hats, M4-OPP-04, reuse blank object cells).

### Roster draft

Roughly easiest to hardest. Doubles teams are marked.

| # | Opponent | Look | Style | Home court |
|---|---|---|---|---|
| 1 | **The Hendersons** (family, doubles) | Matching vacation tees, dad visor, kid cap | Parent is steady and slow; kid is fast but makes lots of mistakes. Easy warm-up. | Suburban Driveway |
| 2 | **Gym Bro Brad** | Tank top, headband | Drives everything, even low balls. High mistake rate; lob over him. | Indoor Rec Center |
| 3 | **The Snowbirds** (retirees, doubles) | White visors, pastel polos | Slow but accurate; lob specialists who punish anyone at the net. | Retirement community courts |
| 4 | **Salty Pete & Bilge** (pirates, doubles) | Tricorn hat, bandana, striped shirts | Bangers aiming at your body; rarely dink. Drives on anything above knee height. | Pirate Dock |
| 5 | **Raven** (goth) | All black, purple hair, pale palette | Soft-game master: dinks and resets, never speeds up first. Few mistakes, low power. | Gothic Courtyard (night) |
| 6 | **Kai** (surfer) | Board shorts, bleached hair | Fast and loose: chases everything, random aim, medium mistakes. | Beach Boardwalk |
| 7 | **The Twins** (doubles) | Identical outfits, mirrored palettes | Stack at the net together and poach. Tests the doubles lane logic. | Rooftop at Night |
| 8 | **The Champion** | Gold trim, sponsor patches | Mixes every shot well; lowest mistake rate. | Championship Stadium |

Other themes to keep in the pocket: ninja, wizard, robot, mime, cowboy,
food-truck chef.

### Story wrapper

- Intro card per opponent (portrait, name, one line of trash talk), then the
  match, then a win/lose card.
- Progress (which rung you've reached) needs saving: battery save (below),
  a password screen, or a short ladder played in one sitting.

## Practice mode: ball machine

**Done:** [ADR-028](decisions/ADR-028-practice.md), with the machine
sprite, its aiming nozzle, and return zones (M4-PRACTICE-02/03/04). The
notes below are the original idea.

A PRACTICE entry where the opponent is a ball machine on the far side. It
feeds balls at you one after another with no scoring, so you can drill a
shot.

- **Machine settings** (a page like OPTIONS):
  - SHOT: DRIVE, LOB, DINK, SERVE, or MIX
  - TARGET: KITCHEN, DEEP, FOREHAND, BACKHAND, at you, or RANDOM
  - SPEED: the difficulty ball speeds (ADR-025)
  - RATE: the time between feeds
- **How it works:**
  - Each feed is a `ball_launch` from the machine's spot to the chosen
    target, using the same shot paces as the players (ADR-019). It plays
    like a CPU that only serves.
  - A ball that is returned, goes out, or bounces twice ends that feed, and
    the next one comes after RATE. Rules still call your faults, but no
    points are scored.
  - Feedback shows on the HUD: returns in a row, your best streak (a new
    record for the save), and maybe a target zone to aim your return at
    (the kitchen for a dink drill).
- **Cost:** mostly logic. The machine needs one small OBJ graphic (a few
  tiles; there is room in the OBJ budget), or it can be an off-screen feeder
  with the ball appearing at the far baseline.
- **Pairs with:**
  - KID: the swing assist and slow ball make a gentle intro.
  - Two-tone court: a visible kitchen to aim dinks at.

## Open play

**Started:** [ADR-034](decisions/ADR-034-open-play.md) adds the park: three
courts with games going, paddle stacks, and your turn as a doubles match.
The original idea (from GOOFY_IDEAS.md): your player arrives at a park with
several courts and has to wait for a match to finish. You wander the
grounds, peek at other courts, and put your paddle in a court's **paddle
stack**. When your turn comes, you play. Still to come: a bigger,
scrolling park, people walking between courts, and partners from the
stack.

## Play modifiers

**Started:** [ADR-033](decisions/ADR-033-modifiers.md) adds the MODIFIERS
page with BIG BALL, FAST BALL, WIN BY 2, and a LAVA kitchen. The notes below
are the original idea.

Toggles that change the rules or physics for a match, e.g. big ball, fast
ball, wind, first to 5 or 21, rally scoring, "kitchen is lava", or
no-volley-anywhere.

- Mostly code and a few constants, so the ROM cost is small.
- Needs a modifiers menu (could live on Player Select or a new options screen)
  and room in `MatchConfig`.
- Some modifiers interact with the rules engine and its tests; each one needs a
  test case.
- Could double as story flavour: a pirate match with wind, a beach match with a
  fast ball.

## Close call replay

**Done:** [ADR-041](decisions/ADR-041-close-call-replay.md), grown up from
GOOFY_IDEAS.md. A long rally that ends just out shows a close-up of the
line during the point result: the ball dropping just past it, and by how
many inches. Still in the goofy pile: a wrong call that kisses the paint.

## The players sitting out, watching

**Done (in part):** [ADR-042](decisions/ADR-042-sitting-out.md), from
GOOFY_IDEAS.md. In a singles ladder match the opponent's doubles partner
watches from the venue's stands and cheers their teammate's points. Still
open: four humans rotating, the two waiting in the stands heckling or
throwing things.

## Battery save (SRAM)

**Started:** [ADR-021](decisions/ADR-021-battery-save.md) adds the SRAM, the
save block, and records (initials since ADR-040). The notes below are the
original idea.

Add battery-backed save RAM so the game can remember things after power-off.
Today the cart has none (ADR-017: "no SRAM").

### What it unlocks

- Story progress and unlocked opponents and courts.
- Custom court colours.
- Records: high scores, win streak vs CPU, longest rally, fastest win, and
  per-opponent wins and losses.
- Settings (default rules, modifiers, difficulty).
- Initials entry for the records, arcade style (done: ADR-040).

### Cost

- **Build:** two Makefile settings that the generated `hdr.asm` already
  supports: `CARTRIDGETYPE := 02` (ROM + RAM + battery) and `SRAMSIZE := 01`
  (2 KiB; `03` = 8 KiB). PVSnesLib has `consoleCopySram` and `consoleLoadSram`.
  2 KiB is plenty for everything above.
- **ROM space:** negligible.
- **Emulators and flash carts:** save to an `.srm` file automatically.
- **Physical carts:** need a board with an SRAM chip and a coin battery.
  That costs a little more, and the battery lasts about 10–20+ years.

### Design notes

- Start the save block with a magic value and version number, followed by a
  checksum. A blank, corrupted, or older-format save gets reset to defaults
  instead of crashing.
- Keep two copies and alternate writes, so powering off mid-save loses at most
  the last change.
- Write only at safe points (match end, leaving a menu), never during play.
- Add a "clear save data" option (e.g. hold a button combo on the title screen).
- Tests: round-trip the save struct and corrupt-checksum recovery in the host
  tests; smoke-test with Mesen's `.srm`.

## Better aiming

The D-pad both moves and aims: the shot reads the direction held at contact
(`collision_apply_targeted_shot`, `intent->aim_x`/`aim_y`). A player running
down to reach a ball is still holding down when they swing, so the ball goes
to the bottom lane. There is no time to run, then change direction.

- **Quick fix:** a direction held since before the swing counts as running,
  not aiming. Only a direction pressed in the last ~16 frames before contact
  aims; otherwise the shot takes a sensible default (away from the opponent,
  as the CPU's `away` style does). Run down, tap up, swing: the top lane.
  Mostly `input_state.c`, host-testable.
- **The real fix** is the charge stance (next entry): while a swing button is
  held, the D-pad only aims.
- **Optional:** timing aim, as in classic tennis games: an early contact
  goes cross-court, a late one down the line. Could be an OPTIONS choice.

## Charged hit

Hold a shot button to build a meter; **release** swings. Useful when the
player is already in position. Releasing too early or too late is the
player's own mistake: there is no auto-swing.

- **Stance:** while held, the player plants (or moves at swing speed,
  `g_paddle_swing_limit`) and the D-pad moves an aim marker on the far court
  instead of the player. Practice mode already draws markers of this kind.
- **Tap** (press and release in a frame or two) swings as today.
- **Pace:** a full charge adds pace through the same n/64 multipliers paddle
  POWER uses. A short charge is a normal shot.
- **Costs:**
  - A new player state in both `player.c` (host) and
    `src/asm/player_step.asm` (SNES); the golden trace compares them.
  - The doubles frame budget is tight (KNOWN_ISSUES #14, #22): `make perf`
    must stay at zero overruns.
  - The meter is a BG3 HUD bar: all eight OBJ palettes are in use in
    doubles.
- **First:** fix KNOWN_ISSUES #19 (a teammate re-hits a shot). A swing held
  open longer makes that more likely.
- **CPUs:** a `charge` style knob in `opponents.json`, later.
- **KID:** the swing assist swings for you; no charge.

## Charged serve

**Done:** [ADR-044](decisions/ADR-044-charged-serve.md) for human servers;
CPU serve power is `M4-SERVE-02`. The notes below are the original idea.

Hold during serve setup to run a meter that rises and falls (golf style);
release to toss and serve at that power.

- **Power is speed:** flight time from `SERVE_FLIGHT_FRAMES` (40) down to
  about 26 at full charge.
- **The bottom band is the net:** a low arc that meets the net. The existing
  `BALL_EVENT_NET_FAULT` and `GAME_FAULT_NET` handle it, so the rules engine
  is unchanged.
- **Aim** stays as today (D-pad at release).
- **KID:** off; today's serve.
- **CPUs:** a serve power from their personality (a risky CHAMPS, a safe
  SNOWBIRDS), with a small chance of a net serve.
- **Draw:** a BG3 bar near the server's score. The serve phase is quiet, so
  frame time is not a concern.
- Pairs with the charged hit: one meter, one look.

## Career mode

**Started:** [ADR-047](decisions/ADR-047-career.md): three slots, stats,
and cosmetic unlocks (stage 1, the data). The notes below are the original
idea.

Create a character, save their name, and play every mode as them. Stats
are kept per character, and playing unlocks cosmetics.

- **Builder:** most of it exists. Opponents already have their own skin,
  hair, shirt, and shorts colours (palette parts, ADR-013) and hats (cap,
  visor, headband, tricorn, bandana, hair; M4-OPP-04). Add skin presets
  (only `skin_light.json` today), and a builder page over the parts.
  The ponytail variant and paddle choice carry over from Player Select.
- **Name:** the initials entry (ADR-040), extended to about 8 letters.
- **Stats:** wins and losses (singles, doubles), a record against each
  ladder opponent, points won and lost, aces, kitchen faults, longest rally,
  ladder clears, open play games, practice best.
- **Unlocks:** cosmetics earned by playing: hats and colours after so many
  wins, a ladder clear, a 20-shot rally, a shutout.
- **Gear with stats:** some unlocked items change play a little, like the
  paddles do today (POWER, CONTROL, SPEED). A visor for control, shoes for
  speed. Always a trade-off, never strictly better, so looks still matter.
- **Where it plugs in:** P1 in singles, doubles, the ladder, and open play.
  Stats record at the same match-end hook as the records (ADR-021).
- **Save:** each SRAM copy can be up to 1 KiB and uses 52 bytes, so one to
  three career slots fit. A layout change with a migration (ADR-032).
- **Open questions:** how many slots; whether 2P can load a second
  character.

## Night courts

**Done:** [ADR-045](decisions/ADR-045-night-courts.md). Still open: light
poles, and a match that darkens as it goes. The notes below are the
original idea.

Play any venue at night: a **TIME** row on the COURT page (DAY, DUSK,
NIGHT), saved with the other court settings.

- **Mostly palettes:** darken and blue-shift the backdrop (BG1 palettes
  3–7) and the ground (palette 2) when the venue loads. No new tiles.
- **Lit court:** the court surface and lines stay brighter than the
  surround, as under floodlights, so the ball and lines stay readable. The
  asset build's line and ball contrast checks (CRT-02) cover each TIME.
- **Players** keep their palettes (they are lit), or take a slight tint.
- **Ambience:** crickets at night (ADR-031 already has the loop).
- **Later:** light poles as backdrop tiles; a match that starts at DUSK and
  darkens a step every few points (a palette fade between points).
- **Pairs with:** the manager idea in GOOFY_IDEAS.md (lights as an
  upgrade), and story flavour (GOTH CLUB at night).
- **Save:** one settings byte, a layout change (ADR-032).
