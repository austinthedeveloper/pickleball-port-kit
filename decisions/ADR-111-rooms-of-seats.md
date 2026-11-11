# ADR-111 — Doubles Online: Rooms of Seats, Drops and Rejoins, Watchers, Quick Chat

Status: **Accepted 2026-11-11** (asked for by the user: "continue with the
stories that don't need my involvement"). Milestone: `PORT-118`,
`PORT-119`, `PORT-120`, `PORT-121`, `PORT-122` (GitHub issues #7 to #11).
This ADR is PORT-118's plan, and the record of what was built.

## Decision

**A room is the host's hub (PORT-118):**
- 2 to 4 machines play, with one or two players a machine (a couch). Up
  to 4 more machines may watch.
- Every guest machine talks only to the host. The host forwards each
  guest's messages (inputs, hashes, chat) to every other machine in the
  room, so a guest hears the others one hop later. The relay needed no new
  routing: it already numbers a host's guests and tags their frames.
  RelayLink gives the host a `Port` (a NetLink) for each guest, and
  `OnlineSession` holds a `Peer` for each machine.
- ENet (by ADDRESS) stays one guest: singles. Rooms of seats are by ROOM
  CODE.

**The seats:**
- Singles is seats 0 (the host) and 2. Doubles fills 0, 2, 1, 3 as
  machines join: the first guest faces the host, and the next one is the
  host's partner.
- A couch of two takes a side's pair: 0 and 1 for the host's couch, 2 and
  3 for a guest's.
- A seat nobody took is a CPU's when the host starts.
- ROOM tells every machine who sits where, and START gives each its own
  seats.
- PLAY on ONLINE picks SINGLES, DOUBLES or DOUBLES, 2 HERE. The host can
  change it until it starts, if everyone seated still fits.

**PROTOCOL 5.**
- HELLO carries the players at a machine and whether it watches.
- New messages: ROOM, DROP, BACK, FILL, CPU, C (chat) and K (a keepalive).
- I carries its seat, and H says whose hash it is.

**Rollback with three remote streams (PORT-119):**
- Rollback keeps inputs, guesses and commands by seat, and confirms a
  frame once every human seat's input for it is in.
- A guess repeats each seat's last held state, as before. The prediction
  window and the input delay are unchanged.
- Time sync: a guest keeps time with the host, and the host with its
  slowest guest.
- The desync check hashes the whole state, as before. Each machine
  compares its own hash with every other it hears.
- Doubles always plays rollback, and so does any room with a watcher:
  lockstep has no state to hand over.
- With two seats the arithmetic is the old two-sided one. The rollback
  tests and the golden traces are unchanged.

**The relay forwards bigger rooms:**
- The host asks for its room's size (`&guests=7`: three seats and four
  watchers). A relay from before this takes one guest, so a doubles room
  on it fills at one guest.
- A big room's host may send at up to 4x the usual rate, since it speaks
  for its guests.
- RelayLink batches a poll's messages to a machine into one frame (`~B`),
  so a doubles host sends at most two frames a guest a frame at 60 Hz.
  `test_relay` plays four machines through the real relay at the game's
  pace, with no TOO FAST.
- This is pickleball-relay's `feature/cld-room-seats`. Merging it deploys
  it.

**Drops and rejoins (PORT-120):**
- A seat whose machine goes silent for 3 s mid-match, or whose line
  closes, pauses everyone. The netcode already waits for its inputs, and
  stalled machines send a keepalive so they aren't taken for dropped.
- Every machine counts down 60 s: "CY DROPPED: WAITING 45". A machine that
  only went quiet and speaks again is BACK, and nothing else happens.
- The dropped guest dials the room again (`redial`) and says which seats
  were its own. The host fills that seat's missing frames with neutral
  inputs on every machine (FILL). It then sends the rejoiner the confirmed
  state (ADR-100's save) and every input known since. The rejoiner reloads
  them into its own sims (`Rollback.restart`), runs its present up, and
  carries on.
- Past the wait, the host picks:
  - **A CPU PLAYS ON:** CPU tells every machine the frame after the seat's
    last known input, and from that frame Sim's new `seat_cpu` command
    plays it with a CPU's style. It's a command (ADR-102), so it's
    rollback-safe and in the state. It's a sim change, made only by the
    room.
  - **END THE MATCH.**
- Neither way is a record: online matches aren't recorded.
- The host leaving ends the match for everyone (the hub is gone). A
  deliberate QUIT in singles ends it too, as before. In doubles it's a
  drop with no wait.

**Watchers (PORT-121):**
- JOIN TO WATCH takes no seat and sends no inputs. Up to 4 a room.
- A watcher's rollback has no seats of its own: it only confirms, and its
  view draws the confirmed sim, a beat behind, with the announcer and the
  crowd as any match has them.
- A watcher arriving mid-match is handed the state, as a rejoin is.
- Watchers can't chat.

**Quick chat (PORT-122):**
- Eight PG lines (`OnlineSession.CHAT`), in the font's characters.
- Between points (a fault, a point's or the match's result), SHORT held
  opens the picker. HIT says a line and letting go closes it. While it's
  open, the pads don't reach the match.
- A line shows in a bubble over its player for 2.5 s.
- One line in 3 s, checked by the sender and again by the host.
- ONLINE > QUICK CHAT MUTED hides everyone's lines but your own (a
  Settings key with a harmless default).
- Chat travels beside the inputs, never in them.

## What it doesn't do

- **A host's drop:** the host is the hub, so the match ends. Handing the
  hub to a guest would need every guest's inputs on every machine, which
  is a mesh, not a star. That's a later step, if drops show up.
- **Doubles by ADDRESS:** it needs ENet to take more than one guest.
- **The partner on a couch** plays on 2P's pad (`GameControls.p2_pad`),
  and it doesn't change mid-match.

## Consequences

- Rooms of seats need the relay's PR merged. Until then the deployed relay
  takes one guest, so ONLINE plays singles and watching fills the room.
- Tests:
  - `test_doubles_online`: four machines over jittery lines, matching the
    one-machine match frame for frame; a couch of two; drop and rejoin at
    a serve, mid-rally and on the result card; a CPU taking a seat,
    matching the one-machine match with a CPU from that frame; a watcher,
    including one arriving mid-match; quick chat; and the views in a room
    (the couch's pads, the watcher drawing the confirmed sim, the sides
    named, chat bubbles and CHAT MUTED).
  - `test_relay`: four machines through the real relay at the game's pace.
  - `test_layout`: PLAY's values, a room's seats, a doubles room's match,
    a drop's lines, the host's choice, the picker and four bubbles.
  - pickleball-relay: the room size and the host's rate.
- Screenshots: `tools/online_shot.gd room|doubles|picker|drop`.
