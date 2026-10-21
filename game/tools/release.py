"""Cuts a release (design/VERSIONING.md, "Cutting a release"): checks,
branch feature/cld-release-X.Y.Z, version bump, release notes, tests,
the commit and the annotated tag vX.Y.Z; with --push, pushes and watches
the Release workflow until the GitHub release has its builds.
    python3 game/tools/release.py X.Y.Z [--dry-run] [--roadmap "summary"]
        [--message "tag summary"] [--push [BRANCH ...]]

The CHANGELOG entry is written by hand, for players: without one this
stops and prints a template from the roadmap's tasks since the last
release. The tree must be clean except game/CHANGELOG.md and
design/PORT_ROADMAP.md, which go into the release commit (untracked
files are ignored and never added).
"""
import argparse
import datetime
import json
import re
import subprocess
import sys
import textwrap
import time
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
CHANGELOG = "game/CHANGELOG.md"
ROADMAP = "design/PORT_ROADMAP.md"
NOTES = "game/RELEASE_NOTES.md"
VERSIONED = ["game/project.godot", "game/export_presets.cfg"]   # what version.py set writes
MAY_BE_DIRTY = {CHANGELOG, ROADMAP}
WORKFLOW = "release.yml"
TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"


class Stop(Exception):
    """A check failed: the message says why and what to do."""


