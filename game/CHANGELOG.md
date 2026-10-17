# Changelog

Pickleball '94, the Godot port. Versions follow
[design/VERSIONING.md](../design/VERSIONING.md); the newest is first.
`game/RELEASE_NOTES.md` has the per-task detail from the roadmap.

## [Unreleased]

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
