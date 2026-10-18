# ADR-054 — The Tournament

Status: **Accepted 2026-10-18**
Milestone: `PORT-25` (Godot port only). Depends on: ADR-023 (the ladder
teams), ADR-024 (their home courts), ADR-026 (intro cards), ADR-047
(career), ADR-052 (the port).

## What

**TOURNAMENT** on MAIN: an eight-entry knockout, you and seven ladder
teams, three rounds (QUARTERFINAL, SEMIFINAL, FINAL). Every match of yours
is at your opponent's home court, with their intro card. Between matches,
a bracket screen shows the draw, the scores, and the champion.

- **The draw** is seeded by the ladder: you're the top seed (the home
  favourite), then the teams from the top rung down. The first rung
  (HENDERSON, the warm-up) sits it out. The bracket order is the usual
  1-8, 4-5, 3-6, 2-7, so your road gets harder each round (SNOWBIRDS, then
  the 4-5 winner, then most likely the top half's CHAMPS or TWINS).
- **CPU-vs-CPU matches** aren't played: they're decided from the
  tournament's seed. The higher rung wins 50% plus 9% per rung apart, at
  most 90%, so upsets happen (about one quarterfinal in four over 60
  draws); the loser's points come closer the closer the teams. A round's
  other matches are decided when you finish yours, and appear one at a
  time when you come back to the bracket.
- **Mode, difficulty and points** are fixed when the tournament starts
  (MODE on the bracket; difficulty and points from MATCH SETUP), with the
  saved modifiers. You play in your last Player Select choice, or as the
  active career player.
- **A forfeit** (FORFEIT, pressed twice) hands your next match over and
  plays the rest out. Leaving a match from the pause menu doesn't count:
  the match is still yours to play.
- **Saved:** the bracket in play (`tournament.bracket`, with how many
  results the screen has shown), and in the records `cup_runs`, `cups`
  and `cup_best`. New keys with harmless defaults, so the save stays at
  layout v5 (CLAUDE.md's rule). RECORDS shows the cups beside SHUTOUTS.

## Why decide the CPU matches

Playing them out (a headless sim per match) would be truer, but the bot
plays with the ladder's AI on only one side; both sides would need a
team's style, which slot 0 never has. The fixed-odds draw is quick, fully
deterministic from the seed (a saved bracket replays the same), and
reads like a real draw: the favourites usually go through.

## What it isn't

- Tournament matches count as ordinary CPU matches: the career, the
  records and the VS row, but not the ladder's rung.
- No 2P or multiplayer tournament yet (KNOWN_ISSUES #50).
