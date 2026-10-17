"""Release notes from design/PORT_ROADMAP.md (PORT-09): each task's title,
status and what to try, for the build's ID. Writes game/RELEASE_NOTES.md.
    python3 game/tools/release_notes.py [build-id]
"""
import re
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
SHEET = KIT / "design/PORT_ROADMAP.md"
OUT = KIT / "game/RELEASE_NOTES.md"


def tasks(text):
    """(id, title, status, try) for each `PORT-NN` row of the sheet."""
    out = []
    for block in re.split(r"\n(?=### )", text):
        m = re.search(r"- \[(x| )\] `(PORT-\d\d)` (.+?)(?=\n  - )", block, re.S)
        if not m:
            continue
        title = " ".join(m.group(3).split())
        st = re.search(r"  - Status: (.+?)(?=\n\n|\n### |\n- \[|\Z)", block, re.S)
        status = " ".join(st.group(1).split()) if st else "Planned"
        head = re.match(r"### (?:\d+\. )?(?:`([^`]+)`: )?([^\n]+)", block)
        branch, name = (head.group(1) or "", head.group(2)) if head else ("", m.group(2))
        out.append((m.group(2), name, branch, m.group(1) == "x", title, status))
    return out


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else subprocess.run(
        ["git", "-C", str(KIT), "describe", "--always", "--dirty"],
        capture_output=True, text=True).stdout.strip()
    rows = tasks(SHEET.read_text())
    done = [r for r in rows if r[3]]
    lines = [f"# Pickleball '94 (Godot port) release notes", "",
             f"Build `{build}`. Generated from `design/PORT_ROADMAP.md` by",
             "`game/tools/release_notes.py`; edit the sheet, not this file.", "",
             f"{len(done)} of {len(rows)} roadmap tasks are in.", ""]
    for pid, name, branch, ok, title, status in rows:
        lines.append(f"## {pid}: {name}" + ("" if ok else " (not in this build)"))
        lines.append("")
        lines.append(title)
        lines.append("")
        lines.append(f"Status: {status}")
        lines.append("")
    OUT.write_text("\n".join(lines))
    print("wrote", OUT, f"({len(done)}/{len(rows)} tasks)")


if __name__ == "__main__":
    main()
