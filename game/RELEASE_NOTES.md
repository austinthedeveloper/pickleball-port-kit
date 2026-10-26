# Pickleball '94 (Godot port) release notes

Build `v0.39.0`. Generated from `design/PORT_ROADMAP.md` by
`game/tools/release_notes.py`; edit the sheet, not this file.

96 of 99 roadmap tasks are in.

## PORT-00: Merge the two running sessions

Merge the practice-mode and opponent-looks branches into the chain's base. Each goes in only if its own tests pass. Conflicts get resolved, and both features are re-run together.

Status: **Done**.

## PORT-01: game feel (product brief "punchy")

Contact punch: a short screen shake on drives and put-aways, a ball trail on fast shots, squash on the bounce, a swing whoosh frame on the paddle, and dust when a player plants.

Status: **Ready to test**: play a few rallies. Hit drives (K), and lob high to get a put-away back. Do the shake, trail and arc feel right, or too much?

## PORT-02: sound (ADR-029, ADR-031)

Hits pitched by shot type. Hits, bounces and the net panned by court x. A crowd that swells with the rally's length and hushes on match point. Applause sized to the point. Ambience fades at scene changes. A SOUND setting (ALL / NO CROWD / OFF), saved.

Status: **Ready to test**: listen to the mix. Are hits, bounces and the whistle balanced? Is the applause too loud? Is the ambience swell on long rallies noticeable but not distracting?

## PORT-03: the menu tree (ADR-025, ADR-030, playbook §7)

A main menu with pages (PLAY, OPTIONS, MODIFIERS, RECORDS) built on one reusable settings-row component, replacing today's one long title list. A pause menu (RESUME / RESTART / MAIN MENU). Every modal swallows its closing input (rule 9). Window options (fullscreen, integer scale).

Status: **Ready to test**: walk the menus with the keyboard and a pad. Do the pages read well, is Y-to-back natural, and do FULLSCREEN and SCALE behave on your display?

## PORT-04: Player Select (ADR-020)

Choose a shirt colour, male or female, and a paddle, with POWER, CONTROL and SPEED bars, following the select concept art. Colours stay unique per match (ADR-010). 2P picks on its own pad. CPUs take the remaining colours.

Status: **Ready to test**: pick a colour, body and paddle; try WOOD vs RED for a few rallies. With a second pad, set PLAYERS to 2P VS.

## PORT-05: court colours (ADR-022, ADR-027)

A COURT page: VENUE plus SURFACE, KITCHEN (with SAME), SURROUND and LINES presets from `court_colors.json`, previewed live behind the page. Recolouring uses the court mask's roles in a shader.

Status: **Done**. (Have a look at a few combinations if you like.)

## PORT-06: night courts (ADR-045)

TIME = DAY, DUSK or NIGHT. The backdrop darkens by the ADR's factors and the court stays lit under floodlights. The crowd dims and night ambience plays.

Status: **Ready to test**: COURT → TIME → NIGHT (and DUSK) at each venue. Is NIGHT dark enough, too dark, or too blue?

## PORT-07: the watcher (ADR-042) and close calls (ADR-041)

In singles, the opponent's partner sits out at the venue's watcher spot and cheers their side. A close out-call after a long rally freezes and shows a close-up of the bounce with a caption ("OUT BY A HAIR!").

Status: **Ready to test**: play a singles ladder match (KIDDO watches DAD). The close-up needs an 8-shot rally that lands just out, so it's rare; `tools/screenshot.gd -- singles park 160 out.png closecall` forces one if you want to look without waiting.

## PORT-08: records and initials (ADR-021, ADR-040)

A RECORDS page: wins and losses by mode, the longest rally, ladder clears, the best practice streak, and a record against each opponent. Initials on a new record, with an arcade keyboard, a 30-frame input lockout and only on a finished match. The save goes to layout v4 with a migration (practice took v3).

Status: **Done**. (A quick look: win a match and enter initials.)

## PORT-09: release prep (playbook 0.1, §9)

Export presets (macOS, Windows, Linux, Web). A build ID on the title (commit plus a dirty flag). An app icon from the art. A headless export check. Release notes generated from this sheet. `CLAUDE.md` refreshed.

Status: **Ready to test**: the platform exports need Godot's export templates, which aren't installed here (see "For you"). Then run `game/tools/export.sh` and try a build.

## PORT-10: organize the code

Split the two big view files: the title's pages move to their own builders, and MatchView's camera, crowd and watcher become components. Retire leftovers (the old MODS presets list stays only as a save reader). Every gdscript warning fixed; the folder layout documented.

Status: **Done**.

## PORT-11: modern menus

Menus that move: pages slide and fade, the cursor eases between rows, a highlight bar replaces the ball icon, values tick with arrows. Fades between the title and a match. Button prompts follow the last device used (keyboard keys or pad glyphs). Mouse: hover selects a row, click presses, wheel changes.

Status: **Ready to test**: try the menus with the mouse, then pick up a pad mid-menu and watch the prompts switch.

## PORT-12: remapping and accessibility

A CONTROLS page: rebind every action for keyboard and pad, with conflict swaps and RESET, saved. ACCESSIBILITY: screen shake and flashes on/off, a bigger HUD text option, and a hold-to-charge serve assist.

Status: **Ready to test**: remap a key and a pad button, play a point, and restart the game to see them kept. Try SERVE ASSIST.

## PORT-13: post-match stats

After the result: a stats card per side (points won on serve, winners by shot type, faults by kind, longest rally, average rally), collected from sim events, display only. Totals roll into the records.

Status: **Ready to test**: finish a match and read the card.

## PORT-14: a livelier HUD

Scores that pop when they change, a serve indicator (who serves, and in doubles which server), a live rally counter for long rallies, and a MATCH POINT pulse.

Status: **Ready to test**: play a doubles match and a long singles rally.

## PORT-15: controller support (asked for 2026-10-17)

The standard approach most games take. Any pad Godot's SDL mappings know (Xbox, PlayStation, Switch Pro, most generic pads) is read on the Xbox layout, and **everything shown uses Xbox buttons**: A, B, X and Y in their colours, LB/RB/LS/RS, the Menu and View buttons, and a drawn D-pad. In one-player any connected pad drives P1, so you just pick one up. With 2P on, the first pad is P1's and the second P2's; with one pad, P1 plays on the keyboard and P2 on the pad. Pads can be plugged and unplugged at any time; a toast says CONTROLLER CONNECTED or DISCONNECTED, and losing one mid-match pauses it. Holding a stick or the D-pad in a menu repeats (300 ms, then every 85 ms, in real time). Rumble on your own contact (a drive harder, a soft shot barely), with VIBRATION in ACCESSIBILITY.

Status: **Ready to test**: plug in a controller (and pull it out mid-match), try the menus with the stick, and feel the rumble.

## PORT-16: four players on controllers (asked for 2026-10-17)

MULTIPLAYER on MAIN opens a lobby. Up to four controllers join with A, each taking the first free player number (P1-P4) and a card: SIDE, SHIRT (unique), BODY, PADDLE. LB/RB switch SINGLES and DOUBLES. In doubles **the players choose their sides, and whoever shares a side is their partner**; an empty place on a side gets a CPU (free colour, standard paddle). A readies, B un-readies or leaves, and Menu starts once everyone is ready and the teams work. Every human plays on their own pad; anyone's Menu pauses and anyone's A works the pause menu; a P1-P4 tag floats over each player in their colour. Friends' matches leave the records alone. All pads are taken to be Xbox pads on the default layout for now (KNOWN_ISSUES #39).

