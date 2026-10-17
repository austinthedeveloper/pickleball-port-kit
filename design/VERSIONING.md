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
