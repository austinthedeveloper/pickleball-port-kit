# ADR-053 — The Overhead

Status: **Accepted 2026-10-18**
Milestone: `PORT-24` (Godot port only). Depends on: ADR-019 (shots),
ADR-037 (situational shots), ADR-052 (the port).

## What

A smash. The SNES game had no overhead: a high ball was hit like any
other, and only the CPU's put-away (a drive at a ball 14 px up near the
net, `ai.c`) came close. The port's sprites already had overhead frames,
which the view showed at a high ball, but the shot was the same as ever.

Now a **standard or drive swing at a falling ball 20 px up or higher**
becomes `SHOT_OVERHEAD`:

- **Fast:** pace 120 (12.4 px per frame; a drive is 60), flight 10..22
  frames (a drive's 16..30). It is hit flat or down, where a drive from
  the same spot rises.
- **Aimed** like a standard shot (deep, neutral or short by the aim),
  with a drive-sized stretch on a mis-hit (24 wide, 18 long).
- **Over the tape:** the flight lengthens a frame at a time until the
  ball crosses the net 3 px over it (`overhead_flight`, which simulates
  the flight as `simulate_step` would). If even the longest flight can't
  clear, it goes anyway and may find the net: a dumped overhead.
- **Not asked for:** no new button. The player chooses it by being under
  a high ball and swinging. SOFT at the same ball stays soft (a block or a
  reset). A rising ball, or one below 20 px, is an ordinary shot.

The CPU needs no new logic: its put-away drive at a high ball near the
net becomes a smash, and so does any of its swings at a lob it gets under.

## Why these numbers

Contact heights from 20 bot matches each (`game/tools/contact_probe.gd`):
ordinary rally contacts cluster at 12..19 px (the top of a standard
shot's arc after the bounce); everything at 20 and up was falling. With
the line at 20:

| | singles | doubles |
|---|---|---|
| shots that are smashes | 9% | 15% |
| points ended by the smash, of all smashes | 8 of 38 | 14 of 87 |
| mean rally (shots), before → after | 4.1 → 4.1 | 6.5 → 5.3 |

So singles barely changes (lobs are rarer there) and doubles gets the
put-away it lacked: a lob that doesn't clear the net player is punished.
The stats harness is unchanged: difficulty order KID..HARD 10, 6, 0, 0;
ladder first rung 8, last 0; mistimes 0 and 18, as before.

## Port and presentation

- `K.SHOT_OVERHEAD = 3` rides in the hit event's shot nibble, as the
  other shots do. The serve never smashes (it isn't a rally hit).
- The view: the overhead windup and contact frames (now also forced on
  the contact itself, whatever the windup guessed), the drive's spark, a
  5 px / 12 frame shake (the biggest), a strong rumble, SMASH! rising
  over the contact, and its own sound (`0_hit_smash*`, `make_sfx.py`: the
  hardest crack, a deeper slap, and the air tearing off the ball).
- The stats card has a SMASHES row and counts smash winners.
- Practice: the ball machine's LOB feed sets up smashes already.

## Golden traces

Regenerated: `doubles_demo` diverges at line 584, its first smash.
`singles_demo` and `bot_vs_cpu` are unchanged (no falling contact that
high in them).
