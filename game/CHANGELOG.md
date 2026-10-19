# Changelog

Pickleball '94, the Godot port. Versions follow
[design/VERSIONING.md](../design/VERSIONING.md); the newest is first.
`game/RELEASE_NOTES.md` has the per-task detail from the roadmap.

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
