# ADR-028 — Practice Mode: the Ball Machine

Status: **Accepted 2026-10-13**
Depends on: ADR-019 (shot paces), ADR-020 (Player Select), ADR-021 (save),
ADR-025 (difficulty).

## Flow

Choose **PRACTICE** (the last title entry; Up from SINGLES wraps to it).

1. **The page:** sets SHOT, TARGET, and RATE, and shows the BEST STREAK. B or
   Start saves any change and continues; Y goes back.
2. **Player Select (1P):** your look and paddle (its stats apply).
3. **The session:** you alone on the left. A ball machine on the far
   baseline (x 232, centred) feeds balls from its nozzle, 8 px up. Start
   pauses, and the pause menu's MAIN MENU leaves (*amended by ADR-030*; it
   used to leave at once).

| Setting | Values | Default |
|---|---|---|
| SHOT | DRIVE, LOB, DINK, MIX | MIX |
| TARGET | KITCHEN, DEEP, FOREHAND, BACKHAND, AT YOU, RANDOM | RANDOM |
| RATE | SLOW (2 s), NORMAL (1.25 s), FAST (0.67 s) between feeds | NORMAL |
| RETURN TO | ANY, KITCHEN, DEEP, LEFT LINE, RIGHT LINE (*amended*) | ANY |

- **Speed and swinging** follow the OPTIONS difficulty: a slow ball on KID
  and EASY, and on KID the swing assist.
- **Targets:** forehand is the lower lane (facing the net, the right hand is
  +y). A DINK always lands in the kitchen. AT YOU aims where you stand,
  clamped to the court. MIX and RANDOM come from a fixed 8-bit pattern, the
  same every session.

## Rules

- There are no serves, points, or faults. Each feed is a `ball_launch` with
  the players' shot paces and flight limits (ADR-019), launched as the right
  team's shot (last hitter slot 2), so the KID assist treats it as incoming.
- **A return counts** when its first bounce is in on the machine's side.
- **A miss resets the streak:** a return into the net, out, or on your own
  side; a feed you let bounce twice; or a feed that runs 5 s without ending.
- **On screen:** the score panels read `P1 <streak>`, `PRACTICE`, and
  `BEST <best>` (up to 99), with a `START  MENU` banner. A spark marks
  each feed. Each feed also emits a HIT event, so it will sound once audio
  exists (`M4-AUDIO-01`); the game has no sound yet (ADR-009).
- **The machine** (`M4-PRACTICE-02`) is a 16 × 16 sprite: a grey body with a
  hopper of yellow balls, a nozzle facing P1, and wheels.
  - It is four 8 × 8 tiles in the small-object sheet (slots 7–10) and four
    OAM entries (18–21). The objects palette gains three greys (entries
    7–9). The OBJ tile count is unchanged (208).
  - Feeds leave the nozzle, so the launch height is 8 px. A flat drive from
    there can't clear the net and still land in the kitchen, so a DRIVE to
    the kitchen is fed as a firm standard shot. The every-shot × every-target
    landing test covers this.
- **Aiming** (*amended 2026-10-14*): the nozzle used to face P1 whatever the
  lane, so a feed's direction was a guess. Now each feed is planned when
  the wait before it starts (`practice_plan`), and the nozzle turns toward
  its lane: **up** (a lane more than 12 px toward the far sideline),
  **centre**, or **down**.
  - It turns one pose every 6 frames, so up to down passes the centre. The
    machine feeds only once it points at the lane, which costs no time
    except on AT YOU, which follows P1 through the wait and locks when the
    wait ends.
  - Each pose has its own left-half tiles (slots 28-31 of the small-object
    sheet for up and down, after the hats; the OBJ tile count is unchanged). A feed leaves
    that pose's muzzle (4 px toward the far sideline for up, 3 px toward
    the near one for down), and the machine kicks back 2 px, then 1, over
    6 frames.
  - MIX and RANDOM draw from the pattern in the same order as before, so
    the same feeds come in the same order.
  - Not shown: depth (KITCHEN or DEEP) and the shot. The ball's flight
    shows those.
- **Saving:** the best streak is saved when you leave, as
  `practice_best`. The settings are kept in `SaveSettings.practice`
  (SaveData v7; the fourth, RETURN TO, since v9).

