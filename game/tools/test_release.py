"""Self-test for release.py: its arguments, the CHANGELOG and roadmap
checks, and whole runs in a throwaway git repository (a copy of the files
it touches, with a bare repository as its origin). Never touches this
repository's tags or remote.
    python3 game/tools/test_release.py
"""
import contextlib
import io
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release  # noqa: E402

KIT = release.KIT
COPIED = ["game/CHANGELOG.md", "design/PORT_ROADMAP.md", "design/PORT_HISTORY.md",
          "game/project.godot", "game/export_presets.cfg", "game/RELEASE_NOTES.md",
          "game/tools/version.py", "game/tools/release_notes.py"]


def git(root, *cmd):
    return subprocess.run(["git", "-C", str(root), *cmd], capture_output=True, text=True,
                          check=True).stdout.strip()


class Args(unittest.TestCase):
    def parse(self, *argv):
        with contextlib.redirect_stderr(io.StringIO()):
            return release.parse_args(list(argv))

    def test_version_and_flags(self):
        a = self.parse("1.2.3", "--dry-run", "--roadmap", "fixes", "--push", "main", "feature/cld-x")
        self.assertEqual((a.version, a.dry_run, a.roadmap, a.push),
                         ("1.2.3", True, "fixes", ["main", "feature/cld-x"]))
        self.assertIsNone(self.parse("1.2.3").push)
        self.assertEqual(self.parse("1.2.3", "--push").push, [])

    def test_bad_arguments(self):
        for argv in (["1.2"], ["v1.2.3"], ["1.2.3.4"], ["x"], [], ["1.2.3", "--roadmap", " "]):
            with self.assertRaises(SystemExit, msg=argv):
                self.parse(*argv)


