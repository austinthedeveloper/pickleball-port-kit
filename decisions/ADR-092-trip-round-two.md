# ADR-092 — ROAD TRIP, Round Two: the Van, More Road, a Story Across Trips

Status: **Accepted 2026-10-24**
Milestone: `PORT-87` (the user: "let's expand the road trip even more...
some way to see stats for the player. Maybe they can also trade out
equipment. Create more scenarios, items, other things you'd like. The
story could also be layered where it evolves over multiple playthroughs.
Any assets you make should be written up as instructions like the venue
ones we did. You can use a placeholder so you can keep moving").
Amends: ADR-087 (ROAD TRIP).

## Decision

Everything here is the trip's meta layer: **no sim change**. The match
gets what it always got (`MatchConfig.trip_stats`, `styles`, `perks`,
`modifiers`), so the golden and conformance traces don't move.

### THE VAN: stats and gear

- **THE VAN** (`view/trip_van.gd`) opens over the map (the VAN button,
  `slice`: Y on a pad, I on the keyboard). Your four stats are bars of
  20 cells coloured by where each point comes from (`RoadTrip.stat_parts`:
  the GARAGE and the road, gear, sets, the diner's meal); your partner's
  under them (their own, then partner gear). A MenuPage: PADDLE, HAT,
  BAG, SETS, BACK, and the chosen thing's card.
- **The locker**: a paddle or hat you replace isn't lost any more; it
  goes in the van's locker (`RoadTrip.locker`). PADDLE and HAT swap
  between what's in hand and the locker (`equip`). What's in the locker
  isn't offered again.
- **TRADE IN** at the PRO SHOP sells something from the locker or the bag
  for half its price (`sell`). The PLAIN ones are worth nothing. A SPARE
  PADDLE sold takes its heart.
- **Sets**: two or three items held together add stats (PIRATE'S KIT,
  OLD SCHOOL, GYM RAT, BEACH BUM, ROYALTY, NIGHT OWL, THE HEIRLOOM, ROAD
  HOG). The paddle and hat count only in hand. A card says when it would
  make a set, or that it's part of one; THE VAN lists the sets whose
  items can turn up.

### More road

- **19 items** (59 in all): stat items with a trade-off (LEAD TAPE, ANKLE
  BRACES, ENERGY DRINK), plain ones (PROTEIN SHAKE, FLIP-FLOPS, TEAM
  JERSEYS), and meta ones: SUNSCREEN (the next hazard passes), TIP JAR
  (+3 cash a stop), FIRST AID KIT (a heart after a big match won), MIXTAPE
  (+5 miles a win), CB RADIO (redraw a pick once a leg), GAS CARD (a
  detour's choices cost nothing; bets still do), LOYALTY CARD (a fifth
  item in the shop, sodas half price), THERMOS (a heart as a leg starts),
  LUCKY DICE (coin flips always win), PARTNER'S PADDLE (+2 to every
  partner stat). Three story paddles (GRANDPA'S, ROAD HOG, CHAMPION'S)
  join the road only through the story. Six are in the starting pool;
  the rest come from six new GARAGE steps at the top of the ladder.
- **4 hazards**, each an existing modifier: HEAT WAVE (FAST BALL), FOG
  (GHOST BALL), FULL MOON (MOON), WRONG GLASSES (INVERSE). Grudge matches
  may also be MOON, WIND or DINK OR DIE.
- **13 detours** (21 in all), 7 of them set at a painted venue (the
  drive-in, the fair, the western town...), with new effects: a stat for
  the rest of the trip (`boost`), miles, a coin flip for cash or a pick,
  your partner's practice.
- **The DINER**, a new stop (weight 8, like the motel it gives no gear):
  three of four dishes, each +3 to a stat for the next match only, or THE
  WORKS (+2 to all) for 20 cash (`meal`, eaten by the next match).
- **The map generator is version 2** (`RoadTrip.GEN`). A saved map keeps
  its version (ADR-087), so a trip in progress isn't changed.

### The story across trips

- **Beats** (`trip.json`'s `beats`): scenes that each play once, at a
  slot (a trip's start, the motel, a new leg, before a team's match,
  before the ROAD HOGS, after beating someone, the win, the end, a story
  detour), when their conditions hold: which trip this is, trips won,
  this trip's HEAT, the ROAD HOGS beaten, earlier beats seen, Pepper as
  partner (`RoadTrip.beat_due`). Four arcs: **THE VAN** (Pepper's
  grandpa, his first SUMMER OPEN, an old court, the stranger: Dale
  Dawson), **THE ROAD HOGS**, **THE CHAMPS** (Ace's secret, at HEAT 4),
  **THE MIXTAPE** (tapes for the deck). Some beats give rewards that
  last: a story paddle into the pool, a cassette.
- **The ROAD HOGS**, a rival pair of locals in an RV (`RIVALS!`, a
  purple pin with their RV beside it), on the long drive's middle column
  from the second trip on. Their level is how often you've beaten them:
  MEDIUM, HARD from two wins, MEDIUM again once their arc is done. A
  win pays like a grudge match and counts for their story at the trip's
  end.
- **The stranger** is put on the coast once the old court is found, and
  the old court on the long drive once its beat is due
  (`RoadTrip.story_extras`, `_place_story`), so an arc never waits on a
  rare roll.
- **Starts**: a captain partner opens a trip with their own lines; a
  second trip on has its own opening (`start_pages`).
- **The SCRAPBOOK** on ROAD TRIP's page: the arcs, the chapters seen
  (left and right choose, B watches one again) and a hint at the next.
- **The GARAGE's CASSETTE**: the tapes play on the map (existing tracks;
  KNOWN_ISSUES #83's cassettes).

### The art

Eight new images (`art/roadtrip-r5/PROMPTS.md`): a second gear sheet, a
second hazard sheet, two pins, the ROAD HOGS' RV, the diner, the old
court, the van's inside, the scrapbook. The sheets ship as placeholders
(`make_placeholders.py`, recoloured bits of the accepted art); a backdrop
not in yet shows another (`TripArt.FALLBACK`), or a story detour its
venue. `import.py` brings the finished art in, checking sizes. All
eight were generated, accepted and imported the same day
(`art/roadtrip-r5/REVIEW.md`).

### The save

Still layout **v6** with no migration: the trip in progress gains
`locker`, `boost`, `meal` and `rival_won`, and what lasts between trips
`hogs`, `beats`, `story_pool`, `tapes` and `looks.tape`, all filled in
when missing (`test_an_old_trip_loads`).

## Why

- A trip's choices were invisible once made: the stats lived only in the
  pick cards. THE VAN shows them, and the locker makes a paddle or hat
  pick a choice you can revisit instead of a loss.
- The story was the same scenes every trip. Beats keyed to what you've
  done give later trips something new, and rewards that last give the
  story a reason to be followed.
- No sim change keeps the cost down and the ROM's game untouched.

## Tests

`test_road_trip`: the new data fits and refers to things that exist;
story stops on the map over 200 seeds keep the leg rules; the locker and
trading; sets; every new item's effect; heals and miles; the ROAD HOGS;
beats (order, conditions, rewards); an old trip and an old save load.
`test_trip_screens`: a second trip through the main scene (the van's
story, THE VAN swapping a paddle, the ROAD HOGS met and beaten, the
SCRAPBOOK replaying a chapter). `test_layout`: THE VAN, the SCRAPBOOK,
the CASSETTE, the diner, every beat, detour page and partner start.
