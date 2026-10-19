# ADR-066 — Dale Dawson

Status: **Accepted 2026-10-19**
Milestone: `PORT-40` (the *Pickleball '95* promises, bible §3 and §5.8:
"Dale Dawson as a playable opponent"; "the remaster finally adds him as
an unlockable"). Remaster-only: he must never be in the ROM, or the box's
in-joke breaks.

## Decision

- **Who:** Dale "Dink" Dawson, the man on the box. A bonus opponent after
  the ladder's eight teams: red shirt, headband, a wood paddle, a
  thumbs-up when he scores, sixteen quips (one is "I WAS NEVER IN THE
  GAME.").
- **Unlocked** by clearing a ladder (singles or doubles; any save with a
  clear already has him). Then MATCH SETUP's VS row offers **DALE
  DAWSON** after the CHAMPS. His intro card reads THE COVER MATCH.
- **He plays doubles alone** (the user's call): two against one, Dale
  covering the whole court. His top speed is 30 (a human runs at 24, the
  ladder's CPUs at 16 to 22), and his AI already covers like a singles
  player when it has no partner.
- How hard: against the stats bot he wins 22-0 in singles (the Champs
  21-3) and holds the Champs' level alone in doubles (17-1; the Champs
  18-2). A boss past the ladder.

## How

- `data/dawson.json`, port-only, in `opponents.json`'s format with one
  player; `opponents.json` stays the SNES's file. `Opponents` loads him
  after the ladder as `Opponents.DAWSON` (8); `count()` stays the ladder's
  eight (the park, the career's `beaten[]`, the tournament and the ladder
  are unchanged), `exists()` and `solo()` cover him.
- `Settings.config_for`: a solo team in doubles sits its partner's slot
  out (`palette[3] = -1`), which the sim already handles.
- Ladder clears gate him (`TitleScreen.dawson_unlocked`); erased records
  lock him again.

## For the project lead

The bible marks the name [PROPOSED; name search required]: it's data in
`data/dawson.json` (and his quips), easy to change.
