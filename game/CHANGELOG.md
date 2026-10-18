# Changelog

Pickleball '94, the Godot port. Versions follow
[design/VERSIONING.md](../design/VERSIONING.md); the newest is first.
`game/RELEASE_NOTES.md` has the per-task detail from the roadmap.

## [Unreleased]

### Fixed
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