def parse_args(argv):
    p = argparse.ArgumentParser(prog="release.py", description=__doc__.split("\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("version", help="X.Y.Z")
    p.add_argument("--dry-run", action="store_true", help="print each step without doing it")
    p.add_argument("--roadmap", metavar="SUMMARY",
                   help="add the `- **vX.Y.Z**` line under ## Releases with this summary")
    p.add_argument("--message", metavar="SUMMARY",
                   help="the tag's summary (default: the CHANGELOG entry's first paragraph)")
    p.add_argument("--push", nargs="*", metavar="BRANCH",
                   help="push these branches and the release branch, then the tag, and watch CI")
    a = p.parse_args(argv)
    if not re.fullmatch(r"\d+\.\d+\.\d+", a.version):
        p.error(f"not a version: {a.version} (want X.Y.Z)")
    if a.roadmap is not None and not a.roadmap.strip():
        p.error("--roadmap needs a summary")
    return a


# The checks, on file text (test_release.py runs them on copies).

def changelog_entry(text, v):
    """The `## [v] - YYYY-MM-DD` entry: (date, body), or None."""
    m = re.search(rf"^## \[{re.escape(v)}\] - (\d{{4}}-\d\d-\d\d)[ \t]*\n(.*?)(?=^## \[|\Z)",
                  text, re.M | re.S)
    return (m.group(1), m.group(2).strip()) if m else None


def first_paragraph(body):
    para = body.split("\n\n")[0] if body else ""
    return " ".join(para.split()).rstrip(".")


def releases_section(text):
    """(start, end) of the text under `## Releases`, up to the next `## `."""
    m = re.search(r"^## Releases[ \t]*\n", text, re.M)
    if not m:
        raise Stop(f"{ROADMAP} has no `## Releases` section")
    nxt = re.search(r"^## ", text[m.end():], re.M)
    return m.end(), m.end() + nxt.start() if nxt else len(text)


def roadmap_has(text, v):
    start, end = releases_section(text)
    return re.search(rf"^- \*\*v{re.escape(v)}\*\*", text[start:end], re.M) is not None


def roadmap_stub(v, summary, date):
    line = (f"- **v{v}** ({date}): {summary.strip().rstrip('.')} (tag `v{v}`, on "
            f"`feature/cld-release-{v}`).")
    return textwrap.fill(line, 74, subsequent_indent="  ", break_on_hyphens=False,
                         break_long_words=False)


def add_roadmap_stub(text, v, summary, date):
    """The sheet with the stub after the last line of ## Releases."""
    start, end = releases_section(text)
    body = text[start:end].rstrip("\n")
    return text[:start] + body + "\n" + roadmap_stub(v, summary, date) + "\n\n" + text[end:]


def released_tasks(text):
    """The PORT numbers any ## Releases line names (a range counts by its ends)."""
    start, end = releases_section(text)
    return {int(n) for n in re.findall(r"PORT-(\d+)", text[start:end])}


def index_tasks(text):
    """(number, what) for each row of the sheet's ## Index table."""
    m = re.search(r"^## Index[ \t]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    rows = re.findall(r"^\| PORT-(\d+) \| ([^|]+?) \|", m.group(1), re.M) if m else []
    return [(int(n), what) for n, what in rows]


def new_tasks(text):
    """The roadmap tasks since the last release: numbered after every task
    a release line names."""
    done = released_tasks(text)
    last = max(done) if done else -1
    return [(n, what) for n, what in index_tasks(text) if n > last]


def changelog_template(v, roadmap_text, date):
    tasks = new_tasks(roadmap_text)
    items = "\n".join(f"- **PORT-{n:02d} {what}**: what a player sees." for n, what in tasks) \
        or "- **...**: what a player sees."
    return (f"## [{v}] - {date}\n\n"
            f"One line: what this release is, for players.\n\n"
            f"### Added\n{items}\n\n"
            f"### Changed\n- ...\n\n"
            f"### Fixed\n- ...\n")


# Git, gh and the steps.

class Releaser:
    def __init__(self, args, root=KIT, out=print):
        self.a, self.root, self.out = args, Path(root), out
        self.v = args.version
        self.tag = f"v{self.v}"
        self.branch = f"feature/cld-release-{self.v}"
        self.today = datetime.date.today().isoformat()

    def git(self, *cmd, strip=True):
        r = subprocess.run(["git", "-C", str(self.root), *cmd], capture_output=True, text=True)
        if r.returncode:
            raise Stop(f"git {' '.join(cmd)} failed:\n{r.stderr.strip()}")
        return r.stdout.strip() if strip else r.stdout

    def has_remote(self):
        return "origin" in self.git("remote").split()

    def read(self, rel):
        return (self.root / rel).read_text()

    def step(self, what, cmd=None, fn=None):
        """Prints a step; does it unless --dry-run. cmd runs in the kit's
        root with its output shown; fn is called."""
        self.out(("[dry run] " if self.a.dry_run else "==> ") + what)
        if self.a.dry_run:
            return
        if cmd:
            r = subprocess.run(cmd, cwd=self.root)
            if r.returncode:
                raise Stop(f"`{' '.join(cmd)}` failed (exit {r.returncode}). Nothing is "
                           f"committed; you're on {self.branch} with the changes uncommitted.")
        if fn:
            fn()

    # 1, 4, 5: everything that can stop the release, before anything changes.
    def checks(self):
        problems = []
        dirty = [line[3:] for line in self.git("status", "--porcelain", "--untracked-files=no",
                                                  strip=False).splitlines()]
        dirty = [p for p in dirty if p not in MAY_BE_DIRTY]
        if dirty:
            problems.append("the tree has uncommitted changes (commit or set them aside):\n  "
                            + "\n  ".join(dirty))
        if self.git("tag", "--list", self.tag):
            problems.append(f"tag {self.tag} already exists here")
        if self.has_remote():
            r = subprocess.run(["git", "-C", str(self.root), "ls-remote", "--tags", "origin",
                                f"refs/tags/{self.tag}"], capture_output=True, text=True)
            if r.returncode:
                problems.append(f"can't reach origin to check for {self.tag}:\n{r.stderr.strip()}")
            elif r.stdout.strip():
                problems.append(f"tag {self.tag} already exists on origin")
        if self.git("branch", "--list", self.branch):
            problems.append(f"branch {self.branch} already exists")

        roadmap = self.read(ROADMAP)
        entry = changelog_entry(self.read(CHANGELOG), self.v)
        if not entry:
            problems.append(f"{CHANGELOG} has no `## [{self.v}] - <date>` entry. Write it "
                            f"for players, at the top; a start, from the roadmap tasks since "
                            f"the last release:\n\n"
                            + changelog_template(self.v, roadmap, self.today))
        self.entry = entry
        self.add_stub = False
        if not roadmap_has(roadmap, self.v):
            if self.a.roadmap:
                self.add_stub = True
            else:
                problems.append(f"{ROADMAP} has no `- **{self.tag}**` line under ## Releases. "
                                f"Add one, or pass --roadmap \"summary\" for:\n\n"
                                + roadmap_stub(self.v, "SUMMARY", self.today))
        return problems

    def run(self):
        problems = self.checks()
        for p in problems:
            self.out(("[dry run] would stop: " if self.a.dry_run else "stop: ") + p + "\n")
        if problems and not self.a.dry_run:
            return 1
        summary = self.a.message or (first_paragraph(self.entry[1]) if self.entry else "SUMMARY")
        files = VERSIONED + [CHANGELOG, NOTES, ROADMAP]

        self.step(f"git switch -c {self.branch}  (from {self.git('rev-parse', '--short', 'HEAD')})",
                  ["git", "switch", "-c", self.branch])
        self.step(f"python3 game/tools/version.py set {self.v}",
                  [sys.executable, "game/tools/version.py", "set", self.v])
        if self.add_stub:
            self.step(f"add to {ROADMAP} ## Releases:\n"
                      + textwrap.indent(roadmap_stub(self.v, self.a.roadmap, self.today), "    "),
                      fn=lambda: (self.root / ROADMAP).write_text(
                          add_roadmap_stub(self.read(ROADMAP), self.v, self.a.roadmap, self.today)))
        self.step(f"python3 game/tools/release_notes.py {self.tag}",
                  [sys.executable, "game/tools/release_notes.py", self.tag])
        self.step("game/tools/test.sh", ["game/tools/test.sh"])
        msg = f"Release {self.v}: version bump and release notes\n\n{TRAILER}\n"
        self.step(f"git add {' '.join(files)}", ["git", "add", "--", *files])
        self.step(f'git commit -m "Release {self.v}: version bump and release notes" (+ trailer)',
                  ["git", "commit", "-m", msg, "--", *files])
        tag_msg = f"Pickleball '94 {self.v}: {summary}"
        self.step(f'git tag -a {self.tag} -m "{tag_msg}"',
                  ["git", "tag", "-a", self.tag, "-m", tag_msg])

        if self.a.push is None:
            if self.a.dry_run:
                self.out("\nDry run: nothing was changed.")
                return 0
            self.out(f"\nDone: {self.tag} on {self.branch}, not pushed. To publish:\n"
                     f"  git push -u origin {self.branch} && git push origin {self.tag}")
            return 0
        branches = [b for b in self.a.push if b != self.branch] + [self.branch]
        for b in branches:
            self.step(f"git push -u origin {b}", ["git", "push", "-u", "origin", b])
        self.step(f"git push origin {self.tag}", ["git", "push", "origin", self.tag])
        self.step(f"watch the {WORKFLOW} run for {self.tag} (gh run list / gh run view)",
                  fn=self.watch)
        self.step(f"print the release's assets; check gh release view says {self.tag} is latest",
                  fn=self.check_release)
        if self.a.dry_run:
            self.out("\nDry run: nothing was changed.")
        return 0

    def gh(self, *cmd):
        r = subprocess.run(["gh", *cmd], cwd=self.root, capture_output=True, text=True)
        if r.returncode:
            raise Stop(f"gh {' '.join(cmd)} failed:\n{r.stderr.strip()}")
        return json.loads(r.stdout) if r.stdout.strip() else None

    def watch(self, poll=30, appear=300):
        sha = self.git("rev-parse", f"{self.tag}^{{commit}}")
        run, waited = None, 0
        while run is None:
            runs = self.gh("run", "list", "--workflow", WORKFLOW, "--limit", "20", "--json",
                           "databaseId,headBranch,headSha,event,url")
            run = next((r for r in runs if r["headBranch"] == self.tag and r["headSha"] == sha),
                       None)
            if run is None:
                if waited >= appear:
                    raise Stop(f"no {WORKFLOW} run for {self.tag} after {appear}s (Actions tab?)")
                time.sleep(10)
                waited += 10
        self.out(f"    run {run['databaseId']}: {run['url']}")
        last = None
        while True:
            r = self.gh("run", "view", str(run["databaseId"]), "--json", "status,conclusion")
            if r["status"] != last:
                self.out(f"    {r['status']}")
                last = r["status"]
            if r["status"] == "completed":
                break
            time.sleep(poll)
        if r["conclusion"] != "success":
            raise Stop(f"the {WORKFLOW} run ended {r['conclusion']}: {run['url']}")

    def check_release(self):
        rel = self.gh("release", "view", self.tag, "--json", "url,assets")
        self.out(f"    {rel['url']}")
        for asset in rel["assets"]:
            self.out(f"    {asset['name']}  ({asset['size']:,} bytes)")
        latest = self.gh("release", "view", "--json", "tagName")["tagName"]
        if latest != self.tag:
            raise Stop(f"gh release view says the latest release is {latest}, not {self.tag}")
        self.out(f"    {self.tag} is the latest release")


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        return Releaser(args).run()
    except Stop as e:
        print(f"stop: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
