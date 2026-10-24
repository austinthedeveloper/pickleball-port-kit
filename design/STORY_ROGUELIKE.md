# STORY as a road trip on a map (a plan)

Asked for 2026-10-23: "Start planning a better story mode: This acts more
like a roguelike. You have a map overview with different paths to the
goal, each stop is a match. Maybe every 1-2 stops there's an upgrade for
your journey." Then: "This doesn't have to follow the bible, we can do a
different story that's on the remaster only. i think the snes game is
pretty feature complete." `PORT-82`. **Nothing here is built.** This is
the proposal to react to; the questions are at the end. When it's agreed,
each stage below gets its own branch, and the ones that change play get
an ADR.

## The short version

- **A new story, the remaster's own: ROAD TRIP.** The park is saved (that
  was SAVE THE PARK, which stays as it is). Now it's the end of summer,
  and you and Pepper load the van and drive to the **SUMMER OPEN** on the
  coast, where the Champs defend their title. Every court on the way is a
  stop. A trip is one run; each trip's map is different.
- **The map is a road map** unfolded on the van's dashboard: roads as
  lines, stops as pins, three legs of the trip from home to the coast.
  Each leg ends in a **big match** against a ladder team; the roads in
  between fork and join, so you choose your way.
- **Stops:** PICKUP GAME (a match against locals), GRUDGE MATCH (a ladder
  team or a hard local team with a twist, for a better prize), YARD SALE
  (a free pick), PRO SHOP, MOTEL (rest), DETOUR (an event), and the big
  matches.
- **Gear:** after every big match, every grudge match, at every yard sale
  and from some detours you pick one of three items for your bag (the
  "upgrade"). The generator makes sure no road goes more than two stops
  without one. About 24 items in three kinds: ones that change only the
  trip, ones that use knobs the game already has, and one-sided rule
  changes (those touch the sim, are off in the ROM's game and need an
  ADR).
- **Hearts:** you start with three. A lost match costs one; no hearts
  left and the trip's over. A RELAXED setting means losses cost nothing.
- **Between trips:** new gear in the pool, harder trips (HEAT), and your
  career player's stats and hats, as today.

## The bible

Not binding here (your call, above): ROAD TRIP is the remaster's, like
the tournament, the couch cup and the fun venues, and claims nothing
about the cartridge. It goes in `BIBLE_PLAN.md`'s list of the remaster's
own additions. Two things still worth keeping, because they cost nothing:

- **No real brands, places or people** (ground rule 2): the towns on the
  map are made up, and the park still has no name on screen (Riverdale
  is open, bible Q10).
- **The cast's looks and lines** stay as they are (Pepper, the ladder
  teams, Dale Dawson); the trip gives them new scenes, not new faces.

SAVE THE PARK (ADR-069), the bible's plot retold, is unchanged.

## The trip

### The map

- **Three legs, left to right**, each a stretch of road with its own
  places (venues) and its own ladder teams:

  | Leg | Where | Venues | Its ladder teams | Big match (one, by seed) |
  |---|---|---|---|---|
  | 1. Out of town | Home and the lake | PARK, LAKESIDE | Hendersons, Snowbirds, Gym Bros | Snowbirds or Gym Bros |
  | 2. The long drive | Theme parks and odd places | DINOSAUR, UNDERSEA, SPACE, RUINS, GLACIER | Gym Bros, Pirates, Goth Club, Surf Crew | Pirates, Goth Club or Surf Crew |
  | 3. The coast | The beach and the city | SUNSET, LAB, STATION | Surf Crew, Twins | The Twins, then the final |

  The **final** is the SUMMER OPEN against the Champs at SUNSET, at night.
  The leg's other ladder teams turn up as GRUDGE MATCHes, so a trip meets
  some of the eight, not all, and two trips meet different ones. A trip
  where you've unlocked Dale Dawson can find him on a back road (a rare
  grudge match).
- **Columns and lanes.** A leg is five columns of stops in three or four
  lanes, then its big match (a single pin every lane meets). Roads go
  from a stop to the stops in its own lane and the lanes either side in
  the next column, never crossing; every stop is reachable and leads on.
  You see the whole leg from the start (a ROAD ATLAS item shows what each
  DETOUR is).
