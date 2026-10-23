# STORY as a summer on a map (a plan)

Asked for 2026-10-23: "Start planning a better story mode: This acts more
like a roguelike. You have a map overview with different paths to the
goal, each stop is a match. Maybe every 1-2 stops there's an upgrade for
your journey." `PORT-82`. **Nothing here is built.** This is the proposal
to react to; the questions are at the end. When it's agreed, each stage
below gets its own branch, and the ones that change play get an ADR.

## The short version

- **A run is one summer.** Mr. Grimsby's vote is at the end of it; you and
  Pepper have until then to get every team's signature and beat the
  Champs. The map is the summer's calendar pinned to the clubhouse
  corkboard: a paper map, left to right, with pins for the stops and
  pencil lines between them.
- **The eight chapters stay, as the map's gates.** Every path runs through
  each ladder team in ladder order, so the canon plot is untouched (seven
  signatures, then the Champs). Between two chapters is a **leg** of one
  or two stops, in two or three lanes: that's where the paths differ.
- **Stops:** PICKUP GAME (a match against park regulars), GRUDGE MATCH
  (a harder team with a twist, for a better prize), PRO SHOP, PEPPER'S
  PORCH (rest), NOTICE BOARD (an event, often one of Grimsby's letters),
  and the CHAPTER itself.
- **Gear:** after every chapter, every grudge match and some events you
  pick one of three items for your bag (the "upgrade"). With legs of one or
  two stops that's a pick every one to two stops, as asked. About 24
  items to start, in three kinds: ones that change only the run, ones that
  use knobs the game already has, and one-sided rule changes (those touch
  the sim, are off in the ROM's game and need an ADR).
- **Hearts:** you start with three. A lost match costs one; a lost chapter
  is played again (as today) at the cost of a heart. No hearts left and
  the summer's over. A RELAXED setting keeps today's no-penalty story.
- **Between summers:** the parks saved, new gear in the pool, harder
  summers (HEAT), and your career player's stats and hats, as today.

## Where it stands against the bible

The canon (bible §5.2, SNES ADR-077) is the ROM's story: Grimsby means to
pave the park, you and Pepper beat the other seven teams first and each
signs, then the Champs, who play with the park as the bet; doubles, a
scene before each match, an ending; Grimsby only ever text. The remaster
already tells it its own way (ADR-069; `BIBLE_PLAN.md` marks it
**differs**). This plan keeps every canon beat:

| Canon | Here |
|---|---|
| All seven teams sign, then the Champs | Chapters are gates every path passes, in ladder order |
| Pepper, your partner, and the look | Pepper partners every match; the gear changes how Pepper plays, not who Pepper is |
| Grimsby never a sprite | He's in letters on the NOTICE BOARD and on the loudspeaker, as now |
| Gym Bros on his payroll, Twins his niece and nephew, Champs bet the park | The chapter scenes, unchanged |
| Doubles, a scene each chapter, an ending, progress saved | The same; the run is saved after every stop |

Four things to flag (questions 1 to 3 at the end):

1. **Losing costs something.** The ROM's story keeps your chapter
   whatever happens (SNES ADR-077); hearts make a loss count. It's the
   remaster's own mode, so no canon fact changes, but `BIBLE_PLAN.md`'s
   row should say so, and RELAXED keeps the ROM's way.
2. **Branching that skips teams would contradict canon.** A bigger map
   where you meet four or five of the seven (and the petition needs that
   many) would be more of a roguelike, but the bible says all seven sign.
   That needs the project lead's word; this plan doesn't do it.
3. **Period-true words** (ground rule 7) on screen: no "run", "perk",
   "build" or "roguelike". The plan's words are SUMMER, STOP, LEG,
   GEAR, YOUR BAG, HEARTS, TICKETS, PRO SHOP, HEAT. ("Run" below is only
   the docs' word.)
4. **The park has no name on screen** (bible Q10, Riverdale is OPEN): the
   map says THE PARK and the venues' names, never a town.

## The run

### The map

- **Columns, left to right.** Chapter 1 (the Hendersons at the park) is
  the first column, the Champs the last. Between chapter *n* and *n + 1*
  is leg *n*: one or two columns of stops, each column two or three lanes.
  The chapter pins are single (every lane meets there); a leg's lanes fan
  out from one chapter and close at the next.
- **Edges** go from a stop to the stops in its own lane and the lanes
  either side in the next column, never crossing; every stop is reachable
  and leads on. You see the whole map from the start (a TOWN MAP item
  shows what's behind each NOTICE BOARD).
- **Length:** 8 chapters and 7 legs of 1 or 2 columns: 15 to 22 stops,
  about 12 to 16 of them matches. At MATCH SETUP's points (first to 5 by
  default) that's a 40 to 60 minute summer, played in sittings: the save
  keeps the run between any two stops. A SHORT SUMMER (every leg one
  column) is a question.
- **Seeded and deterministic.** A run has a seed (shown small on the map
  as SUMMER 4127 so two players can play the same one). The map, every
  offer, the shop's stock and every event come from it, with the
  tournament's LCG (`Tournament._roll`) on separate streams (map, picks,
  shop, events) mixed with the stop's column and lane, so leaving and
  coming back to a pick shows the same three items. The sim isn't
  involved: it stays without randomness; this is the meta layer, like the
  tournament's CPU matches.
- **The generated map is saved**, not regenerated from the seed, so a
  release that changes the generator can't change a summer in progress.

### Stop types

| Stop | Pin | What happens | Prize |
|---|---|---|---|
| CHAPTER | the team's crest | The chapter's scene (in full the first time, then its card and one page), the match with its twist, the petition signed | A gear pick, a signature, tickets |
| PICKUP GAME | a paddle | Doubles against park regulars | Tickets |
| GRUDGE MATCH | a red paddle | A harder team with a modifier (LAVA, ICE, GHOST BALL, POPCORN...) | A gear pick (better odds of rare), tickets |
| PRO SHOP | a shop awning | Buy gear, LEMONADE (a heart back), or pay to lift one of Grimsby's tricks | |
| PEPPER'S PORCH | a porch swing | A heart back, or Pepper drills (one of Pepper's items gets better) | |
| NOTICE BOARD | a pinned letter | A page of text with two or three choices (below) | Varies |

Rules for a leg, checked over a thousand seeds in the tests: at most one
GRUDGE MATCH and one PRO SHOP per column; no PORCH in leg 1; every leg
has a lane with a match and a lane without a grudge match; no stop type
three times in a row along any path.

### A stop's match

- **Doubles, you and Pepper**, as the chapters are now (`StoryMode.config`):
  the active career player or MATCH SETUP's look, the career hooks as
  today (wins count, hats unlock).
- **Chapters:** the ladder team, its venue, time and twist, as
  `story.json` has them. The ladder is already tuned so every rung is
  harder (SNES ADR-062), so the chapters are the difficulty ramp.
- **Pickup games:** two park regulars. Their look is drawn from the
  existing sprites (shirt, body, skin, hair, hat: the same long-chinned
  players, no new faces), names from a list in the data
  (THE MAIL CARRIERS, LUNCH BREAK, THE NIGHT SHIFT...), and their play is
  the last chapter's team's style, a notch easier. They play at the
  venue of the leg (the last chapter's, or the next's).
- **Grudge matches:** the next chapter's style, plus a modifier from a
  short list, and sometimes a team you've already signed wanting a
  rematch (with their own intro line).
- **Difficulty and points** come from a SUMMER page at the start (below),
  defaulting to MATCH SETUP's. HEAT adds to them.

## Gear (the upgrades)

### How it's offered

- **Pick one of three** after a chapter, a grudge match, and some events:
  three cards side by side (icon, name, two lines), and SKIP for a few
  tickets. A LUCKY PENNY makes it four.
- **Rarity:** common, uncommon, rare; a grudge match leans rare. No
  duplicates unless the item says it stacks.
- **Grimsby's tricks** are the opposite: an event or a lost bet puts one
  in your bag (SPRINKLERS: the next match on ICE). They're lifted after a
  match or at the PRO SHOP.

### The three kinds

The kind decides what it costs to build and whether it needs an ADR.

**A. The summer only** (meta code, no match changes, no ADR):

| Item | Effect |
|---|---|
| SPARE PADDLE | One more heart (stacks) |
| PIGGY BANK | Half as many tickets again |
| COUPON BOOK | The PRO SHOP's prices less a quarter |
| LUCKY PENNY | Four cards to pick from |
| TOWN MAP | See what each NOTICE BOARD is before you go |
| RAIN CHECK | Once: a lost match costs no heart |

**B. Knobs the game already has** (a `MatchConfig` field set from the run;
no new rule in the sim; at their defaults the golden and conformance
traces can't move):

| Item | Effect | The knob |
|---|---|---|
| UMBRELLA | The next chapter's twist is lifted | `modifiers` |
| PEPPER'S DINK DRILL | Pepper plays the kitchen line and dinks | the partner's `AiStyle` (net, volley, dink_period) |
| PEPPER'S NEW SHOES | Pepper gets to more balls | the partner's `AiStyle.speed` |
| PEPPER'S LOB | Pepper lobs teams that rush the net | `lob_distance` |
| PEPPER'S SCOUTING | Pepper covers the middle and picks on the weaker player | `team`, `tactics` |
| PICKLE JAR | SPECIALS on for your matches (both sides' meters, ADR-080) | `MOD_SPECIALS` |

Pepper's items need one new config field: a style for the partner's slot
(today `Opponents.slot_style` reads `partner_style` from the data). The
pickup teams need the same for slots 2 and 3, with their looks.

**C. One-sided rules** (new sim code, for the left side only, behind a
`MatchConfig.perks` bit field that is 0 everywhere but the summer, so the
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

The stat items go past the paddles' 9-point budget (bible §5.5), which is
why they are rules and not a new hat: the budget is canon for the ROM's
paddles, and the summer's gear is the remaster's.

Grimsby's tricks are all kind B, existing modifiers for one match:
SPRINKLERS (ICE), BLACKOUT (GLOW), GUSTY (WIND), SHORT NOTICE (SUDDEN
DEATH), ROUGH COURT (POPCORN).

That's 23 items and 5 tricks: enough for a summer to feel different from
the last. More come from the specials and powerups plan
(`SPECIALS_AND_POWERUPS.md`, route B's BIG PADDLE, SNEAKERS, MAGNET...)
once that's decided.

### Events (NOTICE BOARD)

A page like a story scene (`StoryScene`'s dialog panel, or Grimsby's
letterhead) with two or three choices, written in `data/summer.json`.
About 15 to start. For example:

- **A letter from Grimsby Parking Co.:** "SIGN HERE AND THE NEXT MATCH IS
  ON ME." Take the tickets and a trick (SPRINKLERS), or tear it up.
- **The Hendersons' yard sale:** a free common item, or 30 tickets.
- **Pepper's cousin is in town:** play a pickup game with a twist for a
  rare pick, or pass.
- **The ball machine's broken:** fix it (lose 20 tickets) for a gear pick.

## Losing, winning, and between summers

- **Hearts:** 3 to start (2 at HEAT 2 and up). A lost PICKUP or GRUDGE
  match costs one and you go on, with no prize. A lost CHAPTER costs one
  and is played again (as today, Pepper's word in between). At no hearts
  the summer's over: Grimsby's letter ("SEE YOU AT THE VOTE"), the summer
  in numbers, and back to the title. Quitting from the pause menu during a
  match counts as a loss.
- **RELAXED** (a SUMMER page choice): no hearts, losses cost nothing, as
  the story does now. The summer still has its gear.
- **The end:** beating the Champs saves the park: the ending, THE END and
  the epilogue the first time, a card after that; `cleared` goes up, Dale
  Dawson unlocks (as now), and the next HEAT opens.
- **Between summers:**
  - **HEAT 0 to 5**, one per park saved, each adding one thing (the
    opponents err less, two hearts, a trick to start with, fewer PORCH
    stops, chapters to one more point...).
  - **New gear in the pool:** about 12 items at first; the rest come
    with milestones (reach chapter 4, save the park, save it without
    losing a heart, five PRO SHOP visits...). The ACHIEVEMENTS page gets a
    few summer ones.
  - **No lasting stat boosts.** The career player's stats and hats work
    as they do now; a saved park doesn't make the next summer easier
    except through what's in the pool. (Question 5.)
  - **A partner other than Pepper** once you've saved the park? (Question
    6.)

## How it fits today's STORY

It replaces it. STORY on the title opens the SUMMER page: CONTINUE (the
summer in progress, with its chapter and hearts), NEW SUMMER (HEAT,
RELAXED, DIFFICULTY, POINTS), and SCRAPBOOK (the chapter scenes you've
seen, to watch again). The chapter scenes, Grimsby's voice and letters,
the petition card, the ending and the epilogue are all reused as they
are (`story.json`, `StoryScene`); a summer's data is a new
`data/summer.json` next to it. The title's STORY value reads the chapter
and hearts of the summer in progress, or PARK SAVED! x2.

## The save

Today `save.data["story"]` is `{"chapter", "cleared"}`. The chapter's
meaning goes away (a summer's position replaces it), so this is a new
layout, **v7**, with a migration and a test that loads a v6 image:

```
"story": {
  "cleared": 2,            # parks saved (kept from v6)
  "heat": 1,               # the highest HEAT open
  "seen": 255,             # chapter scenes watched, one bit each (v6: the chapters before "chapter")
  "pool": [...],           # gear ids unlocked
  "milestones": 0,         # bits
  "summer": {}             # the summer in progress, {} none
}
"summer": {
  "seed": 4127, "gen": 1, "heat": 0, "relaxed": 0, "difficulty": 2, "points": 5,
  "map": [[{"type": "chapter", "team": 0, "edges": [0, 1, 2]}], ...],
  "at": [3, 1],            # column, lane
  "hearts": 3, "tickets": 45,
  "bag": ["grip_tape", "pepper_dink"],  "tricks": ["sprinklers"],
  "signed": 3,
  "pending": {"kind": "pick", "items": ["...", "...", "..."]}  # an offer not yet taken
}
```

The migration: `cleared` carries over; a v6 save in the middle of the old
story (chapter 4, say) has seen chapters 1 to 3, so their bits are set in
`seen`, and its first summer starts at chapter 1 (the old chapters don't
map onto a summer's hearts and gear). Every value is an int or a string,
as the save requires.

## The screens

All in the game's 960x540 art, the bitmap fonts' characters only (caps,
digits, `!?.,:-'/%+`), panels and labels from `UiKit`, prompts as
`PromptBar`s.

- **THE MAP** (`view/summer_map.gd`): the corkboard (cork texture, the
  clubhouse's wood frame) and a paper map on it, scrolling sideways with
  your position kept left of centre. Stops are pins with an icon on a
  paper tag; the paths are pencil dashes, the one you've walked inked
  over. You and Pepper stand at your pin as the park's walking sprites
  (the match players at their small size, so the faces are the ones the
  game already has) and walk the line to the next stop. The chapter pins
  carry the team's colours and a petition tick once signed. Along the
  top, a strip: hearts (icons, not characters), tickets, signatures n/7,
  the bag's icons; under the map, a panel for the stop you're choosing
  (its name, venue and time, twist, prize). Choosing is a `MenuPage`
  whose rows are the next column's reachable stops by id (`stop_4_1`),
  so tests select by id and the mouse picks a pin; LEFT and RIGHT scroll
  to look ahead.
- **PICK ONE** (`view/gear_pick.gd`): three `UiKit` cards and SKIP;
  each card's icon, name and two lines.
- **PRO SHOP**: a `MenuPage` of items and prices, the shopkeeper's line
  in a dialog panel.
- **NOTICE BOARD** and **PEPPER'S PORCH**: `StoryScene` pages with choice
  rows.
- **SUMMER'S OVER** and **PARK SAVED**: the summer in numbers on a
  panel.
- **The art:** pins, icons (16 x 16 at 2x, about 20 of them) and the
  corkboard drawn in Aseprite like the ball machine (`art/sprites/`),
  in the game's palette; the venue thumbnails on chapter tags cut from the
  level art. A mock-up of the map comes first, for you to look at before
  any art is final.
- **Text never collides** (`test_layout`): new cases for the map at
  every stop in a generated summer (and the longest stop name, the
  fullest bag, 0 and 9 hearts, 999 tickets), every gear card, every event
  page and choice, the shop at its longest list, and the SUMMER page with
  every value of every row, keyboard and pad prompts both.

## Build stages

Each a branch, chained, with its own row on the roadmap when it starts
(the numbers aren't taken yet). Each passes `test.sh` with the golden
traces unchanged.

| Stage | Branch | What | ADR |
|---|---|---|---|
| 1 | `feature/cld-summer-run` | `meta/summer.gd`: the seeded map generator and the run (pure, like `Tournament`); `data/summer.json`; save v7, the migration, the test with a v6 image. No screens. Tests: the same seed gives the same map, the leg rules over 1000 seeds, every path through all eight chapters | One for the mode (replaces ADR-069's flow) |
| 2 | `feature/cld-summer-map` | The map screen with placeholder pins, the SUMMER page, a stop's match and back, hearts and losing, chapters through `StoryScene`. Playable end to end, no gear yet | |
| 3 | `feature/cld-summer-gear` | Gear kinds A and B, PICK ONE, the PRO SHOP, PEPPER'S PORCH, tickets; the slot-style config field | Small: the config field |
| 4 | `feature/cld-summer-perks` | Gear kind C: `MatchConfig.perks`, off in conformance; a view-and-bare-sim test per item | Yes: the one-sided rules |
| 5 | `feature/cld-summer-events` | The NOTICE BOARD's events and Grimsby's tricks, the writing | |
| 6 | `feature/cld-summer-art` | The mock-up, then the corkboard, pins, icons, the walk; screenshots | |
| 7 | `feature/cld-summer-heat` | HEAT, the gear pool's unlocks, achievements, the SCRAPBOOK; tuning with a headless tool that plays summers with a CPU in your place (like `rally_stats.gd`) to set hearts and prices | |

Stages 1 to 3 make a playable summer; 4 to 7 can come in any order after.

## Questions for you

1. **Gates or a bigger map?** The plan keeps all eight chapters as gates
   every path passes (canon: all seven sign). The alternative is a map
   where you meet only some teams and the petition needs, say, five
   signatures: more roguelike, but it changes the bible's story and
   needs the project lead's OK. Gates?
2. **Losing:** three hearts, a lost chapter replayed at a heart's cost,
   and RELAXED for no penalty. Or no hearts at all, and a loss just costs
   the prize?
3. **Replace or keep:** the summer replaces today's eight-chapter STORY
   (the scenes reused, a SCRAPBOOK to rewatch them). Or keep the old one
   as STORY > CHAPTERS beside it?
4. **Length:** 15 to 22 stops, 40 to 60 minutes. Or a SHORT SUMMER (every
   leg one stop) as the default?
5. **Lasting progress:** only new gear in the pool and HEAT; no stat
   boosts that carry over. Should a saved park give something permanent
   (a starting item, a fourth heart)?
6. **Partners:** always Pepper, or once the park is saved, start a summer
   with a captain you've signed (Kiddo, Marge...) as open play's partner
   pick does (ADR-060)? And a second pad in Pepper's place for two
   players?
7. **The one-sided rules (kind C):** fine as story-only gear, or should
   some (SECOND SERVE, KITCHEN PASS) be MODIFIERS for everyone too?
8. **The names:** SUMMER, GEAR, YOUR BAG, TICKETS, HEARTS, HEAT, PRO
   SHOP, NOTICE BOARD, PEPPER'S PORCH. Any you'd change?
