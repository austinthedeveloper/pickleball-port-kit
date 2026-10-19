# ADR-064 — The Momentum Rule

Status: **Accepted 2026-10-18**
Milestone: `PORT-40` (the *Pickleball '95* promises, bible §5.8: "the ROM
only calls the kitchen at contact"). Remaster-only.

## Decision

**MOMENTUM**, a toggle on the RULES page: after a volley, a step into your
own kitchen before the ball next bounces or is hit loses the point, called
**MOMENTUM!** (the real rule: a volley's momentum carrying you into the
non-volley zone is a fault until you've regained balance). Off, the
kitchen is called at contact only (ADR-055), as before.

- **The window** (SNES IDEAS.md's simple version): from the volley's
  contact until the ball next bounces anywhere, or anyone hits it.
- **Forgiveness:** `K.MOMENTUM_GRACE`, 2 px past the line, so a toe over
  the paint after a lunge isn't called (players run fast here).
- The emote over the loser is the anger mark, as for the kitchen.

## How

`K.MOD_MOMENTUM` (1024); `K.FAULT_MOMENTUM` (8). `Sim.momentum_slot` is
set in `contact()` when it's a volley, cleared by any bounce
(`rules_process_ball_events`), the next contact, and the point; checked in
`_update_live` beside LAVA. It joins the snapshot only when on, so the
golden traces and the conformance runs are unchanged.

The CPUs need nothing: their homes and volley positions are already behind
the kitchen (ADR-055), and in bot play none ever faults (`test_momentum`:
113 volleys, 0 faults, the Champs in doubles). The rule catches a human
who charges in.
