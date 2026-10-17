# Pickleball '94 (Godot port) release notes

Build `v0.3.0`. Generated from `design/PORT_ROADMAP.md` by
`game/tools/release_notes.py`; edit the sheet, not this file.

18 of 18 roadmap tasks are in.

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
