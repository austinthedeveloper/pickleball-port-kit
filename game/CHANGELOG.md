# Changelog

Pickleball '94, the Godot port. Versions follow
[design/VERSIONING.md](../design/VERSIONING.md); the newest is first.
`game/RELEASE_NOTES.md` has the per-task detail from the roadmap.

## [0.43.0] - 2026-10-29

Play online with a friend anywhere, by room code.

### Added
- **ONLINE by room code**: HOST A MATCH gets a four-letter room (like
  ROOM BXKM), and your friend types it and joins, from anywhere with the
  internet. No router settings, no VPN, and it works in the Web build
  too. CONNECT BY ADDRESS keeps the old way for the same Wi-Fi.

## [0.42.0] - 2026-10-26

ROAD TRIP's people have more to say.

### Added
- **Five conversations where there was one**: every team you meet on the
  road, your partner's word in the GARAGE, at the motel and at the diner,
  and the ROAD HOGS now have five scenes each, heard one per meeting.
  The more you meet someone, the more you learn about them: why Dad tells
  jokes, how Marge and Walt met, what Raven won't admit, what keeps Ace up
  at five in the morning. TRIP OF THE DAY keeps the first ones.

## [0.41.0] - 2026-10-26

Online play without the lag: rollback netcode.

### Added
- **Rollback for ONLINE**: your presses now show at once. Inputs wait 1
  frame on the same network and 2 over the internet, down from 3 to 12.
  The game guesses your friend's next moves and quietly corrects itself
  when it guessed wrong. A correction can show as a small jump of the
  ball or a player.
- **OPTIONS > NETCODE**: ROLLBACK (the default) or LOCKSTEP, the old way,
  kept for this release to compare. The host's choice is the one played.

### Changed
- **An online rematch starts on the same frame for both players**: the
  host's B travels with the inputs.
- **OUT OF SYNC is caught sooner**: the check covers the whole match, not
  just the score and the players.
- Online play needs both players on 0.41.0: different versions still
  won't connect.

## [0.40.0] - 2026-10-26

New faces: eighteen heads for the ladder, the story, ROAD TRIP and your
career player.

### Added
- **New heads**: ten for men (CREW CUT, BEARD, ATHLETE, MOUSTACHE,
  SHAGGY, GLASSES, GOATEE, BALD, STUBBLE, FULL BEARD) and eight for women
  (BANGS, FOCUSED, GLASSES, LAUGH LINES, LAUGHING, SMILE, ROUND SPECS,
  GRIN), beside the classic long-chinned head. Every one fits under every
  hat and takes every skin and hair colour.
- **The ladder has faces**: each team wears its own, from Dad's moustache
  and Walt's bald head to the Pirates' beards and Jade's bangs. The Twins
  and Dale Dawson keep the classic head; Pepper grins; the ROAD HOGS and
  ROAD TRIP's locals have theirs.
- **HEAD on CAREER > EDIT**, under BODY: pick any head for your career
  player, free. Player Select keeps the classic head.

## [0.39.1] - 2026-10-26

A controller fix for two players on one pad.

### Fixed
- **MATCH SETUP no longer freezes on PLAYERS 2P**: with one controller
  and a keyboard, setting PLAYERS to 2P handed the controller to player
  2 straight away, and the menus stopped answering it. Every menu now
  listens to every controller; the controller is player 2's only once a
  2P match starts.

## [0.39.0] - 2026-10-26

ROAD TRIP's map shows where each choice leads.

### Added
- **See where a road goes**: on ROAD TRIP's map, the stop under the
  cursor lights up every road you could still take from it, in gold, all
  the way to the leg's big match, and the stops you'd miss fade. No more
  finding out after the fact that the top stop keeps you on the top road.

## [0.38.0] - 2026-10-26

ROAD TRIP throws every twist at you, and shows what your miles bought.

### Added
- **Every modifier on the road**: a ROAD TRIP grudge match can now be
  played with any modifier or rule in the game, INVERSE's flipped
  colours, GLOW's lights-out neon, MULTI BALL, SIDE-OUT, MOMENTUM, WIN BY
  2, FAST BALL and SUDDEN DEATH included. The map shows the day's
  modifiers on their own line.
- **FROM THE GARAGE**: a new trip opens on a card with the stats you
  start with, what the GARAGE's ladder adds to them, and (in gold) what's
  new since your last trip.

### Changed
- **Holding SHORT** (L, LB, LT or Shift) now slows you down a little
  while it's held: every shot a dink has a cost. Aiming short with the
  D-pad is unchanged.

## [0.37.0] - 2026-10-25

New shirts to earn, and smarter opponents.

### Added
- **Shirt patterns**: every ladder team now has its own shirt: the
  HENDERSONS in matching Hawaiian shirts, the PIRATES in rugby stripes,
  the SURF CREW in tie-dye, the CHAMPS with a sash, and more. Dale
  Dawson wears flames and the ROAD HOGS chevrons. Beat a team to wear
  their pattern yourself: CAREER > EDIT has a new **PATTERN** row, with
  twelve patterns in all (RINGER is free; POLKA DOTS, CHEVRON and
  FLAMES come from wins, aces and ladder clears). Player Select keeps
  its four plain colours.

