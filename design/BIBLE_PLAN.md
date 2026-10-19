# The bible, and what the remaster needs from it

Source: `../pickleball/docs/PICKLEBALL_94_BIBLE.md`, **draft canon v0.3**
(2026-10-18, commit `c00c450` "LORE-01" in the SNES repo). Read
2026-10-18 against this port at v0.9.2. This file turns it into port work;
the bible stays the source of truth (its change rule: no artifact may
contradict it, and the remaster is an artifact).

## What the bible asks of the remaster

- **§1, §4:** the remaster is "faithfully remastered", **with the '95
  features finally delivered**. So it does at least everything the ROM
  does (ground rule 5: "if the box says it, the ROM does it"; the remaster
  inherits the box), plus the *Pickleball '95* promises.
- **§3:** Dale "Dink" Dawson, the cover athlete, is never in the ROM; the
  remaster adds him as an **unlockable**. (Name search required first.)
- **§5.7 / §5.8:** the overhead smash is the strongest '95 promise, using
  the frames left unused on the cart. **Delivered:** PORT-24 (our
  ADR-053) uses `overhead_windup` / `overhead_contact`. The ROM still never
  draws them, so §5.7 stays true for the ROM.
- **§2, A-11:** Tiny Chair is the remaster's studio (name search
  required): the logo is "TINY" over "CHAIR" with the I running into a
  lowercase h, cream `#F2EBDC` on navy `#1C2340`, the chair in coral
  `#E8734A`.
- **Ground rule 1:** every public release links an **"About this project"**
  note saying the 1993 history is invented. This repo and its releases
  went public on 2026-10-18 (for the updater), so this is due now.
