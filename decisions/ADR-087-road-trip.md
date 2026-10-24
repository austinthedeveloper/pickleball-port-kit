# ADR-087 — ROAD TRIP: a Roguelike Mode on a Map

Status: **Accepted 2026-10-24**
Milestone: `PORT-82` (the user: "a better story mode ... acts more like a
roguelike. You have a map overview with different paths to the goal,
each stop is a match. Maybe every 1-2 stops there's an upgrade for your
journey"; then "this doesn't have to follow the bible ... this'll be
separate").
Design: `design/ROAD_TRIP.md` (the plan, the user's answers, the art).

## Decision

**ROAD TRIP** is a mode of its own on MAIN, beside STORY (which is
unchanged). It's the remaster's only; the bible is not asked of it.

- **A trip** is one drive to the SUMMER OPEN, where the Champs defend
  their title: three legs, each three columns of stops in three lanes and
  then its big match (the last leg's is the final). About 12 stops and 8
  matches, 30 minutes at most.
- **Stops**: PICKUP GAME (locals, first to 3), GRUDGE MATCH (a ladder team
  of the leg, Dale Dawson now and then, or locals, with a twist), YARD
  SALE (a free pick), PRO SHOP, MOTEL, DETOUR (a page and a choice), and
  the big match (first to 5) and the final (first to 7, HARD).
- **Seeded**: the map, every offer, the shop's stock and the detours
  come from the trip's seed and where on the map they're decided
  (`RoadTrip.roll`), so a trip is the same wherever it's played and a
  pick reopened shows the same cards. Every leg keeps rules checked over
  300 seeds: at most one grudge match, shop and yard sale a column; no
  motel on the first leg; along every road no two stops in a row without
  gear on offer, never the same stop twice in a row, at least one match;
  roads never cross. The generated map is saved, not regenerated.
- **You start weak**: a PLAIN PADDLE, a PLAIN CAP, and four stats
  (POWER, CONTROL, SPEED, FEET) at 1 of 20. The game's standard player is
  about 8. Gear (pick one of three after a grudge or big match, at a yard
  sale, from some detours; or bought) raises them: the game's paddles and
  hats, stacking items, partner training, and one-sided rules.
- **Hearts**: three (two at HEAT 2). A lost match costs one (a lost big
  match is played again); none left, the trip is over.
- **Between trips**: the miles driven fill the GARAGE's fixed ladder of
  lasting rewards (starting stats, a heart, starting cash and gear, new
  gear in the pool, van paints and dash ornaments); a captain beaten
  becomes a partner (the Champs' only by winning a trip); a trip won opens
  the next HEAT (0 to 5).
- **Nothing leaks**: a trip's matches count for nothing outside it (no
  records, career stats, ladder, hats or achievements), and nothing
  outside unlocks anything in it.

### The sim (remaster-only, off in the ROM's game)

`MatchConfig.trip` switches on three things, all off by default so the
golden and conformance traces are unchanged:

- **`trip_stats`**: a slot's [power, control, speed, feet]. The first
  three become a paddle profile past every real one
  (`Paddles.trip_profile`): each point from 8 moves a tunable 2/64 of its
  standard value (1 is about 0.8, 20 about 1.4). FEET sets a human's top
  speed (`Paddles.trip_feet`: 20 at 1, 24 at 8, 31 at 20).
- **`styles`**: a CPU slot's play (`Opponents.slot_style`), for the
  partner's training.
- **`perks`** (`K.PERK_*`), the left side's one-sided rules: HEAD START
  (1-0), LONG ARMS (BIG BALL's reach), SECOND WIND (+4 top speed while
  the other side has match point), KITCHEN PASS (the first KITCHEN! of a
  match is forgiven), SECOND SERVE (the first faulted serve of a match is
  served again). A forgiven one emits `EVENT_PERK`.

## Why

- The user's ask, then answers: a mode beside STORY, hearts so a trip can
  end, 30 minutes, starting with nothing and growing slowly, captains as
  partners, everything kept inside the mode.
- Gates every path passes were the first plan, to keep the bible's
  petition; once the story didn't have to be canon, the legs could meet
  some teams and not others, which is what makes two trips different.
- Stats on a 20-point scale give room to grow; the paddles' 9-point
  budget stays the ROM's.

## Tests

`test_road_trip`: the data fits the screens and the font; a seed draws
the same map; 300 seeds' legs keep the rules; roads never cross; a trip
won, a trip lost, a big match lost and replayed; stats and gear; picks
the same each time; the shop and detours; the save (a trip survives a
restart, its end goes to the GARAGE, nothing else changes, an old save
loads); the trip's stats and perks in the sim, and a trip config without
`trip` playing as the game always has.