Status: **Ready to test**: needs two to four controllers. MAIN → MULTIPLAYER, A to join, pick sides, A to ready, Menu to start.

## PORT-17: open play (ADR-034, the "long" candidate)

OPEN PLAY on MAIN (the third row, as on the SNES) opens the park: three courts at three skill levels (UNDER 3.5 teal, 3.5-4.5 gold, 4.5+ red), each with a ladder game going to 7 and a paddle rack at its gate, and the clubhouse beside them. Walk with the D-pad (the fences and walls are solid); B at a rack stacks your paddle, takes it back, or moves it. When your paddle reaches the top at a changeover the park calls you ("YOUR GAME!", "WITH PETE VS GOTH CLUB") and starts a doubles match at the park against the team drawn, with the captain next in line as your partner (their look, paddle, and play style), at the court's difficulty (KID stays KID), on the saved points and modifiers: no intro card, no ladder change. B on the result goes back to the park ("YOU WON 5-3"), Start to the title. In the clubhouse: B at the records board turns its pages, B at the ball machine starts practice on the saved drill (PARK on its pause menu comes back), and the teams waiting sit on the bench. 2P comes along as your partner with PLAYERS 2P, or Start on pad 2 in the park.

Status: **Ready to test**: MAIN → OPEN PLAY. Walk to a rack, B, and wait about 20 s; play the game; B on the result. Try the clubhouse board and ball machine. Look at the park art (drawn in code, KNOWN_ISSUES #40).

## PORT-18: HD sounds (asked for 2026-10-17)

Every effect and ambience loop remade without the SNES's limits by `audio/hd-sfx/make_sfx.py` (numpy, fixed seeds; see its README). Shots have their own samples instead of a pitched one; hits and bounces have variants played round-robin with a little pitch spread. The SNES set stays in `audio/snes-sfx`.

Status: **Done**: you listened and they sound good (2026-10-17).

## PORT-19: the park, modernised (asked for 2026-10-17)

The open-play park, taking the old screen as a wireframe: a 3/4 view from about a second storey, twice as close, the camera following you (a little ahead as you walk; framing the room inside the clubhouse). Art by `art/park/build_park.py` with the venue pixel kit: the ground (striped grass, a concrete walkway with spurs, the courts in their level colours, the clubhouse floor, baked shadows) and upright sprites sorted with the people by depth (chain-link fences, sliced where they run into the picture; nets; racks with the waiting paddles; benches; lamps; trees; the clubhouse's walls and roof). The roof fades away and the front wall ghosts while you're inside; a tree's canopy fades when you walk behind it. HUD: OPEN PLAY and EXIT top left, a COURTS panel top right (level, score or NEXT/YOU, +N waiting), and the message and prompts at the bottom. The park sim is untouched.

Status: **Done**: you looked and approved it (2026-10-17).

## PORT-20: DINOSAUR, SPACE and UNDERSEA (asked for 2026-10-17)

The SNES's other three venues (ADR-046), drawn at 960x540 by the level pipeline in the levels' style and manifest format: each has the eight parallax layers, the court mask, its venues.json default court (DINOSAUR GREEN / ORANGE / GRASS / WHITE, SPACE NAVY / PURPLE / ASPHALT / CYAN, UNDERSEA AQUA / NAVY / SAND / WHITE), four standing spectators, and a watcher spot behind the fence. DINOSAUR: a sunset jungle, palms, a volcano with lava and smoke, a long-neck over the trees, pterodactyls; a stegosaurus, raptors, a triceratops and a T. rex over a wooden palisade. SPACE: stars, a nebula, Earth, Saturn, a moon, a dome, a rocket on its gantry; aliens and astronauts behind a lit chain-link fence. UNDERSEA: light shafts and bubbles, a shipwreck, fish, jellyfish, a turtle, kelp and coral; an octopus, crabs, a pufferfish, a seahorse and a starfish along a rope fence. The creatures are shapes lit by `pix.solid` (`art/levels/tools/critters.py`). In the game: the COURT page's VENUE cycles all six, the ladder's GYM BROS, GOTH CLUB and SURF CREW play at home there (VS sets the venue), the venues' own ambience loops play by day, and every TIME works (NIGHT plays the crickets, as on the SNES).

Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

## PORT-21: career players (ADR-047, asked for 2026-10-17)

MAIN's RECORDS row is now CAREER: three save slots, each a named player with a look, lifetime stats and unlocks, and the old records behind a RECORDS row. A slot opens the player's card (singles and doubles W-L, aces, shutouts, best streak, longest rally, unlocks n/9 and the next with its hint) and makes them active; an empty slot makes a new player, named on an arcade keyboard, then dressed in the editor (body, skin, hair, shirt, hat, paddle; locked hair and hats are skipped; a GEAR row shows the hat's shift on the paddle), with a big portrait beside it. NO PLAYER plays as before. The active player is 1P: Player Select starts on their look (skin, hair and hat on the portrait and thumbnails, the gear in the bars), the HUD shows their name, open play, the ball machine and the park's walk-around sprite use their saved look, and their hat's gear applies to their paddle (ADR-047 stage 4). Matches against the CPU (not the demo, practice, 2P versus, or multiplayer) count, and after the initials card an UNLOCKED! card lists what was just earned.

Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

## PORT-22: music (asked for 2026-10-17)

An original soundtrack, where the SNES had none (ADR-029/031's `M4-AUDIO-03`; ADR-052 amended): a title theme (D major, 132 BPM), the park's theme for open play (G, 116), a calmer match loop per venue (PARK: F, 100, electric piano and flute; LAKESIDE: A, 94, marimba and bells; SUNSET: Eb, 86, mellow keys and a round lead), and stingers for match won, match lost and ladder cleared. All composed and synthesized by `audio/music/make_music.py` (numpy, fixed seeds; see its README): 48 kHz stereo, loops seamless. `view/music.gd` crossfades between screens, stings a match's end, ducks under the applause and the whistle, and follows SOUND; MUSIC (OFF..100%) on OPTIONS, saved.

Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

## PORT-23: a cleanup round (asked for 2026-10-18)

Step back and organize, and fix what turned up: players flashing in the top-left corner whenever the title's demo restarted (a new COURT or TIME), every match leaking its whole sim, the title's CAREER pages split into their own component, one `UiKit` for the panels and labels seven screens built by hand, and the docs: this sheet down to an index (the full tasks moved to `design/PORT_HISTORY.md`), `game/README.md` and `CLAUDE.md` current. Two open defects closed on the way: the e2e's save is per checkout (KNOWN_ISSUES #42) and `sync_assets.sh` keeps the import files (#43).

Status: **Done**.

## PORT-24: the overhead (asked for 2026-10-18)

A smash, which the SNES never had (ADR-053): a HIT or DRIVE swing at a falling ball 20 px up or higher becomes `SHOT_OVERHEAD`, twice a drive's pace, hit flat or down, aimed like a standard shot, and lengthened just enough to clear the tape (a dumped overhead only when it can't). SOFT still blocks. The CPUs smash with no new logic (their put-away and any lob they get under). The view: the overhead frames, SMASH! over the contact, the biggest shake and rumble, its own sound (`0_hit_smash*`), and a SMASHES row on the stats card.

Status: **Ready to test**: get under a lob (practice: SHOT LOB) and swing with HIT or DRIVE. Does it feel strong enough, and too common in doubles?

## PORT-25: the tournament (chosen 2026-10-18)

TOURNAMENT on MAIN (ADR-054): an eight-entry knockout, you as top seed and seven ladder teams (the warm-up HENDERSON sits out), QUARTERFINAL, SEMIFINAL, FINAL, each match at the opponent's home court with their intro card. The bracket screen (`view/bracket_screen.gd`) shows the draw, scores, connectors and the champion; START / MODE / BACK before it starts, PLAY / FORFEIT (twice) / BACK during, NEW TOURNAMENT after. The other matches are decided from the tournament's seed (the higher rung usually wins) and appear one at a time when you come back. The result screen says BRACKET, and OUT AS SEMIFINALIST or CHAMPION! when it ends. Saved: the bracket in play, and cups in the records (RECORDS: SHUTOUTS CUPS). MAIN's footer prompt went (the key legend says HIT) to make room for the row.

Status: **Ready to test**: TOURNAMENT on MAIN. Is the road's ramp right (SNOWBIRDS first), and do upsets feel too common or too rare?

## PORT-26: no volleys from the kitchen (reported 2026-10-18)

A volley from inside your own kitchen loses the point, KITCHEN! (ADR-055; the SNES left it out as "ARCADE RULES"). Standing in it, or hitting a ball that bounced there, stays legal. The two-bounce rule's VOLLEY! comes first. The CPUs never volley from their kitchen (they step back or let it bounce). Manual, guide and README updated.

Status: **Ready to test**: stand in your kitchen and try to volley.

## PORT-27: split the match view (chosen 2026-10-18)

`view/match_view.gd` (about 800 lines) loses three parts, each a RefCounted holding the view, as the title's CAREER pages did: `match_actors.gd` (the people and ball: sprites, frames, the swing choice, sparks, SMASH!), `match_input.gd` (each slot's intents, multiplayer pads, the input lock, SERVE ASSIST, a dropped pad, the pause menu) and `match_end.gd` (records, ladder, bracket and career at the result; the initials and UNLOCKED! cards). The view keeps the scene, the frame and the events (471 lines) and thin wrappers for what the HUD, tools and tests use.

Status: **Done**.

## PORT-28: each pad's own buttons (chosen 2026-10-18)

Prompts draw the pad family's buttons (`view/prompts.gd`): Xbox (as before, and any unknown pad), PlayStation (cross, circle, square, triangle drawn as shapes; L1 R1 L3 R3, OPTIONS, CREATE) and Nintendo (B A Y X by position, since Godot maps pads by position; L R, + and -, all grey). The family comes from the last pad's name (`Prompts.family_of`), or BUTTON ICONS on CONTROLS (AUTO, XBOX, PLAYSTATION, NINTENDO; saved, a new key with a default). Display only: the bindings don't change.

Status: **Ready to test**: plug in a PlayStation or Switch pad. Does it pick the right icons? Is your pad's name one I don't know?

## PORT-29: the couch cup (chosen 2026-10-18)

A multiplayer tournament (ADR-054 amendment): the lobby's LB / RB step through SINGLES, DOUBLES, SINGLES CUP and DOUBLES CUP; a cup enters each player (singles) or side (doubles) in an eight-entry bracket as its top seeds, in separate quarters, with CPU teams from the ladder's top. Human against CPU at the team's court; human against human on their own pads. A round's CPU matches wait for its human matches. The bracket screen says COUCH CUP, names the entries in their shirt colours, and PLAY sends each human slot's pad. Its own save slot; never in the records. The HUD now names a multiplayer side by its players.

Status: **Ready to test**: MULTIPLAYER, RB twice, join with two pads.

## PORT-30: HOW TO PLAY (chosen 2026-10-18)

Six lessons (`meta/tutorial.gd`, `view/tutorial_view.gd`), each a real sim with one goal read from its events: RALLY (the ball machine at you: 3 returns), SHOTS (a DRIVE and a SOFT landed), SMASH (the machine lobs: 1 smash in), SERVE (vs a KID CPU: 2 in), TWO BOUNCES (2 rallies past the rule), THE KITCHEN (2 volleys from behind the line). A card first (the match waits, its press doesn't swing), then a banner with the progress and advice after a miss (VOLLEY!, KITCHEN!, a serve fault, a missed lob), LESSON DONE!, and the next. MAIN's PRACTICE opens a page: HOW TO PLAY (from the first lesson not done), LESSON (any one), BALL MACHINE. MAIN's PRACTICE row says HOW TO PLAY until one's done. Lessons record nothing but themselves (`records.lessons`, a bit each).

Status: **Ready to test**: PRACTICE > HOW TO PLAY. Is SMASH too hard?

## PORT-31: online play (asked for 2026-10-18)

1 vs 1 singles over the internet by address (ADR-056, your choices: direct connections, singles first). MULTIPLAYER opens a page: LOCAL (the lobby) or ONLINE (`view/online_screen.gd`: HOST A MATCH, ADDRESS, JOIN). ENet on UDP 24994; HELLO with the versions and looks; the host's START sends the match; lockstep over the exact sim with an input delay fitted to the measured round trip, a wait when an input is late, a hash every 2 s against desyncs. Menu leaves (twice in play), the host rematches, nothing recorded. README: how to connect (same Wi-Fi, Tailscale, or a forwarded port).

Status: **Ready to test**: with a friend. Start on the same Wi-Fi, then over Tailscale.

## PORT-32: updates in the game (asked for 2026-10-18)

OPTIONS > UPDATES (ADR-057): a check of GitHub's latest release at start, the news on the title, a download of just the game's .pck (checked against the release's SHA-256), and RESTART onto it. The boot scene (`scenes/boot.gd`, now the main scene) loads a newer downloaded pack before anything else, then adds the input map and the updater (no longer autoloads) and the title; a start that never reaches the title is skipped next time. CI publishes the .pck and its manifest (`tools/update_manifest.py`) with each release. The layout test now also fails on a character the font can't draw (it found ONLINE's invisible typing cursor).

Status: **Ready to test**: after 0.9.0, the next release (0.9.1) is the first real update. Not tried on Windows or Linux.

## PORT-34: from playing 0.9.1 (2026-10-18)

Four things you found: the update now comes up when the game opens and can't be skipped (`view/update_screen.gd`, ADR-057 amended); OPTIONS > UPDATES no longer sticks on 98%; HOW TO PLAY's match lessons play HENDERSON at full speed (KID's slowed ball read as slowdown) and THE KITCHEN is a ball-machine drill; ONLINE's HOST screen shows up to two addresses, 192.168 first, named by adapter.

Status: **Ready to test**: 0.9.1 gets 0.9.2 from OPTIONS > UPDATES once; from then on updates come up at launch.

## PORT-35: catch the sim up to the ROM (planned 2026-10-18)

The sim is the ROM's at TUNING_VERSION 4 (port ADR-059; with PORT-41's slice). The SNES repo's conformance traces come in by `tools/conformance_import.sh` and `test_conformance` replays all four scenarios frame by frame: every frame matches. On the way: the ROM's `opponents.json` and `quips.json` (the rebalance, serve power and duds, sixteen quips and the deck), the serve's depth, aim and power, the lane covers' stagger per match, KID's top speed, ICE and POPCORN in the sim and the AI, GHOST in the view, the kitchen line, and a ladder per mode (save v6, a quit resets it). GHOST BALL, POPCORN, ICE are on MODIFIERS.

Status: **Done**: the conformance traces are the proof. The upper rungs are easier than before (the ROM's playtest); say if they feel off.

## PORT-36: about this project, and Tiny Chair

About this project, and Tiny Chair: the bible's ground rule 1 note, and a Tiny Chair splash in the A-11 colours after a name search.

Status: **In progress**: the splash waits on the name search and the logo's final art (bible A-11); the releases already published don't carry the line (For you).

## PORT-37: the period-true park (planned 2026-10-18)

Period-true park: courts ROOKIE / CLUB / CHAMP (the port shows DUPR-style `UNDER 3.5`), park points, winners stay on (two wins), pick your partner (SNES ADR-070 to 072).

Status: **Ready to test**.

## PORT-38: career and the Hat Museum (planned 2026-10-18)

Career and the Hat Museum: 13 hats and 16 unlocks (the port has 6 and 9), the museum (SNES ADR-059 to 061), new hat art.

Status: **Ready to test**.

## PORT-39: the show (planned 2026-10-18)

The show: rings at each player's feet, celebrations, slumps, emotes, net shiver, critters, more quips, and GLOW / INVERSE redone for full colour (SNES ADR-054, 063, 064, 066).

Status: **Ready to test**.

## PORT-40: the Pickleball '95 promises (and the branches after it)

The Pickleball '95 promises (bible §5.8): Dale Dawson as an unlockable (§3), side-out scoring, the momentum rule, new modifiers; the overhead smash is already in (PORT-24).

Status: **In progress**.

## PORT-41: four swings and the short hold (asked for 2026-10-18)

The first piece of PORT-35 (ADR-058): SNES ADR-056 and 057. SLICE (slow, never deep, steady), SHORT held (any swing goes short, the D-pad still moves), the fast drop's long spray off a stretch, and CPUs that slice (WALT, RAVEN, VLAD 3; ACE, JADE 4). Pad by position: SLICE north, SHORT LB or RB; keyboard I and Shift/U; both on CONTROLS. The overhead moved to shot 4 so the slice has the C's number; its own sound; the key legend and the SHOTS lesson teach all four.

Status: **Ready to test**: try I / Y for the slice and hold Shift / LB with each swing.

## PORT-42: cleanup round 4 (asked for 2026-10-19)

Organize the files, optimize the code, clean up the docs. Docs: one heading per roadmap task (the release notes had dropped PORT-37 to 40), the finished tasks moved to the history, the SNES-era docs into `design/snes/`, 37 broken links fixed, KNOWN_ISSUES split into open, resolved and the SNES game's, the READMEs current. Code: text doesn't redraw unchanged, hidden menu pages and the hidden lobby stop working every frame, the lobby dresses a card only when it changes, palettes.json and manifest.json are read once, the host screen reads the adapters once; dead code out; `UiKit`, `PlayerLook.team_sheet` and `TestSuite.fresh_save` own what was copied; the AI's and Feel's references typed. Then the splits: `title_pages.gd` (the title's page tables), `hud_cards.gd` (the HUD's cards), `park_message.gd` (the park's panel text), `sim/multi_ball.gd` (MULTI BALL, so `sim.gd` keeps the C's shape), and `MenuPage.drive()` for the five copies of the menu keys.

Status: **Done**.

## PORT-43: rally heat (asked for 2026-10-19)

Visual cues for a long rally (ADR-068), display only: at 10 shots the ball and the RALLY sign catch fire; from 15, and a step darker every 5 after, everything but the court dims, the players in a spotlight; the point's end lets it go. The ball speeding up as a rally goes on is set aside for now.

Status: **Ready to test**: play a long rally; say if the steps should come sooner, go darker, or the fire be bigger.

## PORT-44: story mode (asked for 2026-10-19)

STORY: SAVE THE PARK (ADR-069), the SNES story's plot told as a visual novel: eight chapters, one per ladder team, each a chapter card, a scene at its venue and time (you and Pepper, the team, Grimsby on the loudspeaker or in letters), a doubles match with Pepper and the chapter's twist, and the petition signed; the ending, THE END, and an epilogue pointing to Dawson. Progress is saved; a clear unlocks Dawson.

Status: **Ready to test**: play chapter 1; say what to change in the writing (`game/data/story.json`), the pacing, or the twists. - Fix (`feature/cld-story-paper`): Grimsby's notices and the petition were hard to read (the outlined fonts tinted dark ran together); the paper's text is now ink: the letters' fill alone, solid, no outline (`BitmapText.ink`).

## PORT-45: the real game (asked for 2026-10-19)

PICKLEBALL 101 (ADR-070), on PRACTICE: eight lessons on real pickleball (the court, the serve, the two-bounce rule, the kitchen, keeping score, line calls, playing smart, court manners), each page with an animated court diagram, 17 quizzes, TRY IT links to the matching HOW TO PLAY drills. Progress saved (DONE, PERFECT).

Status: **Ready to test**: read a lesson or two; say if anything should be explained differently (`game/data/pickleball101.json`). - Added (`feature/cld-rally-scoring-lesson`, the user's note): KEEPING SCORE now names side-out as the park's way and adds rally scoring (every rally scores; this game plays it; MODIFIERS, RULES, SIDE-OUT switches) with a quiz.

## PORT-46: ball speed (asked for 2026-10-20)

BALL SPEED (ADR-071), MODIFIERS' first row: 70% to 130% in 1% steps, 100% the ball as it was. A shot lands where it was aimed over 100 / speed as many frames (so a slower ball also arcs a little higher, as MOON does). Saved; every match, drill and online game gets it.

Status: **Ready to test**: try 90% to 95%; say where it feels right and I can make that the default.

## PORT-47: the ball's defaults (asked for 2026-10-20)

(ADR-072) BALL SPEED defaults to 78% (the user's pick; untouched 0.16.0 saves move to it); BALL SIZE, display only, 80-150%, 105% by default.

Status: **Ready to test**.

## PORT-48: longer rallies (asked for 2026-10-20)

(ADR-073) Measured with `tools/rally_stats.gd`. BALL SPEED now paces the ball as the ROM does on KID and EASY (same flights, slower; ADR-071's higher arcs had made balls unreachable), drawn gliding; CPU ERRORS on MATCH SETUP, 50% by default, spaces the CPUs' late swings. Doubles rallies at MEDIUM: 8.1 shots (the ROM) to about 12.5; singles 6.4 to 9.

Status: **Ready to test**: say if rallies should run longer still (CPU ERRORS lower) or the CPUs should reach more.

## PORT-49: the tuning panel (asked for 2026-10-20)

(ADR-074) F2 or the pause menu's TUNE: a flyout during a match, the match waiting. BALL SPEED, BALL SIZE and CPU ERRORS live (and saved); every modifier and rule, with APPLY restarting the match with them; DEFAULTS. Not online or in the demo.

Status: **Ready to test**: say what else belongs on it.

## PORT-50: new ball defaults (asked for 2026-10-20)

(ADR-072, since) BALL SPEED 85% and BALL SIZE 110% by default, the user's picks after playing 0.17.0; untouched saves move to them (`ball_speed_v` 2), choices are kept.

Status: **Ready to test**.

## PORT-51: PLAY OF THE MATCH (dealer's choice, 2026-10-20)

(ADR-075) When a match ends, its longest rally replayed television-style (REPLAY bug, card, half-speed finish, how it was won), skippable; the real rally, re-run from the recorded inputs by a second sim and checked against the live one.

Status: **Ready to test**: finish a match with a long rally. Say if it should be optional (a setting), or show a second-best too.

## PORT-52: the announcer (asked for 2026-10-20)

A voiced 1994 TV announcer, with no text on screen (the user: captions would clutter it). Step 1 done: the script, `design/announcer/SCRIPT.md` and `lines.csv` (253 lines by trigger: the title, venues, teams by their canon players, modifiers, serves and aces, score calls built from numbers, rally shots, long rallies, how each point ended, streaks and match point, pickle puns, pauses and replays, the match's end, the ladder, bracket and story), with the recording spec. `make_script.py` makes both. Step 2: the user records them with an AI voiceover. Step 3: wiring them to the events, with a volume, how often it talks, and ducking.

Status: **Ready to test**: play a match with sound. Say if it talks too much or too little (COMMENTARY), or a line should go.

## PORT-53: after playing 0.19.0 (asked for 2026-10-20)

The team intros out (too long); `design/announcer/removed.txt`, the list of lines to take out, honoured by `prep.py` (244 clips now); ANNOUNCER an ON/OFF switch, VOICE VOLUME its own row (ADR-076, since). PLAY OF THE MATCH's players were frozen in the match's end reaction: fixed (KNOWN_ISSUES #67, ADR-075, since).

Status: **Ready to test**: add any line to `removed.txt` (or tell me its id).

## PORT-54: `feature/cld-crowd-parallax`, `feature/cld-achievements` (asked for 2026-10-21)

The crowd and the watcher move with the stands as the camera leans (KNOWN_ISSUES #68). Achievements (ADR-077): thirteen, PICKLED first; a toast and a chime as each unlocks; RECORDS > ACHIEVEMENTS lists them with how to earn each.

Status: **Ready to test**: say which achievements to add next.

## PORT-55: the announcer's second batch (asked for 2026-10-21) (not in this build)

A second list to record, `design/announcer/ADDITIONS.md` and `additions.csv` (17 lines, `make_additions.py` makes both): under WIN BY 2 past game point, advantage (serving or receiving side) and deuce; an achievement's line as it unlocks. The game already asks for them and falls back to what it said before ("win by two", nothing) until they're in `audio/announcer/raw/`. Score calls need nothing new: the numbers go to twenty-five.

Status: **Done** (the power-up lines wait for power-ups).

## PORT-56: the near-side reach (asked for 2026-10-21)

KNOWN_ISSUES #69, the look only (the user's call): a ball on the near side of a player gets the low reach and a step down toward it; the ROM's hit area is unchanged.

Status: **Ready to test**.

## PORT-57: `feature/cld-title-record`, `feature/cld-park-locations` (asked for 2026-10-21)

The title's line under the logo is just the RECORD (the ladder's place resets on a quit, so it isn't progress; RECORDS keeps it and the clears). OPEN PLAY's locations (ADR-078): THE PARK, DINO PARK, THE GYM, one plan in three looks; THE GYM's games at the new indoor GYM venue (always lit, its own ambience and music).

Status: **Ready to test**: walk both, and play a game in each.

## PORT-58: `feature/cld-lobby-sides`, `feature/cld-player-tags` (asked for 2026-10-21)

The lobby: doubles takes any split (two players together against two CPUs, or one each side with a CPU partner; humans only on the right swap ends); LB / RB go round the four modes, shown as tabs; the line says who plays whom ("P1 + P2 VS CPU + CPU"). The tags over the players: the text centred, the pointer in the player's colour (KNOWN_ISSUES #70).

Status: **Ready to test**.

## PORT-59: cleanup round 5 (asked for 2026-10-21)

The local branches merged into `origin/main` deleted (73; the two still checked out in agent worktrees, both merged, stay until those are cleaned up). The code: the three sliders (BALL SPEED, BALL SIZE, CPU ERRORS) defined once (`Settings.SLIDERS`, `Settings.nudge`, `view/setting_rows.gd`) for the title and the tuning panel; PLAY OF THE MATCH's event handling in `highlight.gd`, out of `match_view.gd`; a dead `Announcer.speak_ids`; `TestSuite.match_view` for the tests' match setup. The docs: PORT-42 to 58 (but 55) moved to `PORT_HISTORY.md`, the index naming each task's release; `decisions/README.md`, an index of the ADRs; the bible plan's list of the remaster's own additions; the README's file layout.

Status: **Done**.

## PORT-60: the park's stack and winners staying (asked for 2026-10-21)

KNOWN_ISSUES #71: the rack draws a pair of paddles for each waiting team (one a player, as real stacking reads), the panel counts the teams ahead of you, and a win that keeps you on says so (WINNERS STAY ON, then YOU STAY ON COURT n with STEP OFF at its rack). The park's rules (SNES ADR-070 to 072) are unchanged.

Status: **Released (v0.21.1)**.

## PORT-61: the swing-arm ball machine (asked for 2026-10-21)

KNOWN_ISSUES #34: practice's machine is row C of `art/concept/ball-machine.png`, a cart with a hopper of balls and a launcher arm on a pivot, built in Aseprite (`art/sprites/machine`: `machine.py` draws the layers, `build_machine.lua` makes `machine.aseprite` and the sheet). The arm has nine angles and swings through them toward the sim's pose (up, centre, down) instead of snapping; it recoils along itself on a feed. Display only: the sim's poses and feeds are unchanged.

Status: **Ready to test**.

## PORT-62: player specials and powerups (asked for 2026-10-21) (not in this build)

`design/SPECIALS_AND_POWERUPS.md`, a running document: a SPECIAL button with a meter (route A), powerups on the court (route B), or both (route C, the pick so far); specials by paddle, with the '95 overhead smash as PICKLE SMASH; the first powerup list. Nothing built yet.

Status: **In progress** (waiting on the questions in the doc).

## PORT-63: practice without the announcer (asked for 2026-10-21)

KNOWN_ISSUES #72: no announcer in practice. With no points there, its rally lines counted the machine's feeds, missed or not, as one long rally. Lessons and matches are unchanged.

Status: **Released (v0.22.1)**.

## PORT-64: the title menu regrouped (asked for 2026-10-21)

ADR-079: MAIN is STORY, PLAY, PRACTICE, PLAYER and OPTIONS (was twelve rows). PLAY has QUICK MATCH (SINGLES or DOUBLES, one row), TOURNAMENT, OPEN PLAY and MULTIPLAYER; QUICK MATCH opens MATCH SETUP (START, MODE, PLAYERS, VS, DIFFICULTY, CPU ERRORS, POINTS, COURT, MODIFIERS); PLAYER has the players, RECORDS, ACHIEVEMENTS and the HAT MUSEUM. BACK goes to the page you came from; after a match the title opens where it started (MATCH SETUP after a quick match). Mocked up first with the game's panels, then built as mocked.

Status: **Released (v0.23.0)**.

## PORT-65: SPECIALS, the meter and PICKLE SMASH (asked for 2026-10-21)

ADR-080: SPECIALS on RULES (off by default, off in the ROM's game). Each player's meter fills with shots, points won and time in a rally; SPECIAL (O, the right trigger) spends a full one on PICKLE SMASH: twice a drive's pace, never stretched, always over the net, aimed deep away from the other side, and its return pops up soft (the knock-back). The CPUs use it too. Meters under the score panels, a PICKLE SMASH prompt, the PICKLE SMASH! pop.

Status: **Released (v0.24.0)**.

## PORT-66: three light effects (asked for 2026-10-22)

`view/court_effects.gd`, display only and deterministic: a scuff where the ball bounces, fading over four seconds (a dozen at most); camera flashes among the crowd at the big moments (a 15, 20, 25 or 30-shot rally, PICKLE SMASH, match point, the match won), none with FLASHES off or in the demo; the net wobbles (a couple of pixels) when a ball clips the tape and carries over, with the net's sound, and when one goes into it. A few shapes a frame each, no new shaders or particles.

Status: **Ready to test**.

## PORT-67: the players' body and swing (asked for 2026-10-22)

A side-by-side test first (`art/sprites/hd/v2/`: v2 `.aseprite` copies of the 48 px players, old-vs-v2 GIFs and a still), then the same changes in the game's players (`art/levels/tools/players.py`): the shirt tapers from the shoulders to the waist (a V, not a bean), the hips sit higher (a shorter torso, longer legs), the shorts are narrower at the waist and a little longer. The forehand uses the body: the windup coils the shoulders and loads the back leg, contact drives onto the front knee with the back heel up, and the follow-through wraps the paddle up (tilted forward, clear of the face) with the back foot dragging on its toe. The head is left alone: no head code changed and every pose keeps its neck, so heads, caps and hats are pixel-identical (every cap and hat overlay sheet is byte-identical to before).

Status: **Ready to test**.

## PORT-68: the SPECIALS meters under the players (asked for 2026-10-22)

ADR-080, amended: each player's SPECIALS meter is a small fixed-width bar under their feet (in their colour, gold when full), following them, flipped or not, all four in doubles, instead of a bar under the score panel that grew with the team name. The PICKLE SMASH prompt stays under the score panel. Display only.

Status: **Ready to test**: play a match with SPECIALS on (RULES) and say if the bars read at a glance and sit well under the feet.

## PORT-69: saved replays (asked for 2026-10-22)

ADR-081: **SAVE LAST RALLY** on the pause menu keeps the rally that ended last (PLAY OF THE MATCH's recording, cut after it) as a file under `user://replays/`, six at most. **REPLAYS** on PLAYER lists them, newest first; a press watches one full screen with a SAVED REPLAY card (or, with ON PRESS set to DELETE, deletes it). **IN THE DEMO** (on) lets the title's demo play them, every other time, between live matches. A replay from another sim lists as OLD VERSION.

Status: **Ready to test**: save a good rally from the pause menu, then watch it from PLAYER, REPLAYS, and let the title sit to see it in the demo.

## PORT-70: SAVE on PLAY OF THE MATCH (asked for 2026-10-22)

ADR-081, amended: while PLAY OF THE MATCH plays, SAVE (soft: X or L, beside SKIP) keeps the match's best rally in REPLAYS. The card says SAVED (and SAVE goes) or REPLAYS FULL; never twice, and not on a saved replay's own card.

Status: **Ready to test**.

## PORT-71: replays trimmed to the rally (asked for 2026-10-22)

ADR-081, amended: a replay (saved, or PLAY OF THE MATCH) opens just before the serve is struck, not at the serve's setup; any pause in the rally runs unseen (the sim steps while paused, so the pause menu used to show in the replay); and it ends 50 frames after the point (was 80). The recording is unchanged, so the replay is still exact. Replays saved before this have no serve frame and still open at the setup, but skip their pauses.

Status: **Ready to test**: save a rally you paused in, and one you waited to serve, and watch them from REPLAYS.

## PORT-72: L for SHORT, R for SPECIAL (asked for 2026-10-22)

ADR-082: on a pad, L and the left trigger are SHORT, R and the right trigger SPECIAL (PICKLE SMASH); SHORT was either shoulder and SPECIAL the right trigger. The keyboard is unchanged. A save's old bindings load with R on SPECIAL. Departs from the bible's "L or R" (For you).

Status: **Ready to test**: try L and R in a rally.

## PORT-73: generic pads, mapped (asked for 2026-10-22)

ADR-082: OPTIONS, CONTROLS, **CONTROLLER**: the pad in hand, **MAP BUTTONS** for a pad SDL doesn't know (it asks for each action, naming the SNES button, from the pad's raw buttons, hat or axes), **CLEAR MAPPING**, BUTTON ICONS (moved here, with a new SNES family) and PAD NOTICE. The map becomes an SDL mapping string given to Godot, saved per pad model (GUID) and given again whenever the pad connects; a mapped pad draws as a SNES pad.

Status: **Ready to test**: plug in a SNES USB pad, open OPTIONS, CONTROLS, CONTROLLER, and see what MAP BUTTONS says. UNKNOWN: press it and answer each step. STANDARD: SDL knows it already; try it in a match, and fix any button on CONTROLS.

## PORT-74: a controller recommended (asked for 2026-10-22)

ADR-082: with no pad connected, the title opens on A CONTROLLER IS RECOMMENDED (OK, DON'T SHOW AGAIN), once a session; a pad connecting closes it.

Status: **Ready to test**: start the game with no pad plugged in.

## PORT-75: smaller audio (asked for 2026-10-22)

ADR-083: first a comparison: nine clips (three SFX, the park ambience, two music tracks, three announcer lines) in Ogg q6/q4/q2, IMA-ADPCM, 22 kHz mono and MP3 beside their originals, with sizes against the QOA the game shipped (`audio/compare/`, `make_compare.py --estimate`). Then the switch: the 12 music files and 7 ambience loops ship as Ogg q4, encoded by `sync_assets.sh` (`tools/encode_ogg.py`, reproducible bytes); effects and the announcer stay WAV/QOA. The `.pck` goes from about 34 MB to 18.5 MB.

Status: **Ready to test**: play a match at the park and at SPACE past the loop's end (about 40 s) and listen at the wrap; compare the title music with `audio/compare/out/music_title_original.wav`.

## PORT-76: the dinosaur game's dinosaurs at DINOSAUR (asked for 2026-10-22)

ADR-084: the Carnotaurus of the SNES dinosaur game, with Nathan up, walks the DINOSAUR venue's stands behind the fence (his own `mount_walk` and `mount_idle` frames, 1x), stops to look about, turns back, and once a lap walks off the right edge and returns. From the same game: the Spinosaurus breathes in the jungle's gap, the baby dinosaur patrols the jungle's edge (2x), and the pterodactyl crosses the sky behind the volcano. The sprites are exported as drawn (`art/sprites/dinos/export.sh`, the dinosaur repo only read) and drawn by `view/dino_walkers.gd`: display only, from the frame count, each on a backdrop layer's parallax and tint. The raptor, T. rex and Brachiosaurus were tried and left out (the venue paints all three). OPEN PLAY's DINO PARK has them too: the Carnotaurus strolls the sand path among the people (sorted by his feet), the baby patrols the grass by the T. rex statue, the pterodactyl flies over the courts. He roars (his `mount_roar`) when a long rally (10+ shots) ends or a match is won, and in DINO PARK when you come back a winner.

Status: **Ready to test**: play a match at DINOSAUR and watch the fence line for a minute (his lap is about 80 s) and for a roar after a long rally; walk DINO PARK's path, and come back from a win there.

## PORT-77: the dinosaur game's levels as courts (asked for 2026-10-22)

ADR-085: four venues from the dinosaur game's level concepts (`../dinosaur/assets/levels`), after the GYM on COURT > VENUE. **RUINS** (`01-ruins.png`): a burning, drowned city under a purple and orange sunset, a broken bridge, mossy pillars and rusted girders, the crowd on a mossy wall; PURPLE court, CLAY kitchen, cracked CONCRETE. **GLACIER** (`ice-wilderness.png`): snowy peaks at dusk, ice spires, the aqueduct hung with icicles, snowy pines; BLUE and NAVY on SNOW. **LAB** (`science-lab.png`, indoors): green tanks with a T. rex, a raptor and a long-neck's skeletons, a hazard-striped catwalk, consoles, a raptor loose on the deck behind a yellow rail; BLACK and GREEN, YELLOW lines, steel plates. **STATION** (`space.png`, indoors): windows on a nebula, a ringed planet, asteroids and a wreck, orange-lit rails and consoles, an astronaut and a drone; SLATE and ORANGE on deck plates. Dinosaurs only at the LAB (your call after the first cut): there Nathan rides the Carnotaurus along the deck (ADR-084's sprites, with the roar). Each has its own ambience and match track; the announcer's lines for them are in the batch to record (until then: the format).

Status: **Ready to test**: COURT > VENUE, play a game at each and listen to the ambience and track; try TIME at RUINS and GLACIER (LAB and STATION stay lit).

## PORT-78: keyboard controls you can guess (asked for 2026-10-23, parked) (not in this build)

The keyboard layout (`game_ui/controls.gd`) grew one SNES button at a time: hit Space/J, drive K, soft L, slice I, short Shift/U, special O, so nothing about where the keys sit says which shot is which, and the prompts show the first key only (SHIFT, not the U I O over J K L grid). There's no single standard, but two conventions: emulators (RetroArch, Snes9x: arrows, Z = B, X = A, A = Y, S = X, Q/W = L/R, Enter = Start) and PC action games (WASD, the common actions on J K L, the rare ones on U I O). The proposal: two presets on CONTROLS, on top of REBIND (`game_ui/bindings.gd`): | | WASD (default) | Arrows | |---|---|---| | Hit | J | Z | | Drive | K | X | | Soft | L | C | | Slice | I | S | | Special | O | D | | Short (held) | Shift or Space | Shift | The three shots in one row in one order, the rarer ones on the row above. And the lesson cards draw the keys where they sit (a little keyboard) instead of a line of names.

Status: **Planned**, parked until you've decided the layout.

## PORT-79: text centred in the bars and keys (asked for 2026-10-23)

Known issue 77: the menus' highlight bar, MAP BUTTONS' bar and the prompts' keys had their text about 3 px low (the offsets didn't allow for the small font's outline and shadow). The bars start 2 px above the letters (the change arrows and the mouse's row bands follow), keys and pills are 24 px tall with a 2 px lip, and the key letters and their labels share one height (`PromptBar.TEXT_Y`). Display only, no ADR.

Status: **Ready to test**: look at any menu and the prompts, and at a pad's prompts (the round buttons' letters moved up 3 px; not screenshotted).

## PORT-80: cleanup round 6 (asked for 2026-10-23)

The local branches merged into `origin/main` deleted (33; `feature/cld-release-0.26.0` kept: it has commits its remote branch lacks, though `main` has them; the two in agent worktrees stay). The code: a hit's spark and smash pop in one place (`MatchView.contact_fx`, the match's and PLAY OF THE MATCH's replay); SAVE LAST RALLY's rules in `Highlight` next to PLAY OF THE MATCH's SAVE; one `TitleScreen.back_to` for the seven ways back to a page; the dinosaurs' looks once (`DinoWalkers.LOOKS`, merged into DINOSAUR's and DINO PARK's casts, checked equal to the old tables); `PadMaps.short_name` for CONTROLLER and MAP BUTTONS; QUICK MATCH and MODE share their row; "PRESS AGAIN" for "B AGAIN" (prompts, not button names); stale comments (the announcer's recorded lines, the SNES icons). The tests: `TestSuite.title_screen` for 25 copies of the title's setup. New: a rally saved once by SAVE LAST RALLY and PLAY OF THE MATCH, whichever first, and a new match forgetting the best; replay files that aren't replays, another format, two in one second; practice's view against a bare sim; QUICK MATCH's DOUBLES and SPECIALS surviving a restart (and an old save without the key); `test_layout` for the park's YOU STAY ON COURT and 2 TEAMS AHEAD, the CONTROLLER page at its longest name and every status, and the mouse picking a row anywhere on its bar; pad names cut to fit. The docs: PORT-55, 59 to 77 (but 62) moved to `PORT_HISTORY.md`. Then, at your call: replays show the match's light effects too (the bounce marks, and the camera flashes when a saved one is watched from REPLAYS; none behind the title's menu, as in the demo). And known issue 78: SMASH! pop-ups one at a time (two could overlap).

Status: **Done**.

## PORT-81: touch controls on the web (asked for 2026-10-23)

The web build had no touch input (a tap on a menu row worked, through Godot's mouse emulation; a match couldn't be played). Godot has touch events and `TouchScreenButton`, but no D-pad node, so one `TouchPad` node (`view/touch_pad.gd`, port ADR-086) tracks the fingers and presses the input map's actions through `Input`: a SNES pad with the D-pad bottom left, B A Y X bottom right (hit, drive, soft, slice), START, L (SHORT) and R (SPECIAL) up top. The prompts follow it (B HIT, A DRIVE...). TOUCH PAD on CONTROLLER: AUTO (a touch screen, no pad), ON, OFF. Taps off the pad still drive the menus; a tap on a button doesn't click the row under it; a part with a menu's panel under it steps aside. No controller card on a phone.

Status: **Ready to test** on a phone: export the web build (`game/tools/export.sh`), serve it and open it on a phone in landscape. Try a match (move and hit with two thumbs, hold L while hitting), the menus by tap, and whether the buttons sit right under your thumbs. Known issue 79 lists what couldn't be checked here.

## PORT-82: ROAD TRIP, a roguelike mode (asked for 2026-10-23)

ROAD TRIP (port ADR-087; the plan with your answers and the art: `design/ROAD_TRIP.md`; the art in `art/roadtrip-v3` and `art/roadtrip-r4-fixes`, imported to `game/assets/trip`). A mode on MAIN beside STORY: you and a partner drive to the SUMMER OPEN on a road map of three legs (three columns of stops in three lanes, then a big match; the last leg's is the final against the Champs). Stops: PICKUP GAME, GRUDGE MATCH, YARD SALE, PRO SHOP, MOTEL, DETOUR. You start weak (a plain paddle and cap, four stats at 1 of 20); gear picked one of three (the game's paddles and hats, stacking items, partner training, one-sided rules) makes a trip strong. Three hearts; the trip can end. The miles fill the GARAGE's fixed ladder of lasting rewards (starting stats, a heart, gear, van paints and ornaments); beaten captains become partners; a trip won opens the next HEAT. Nothing counts outside the trip. Seeded: the map, picks, shop and detours are the same wherever played. The sim: `MatchConfig.trip` (a slot's stats, a CPU's style, the left side's perks), off everywhere else.

Status: **Ready to test**: play a trip or three. Say how it feels: too easy or hard (the bot wins leg 1 from the start and needs about 12 in every stat for the final), the length, the prices, the gear. Not built: the cassettes and the map's pen colour (KNOWN_ISSUES #82, #83).

## PORT-83: the painted venues (asked for 2026-10-24)

Seven venues from generated paintings (port ADR-088), after STATION on COURT > VENUE: WESTERN, ROOFTOP, PIRATES, MOTEL (the drained pool from ROAD TRIP's motel), FAIR, DRIVE-IN, MALL. The loop was ROAD TRIP's: I wrote the prompts and reviewed each round, you generated (`art/venues-r1`: prompts, references, concepts, plates, cutouts, locals, both reviews; MOTEL's re-layout in `art/venues-r2-fixes`). `art/levels/tools/painted.py` cuts the layers and paints the court on each floor; every venue has its own locals (`Crowd` takes a venue's sheet), its court presets, its own ambience and match track. MALL and the DRIVE-IN ignore TIME (indoors; already night). ROAD TRIP's legs visit them.

Status: **Ready to test**: play a match at each. Say if a scene, its crowd or its sound should change. Not done: the announcer's lines (KNOWN_ISSUES #85); no parallax (#86).

## PORT-84: the lite Web build (asked for 2026-10-24)

The Web build thinned, the desktop builds untouched (port ADR-089). Its preset carries the `lite` feature and leaves out the announcer, ROAD TRIP's art and the seven painted venues; the game, with `Settings.lite` on, hides ROAD TRIP and the announcer's rows and goes round the first eleven venues. `export.sh` exports it from a copy with its music and ambience re-encoded smaller (q1, the ambience mono). The Web pack is 12 MB (was 41), the zip 21 MB (was 51).

Status: **Ready to test**: open the Web build and listen to the music and the crowd. If q1 sounds rough, the setting is `WEB_QUALITY` in `game/tools/encode_ogg.py`.

## PORT-85: OPTIONS in the pause menu (asked for 2026-10-24)

Pause > OPTIONS (port ADR-090): the title's OPTIONS, ACCESSIBILITY, CONTROLS and CONTROLLER pages over a paused match, from one builder (`view/options_pages.gd`) both screens use. Closing saves them and applies CAMERA and HUD TEXT to the match.

Status: **Ready to test**: pause a match and change the sound.

## PORT-86: ROAD TRIP tuning (asked for 2026-10-24)

After your first trip (port ADR-091): leg 1's grudge and big matches are MEDIUM and its CPU errors 60% of the rest's, so its rallies are about twice as long. The partner is late on every 12th ball (was 7th), further apart with each CONTROL point from the MOTEL. Legs 2 and 3 and the final are unchanged.

Status: **Ready to test**: play a trip. Say if leg 1 is now right, and whether Pepper still lets balls go by.

## PORT-87: ROAD TRIP round two (asked for 2026-10-24)

ROAD TRIP grows (port ADR-092, no sim change): THE VAN over the map (Y / I) shows your stats as bars by where each point comes from, your partner's, and your gear; replaced paddles and hats go in the van's locker to swap back in; TRADE IN at the PRO SHOP; eight item sets. 19 new items, 4 hazards, 13 detours (7 at painted venues), the DINER (a meal for the next match). The story now grows across trips: 20 beats in four arcs (THE VAN, THE ROAD HOGS, THE CHAMPS, THE MIXTAPE) with lasting rewards (three story paddles, cassettes for the map's music), the ROAD HOGS as recurring rivals from the second trip, a captain partner's own start, and the SCRAPBOOK on ROAD TRIP's page.

Status: **Ready to test**: take two or three trips.

## PORT-88: the announcer's ROAD TRIP lines (asked for 2026-10-24)

29 ROAD TRIP lines added to the announcer's second batch (`design/announcer/ADDITIONS.md`, now 105 lines) and wired in: a stop's kind opens its match, your last heart, hazards, the meal, the one-sided rules' saves, the SUMMER OPEN and the encore won. Each is used once recorded.

Status: **Ready to test** once you've recorded them.

## PORT-89: TODAY'S TRIP (asked for 2026-10-24)

A row on ROAD TRIP's page: today's map (from the date), HEAT 0, Pepper, no GARAGE or story, so it's the same for everyone; the best result kept for the day, days won on the records.

Status: **Ready to test**.

## PORT-90: partner bonds (asked for 2026-10-24)

Every partner earns bond points with you (a win each, three for a title). Level 1: +1 to their stats; 2: their own item and a scene; 3: +2 and a line from the announcer at the big matches.

Status: **Ready to test**.

## PORT-91: the islands (asked for 2026-10-24)

A secret fourth leg past the SUMMER OPEN, open once a story is finished or HEAT 5 is won: THE ISLANDS, ending in THE ENCORE against Dale Dawson, with its own three-chapter story.

Status: **Ready to test** (to see it now: finish a story, or ask me for a save that has one).

## PORT-92: postcards (asked for 2026-10-24)

A postcard for every venue played and detour taken (38), on the SCRAPBOOK; 8, 16 and 24 earn new map pens.

Status: **Ready to test**.

## PORT-93: the map pen and NOW PLAYING (asked for 2026-10-24)

MAP PEN in the GARAGE colours the road driven; the cassette chosen shows on a NOW PLAYING card as the map opens.

Status: **Ready to test**.

## PORT-94: a ROAD TRIP balance pass (asked for 2026-10-24)

`tools/trip_gear_stats.gd` measures how far gear takes the stats: no runaway POWER (7 at the final on a new GARAGE), but sets were rarely finished, so one card in two is now a missing piece of a set you've started (0.2 sets a trip to 0.5).

Status: **Ready to test**: say how the sets feel.

## PORT-95: smart play (asked for 2026-10-25)

A remaster-only layer over the ROM's AI (port ADR-094), three knobs a CPU: KITCHEN (wait just behind the kitchen line once the rules allow), TOGETHER (a CPU pair level; your partner follows you up, and half way back), AIM (third-shot drops, dinks cross-court, the ball to whoever's back, drives down the middle). Profiles by difficulty and for your partner in `data/ai_smarts.json`; F2 > SMART PLAY tunes them live and saves them.

Status: **Ready to test**: play a doubles match at HARD, and press F2 > SMART PLAY to change any knob mid-match.

## PORT-96: more ROAD TRIP tests (asked for 2026-10-25)

`test_trip_fuzz`: 120 random trips checked after every step (hearts, cash, stats, the locker, save round trips, picks, always a way on, an end), 50 trips on one save (beats in order and once, the scrapbook and postcards only growing, the islands once open), every story map, the islands end to end, the day's trip the same for a full and a new save, bonds across finishes, a pre-round-two save played to its end, and the data's references. It found a bug, fixed: when 400 draws of a leg all broke the leg rules, the generator kept the last (1 leg in 7,000); generator 3 keeps drawing.

Status: Planned

## PORT-97: shirt patterns (asked for 2026-10-25)

Twelve shirt patterns (port ADR-095), generated on the player rig in `players.py` so they follow every pose: RUGBY, CHEST BAND, SASH, RAGLAN, RINGER, PINSTRIPE, POLKA DOTS, TIE-DYE, FLAMES, HAWAIIAN, CHEVRON, SPLIT, each a body sheet in a new design colour (two palette roles). Every ladder team wears one in its own colours, and so do Dale Dawson (FLAMES) and the ROAD HOGS (CHEVRON). A career player picks one on EDIT's PATTERN row: PLAIN and RINGER free, a team's pattern for beating them, and POLKA DOTS, CHEVRON and FLAMES from wins, aces and ladder clears (eleven unlocks after the ROM's sixteen; the mask widened, the save still v6). Player Select is unchanged.

Status: **Ready to test**: play the ladder and say which patterns or colours miss.

## PORT-98: every modifier on a trip, SHORT held (asked for 2026-10-26)

A grudge's twist draws from every modifier and rule (FAST BALL, GLOW, INVERSE, WIN BY 2, SIDE-OUT, MOMENTUM, SUDDEN DEATH and MULTI BALL added); the map's panel gives TODAY its own line. Holding SHORT slows a human to 7/8 top speed, remaster only (port ADR-096).

Status: **Ready to test**: hold SHORT and feel the drag; play a few grudges for the new twists.

## PORT-99: FROM THE GARAGE (asked for 2026-10-26)

A new trip opens on a FROM THE GARAGE card: the stats you start with, what the GARAGE adds (stats, hearts, cash, paddle), and in gold what's NEW since the last trip began (meta `garage_steps`, save still v6). None before the first step, none on TODAY'S TRIP (port ADR-097).

Status: **Ready to test**: start a trip once you have some MILES.
