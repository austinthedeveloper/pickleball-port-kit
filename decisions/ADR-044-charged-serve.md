# ADR-044 — Charged Serve

Status: **Accepted 2026-10-15**
Milestone: `M4-SERVE-01`. From [IDEAS.md](../IDEAS.md), "Charged serve".
Depends on: ADR-021/025 (KID), ADR-029 (HUD prompts).

## Why

The serve was one press: the same 40-frame serve every time. A meter makes
it a small skill test with a risk: more power, or a dud into the net.

## What

- **Who:** a human server, not on KID, outside the attract demo
  (`serve_charged`). CPUs and KID serve as before, at the classic power.
- **A tap is safe:** a press serves the classic 40-frame serve, as before,
  and a press before the ready frame is still buffered to it. Only a hold
  can fail (amended 2026-10-15: at first any release at the bottom was a
  dud, so a tap was one, and an early press was dropped).
- **Hold:** from the serve's ready frame, holding B, A, or Y runs a meter
  from level 0 up to 30 and back down, one level a frame (one second up and
  down). A button held before the ready frame starts it at the ready frame.
- **Release** tosses and serves at the level shown:
  - **Before the meter reaches level 4** (a tap, or let go at once): the
    classic serve.
  - **4-30:** the flight shortens a frame for every two levels, from 40
    frames (level 4, the classic) to 27 at the top. Every level, aim, box,
    and side lands in (`test_charged_serves_land`): the fastest serve still
    clears the net.
  - **0-3 on the way back down: a dud.** The ball goes low and slow to just
    past the net (`SERVE_DUD_PAST_NET`, 30 frames) and meets the net: a NET
    fault through the existing `BALL_EVENT_NET_FAULT` path.
- **Aim** is as before: the D-pad at contact.
- **HUD:** the prompt reads `HOLD @ TO SERVE`; once the meter runs, a
  15-cell bar replaces the text, one cell for two levels. The first cell is
  white, the dud zone on the way down; the rest fill yellow. Only the
  changed cells redraw, on idle HUD frames (one tile most frames); VRAM
  follows the level one frame behind.

## State

`ServeCharge g_serve_charge` (charging, level, rising, armed, power), apart from
`ServeState`, which the golden trace captures at a fixed size.
`PlayerIntent` gains `hit_held` at the end (the assembly reads only the
fields before it).

## Bots and tests

Host tests and `make stats` bots serve P1 with a press, which is the
classic serve, so every ladder table is unchanged.

A tap after the ready frame serves one frame later than before (the release
is what tells a tap from a hold), so the golden trace differs from frame
340 and is re-recorded. The smoke timelines that serve for P1 in perf runs
(`doubles_ladder`, `modifiers`, `modifiers_doubles`) hold B for 15 frames,
so `make perf` covers the meter's drawing.

## Not yet

- CPU serve power from personality (a risky CHAMPS, a safe SNOWBIRDS).
  CPUs serve at the classic power, so a strong human serve is an edge.
- A sound for the meter's top and bottom.

## Tests

- `test_serve.c: test_charged_meter`: waits for the ready frame, rises and
  falls a level a frame, the flight table, no meter for CPU, KID, or the
  demo.
- `test_serve.c: test_charged_serves_land`: both teams, both boxes, every
  level and aim, released on the way up and on the way down: only the dud
  zone on the way down goes in the net.
- `test_serve.c: test_tap_is_classic`: an early tap is buffered and serves
  the classic serve.
- MesenCE: a tap serves in; a full charge (level 30) lands in; the bar's
  cells in VRAM follow the level.
- `make perf`: zero overruns.
