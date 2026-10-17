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
5. Tag that commit with an annotated tag, `git tag -a vX.Y.Z`. Push the
   branch and the tag.
6. `game/tools/export.sh` on the tagged, clean tree: the build ID is then
   exactly `vX.Y.Z`, and the title shows `V X.Y.Z` alone. Without export
   templates, `--check` still verifies the pack.
7. Publish a GitHub release for the tag, with the CHANGELOG entry and any
   builds.

Between releases the title shows the version and the build
(`V0.1.0  DEV V0.1.0-3-GABC1234`), so a screenshot always says where it
came from.
