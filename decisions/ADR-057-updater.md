# ADR-057 — The In-Game Updater

Status: **Accepted 2026-10-18**
Milestone: `PORT-32` (Godot port only). Depends on: ADR-052 (the port),
design/VERSIONING.md (releases).

## What

OPTIONS > **UPDATES**: the game checks GitHub for the latest release when
it starts, and when there's a newer one says so on the title (the line
under the logo). Pressing UPDATES downloads it (about 23 MB, not the 60-80
MB full builds), checks it, and RESTART starts the game on it. You chose
this over itch.io's app for now (2026-10-18).

- **What an update is:** a release's `.pck` (the whole game: scripts,
  art, sound). The app around it is Godot's engine, which only changes
  with Godot's version. CI publishes `Pickleball94-X.Y.Z.pck` and
  `Pickleball94-X.Y.Z.json` (the version, the engine it needs, its size and
  SHA-256; `game/tools/update_manifest.py`) with each release.
- **The check** (`meta/updater.gd`, a node the boot scene adds): GitHub's
  latest-release API; if newer, its manifest. A release that needs another
  engine says "X IS OUT" and UPDATES opens the releases page instead
  (FULL). A release without the updater's files (before 0.9.0) is the same.
- **The download** goes to `user://updates/`, is checked against the
  manifest's SHA-256 (a damaged one is deleted: TRY AGAIN), renamed to
  `Pickleball94-X.Y.Z.pck`, and recorded in `current.json`. Older packs are
  removed.
- **Starting on it** (`scenes/boot.gd`, now the main scene): before
  anything else loads, boot reads `current.json`; if the update is newer
  than this build and for this engine, it loads the pack over the
  built-in one (`ProjectSettings.load_resource_pack`, replacing files),
  sets the version to the update's, then adds the input map's node and
  the updater (they were autoloads, and an autoload would stay the old
  version) and opens the title. RESTART starts the game again and quits.
- **Safety:** boot marks the update `booting`; the title clears it. If an
  update's start never reaches the title, the next start skips it and
  runs the built-in game. A newer full download always wins over an older
  update.
- Only exported desktop builds check (a checkout says DEV BUILD; the Web
  build is always the newest: WEB). Nothing is sent but the requests.

## Amendment: at launch, not in OPTIONS (PORT-34, 2026-10-18)

Played on 0.9.0 to 0.9.1 on macOS and Windows: it worked, but the steps
weren't obvious (OPTIONS showed 98% after the download was done). You
asked for the update to come up when the game opens, with no skipping.

`view/update_screen.gd` is now the first screen of an exported desktop
game: CHECKING FOR A NEW VERSION, then (if there's one) VERSION X IS OUT,
DOWNLOADING with a bar and the MB, then INSTALLED, RESTARTING. There's no
way past a download. It goes on to the title when it's up to date, when
there's no answer in 8 s or no network, and offers PLAY THIS VERSION only
when updating in-game can't work: a failed download (with RETRY) or a
release that needs a full download (with GET THE FULL DOWNLOAD). If the
restart doesn't start, it asks you to close and open the game (the update
is installed). OPTIONS > UPDATES stays for a check by hand, and now
refreshes when its state changes.

## Why not `--main-pack`

The first design relaunched the game with `--main-pack <update>`. Release
builds of Godot refuse it ("compiled without support for path
overrides"), found by trying it on an exported macOS build. Loading the
pack from a boot scene works on the same build, including classes that
exist only in the update (checked with a probe class) and the version.

## Limits

- **The repository must be public.** The game asks GitHub's API without
  signing in; a private repository's releases answer "Not Found". Found
  on the 0.9.0 release; the repository was made public that day (with
  your OK, after a scan of its history for secrets).

- `boot.gd` is the one file an update can't change: keep it small and
  never load a game script in it before the pack.
- An update can't change `project.godot` settings (the window, rendering,
  input defaults there), only the version, which boot sets. The input map
  is built in code, so it updates. A release that changes such a setting,
  or Godot's version, needs a full download: VERSIONING.md says how.
- The first build with the updater (0.9.0) has to be downloaded by hand.

## Verified

`tests/test_updater.gd` (versions, the release JSON, boot's choice and its
safety, each state's words, the title's notice, the manifest), and by
hand on this Mac: an exported 0.8.1 app with a 0.9.9 pack in
`user://updates/` started 0.9.9 (a probe class only in the update ran,
the version read 0.9.9, the title cleared `booting`); a damaged pack fell
back to the built-in game and was skipped after. Not tried: a download
from a real release (none has the files until 0.9.0), Windows and Linux.
