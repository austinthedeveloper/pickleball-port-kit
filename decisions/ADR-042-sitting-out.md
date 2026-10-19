# ADR-042 — The Partner Sitting Out

Status: **Accepted 2026-10-14**
From [GOOFY_IDEAS.md](../design/GOOFY_IDEAS.md) ("A crowd made of the players who
are sitting out").
Depends on: ADR-023 (opponents), ADR-024 (venues), ADR-034 (the park's
people).

## What

The idea was the players waiting their turn watching from the stands. The
game has no rotation of four humans, but every ladder team is a pair, and
in a **singles** ladder match one of them sits out. Now they watch: the
opponent's doubles partner sits in the venue's stands (KIDDO watches DAD,
CHAD watches BRAD), facing the court, and hops while their teammate wins a
point or the match.

- **Where:** each venue in `venues.json` has a `watcher` spot: x and y of
  the feet, and `sit` or `stand`. PARK and LAKESIDE seat them on a free
  stretch of the bleacher or bench; SUNSET's benches are full, so they
  stand beside them. The build checks the spot is on screen.
- **Look:** the park's person sprite (ADR-034): the top alone when
  sitting (the bench hides the legs), top and legs standing. It uses the
  captain's OBJ palette, the team's kit: singles has OBJ palettes 0-3
  outside the shadows' colour math, and all four are in use, so the
  partner's own skin and hair would need a fifth.
- **When:** singles ladder matches only, not the attract demo, open play,
  practice, or 2P. Doubles has nobody sitting out.
- **OAM:** 32-33 (after the close call's 30-31, ADR-041).

Display only: GameState and the golden trace are unchanged.

## Verified

- MesenCE: KIDDO on the PARK bleachers and the LAKESIDE bench, and
  standing by the SUNSET bench, in a singles match against DAD; a doubles
  match shows nobody.
- `make check`, zero overruns in `make perf`, golden trace identical.
