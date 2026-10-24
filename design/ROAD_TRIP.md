# ROAD TRIP: a roguelike mode on a map (a plan)

Asked for 2026-10-23: "Start planning a better story mode: This acts more
like a roguelike. You have a map overview with different paths to the
goal, each stop is a match. Maybe every 1-2 stops there's an upgrade for
your journey." Then: "This doesn't have to follow the bible, we can do a
different story that's on the remaster only." `PORT-82`. **Nothing here
is built.** When it's agreed, each stage below gets its own branch, and
the ones that change play get an ADR.

**Your answers so far** (2026-10-23), worked into the plan below:

1. ROAD TRIP it is. More venues are coming, so the legs take their
   venues from data and new ones slot in.
2. A trip can end: three hearts, no RELAXED option.
3. Separate: ROAD TRIP is its own mode, and STORY (SAVE THE PARK) stays
   as it is.
4. 30 minutes at most.
5. You start with nothing (a plain paddle and a plain hat, no stats, low
   stats overall); later trips slowly raise the stats or give gear.
6. Any captain you've beaten can be your partner.
7. Everything you unlock in ROAD TRIP stays in ROAD TRIP, and nothing
   outside the mode unlocks anything in it.
8. The names are fine.

The **[IMAGE ...]** notes describe art for an image agent to draft. The
brief that applies to all of them is in "The art" near the end.

## The short version

- **The story, the remaster's own.** It's the end of summer, and you and
  your partner (Pepper to start) load the van and drive to the **SUMMER
  OPEN** on the coast, where the Champs defend their title. Every court on
  the way is a stop. A trip is one run, and each trip's map is different.
- **The map is a road map** unfolded on the van's dashboard: roads as
  lines, stops as pins, three legs from home to the coast. Each leg ends
  in a **big match** against a ladder team, and the roads in between fork
  and join, so you choose your way.
- **Stops:** PICKUP GAME (a match against locals), GRUDGE MATCH (a ladder
  team or a hard local team with a twist, for a better prize), YARD SALE
  (a free pick), PRO SHOP, MOTEL (rest), DETOUR (an event), the big
  matches, and the final.
- **You start weak.** A PLAIN PADDLE and a PLAIN CAP, no stats, every
  stat at its lowest. The gear you find on the road (paddles, hats, and
  the rest) is what makes a trip strong.
- **Gear:** after every big match, every grudge match, at every yard sale
  and from some detours, you pick one of three items. No road goes more
  than two stops without a pick.
- **Hearts:** you start with three. A lost match costs one; with no hearts
  left the trip's over.
- **Between trips:** the miles you drove buy lasting upgrades in the
  GARAGE (stats, a heart, starting gear, new gear in the pool), and every
  captain you beat can be your partner on the next trip. The trips get
  harder (HEAT).
- **A closed world:** ROAD TRIP has its own stats, gear, unlocks and
  records. Its matches don't count toward the career, the ladder, the
  hats, ACHIEVEMENTS or Dale Dawson, and none of those carry into it.
  Your career player lends only their look.

## The bible

Not binding here (your call): ROAD TRIP is the remaster's, like the
tournament and the fun venues, and claims nothing about the cartridge. It
goes in `BIBLE_PLAN.md`'s list of the remaster's own additions. Two
habits still apply, because they cost nothing: no real brands, places or
people (the towns are made up, the park unnamed); and the cast keeps its
looks (Pepper, the ladder teams, Dale Dawson), with new scenes but no new
faces.

## The trip

### The map

- **Three legs, left to right.** Each is a stretch of road with its own
  venues and its own ladder teams, listed in `data/trip.json` so new
  venues can be added to a leg:

  | Leg | Where | Venues today | Its ladder teams | Big match (one, by seed) |
  |---|---|---|---|---|
  | 1. Out of town | Home and the lake | PARK, LAKESIDE | Hendersons, Snowbirds, Gym Bros | Snowbirds or Gym Bros |
  | 2. The long drive | Theme parks and odd places | DINOSAUR, UNDERSEA, SPACE, RUINS, GLACIER | Gym Bros, Pirates, Goth Club, Surf Crew | Pirates, Goth Club or Surf Crew |
  | 3. The coast | The beach and the city | SUNSET, LAB, STATION | Surf Crew, Twins | The Twins, then the final |

  The **final** is the SUMMER OPEN against the Champs at SUNSET, at night.
  A leg's other ladder teams turn up as GRUDGE MATCHes, so a trip meets
  some of the eight teams, never all of them, and two trips meet different
  ones. Dale Dawson is a rare grudge match on a back road (he's always
  in the pool, since nothing outside the trip unlocks anything in it).
