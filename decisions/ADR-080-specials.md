# ADR-080 — SPECIALS: a Meter and PICKLE SMASH

Status: **Accepted 2026-10-21**
Milestone: `PORT-65` (the user: "let's try a special move, whatever the
first one was that you came up with. Specials should be a togglable
feature that defaults to off ... I'd expect the Special to be controlled
by a meter or something that builds over time").
Design notes: `design/SPECIALS_AND_POWERUPS.md` (route A, the first special).

## Decision

**SPECIALS** is a new RULES row (`K.MOD_SPECIALS`), off by default and
off in `MatchConfig` (the ROM's game: the golden and conformance traces
never see it). Not in practice or MULTI BALL.

- **The meter**, one for each player (`Sim.meter`, 0 .. 96): +4 for each
  shot you hit, +8 for each point your side wins, and +1 every 40 frames
  of a live rally. A full one lasts until it's spent. A new match empties
  it. About two or three rallies fill it.
- **SPECIAL**: a new swing button (`SHOT_SPECIAL`). With a full meter, in
  a rally, it plays **PICKLE SMASH** and the contact spends the meter;
  otherwise it's a standard hit (on the serve too), so a press is never
  wasted.
- **PICKLE SMASH**: pace 128 (twice a drive's), 10 to 20 frames,
  never stretched off the sweet spot, and always over the net however low
  the ball (the overhead's net clearance, ADR-053, with a long enough
  flight). It aims itself deep, down the lane away from the other side,
  whatever was held.
- **The knock-back**: whoever returns a PICKLE SMASH has their paddle
  knocked back. The return is a soft lob to the middle, whatever they
  pressed, which sets the smasher's side up for the next shot.
- **The CPUs** (and the stats bot) play it on their next standard shot or
  drive once their meter is full.
- **Buttons**: O on the keyboard, the **right trigger** on a pad (RT, R2,
  ZR). The bible's controls are canon ("hold L or R to hit short", SNES
  ADR-056), so the shoulders stay SHORT and SPECIAL takes an input the
  SNES pad never had. It's on CONTROLS (the key, or a button as well as
  the trigger), and online carries the shot's third bit.
- **On screen** (display only, `view/special_meters.gd`): a small bar
  under each player's feet (PORT-68, below), in their colour and
  flashing gold when full, with an O / RT **PICKLE SMASH** prompt under
  the side's score panel while a human's is full. The smash plays the overhead's swing, a bigger sound
  and shake, a strong rumble, and a **PICKLE SMASH!** pop. The announcer
  always calls it.

### Amended 2026-10-22 (PORT-68): the bars under the players

The first bars sat under the score panels, as wide as the panel, so a
long team name made longer bars, and you had to look away from the court
to read yours (the user, after playing v0.27.0: put it under each
player). Each bar is now 40 x 4 px, centred under the player's feet just
below their marker, and goes where they go (all four in doubles; hidden
on the result card). Its width never depends on a name. The PICKLE SMASH
prompt stays under the score panel, where the bars were. `test_layout`
puts the players at the corners of their runoff and at the net and checks
no bar meets a text or leaves the screen.

## Measured (`tools/rally_stats.gd ... mods=131072`, 6 matches)

| | doubles | singles |
|---|---|---|
| PICKLE SMASHES | 96 | 47 |
| the smasher's side won the rally | 56% | 79% |

Mean rallies stay about where they were (doubles 13.5 against 11.9 off;
singles 8.8 against 10.9). Without the knock-back the smasher's side won
only about 1% of rallies outright in doubles: the partner covers the
open lane.

## Why

A special should feel decisive, but not be a free point, and the meter
makes it something you earn. The constants (`K.SPECIAL_*`,
`K.HIT_*_SPECIAL_*`) are the knobs for tuning after playtesting.

## Not changed

The ROM's game (SPECIALS off); the overhead smash (ADR-053); the save
layout (the new modifier bit rides on `mod_bits`, the new binding on
`bindings`, both with defaults).
