# ADR-103 — Rollback for Online Play

Status: **Accepted 2026-10-26** (the user approved the defaults: W = 8,
D = 1 or 2, lockstep kept a release as the fallback, the HUD's score
following the drawn sim). Stage 1 is in (`PORT-106`); the core is
`PORT-107`.
Milestone: `PORT-106` onward (the user: "plan rollback itself — give PLAY
OF THE MATCH, the lesson and the match end the confirmed sim, then the
rollback ADR"). Builds on ADR-056 (lockstep online play), ADR-100 (the
whole state), ADR-101 (events by step) and ADR-102 (commands).

## Context

Online play is lockstep (ADR-056). A frame is stepped only when both
sides' inputs for it are here, and each side's input is scheduled D
frames ahead, with D fitted to the line (3 to 12). So every press you
make takes the line's delay to show up: about 3 frames on a LAN, and
4 to 7 over the internet (known issue #53). For a reaction game with
dinks and volleys at the kitchen line, that delay is noticeable.

Rollback hides most of it. Each side steps at once, guessing the other
side's input. When the real input arrives and differs from the guess, it
goes back to the last frame both sides agree on and steps forward again
with the real one. The groundwork is in:

- the sim's whole state saves and loads exactly (ADR-100);
- events are played once and counted only when confirmed (ADR-101);
- every change to a match travels with the inputs (ADR-102).

## Decision

### Stage 1, in: the confirmed sim (`PORT-106`)

`MatchView.truth` is the sim stepped only on inputs both sides know;
`MatchView.sim` is the one drawn and heard. Offline and in lockstep
they're the same object, so nothing changes. Everything counted or
impossible to take back reads `truth`:

- the stats, the rally record and the career player's points (the
  counting path now reads `truth` itself, in place of ADR-101's
  per-step context);
- PLAY OF THE MATCH's recording (`record`, `after_step`), and the
  tutorial's lesson;
- the match end (records, the stinger) and close calls, which fire on
  `truth`'s phase changes;
- the rematch and title requests, and online's desync hash.

Commentary's phase calls stay on the drawn sim, because it's what you
hear. PLAY OF THE MATCH, lessons and the records never run online today,
so for now this is a guarantee, not a change: no future online feature
can count a guess.

`tests/test_confirmed_sim.gd` makes `truth` a second sim, as rollback
will, and shows:

- the drawn sim reaching its result records nothing, and the confirmed
  sim reaching it records the match once;
- a counted point reads the confirmed score;
- only the confirmed sim's rematch is asked for.

### Stage 2 onward

**Two sims, not a ring of saved states.** `truth` steps exactly once per
confirmed frame. `sim`, the prediction, runs ahead of it to the present.
When an input arrives that differs from what was guessed, the
prediction is reset to the confirmed sim (`load_state(truth.save_state())`)
and steps again from there to the present. That gives three things:

- truth comes for free: the desync hash, and counting that reads the
  confirmed sim's own events;
- no history of saves to keep;
- a misprediction costs one save and load plus re-running the frames
  that were guessed.

**Each frame** (`net/rollback.gd`, pure: no Nodes, no clock):

1. Read the local intent and schedule it, with any commands, for frame
   P + D, where P is the present predicted frame. Send
   `["I", frame, packed, commands?, P]`.
2. Take in what arrived. While both inputs for frame C + 1 are known,
   step `truth` with them, count its events, and C += 1. On hash
   frames, send `truth.state_hash()`.
3. If an arrived input differs from the guess made for that frame, or
   the prediction is behind `truth`, reset the prediction to `truth` and
   re-run frames C + 1 .. P. Each re-run frame's events go to
   `EventLedger.run`, which plays only what's new.
4. Step the prediction to P + 1, unless P + 1 − C > W. In that case,
   wait, as lockstep does now, and say WAITING FOR YOUR FRIEND after 20
   frames.

**Guessing.** Repeat the other side's last known held state: movement,
aim, `hit_held`, `short_held`. Never repeat a press: `hit_pressed` and
`pause_pressed` are guessed 0, since a repeated press would be a swing
they never made. Commands are guessed to be none. The host's NEW MATCH
arriving late is corrected like any other wrong guess.

**Delay and window.**

- D, the input delay, is 1 on a LAN (a round trip under 20 ms) and 2
  otherwise. It's fitted at START from ENet's round trip, as now. A
  frame or two of delay keeps corrections short.
- W, the prediction window, is 8 frames (133 ms). Past it, the game
  waits rather than guess further: a long guess means a big correction.

**Time sync.** Each input message carries the sender's present frame P.
Every 60 frames, each side compares how far ahead of the other it is.
If it's 2 or more frames further ahead than the other side is, it holds
one frame: it draws without stepping the prediction. Otherwise the side
with the faster clock, or the one that joined later, would do all the
rolling back.

**Counting and playing.**

