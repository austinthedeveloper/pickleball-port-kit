# ADR-019 — Shot Types

Status: **Accepted 2026-10-13**
Resolves the deferred rule decision "Lob, dink, drive, charge, and
special-shot controls" (`07_DECISIONS_AND_RISKS.md`). Charge and special
shots stay deferred. Paddle stats (ADR-015) will scale these shots later.

## Controls

| Button | Shot | Flight |
|---|---|---|
| B | Standard | Deep/neutral/short target from the D-pad at contact; pace 2.5–3.0 px/frame, 24–46 frames |
| A | Drive | Same targets; pace 3.75 px/frame, 16–30 frames (flatter, faster) |
| Y | Lob | Deep target; pace 1.75 px/frame, 44–50 frames (apex ~45–58 px) |
| Y + away from the net | Dink | Lands inside the opponent's kitchen (net + 18 px); pace 1.5 px/frame |

- The shot type is latched when the swing starts (`Player.shot_type`) and
  used at contact; all three share the swing animation.
- A stretched (off-centre) contact sprays wide and long as before. For a
  drive it sprays further (26 px wide, 22 px long, against 20/16), so the
  fast shot carries more risk.
- A dink landing in the kitchen is legal on rally shots. The serve still
  faults in the kitchen.
- Serves use B, A, or Y identically (standard serve).

## CPU

Deterministic, chosen at the swing press from what it can see:

1. Put-away drive: the ball will be at least 14 px high and the CPU is
   within 48 px of the net.
2. Lob: an opponent stands within 44 px of the net.
3. Dink: every 4th shot (the former drop shot).
4. Otherwise standard, alternating deep and neutral.

The CPU's late-shot period moved from 8 to 7, keeping the balance gradient:
stand-ins mistiming every 2nd / 5th / 10th shot win 0 / 10 / 16 of 20
(`test_match_flow.c`, `make stats`).

## Presentation

The contact spark is a big burst for a drive, the small spark for lobs and
dinks, and alternates for standard shots.