- **Ground rule 7:** period-true words in in-universe text. The ROM
  renamed the park's courts from DUPR ratings to **ROOKIE / CLUB / CHAMP**
  (DUPR didn't exist in 1994). The remaster's own modern features (ONLINE,
  UPDATES) are 2026 and outside the rule, but text it shares with the ROM
  should match it.
- **A-10:** the remaster's patch notes: "original bugs preserved as
  toggles". An idea to build toward (a 1994 MODE), not yet designed.

## The ROM has moved on since the port

The port was copied from the SNES repo at **0.18.1** (ADR-068 in the SNES
repo). The ROM is now at **0.25.0** plus four players and pick your
partner on `main`, with **TUNING_VERSION 4**. Twenty-two SNES decisions
(SNES ADR-052 to 073) have no port counterpart. The SNES side prepared for
this: `docs/TUNING.md` (the port's catch-up steps), `docs/tuning/tuning.json`
(every sim number, versioned), and `make conformance` (frame-by-frame
traces an integer-exact port must match), proven against the ROM itself
(`make lockstep`, SNES ADR-069).

**Numbering:** the SNES repo's ADR-052 to 057 are not ours. The port's own
records ADR-052 to 057 (the Godot port, overhead, tournament, kitchen
volleys, online, updater) clash with SNES ADR-052 to 057 (kitchen fault,
fun modifiers, glow and inverse, ladder per mode, slice, CPU slice).
Decided (2026-10-18): the port keeps its numbers; the SNES repo's are
cited as **SNES ADR-n**, here and everywhere in this repo. The port's next
record is ADR-058.

### Gaps, by the bible's §5

Status: **have** (the port does it), **partly**, **missing**, **differs**
(the port does something else).

| Bible fact | SNES ADR | Port | Notes |
|---|---|---|---|
| Kitchen volley fault, the **line counts as kitchen** | 052 | **differs** | Port ADR-055 calls the line outside (an "arcade allowance"). The ROM: `COURT_IN_KITCHEN_FP` is `>=`/`<=`. Copy the ROM. |
| Charged serve: let go on the last white block and it dumps into the net | 044 | check | Port has ADR-044; check the dud block matches. |
| CPU serve power and duds (bangers serve hard, sometimes into the net) | 058 | **missing** | Sim + opponents.json. |
| Slice on **X**; **hold L or R** to hit short (L+A fast drop, L+Y dink) | 056 | **missing** | Port X is SOFT; L/R unbound in play. New shot type and input. |
| CPUs slice (Goth Club, Champs) | 057 | **missing** | |
| Ladder rebalance, every rung measurably harder | 062 + tuning v2-4 | **missing** | opponents.json differs from the ROM's in 216 lines. |
| Singles and doubles keep **separate ladder places**; quitting a ladder match resets it | 055 | **missing** | Save change (a migration). |
| Modifiers **GHOST ball, POPCORN rally, ICE footing** | 053 | **missing** | Sim (POPCORN adds ball steps; ICE is footing). |
| Modifiers **GLOW lights, INVERSE colours** | 054 | **missing** | Display (palettes); the port draws in full colour, so re-design them. |
| OPTIONS: SCORING (FIRST TO / WIN BY 2), CAMERA with AMOUNT | 065 | **partly** | Port: WIN BY 2 is a modifier; CAMERA has %. |
| Nine title entries in the ROM's order | 065 | **differs** | The port's menus are its own (modernised, ADR-052). Keep, but note it. |
| Career looks: 4 skins, **10 hair** (5 to earn), **13 hats** (11 to earn) | 059, 060 | **partly** | Port: 10 hair, **6 hats**, 9 unlocks. Needs the new hats' art. |
| The **16 unlocks** (VISOR ... CROWN, BUCKET; five hair colours) | 060 | **partly** | Port has 9. |
| Four hats trade a paddle stat (VISOR, HEADBAND, TRICORN, BANDANA) | 047 | **have** | `data/career.json` gear. |
| **Hat Museum**: X on a player's card, 4 × 3 cases, locked as silhouettes with hints | 061 | **missing** | |
| A taken shirt colour shows as a dark silhouette in Player Select | 020 | check | |
| The female player wears a ponytail | 059 | check | The port's art is its own (HD); check it has one. |
| Open play courts **ROOKIE / CLUB / CHAMP** | 070 | **differs** | Port shows `UNDER 3.5`, `3.5-4.5`, `4.5+` (view/park_view.gd). Anachronistic: rename. |
| **Park points**: 10 to start, +2 a win at your level, -1 a loss; CLUB at 15, CHAMP at 25 | 070 | **missing** | Career save field. |
| **Winners stay on**, up to two wins in a row | 071 | **missing** | open_play.c port. |
| **Pick your partner** at the rack (Y): any captain you've beaten | 072 | **missing** | Career `beaten[]`. |
| A clubhouse with the records board and a ball machine | 034 | **have** | PORT-19. |
| Four players | 073 | **have** | Port's own lobby (PORT-16), and online (PORT-31). |
| **Rings at each player's feet**: 1P red, 2P blue, 3P yellow, 4P green, CPU grey | 066 | **missing** | Display. |
| Close-call replay with inches | 041 | **have** | |
| Story cards, portraits, quips | 026, 048 | **have** | |
| **More quips** (more lines, a better pick) | 063 | **missing** | Data. |
| The captain's partner watches in singles | 042 | **have** | |
| **Celebrations** (thumbs-up, flex, en garde), slumps, diving saves, emotes (`!` `?` sweat anger star Z's), bounce dust, net shiver, squash on drives | 064 | **partly** | Port has dust and squash (Feel); the rest is missing. |
| **Critters** across the sky: a gull at Lakeside, a satellite in Space, a fish Undersea | 064 | **missing** | Display. |
| Venues, day/dusk/night, ambiences, camera and parallax | 024-051 | **have** | |
| KID swings and serves for you | 025 | **have** | |

### The '95 promises (bible §5.8) the remaster may deliver

| Promise | Port |
|---|---|
| The overhead smash | **delivered** (PORT-24) |
| Dale Dawson playable (as an unlockable) | not yet |
| Traditional side-out scoring | not yet |
| The momentum rule (carry into the kitchen after a volley) | not yet (KNOWN_ISSUES #51 says it isn't called) |
| A fifth player as line judge | not yet |
| Modifiers MOON, BOUNCY, WIND, DINK OR DIE, SUDDEN DEATH, MULTI BALL | not yet |
| A club manager mode | not yet |

Only the remaster may deliver these; they must stay out of the ROM (bible
§5.8: anything the ROM does leaves the list).

## The plan

Phase 5 in `design/PORT_ROADMAP.md`, in this order. The first is the
foundation: once the sim is integer-exact with the ROM again, the rest
copies the ROM's behaviour instead of guessing it.

| Task | What | Kind |
|---|---|---|
| PORT-35 | **Catch the sim up to the ROM** (TUNING_VERSION 4): import `tuning.json` and the three JSON sources; slice and short hold (SNES 056, 057); CPU serve power and duds (058); the ladder rebalance (062 and v2-4); ladder per mode (055); GHOST, POPCORN, ICE (053); the kitchen line (052). A conformance-trace runner in the tests (068, 069) proves it frame by frame. | Sim: golden traces regenerate, with the reason |
| PORT-36 | **About this project, and Tiny Chair**: the "About" note (title, README, every release), a Tiny Chair splash in the bible's colours (after the name search). | Presentation, docs |
| PORT-37 | **Period-true park**: ROOKIE / CLUB / CHAMP, park points, winners stay on, pick your partner (SNES 070-072). | Sim (open play), save |
| PORT-38 | **Career and the Hat Museum**: 13 hats, 16 unlocks, the museum (059-061); check the ponytail and the silhouette for a taken shirt. | Art, save, menus |
| PORT-39 | **The show**: rings at the feet (066), celebrations, slumps, emotes, net shiver, critters (064), more quips (063), GLOW and INVERSE redone for full colour (054). | Display |
| PORT-40 | **The '95 promises**: Dale Dawson as an unlockable, side-out scoring, the momentum rule, the new modifiers; one at a time, each with an ADR. | Remaster-only |

Port-only features stay (online, the updater, the tournament, the couch
cup, HOW TO PLAY, controller glyphs): they're the remaster's own, outside
the bible's 1993-95 rules. The bible could list them (a "Remaster
features" section); that's the project lead's call.