### Changed
- **Smarter CPUs** at MEDIUM and HARD: they play from the kitchen line,
  move up together, hit third-shot drops and dinks, and aim at whoever
  is hanging back. A CPU partner comes up to the line when you do.

### Fixed
- ROAD TRIP could, very rarely (about 1 leg in 7,000), draw a leg that
  broke its own rules.

## [0.36.0] - 2026-10-25

ROAD TRIP grows: the van, a longer road, and a story that unfolds over
many trips.

### Added
- **THE VAN**: press Y (I on the keyboard) on ROAD TRIP's map to see
  your stats, where each point comes from, your partner's, and your
  gear. Paddles and hats you replace now go in the van's locker, so you
  can swap them back in.
- **TRADE IN** at the PRO SHOP: sell gear for half its price.
- **Sets**: some items held together add stats (PIRATE'S KIT, GYM RAT,
  BEACH BUM and more), and a pick is more likely to offer the piece
  you're missing.
- **More road**: 19 new items, 4 new hazards, 13 new detours (seven at
  the painted venues), and the **DINER**, where a meal helps your next
  match.
- **A story across trips**: from your second trip, scenes that play once
  each as you go, in five stories (THE VAN, THE ROAD HOGS, THE CHAMPS,
  THE MIXTAPE, THE ISLANDS), some with rewards that last: new paddles,
  cassettes for the map's music, a gold map pen. The **ROAD HOGS** are
  your rivals on the road. A **SCRAPBOOK** on ROAD TRIP's page replays
  the chapters you've seen.
- **TODAY'S TRIP**: one map a day, the same for everyone, with your best
  result for the day kept.
- **Partner bonds**: the more you win with a partner, the stronger they
  get, and at level 2 they give you their own item.
- **The islands**: a secret leg past the SUMMER OPEN, once you've
  finished a story or won at HEAT 5.
- **Postcards** from every place you visit, which earn new map pens; the
  GARAGE's **MAP PEN** and **CASSETTE**.
- **OPTIONS in the pause menu**: change the sound or the camera without
  leaving the match.
- The announcer has new ROAD TRIP lines waiting to be recorded; matches
  sound as before until they are.

### Changed
- ROAD TRIP's first leg is a little harder, and your partner lets fewer
  balls go by.

## [0.35.0] - 2026-10-24

A lighter web build.

### Changed
- **The web build downloads less than half as much**: 21 MB, down from
  51 MB. Its music and crowd sounds are encoded smaller, and it leaves
  out ROAD TRIP, the announcer and the seven painted venues (WESTERN,
  ROOFTOP, PIRATES, MOTEL, FAIR, DRIVE-IN, MALL). The Mac, Windows and
  Linux builds have everything, as before. On the web, GLOBETROTTER
  counts the venues the web build has, and a saved painted venue goes
  back to one it has.

## [0.34.0] - 2026-10-24

Seven new courts, painted.

