"""The GitHub release text for a version: its game/CHANGELOG.md entry
(without the heading) and the downloads list. The release workflow uses
it when it creates the release for a tag.
    python3 game/tools/release_body.py 0.2.1
"""
import re
import sys
from pathlib import Path

CHANGELOG = Path(__file__).resolve().parents[1] / "CHANGELOG.md"

DOWNLOADS = """### Downloads
- **macOS** (universal, Apple Silicon and Intel): `Pickleball94-{v}-macos.zip`. It's ad-hoc signed, not notarized, so the first time, right-click the app and choose **Open**.
- **Windows** (64-bit): `Pickleball94-{v}-windows.zip`.
- **Linux** (x86_64): `Pickleball94-{v}-linux.tar.gz`. Mark it executable if needed (`chmod +x`).
- **Web**: `Pickleball94-{v}-web.zip`. It must be served over HTTP (e.g. `python3 -m http.server` in the unzipped folder); it won't run opened as a file.
"""


def entry(v, text):
    """The body of `## [v] - date`, up to the next `## [`; None if absent."""
    m = re.search(rf"^## \[{re.escape(v)}\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.M | re.S)
    return m.group(1).strip() if m else None


def unwrap(md):
    """Joins hard-wrapped lines: GitHub shows a release's newlines as line
    breaks. Headings, list items and blank lines start a new line."""
    out = []
    for line in md.split("\n"):
        starts = not line.strip() or re.match(r"\s*(#|- |\* |\d+\. )", line)
        if out and out[-1].strip() and not out[-1].lstrip().startswith("#") and not starts:
            out[-1] += " " + line.strip()
        else:
            out.append(line)
    return "\n".join(out)


if __name__ == "__main__":
    if len(sys.argv) != 2 or not re.fullmatch(r"\d+\.\d+\.\d+", sys.argv[1]):
        sys.exit(__doc__)
    v = sys.argv[1]
    body = entry(v, CHANGELOG.read_text())
    if not body:
        sys.exit(f"no ## [{v}] entry in {CHANGELOG}")
    print(unwrap(body) + "\n\n" + DOWNLOADS.format(v=v))
