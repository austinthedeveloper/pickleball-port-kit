# ADR-101 — Sim Events by Step: Played Once, Counted When Confirmed

Status: **Accepted 2026-10-26**
Milestone: `PORT-104` (the user: "tag sim events by frame so a
re-simulated frame doesn't replay its sounds or stats (rollback
groundwork)"). Builds on ADR-100 (the sim's whole state) and ADR-056
(online play).

## Context

Rollback runs a step on a guess of the other side's input. When the real
input differs, it loads the state from before (ADR-100) and runs the
steps again. Each run makes that step's events again: the same ones,
or others if the guess changed the outcome. The view took every event it
drained as new, and did two kinds of thing with it in one handler:

- **Show it:** sounds, sparks, dust, the crowd, rumble, quips, the HUD's
  point flash.
- **Count it:** match stats, the rally record, the career player's
  points.

Under rollback, every re-run would replay its sounds, and every guess
that was taken back would have been counted.

## Decision

- **Every event carries its step.** `Sim.step_count` counts the steps the
  sim has run and is never reset (a rematch goes on counting). `emit`
  stamps it as the event's fifth element: `[kind, x, y, detail, step]`.
  It's part of the state (ADR-100), so a step run again after a load
  gets the same stamp. All events come from `step()`, since `new_match`
  clears them. Play is unchanged: the golden traces are the same
  (`golden.gd` logs each event's first four fields, without the step).
- **`EventLedger`** (`view/event_ledger.gd`) sits between the sim and the
  view, with two outputs:
  - `run(step, events, context)` after each step returns the events to
    **play**: those not already played for that step. A step's first run
    plays everything; a re-run plays only what's new. An event played
    once for a step never plays again for it, even if a re-run drops it
    and a later one brings it back. A sound played for a guess that's
    then taken back stays played: playing on time costs that.
  - `confirm(step)` returns the events to **count**, each with the
    context recorded at its step. These are the events of each
    confirmed step's last run, oldest first, each counted once, so a
    guess that was taken back is never counted.
- **MatchView's handler is split.** `_on_event` plays (feel, flair,
  effects, sound, rumble, sparks, crowd, dinos, the watcher, quips, the
  HUD's point). `_count_event` counts (stats, `note_score`,
  `record_rally`, the career player's `record_point`). It reads the
  context of the event's step (score, rally shots, server), never the
  live sim, which may be steps further on by then. PLAY OF THE MATCH
  and the tutorial's lesson take the counted events.
- **Offline and in lockstep, a step is confirmed as soon as it runs**, so
  both come on the same frame and in the same order as before.
  Commentary stays with the played events (it's what you hear).

## Proof

`tests/test_event_ledger.gd`:

- **Ledger rules:** a re-run plays only what's new, an event a step makes
  twice plays twice, confirmation goes in order and counts each step's
  last run once, and a confirmed step can't run again.
- **Rollback:** a naive rollback over a real 2P match. Every frame it
  loads the last confirmed state and re-runs to the present, using a
  deliberately bad guess for the last 12 steps' remote input. Events
  from guesses do get taken back, and still the counted events are
  exactly the events of the same match run straight. Every real event is
  played, and none is played twice for a step.
- **Offline:** the view's stats match a bare sim's events counted as
  they come, and every step the view runs is confirmed.

## Not in this ADR

Three consumers still read the live sim when given counted events:
PLAY OF THE MATCH (`highlight.after_step` snapshots the sim and
`record()` keeps the inputs as they're stepped), the tutorial's lesson,
and the match end. That's right while a step is confirmed as it runs.
Under rollback they need the confirmed sim, or a record of their own in
the step's context, and the rollback ADR decides which. The changes made
to the sim outside its inputs (`retune`, `retune_smarts`, `new_match`)
still need routing through the inputs, or locking out when online.
