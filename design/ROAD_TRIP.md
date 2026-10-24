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

And the second round:

9. A stat has room to grow: 20 points before it's full.
10. The GARAGE is a fixed ladder of rewards the miles fill in order.
11. Cosmetics are in (on the ladder).

**Built (2026-10-24, `feature/cld-trip-run`; port ADR-087):** the plan's
stages 1 to 5 and 7, and the art imported (stage 6): ROAD TRIP is on
MAIN and playable from start to finish. What's not built, or built
differently, is listed under "Built so far" at the end.

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
- **Between trips:** the miles you drove fill the GARAGE's ladder of
  lasting rewards, one step after another (stats, a heart, starting gear,
  new gear in the pool, paint and ornaments for the van), and every
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

> **[IMAGE trip_map_dashboard]** 960 x 540, the map screen's backdrop,
> seen from the driver's seat, level (no tilt or perspective on the dash
> top, so the flat map drawn on it in code sits right). The bottom 120 px
> are the van's dashboard front: sun-faded teal vinyl, a cassette deck in
> the middle, two round gauges with plain dials (no numbers or marks), a
> paper coffee cup in a holder at the right. Above it, the dash top: a
> flat, empty strip of teal vinyl from x 30 to x 930 and y 190 to y 420,
> **with no map, paper or objects on it** (the game draws the map there).
> The only things on the dash top are at the far left (an empty round
> spot for the ornament, 48 x 64, drawn in code) and nothing at the right.
> The top 190 px are the windscreen: a soft-focus coastal road and hills,
> darker and less saturated so the map reads over it, the rear-view
> mirror's edge at the top right with an empty hook under it (the air
> freshener is drawn in code). No steering wheel in the map's area.

> **[IMAGE trip_map_paper]** Exactly 1800 x 330, flat and seen from
> straight above, wider than the screen (the map scrolls sideways). A
> folded paper road map: off-white paper with vertical fold creases
> exactly every 300 px, faint pale-green land with a blue lake in the
> first 600 px, tan desert and mountains from 600 to 1200, green hills, a
> blue coastline and beach from 1200 to 1800. Thin grey printed roads,
> small printed tree, cactus and mountain symbols, a compass rose in the
> bottom right corner, a coffee ring stain bottom left. Keep the middle
> band (y 60 to 270) light and sparse: the pins and drawn roads go on top
> in code. No words, numbers or letters. (The first draft is the right
> idea: keep its look, at this exact size.)

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