class Files(unittest.TestCase):
    """The checks on temporary copies of the real CHANGELOG and roadmap."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.changelog = self.dir / "CHANGELOG.md"
        self.roadmap = self.dir / "PORT_ROADMAP.md"
        shutil.copy(KIT / release.CHANGELOG, self.changelog)
        shutil.copy(KIT / release.ROADMAP, self.roadmap)

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_changelog_entry(self):
        text = self.changelog.read_text()
        self.assertIsNone(release.changelog_entry(text, "9.9.9"))
        text = text.replace("## [", "## [9.9.9] - 2026-12-01\n\nA test.\n\n### Fixed\n- x\n\n## [", 1)
        self.changelog.write_text(text)
        date, body = release.changelog_entry(self.changelog.read_text(), "9.9.9")
        self.assertEqual(date, "2026-12-01")
        self.assertTrue(body.startswith("A test.") and body.endswith("- x"))
        self.assertEqual(release.first_paragraph(body), "A test")
        # A heading without a date, or another version's, doesn't count.
        self.assertIsNone(release.changelog_entry("## [9.9.9]\n\nx\n", "9.9.9"))
        self.assertIsNone(release.changelog_entry("## [9.9.90] - 2026-01-01\n", "9.9.9"))

    def test_roadmap_line_and_stub(self):
        text = self.roadmap.read_text()
        self.assertFalse(release.roadmap_has(text, "9.9.9"))
        self.assertTrue(release.roadmap_has(text, "0.1.0"))
        out = release.add_roadmap_stub(text, "9.9.9", "the long summary of a test release.",
                                       "2026-12-01")
        self.roadmap.write_text(out)
        out = self.roadmap.read_text()
        self.assertTrue(release.roadmap_has(out, "9.9.9"))
        start, end = release.releases_section(out)
        section = out[start:end]
        self.assertTrue(section.rstrip().endswith("on\n  `feature/cld-release-9.9.9`).")
                        or section.rstrip().endswith("`feature/cld-release-9.9.9`)."))
        self.assertIn("- **v9.9.9** (2026-12-01): the long summary of a test release (tag", out)
        self.assertTrue(all(len(line) <= 74 for line in release.roadmap_stub(
            "9.9.9", "the long summary of a test release", "2026-12-01").split("\n")))
        # Only the section changed, and the next heading keeps its blank line.
        self.assertEqual(out.replace(release.roadmap_stub(
            "9.9.9", "the long summary of a test release", "2026-12-01") + "\n", ""), text)
        # A version mentioned outside ## Releases doesn't count.
        self.assertFalse(release.roadmap_has("## Releases\n\n## Next\n- **v9.9.9**\n", "9.9.9"))
        with self.assertRaises(release.Stop):
            release.roadmap_has("# no releases\n", "9.9.9")

    def test_template_lists_tasks_since_the_last_release(self):
        text = ("## Index\n\n| Task | What | Branch | Status |\n|---|---|---|---|\n"
                "| PORT-00 | First | | Done |\n| PORT-07 | Seven | `b` | Done |\n"
                "| PORT-08 | Eight | `b` | Done |\n| PORT-12 | Twelve | `b` | Done |\n\n"
                "## Releases\n\n- **v0.1.0** (d): PORT-00 to PORT-07 (tag).\n\n## Later\n")
        self.assertEqual(release.new_tasks(text), [(8, "Eight"), (12, "Twelve")])
        t = release.changelog_template("0.2.0", text, "2026-12-01")
        self.assertTrue(t.startswith("## [0.2.0] - 2026-12-01\n"))
        self.assertIn("- **PORT-08 Eight**", t)
        self.assertNotIn("Seven", t)
        # The template is itself an entry the check accepts.
        self.assertIsNotNone(release.changelog_entry(t, "0.2.0"))
        # The real sheet gives at least the shape.
        release.new_tasks(self.roadmap.read_text())


class Runs(unittest.TestCase):
    """release.py end to end in a throwaway repository with a bare origin."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.root, self.origin = self.dir / "kit", self.dir / "origin.git"
        for rel in COPIED:
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(KIT / rel, self.root / rel)
        self.set_tests(0)
        subprocess.run(["git", "init", "-q", "--bare", str(self.origin)], check=True)
        git(self.root.parent, "init", "-q", str(self.root))
        git(self.root, "config", "user.email", "test@example.com")
        git(self.root, "config", "user.name", "Test")
        git(self.root, "config", "commit.gpgsign", "false")
        git(self.root, "config", "tag.gpgsign", "false")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-q", "-m", "start")
        git(self.root, "remote", "add", "origin", str(self.origin))
        (self.root / "scratch.txt").write_text("untracked, never added\n")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def set_tests(self, status):
        test = self.root / "game/tools/test.sh"
        test.write_text(f"#!/bin/sh\nexit {status}\n")
        test.chmod(0o755)

    def write_entry(self, v="9.9.9"):
        p = self.root / release.CHANGELOG
        p.write_text(p.read_text().replace(
            "## [", f"## [{v}] - 2026-12-01\n\nA test release.\n\n### Fixed\n- x\n\n## [", 1))

    def run_release(self, *argv):
        lines = []
        r = release.Releaser(release.parse_args(list(argv)), root=self.root, out=lines.append)
        try:
            status = r.run()
        except release.Stop as e:
            lines.append(f"stop: {e}")
            status = 1
        return status, "\n".join(lines)

    def test_dry_run_changes_nothing(self):
        head = git(self.root, "rev-parse", "HEAD")
        status, out = self.run_release("9.9.9", "--dry-run", "--push", "main")
        self.assertEqual(status, 0)
        self.assertIn("would stop: game/CHANGELOG.md has no `## [9.9.9]", out)
        self.assertIn("[dry run] git tag -a v9.9.9", out)
        self.assertIn("[dry run] git push origin v9.9.9", out)
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), head)
        self.assertEqual(git(self.root, "status", "--porcelain", "--untracked-files=no"), "")
        self.assertEqual(git(self.root, "tag"), "")

    def test_missing_entries_stop_before_any_change(self):
        status, out = self.run_release("9.9.9")
        self.assertEqual(status, 1)
        self.assertIn("## [9.9.9] - ", out)            # the template
        self.assertIn("--roadmap", out)
        self.assertEqual(git(self.root, "branch", "--list", "feature/cld-release-9.9.9"), "")

    def test_dirty_tree_and_existing_tags(self):
        self.write_entry()
        (self.root / "game/project.godot").write_text("dirty\n")
        status, out = self.run_release("9.9.9", "--roadmap", "a test")
        self.assertEqual(status, 1)
        self.assertIn("uncommitted changes", out)
        self.assertIn("game/project.godot", out)
        git(self.root, "checkout", "--", "game/project.godot")
        git(self.root, "tag", "v9.9.9")
        status, out = self.run_release("9.9.9", "--roadmap", "a test")
        self.assertIn("tag v9.9.9 already exists here", out)
        git(self.root, "push", "-q", "origin", "v9.9.9")
        git(self.root, "tag", "-d", "v9.9.9")
        status, out = self.run_release("9.9.9", "--roadmap", "a test")
        self.assertEqual(status, 1)
        self.assertIn("tag v9.9.9 already exists on origin", out)
        self.assertNotIn("already exists here", out)

    def test_failing_tests_commit_nothing(self):
        self.write_entry()
        self.set_tests(1)
        git(self.root, "commit", "-q", "-am", "failing tests")
        head = git(self.root, "rev-parse", "HEAD")
        status, out = self.run_release("9.9.9", "--roadmap", "a test")
        self.assertEqual(status, 1)
        self.assertIn("game/tools/test.sh` failed", out)
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), head)
        self.assertEqual(git(self.root, "tag"), "")

    def test_a_release(self):
        self.write_entry()     # uncommitted: it rides in the release commit
        status, out = self.run_release("9.9.9", "--roadmap", "a test")
        self.assertEqual(status, 0, out)
        self.assertEqual(git(self.root, "branch", "--show-current"), "feature/cld-release-9.9.9")
        self.assertEqual(git(self.root, "log", "-1", "--format=%B"),
                         "Release 9.9.9: version bump and release notes\n\n" + release.TRAILER)
        changed = set(git(self.root, "show", "--name-only", "--format=", "HEAD").split())
        self.assertEqual(changed, {"game/project.godot", "game/export_presets.cfg",
                                   "game/CHANGELOG.md", "game/RELEASE_NOTES.md",
                                   "design/PORT_ROADMAP.md"})
        self.assertIn('config/version="9.9.9"', (self.root / "game/project.godot").read_text())
        self.assertIn("Build `v9.9.9`", (self.root / "game/RELEASE_NOTES.md").read_text())
        self.assertEqual(git(self.root, "cat-file", "-t", "v9.9.9"), "tag")
        self.assertEqual(git(self.root, "tag", "-n1", "v9.9.9").split(None, 1)[1],
                         "Pickleball '94 9.9.9: A test release")
        self.assertEqual(git(self.root, "rev-parse", "v9.9.9^{commit}"),
                         git(self.root, "rev-parse", "HEAD"))
        self.assertIn("scratch.txt", git(self.root, "status", "--porcelain"))   # never added
        self.assertEqual(git(self.root, "ls-remote", "origin"), "")              # not pushed


if __name__ == "__main__":
    unittest.main()