- **Length:** 3 legs of 5 stops plus 3 big matches and the final: 19
  stops, about 13 of them matches. At MATCH SETUP's points (first to 5 by
  default) that's about 45 minutes, played in sittings: the save keeps
  the trip between any two stops. A SHORT TRIP (legs of 3) is a
  question.
- **Seeded and deterministic.** A trip has a seed (shown small on the map
  as TRIP 4127 so two players can drive the same one). The map, every
  offer, the shop's stock and every detour come from it, with the
  tournament's LCG (`Tournament._roll`) on separate streams (map, picks,
  shop, detours) mixed with the stop's column and lane, so leaving and
  coming back to a pick shows the same three items. The sim isn't
  involved: it stays without randomness; this is the meta layer, like the
  tournament's CPU matches.
- **The generated map is saved**, not regenerated from the seed, so a
  release that changes the generator can't change a trip in progress.

### Stop types

| Stop | Pin | What happens | Prize |
|---|---|---|---|
| BIG MATCH | the team's crest | A short scene with the team, then the match at its venue with a twist | A gear pick, cash |
| FINAL | a trophy | The SUMMER OPEN against the Champs | The trip won |
| PICKUP GAME | a paddle | Doubles against locals | Cash |
| GRUDGE MATCH | a red paddle | A ladder team of the leg, or locals with a modifier (LAVA, ICE, GHOST BALL, POPCORN...) | A gear pick (better odds of rare), cash |
| YARD SALE | a cardboard box | Pick one of three, free | A gear pick |
| PRO SHOP | an awning | Buy gear, a soda (a heart back), or get rid of a hazard | |
| MOTEL | a neon sign | A heart back, or Pepper practises (one of Pepper's items gets better) | |
| DETOUR | a road sign | A page of text with two or three choices (below) | Varies |

Rules for a leg, checked over a thousand seeds in the tests: at most one
GRUDGE MATCH, one PRO SHOP and one YARD SALE per column; no MOTEL in the
first two columns of leg 1; along every road, a pick at least every two
stops and no stop type three times in a row; every leg has a road with
four matches and one with two.

### A stop's match

- **Doubles, you and Pepper**, as the story's chapters are now
  (`StoryMode.config`): the active career player or MATCH SETUP's look,
  the career hooks as today (wins count, hats unlock).
- **Big matches and the ladder teams' grudge matches:** the team, its
  style, a venue of the leg and a twist. The ladder is already tuned so
  every rung is harder (SNES ADR-062), so the legs' teams are the
  difficulty ramp.
- **Pickup games:** two locals. Their look is drawn from the existing
  sprites (shirt, body, skin, hair, hat: the same long-chinned players, no
  new faces), names from a list in the data (THE MAIL CARRIERS, LUNCH
  BREAK, THE NIGHT SHIFT...), and their play is the leg's easiest
  team's style, a notch easier, rising through the leg. They play at a
  venue of the leg.
- **Difficulty and points** come from the trip's page at the start
  (below), defaulting to MATCH SETUP's. HEAT adds to them.

### The story

Short and light, in the existing scene style (`StoryScene`: the venue
behind, the speakers side by side, a dialog panel): a page or two at the
start, one before each big match and the final, a closing scene. Pepper
does most of the talking; each ladder team gets a scene about why
they're on the road (the Snowbirds on their way to Florida, the Pirates
"between ships", the Gym Bros on a protein tour). A van that breaks down,
a rival team that keeps turning up, a road-trip mixtape running gag.
Written in `data/trip.json`; I'd draft it in stage 5 for you to edit.

## Gear (the upgrades)

### How it's offered

- **Pick one of three** after a big match, a grudge match, at a yard
  sale, and from some detours: three cards side by side (icon, name, two
  lines), and SKIP for a little cash. A LUCKY PENNY makes it four.
- **Rarity:** common, uncommon, rare; a grudge match leans rare. No
  duplicates unless the item says it stacks.
