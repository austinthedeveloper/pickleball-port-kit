# ADR-079 — The Title Menu, Regrouped

Status: **Accepted 2026-10-21**
Milestone: `PORT-64` (the user: "I'm trying to re-think the entire menu
but I can't figure out where to start. There's too many choices").
Supersedes the MAIN page of ADR-025/030; the pages under it are kept.

## Decision

MAIN had twelve rows: the modes (STORY, SINGLES, DOUBLES, OPEN PLAY,
MULTIPLAYER, TOURNAMENT), PRACTICE, OPTIONS, CAREER, and three that were
settings for the next match rather than places to go (MATCH SETUP, COURT,
MODIFIERS). It now has five places to go, and a match's settings are on
the way to the match:

- **STORY** first: the game's headline mode, where a new player lands.
- **PLAY**: QUICK MATCH (SINGLES or DOUBLES, Left/Right), TOURNAMENT,
  OPEN PLAY (its location, Left/Right) and MULTIPLAYER (LOCAL, ONLINE).
  SINGLES and DOUBLES are one row; MULTIPLAYER is folded in (the user's
  three choices, 2026-10-21).
- **MATCH SETUP** (QUICK MATCH's page): START (to Player Select), MODE,
  PLAYERS, VS, DIFFICULTY, CPU ERRORS, POINTS, COURT and MODIFIERS (their
  pages, and RULES under MODIFIERS, as before). Everything is filled in
  from last time, so a match is PLAY, QUICK MATCH, START.
- **PRACTICE**: unchanged (PICKLEBALL 101, HOW TO PLAY, the ball machine).
- **PLAYER** (was CAREER): PLAYERS (CAREER's slots, cards and editor),
  RECORDS, ACHIEVEMENTS (one level down, was three) and the active
  player's HAT MUSEUM.
- **OPTIONS**: unchanged.

How it moves:

- **BACK** returns to the page a page was opened from, on the row that
  opened it (ACHIEVEMENTS from RECORDS goes back to RECORDS; from PLAYER,
  to PLAYER). A page reached any other way goes back to its place in the
  tree (`TitleScreen.TREE`).
- **After a match** the title opens where it started: MATCH SETUP on
  START after a quick match, PLAY after a tournament or the park,
  MULTIPLAYER after the lobby or online. A rematch is one press.
- **QUICK MATCH's MODE** is saved (`quick_doubles`, a new settings key
  with a harmless default: no new save layout).
- Tests reach a row by id wherever it lives (`TitleScreen.reveal(id)`),
  and the screenshot tool opens `title_<page>` the same way.

## Why

Most of MAIN's length was settings sitting beside the destinations, so
the main menu read as a list of choices with no shape. Five rows say what
the game has; the settings show up when they matter, before a match.

## Not changed

The modes, their screens and rules; Player Select; the lobby; CAREER's
logic (its slots keep their RECORDS row too); the save layout (v6).
