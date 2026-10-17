"""The game's version (design/VERSIONING.md): one number, kept in
project.godot (application/config/version) and copied into every export
preset. `get` prints it; `set X.Y.Z` writes it everywhere.
    python3 game/tools/version.py get
    python3 game/tools/version.py set 0.2.0
"""
import re
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
PROJECT = GAME / "project.godot"
PRESETS = GAME / "export_presets.cfg"


def get():
    m = re.search(r'^config/version="([^"]+)"', PROJECT.read_text(), re.M)
    return m.group(1) if m else ""


def set_version(v):
    if not re.fullmatch(r"\d+\.\d+\.\d+", v):
        sys.exit(f"not a version: {v} (want X.Y.Z)")
    text = PROJECT.read_text()
    text = re.sub(r'^config/version="[^"]*"', f'config/version="{v}"', text, flags=re.M)
    PROJECT.write_text(text)
    p = PRESETS.read_text()
    p = re.sub(r'^(application/(?:short_)?version)="[^"]*"', rf'\1="{v}"', p, flags=re.M)
    p = re.sub(r'^(application/(?:file|product)_version)="[^"]*"', rf'\1="{v}.0"', p, flags=re.M)
    PRESETS.write_text(p)
    print("version", v)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "get":
        print(get())
    elif len(sys.argv) == 3 and sys.argv[1] == "set":
        set_version(sys.argv[2])
    else:
        sys.exit(__doc__)