## Return zones

*Amended 2026-10-14 (M4-PRACTICE-03).* RETURN TO picks a zone on the
machine's side that a return must land in to count:

| Zone | Ground rectangle (edges in) |
|---|---|
| ANY | the machine's side: the plain streak, as before |
| KITCHEN | net to the kitchen line (x 128-164) |
| DEEP | the last 36 px before the baseline (x 204-240) |
| LEFT LINE | P1's left, facing the net: 22 px in from the far sideline (y 90-112) |
| RIGHT LINE | P1's right: 22 px in from the near sideline (y 148-170) |

- A return whose first bounce is in the zone (and in the court) adds to the
  streak. Anywhere else resets it, even in the court: the drill is the
  placement.
- **Each zone has its own best**, saved on leaving as
  `SaveRecords.practice_zone_best[4]` (u8, up to 99), apart from ANY's
  `practice_best`. The practice page's BEST STREAK shows the chosen zone's
  best and changes with RETURN TO. The RECORDS erase clears them too.
- **On screen:** a corner object at each corner of the zone (the select
  cursor's corner, flipped, in the objects palette; OAM 34-37), placed
  through the court projection. The corners blink for 32 frames after a
  return lands in. The centre score panel names the zone (PRACTICE on
  ANY), and BEST is that zone's best.
- **Save layout 10** (ADR-032): `practice[4]` takes the place of
  `SaveSettingsV8.reserved`, and the records gain the four bests (52 bytes,
  with ADR-040's initials). Layout 9 (v0.13.0, the initials) went out
  first, so this one is 10. A v8 save (v0.6.0 to v0.12.0) or a v9 save
  (v0.13.0, its initials kept) carries everything over, with RETURN TO at
  ANY and the zone bests at 0.
- **Merged after v0.13.0:** the machine's up and down poses moved to
  small-object cells 28-31 (the hats took 22-27) and the zone corners to
  OAM 34-37 (after the close call and the watcher). Leaving practice for
  the park sets the title demo up as the park loads, in forced blank: on
  the pause frame, with the session's save, it went over the frame budget
  (`clubhouse.timeline`).

## Code

- `src/practice.c`: settings, the page editor, feeds, and streaks.
- `game.c`:
  - starts a session instead of a serve
  - runs `practice_update` instead of the phase logic
  - `game_step_ball` (the slow-ball step) and `game_contact` (contact
    effects) are shared with matches
  - Start leaves practice
- `match_config_practice`: singles with slot 2 inactive and no opponent.
- The HUD has its own practice key (`0x400`, clear of the title's bit 8).

## Tests

- `test/test_practice.c`:
  - settings and the editor
  - **every shot to every target, 6 feeds each:** the feed clears the net,
    first bounces in on P1's side (in the kitchen for KITCHEN and DINK, deep
    for DEEP), and an unreturned feed ends with the streak at 0
  - the bot builds a streak of 8 on MIX/RANDOM; a KID-assist-only P1 builds
    32 on DINK/KITCHEN
  - the best is saved on leaving and never lowered
  - Start returns to the title
- `test_practice.c: test_machine_aim`: the nozzle turns one pose at a time,
  points at each feed's lane when it leaves (all three poses seen over 30
  RANDOM feeds), and follows P1 on AT YOU.
- `test/smoke/machine.timeline`: centre, up, the feed's kick, and a turn
  through the centre to down.
- `test_practice.c: test_zones`: for each zone, two returns into it make a
  streak of 2 (the corners blink on a zone), one outside resets it, and
  the best is saved for that zone only. `test_save.c: test_migrate_v8`.
- `test/smoke/zones.timeline`: RETURN TO KITCHEN on the page, then the
  session with the kitchen's corners and KITCHEN on the centre panel.
- `test/smoke/practice.timeline`: the page, Player Select, a session with a
  forehand return, and Start back to the title.

## Found while testing

The **doubles attract demo** drops about 1 frame in 40. It was already true
in v0.4.0, but the soaks never reached it: the singles demo fills the first
~4,300 frames. It averages about 197 of 225 scanlines a frame (four AI
players, four bodies, and the title). Human doubles matches run one fewer AI
and have zero drops. This is logged as `M4-UI-03`.
