#!/bin/sh
# Release exports (playbook 0.1, §9). Writes game/build_id.txt from
# `git describe --tags --always --dirty`, refusing a dirty tree, then exports each
# preset in export_presets.cfg into build/. Without Godot's export
# templates it says so and makes only the platform-free .pck (the export
# check), then boots the .pck headless for 200 frames.
#   game/tools/export.sh            # every preset (needs templates)
#   game/tools/export.sh --check    # the .pck check only
#   game/tools/export.sh --dev      # allow a dirty tree (the ID says -dirty)
cd "$(dirname "$0")/.." || exit 2
KIT="$(cd .. && pwd)"
check=0
dev=0
for a in "$@"; do
  [ "$a" = "--check" ] && check=1
  [ "$a" = "--dev" ] && dev=1
done
if ! git -C "$KIT" diff --quiet HEAD -- ; then
  if [ $dev -eq 0 ]; then
    echo "refused: the tree has uncommitted changes (commit, or pass --dev)"; exit 1
  fi
fi
id=$(git -C "$KIT" describe --tags --always --dirty)
printf '%s\n' "$id" > build_id.txt
echo "build $id"
godot --headless --path . --import >/dev/null 2>&1
ver=$(godot --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+).*/\1.\3/')
templates="$HOME/Library/Application Support/Godot/export_templates/$ver"
[ -d "$templates" ] || templates="$HOME/.local/share/godot/export_templates/$ver"
status=0
mkdir -p "$KIT/build/pck"
godot --headless --path . --export-pack "Linux" "$KIT/build/pck/Pickleball94.pck" >/dev/null 2>&1 || status=1
if [ $status -ne 0 ] || [ ! -s "$KIT/build/pck/Pickleball94.pck" ]; then
  echo "FAIL: the .pck export"; exit 1
fi
echo "ok   .pck exported ($(du -h "$KIT/build/pck/Pickleball94.pck" | cut -f1))"
out=$(godot --headless --main-pack "$KIT/build/pck/Pickleball94.pck" --quit-after 200 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR"; then
  echo "$out" | grep "SCRIPT ERROR"; echo "FAIL: the .pck doesn't boot cleanly"; exit 1
fi
echo "ok   the .pck boots and runs 200 frames"
[ $check -eq 1 ] && exit 0
if [ ! -d "$templates" ]; then
  echo "no export templates for $ver: install them (Editor > Manage Export Templates), then re-run"
  exit 3
fi
for p in macOS Windows Linux Web; do
  dest=$(awk -v p="$p" '$0=="name=\""p"\"" {f=1} f && /^export_path=/ {gsub(/export_path=|"/,""); print; exit}' export_presets.cfg)
  mkdir -p "$(dirname "$dest")"
  if godot --headless --path . --export-release "$p" "$dest" >/dev/null 2>&1 && [ -e "$dest" ]; then
    echo "ok   $p -> build/${dest#../build/}"
  else
    echo "FAIL $p"; status=1
  fi
done
exit $status
