# ADR-093 — ROAD TRIP, Round Three: the Day's Trip, Bonds, the Islands, Postcards

Status: **Accepted 2026-10-24**
Milestones: `PORT-88` to `PORT-94` (the user, on six suggestions and the
announcer: "add the voice lines to the additions file... You can
implement them and I'll create the audio. Let's do all 6").
Amends: ADR-087, ADR-092 (ROAD TRIP); ADR-076 (the announcer).

## Decision

Meta layer and display only, as ADR-092: **no sim change**; the golden
and conformance traces don't move.

### The announcer's ROAD TRIP lines (PORT-88)

29 lines in the additions batch (`design/announcer/make_additions.py`,
group "ROAD TRIP"). `RoadTrip.calls_for` gives a stop's opening calls
(`MatchView.trip_calls`): the day's first match, the islands' arrival,
the stop's kind (pickup, grudge, the stranger, the ROAD HOGS first or
again, big, final, encore), your last heart, a hazard, the meal, HEAD
START, a level-3 bond. The commentary says the first two recorded in
place of the venue's welcome; KITCHEN PASS, SECOND SERVE, LUCKY LINE,
HOT HAND (on `EVENT_PERK`) and SECOND WIND (match point against you)
are called; the SUMMER OPEN and the island encore won have their lines.
A line not recorded is skipped (`Commentary._line`: a family, or its one
take), so the match sounds as it did until the recordings arrive.

### TODAY'S TRIP (PORT-89)

A row on ROAD TRIP's page: a trip from the date's seed
(`RoadTrip.daily_seed`), at HEAT 0 with Pepper and nothing from the
GARAGE or the story, so every player's map and start are the same. Its
best result is kept for the day (`meta.daily`: the leg reached, won,
tries), and the days won are counted (`daily_won`, on the records). Its
miles still go to the GARAGE. Pressed twice over a trip in progress.

### Partner bonds (PORT-90)

Each partner keeps bond points (`meta.bonds`): a point a match won
together, three for a SUMMER OPEN. Levels at 4, 12 and 24 points: +1 to
their stats; their own item in your bag at the start of a trip (PEP
TALK, DAD'S PLAYBOOK, MARGE'S PIE TIN, BRAD'S SHAKER, PETE'S SPYGLASS,
RAVEN'S PARASOL, KAI'S BOARD WAX, MAX'S LUCKY COIN, ACE'S GRIP; rarity
"bond", never offered or sold); +2. Level 2 plays their scene once,
after the trip's start. PARTNER shows the level; a trip's results say
when one rises. The effects reuse the item keys (`atlas`, `sunscreen`
now counts, `lucky`, `leg_cash` new).

### The islands (PORT-91)

Once THE VAN's, THE ROAD HOGS' or THE CHAMPS' story is finished, or a
trip is won at HEAT 5 (`islands_open`), new trips have a fourth leg
(`RoadTrip.ISLANDS`, `legs()`): THE ISLANDS (pirate ship, undersea,
sunset, lakeside; every late ladder team as a grudge match), ending in
THE ENCORE against Dale Dawson (first to 7, HARD, on the pirate ship at
night). Winning the final takes the van on (`title`); the trip is won
either way, and losing every heart on the islands ends it as won.
Story: THE ISLANDS arc (the ferry, the last court, the true ending),
whose reward is the gold map pen. The map folds out a fourth panel.

### Postcards (PORT-92)

A postcard for every venue a trip plays and every detour taken
(`meta.postcards`, 38 to collect), on the SCRAPBOOK's POSTCARDS: pages
of eight, each the place's picture (the venue at dusk, the detour's
scene) or "?". 8, 16 and 24 earn the blue, green and purple pens.

### The cosmetics left (PORT-93)

The GARAGE's MAP PEN (red, blue, green, purple, gold) colours the road
driven. The cassette isn't drawn in the deck (the stop's panel covers
it): a NOW PLAYING card slides over the windscreen as the map opens.

### The balance pass (PORT-94)

`tools/trip_gear_stats.gd` plays trips on paper. Gear never takes a
stat to 20 on a new GARAGE (greedy picks reach POWER 7 at the final), and
only 9% of full-GARAGE greedy trips get one there. So the worry about
POWER stacking (KNOWN_ISSUES #88) doesn't hold; what didn't work was
sets: 0.2 a trip. Now one card in two is a missing piece of a set you've
started (`set_pieces`): 0.5 a trip greedily.

### The save

Still layout **v6**, no migration: new keys with harmless defaults
(`bonds`, `bond_seen`, `daily`, `daily_won`, `postcards`, `pens`,
`looks.pen`; a trip's `daily`, `title`).

## Tests

`test_road_trip`: the day's trip, bonds, the islands, postcards and
pens, the announcer's calls (and every call on the list to record).
`test_announcer.test_the_trip_lines`. `test_trip_screens`: TODAY'S TRIP
from the home, the final won going on to the ferry. `test_layout`: the
new rows, the pens, POSTCARDS' pages, the islands map, the results with
every extra line.
