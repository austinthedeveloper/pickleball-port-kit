# Test and Hardware Plan

Status: **Required for every milestone**

## Test levels

| Level | Runs when | Purpose |
|---|---|---|
| Host checks | Every change | Math, court predicates, rule transitions, asset manifests where practical |
| Fast emulator smoke | Every change | Boot, input, basic visual regression |
| Accuracy emulator | Milestone candidate | Timing, OAM, header, uninitialized-state sensitivity |
| Real hardware | M1 smoke and M3 certification | Actual console, controller, display, cartridge/flash cart behavior |

Recommended emulator roles: Mesen for debugging and bsnes/higan-class accuracy for a second opinion. Passing an emulator never replaces the hardware test.

## Debug instrumentation

The debug build exposes:

- build ID and configuration;
- game/rally state and timer;
- player positions/states;
- ball x/y/z and velocity;
- bounce counters and last hitter;
- predicted landing marker;
- hit volumes and court bounds;
- current/pressed input bits;
- Multitap detected flag;
- frame-overrun latch;
- last fault reason.

Diagnostics use BG3 or a dedicated test screen, not extra gameplay objects.

## Core deterministic scenarios

Assign each scenario a button-triggered debug setup or compile-time fixture by M3.

| ID | Setup | Expected result |
|---|---|---|
| PHY-01 | Ball crosses net one unit above threshold | Rally continues |
| PHY-02 | Ball crosses net one unit below threshold | `NET` fault |
| PHY-03 | Ball lands on line coordinate | In |
| PHY-04 | Ball lands one unit outside line | Out |
| PHY-05 | Ball reaches ground at high planar speed | Exactly one bounce event |
| HIT-01 | Active swing overlaps once for three frames | Exactly one hit |
| HIT-02 | Ball overlaps during windup | No hit |
| RUL-01 | Legal serve, return bounce, then volley | Legal rally |
| RUL-02 | Return volleyed before required bounce | Receiver loses point |
| RUL-03 | Second bounce on one side | That side loses point |
| SCR-01 | Score reaches 5 | Match result |
| RST-01 | Rematch | All state equals fresh match state |

Lines count as in. Use inclusive comparisons consistently.

## Visual/OAM stress scene

Debug scene places four 32×32 player objects, four shadows, four 8×8 accessories, ball, ball shadow, and four impact objects on overlapping scanlines. It must:

- display all planned objects without dropout;
- report the planned 32-sliver row budget (head height, ADR-014 hats amendment) in its source comment/test note;
- cycle all four player palettes;
- flip players left/right;
- animate every frame slot;
- run for five minutes without corrupt tiles or OAM.

## M1 real-hardware smoke

- ROM boots from the chosen flash cartridge or test cartridge.
- Court fills the intended safe area on a CRT or original-compatible display path.
- P1 moves in all eight directions and stops at bounds.
- Start pause/unpause works 20 consecutive times.
- Reset and power cycle both return to a valid screen.
- Build ID photographed or recorded in the test log.

## M3 certification matrix

Record exact versions and hardware revisions in `test/hardware-log.md`.

| Target | Required | Duration |
|---|---:|---:|
| Debug emulator | Yes | All deterministic scenarios |
| Accuracy emulator A | Yes | Two complete matches |
| Accuracy emulator B | Yes | Two complete matches |
| NTSC SNES/SFC + real pad | Yes | 15-minute soak and 3 matches |
| Super Multitap detection | If accessory available | Boot/detection/input screen |
| PAL console | No for POC | Deferred |

## Defect severity

- **Blocker:** fails boot, crashes, corrupts state, loses control, invalid ROM/header, hardware-only failure.
- **Major:** wrong point winner, missed/double collision, sprite dropout, sustained frame overrun, unreadable ball.
- **Minor:** animation jitter, cosmetic line mismatch under one pixel, wording/temporary-art issue.

M3 ships with zero open blockers or majors. Minor issues must be listed with reproduction steps.

## Hardware test log template

```markdown
### YYYY-MM-DD — build/version — commit
- Console/revision:
- Video path/display:
- Cartridge/flash cart + firmware:
- Controllers/accessories:
- Cold boot: PASS/FAIL
- Reset: PASS/FAIL
- Matches completed:
- Soak duration:
- Frame-overrun latch:
- Visual/input/audio notes:
- Defects filed:
- Tester:
```
