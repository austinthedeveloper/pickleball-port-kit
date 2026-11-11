# ADR-112 — Replays You Can Share, Replay Codes, 2P in the Park, Winter Crowds

Status: **Accepted 2026-11-11** (asked for by the user: "continue with the
stories that don't need my involvement", then "yes, keep going").
Milestone: `PORT-156`, `PORT-157`, `PORT-163`, `PORT-164` (GitHub issues
#46, #47, #53, #54). PORT-162 (the right team's paddle hand: every swing
pose redrawn with the paddle in the far arm) and PORT-165 (a new ROAD TRIP
region: new teams and characters, the bible's canon) need the lead's eye,
and wait.

## Decision

**A replay as a file (PORT-156):**
- A saved replay has a byte form: `PB94R1`, then the replay's dictionary
  (ADR-081's: the config and one rally's inputs), as var_to_bytes, gzipped.
  A rally is a few KB.
- REPLAYS' ON PRESS now offers WATCH, DELETE, EXPORT and SHARE.
  - **EXPORT** writes the file to the desktop's Downloads (else the game's
    exports folder). The Web build downloads it.
  - **IMPORT** (the desktop's file dialog) reads one into REPLAYS and plays
    it at once. The Web build watches codes instead.
- An import is checked before it's kept:
  - the magic and the size (36 KB at most);
  - a dictionary with the replay's keys and types, and nothing but plain
    data (no objects);
  - the sim it was recorded on. A replay plays only on its own
    TUNING_VERSION (ADR-081), so an older game's says FROM AN OLDER GAME
    and a newer game's says UPDATE TO WATCH IT.
- The imported replay plays the rally frame for frame
  (`test_export_and_import`).

**A replay as a code (PORT-157):**
- SHARE posts the same bytes to the relay's new `/v1/replay` and the row
  shows CODE BXKMQT: six letters from the rooms' alphabet, 64 million
  codes.
- WATCH CODE takes the letters a press at a time (left and right pick,
  HIT keeps), or from a keyboard. With all six, it fetches, imports and
  plays.
- The relay (pickleball-relay `replays.js`):
  - **What it keeps:** a replay's bytes and when it came, for 7 days.
  - **What it doesn't:** no names, no accounts. The sender's address is
    used for the rate limit (20 shares an hour) and is never stored with a
    replay.
  - **Limits:** 48 KB a replay as base64, and 5000 replays at most.
- Replays live in memory, and in `REPLAY_FILE` if it's set, as the boards
  do. A relay asleep forgets them, so codes are only as durable as the
  boards: the same storage question (For you).

**2P walks the park (PORT-163, KNOWN_ISSUES #41):**
- With 2P in open play, a follower in 2P's Player Select look (another
  shirt if it's yours) walks your trail 18 frames behind and stands beside
  you when you stop.
- Display only: OpenPlay's state is the same with it drawn or not
  (`test_two_p_walks_the_park`). OpenPlay still has no 2P position of its
  own (ADR-034).

**Winter crowds (PORT-164, KNOWN_ISSUES #76):**
- The crowd generator (`art/levels/tools/crowd.py`) has a season. In
  winter, the same people as the shared sheet wear puffy coats in deep
  colours, with sleeves to the wrist, mittens, scarves, long trousers,
  boots, and on most heads a knit beanie with a bobble.
- A procedural venue sets `crowd_season`, and build.py writes its own crowd
  sheet on the shared sheet's rows, so the seats still index it. GLACIER
  is winter.
- The painted venues already had their own crowds (ADR-088: SPACE's, the
  DEEP's), so "space suits and divers" were there.

## Consequences

- Replay codes need the relay's PR merged (which deploys it). Until then
  SHARE and WATCH CODE say NO CODES HERE YET, and files work anyway.
- KNOWN_ISSUES #41 is resolved. #76 keeps its half about the announcer's
  lines for the new venues.
- Tests:
  - `test_saved_replays`: export and import, the replay frame for frame;
    the refusals; the title's EXPORT and WATCH CODE; a code through the
    real relay, when its code is here (`PB94_RELAY_JS`).
  - `test_park_locations.test_two_p_walks_the_park`.
  - `test_layout`: every ON PRESS and every word a REPLAYS row can say.
- Screenshots: a GLACIER match, 2P in the park, the winter crowd sheet.