- Counted events are `truth`'s own, drained as it steps, with `truth` as
  their context. `EventLedger.confirm` is kept only to drop old step
  records, and its counted output and context retire.
- Offline and in lockstep, the one sim's events serve both: they're
  played through the ledger, and counted as they're drained.
- Played effects can sound for a guess that's then taken back (ADR-101
  accepts that).
- The HUD's score follows the drawn sim, so a point can flash and be
  taken back. That can only happen within W frames of a rally's end.
  Accepted, for scoring that feels instant.

**Transport.** ENet's reliable, ordered channel, as now: it's simple, and
inputs are never lost. A dropped packet holds the inputs behind it for
about a round trip, and the window absorbs that. Unreliable packets
carrying the last few frames of input, with acknowledgements, come only
if playtests show stalls. `OnlineSession.PROTOCOL` becomes 3.

**Rollout.** Rollback is the default. Lockstep stays for one release as
the host's choice (`START`'s `"netcode"`, set in OPTIONS), so the two
can be compared on real lines, and then it goes. Still singles only:
doubles online is its own step. The measured costs below allow for it.

**Cost** (one machine, measured with the core in, `PORT-107`):

- a correction at its worst (save `truth`, load it into the prediction,
  re-run a full window of 8 frames) is about 1.0 ms in doubles and 0.96
  ms in singles. The save, about 0.45 ms, wasn't in the first estimate;
- `truth`'s own step is about 0.03 ms;
- a hash every 120 frames is about 0.45 ms.

The worst case is well inside a 16.6 ms frame. If it ever isn't,
`SimState` can cache each class's getters (ADR-100).

- a correction is a load (about 0.4 ms) plus up to W re-run steps (about
  0.03 ms each), so about 0.65 ms at worst;
- `truth`'s own step is about 0.03 ms;
- a hash every 120 frames is about 0.45 ms.

The worst case is well inside a 16.6 ms frame. If it ever isn't,
`SimState` can cache each class's getters (ADR-100).

**Corrections on screen.** A corrected ball or player jumps by however
far the guess was off, usually a few pixels. Smoothing it (drawing the
drawn position easing to the corrected one over about 4 frames, like
`BallGlide`) is display-only and comes last, after playtests show how
much it's needed.

## Stages (branches, chained)

1. `PORT-106` `feature/cld-confirmed-sim`: `MatchView.truth` (in).
2. `PORT-107` `feature/cld-rollback-core` (in): `net/rollback.gd`, the
   core, with `catch_up()` for waits and a match's end. Tests run two cores over the
   loopback link with 0, 3 and 7 frames of latency and jitter:
   - the confirmed sims match frame by frame;
   - the predictions match the confirmed sims once they catch up;
   - nothing waits inside the window;
   - wrong guesses happen and are corrected;
   - there's no desync, and the time sync keeps the two within 2 frames.
3. `PORT-108` `feature/cld-rollback-session` (in): the session.
   - START names the netcode (`"rollback"` or `"lockstep"`), and a START
     without one is lockstep. Under rollback the session owns the two
     sims (`OnlineSession.rollback`), and MatchView will call
     `tick(intent)`, which keeps presses from frames that couldn't step.
   - The delay comes from the round trip (`Rollback.for_rtt`), and a
     desync closes both sides. `waited()` serves either netcode.
     `PROTOCOL` is 3.
   - OPTIONS > ONLINE NETCODE (ROLLBACK or LOCKSTEP) is saved
     (`"netcode"`, a default that fills a missing key: the save stays
     v6).
   - Until the view plays rollback, `OnlineSession.VIEW_PLAYS_ROLLBACK`
     is off: the host starts lockstep and the OPTIONS row is hidden, so
     every build plays. PORT-109 turns both on.
   - Tests (`test_rollback_session`): two sessions over a jittery line
     count the same events step for step and end in the same whole
     state, over ENet on this machine too (a delay of 1); a desync
     closes them; and the fallback.
4. `PORT-109`: MatchView under rollback: `truth` and `sim` as separate
   sims, counting from `truth`'s events, playing through the ledger.
   Tests run two online views over a jittery line:
   - each event plays at most once per step and is counted exactly once;
   - the match ends once on each side;
   - the rematch works;
   - the two `truth`s match;
   - a timing check for the worst case (doubles, a full window).
5. `PORT-110`: correction smoothing (display-only, with a
   display-only proof per CLAUDE.md), then a playtest on a real line.

## Answered in review (2026-10-26)

- W = 8 and D = 1 or 2 to start, then tuned from playtests.
- Lockstep stays for one release as the host's fallback, then goes.
- The HUD's score follows the drawn sim: instant, and taken back on the
  rare correction.

## Not in this ADR

Rejoining a dropped match (ADR-100's state makes it possible), doubles
online, a relay server or NAT traversal for play over the internet
without port forwarding or a VPN, and spectators.