- **Hazards** are the opposite: a detour or a bad bet puts one in your
  bag (FLAT TIRE: the next match on ICE, you're late and rushed). They're
  lifted after a match or at the PRO SHOP.

### The three kinds

The kind decides what it costs to build and whether it needs an ADR.

**A. The trip only** (meta code, no match changes, no ADR):

| Item | Effect |
|---|---|
| SPARE PADDLE | One more heart (stacks) |
| PIGGY BANK | Half as much cash again |
| COUPON BOOK | The PRO SHOP's prices less a quarter |
| LUCKY PENNY | Four cards to pick from |
| ROAD ATLAS | See what each DETOUR is before you go |
| RAIN CHECK | Once: a lost match costs no heart |

**B. Knobs the game already has** (a `MatchConfig` field set from the
trip; no new rule in the sim; at their defaults the golden and
conformance traces can't move):

| Item | Effect | The knob |
|---|---|---|
| UMBRELLA | The next match's twist is lifted | `modifiers` |
| PEPPER'S DINK DRILL | Pepper plays the kitchen line and dinks | the partner's `AiStyle` (net, volley, dink_period) |
| PEPPER'S NEW SHOES | Pepper gets to more balls | the partner's `AiStyle.speed` |
| PEPPER'S LOB | Pepper lobs teams that rush the net | `lob_distance` |
| PEPPER'S SCOUTING | Pepper covers the middle and picks on the weaker player | `team`, `tactics` |
| PICKLE JAR | SPECIALS on for your matches (both sides' meters, ADR-080) | `MOD_SPECIALS` |

Pepper's items need one new config field: a style for the partner's slot
(today `Opponents.slot_style` reads `partner_style` from the data). The
locals need the same for slots 2 and 3, with their looks.

**C. One-sided rules** (new sim code, for the left side only, behind a
`MatchConfig.perks` bit field that is 0 everywhere but the trip, so the
ROM's game, the golden traces and the conformance replay never see them,
as `MatchConfig.overhead` does; one ADR for the set, ints only):

| Item | Effect |
|---|---|
| GRIP TAPE | +1 CONTROL (stacks to the stat's cap, 5) |
| HEAVY PADDLE | +1 POWER |
| NEW SNEAKERS | +1 SPEED |
| SWEATBAND | Your swing recovers sooner |
| LONG ARMS | Your reach as with BIG BALL, without the big ball |
| SECOND SERVE | A serve into the net or out is taken again, once a game |
| KITCHEN PASS | Your side's first KITCHEN! of a match is a let |
| LUCKY LINE | Once a match, your ball out by a hair is called in (the close-call replay says LUCKY!) |
| HEAD START | Every match starts 1-0 to you |
| SECOND WIND | At match point against you, your side moves faster |
| HOT HAND | Three points in a row and your next shot is a PICKLE SMASH |

The stat items go past the paddles' 9-point budget, which is why they are
rules and not a new hat: the ROM's paddles keep their budget, and the
trip's gear is the remaster's.

Hazards are all kind B, existing modifiers for one match: FLAT TIRE
(ICE), POWER CUT (GLOW), STORM (WIND), LATE START (SUDDEN DEATH), POTHOLES
(POPCORN).

That's 23 items and 5 hazards: enough for one trip to feel different from
the last. More come from the specials and powerups plan
(`SPECIALS_AND_POWERUPS.md`, route B's BIG PADDLE, SNEAKERS, MAGNET...)
once that's decided.

### Detours

A page like a story scene with two or three choices, written in
`data/trip.json`. About 15 to start. For example:

- **A hitchhiker with a paddle:** give them a lift (a pickup game with
  them as your partner instead of Pepper, for a rare pick), or drive on.
- **A roadside stand:** a free common item, or 30 cash.
- **A shortcut:** skip the next stop, but take a hazard (STORM).
- **The van's making a noise:** pay 20 cash to fix it, or risk a FLAT
  TIRE.

## Losing, winning, and between trips

- **Hearts:** 3 to start (2 at HEAT 2 and up). A lost PICKUP or GRUDGE
  match costs one and you drive on, with no prize. A lost BIG MATCH costs
  one and is played again (Pepper's word in between). At no hearts the
  trip's over: the van turns home, the trip in numbers, and back to the
  title. Quitting from the pause menu during a match counts as a loss.
- **RELAXED** (a choice on the trip's page): no hearts, losses cost
  nothing. The trip still has its gear.
- **The end:** winning the SUMMER OPEN: the trophy, the closing scene the
  first time, a card after that; the trips won go up, and the next HEAT
  opens.
- **Between trips:**
  - **HEAT 0 to 5**, one per trip won, each adding one thing (the
    opponents err less, two hearts, a hazard to start with, fewer MOTEL
    stops, big matches to one more point...).
  - **New gear in the pool:** about 12 items at first; the rest come
    with milestones (reach leg 2, win a trip, win one without losing a
    heart, five PRO SHOP visits...). The ACHIEVEMENTS page gets a few trip
    ones.
  - **No lasting stat boosts.** The career player's stats and hats work
    as they do now; a won trip doesn't make the next one easier except
    through what's in the pool. (Question 5.)
  - **A partner other than Pepper** once you've won a trip? (Question 6.)

## How it fits today's STORY

STORY on the title opens a page with **ROAD TRIP** (CONTINUE the trip in
progress, with its leg and hearts; NEW TRIP with HEAT, RELAXED,
DIFFICULTY, POINTS) and **SAVE THE PARK** (the eight chapters, as now).
The title's STORY value reads the trip in progress (LEG 2, 3 HEARTS) or
the park's chapter. The scenes reuse `StoryScene`; the trip's data is
`data/trip.json` next to `story.json`. (Or ROAD TRIP replaces SAVE THE
PARK: question 3.)

## The save

SAVE THE PARK's `save.data["story"]` keeps its meaning, so the trip is a
new key with a harmless default (`{}`: no trip), filled in on load as
the save does for new keys: the layout stays **v6**, no migration (a
test still loads a save without the key). If question 3 goes the other
way and SAVE THE PARK goes, its key is dropped by a v7 migration then.

```
"trip": {
  "won": 2,                # trips won
  "heat": 1,               # the highest HEAT open
  "pool": [...],           # gear ids unlocked
  "milestones": 0,         # bits
  "seen": 0,               # scenes watched once, one bit each
  "now": {                 # the trip in progress, {} none
    "seed": 4127, "gen": 1, "heat": 0, "relaxed": 0, "difficulty": 2, "points": 5,
    "map": [[{"type": "pickup", "venue": "lakeside", "edges": [0, 1]}, ...], ...],
    "at": [1, 3, 2],       # leg, column, lane
    "hearts": 3, "cash": 45,
    "bag": ["grip_tape", "pepper_dink"], "hazards": ["storm"],
    "pending": {"kind": "pick", "items": ["...", "...", "..."]}
  }
}
```

Every value is an int or a string, as the save requires.

## The screens

All in the game's 960x540 art, the bitmap fonts' characters only (caps,
digits, `!?.,:-'/%+`: so CASH 45, not $45), panels and labels from
`UiKit`, prompts as `PromptBar`s.

- **THE MAP** (`view/trip_map.gd`): a fold-out road map on the van's
  dashboard (the dash and the windscreen's bottom edge framing it),
  scrolling sideways with your position kept left of centre. Stops are
  pins with an icon on a paper tag; the roads are drawn lines, the ones
  you've driven inked over in red pen. The van, a small sprite, sits at
  your pin and drives the road to the next stop, with you and Pepper in
  its windows (the match players' heads at their small size, so the faces
  are the ones the game already has). Big-match pins carry the team's
  colours. Along the top, a strip: hearts (icons, not characters), cash,
  the leg, the bag's icons; under the map, a panel for the stop you're
  choosing (its name, venue and time, twist, prize). Choosing is a
  `MenuPage` whose rows are the next column's reachable stops by id
  (`stop_2_4_1`), so tests select by id and the mouse picks a pin; LEFT
  and RIGHT scroll to look ahead.
- **PICK ONE** (`view/gear_pick.gd`): three `UiKit` cards and SKIP;
  each card's icon, name and two lines.
- **PRO SHOP**: a `MenuPage` of items and prices, the shopkeeper's line
  in a dialog panel.
- **DETOUR**, **YARD SALE** and **MOTEL**: `StoryScene` pages with choice
  rows.
- **TRIP'S OVER** and **CHAMPIONS!**: the trip in numbers on a panel.
- **The art:** the dashboard, the van, pins and icons (16 x 16 at 2x,
  about 24 of them) drawn in Aseprite like the ball machine
  (`art/sprites/`), in the game's palette; the venue thumbnails on the
  tags cut from the level art. A mock-up of the map comes first, for you
  to look at before any art is final.
- **Text never collides** (`test_layout`): new cases for the map at
  every stop in a generated trip (and the longest stop name, the fullest
  bag, 0 and 9 hearts, 999 cash), every gear card, every detour page and
  choice, the shop at its longest list, and the trip's page with every
  value of every row, keyboard and pad prompts both.

## Build stages

Each a branch, chained, with its own row on the roadmap when it starts
(the numbers aren't taken yet). Each passes `test.sh` with the golden
traces unchanged.

| Stage | Branch | What | ADR |
|---|---|---|---|
| 1 | `feature/cld-trip-run` | `meta/trip.gd`: the seeded map generator and the trip (pure, like `Tournament`); `data/trip.json`; the save key. No screens. Tests: the same seed gives the same map, the leg rules over 1000 seeds, every road reaching the final | One for the mode |
| 2 | `feature/cld-trip-map` | The map screen with placeholder pins, STORY's page, a stop's match and back, hearts and losing, the big matches and final. Playable end to end, no gear yet | |
| 3 | `feature/cld-trip-gear` | Gear kinds A and B, PICK ONE, YARD SALE, the PRO SHOP, MOTEL, cash; the slot-style config field | Small: the config field |
| 4 | `feature/cld-trip-perks` | Gear kind C: `MatchConfig.perks`, off in conformance; a view-and-bare-sim test per item | Yes: the one-sided rules |
| 5 | `feature/cld-trip-story` | The scenes and detours, the hazards, the writing | |
| 6 | `feature/cld-trip-art` | The mock-up, then the dashboard, van, pins, icons; screenshots | |
| 7 | `feature/cld-trip-heat` | HEAT, the gear pool's unlocks, achievements; tuning with a headless tool that plays trips with a CPU in your place (like `rally_stats.gd`) to set hearts and prices | |

Stages 1 to 3 make a playable trip; 4 to 7 can come in any order after.

## Questions for you

1. **The story:** ROAD TRIP to the SUMMER OPEN (the cast on a drive to the
   coast, new places on the way). Or something else: Grimsby back with a
   new scheme, a tour of the remaster's odd venues, a story with a rival
   of your own?
2. **Losing:** three hearts, a lost big match replayed at a heart's
   cost, and RELAXED for no penalty. Or no hearts at all, and a loss just
   costs the prize?
3. **Beside or instead:** ROAD TRIP next to SAVE THE PARK under STORY.
   Or replace SAVE THE PARK (its scenes could become the first trip's)?
4. **Length:** three legs of five stops, about 45 minutes. Or a SHORT
   TRIP (legs of three) as the default?
5. **Lasting progress:** only new gear in the pool and HEAT; no stat
   boosts that carry over. Should a won trip give something permanent
   (a starting item, a fourth heart)?
6. **Partners:** always Pepper, or once you've won a trip, take any
   captain you've beaten (Kiddo, Marge...) as open play's partner pick
   does (ADR-060)? And a second pad in Pepper's place for two players?
7. **The one-sided rules (kind C):** fine as trip-only gear, or should
   some (SECOND SERVE, KITCHEN PASS) be MODIFIERS for everyone too?
8. **The names:** ROAD TRIP, SUMMER OPEN, GEAR, YOUR BAG, CASH, HEARTS,
   HEAT, PRO SHOP, YARD SALE, MOTEL, DETOUR, HAZARDS. Any you'd change?