> **[IMAGE trip_pins]** A transparent PNG sheet, 9 columns x 2 rows of
> exactly 32 x 40 cells, nothing between them. Each pin: a round cream
> pushpin head 28 px across at the top of its cell, a 4 px grey needle
> below, no shadow, glow or ground shadow. On the head, a simple icon in
> kept simple enough to read at this size: a shield
> (**plain mid-grey, light and dark grey only**, so the game can tint it
> to each team's colours), a gold trophy, a blue paddle, a red paddle, a
> cardboard box with a lamp poking out, a red and white striped awning, a
> pink arrow sign, a yellow diamond with a "?" shape (the one symbol
> allowed), and the front of **our van** (`trip_van`'s boxy cream-over-blue
> minivan, not a VW bus). Row 2: the same 9, desaturated to grey and a
> little darker, for stops already passed.

> **[IMAGE trip_van]** A transparent PNG sheet of 5 cells, each exactly 64
> x 40, side view facing right, the **one drawing of the van** every other
> image follows (the first set's side-view van is the look to keep): a
> boxy late-80s minivan, cream over sky blue, a dark blue paddle bag
> strapped to the roof rack, black tyres with grey hubs. Its windows, front
> to back: the sloped windscreen's edge, **the driver's door window**
> (glass with a highlight, like a real van's), then two passenger windows
> behind it, plain dark blue with no reflections (the game draws the
> player and partner heads in those two). Frames 1 to 4 driving: the
> wheels' hubs turn a quarter each frame and the body bobs 1 px on frames
> 2 and 4; everything else the same. Frame 5 parked.

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
> and distant mesas. The lower 200 px carry on the scene (the gravel
> shoulder, scrub, the road's edge) in lower contrast, not a flat fill:
> the speakers and the dialog panel stand over them.

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
> pennant flags, small bleachers packed with a crowd (dark silhouettes
> only, no faces), a trophy table at the net post, the ocean behind with
> a moon on it. The crowd sits in the middle band; **the bottom 200 px are
> sand and court in lower contrast** (not a flat fill), for the speakers
> and the dialog panel.

## You, your partner, and their stats

### The trip's stats

Four stats, 1 to 20, kept by the trip and passed to the match:

| Stat | What it moves | Start |
|---|---|---|
| POWER | Pace (as a paddle's POWER) | 1 |
| CONTROL | How much a stretched contact sprays (as CONTROL) | 1 |
| SPEED | Swing recovery and swing limit (as the paddle's SPEED) | 1 |
| FEET | How fast you run | 1 |

- **The scale:** the game's standard player (the blue paddle, 3/3/3)
  sits at about **8** on it, so a new driver at 1 is clearly weaker than
  anyone outside the trip, a well-geared trip gets past 8 by leg 3, and
  20 is far beyond the ROM's strongest paddle. Each point moves a tunable
  by a fixed step (as the paddles do, `Paddles`: 3/64 a point there),
  sized so 1 to 20 spans about half to one and a half times the standard
  value. The tuning tool (stage 7) sets the step so a few points are
  felt, and so a geared driver at the final is about where the Champs are.
- **FEET** is new: the run speed, on the same scale.
- The ROM's paddles (the 9-point budget, the hats' one-point trades)
  don't apply in the trip. It needs a config field that gives a slot its
  stats directly, which is a sim change, behind the switch below.

### Gear slots

You carry **one paddle, one hat, and up to six bag items**. A paddle or
hat you pick replaces the one you hold (the card shows the swap).
Paddles and hats are the game's own, so the sprites show them with no new
art:

| Gear | Effect | Look |
|---|---|---|
| PLAIN PADDLE (start) | Nothing | A blank paddle |
| PLAIN CAP (start) | Nothing | The cap |
| WOOD PADDLE | +5 CONTROL | Wood |
| BLUE PADDLE | +2 POWER, +2 CONTROL, +2 SPEED | Blue |
| RED PADDLE | +5 POWER | Red |
| GOLD PADDLE | +5 SPEED | Gold |
| VISOR | +3 CONTROL | Visor |
| HEADBAND | +3 SPEED | Headband |
| TRICORN | +3 POWER | Tricorn |
| BANDANA | +2 POWER, +2 FEET | Bandana |
| BEANIE | +3 FEET | Beanie |

The other hats (VIKING, CHEF, CROWN, WHIRLY, BUCKET...) are rarer finds,
each with its own small trade, or kept as GARAGE looks.

> **[IMAGE trip_paddle_plain]** Not a new drawing: the existing paddle in
> the player rig (`art/sprites/hd`), recoloured as a PLAIN PADDLE:
> unpainted pale plywood face (two tones), a black taped handle. Deliver
> it as the palette (the colours replacing the paddle's), plus one 64 x 64
> icon of it, front-on, for the gear card.

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

> **[IMAGE trip_card]** A transparent PNG sheet of 3 cards, each exactly
> 200 x 260, for nine-slice (the corners are 16 x 16 and the edges between
> them repeat cleanly). A cream index card, flat colour with a light
> paper speckle, a 1 px dark outline, a 12 px coloured band along the top
> (grey for common, blue for uncommon, gold for rare), a red pushpin at
> the top centre. An empty 64 x 64 window (a 2 px darker frame, a plain
> fill) centred 24 px below the band. The lower half blank. No shadow.

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
| GRIP TAPE | +2 CONTROL (stacks) |
| WRIST WEIGHTS | +2 POWER (stacks) |
| NEW SNEAKERS | +2 FEET (stacks) |
| SWEATBAND | +2 SPEED (stacks) |
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

> **[IMAGE trip_gear_icons]** A transparent PNG sheet on an exact grid of
> 64 x 64 cells, one item per cell in the order below, each object drawn
> whole inside its cell with a 2 px margin; no background, gradient,
> glow or cast shadow. Objects, not symbols, lit from the top left, a dark
> outline. **No letters, digits, % or other
> symbols on any object** (the rain check is a plain torn ticket stub, the
> coupon book has blank coupons). Items: a spare paddle, a pink piggy
> bank, a coupon booklet, a copper penny, a folded road atlas, a torn
> ticket stub, a striped umbrella, a pair of high-top sneakers, a roll of
> grip tape, wrist weights, a terrycloth sweatband, a reach-grabber tool, a
> hand holding a second ball, a blank laminated pass on a lanyard, a
> four-leaf clover on a chalk line, a chequered starting flag, a gust of
> wind with sweat drops, a flaming paddle, a pickle jar, a clipboard with
> Xs and Os, a clipboard with a dink's short arc, a lob's high arc over a
> net, a pair of shoes in a paddle bag. Then the 4 paddles (wood, blue,
> red, gold) and, for the hats, **the game's own hats** drawn front-on as
> the player sprites wear them (`data/career.json`'s hats: VISOR,
> HEADBAND, TRICORN, BANDANA, BEANIE, and the rest), not new caps.

> **[IMAGE trip_hazard_icons]** A transparent PNG sheet of 5 cells, 64 x
> 64, the gear icons' style with a 3 px red border: **a flat tyre on its
> own** (no car), a dark light bulb, a storm cloud with wind lines, a
> stopwatch with a blank face, a pothole with a cracked edge.

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
  for a win). They're kept between trips, won or lost, and they fill the
  GARAGE's ladder.
- **The GARAGE** (after every trip, and from ROAD TRIP's page): a fixed
  ladder of lasting rewards, the same for everyone, that the miles fill
  in order. Nothing to choose: after a trip the miles count up and each
  step reached is handed over with a little fanfare; the page shows the
  steps you have and the next three ahead. Each step costs a little more
  than the last, so the first trips pay out often and later ones slowly.
  So the first trips are short and hard, and each one leaves you a little
  stronger. A first draft of the ladder (`data/trip.json`; stage 7 sets
  the miles):

  | Step | Reward |
  |---|---|
  | 1 | +1 FEET to start |
  | 2 | New gear in the pool: GRIP TAPE, SWEATBAND |
  | 3 | Van paint: CHERRY |
  | 4 | +1 POWER to start |
  | 5 | Start with 20 cash |
  | 6 | +1 CONTROL to start |
  | 7 | Dash ornament: the pickle bobblehead |
  | 8 | New gear: SECOND SERVE, ROAD ATLAS |
  | 9 | +1 SPEED to start |
  | 10 | Start with a BLUE PADDLE |
  | 11 | Van paint: WOOD PANEL |
  | 12 | A fourth heart |
  | 13 | New gear: HOT HAND, LUCKY LINE |
  | 14 | +1 to every starting stat |
  | 15 | Dash ornament: the fuzzy dice |
  | 16 | Start with a common item from your last trip |
  | ... | More steps of the same kinds, up to +4 a stat at the top |

  About 12 items are in the pool at first; the rest come from the ladder
  and from milestones (reach leg 2, win a trip, win one without losing a
  heart).
- **Cosmetics** on the ladder and from milestones: the van's paint, the
  ornament on the dash, the air freshener, the cassette in the deck (the
  map screen's music), and the map's pen colour. Picked on the GARAGE
  page once you have them; looks only.
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

> **[IMAGE trip_van_paints]** **Recolours of `trip_van`, not new
> drawings:** the same pixels, side view, frame 5 (parked), with only the
> body's colours changed. Deliver each as the van sheet's palette with
> the body colours replaced: CREAM AND SKY (the start), CHERRY (red with a
> white stripe), WOOD PANEL (cream with wood-brown lower panels), SUNSET
> (orange over purple), MIDNIGHT (dark blue with a light blue stripe).

> **[IMAGE trip_dash_ornaments]** A transparent PNG sheet. Dash ornaments,
> each in a 48 x 64 cell, standing on the same base line so any of them
> sits on the dash's ornament spot: the hula figure (the start), a pickle
> bobblehead with a paddle, a plastic dinosaur, a snow globe, a tiny
> trophy; and fuzzy dice in a 48 x 64 cell hanging from a string at the
> top (they hang from the mirror instead). Air fresheners, 20 x 40, on a
> string: **a cherry, a lemon, a pickle and a pineapple (no tree
> shapes)**. Cassettes, 40 x 26, a coloured shell each (red, blue,
> purple, yellow) with a blank label.

> **[IMAGE trip_ladder_step]** A transparent PNG sheet of 3 tags, each
> exactly 120 x 72: a manila shipping tag on a short string, with **an
> empty 48 x 48 window** (a plain lighter fill and a 1 px frame, nothing
> drawn in it: the game draws each reward's icon there). One plain, one
> "reached" with a red rubber-stamp ring around the window (the ring only,
> no words), one "next" a little greyed.

## Where it sits

ROAD TRIP is its own row on MAIN, after STORY. Its page: CONTINUE (the
trip in progress: its leg, hearts and partner), NEW TRIP (PARTNER, HEAT),
GARAGE, and RECORDS. The title's ROAD TRIP value reads the trip in
progress (LEG 2, 3 HEARTS) or the trips won. STORY (SAVE THE PARK) is
unchanged. The scenes reuse `StoryScene`; the trip's data is
`data/trip.json`; the code is `meta/trip.gd` and `view/trip_*.gd`.

> **[IMAGE trip_title_card]** A transparent PNG, 640 x 200, the mode's
> logo: **ROAD TRIP as two words** in a chunky 80s road-sign style (the
> one place letters are drawn into art), a dark outline, the van
> (`trip_van`'s drawing, larger) driving out of the letters' right side
> with a dust trail, a pickleball paddle on its roof.

## The save

STORY's key keeps its meaning, so the trip is a new key with a harmless
default (`{}`), filled in on load as the save does for new keys: the
layout stays **v6**, with no migration (a test still loads a save without
the key).

```
"trip": {
  "miles": 820,            # all miles driven; the ladder's steps reached follow from it
  "won": 2, "trips": 9,    # records
  "best_heat": 1, "fastest": 1730,   # seconds
  "heat": 1,               # the highest HEAT open
  "looks": {"van": 2, "ornament": 1, "freshener": 0, "tape": 0, "pen": 0},  # cosmetics chosen
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
- **PRO SHOP**: a `MenuPage` of items and prices.
- **GARAGE**: the ladder as a row of tags (reached, next, ahead), the
  miles counting up after a trip, and a `MenuPage` for the looks you
  have.
- **DETOUR**, **YARD SALE** and **MOTEL**: `StoryScene` pages with choice
  rows.
- **TRIP'S OVER** and **CHAMPIONS!**: the trip in numbers on a panel,
  then the miles counted up.
- **Text never collides** (`test_layout`): new cases for the map at
  every stop in a generated trip (and the longest stop name, the
  fullest bag, 0 and 9 hearts, 999 cash), every card, every detour page
  and choice, the shop at its longest list, the garage's ladder at every step, and ROAD TRIP's
  page with every value of every row, with keyboard and pad prompts.

> **[IMAGE trip_hud_icons]** A transparent PNG sheet of 24 x 24 cells: a red heart, a red heart's empty outline (a lost
> heart), a green bundle of bills (plain, no symbols), an odometer
> **with blank wheels and no lettering** (the game prints the miles), and
> a flame in three strengths (yellow, orange, red).

### The art

The brief for every [IMAGE] note above, for whoever drafts them.

**The direction is the first set's** (`art/roadtrip-drafts/`, 2026-10-23):
warm, rich, painterly pixel art with lots of detail. The second set
(`art/roadtrip-v2/`) was strict pixel art with small palettes, and it lost
that warmth; it's kept only for the scenes, where both sets work. The
Godot port has no colour or pixel-grid limit (only the SNES did), so the
rules are about fitting the game's screens, not the hardware:

- **Sizes are exact** at the game's 960 x 540: a backdrop is 960 x 540, a
  sheet is a grid of cells of exactly the size its note gives, in the
  order it lists, with nothing between cells. Art drawn bigger is scaled
  down to the size once, smoothly (the game then scales the whole screen
  up by whole numbers, sharply).
- **Transparent backgrounds** for every sheet, sprite and icon: no
  backdrop, vignette, glow or ground shadow, and a clean cut-out edge (no
  halo of the old background).
- **Small things stay readable.** Pins (32 x 40) and icons (24 and 64)
  are drawn for their size: bold shapes, a dark outline, few details. A big
  drawing shrunk down turns to mush; redraw instead.
- **One van.** `trip_van` is the van's drawing; every other image with
  the van in it (the pins, the paints, the scenes, the garage, the title)
  copies that side view, those windows and those colours. The paint jobs
  are recolours of it.
- **Scenes keep the bottom 200 px quieter** (lower contrast, no busy
  detail) where the speakers and the dialog panel stand, but never a flat
  slab of colour.
- **No people.** The players, partners and locals are drawn by the game
  from the existing rig, and those long-chinned faces stay as they are.
  The art holds places for them; it never draws them. A crowd is dark
  silhouettes only.
- **No text, letters, digits or symbols** in any image except the title
  card's ROAD TRIP and the DETOUR pin's "?": no labels on gauges,
  odometers, tickets, coupons, signs or posters. The game prints every
  word in its bitmap fonts.
- **No brands, real people or trademarked shapes:** no logos, no real
  coins or banknotes with a portrait, and no look-alikes of well-known
  products (a tree-shaped air freshener, a famous van's face).
- **In the game:** backdrops import as lossy WebP so the `.pck` stays
  small (a detailed 960 x 540 PNG is about 1 MB, lossy about 150 KB);
  sheets and icons stay lossless.
- **Drafts first:** nothing is final until you've approved it, and the
  map gets a mock-up in the game (stage 6) before the art is polished.

### The accepted art (2026-10-24)

All 19 images are **accepted**: the third set (`art/roadtrip-v3/`) with
round 4's five fixes (`art/roadtrip-r4-fixes/`) in place of their v3
files. Stage 6 imports them into the game (backdrops as lossy WebP) and
you see them there; anything that looks wrong in play is fixed then.

| Image | From |
|---|---|
| trip_map_dashboard | `art/roadtrip-r4-fixes/` |
| trip_map_paper | `art/roadtrip-r4-fixes/` |
| trip_pins | `art/roadtrip-v3/` |
| trip_van | `art/roadtrip-r4-fixes/` |
| trip_van_paints | `art/roadtrip-r4-fixes/` |
| trip_scene_roadside | `art/roadtrip-v3/` |
| trip_scene_motel | `art/roadtrip-v3/` |
| trip_scene_yard_sale | `art/roadtrip-v3/` |
| trip_scene_pro_shop | `art/roadtrip-v3/` |
| trip_scene_summer_open | `art/roadtrip-v3/` |
| trip_paddle_plain | `art/roadtrip-v3/` |
| trip_card | `art/roadtrip-v3/` |
| trip_gear_icons | `art/roadtrip-r4-fixes/` |
| trip_hazard_icons | `art/roadtrip-v3/` |
| trip_garage | `art/roadtrip-v3/` |
| trip_dash_ornaments | `art/roadtrip-v3/` |
| trip_ladder_step | `art/roadtrip-v3/` |
| trip_title_card | `art/roadtrip-v3/` |
| trip_hud_icons | `art/roadtrip-v3/` |

Two small things to touch up when they're imported, not worth another
round: MIDNIGHT's paint keeps a few light blue pixels at the front bottom
corner, and the SWEATBAND item and the HEADBAND hat share a drawing (one
could take another colour).

The drafts before these (`art/roadtrip-drafts/`, the first set, and
`art/roadtrip-v2/`) are history: the first set set the style, the second
the sizes and cut-outs.

Both folders are in the repo with their exports, palettes, layouts,
WebP backdrops, review pages and the scripts that made them. Left out (in
the main checkout only, not committed): the asset zips (copies of the
PNGs), v3's `sources/` (the raw generations, 32 MB) and round 4's
`support/` (intermediate files), and the two earlier draft sets.

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
| 6 | `feature/cld-trip-art` | The map mock-up, then the accepted art (above) imported, the two touch-ups; screenshots | |
| 7 | `feature/cld-trip-garage` | MILES, the GARAGE's ladder and the looks, HEAT, the pool's unlocks, the records page; a headless tool that plays trips with a CPU in your place (like `rally_stats.gd`) to time them (30 minutes at most) and set the stat step, hearts, prices and the ladder's miles | |

Stages 1 to 4 make a playable trip; 5 to 7 can come in any order after.

## Questions for you

None open: both rounds are answered (top of the doc). Stage 1 can start
on your go; the [IMAGE] notes can go to an image agent at any time
(stage 6 puts the drafts in the game).

## Built so far

Everything above is built (ADR-087 has the details), except:

- **HOT HAND** turns SPECIALS on and three points in a row fill your
  side's meters (the PICKLE SMASH is then a press away), rather than the
  next shot smashing on its own. **LUCKY LINE** saves a ball out by 6
  inches or less (the close-call replay's measure).
- **Stats** are on the 20-point scale as planned; a point is 2/64 of a
  tunable (not the paddles' 3/64), so 1 is about 0.8 and 20 about 1.4 of
  the standard value. FEET is a human's top speed, 20 to 31 (24 at 8).
- **The GARAGE's cosmetics** are the van's paint and the dash ornament
  (the freshener follows the ornament); the cassettes and the map's pen
  colour wait (KNOWN_ISSUES #83).
- **Scenes** play in full every trip (they're a page or two; START skips).
- **The locals** have looks of their own (a shirt colour for the pair,
  each their own skin, hair, hat and body) drawn from the seed.
- **A trip's length**: about 12 stops and 8 matches; a bot's matches take
  0.5 to 2.5 minutes (`tools/trip_balance.gd`), so a trip is well under
  30 minutes. The balance is a first guess (KNOWN_ISSUES #82).
- **Screenshots**: `godot --path game --resolution 960x540 -s res://tools/trip_shot.gd -- <home|garage|results|map|pick|shop|card|team|detour|motel|start|match> 60 out.png`.

