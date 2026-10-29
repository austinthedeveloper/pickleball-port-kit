# ADR-105 — Online by Room Code, Through the Relay

Status: **Accepted 2026-10-29** (asked for by the user: "yes do it on the
port", after the relay went live for the VR game's coaching).
Milestone: `PORT-112`. Builds on ADR-056 (online), ADR-103 (rollback);
the plan is `design/RELAY.md`.

## Context

ONLINE dialled the host's address over UDP (ENet, port 24994). Across
the internet that meant forwarding the port on a router or both joining
a VPN, which most friends can't do. The Web build had no ONLINE at all:
a browser can't use UDP. The relay (`../pickleball-relay`, on Azure in
East US) now pairs WebSocket connections in rooms for both games.

## Decision

**ONLINE's first row, CONNECT BY, picks the way:**

- **ROOM CODE (the default).** HOST A MATCH opens a room on the relay
  and shows it ("ROOM BXKM", on the row and in the panel). The friend
  types the ROOM (only the relay's 20 consonants are taken, four of
  them) and JOINS. It works in the Web build.
- **ADDRESS:** the ENet way, unchanged, for the same Wi-Fi or a VPN. The
  Web build stays on ROOM CODE.

The way is kept in the save (`net_way`, a new key with a harmless
default: no new save version). A room isn't kept: it's new every time.

**`RelayLink` is a NetLink** (`net/relay_link.gd`), beside `ENetLink`:
- The messages are ENet's (`var_to_bytes` Arrays) in binary frames. The
  host's carry the relay's one-byte guest number; the guest's are bare.
- The relay's JSON text frames (room, welcome, joined, left, error) set
  the link's state. Its refusals become the screen's words: NO SUCH ROOM,
  THAT ROOM IS FULL, THE OTHER PLAYER LEFT, THE ROOM CLOSED: IDLE.
  Godot can drop the text frame that comes right before a close, so the
  close's reason (the relay sends the same words) is read too.
- **It measures its own round trip:** a PING / PONG every 2 s between the
  two games, kept out of `receive()`. `Rollback.for_rtt` and
  `Lockstep.for_rtt` see the relay's line as they see ENet's.
- A host waiting for a friend tells the relay it's there every minute,
  so the room doesn't close as idle.
- The handshake, the version check, rollback, lockstep and the desync
  check are unchanged: they only see a NetLink.
- The relay's address is `RelayLink.URL`; `relay=ws://...` on the
  command line points a game at a local relay.

## Consequences

- **Anywhere, no setup:** two friends who can browse the web can play.
  From the lead's Mac, two games through East US: the room in 0.2 s,
  connected in 1.5 s, an 88 ms round trip, rollback at 2 frames of delay.
- **A server in the middle:** every input goes through East US, so a
  player's distance from it adds to the delay. Friends on the same Wi-Fi
  are better off BY ADDRESS.
- **TCP:** one lost packet holds up the ones behind it until it's sent
  again. Rollback guesses through the wait; lockstep pauses. If that's
  ever a real problem, WebRTC data channels with the relay as their
  signalling server are the next step (`design/RELAY.md`).
- **The relay sleeps when nobody plays.** The first room after a quiet
  spell waits for it to wake: 18.6 s, measured 2026-10-29 (OPENING A ROOM
  ON THE SERVER... IT CAN TAKE 20 SECONDS TO WAKE UP). `RelayLink.TIMEOUT_MS`
  waits 45 s. Keeping one server awake (`min-replicas 1`) would end the
  wait for about $15 a month: the lead's call.
- **Rooms end** after 4 hours, or 10 minutes with no messages (a match
  sends 60 a second, so only a forgotten room ends that way).
- **Cost:** the relay's one small server runs while anyone is connected;
  about 200 hours a month fit Azure's free grant (`design/RELAY.md`).
- **Tests:** `test_relay` runs two sessions through a stand-in relay
  (the room, the handshake, both measuring the line, 300 lockstep frames
  the same on both, the relay's words for leaving), and the ONLINE
  screens through the real relay server when `../pickleball-relay` and
  Node are there (skipped on CI). `test_layout` has the room's states;
  `test_online` covers CONNECT BY being kept.
