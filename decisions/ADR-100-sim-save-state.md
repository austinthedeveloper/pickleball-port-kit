# ADR-100 — The Sim's Whole State, Saved and Loaded

Status: **Accepted 2026-10-26**
Milestone: `PORT-103` (the user, preparing for online play over the
internet: "add full Sim save_state/load_state with round-trip tests, and
use it for the desync hash"). Builds on ADR-056 (online play).

## Context

Online play (ADR-056) is lockstep: only inputs travel, and the exact sim
keeps both machines the same. Its next steps all need the sim's state
itself, not just its inputs:

- **Rollback** (known issue #53): step on a guess of the other side's
  input, and when the real one differs, load the state from before it and
  step again.
- **Rejoin**, or joining a match already under way: the state is sent
  across, and the new machine carries on from it.
- **The desync check** hashed `Sim.snapshot()`, the traced state the
  golden and conformance traces compare. That leaves out a lot the sim
  carries from frame to frame: the serve charge, the wind, the ball's
  pacing, POPCORN, the ROAD TRIP perks, the AI's caches (its landing
  prediction, `block_volley`, `last_think`, `held_intent`), `loop_count`
  and `ball_steps`. A desync there went unseen until it reached a traced
  field, if it ever did.

## Decision

`Sim.save_state()` returns the sim's whole state as plain data;
`Sim.load_state(state)` puts it back, and the sim steps on exactly as the
one that saved it. `Sim.state_hash()` hashes it, and online's desync check
(`Lockstep.hash_after`) uses that instead of the snapshot. `snapshot()`
stays what the traces compare.

- **Nothing is listed by hand** (`sim/sim_state.gd`). The state is every
  script variable of the Sim and of everything it holds: players, intents,
  balls, the AI and its records and styles, practice, MULTI BALL, the
  config. A variable added to any of them is in the state with no change
  to the save code, so it can't be forgotten. The one skip is `Sim.multi`,
  a getter with no storage.
- **Objects keep their identity.** MULTI BALL's `sim.ball` *is* one of its
  entries' balls (or its idle ball), and it compares them with `==`; the
  AI's `g`, `style` and `mate` point at records it holds. Each object is
  written once (`{"@": id, "class", "fields"}`) and referred to after
  (`{"&": id}`), and loading rebuilds the same graph.
- **Loading works in place.** The Sim, its AI, practice and MULTI BALL
  are always the objects already there, and so are any players, balls or
  records whose place in the graph is unchanged, so a view holding them
  still holds the right ones. A state loads into any Sim, even one built
  for another match: the config comes with it.
- **Plain data.** Ints, bools, strings, Arrays and Dictionaries, tagged by
  class name (`SimState.CLASSES`), so `var_to_bytes` sends it over a line.
  A class not in that table is an error. `SimState.FORMAT` is 1. Both
  machines must run the same version anyway (ADR-056's HELLO), so the
  format follows the code and needs no migration.

**Cost** (one machine, doubles): a save is about 0.45 ms, a load 0.4 ms,
a hash 0.45 ms, and a state is about 15 KB as bytes. The hash runs every
120 frames. Rollback would save every frame, which still fits in a 16 ms
frame, and the save could later skip the reflection by caching each
class's getters if it needs to be faster.

## Proof

`tests/test_sim_state.gd` runs 26 matches (singles, doubles, 2P, KID,
EASY's paced ball, each modifier alone and several together, ROAD TRIP's
perks, smart play, practice). Each one saves at frames 0, 1, 37, 400 and
1500 and steps on 300 frames. Then it loads the state back into the same
sim (a rollback) and, sent as bytes, into a new singles sim (a rejoin),
and steps both again. Every frame's traced state, and the whole state
every 60 frames and at the end, must match the sim that never stopped.
Leaving out one field (tried: `loop_count`, `last_think`) fails it at
once. Further tests check that loading keeps identity (MULTI BALL's
ball, the sim's own parts and players) and that the hash sees untraced
fields. `test_online.test_a_desync_is_caught` now also catches a desync
in an untraced field and in the AI's cache, which the old hash missed.

## Not in this ADR

Rollback itself, rejoin, doubles online and play over the internet. Each
needs its own ADR. Before rollback, two more pieces of groundwork:

- Sim events need tagging by frame, so a re-simulated frame doesn't
  play its sounds again.
- The changes made to the sim outside its inputs (`retune`,
  `retune_smarts`, `new_match`) need routing through the input stream, or
  locking out when online.
