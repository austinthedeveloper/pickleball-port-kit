#!/bin/sh
# Imports the SNES repo's conformance traces (SNES ADR-068, docs/TUNING.md)
# into game/tests/conformance/: builds its tools/conformance.c on the host
# (into a temp folder: nothing is written in the SNES repo), runs it, and
# keeps each frame's line as a short hash (the full traces are megabytes).
# tests/test_conformance.gd replays every scenario and compares.
#   game/tools/conformance_import.sh [path/to/pickleball]   # default ../pickleball
# For a mismatch, KEEP=1 also copies the full traces to game/tests/conformance/full/
# (git-ignored) to read the C's line beside the port's.
set -e
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
SNES="$(cd "${1:-$KIT/../pickleball}" && pwd)"
OUT="$KIT/game/tests/conformance"
TMP="$(mktemp -d)"
SRC=$(sed -n '/^HOST_CORE :=/,/^[A-Z_]* :=/p' "$SNES/Makefile" | grep -v '^HOST_TESTS' \
  | sed 's/HOST_CORE :=//; s/\\//g' | tr -s ' \n' ' ')
( cd "$SNES" && ${CC:-cc} -std=c99 -Wall -Wextra -Werror -DHOST_TEST -Iinclude \
    -Iassets/generated -Itest tools/conformance.c $SRC -o "$TMP/conformance" )
"$TMP/conformance" "$TMP" >/dev/null
commit=$(git -C "$SNES" rev-parse --short HEAD)
python3 - "$TMP" "$OUT" "$commit" <<'PY'
import hashlib, sys, pathlib
tmp, out, commit = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
for tr in sorted(tmp.glob("*.trace")):
    head, frames = [], []
    for line in tr.read_text().splitlines():
        if line.startswith("#"):
            head.append(line)
        else:
            frames.append(hashlib.md5(line.encode()).hexdigest()[:12])
    head.insert(1, "# from the SNES repo at %s; one md5[:12] per frame line" % commit)
    (out / (tr.stem + ".hashes")).write_text("\n".join(head + frames) + "\n")
    print("imported", tr.stem, len(frames), "frames")
PY
if [ -n "$KEEP" ]; then mkdir -p "$OUT/full" && cp "$TMP"/*.trace "$OUT/full/"; fi
rm -rf "$TMP"
