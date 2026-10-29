# The relay: online play by room code, for both games (plan)

**Status:** Planned (2026-10-28), not started. One small server on Azure
for both games:
- this port's ONLINE play (PORT-31, port ADR-056);
- the VR game's remote coaching (`../pickleball-vr`, design/COACHING.md
  C-20);
- later, VR online play.

When it's built, it becomes an ADR in each repo (port ADR-105; VR
ADR-026 or the next free one).

## Why

- **Online today needs one of two workarounds.** ONLINE dials the host's
  address over UDP (ENet, port 24994). Across the internet the host
  forwards that port on their router, or both join a VPN (Tailscale).
  Most friends can do neither.
- **The Web build has no ONLINE at all.** A browser can't use UDP.
- **The VR coach page works only on the headset's Wi-Fi**, so a coach
  can't watch from home.

A relay fixes all three. Both sides dial out to it, which every network
allows, and meet in a room by a short code: "JOIN ROOM BXKM".

## What it is

A tiny WebSocket server. It knows nothing of pickleball: it pairs
connections in rooms and passes their messages on.
- **Games:** both use WebSockets already (Godot's `WebSocketPeer`; the
  coach page). WebSockets work in a browser, so the Web build gets ONLINE.
- **Encryption:** it's served over `wss://` (TLS), so traffic is
  encrypted.

### Rooms

- **A host opens a room**, and the relay answers with a code:
  - four letters from an alphabet without look-alikes (no I, O, 0 or 1);
  - 160,000 codes, plenty for the rooms open at any one time.
- **Guests join with the code.** Each game has its own namespace (`game=`
  on the URL), so a VR code never lands in a port room. Each kind of
  room has a guest limit:

  | Game | Guests |
  |------|--------|
  | `pb94-port` (ONLINE) | 1 |
  | `pb94-vr-coach` (coach phones) | 8 |
  | `pb94-vr` (future VR online) | 3 |

- **Messages:**
  - A guest's go to the host.
  - The host's go to one guest, or to all of them.
  - Binary frames carry a one-byte header: the guest's number, or 255
    for "all".
- **Control messages** are short JSON text frames:
  `room`, `welcome`, `joined`, `left`, `error` (with a reason the game
  shows in capitals: NO SUCH ROOM, ROOM FULL, OLD VERSION).
- **When rooms end:**
  - when the host leaves, its guests are told and closed;
  - after 10 minutes with no messages;
  - at a hard cap of 4 hours.

### The protocol (v1)

```
wss://<relay>/v1/host?game=pb94-port&ver=0.43.0      -> {"op":"room","code":"BXKM"}
wss://<relay>/v1/join?game=pb94-port&code=BXKM       -> {"op":"welcome","you":0} (or error)
host gets {"op":"joined","guest":0} / {"op":"left","guest":0}
binary: [guest or 255][payload...]                   both ways, in order, nothing lost
GET https://<relay>/healthz                          -> 200 "ok"
GET https://<relay>/c/BXKM                           -> the VR coach page that room's headset sent (below)
```

- **Versions:** `ver` is the game's version. The games already refuse a
  mismatched version in their own handshake; the relay passes `ver` on
  in `joined`, so the host can say OLD VERSION before the handshake.
- **Keepalive:** a ping every 15 s keeps idle connections alive through
  Azure's ingress.

### Limits, against abuse and runaway cost

- **Message size:** 1 MiB at most (a VR voice clip is up to about
  350 KB).
- **Rate:** 200 messages a second per connection. Lockstep sends about
  60.
- **Opening rooms:** 10 a minute per IP.
- **In total:** 500 connections.
- **Nothing is stored**, and no accounts exist. Logs keep counts, never
  payloads.

## On Azure, cheaply: Container Apps

**Azure Container Apps, consumption plan, scale to zero, one replica.**
- **The free grant:** each month, every subscription gets 180,000
  vCPU-seconds, 360,000 GiB-seconds and 2 million requests free.
- **When no one plays,** the app runs on no replicas and costs nothing.
- **A session:** a replica of 0.25 vCPU and 0.5 GiB runs while
  connections are open. 100 hours of play a month is 90,000 vCPU-seconds
  and 180,000 GiB-seconds: half the grant.
- **Expected cost: $0 a month.** Even running all month, a replica would
  be about $15.
- **Rooms live in memory**, so it's held at one replica (`max-replicas 1`).
  One small replica handles hundreds of rooms: it only copies bytes.
- **Waking up takes a few seconds:** the first connection after idle
  waits for a replica to start. The games say CONNECTING TO THE SERVER...
  and wait up to 20 s.
- **Image:** a public image on GitHub's registry (ghcr.io, free), so no
  Azure Container Registry ($5 a month) is needed.
- **Logs:** the environment's logs go nowhere (`logs-destination none`),
  so there's no Log Analytics bill. Container Apps' own console log
  stream still works for debugging.
- **Address:** the app's address (`<name>.<region>.azurecontainerapps.io`)
  comes with TLS for free. A custom domain can come later.
- **Region:** the one nearest the players. Every message goes through
  it, so each player's round trip to the region adds up.

