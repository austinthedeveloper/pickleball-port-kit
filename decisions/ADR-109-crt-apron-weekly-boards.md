# ADR-109 — CRT, the Lit Apron, the WEEKLY CHALLENGE and Score Boards

Status: **Accepted 2026-11-11** (asked for by the user: "add port-131,
161, 159, 158"). Milestone: `PORT-131`, `PORT-161`, `PORT-159`,
`PORT-158` (GitHub issues #21, #51, #49, #48). The boards' server side
is in pickleball-relay (`boards.js`), on its own branch and PR.

## Decision

**CRT (PORT-131):** OPTIONS > CRT OFF (the default), SOFT or STRONG: a
filter over the whole picture (`view/crt.gdshader`), with scanlines on
the game's 540 rows, a soft red/green/blue shadow mask, a little bloom
from the bright parts and darker corners. It sits under the touch pad and
the caption bar, so they stay crisp. The lite Web build offers SOFT at
most (a phone's GPU). The scanlines need 2x or more to show: at 1x a game
row is one screen row. Display only.

**The lit apron (PORT-161, KNOWN_ISSUES #38):** at DUSK and NIGHT the
ground shader lights the surround near the court as it lights the court,
fading to the night's dark over 70 ground px past the court's box. The
box comes from each venue's court mask (its court roles, found once per
mask). A player's shadow behind the baseline now shows on every surround
(`test_night.test_lit_apron`, the dark ones too). Display only; DAY is
unchanged.

**The WEEKLY CHALLENGE (PORT-159):** PLAY > WEEKLY. Each week (the ISO
week) has one challenge from `data/challenges.json` (eight to start,
round the list): a team, the points, modifiers, a venue and time, and a
goal (WIN, MARGIN, SHUTOUT, ACES, RALLY). It's the same match for everyone
(MEDIUM, no ASSIST); it counts as any match does. A goal met scores (the
margin x 100, 50 an ace, 10 a hit of the longest rally), and the week's
best is kept (`save.data["weekly"]`, a new key with a harmless default).
No server is needed to play.

**Score boards (PORT-158 and the week's):** through the relay, at
`/v1/board` (pickleball-relay `boards.js`): a day's TODAY'S TRIP board
(`trip-YYYYMMDD`) and a week's challenge board (`week-YYYYWW`). The game
sends three letters (the career player's name, else a record's initials,
else PLR), a score and a short detail. Nothing else. A TODAY'S TRIP
result goes up when the day's trip ends; a new weekly best when it's set.
SCORE BOARDS (on WEEKLY) turns posting off. ROAD TRIP's home has a
TODAY'S BOARD row, and WEEKLY shows its board; both say OFFLINE or NO
BOARD YET when they can't reach it.

The relay keeps the top 20, one per address and initials. It only takes
boards near today, refuses a short list of words as initials, allows 6
posts a minute per address, and answers any page (CORS) so the Web build
can call it.

**What it doesn't do, and why:**
- **The relay can't replay a trip or a match.** The story asked for a
  score replayed headless before it counts. That would mean Godot in the
  relay's container (a much bigger image and server) or the sim ported to
  JavaScript. So a score is the game's own claim: a board is for friends,
  not prizes.
- **Boards live in the relay's memory.** The relay sleeps when idle (no
  replicas, KNOWN_ISSUES #94), and a sleeping relay forgets them. Setting
  `BOARD_FILE` to a mounted volume keeps them. That's an Azure change
  (a storage account and a mount), a cost, and the lead's call.

## Consequences

- The boards need the relay's PR merged (which deploys it). Until then
  the screens say NO BOARD YET; the game plays as before.
- New tests:
  - `test_weekly.gd`: ISO weeks as the relay counts them, every challenge
    playable, the goals, the week's best, a bot playing this week's, the
    trip scores. A score also goes through the real relay when its code is
    there (`PB94_RELAY_JS`, or `../pickleball-relay` once merged).
  - `test_night.test_lit_apron`.
  - `test_layout` cases for WEEKLY, the boards at their widest and
    TODAY'S BOARD.
- Screenshots: `tools/screenshot.gd crt=N`, `tools/weekly_shot.gd`.