### Added
- **Seven new venues** on COURT > VENUE: **WESTERN** (Main Street at
  golden hour, townsfolk on the boardwalk), **ROOFTOP** (a city roof at
  dusk), **PIRATES** (a galleon's deck at sea, a parrot on the rail),
  **MOTEL** (the drained pool at a desert motel), **FAIR** (a county
  fair's midway, a goat at the fence), **DRIVE-IN** (a drive-in movie at
  night) and **MALL** (a 1994 mall's centre court). Each has its own
  crowd of locals, court colours, sounds and match music. MALL and the
  DRIVE-IN keep their own lighting whatever TIME says.
- ROAD TRIP's road now passes through them.

### Changed
- GLOBETROTTER counts the new venues. If you've already earned it, you
  keep it.

## [0.33.0] - 2026-10-24

ROAD TRIP, and touch controls for the web.

### Added
- **ROAD TRIP**, a new mode on the title, beside STORY. You and Pepper
  load the van and drive to the SUMMER OPEN on the coast, where the Champs
  defend their title. Every trip is a different road map: pick your way
  through pickup games, grudge matches, yard sales, the pro shop, motels
  and detours, with a big match at the end of each leg and the final at
  the beach. You start with a plain paddle and not much else; the gear
  you pick up on the way (paddles, hats, grip tape, sneakers, partner
  drills, and tricks like SECOND SERVE and LUCKY LINE) makes you stronger.
  You have three hearts, so a trip can end. The miles you drive fill the
  GARAGE with lasting rewards (better starting stats, new gear, van paint
  jobs and dashboard ornaments), captains you beat can partner you, and
  winning opens a harder HEAT. Nothing in a trip counts toward your
  records or career.
- **Touch controls** in the web build: an on-screen SNES pad on phones
  and tablets (TOUCH PAD on CONTROLLER: AUTO, ON or OFF). Taps still work
  the menus.

### Changed
- Replays show the bounce marks and the crowd's camera flashes.
- Text sits centred in the menus' highlight bar and the prompts' keys.

### Fixed
- Two SMASH! pop-ups no longer overlap.

## [0.32.0] - 2026-10-22

Dinosaurs, and four new courts.

### Added
- **Four new venues** on COURT, VENUE, from the levels of the SNES
  dinosaur game: **RUINS** (a burning city at sunset over a river),
  **GLACIER** (snowy peaks, ice spires and an icicled stone bridge),
  **LAB** (green tanks of dinosaur skeletons, a hazard-striped catwalk,
  and a few dinosaurs on the loose) and **STATION** (windows on a nebula
  and a ringed planet). Each has its own court colours, sounds and match
  music. LAB and STATION are indoors, so they stay lit at any TIME. The
  announcer doesn't introduce them yet.
- **The Carnotaurus**, with Nathan riding, wanders behind the fence at
  DINOSAUR and the LAB, and strolls DINO PARK's path in OPEN PLAY. He
  roars after a long rally or a match won. At DINOSAUR the Spinosaurus,
  a baby dinosaur and a pterodactyl join him.

### Changed
- **GLOBETROTTER** now asks for a win at all eleven venues. Already
  earned? You keep it.

## [0.31.0] - 2026-10-22

Bring your own pad, and a smaller download.

### Added
- **Map any controller**: OPTIONS, CONTROLS, CONTROLLER has MAP BUTTONS
  for pads the game doesn't recognise, like SNES-style USB pads. It asks
  for each button in turn and remembers that pad from then on. CLEAR
  MAPPING undoes it, and a mapped pad shows SNES buttons in the prompts.
- **A controller is recommended**: with no pad plugged in, the title says
  so once a session (DON'T SHOW AGAIN turns it off).

### Changed
- **Shoulder buttons**: L (and the left trigger) hits short, R (and the
  right trigger) is SPECIAL. Before, either shoulder hit short. The
  keyboard is unchanged.
- **A smaller download**: the music and ambience are compressed better,
  so the game's update is about 18 MB instead of 34 MB.

## [0.30.0] - 2026-10-22

Replays show just the rally.

### Fixed
- **Replays** start a moment before the serve instead of while the server
  is still waiting, skip any time you spent on the pause menu during the
  rally, and end soon after the ball is dead. This goes for saved replays
  and PLAY OF THE MATCH. Replays saved before this version still start at
  the serve's setup, but skip their pauses.

## [0.29.0] - 2026-10-22

Keep the play of the match.

### Added
- **SAVE on PLAY OF THE MATCH**: while the match's best rally replays at
  the end, press SAVE (X on a pad, L on the keyboard) to keep it in
  REPLAYS. The card tells you it's saved, or that REPLAYS is full.

## [0.28.0] - 2026-10-22

Save your best rallies, and keep an eye on your meter.

### Added
- **Saved replays**: pause after a great point and pick SAVE LAST RALLY
  to keep it. PLAYER, REPLAYS lists your saved rallies (up to six) to
  watch again or delete, and the title screen's demo shows them off
  between its own matches (IN THE DEMO turns that off).

### Changed
- **The SPECIALS meters** sit under each player's feet now and follow
  them around the court, instead of under the score panels, so you can
  see yours without looking away from the play. They're the same size
  whatever the team's name.

## [0.27.0] - 2026-10-22

The players get a new build and a proper forehand.

### Changed
- **The players' bodies**: athletic shoulders tapering to the waist, and
  longer legs. Faces, hair, caps and hats are just as they were.
- **The forehand**: players coil their shoulders and sit on the back leg
  as they wind up, drive their weight forward through the hit with the
  back heel coming up, and finish with the paddle high.

## [0.26.0] - 2026-10-22

Little touches on the court.

### Added
- **Bounce marks**: the ball leaves a faint scuff where it lands, fading
  after a few seconds.
- **Camera flashes**: the crowd's cameras flash at the big moments, such
  as a long rally, a PICKLE SMASH, match point and the winning point.
  Turning FLASHES off in ACCESSIBILITY turns them off too.
- **Net cords**: the net shakes when a ball clips the tape and rolls over,
  and when one goes into it.

## [0.25.0] - 2026-10-21

A new voice in the booth.

### Changed
- **The announcer** is re-recorded in one new voice, every line of it.
- **New calls**: advantage and deuce under WIN BY 2, a line for every
  achievement, an intro at THE GYM, and the SPECIALS calls (your meter
  filling up, PICKLE SMASH, its knocked-back return, and a smash that wins
  the point).
- The 20, 25 and 30-shot rally calls and PICKLE SMASH have more room, so
  the longer takes still play mid-rally.

 - 2026-10-21

The first special move.

### Added
- **SPECIALS** (MODIFIERS > RULES, off by default): each player has a
  meter that fills as you play. It goes up with every shot you hit, every
  point your side wins, and the time a rally lasts. The meters sit under
  the score panels and flash gold when full.
- **PICKLE SMASH**: with a full meter, press **SPECIAL** (O on the
  keyboard, the right trigger on a pad) for a smash from any height. It's
  twice as fast as a drive, always clears the net, and aims itself deep
  into the open lane. Whoever returns it gets their paddle knocked back,
  and their return pops up. Without a full meter, SPECIAL is a normal hit.
  The CPUs use it too.

 - 2026-10-21

A simpler title menu.

### Changed
- **The title menu** has five rows instead of twelve: STORY, PLAY,
  PRACTICE, PLAYER and OPTIONS.
- **PLAY** holds the modes: QUICK MATCH (pick SINGLES or DOUBLES with
  Left/Right), TOURNAMENT, OPEN PLAY and MULTIPLAYER.
- **MATCH SETUP** comes up on the way to a quick match, with everything
  for the match in one place: the mode, players, opponent, difficulty,
  CPU errors, points, court and modifiers. It remembers your choices, so
  START gets you straight in, and after the match you're back on it for
  a rematch.
- **PLAYER** gathers your players, records, achievements and the hat
  museum. Achievements are now two presses from the title.
- BACK returns to the page you came from.

 - 2026-10-21

A quieter practice.

### Fixed
- **No announcer in practice.** With no points to end a rally, the
  announcer counted the ball machine's feeds as one long rally and kept
  saying no one had missed, even after you had.

 - 2026-10-21

A new ball machine for practice.

### Changed
- **The ball machine** is redrawn: a cart with a hopper full of balls and
  a launcher arm on a swivel. The arm swings smoothly toward where the
  next ball is going instead of snapping, and kicks back as it fires.

 - 2026-10-21

Open play's paddle rack and winners staying on, made clear.

### Fixed
- **The paddle rack** shows a pair of paddles for each team waiting, one
  per player, as real paddle stacking reads. The panel says how many
  teams are ahead of you ("1 TEAM AHEAD OF YOU ON COURT 2").
- **Winners stay on** is now said: after a win you see "YOU WON 7-4
  WINNERS STAY ON", then "YOU STAY ON COURT 1", with STEP OFF at its rack
  if you'd rather rotate out. Before, the next game seemed to start by
  itself.

## [0.21.0] - 2026-10-21

Two new places to play, and friendlier local multiplayer.

### Added
- **OPEN PLAY locations**: press Left/Right on OPEN PLAY to pick THE PARK,
  **DINO PARK** (palms, a smoking volcano, dino statues, a ranger hut) or
  **THE GYM** (a maple floor, divider nets, bleachers, a scoreboard).
  Your park progress carries across all three.
- **The GYM venue**: an indoor court with banners, a scoreboard and the
  crowd on bleachers, always lit, with its own sound and music. THE GYM's
  games play there, and you can pick it on COURT for any match.
- **MAPLE** court surround colour.

### Changed
- **Local multiplayer**: two players can now team up against two CPUs, or
  play on opposite sides with a CPU partner each. LB/RB cycle round all
  four modes, shown as tabs, and the lobby says who plays whom.
- The title's top line shows just your RECORD; ladder places and clears
  are on RECORDS.
- GLOBETROTTER now asks for a win at every venue, the GYM included.

### Fixed
- The player tags over heads: the text no longer sits low in the box,
  and the pointer is the player's colour instead of black.

## [0.20.0] - 2026-10-21

Achievements, and a few fixes.

### Added
- **Achievements**: thirteen to start, with PICKLED first (win without
  letting the other side score). Each one pops up with a chime as you
  earn it; RECORDS > ACHIEVEMENTS lists them all, with how to earn each.

### Fixed
- The people in the stands now move with the stands as the camera leans,
  instead of sliding against their benches.
- A ball coming in low on your near side is now played with a low, reaching
  swing, with the player stepping toward it, instead of a paddle swung at
  chest height. How the game plays is unchanged.

## [0.19.1] - 2026-10-20

A trimmed announcer, a plain off switch, and a fixed replay.

### Changed
- **The announcer no longer introduces the teams** (it took too long). A
  match opens with the venue, then the modifier or the format.
- **ANNOUNCER is now an ON/OFF switch** on OPTIONS, and **VOICE VOLUME**
  sets its volume. If you had the old slider at OFF, the switch is OFF.

### Fixed
- **PLAY OF THE MATCH**: the players no longer slide around frozen in
  their end-of-match pose; they run and swing as they did in the rally.
  The RALLY counter no longer peeks out from under the replay's caption.

## [0.19.0] - 2026-10-20

The announcer.

### Added
- **The announcer**: a 1994 TV sports voice for every match, with nothing
  added to the screen. It introduces the venue or the team, calls the
  score at each serve, reacts to aces, long rallies, faults, streaks,
  comebacks and match point, throws in the odd pickle pun, and calls the
  result, close calls and PLAY OF THE MATCH. The music and crowd dip
  while it talks.
- **ANNOUNCER** and **COMMENTARY** on OPTIONS: its volume (or OFF), and how
  much it says: LIGHT (the big moments), NORMAL, or LOTS.

### Changed
- OPTIONS sits higher on the screen to fit its two new rows.

## [0.18.0] - 2026-10-20

PLAY OF THE MATCH, and a new standard ball.

### Added
- **PLAY OF THE MATCH**: when a match ends, its longest rally plays again
  like a TV replay, with a REPLAY sign, the rally's length, a half-speed
  finish and how it was won. Press HIT or START to skip it. It's the real
  rally, run again from the match itself.

### Changed
- **BALL SPEED defaults to 85% and BALL SIZE to 110%.** If you never
  moved those sliders you get the new defaults; a setting you picked is
  kept.

## [0.17.0] - 2026-10-20

A slower, bigger ball, longer rallies, and a tuning panel during play.

### Added
- **Tuning panel**: press F2 during a match (or TUNE on the pause menu)
  for a panel on the right; the match waits while it's open. BALL SPEED,
  BALL SIZE and CPU ERRORS change the match as you go and are saved.
  Every modifier and rule is there too: APPLY restarts the match with
  them.
- **BALL SIZE** on MODIFIERS: 80% to 150%, 105% by default. It only
  changes how big the ball looks.
- **CPU ERRORS** on MATCH SETUP: how often the CPUs mistime a swing,
  50% of the original game's by default, for longer rallies (in doubles,
  about 12 shots instead of 8).

### Changed
- **BALL SPEED defaults to 78%.** If you never moved the slider, you get
  78%; a speed you picked is kept.
- A slower ball now slows down the way the easier difficulties always
  did: the same flight, just slower, so it no longer bounces too high to
  reach. A slowed ball now glides smoothly instead of stuttering.
- MODIFIERS sits higher on the screen to fit its new row.

## [0.16.0] - 2026-10-20

Set the ball's speed.

### Added
- **BALL SPEED**, the first row on MODIFIERS: 70% to 130% in 1% steps,
  starting at 100% (the ball as it was). Shots still land where they're
  aimed; a slower ball also arcs a little higher. It's saved, and it
  applies to every match, practice drill and online game (online, the
  host's setting is used).

## [0.15.1] - 2026-10-20

Easier-to-read story notices, and rally scoring in PICKLEBALL 101.

### Changed
- **Story**: Grimsby's notices and the petition are printed in clean,
  solid ink, so they read clearly on the paper.
- **PICKLEBALL 101**: KEEPING SCORE now says side-out is how most parks
  play, then explains rally scoring (what this game plays: every rally
  scores) and where to switch SIDE-OUT on, with a new quiz.

## [0.15.0] - 2026-10-19

Story mode, and a course on how to play pickleball for real.

### Added
- **STORY: SAVE THE PARK**: the first row on the title. Mr. Grimsby of
  Grimsby Parking Co. wants to pave Riverdale Park; you and your partner
  Pepper play all eight teams for their names on the petition. Each
  chapter has a title card, a scene at its venue and time of day, a
  doubles match with a twist (wind on the lake, moon gravity under the
  sea, win by 2 against the Champs), and the petition signed. There's an
  ending, and finishing the story also unlocks Dale Dawson. Your progress
  is saved.
- **PICKLEBALL 101**, on PRACTICE: eight lessons on the real game (the
  court, the serve, the two-bounce rule, the kitchen, keeping score, line
  calls, playing smart, court manners). Each page has an animated court
  diagram, and each lesson ends in a quiz. The serve, bounce and kitchen
  lessons link to their HOW TO PLAY drills.

## [0.14.0] - 2026-10-19

Rally heat: long rallies catch fire and put the court in a spotlight.

### Added
- **Rally heat**: at 10 shots the ball and the RALLY sign catch fire; from
  15, and a little darker every 5 shots after, everything but the court
  dims, putting the players in a spotlight. The point's end lets it go.

## [0.13.1] - 2026-10-19

A cleanup release: the same game, with less work per frame in the menus,
the lobby and the online screen.

### Changed
- Menus, the multiplayer lobby and the online host screen do less work
  each frame (text redraws only when it changes, hidden pages rest).
- The lobby's status line reads READY TO START (the prompt bar shows
  which button).
- 2P's pad on the title now also steers with the stick.

## [0.13.0] - 2026-10-19

MULTI BALL, and a gentler screen shake you can set.

### Added
- **MULTI BALL**, the last '95 modifier: RULES > MULTI BALL. No serving:
  balls appear at the net every few seconds (three at most), blink, then
  shoot to one side. Every ball scores on its own, two-bounce rule and
  all, and the first to the winning score wins.

### Changed
- SCREEN SHAKE (OPTIONS > ACCESSIBILITY) is a strength now: OFF, 25%, 50%,
  75% or 100%. It starts at 50%; the full shake was too jarring.

## [0.12.2] - 2026-10-19

Fuller backdrops: LAKESIDE's lake and town across the whole view.

### Fixed
- LAKESIDE's lake and its little town now stretch across the whole view
  (they were a small rectangle in the middle), with hills behind and
  sailboats on the water; PARK's and SUNSET's city skylines no longer
  stop short.

## [0.12.1] - 2026-10-19

Online: the host's wired address is labelled and listed first.

### Fixed
- ONLINE: hosting on a PC with both Ethernet and Wi-Fi, the wired address
  showed as "NETWORK" and came second. It reads ETHERNET now and comes
  first (it's the one that answered in testing).

## [0.12.0] - 2026-10-19

The Pickleball '95 promises: side-out scoring, the momentum rule, five
new modifiers, and Dale Dawson.

### Added
- **Side-out scoring**, the *Pickleball '95* promise: MODIFIERS > RULES >
  SIDE-OUT. Only the serving side scores; in doubles both partners serve
  before the side out, and a game opens on the second server.
- **The momentum rule**, another '95 promise: RULES > MOMENTUM. After a
  volley, step into your kitchen before the ball bounces or is hit again
  and it's your point lost (MOMENTUM!).
- Five more '95 modifiers: **MOON** (low gravity, floaty shots),
  **BOUNCY**, **WIND** (a new crosswind each serve), and on RULES **DINK
  OR DIE** (a drive loses the point) and **SUDDEN DEATH** (one point takes
  the match).
- **Dale "Dink" Dawson**, the man on the box, at last: clear a ladder and
  he's on MATCH SETUP's VS row. In doubles he takes on both of you alone,
  and he's fast enough to do it.

### Changed
- WIN BY 2 and LAVA moved to the new RULES page (MODIFIERS > RULES).

## [0.11.0] - 2026-10-18

The show: players react to every point, emote, and wear a coloured
circle; critters cross the sky; GLOW and INVERSE.

### Added
- **A coloured circle at each player's feet**: you in your player colour,
  the CPUs grey.
- **Celebrations and slumps** after every point: the Gym Bros flex, the
  Pirates go en garde, Dad and Kiddo give a thumbs-up, and a player who
  can't reach a ball dives for it.
- **Emotes**: ! into the net, ? out, sweat, anger at a fault, a star for
  a long rally, a note in a dink rally, Z's while you take your time to
  serve.
- The net shivers, drives squash and streak, slices leave a trail.
- A gull at LAKESIDE, a satellite in SPACE, a fish UNDERSEA; a trophy
  for the CHAMPION.
- Two more modifiers: **GLOW** (lights out, neon players and lime lines)
  and **INVERSE** (a photo negative).

## [0.10.0] - 2026-10-18

The game caught up with the SNES: CPUs that play frame for frame as the
ROM's, the 1994 park, thirteen hats and the Hat Museum.

### Added
- Three more modifiers from the SNES game: **GHOST BALL** (high in flight
  the ball only blinks), **POPCORN** (every hit in a rally adds pace) and
  **ICE** (everyone slides).
- Singles and doubles each keep their own **ladder place**. Quitting a
  ladder match from the pause menu starts that ladder over; losing keeps
  your place. Your current place carries over to both.
- **The park, as in 1994**: the courts are ROOKIE, CLUB and CHAMP. A
  career player earns **park points** (10 to start; CLUB opens at 15,
  CHAMP at 25), **winners stay on** for up to two games, and at your rack
  SLICE picks **your partner** from the captains you've beaten.
- **Seven new hats** to earn, as on the SNES: BEANIE, BUCKET, BACKCAP,
  WHIRLY, VIKING, CHEF and CROWN.
- The **HAT MUSEUM**, from your career card: every hat in a lit case on
  you, the ones still to earn as silhouettes with how to get them.

### Changed
- **The CPUs play exactly as on the SNES**, frame for frame: the ladder
  was rebalanced there (the upper teams can be beaten now), the big
  hitters serve hard and sometimes into the net, and a short serve goes to
  the middle of the box.
- Each team has sixteen things to mutter after a lost point (four
  before), and says them all before repeating one.
- A volley with your feet on the kitchen line is a kitchen fault, as on
  the SNES.

## [0.9.3] - 2026-10-18

All four swings, as on the SNES: the slice, and SHORT to drop any shot.

### Added
- **All four swings**, as on the SNES: the **SLICE** (I on the keyboard,
  Y on an Xbox pad, triangle on PlayStation) is slow, never deep, and
  steady when you stretch: it buys time. Hold **SHORT** (Shift or U, LB or
  RB) and any swing goes short: a short shot, a fast drop, a dink or a
  short slice. Both are on CONTROLS.
- The Snowbirds' Walt, the Goth Club and the Champs slice too.

### Changed
- A drive hit short off a stretch now flies long and sits up mid-court,
  as on the SNES. HOW TO PLAY's SHOTS lesson asks for a slice too.

## [0.9.2] - 2026-10-18

Updates at launch, easier lessons, and online's addresses. From 0.9.1, get
it in OPTIONS > UPDATES; after this one, updates come up by themselves.

### Changed
- **Updates happen when you open the game**: a new version downloads
  right away with a progress bar, says INSTALLED, and restarts the game.
  Only no connection, a failed download, or a release that needs a full
  download lets you play the version you have. (OPTIONS > UPDATES still
  checks by hand.)
- **HOW TO PLAY**: THE KITCHEN is a ball-machine drill now (volley the
  machine's drive back from behind the line), and SERVE and TWO BOUNCES
  play HENDERSON at full ball speed (the KID opponent's slowed ball felt
  like slow motion).

### Fixed
- ONLINE's HOST screen showed only one address and could pick the wrong
  one (a second network's); it now shows up to two, the home router's
  (192.168...) first, each named by its adapter.
- OPTIONS > UPDATES could stay on 98% after the download finished.

## [0.9.1] - 2026-10-18

The first update you can get in the game: OPTIONS > UPDATES.

### Changed
- **CAMERA** (OPTIONS) now starts at 50%, so the view leans toward the
  ball. If yours was OFF (the old default) it moves to 50% once; set it
  back to OFF and it stays.

## [0.9.0] - 2026-10-18

Updates in the game. Download this one in full; after it, OPTIONS >
UPDATES gets the next ones for you.

### Added
- **Updates in the game**: when a new version is out, the title says so,
  and OPTIONS > UPDATES downloads just the game (about 23 MB) and restarts
  on it. This is the last version you need to download by hand (desktop
  builds; the Web build is always the newest).

### Fixed
- ONLINE's address had an invisible cursor while typing (the font has no
  underscore); it's a blinking slash now.

## [0.8.1] - 2026-10-18

A fix for online play's HOST screen.

### Fixed
- ONLINE's HOST screen listed addresses nobody else can reach (a virtual
  network adapter's: WSL, Hyper-V, VirtualBox, Docker). It now shows only
  the home network's, labelled SAME WI-FI, and a Tailscale address,
  labelled TAILSCALE.

## [0.8.0] - 2026-10-18

Online play, a tutorial, the couch cup, your controller's own buttons, and
the kitchen rule.

### Added
- **ONLINE play** (MULTIPLAYER > ONLINE): 1 vs 1 singles with a friend.
  One hosts, the other types the host's address and joins; same Wi-Fi
  just works, and the README says how to connect over the internet
  (Tailscale, or a forwarded port). MULTIPLAYER now opens a page: LOCAL
  (the four-pad lobby) or ONLINE.
- **Your controller's own buttons** in every prompt: PlayStation pads show
  the cross, circle, square and triangle (and L1, R1, OPTIONS), Switch pads
  their B, A, Y, X, + and -. Picked from the pad's name; CONTROLS has a
  BUTTON ICONS row to choose one by hand.

- **HOW TO PLAY** (under PRACTICE): six short lessons, each one goal in a
  real rally: returning the ball, drives and soft shots, the smash, the
  serve, the two-bounce rule and the kitchen. They pick up where you left
  off, and MAIN points new players to them.
- The **COUCH CUP**: in MULTIPLAYER, LB / RB now reach SINGLES CUP and
  DOUBLES CUP. Everyone enters the bracket (each player, or each side in
  doubles), CPU teams fill it out, and you meet each other as late as the
  draw allows.

### Fixed
- In multiplayer, the score panel names each side by its players (P3,
  P1 + P4); singles always said P1 and 2P before.
- **The kitchen rule:** you can no longer volley from inside your own
  kitchen. Stand in it as much as you like, but a ball hit out of the air
  from there loses the point (KITCHEN!). The CPUs play by it too.

## [0.7.0] - 2026-10-18

The overhead smash, a tournament, and a cleanup round.

### Added
- The **overhead smash**, which the SNES game never had: swing HIT or
  DRIVE at a high ball on its way down (a lob you get under) and it's a
  fast, steep smash, with its own sound, a big shake and SMASH! over it.
  The CPUs smash too. SOFT still blocks a high ball. The stats card counts
  SMASHES.
- A **TOURNAMENT** on the main menu: an eight-team knockout against the
  ladder teams, each match at your opponent's home court, with a bracket
  between matches that fills in as the rounds go. Cups won show on
  RECORDS.

### Fixed
- A player no longer flashes in the top-left corner of the title when
  you change COURT or TIME of day.
- Every match kept its whole simulation in memory after it ended; long
  sessions now stay small.

### Changed
- Behind the scenes: the title's CAREER pages and the menus' panels and
  labels share code; the roadmap is an index, with the finished tasks in
  `design/PORT_HISTORY.md`. Re-syncing the art no longer rewrites every
  asset's import file, and two checkouts can run their tests at once.

## [0.6.0] - 2026-10-18

Three new venues, career mode, and music.

### Added
- Three more venues from the SNES game (COURT → VENUE): **DINOSAUR**
  (a sunset jungle with a volcano and dinosaurs over a wooden fence),
  **SPACE** (stars, Earth, Saturn, a rocket, aliens and astronauts behind
  a lit fence), and **UNDERSEA** (a shipwreck, fish, crabs and an octopus
  along a rope fence). Each has its own default court colours and
  background sounds, and works at every time of day.
- The GYM BROS, GOTH CLUB and SURF CREW play their ladder matches at home
  at the new venues.
- Music, which the SNES game never had: a title theme, the park's theme
  in open play, a match loop for each of the six venues, and stingers for a match
  won, a match lost and the ladder cleared. All original, made in code.
  - It crossfades between screens and dips under the crowd and the
    whistle.
  - **MUSIC** on OPTIONS sets its level (OFF to 100%); SOUND OFF silences
    it too.
- **Career** (ADR-047): MAIN's RECORDS row is now CAREER.
  - **Players:** three save slots, each a named player with a look,
    lifetime stats and unlocks. Name them on an arcade keyboard and dress
    them (body, skin, hair, shirt, hat, paddle) beside a big portrait.
  - **Playing as them:** the active player is 1P. Player Select starts on
    their look, the score panel shows their name, and open play, the ball
    machine and the park's walker use their saved look.
  - **Stats:** matches against the CPU count (W-L by mode, aces,
    shutouts, best streak, longest rally); the card shows them and the
    next unlock.
  - **Unlocks:** four hats and five hair colours, earned by wins, rallies,
    aces, shutouts, streaks, beating the PIRATES, open play and clearing
    the ladder. An UNLOCKED! card follows the match that earns them.
  - **Gear:** a hat moves one paddle stat point to another (the editor's
    GEAR row and Player Select's bars show it).
  - NO PLAYER plays exactly as before; the records are behind CAREER's
    RECORDS row.

### Changed
- The save moves to layout v5 (the career players); a v4 save carries
  over with no players.

### Fixed
- An error at startup when the window mode changes (FULLSCREEN saved on,
  or a window the system opens maximized).

## [0.5.0] - 2026-10-17

The park, modernised.

### Changed
- The park (OPEN PLAY) is redrawn and modernised:
  - **View:** a 3/4 view from about a second storey, closer in, with a
    camera that follows you.
  - **Art:** pixel-art courts with fences, nets, racks and benches;
    trees; lamps; a walkway; a clubhouse with a roof and a front wall.
  - **Clubhouse:** walking in, the roof lifts away and the camera frames
    the room.
  - **Trees:** they let you show through when you walk behind them.
  - **HUD:** a COURTS panel shows every court's level, score and queue.
  - **Panel:** what's around you, and what you can do, moves to the bottom.

### Fixed
- A changed prompt no longer leaves the old one showing for a frame.

## [0.4.0] - 2026-10-17

HD sound.

### Changed
- Every sound remade in HD (48 kHz, stereo where it counts) without the
  SNES's limits:
  - paddle hits with a real "pock", and their own sound for drives and
    soft shots;
  - court bounces, the net, a pea whistle;
  - a crowd of individual clappers;
  - new venue ambience: birds and wind, gulls and waves, crickets.

  Hits and bounces come in variants, so rallies don't repeat. The SNES
  sounds are kept in `audio/snes-sfx`.

## [0.3.1] - 2026-10-17

Text and layout fixes.

### Fixed
- Crowded and overlapping text: the title's header and menu panel, BODY
  and FEMALE on Player Select, two-digit scores against the team name,
  the COURT page against the record line, a READY lobby card over its
  rows, and prompt bars wider than their panels (pause, initials,
  practice). A layout test now checks every screen for overlaps.

## [0.3.0] - 2026-10-17

Open play: the park from the SNES game.

### Added
- OPEN PLAY on MAIN: walk around the park, put your paddle in a court's
  rack, and when it's your turn the park calls you into a doubles game
  with a ladder player as your partner. There are three courts at three
  skill levels (UNDER 3.5, 3.5-4.5, 4.5+), games to 7, on your saved
  points and modifiers. Win or lose, B takes you back to the park.
- The clubhouse: a records board, the ball machine (practice on your
  saved drill, with PARK on its pause menu to come back), and the teams
  waiting on the bench.
- 2P comes along as your partner (PLAYERS 2P, or Start on pad 2 in the
  park).
- Releases are now built and published by GitHub Actions when a version
  is tagged; every push runs the tests.

### Known
- The park and clubhouse are drawn in code for now (KNOWN_ISSUES #40).

## [0.2.1] - 2026-10-17

The first release with downloadable builds: macOS (universal), Windows,
Linux and Web. The game is the same as 0.2.0.

### Fixed
- macOS export: the project now imports ETC2/ASTC textures, which
  universal and Apple Silicon builds need. The game's art is lossless, so
  nothing looks different.

## [0.2.0] - 2026-10-17

Multiplayer for up to four players.

### Added
- MULTIPLAYER: up to four players on controllers. A lobby to join, pick
  sides (partners in doubles), shirts, bodies and paddles; CPUs fill
  doubles; P1-P4 tags in the match.

### Changed
- B backs out of menus on a controller (the Xbox convention).
- All controllers are treated as Xbox pads for now (KNOWN_ISSUES #39).

## [0.1.0] - 2026-10-17

The first versioned release: the SNES game ported to Godot 4.7 at
960x540, plus a first pass beyond the 16-bit limits.

### The game (PORT-00 to PORT-09)
- The full SNES rules and AI as an exact integer sim, checked by golden
  traces: singles, doubles, 2P versus, the ladder with intro cards and
  quips, practice with the ball machine, modifiers (BIG BALL, FAST BALL,
  WIN BY 2, LAVA), the camera lean.
- Game feel: shake, ball trail, squash, swing arc, plant dust.
- Sound: hits pitched by shot, panned by court position, a crowd that
  swells with the rally; SOUND (ALL, NO CROWD, OFF).
- A menu tree and pause menu (RESUME, RESTART, MAIN MENU); fullscreen
  and scaling options.
- Player Select: shirt, body, paddle with POWER, CONTROL and SPEED.
- Court colours (surface, kitchen, surround, lines) and TIME (DAY, DUSK,
  NIGHT), contrast-checked.
- The close-call replay ("OUT BY A HAIR!") and the partner watching
  singles from the stands.
- RECORDS with initials for the best streak and longest rally, records
  against each team; save layout v4.
- Export presets (macOS, Windows, Linux, Web), the build ID on the
  title, an app icon.

### Beyond the SNES (PORT-10 to PORT-15)
- Modern menus: an easing highlight, slide-in pages, mouse support,
  fades between screens.
- Prompts that follow the device in hand and the bindings.
- CONTROLS remapping; ACCESSIBILITY (screen shake, flashes, large HUD
  text, serve assist, vibration).
- A post-match stats card; totals in the records.
- A livelier HUD: score pops, serve marks, a rally counter.
- Controller support: any pad on the Xbox layout, Xbox prompts,
  hot-plugging, pause on a lost controller, rumble.

### Known
- Platform builds need Godot's export templates (not bundled); run from
  source with `godot --path game`. See `design/KNOWN_ISSUES.md`.