Rejected:
- **Azure Web PubSub:** the free tier allows 20,000 messages a day, which
  one lockstep match uses up in about three minutes. Standard is about
  $49 a month per unit.
- **App Service Free (F1):** a 60-CPU-minute daily quota and few
  WebSockets. Basic (B1) is about $13 a month.
- **A VM** (about $8 a month, and patching it is ours): it could relay
  UDP and keep ENet as is, but the Web build still couldn't use it.

## The server

- **Language:** Node.js with the `ws` package, about 200 lines. It's
  small, and both the lead and Azure know it well.
- **Its own repo:** `pickleball-relay`, because both games use it. It
  holds `server.js`, its tests (two fake games over a local server:
  rooms, limits, fan-out, a 1 MiB message) and a `Dockerfile`.
- **Deploying:** GitHub Actions on a push to main runs the tests, builds
  the image, pushes it to ghcr.io, and runs `az containerapp update` with
  the new image.
- **Signing in to Azure:** GitHub's OIDC, through a federated credential
  on an Azure app registration. No Azure password or secret is stored in
  GitHub.
- **Infrastructure as code:** one Bicep file (`infra/main.bicep`) holds
  the resource group's contents: the Container Apps environment (no logs)
  and the app (ingress on, WebSockets, port 8080, 0 to 1 replicas,
  0.25 vCPU and 0.5 GiB).
- **Cost alarm:** a budget of $5 a month on the resource group, with an
  email alert at 80%.

## In the games

### This port (Godot)

- **`net/relay_link.gd`:** a NetLink over `WebSocketPeer`, beside
  `ENetLink`. It sends the same `var_to_bytes` Arrays as binary frames.
  Lockstep, rollback, the handshake, the version check and the desync
  check are unchanged: they only see a NetLink.
- **ONLINE's page:**
  - HOST shows ROOM BXKM.
  - JOIN types the four letters.
  - BY ADDRESS keeps the direct ENet way for the same Wi-Fi or a VPN.
- **The Web build gets ONLINE through the relay.** The lite build's
  exclude list doesn't change.
- **The relay's address** goes in one constant (`RelayLink.URL`),
  overridable on the command line for a local relay in tests.
- **The line:** a WebSocket runs over TCP, so one lost packet holds up
  the ones after it until it's re-sent. Lockstep pauses for it (as it
  does now on a late input), and rollback guesses through it. On normal
  home internet that's rare. `Lockstep.for_rtt` measures the relay's
  round trip as it does ENet's.
- **Tests:**
  - a RelayLink against a local relay (the Node server started by the
    test, when Node is installed; skipped otherwise, like the OpenXR
    tests);
  - the existing two-session tests over it.

### The VR game: remote coaching (C-20)

- **The headset opens a `pb94-vr-coach` room** when COACH MODE is on and
  ANYWHERE is chosen.
- **It sends the relay its own coach page**, so the page always matches
  the game's version, with no second copy to deploy.
- **The coach** opens `https://<relay>/c/BXKM` from anywhere and types
  the 4-digit code as now.
- **The page knows where it came from:** served by the relay, it talks
  to the relay; served by the headset, it talks to the headset.
- **The desk is unchanged:** messages are the same JSON, so CoachDesk
  sees a coach either way.
- **A bonus: HOLD TO TALK works.** The relay's page is HTTPS, so the
  phone's microphone works, iPhones included, and PRANKS voice needs no
  SEND IT step.
- **Large messages** (voice clips, selfies) fit the 1 MiB limit.

### The VR game: online play (later)

The same rooms (`pb94-vr`, up to 4 players) once the VR game has online
play. It would follow this port's lockstep or rollback; that's its own
plan.

## Who does what

**You (once; accounts and payment are yours):**
1. An Azure subscription (pay-as-you-go; the free grant applies), and the
   region to use.
2. Sign in to the Azure CLI on this Mac (`az login`), so I can create
   the resource group, the app registration for GitHub's OIDC and the
   budget alert, each shown to you before I run it.
3. Create the `pickleball-relay` repo on GitHub (public, so its image on
   ghcr.io is free), or tell me to create it with `gh`.

**Me:**
1. The server, its tests, the Dockerfile, the Bicep file, and the deploy
   workflow in `pickleball-relay`.
2. The first deploy, then `/healthz` and a test room checked from this
   Mac.
3. **This port:** RelayLink, ONLINE's ROOM / JOIN / BY ADDRESS, the Web
   build's ONLINE, tests, and port ADR-105.
4. **VR:** ANYWHERE on the COACH page, the page sent to the relay, the
   page's relay mode, tests, and the VR ADR.
5. Docs in both repos: this sheet becomes the ADRs; the roadmaps and the
   known issues are updated.

## Known risks

- **Cold start:** the first connection after idle takes a few seconds.
  If it annoys, `min-replicas 1` keeps one warm for about $15 a month.
- **One region for everyone:** friends far from it get more delay.
  Rollback hides some of that; lockstep shows it.
- **TCP stalls on a lossy line** (above). If it's ever a real problem,
  the next step is WebRTC data channels (UDP-like, through the browser
  too), with this relay as their signalling server.
- **Abuse of an open relay:** the limits above. Nothing is stored, so the
  worst case is bandwidth, capped by the budget alert.
