# ADR-060 — The Period-True Park

Status: **Accepted 2026-10-18**
Milestone: `PORT-37`. Ports: SNES ADR-070 (ROOKIE / CLUB / CHAMP and the
park rating), 071 (winners stay on) and 072 (pick your partner), from the
SNES repo's `src/open_play.c`, `src/career.c` and `test/test_open_play.c`.

## What changed

- **The courts are ROOKIE, CLUB and CHAMP.** The port showed DUPR-style
  ratings (`UNDER 3.5`, `3.5-4.5`, `4.5+`), which didn't exist in 1994
  (KNOWN_ISSUES #63).
- **Park points.** A career player has a park rating in tenths, shown as
  points with no decimals: 10 to start (3.0), 0 to 40. A win at your
  level is +2, a win on a court above it +3, a win below it nothing; a
  loss is -1 anywhere. CLUB opens at 15 points and CHAMP at 25; a court
  you've reached stays open if your points drop. No career player, or
  KID, rates nothing and opens every court. A locked rack says "OPENS AT
  15 PTS  YOU HAVE 12".
- **Winners stay on**, for two wins in a row: the losers go to the back
  of the stack and the next team comes on against the winners. You too:
  win and you're called again with the same partner ("WINNERS STAY: VS
  ..."); pressing B at a rack while you wait gives that up.
- **Pick your partner.** At your own rack, SLICE (Y on a pad, I on the
  keyboard) cycles NEXT UP and the captain of each ladder team you've
  beaten. A picked partner's team is never your opponent: if they're the
  winners you'd face, the game starts fresh instead.

## How

`sim/open_play.gd` follows the C's functions in its order and shape
(`_stack_take`, `_team_waiting`, `_next_entry(c, skip)`, `_court_won`,
`_leave_stay`, `_court_start_game`, the rating helpers, `partners`,
`pick_ready`, `pick_next`). `MatchConfig.open_play` is the court + 1, as
in the C, so the career can rate the game. `Career.Player.park` is the
C's packed byte (the best court in the top two bits, the rating less 19
below); a save without it reads as a new player, so the save stays at v6.
The C rates on the frame after the match (`career_park_flush`, for the
SNES's frame budget); the port rates at once. The result screen shows the
move ("PARK POINTS 14 TO 16" or "CLUB COURT OPEN! 16 PTS") where a ladder
match shows NEXT UP.

`tests/test_open_play.gd` ports the C's new tests (the rating, winners
stay, you staying and losing, nobody waiting, the soaks, the pick cycle,
picked calls, a pick against winners), and `test_career.gd` the packed
rating.
