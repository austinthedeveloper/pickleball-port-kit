# Pickleball '94 (Godot port) release notes

Build `v0.13.0`. Generated from `design/PORT_ROADMAP.md` by
`game/tools/release_notes.py`; edit the sheet, not this file.

36 of 37 roadmap tasks are in.

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

## PORT-35: Catch the sim up to the ROM (planned)

The sim is the ROM's at TUNING_VERSION 4 (port ADR-059; with PORT-41's slice). The SNES repo's conformance traces come in by `tools/conformance_import.sh` and `test_conformance` replays all four scenarios frame by frame: every frame matches. On the way: the ROM's `opponents.json` and `quips.json` (the rebalance, serve power and duds, sixteen quips and the deck), the serve's depth, aim and power, the lane covers' stagger per match, KID's top speed, ICE and POPCORN in the sim and the AI, GHOST in the view, the kitchen line, and a ladder per mode (save v6, a quit resets it). GHOST BALL, POPCORN, ICE are on MODIFIERS.

Status: **Done**: the conformance traces are the proof. The upper rungs are easier than before (the ROM's playtest); say if they feel off.

## PORT-36: 36-40 (planned) (not in this build)

About this project, and Tiny Chair: the bible's ground rule 1 note, and a Tiny Chair splash in the A-11 colours after a name search.

Status: **In progress**: the splash waits on the name search and the logo's final art (bible A-11); the releases already published don't carry the line (For you).

## PORT-41: four swings and the short hold (asked for 2026-10-18)

The first piece of PORT-35 (ADR-058): SNES ADR-056 and 057. SLICE (slow, never deep, steady), SHORT held (any swing goes short, the D-pad still moves), the fast drop's long spray off a stretch, and CPUs that slice (WALT, RAVEN, VLAD 3; ACE, JADE 4). Pad by position: SLICE north, SHORT LB or RB; keyboard I and Shift/U; both on CONTROLS. The overhead moved to shot 4 so the slice has the C's number; its own sound; the key legend and the SHOTS lesson teach all four.

Status: **Ready to test**: try I / Y for the slice and hold Shift / LB with each swing.