- **Columns and lanes.** A leg is three columns of stops in three lanes,
  then its big match (a single pin where every lane meets). Roads go from
  a stop to the stops in its own lane and the lanes either side of it in
  the next column, and never cross. Every stop can be reached and leads
  on. You see the whole leg from the start (a ROAD ATLAS item shows what
  each DETOUR is).
- **Length, 30 minutes at most:** 3 legs of 3 stops, plus 2 big matches
  and the final, makes 12 stops, about 8 of them matches. Pickup games are
  first to 3, grudge and big matches first to 5, the final first to 7.
  That's roughly 20 minutes of play, plus the stops without matches and
  the map. The tuning tool (stage 7) times trips and sets the points so a
  typical trip lands under 30. The save keeps the trip between any two
  stops, so it can be played in sittings.
- **Seeded and deterministic.** A trip has a seed, shown small on the map
  as TRIP 4127 so two players can drive the same one. The map, every
  offer, the shop's stock and every detour come from it, using the
  tournament's LCG (`Tournament._roll`) on separate streams (map, picks,
  shop, detours) mixed with the stop's place on the map. Leaving and
  coming back to a pick shows the same three items. The sim isn't
  involved and stays without randomness: this is the meta layer, like the
  tournament's CPU matches.
- **The generated map is saved**, not regenerated from the seed, so a
  release that changes the generator can't change a trip in progress.

> **[IMAGE trip_map_dashboard]** 960 x 540, the map screen's backdrop.
> The view from the driver's seat looking down: the bottom third is the
> van's dashboard (sun-faded teal vinyl, a cassette deck, a hula figure
> on the dash, a pine-tree air freshener hanging at the top right, a
> paper coffee cup in a holder), and the top two thirds is the windscreen
> with a soft-focus summer road and hills, slightly blurred and darker so
> the map reads over it. A fold-out road map lies open across the dash,
> taking the middle 900 x 330. The map itself is a separate image (next).

> **[IMAGE trip_map_paper]** 1800 x 330, wider than the screen (the map
> scrolls sideways). A folded paper road map: off-white paper with two
> vertical fold creases every 300 px, faint pale-green land, a blue lake
> on the left third, tan desert and mountains in the middle third, a blue
> coastline and beach on the right third. Thin grey printed roads, tiny
> printed tree and mountain symbols, a compass rose in one corner, a
> coffee ring stain. No words or numbers (the game prints its own text).
> The pins and drawn roads go on top in code.

### Stop types

| Stop | Pin | What happens | Prize |
|---|---|---|---|
| BIG MATCH | the team's crest | A short scene with the team, then the match at a venue of the leg, with a twist | A gear pick, cash, the captain unlocked |
| FINAL | a trophy | The SUMMER OPEN against the Champs | The trip won |
| PICKUP GAME | a paddle | Doubles against locals | Cash |
| GRUDGE MATCH | a red paddle | A ladder team of the leg, or locals with a modifier (LAVA, ICE, GHOST BALL, POPCORN...) | A gear pick (better odds of rare), cash, a ladder team's captain unlocked |
| YARD SALE | a cardboard box | Pick one of three, free | A gear pick |
| PRO SHOP | an awning | Buy gear, a soda (a heart back), or get rid of a hazard | |
| MOTEL | a neon sign | A heart back, or your partner practises (one partner item gets better) | |
| DETOUR | a road sign | A page of text with two or three choices (below) | Varies |

Rules for a leg, checked over a thousand seeds in the tests: at most one
GRUDGE MATCH, one PRO SHOP and one YARD SALE per column; no MOTEL in leg
1; along every road, a pick at least every two stops, and no stop type
twice in a row; every leg has a road with three matches and one with
one.

> **[IMAGE trip_pins]** A sheet of 9 map pins, each 32 x 40: a round
> pushpin head on a short needle, the head carrying a 24 x 24 icon. Icons:
> a team crest (a plain shield, recoloured in code per team), a gold
> trophy, a paddle, a red paddle, a cardboard box with a lamp poking out,
> a striped shop awning, a motel's neon sign (an arrow), a yellow diamond
> road sign with a "?" shape (drawn, not lettered), and a small "you are
> here" van-front icon. Each pin also has a 50%-grey "already passed"
> version.

