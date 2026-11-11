# ADR-106 — CLUB: the Club Manager

Status: **Accepted 2026-11-11** (asked for by the user: "knock out all
the Club manager stories", the phase 6 milestones 2027-06 and 2027-07).
Milestone: `PORT-142` to `PORT-150` (GitHub issues #32 to #40). The
bible's §5.8 lists "a club manager mode" among the Pickleball '95
promises; `design/GOOFY_IDEAS.md` had its smallest version. Builds on
ADR-034 (open play), ADR-078 (the park's locations), PORT-25 (the
tournament), PORT-30 (HOW TO PLAY).

## Context

Open play is a park you visit: three courts, their paddle stacks, the
ladder teams, the clubhouse. The '95 promise is to run it. The idea list
asked for a day cycle, a ledger, upgrades that change the park, still
playing on court 1, and then a coach, a weekend tournament, members who
leave when the wait is too long, and weather.

## Decision

**PLAY > CLUB** opens the club's home (`view/club_home.gd`). The logic is
`meta/club.gd` (`Club`): meta, not sim. Nothing in a match changes, and
`sim/open_play.gd` is untouched: the club's park is the open play park,
driven exactly as before (`test_club_park_is_the_same_park`).

### The day

- A day runs 9:00 AM to 6:00 PM (9:00 PM with LIGHTS). In the park the
  clock moves a minute every 8 frames while you walk (about 72 s for the
  day without matches); each of your matches takes 40 minutes, a drill 30.
- **OPEN THE PARK** is the open play park (seeded by the club and the
  day, the same park all day). You stack and play as in open play; your
  matches are open play matches (`MatchConfig.open_play`), so records,
  achievements and the career's park rating count them as they count
  any open play match. Start goes home; the day waits.
- At closing time the park says so and closes: the night. **END THE
  DAY** (pressed twice) skips to it: the members play the day out without
  you.
- **The night's ledger**, a card on the home: dues, court fees, the snack
  bar, the cup, upkeep, the coach; the night's total and the cash;
  members joined and left (by name); the games played of what the courts
  hold; the wait at a court; your wins and losses.

### The ledger's model (ints, seeded)

- Each member pays 3 a day. Members come in by the weather's attendance
  (SUNNY 60%, CLOUDY 55, HOT 40, WINDY 45, SHOWERS 35, RAIN 0, or 50
  indoors), plus walk-ins from the club's reputation. Each wants three
  games; four play a game; every player-game pays 1.
- The courts hold a game an hour each. The **wait** is the park's own
  stacks, sampled once a second while you walk (15 minutes for each team
  waiting at a court), plus the games wanted past what the courts hold,
  spread over the courts.
- **Members** have a skill (30 to 60 at first), a patience (20 to 60
  minutes) and a mood. A day they come and wait longer than their
  patience costs a point of mood, a good day gives one (to +3); at -3
  they leave. Your **wins** build reputation (3 a win, more on the higher
  courts), as do the upgrades, a strong membership and a cup won; it
  decays 10% a night. New members join from it (2 a day at most, none
  when the wait is over 45 minutes), up to 80.
- Upkeep: 30, plus 8 a court, plus each upgrade's own.
- **The bank:** 14 nights in a row in the red and the club closes. Its
  last ledger says so, and a new club opens.

### Upgrades (UPGRADES)

| | Price | Upkeep | In the park |
|---|---|---|---|
| LIGHTS | 900 | 6 | Open till 9 PM; the park's lamps light at dusk and the park darkens; matches after 5 PM at DUSK, after 6:30 at NIGHT |
| SNACK BAR | 600 | 8 | The gym's cart and cooler by the path; a visitor buys a snack (two on a HOT day) |
| BALL MACHINE | 400 | 2 | The clubhouse's machine (hidden until bought; its spot says so) |
| ANNEX COURT, SECOND ANNEX | 1500, 2200 | 8 (a court) | A court each for the members, on the COURTS panel |
| INDOOR COURTS | 2800 | 15 | A RAIN day is played at THE GYM (ADR-078's location) |

The annexes are courts the members play on, off the park's picture (the
park's art has three courts and the clubhouse; a fourth would need new
art). They show as ANNEX rows on the COURTS panel.

### Staff

**COACH**: 250 to hire, then 2 a member a day (20 at least). Every
member who comes gains a point of skill a day (two on a drill day) and a
minute of patience (to 90): coached members wait their turn better and
stay. **TODAY'S DRILL** is a HOW TO PLAY lesson (the drills PICKLEBALL 101
uses), a new one each day, once a day; finishing it counts for today's
members. MEMBERS has a card for each member: skill, patience, mood, the
day they joined, the days coached.

### WEEKEND CUP

On a Saturday that isn't washed out: an eight-team bracket (the
tournament's, PORT-25, under the save key "club"), you and seven
visiting ladder teams. Each visiting team pays 30 to enter and each
member who comes pays 2 at the gate; the purse is 100, yours back if you
win, with a trophy on the clubhouse shelf (by the records board) and
reputation. The cup is Saturday's: once it's over for you, the day ends.
The cup counts in RECORDS as any cup does.

### Weather

From the club's seed and the day (`Club.weather`), so the forecast on
the home is the day's. SUNNY, CLOUDY, HOT (heat haze over the park, the
snack bar sells twice), WINDY (your matches add the WIND modifier, ADR-065:
an existing modifier, not a sim change), SHOWERS (rain over the park,
fewer come), RAIN (the outdoor courts shut: no games, no cup, no drill,
the dues still come; with INDOOR COURTS the day is at THE GYM on its
three courts).

### Saving

`save.data["club"]`: the club (`now`) and what lasts across clubs (clubs
started, the best day and cash, cups). A missing key fills in, so a save
from before CLUB loads with no club; the layout stays v6 (CLAUDE.md's
rule: a new key with a harmless default rides on the defaults; no meaning
changed). PORT-143's story asked for v7; this is why it isn't.

### Balance (PORT-150)

`tools/club_stats.gd` plays clubs headless by four strategies
(`Club.bot_day`): SAVER (buys nothing, never plays), BUILDER (buys with a
cushion, plays two matches a day at 50%), PLAYER (three at 70%, hires the
coach), SPENDER (buys everything the moment it can). Over 8 seeds:

| Day | SAVER | BUILDER | PLAYER | SPENDER |
|---|---|---|---|---|
| 30 cash | 1012..1132 | 1124..1895 | 959..1454 | 38..567 |
| 30 members | 16 | 41..62 | 51..63 | 18..55 |
| 60 cash | 1440..1632 | 3148..7088 | 1063..2861 | 145..1825 |

None goes bust by day 30 and none reaches 20,000 by day 60
(`test_club.test_balance`, 6 seeds each). A club left alone stays at 16
members and gains slowly; past day 60 a growing club fills to 80 members
and its cash climbs fast (see Consequences).

## Consequences

- One mode more on PLAY; no sim, golden trace or conformance change.
- The late game has nothing to spend on: a year in, a growing club holds
  around 100,000 (KNOWN_ISSUES #95). A second tier of upgrades, or
  members' fees that rise with what's built, would be the next step.
- The balance is a bot's, not a person's (KNOWN_ISSUES #95).
- Tests: `test_club.gd` (the logic, the balance, the soak, the save, the
  park in club mode, main's day, drill and cup), `test_layout.test_club`.
  Screenshots: `tools/club_shot.gd`.
