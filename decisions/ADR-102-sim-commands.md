# ADR-102 — Commands: a Match's Changes Travel With Its Inputs

Status: **Accepted 2026-10-26**
Milestone: `PORT-105` (the user: "route retune/retune_smarts/new_match
through the input stream or lock them out online"). Builds on ADR-100 and
ADR-101 (rollback groundwork) and ADR-056 (online play).

## Context

Apart from the pads, the views changed a running sim in three ways,
each called between steps:

- `new_match`: the rematch (MatchView), RESTART (the pause menu), and a
  lesson's next match.
- `retune`: TUNE's BALL SPEED and CPU ERRORS sliders (ADR-074).
- `retune_smarts`: TUNE's SMART PLAY knobs (ADR-094).

None of these were in the input stream. PLAY OF THE MATCH already kept
them on the side (`Highlight.op`) so its replay could make the same
calls. Online, TUNE and RESTART weren't offered, but the rematch was: the
host's B set `rematch_requested` on both sims, and then each view called
`new_match` on its own. That was in step only because both views reacted
on the same frame. A rollback, a rejoin, or anything that let one view
react a frame later would have split the sims.

## Decision

- **A command is a change that isn't a pad's**: `["new_match"]`,
  `["retune", speed, errors]` or `["smarts", [12 ints]]`, the same
  vocabulary PLAY OF THE MATCH recorded. `Sim.step(human, commands)`
  applies them (`Sim.apply`) as the step begins, then steps. A step's
  commands are part of that step: a replay or a rollback that re-runs it
  with the same commands gets the same match.
- **The views never call the sim's mutators on a running match.**
  `MatchView.command(c)` queues a command for the next step. The
  rematch, RESTART, the lesson's next match and the tuning panel's
  sliders all go through it. MatchView passes each step's commands to
  `Highlight.op` as it steps them, and the replay steps them the same way
  (`replay.step(human, ops)`). The saved replays' format is unchanged.
  The screen starts over (fresh HUD, stats, flair, the music) when the
  NEW MATCH is *stepped*, not when it's asked for (`command(c,
  on_stepped)`). Until then the sim is still on the result screen, and
  online that's delay frames later, on the frame both machines agree on.
  The only difference you could see is that a slider's change lands on
  the next step instead of between frames. The match is waiting while
  the panel is open, so the result is the same.
- **Online, NEW MATCH is the only command, and only the host sends it.**
  It rides on the host's input message (`["I", frame, packed, commands]`)
  for frame + delay, and `Lockstep.advance` hands both sides that frame's
  commands, the lower slot's first. The guest's view marks the rematch as
  coming and waits; both sims step it on the same frame. Any other
  command online is refused (`push_error`) and never reaches the sim.
  `OnlineSession.PROTOCOL` is 2: a game without commands refuses this
  one at HELLO.
- **Locked out online:** TUNE (so its APPLY, which rebuilds the match as
  a new sim) and RESTART aren't offered there (ADR-056, ADR-074).
  `MatchView.rebuild` now refuses outright when online. `start_attract` is
  the demo's setup, not a change to a running match.
- **What stays outside the stream:** the sim's own calls (the attract
  demo's `new_match` after its result is inside `step()`), and tests and
  tools that drive a bare sim, which call the mutators directly as before.

## Proof

`tests/test_commands.gd`:

- Each command, stepped, gives the same match as the call it names,
  made just before that step.
- A step with a command, taken back (ADR-100) and run again, comes out
  the same.
- Lockstep carries both sides' commands and hands them to both on the
  same frame, in the same order.

`test_online.test_an_online_rematch_comes_through_the_stream` plays a
match to 2 between two online views and rematches through the host's
command. The two sims' whole states match at every shared frame, and a
guest's TUNE command never reaches its sim. Changing the code so the
guest starts the rematch itself fails that test. `test_tuning.test_live`
now checks that a slider's change lands on the first step after the panel.

## Not in this ADR

Rollback itself. With ADR-100, ADR-101 and this, a step is fully
described by its inputs and its commands, and its effects are played
once and counted when confirmed. What's still open is ADR-101's list:
PLAY OF THE MATCH, the lesson and the match end read the live sim.