> **[IMAGE trip_van]** The van, 64 x 40, side view facing right, as a
> sprite sheet: 4 driving frames (wheels turning, a small bounce) and 1
> parked frame. A boxy late-80s minivan, two-tone (cream over sky blue), a
> paddle bag strapped to the roof rack, two side windows where the game
> draws the player and partner heads (leave those windows dark and plain).

### A stop's match

- **Doubles, you and your partner.** You look like the active career
  player, or MATCH SETUP's look if there's none, but you play with the
  trip's stats and gear (below), not the career's.
- **Big matches and the ladder teams' grudge matches:** the team, its
  style, a venue of the leg and a twist. The ladder is already tuned so
  every rung is harder (SNES ADR-062), so the legs' teams are the ramp.
- **Pickup games:** two locals. Their look is built from the existing
  player sprites (shirt, body, skin, hair, hat: the same long-chinned
  players, no new faces), their names come from a list in the data (THE
  MAIL CARRIERS, LUNCH BREAK, THE NIGHT SHIFT...), and their play starts
  below the leg's easiest team and rises through the leg.
- **Difficulty:** the trip's own, not MATCH SETUP's. Leg 1 is tuned to be
  winnable with the starting stats, and HEAT adds to it. The points are
  fixed by the trip (above).

### The story

Short and light, in the existing scene style (`StoryScene`: the venue
behind, the speakers side by side, a dialog panel): a page or two at the
start, one before each big match and the final, and a closing scene.
Your partner does most of the talking (each captain partner gets a few
lines of their own). Each ladder team gets a scene about why they're on
the road: the Snowbirds on their way to Florida, the Pirates "between
ships", the Gym Bros on a protein tour. Running gags: a van that breaks
down, a rival team that keeps turning up, a mixtape. Written in
`data/trip.json`; I'd draft it in stage 5 for you to edit. The first trip
plays the scenes in full; later trips show a page each, and START skips.

> **[IMAGE trip_scene_roadside]** 960 x 540, a scene backdrop in the
> venues' layered style (sky, far, mid, near as separate layers if
> possible): a two-lane desert highway at golden hour, the van parked on
> the gravel shoulder with its hood up, a lone mailbox, telephone poles
> and distant mesas. The lower 200 px stay calm (the speakers and the
> dialog panel cover them).

> **[IMAGE trip_scene_motel]** 960 x 540, the same layered style: a
> one-storey roadside motel at dusk, a row of doors, an ice machine, a
> drained swimming pool with a pickleball net strung across it, a tall
> neon arrow sign (its tubes lit pink and teal, no letters).

> **[IMAGE trip_scene_yard_sale]** 960 x 540: a suburban front lawn on a
> sunny afternoon, folding tables of junk (lamps, board games, old
> paddles in a bucket, a box of tennis balls), a hand-drawn sign shape
> with no text, a station wagon in the driveway.

> **[IMAGE trip_scene_pro_shop]** 960 x 540: inside a small sporting goods
> shop, a wall of paddles on pegs, a rack of caps and visors, a glass
> counter with an old cash register, a soda cooler, a sun-bleached poster
> of a smash (no text, no logos).

> **[IMAGE trip_scene_summer_open]** 960 x 540: the final's arrival: a
> beach court at night under string lights and two tall light towers,
> pennant flags, small bleachers packed with a crowd (silhouettes), a
> trophy table at the net post, the ocean behind with a moon on it.

## You, your partner, and their stats

### The trip's stats

Four stats, 0 to 9, kept by the trip and passed to the match:

