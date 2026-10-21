# Versioning (the Godot port)

Started with **0.1.0** on 2026-10-17.

## The number

[Semantic versioning](https://semver.org), `MAJOR.MINOR.PATCH`:

- **MINOR** for a release with new features (a roadmap batch, such as
  multiplayer).
- **PATCH** for fixes only, with no new features and no save change.
- **MAJOR** stays 0 until the port is called finished (1.0.0). Until
  then a minor release may change things, but a save must always
  migrate (`meta/save.gd`).

One number, in `game/project.godot` (`application/config/version`) and
every export preset. Change it only with the tool, which keeps them in
step (`test_release.gd` checks):

```sh
python3 game/tools/version.py set 0.2.0
```

## Cutting a release

`game/tools/release.py` does steps 1 to 6 below:

```sh
python3 game/tools/release.py X.Y.Z --dry-run    # the plan, and what would stop it
python3 game/tools/release.py X.Y.Z              # up to the tag, nothing pushed
python3 game/tools/release.py X.Y.Z --push feature/cld-a feature/cld-b
```

Before it changes anything it checks, and stops on any failure:

- the tree is clean, except `game/CHANGELOG.md` and
  `design/PORT_ROADMAP.md`, which go into the release commit (untracked
  files are ignored and never added);
- tag `vX.Y.Z` exists neither here nor on `origin`, nor the release branch;
- `game/CHANGELOG.md` has the `## [X.Y.Z] - YYYY-MM-DD` entry. You write
  it, for players; without one it prints a template listing the roadmap
  tasks numbered after every task a `## Releases` line names;
- `design/PORT_ROADMAP.md` has a `- **vX.Y.Z**` line under `## Releases`,
  or `--roadmap "summary"` adds the usual one-line stub.

Then it branches `feature/cld-release-X.Y.Z` from HEAD, runs
`version.py set`, `release_notes.py vX.Y.Z` and `game/tools/test.sh`
(a failure stops it with nothing committed), commits exactly the version,
CHANGELOG, release-notes and roadmap files, and tags `vX.Y.Z` (annotated,
"Pickleball '94 X.Y.Z: " plus the CHANGELOG entry's first paragraph, or
`--message`). `--push BRANCH...` pushes those branches and the release
branch, then the tag, follows the Release workflow's run for the tag
(`gh run list`/`gh run view`) to the end, prints the release's assets and
checks `gh release view` names it the latest. `game/tools/test_release.py`
tests it in a throwaway repository.

By hand:

1. Branch `feature/cld-release-X.Y.Z` from the tip of the work going in.
2. `python3 game/tools/version.py set X.Y.Z`.
3. Add the `## [X.Y.Z] - date` entry at the top of `game/CHANGELOG.md`.
   This is what changed, for players. Then regenerate
   `game/RELEASE_NOTES.md` (`python3 game/tools/release_notes.py vX.Y.Z`).
4. `game/tools/test.sh` passes. Commit as "Release X.Y.Z: version bump
   and release notes".
5. Tag that commit with an annotated tag, `git tag -a vX.Y.Z`.
6. Push the branch, then the tag (`git push origin vX.Y.Z`). CI builds
   and publishes: the Release workflow (`.github/workflows/release.yml`)
   runs the tests, checks the tag matches `version.py get`, runs
   `game/tools/export.sh` on the clean tagged tree (so the build ID is
   exactly `vX.Y.Z` and the title shows `V X.Y.Z` alone), packages
   `Pickleball94-X.Y.Z-{macos.zip,windows.zip,linux.tar.gz,web.zip}`, and
   attaches them to the GitHub release for the tag.
7. The release is created from the CHANGELOG entry plus a downloads list
   (`python3 game/tools/release_body.py X.Y.Z` prints it). If a release
   for the tag already exists, its text is kept and the builds are added
   (same-named files replaced), so a release drafted by hand first is
   fine. To rebuild a release, re-run the workflow from the Actions tab.

Builds by hand still work: `game/tools/export.sh` with Godot's export
templates installed (without them, `--check` verifies the pack).

## Updates in the game (ADR-057)

From 0.9.0 each release also carries `Pickleball94-X.Y.Z.pck` and its
`.json` manifest, which OPTIONS > UPDATES downloads. An update is only the
game's pack, so a release whose players need a **full download** instead
is one that:

- changes Godot's version (the manifest's `engine` differs, and the game
  sends players to the releases page by itself), or
- changes a `project.godot` setting other than the version (the window,
  rendering, a new autoload): the pack can't change those. Say so in the
  CHANGELOG entry ("download this one in full").

The game reads releases without signing in, so the repository must stay
public (`config/update_repo` in project.godot names it).

`game/scenes/boot.gd` is the one file an update can't replace: change it
only in a release that asks for a full download.

## CI

`.github/workflows/ci.yml` runs `game/tools/test.sh` (every suite and the
e2e smoke, failing on any SCRIPT ERROR) on Linux, headless, for every
branch push and pull request. Godot comes from the official release,
pinned with its SHA-512 in `.github/actions/setup-godot/action.yml`; a
new Godot version changes the version and both hashes there (from the
release's `SHA512-SUMS.txt`) along with `project.godot`.

Between releases the title shows the version and the build
(`V0.1.0  DEV V0.1.0-3-GABC1234`), so a screenshot always says where it
came from.
