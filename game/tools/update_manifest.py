"""The in-game updater's manifest for a release (ADR-057): the version, the
Godot version the pack needs (an update can't change the engine), the
pack's file name, size and SHA-256. CI publishes it beside the .pck.
    python3 game/tools/update_manifest.py 0.9.0 build/dist/Pickleball94-0.9.0.pck
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


def engine():
    """Godot's MAJOR.MINOR.PATCH, from `godot --version` (4.7.2.stable...)."""
    out = subprocess.run(["godot", "--version"], capture_output=True, text=True).stdout
    m = re.match(r"(\d+)\.(\d+)(?:\.(\d+))?", out.strip())
    return f"{m.group(1)}.{m.group(2)}.{m.group(3) or 0}"


def main():
    version, pck = sys.argv[1], Path(sys.argv[2])
    data = pck.read_bytes()
    print(json.dumps({"version": version, "engine": engine(), "pck": pck.name,
                      "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}, indent=1))


if __name__ == "__main__":
    main()