| Stat | What it moves | Start |
|---|---|---|
| POWER | Pace (as a paddle's POWER) | 1 |
| CONTROL | How much a stretched contact sprays (as CONTROL) | 1 |
| SPEED | Swing recovery and swing limit (as the paddle's SPEED) | 1 |
| FEET | How fast you run | 1 |

The first three use the paddles' rule (each point away from 3 moves a
tunable by 3/64 of its standard value, `Paddles`); a step that size may
be too small for 1 against 9 to feel different, so the trip may use a
bigger one (stage 7 tunes it). FEET is new. The ROM's paddles (the
9-point budget, the hats' one-point trades) don't apply in the trip; it
needs a config field that gives a slot its stats directly, which is a sim
change, behind the switch below.

### Gear slots

You carry **one paddle, one hat, and up to six bag items**. A paddle or
hat you pick replaces the one you hold (the card shows the swap).
Paddles and hats are the game's own, so the sprites show them with no new
art:

| Gear | Effect | Look |
|---|---|---|
| PLAIN PADDLE (start) | Nothing | A blank paddle |
| PLAIN CAP (start) | Nothing | The cap |
| WOOD PADDLE | +3 CONTROL | Wood |
| BLUE PADDLE | +1 POWER, +1 CONTROL, +1 SPEED | Blue |
| RED PADDLE | +3 POWER | Red |
| GOLD PADDLE | +3 SPEED | Gold |
| VISOR | +2 CONTROL | Visor |
| HEADBAND | +2 SPEED | Headband |
| TRICORN | +2 POWER | Tricorn |
| BANDANA | +1 POWER, +1 FEET | Bandana |
| BEANIE | +2 FEET | Beanie |

The other hats (VIKING, CHEF, CROWN, WHIRLY, BUCKET...) are rarer finds,
each with its own small trade, or kept as GARAGE looks.

> **[IMAGE trip_paddle_plain]** A new paddle look for the player rig: the
> PLAIN PADDLE, an unpainted pale plywood paddle with a black taped
> handle, at the size and angle of the existing paddles in
> `art/sprites/hd` (it replaces the paddle's colours only, so the drawing
> is the existing paddle with a plain palette).

### Your partner

Pepper to start. Beating a ladder team in a big match or grudge match
unlocks its captain (DAD, MARGE, BRAD, PETE, RAVEN, KAI, MAX, ACE, and
DALE DAWSON) as a partner for later trips, picked on NEW TRIP. Each plays
in their own style (Dad stays back, Pete plays the kitchen line, Ace does
everything), at the trip's level. Partners start with their own stats,
lower than they have on the ladder, and partner gear raises them. Ace,
the Champs' captain, comes only from winning a trip.

## Gear (the upgrades)

### How it's offered

- **Pick one of three** after a big match, a grudge match, at a yard
  sale, and from some detours: three cards side by side (icon, name, two
  lines), and SKIP for a little cash. A LUCKY PENNY makes it four.
- **Rarity:** common, uncommon, rare; a grudge match leans rare. No
  duplicates unless the item says it stacks.
- **Hazards** are the opposite: a detour or a bad bet puts one in your
  bag (FLAT TIRE: the next match is on ICE, you're late and rushed).
  They're lifted after a match or at the PRO SHOP.

> **[IMAGE trip_card]** 200 x 260, the frame for a pick card, nine-slice
> friendly (16 px corners): a cream index card with a thin coloured top
> band (one version each for common grey, uncommon blue, rare gold), a
> pushpin at the top centre, a slight paper texture. A 64 x 64 window near
> the top for the item's icon, and the lower half blank for text.

### The kinds

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

**B. Settings the game already has** (a `MatchConfig` field set from the
trip; no new rule in the sim):

| Item | Effect | The setting |
|---|---|---|
| UMBRELLA | The next match's twist is lifted | `modifiers` |
| DINK DRILL | Your partner plays the kitchen line and dinks | the partner's `AiStyle` (net, volley, dink_period) |
| PARTNER'S SHOES | Your partner gets to more balls | the partner's `AiStyle.speed` |
| LOB LESSON | Your partner lobs teams that rush the net | `lob_distance` |
| SCOUTING REPORT | Your partner covers the middle and picks on the weaker player | `team`, `tactics` |
| PICKLE JAR | SPECIALS on for your matches (both sides' meters, ADR-080) | `MOD_SPECIALS` |

The partner items need a config field that gives the partner's slot a
style (today `Opponents.slot_style` reads it from the data); the locals
need the same for slots 2 and 3, with their looks.

**C. Stats and one-sided rules** (new sim code, behind a
`MatchConfig.trip` switch that is off everywhere but ROAD TRIP, so the
ROM's game, the golden traces and the conformance replay never see it,
as `MatchConfig.overhead` does; one ADR for the set, ints only). The
paddles and hats above are this kind, and so are:

| Item | Effect |
|---|---|
| GRIP TAPE | +1 CONTROL (stacks) |
| WRIST WEIGHTS | +1 POWER (stacks) |
| NEW SNEAKERS | +1 FEET (stacks) |
| SWEATBAND | +1 SPEED (stacks) |
| LONG ARMS | Your reach as with BIG BALL, without the big ball |
| SECOND SERVE | A serve into the net or out is taken again, once a game |
| KITCHEN PASS | Your side's first KITCHEN! of a match is a let |
| LUCKY LINE | Once a match, your ball out by a hair is called in (the close-call replay says LUCKY!) |
| HEAD START | Every match starts 1-0 to you |
| SECOND WIND | At match point against you, your side runs faster |
| HOT HAND | Three points in a row and your next shot is a PICKLE SMASH |

Hazards are kind B, existing modifiers for one match: FLAT TIRE (ICE),
POWER CUT (GLOW), STORM (WIND), LATE START (SUDDEN DEATH), POTHOLES
(POPCORN).

That's 9 paddles and hats, 23 items and 5 hazards to start. More can come
from the specials and powerups plan (`SPECIALS_AND_POWERUPS.md`, route
B's BIG PADDLE, MAGNET...).

> **[IMAGE trip_gear_icons]** A sheet of 64 x 64 item icons, one per item,
> drawn as objects, not symbols, on a transparent background, lit from the
> top left with a dark outline: a spare paddle, a pink piggy bank, a
> coupon booklet, a copper penny, a folded road atlas, a torn ticket stub
> (RAIN CHECK), a striped umbrella, a pair of high-top sneakers, a coiled
> roll of grip tape, wrist weights, a terrycloth sweatband, a reach-grabber
> tool (LONG ARMS), a second ball in a hand (SECOND SERVE), a laminated
> pass on a lanyard (KITCHEN PASS), a four-leaf clover on a chalk line
> (LUCKY LINE), a starting flag (HEAD START), a gust of wind with sweat
> drops (SECOND WIND), a flaming paddle (HOT HAND), a pickle jar (PICKLE
> JAR), a clipboard with Xs and Os (SCOUTING REPORT and DINK DRILL as two
> variants), a lob arc over a net (LOB LESSON), a paddle bag (PARTNER'S
> SHOES as shoes in a bag). The paddles and hats get icons too: each
> existing paddle colour and hat, drawn front-on.

> **[IMAGE trip_hazard_icons]** Five 64 x 64 icons in the same style with
> a red warning border: a flat tyre, a dark light bulb, a storm cloud with
> wind lines, a stopwatch, a pothole with a cracked edge.

### Detours

A page like a story scene with two or three choices, written in
`data/trip.json`. About 15 to start. For example:

- **A hitchhiker with a paddle:** give them a lift (a pickup game with
  them as your partner, for a rare pick), or drive on.
- **A roadside stand:** a free common item, or 30 cash.
- **A shortcut:** skip the next stop, but take a hazard (STORM).
- **The van's making a noise:** pay 20 cash to fix it, or risk a FLAT
  TIRE.

## Losing, winning, and between trips

- **Hearts:** 3 to start. A lost PICKUP or GRUDGE match costs one and you
  drive on, with no prize. A lost BIG MATCH costs one and is played again
  (your partner has a word in between). With no hearts the trip's over:
  the van turns for home, the trip in numbers, then the GARAGE. Quitting
  from the pause menu during a match counts as a loss.
- **The end:** win the SUMMER OPEN: the trophy, the closing scene the
  first time (a card after that), and the next HEAT opens.
- **MILES:** every stop reached adds miles (more for later legs, a bonus
  for a win). They're kept between trips, won or lost, and spent in the
  GARAGE.
- **The GARAGE** (between trips, and from ROAD TRIP's page): lasting
  upgrades, each a little dearer than the last:
  - **Stats:** +1 to a starting stat (up to 4).
  - **A fourth heart** (once).
  - **Starting cash.**
  - **A starting item:** begin with one common item you've found before.
  - **New gear in the pool:** about 12 items are in the pool at first;
    the rest are bought here or come with milestones (reach leg 2, win a
    trip, win one without losing a heart).
  - **Looks:** the van's paint, the dashboard's ornament (cosmetic).
  So the first trips are short and hard, and each one leaves you a little
  stronger, as you asked. (An alternative: no shop, and the miles fill a
  bar whose steps give fixed rewards in order. Question 2.)
- **HEAT 0 to 5:** one more level opens per trip won, each adding one
  thing (the opponents err less, a hazard to start with, fewer MOTELs,
  big matches to one more point...). Picked on NEW TRIP.
- **ROAD TRIP's own records:** trips, trips won, best HEAT, the fastest
  win, captains unlocked, on its own page (not RECORDS or ACHIEVEMENTS).

> **[IMAGE trip_garage]** 960 x 540: a cluttered home garage, the van
> parked nose-in on the left half with its side door open, a workbench and
> pegboard on the right (paddles, caps and tools on hooks), a calendar
> with summer days crossed off (no readable text), a strip light
> overhead, a pickleball rolling on the concrete floor. The right half
> stays fairly plain behind where the GARAGE's menu panel sits.

## Where it sits

ROAD TRIP is its own row on MAIN, after STORY. Its page: CONTINUE (the
trip in progress: its leg, hearts and partner), NEW TRIP (PARTNER, HEAT),
GARAGE, and RECORDS. The title's ROAD TRIP value reads the trip in
progress (LEG 2, 3 HEARTS) or the trips won. STORY (SAVE THE PARK) is
unchanged. The scenes reuse `StoryScene`; the trip's data is
`data/trip.json`; the code is `meta/trip.gd` and `view/trip_*.gd`.

> **[IMAGE trip_title_card]** 640 x 200, the mode's logo: the words ROAD
> TRIP in a chunky 80s road-sign style (the one place text is drawn into
> art), the van driving out of the letters' right side with a dust trail,
> a small pickleball paddle on the roof. A transparent background.

## The save

STORY's key keeps its meaning, so the trip is a new key with a harmless
default (`{}`), filled in on load as the save does for new keys: the
layout stays **v6**, with no migration (a test still loads a save without
the key).

```
"trip": {
  "miles": 820,            # unspent
  "won": 2, "trips": 9,    # records
  "best_heat": 1, "fastest": 1730,   # seconds
  "heat": 1,               # the highest HEAT open
  "garage": {"stats": [1, 0, 2, 0], "heart": 1, "cash": 1, "start_item": "grip_tape", "van": 2},
  "pool": [...],           # gear ids unlocked
  "partners": [0, 3],      # captains unlocked (ladder team indices; Pepper is always there)
  "milestones": 0,         # bits
  "seen": 0,               # scenes watched once, one bit each
  "now": {                 # the trip in progress, {} none
    "seed": 4127, "gen": 1, "heat": 0, "partner": -1,
    "map": [[{"type": "pickup", "venue": "lakeside", "edges": [0, 1]}, ...], ...],
    "at": [1, 2, 0],       # leg, column, lane
    "hearts": 3, "cash": 45, "stats": [1, 1, 2, 1],
    "paddle": "red", "hat": "visor",
    "bag": ["grip_tape", "dink_drill"], "hazards": ["storm"],
    "pending": {"kind": "pick", "items": ["...", "...", "..."]}
  }
}
```

Every value is an int or a string, as the save requires.

## The screens

All drawn at 960x540 in the game's style, using only the bitmap fonts'
characters (caps, digits, `!?.,:-'/%+`: so CASH 45, not $45). Panels and
labels come from `UiKit`, and prompts are `PromptBar`s.

- **THE MAP** (`view/trip_map.gd`): the dashboard backdrop with the paper
  map on it, scrolling sideways with your position kept left of centre.
  Stops are pins; roads are drawn lines, and the ones you've driven are
  inked over in red pen. The van sits at your pin and drives the road to
  the next stop, with you and your partner in its windows (the match
  players' heads at their small size, so the faces are the ones the game
  already has). Big-match pins carry the team's colours. Along the top
  runs a strip: hearts (icons, not characters), cash, the leg, your paddle
  and hat, and the bag's icons. Under the map, a panel shows the stop
  you're choosing: its name, venue and time, twist and prize. Choosing is
  a `MenuPage` whose rows are the reachable stops in the next column, by
  id (`stop_2_1_1`), so tests select by id and the mouse picks a pin.
  LEFT and RIGHT scroll to look ahead.
- **PICK ONE** (`view/trip_pick.gd`): three cards and SKIP.
- **PRO SHOP** and **GARAGE**: `MenuPage`s of items and prices.
- **DETOUR**, **YARD SALE** and **MOTEL**: `StoryScene` pages with choice
  rows.
- **TRIP'S OVER** and **CHAMPIONS!**: the trip in numbers on a panel,
  then the miles counted up.
- **Text never collides** (`test_layout`): new cases for the map at
  every stop in a generated trip (and the longest stop name, the
  fullest bag, 0 and 9 hearts, 999 cash), every card, every detour page
  and choice, the shop and garage at their longest lists, and ROAD TRIP's
  page with every value of every row, with keyboard and pad prompts.

> **[IMAGE trip_hud_icons]** 24 x 24 icons for the map's top strip: a red
> heart, a green dollar-bill bundle (no digits or symbols on it), a small
> odometer (MILES), a HEAT flame in three strengths (yellow, orange,
> red).

### The art

The brief for every [IMAGE] note above, for whoever drafts them:

- **The style:** the game's HD pixel art, as in the venues
  (`game/assets/levels/venues/`), the park's props
  (`game/assets/park/`: the bench is 82 x 32, the ball machine 64 x 76)
  and the dinosaurs (`game/assets/dinos/`). Hard pixel edges, no
  anti-aliasing or blur except where a note asks for soft focus, a dark
  one-pixel outline on objects, light from the top left, a limited palette
  sampled from the venues' art (sunny, saturated, early-90s).
- **No people.** The players, partners and locals are drawn by the game
  from the existing rig, and those long-chinned faces stay as they are.
  The art holds places for them; it never draws them.
- **No text, logos or brands** in any image except the title card. The
  game prints all words in its bitmap fonts.
- **Sizes** are the final on-screen size at 960x540; draw at that size
  (or at half and scale by an exact 2x).
- **Drafts first:** the generated art is a draft for you to look at.
  Nothing is final until you've approved it, and the map gets a mock-up
  in the game (stage 6) before the art is polished.

## Build stages

Each stage is a branch, chained, with its own row on the roadmap when it
starts (the numbers aren't taken yet). Each passes `test.sh` with the
golden traces unchanged.

| Stage | Branch | What | ADR |
|---|---|---|---|
| 1 | `feature/cld-trip-run` | `meta/trip.gd`: the seeded map generator and the trip (pure, like `Tournament`); `data/trip.json`; the save key. No screens. Tests: the same seed gives the same map, the leg rules over 1000 seeds, every road reaching the final | One for the mode |
| 2 | `feature/cld-trip-stats` | `MatchConfig.trip`: a slot's stats (POWER, CONTROL, SPEED, FEET) and style from the config, off everywhere else; a view-and-bare-sim test | Yes: the sim change |
| 3 | `feature/cld-trip-map` | The map screen with placeholder pins, ROAD TRIP's page, a stop's match and back, hearts and losing, the big matches and final. Playable end to end with the starting gear | |
| 4 | `feature/cld-trip-gear` | Paddles and hats, kinds A and B, PICK ONE, YARD SALE, the PRO SHOP, MOTEL, cash, partners unlocked | |
| 5 | `feature/cld-trip-story` | The scenes and detours, the hazards, the writing; kind C's one-sided rules | Amends stage 2's |
| 6 | `feature/cld-trip-art` | The map mock-up, then the generated art from the notes above, polished; screenshots | |
| 7 | `feature/cld-trip-garage` | MILES, the GARAGE, HEAT, the pool's unlocks, the records page; a headless tool that plays trips with a CPU in your place (like `rally_stats.gd`) to time them (30 minutes at most) and set the stat step, hearts and prices | |

Stages 1 to 4 make a playable trip; 5 to 7 can come in any order after.

## Questions for you

The first round is answered (top of the doc). New ones:

1. **The stat step:** a paddle point is 3/64 (about 5%) of a tunable, so
   1 against 9 in every stat is a big gap but 1 against 2 is hard to
   feel. I'd let the tuning tool (stage 7) set it. Or would you rather
   name a feel ("a fully geared player is about twice as strong as a new
   one")?
2. **The GARAGE:** choose your own lasting upgrades with MILES (the plan),
   or a fixed ladder of rewards that the miles fill in order?
3. **Cosmetics in the GARAGE** (the van's paint, the dash ornament): worth
   having, or keep the garage to stats and gear?
