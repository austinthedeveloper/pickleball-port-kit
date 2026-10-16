# Goofy Ideas

A running list of ideas that are **not** needed for the MVP and are not fully
baked. These are for fun and inspiration, not commitments. When one grows
up, it moves to [IDEAS.md](IDEAS.md) and gets an ADR.

## 5-player Multitap: the line judge

With a Super Multitap, four players play doubles and a fifth is the **line
judge**. They call balls in or out, and maybe the game keeps score of how
often they get it right. They could be bribed? Heckled? They could have a
whistle button.

- Notes: the Multitap gives five pads (port 1 plus four on port 2;
  docs/04_INPUT_MULTITAP_PLAN.md), so the fifth pad is free in doubles.

## Pickleball manager

Run the club behind open play (ADR-034): the courts, the players, and the
money.

- **Smallest version:**
  - a day cycle
  - a club ledger: member dues and court fees in, upkeep out
  - upgrades that change the park: lights for night play (see Night
    courts in IDEAS.md), a snack bar, more courts, a ball machine that
    unlocks practice
- **You still play:** you own the club and play on court 1; managing
  happens between days.
- **More ideas:** hire a coach, run a weekend tournament, members who leave
  when the wait at the paddle stack is too long, weather.
- Needs its own ADR before any code: the economy loop, what a day is, and
  what the park scene already supports (M4-OPEN-05).

## Quips

**Done:** [ADR-048](decisions/ADR-048-quips.md). The notes below are the
original idea.

Players say something when they miss or fault, in the point-result banner
(where `KITCHEN!` already shows). PG only: no cursing, no put-downs.

- **Per opponent:** a `quips` list in `opponents.json`, next to `intro`,
  `taunt`, and `concede`. Your player gets a generic list.
  - HENDERSON: `WELL, THAT'S A PICKLE.`
  - SNOWBIRDS: `OH, FIDDLESTICKS.`
  - GYM BROS: `BRO. NO.`
  - PIRATES: `ARRRGH!`, `SHIVER ME PADDLES!`
  - GOTH CLUB: `HOW TRAGIC.`
  - SURF CREW: `WIPEOUT!`
  - TWINS: `THAT WAS HIS FAULT.`
  - CHAMPS: `...THAT NEVER HAPPENS.`
- **Not every time:** at most one miss in three, never the same line
  twice in a row.
- **Cost:** a few hundred bytes of text.
