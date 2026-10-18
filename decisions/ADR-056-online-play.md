# ADR-056 — Online Play

Status: **Accepted 2026-10-18**
Milestone: `PORT-31` (Godot port only). Depends on: ADR-052 (the port),
the deterministic sim (CLAUDE.md: "the sim is pure and exact").

## What

**ONLINE** (MAIN > MULTIPLAYER > ONLINE): 1 vs 1 singles with a friend,
by address. One of you hosts; the other types the host's address and
joins. You chose (2026-10-18) direct connections over a relay server, and
singles first.

- **The line:** ENet over UDP (`net/enet_link.gd`), port **24994**, one
  peer, every message on the reliable, ordered channel. No server of
  ours: the guest dials the host. On the same Wi-Fi it just works; across
  the internet the host forwards UDP 24994 on their router, or you both
  join a free VPN (Tailscale, ZeroTier) and use its address (Tailscale's
  are 100.x.y.z). The Web build has no UDP: ONLINE says so.
- **Handshake** (`net/online_session.gd`): each side sends HELLO (the
  game's version, the protocol, the Player Select look, a career name if
  any). Different versions refuse each other. The host's START sends the
  match: the MatchConfig (singles, the host's POINTS and MODIFIERS; the
  guest in another shirt if both chose the same), the venue, time and
  court colours. The host plays slot 0 (left), the guest slot 2 (right).
- **Lockstep** (`net/lockstep.gd`): the sim is exact, so only inputs
  travel. Each side's intent for frame f + D is packed into one int and
  sent when it steps frame f; a side steps a frame only with both inputs
  for it. Frames 0..D-1 start empty. A late packet makes both wait (the
  match pauses: WAITING FOR YOUR FRIEND...); nothing is ever guessed, so
  nothing diverges. D comes from ENet's measured round trip at START
  (`Lockstep.for_rtt`: half the round trip in frames, plus 2, from 3 to
  12), so on a normal line neither side ever waits. Presses made while
  waiting are kept for the next step.
- **Desync check:** every 120 frames each side sends a hash of its sim;
  different hashes end the match (OUT OF SYNC AT FRAME n). It would be a
  bug: the tests run the same match on two sims and compare every frame.
- **In the match:** Menu never pauses (the sim's pause belongs to slot
  0): pressed twice in play, or once on the result, it leaves, and the
  other side is told (YOUR FRIEND LEFT). The host's B on the result is the
  rematch, as slot 0's always was. The HUD says YOU and the friend's name;
  the stingers, rumble and banners are this machine's player's. Nothing
  is recorded: no records, ladder or career.

## Why lockstep, not rollback

Rollback would hide the delay entirely but needs the sim saved and
re-run several frames each frame; GDScript's sim is fast, but not that
fast with four players and the AI (PORT perf gate). With D fitted to the
line, lockstep's delay is the line's own (a 60 ms round trip: 4 frames).
Rollback stays the next step if play feels laggy (KNOWN_ISSUES #53).

## Tests

`tests/test_online.gd`: packing; two sessions over a loopback line with
0, 3 and 7 (+ jitter) frames of latency, the sims compared frame by frame
over 3000 frames; a late input waits; a desync is caught; the handshake
and version check; the delay from the round trip; ENet on this machine
(connect, 600 identical frames, a QUIT); two MatchViews, host and guest,
playing a match to 3 through the views, identical, with the HUD's names
and the leave; two ONLINE screens connecting over ENet and starting; main's
MULTIPLAYER > ONLINE > BACK. `test_layout.test_online`: every screen state
and the online HUD and result.
